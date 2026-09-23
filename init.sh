#!/bin/bash

# Master script to run both NDX infrastructure and member services
# Usage: ./init.sh
#
# Environment Variables:
#   CLEAN_START - Controls volume cleanup behavior (default: true)
#                 true:  Removes Docker volumes on exit (fresh start every time)
#                 false: Preserves Docker volumes (faster restarts, keeps data)
#
# Examples:
#   ./init.sh                    # Default: Clean volumes on exit
#   CLEAN_START=false ./init.sh  # Preserve data between runs

set -e

echo "=== Starting script at $(date) ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NDX_DIR="${SCRIPT_DIR}/ndx"
MEMBERS_DIR="${SCRIPT_DIR}/members"

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to log errors with context
log_error() {
    local line_number=$1
    local command=$2
    local exit_code=$3
    print_error "Command failed at line $line_number with exit code $exit_code"
    print_error "Failed command: $command"
    echo "=== Error occurred at $(date) ===" >> "$LOG_FILE"
}

# Function to cleanup on exit
cleanup() {
    local exit_code=$?

    # Preventing infinite loop when exiting by disabling traps.
    trap - INT TERM EXIT

    # Exit codes 130 (SIGINT/Ctrl+C) and 143 (SIGTERM) are normal user-initiated stops
    if [ $exit_code -ne 0 ] && [ $exit_code -ne 130 ] && [ $exit_code -ne 143 ]; then
        print_error "Script failed with exit code: $exit_code"
    fi

    print_info "Stopping all services..."

    # Stop member services (they should be killed by the script itself)
    print_info "Member services stopping..."

    # Stop docker-compose services
    print_info "Stopping NDX infrastructure services..."
    
    # Remove volumes based on CLEAN_START environment variable
    # Set CLEAN_START=false to preserve data between runs
    cd "$NDX_DIR"
    if [ "${CLEAN_START:-true}" = "true" ]; then
        print_info "Removing volumes (set CLEAN_START=false to preserve data)..."
        docker-compose down -v
    else
        print_info "Preserving volumes..."
        docker-compose down
    fi

    print_success "All services stopped"
    exit $exit_code
}

# Set trap to cleanup on exit and capture errors
trap cleanup INT TERM EXIT
trap 'log_error ${LINENO} "$BASH_COMMAND" $?' ERR

# Check if docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check Whether jq is installed
if ! command -v jq &> /dev/null; then
    print_error "Error: 'jq' is not installed."
    print_error "This script requires jq to parse JSON responses."
    echo "  - macOS: brew install jq"
    echo "  - Ubuntu: sudo apt-get install jq"
    exit 1
fi

print_info "Starting OpenNDX Farajaland - All Services"
print_info "==========================================="
echo ""

# Show cleanup behavior
if [ "${CLEAN_START:-true}" = "true" ]; then
    print_info "Volume cleanup: Enabled (set CLEAN_START=false to preserve data)"
else
    print_info "Volume cleanup: Disabled (data will be preserved between runs)"
fi
echo ""


# Initialize Variables. init.sh runs on the host, so it reaches ThunderID at the
# published localhost:8090 port - no /etc/hosts entry and no host-IP detection are
# needed for this local-only stack.
export IDP_PORT="${IDP_PORT:-8090}"
THUNDERID_URL=localhost:${IDP_PORT}

# The OIDC issuer is https://localhost:8090 (set in ndx/.env). The browser reaches
# it directly and ThunderID's dev cert is CN=localhost, so the cert matches, and
# consent-engine validates the token `iss` against this string. JWKS is fetched
# server-side by consent-engine over Docker DNS (thunderid:8090).
ISSUER_URL="https://localhost:${IDP_PORT}"

# Start NDX infrastructure services
print_info "Starting NDX infrastructure services (docker-compose)..."
cd "$NDX_DIR"

if [ ! -f "docker-compose.yml" ]; then
    print_error "docker-compose.yml not found in ndx directory"
    exit 1
fi

# Start docker-compose in detached mode
docker-compose up -d

if [ $? -ne 0 ]; then
    print_error "Failed to start docker-compose services"
    exit 1
fi

print_success "NDX infrastructure services started"
echo ""
print_info "Running services:"
print_info "  - etcd (ports 2379, 2380)"
print_info "  - API Gateway (ports 9081, 9180)"
print_info "  - Policy Decision Point (port 8082)"
print_info "  - Consent Engine (port 8081)"
print_info "  - Orchestration Engine (port 4000)"
print_info "  - PostgreSQL (port 5432)"
echo ""

# Wait for infrastructure services to be ready
print_info "Waiting for infrastructure services to be ready..."
sleep 20

# Check if postgres is ready
print_info "Checking PostgreSQL health..."
for i in {1..30}; do
    if docker-compose exec -T postgres pg_isready -U exchange > /dev/null 2>&1; then
        print_success "PostgreSQL is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        print_warning "PostgreSQL health check timeout, continuing anyway..."
    fi
    sleep 1
done

print_info "Checking ThunderID health..."

for i in $(seq 1 30); do
    # ThunderID's own convention: any HTTP response (including 401) means the
    # server is up - don't exit on curl failure, just retry.
    if STATUS_CODE=$(curl -o /dev/null -s -w "%{http_code}" --connect-timeout 5 --max-time 10 --insecure \
        https://"$THUNDERID_URL"/ 2>/dev/null); then

        if [ -n "$STATUS_CODE" ] && [ "$STATUS_CODE" != "000" ]; then
            print_success "ThunderID is ready (HTTP $STATUS_CODE)"
            break
        else
            print_info "ThunderID responded with HTTP $STATUS_CODE, retrying... ($i/30)"
        fi
    else
        print_info "ThunderID not reachable yet, retrying... ($i/30)"
    fi

    if [ "$i" -eq 30 ]; then
        print_error "ThunderID health check failed after 30 attempts"
        print_error "Please check if the ThunderID containers are running properly:"
        print_error "  docker-compose -f $NDX_DIR/docker-compose.yml logs thunderid thunderid-setup thunderid-db-init"
        print_error ""
        print_error "The script will now exit. Please resolve the issue and try again."
        exit 1
    fi

    sleep 2
done

# The API Gateway client, the Consent Portal client, CORS, and the mock
# citizen user are all infrastructure - provisioned declaratively at startup
# by thunderid-setup's in-process bootstrap (config/thunderid/bootstrap/
# 02..07-*.yaml, see docker-compose.yml). Nothing left for this script to POST
# for those; the client ids/secrets below just have to agree with those files
# (see ndx/.env).
GATEWAY_CLIENT_ID="ndx-api-gateway"
GATEWAY_CLIENT_SECRET="${GATEWAY_CLIENT_SECRET:-1234}"
CLIENT_ID="$GATEWAY_CLIENT_ID"

PORTAL_CLIENT_ID="CONSENT_PORTAL_APP"

print_success "ThunderID infra apps, CORS, and the mock user were already provisioned by thunderid-setup"
print_info "API Gateway Client ID: $CLIENT_ID"
print_info "Consent Portal Client ID: $PORTAL_CLIENT_ID"
echo ""

# The passport app, by contrast, is a data-consumer application, not exchange
# infrastructure - in a real deployment it would be onboarded at runtime,
# after the exchange is already up, through whatever registration flow the
# exchange operator exposes. We register it the same way here: mint a
# system-scoped management token from admin-cli (created by
# config/thunderid/bootstrap/02-admin-cli.yaml), then POST its declarative
# resource file to ThunderID's authenticated /import API - the same
# import mechanism thunderid-setup itself uses internally, just invoked
# explicitly and after the fact rather than at boot. This is a convenience so
# trying the passport app doesn't require hand-crafting a REST payload; it is
# not a stand-in for the real (manual, admin-console/API) onboarding flow.
print_info "Registering the Passport Application data-consumer app..."
M2M_CLIENT_ID="passport-app"
M2M_CLIENT_SECRET="${PASSPORT_CLIENT_SECRET:-1234}"

ADMIN_CLI_SECRET="${ADMIN_CLI_SECRET:-1234}"
# The image-shipped "System" resource server's identifier (see
# config/thunderid/bootstrap/02-admin-cli.yaml's resourceServerId) - 1.0.1
# requires client_credentials token requests to name a target resource
# explicitly via `resource`, unlike 0.48.
SYSTEM_RESOURCE_SERVER="https://${THUNDERID_URL}/mcp"
ADMIN_TOKEN_RESPONSE=$(curl --silent -X POST https://"$THUNDERID_URL"/oauth2/token \
  --insecure \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "ADMIN_CLI:$ADMIN_CLI_SECRET" \
  --data-urlencode "grant_type=client_credentials" \
  --data-urlencode "scope=system" \
  --data-urlencode "resource=${SYSTEM_RESOURCE_SERVER}")
ADMIN_TOKEN=$(echo "$ADMIN_TOKEN_RESPONSE" | jq -r '.access_token')

if [ "$ADMIN_TOKEN" = "null" ] || [ -z "$ADMIN_TOKEN" ]; then
    print_error "Failed to mint admin-cli management token"
    print_error "Response was: $ADMIN_TOKEN_RESPONSE"
    exit 1
fi

PASSPORT_APP_YAML="$NDX_DIR/config/thunderid/data-consumers/passport-application.yaml"
PASSPORT_APP_RESOLVED=$(sed "s/{{ .PASSPORT_CLIENT_SECRET }}/${M2M_CLIENT_SECRET}/" "$PASSPORT_APP_YAML")
IMPORT_PAYLOAD=$(jq -n --arg content "$PASSPORT_APP_RESOLVED" \
  '{content: $content, options: {upsert: true, continueOnError: false, target: "runtime"}}')
IMPORT_RESPONSE=$(curl --silent -X POST https://"$THUNDERID_URL"/import \
  --insecure \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  --data "$IMPORT_PAYLOAD")
IMPORT_FAILED=$(echo "$IMPORT_RESPONSE" | jq -r '.summary.failed // "unknown"')

if [ "$IMPORT_FAILED" = "0" ]; then
    print_success "Passport Application registered successfully"
else
    print_error "Failed to register the Passport Application (HTTP response below)"
    print_error "Response: $IMPORT_RESPONSE"
    exit 1
fi
print_info "Passport Application Client ID: $M2M_CLIENT_ID"
echo ""
# Extract ThunderID's RS256 signing public key so APISIX can verify token
# signatures locally (public_key mode). We validate locally rather than via JWKS
# because the issuer is https://localhost:8090: the JWKS URL advertised in the
# discovery document would be https://localhost:8090/oauth2/jwks, which the APISIX
# container cannot reach (there, localhost means APISIX itself). Local verification
# needs no network call to the IdP, so the issuer host is only ever compared as a
# string (claim_validator.issuer.valid_issuers), never dereferenced.
print_info "Extracting ThunderID signing public key for APISIX token validation..."
THUNDERID_CID=$(docker-compose ps -q thunderid)
if [ -z "$THUNDERID_CID" ]; then
    print_error "Could not find the thunderid container to extract its signing key"
    exit 1
fi
if ! command -v openssl >/dev/null 2>&1; then
    print_error "'openssl' is not installed on the host; it is required to extract the signing public key"
    exit 1
fi
SIGNING_CERT_FILE="$(mktemp)"
if ! docker cp "${THUNDERID_CID}:/opt/thunderid/config/certs/signing.cert" "$SIGNING_CERT_FILE" >/dev/null 2>&1; then
    print_error "Failed to copy the signing certificate from the thunderid container"
    rm -f "$SIGNING_CERT_FILE"
    exit 1
fi
IDP_PUBLIC_KEY=$(openssl x509 -in "$SIGNING_CERT_FILE" -pubkey -noout 2>/dev/null)
rm -f "$SIGNING_CERT_FILE"
if [ -z "$IDP_PUBLIC_KEY" ]; then
    print_error "Failed to extract the ThunderID signing public key from the certificate"
    exit 1
fi
print_success "Extracted ThunderID signing public key"
echo ""

# Register Orchestration Engine Routes
print_info "Exposing OE Endpoints Publicly with OpenID Connect Authentication"
OE_ROUTE_CODE=$(jq -n \
  --arg pk "$IDP_PUBLIC_KEY" \
  --arg client_id "$CLIENT_ID" \
  --arg client_secret "$GATEWAY_CLIENT_SECRET" \
  --arg discovery "https://thunderid:${IDP_PORT}/.well-known/openid-configuration" \
  --arg issuer "$ISSUER_URL" \
  '{
    uri: "/public/*",
    methods: ["GET", "POST"],
    upstream: { type: "roundrobin", nodes: { "orchestration-engine:4000": 1 } },
    plugins: {
      "openid-connect": {
        client_id: $client_id,
        client_secret: $client_secret,
        discovery: $discovery,
        bearer_only: true,
        public_key: $pk,
        token_signing_alg_values_expected: "RS256",
        claim_validator: { issuer: { valid_issuers: [$issuer] } },
        set_userinfo_header: true,
        ssl_verify: false
      }
    },
    id: "oe-endpoint"
  }' | curl -s -o /dev/null -w "%{http_code}" \
    --location --request PUT http://localhost:9180/apisix/admin/routes \
    --header "Content-Type: application/json" \
    --header "X-API-KEY: QuNGwapKysRvHfUtNkQFbUaGiiYeOcGo" \
    --data @-)

if [ "$OE_ROUTE_CODE" != "200" ] && [ "$OE_ROUTE_CODE" != "201" ]; then
    print_error "Failed to register OE public routes (HTTP $OE_ROUTE_CODE)"
    exit 1
fi

print_info "Exposing Required Consent Engine Endpoints Publicly with OpenID Connect Authentication"

CE_ROUTE_CODE=$(jq -n \
  --arg pk "$IDP_PUBLIC_KEY" \
  --arg client_id "$CLIENT_ID" \
  --arg client_secret "$GATEWAY_CLIENT_SECRET" \
  --arg discovery "https://thunderid:${IDP_PORT}/.well-known/openid-configuration" \
  --arg issuer "$ISSUER_URL" \
  --arg cors_origin "${CONSENT_PORTAL_URL:-http://localhost:5173}" \
  '{
    uri: "/api/v1/consents/*",
    methods: ["GET", "PUT", "OPTIONS"],
    upstream: { type: "roundrobin", nodes: { "consent-engine:8081": 1 } },
    plugins: {
      "openid-connect": {
        client_id: $client_id,
        client_secret: $client_secret,
        discovery: $discovery,
        bearer_only: true,
        public_key: $pk,
        token_signing_alg_values_expected: "RS256",
        claim_validator: { issuer: { valid_issuers: [$issuer] } },
        set_userinfo_header: true,
        ssl_verify: false,
        access_token_in_authorization_header: true
      },
      "cors": {
        allow_origins: $cors_origin,
        allow_headers: "*",
        allow_methods: "GET,PUT,OPTIONS"
      }
    },
    id: "consent-endpoint"
  }' | curl -s -o /dev/null -w "%{http_code}" \
    --location --request PUT http://localhost:9180/apisix/admin/routes \
    --header "Content-Type: application/json" \
    --header "X-API-KEY: QuNGwapKysRvHfUtNkQFbUaGiiYeOcGo" \
    --data @-)

if [ "$CE_ROUTE_CODE" != "200" ] && [ "$CE_ROUTE_CODE" != "201" ]; then
    print_error "Failed to register consent engine routes (HTTP $CE_ROUTE_CODE)"
    exit 1
fi

print_success "Consent engine routes registered successfully"
echo ""

print_info "Exposing Required Audit Service Endpoints Publicly"

curl --location --request PUT 'http://localhost:9180/apisix/admin/routes' \
--header 'Content-Type: application/json' \
--header 'X-API-KEY: QuNGwapKysRvHfUtNkQFbUaGiiYeOcGo' \
--data @- <<EOF
{
    "uri": "/api/audit-logs",
    "methods": [
        "GET"
    ],
    "upstream": {
        "type": "roundrobin",
        "nodes": {
            "audit-service:3001": 1
        }
    },
    "id": "audit-endpoint"
}
EOF

if [ $? -ne 0 ]; then
  print_error "Failed to register audit service routes"
  exit 1
fi

print_success "Audit Service public routes registered successfully"
echo ""


print_success "=========================================="
print_success "M2M Application Credentials"
print_success "=========================================="
print_info "Application Name: Passport Application"
print_info "Client ID:        $M2M_CLIENT_ID"
print_info "Client Secret:    $M2M_CLIENT_SECRET"
print_success "=========================================="
echo ""
print_info "Mock user - Username: nayana"
print_info "Mock user - Password: ${MOCK_USER_PASSWORD:-Abc12#45}"
echo ""

# Start member services
print_info "Starting member data source services..."
cd "$MEMBERS_DIR"

if [ ! -f "run-member-services.sh" ]; then
    print_error "run-member-services.sh not found in members directory"
    exit 1
fi

if [ ! -x "run-member-services.sh" ]; then
    print_info "Making run-member-services.sh executable..."
    chmod +x run-member-services.sh
fi

# Export M2M credentials for use by run-member-services.sh
export M2M_CLIENT_ID
export M2M_CLIENT_SECRET

# Run member services
./run-member-services.sh all

print_success "=========================================="
print_success "All services started successfully!"
print_success "=========================================="
echo ""

# Prompt user to access the passport application
echo ""
print_info "=========================================="
print_info "Next Step: Test Passport Application"
print_info "=========================================="
echo ""
print_info "Please open the passport application in your browser:"
print_info "  URL: http://localhost:3000"
echo ""
print_info "Login with the following credentials:"
print_info "  Username:   nayana"
print_info "  Password:   Abc12#45"
echo ""
print_info "This will allow you to provide consent for the application."
print_info "=========================================="
echo ""
print_warning "Press Ctrl+C to stop all services"

# Keep script running until interrupted
print_info "All services are running. Monitoring..."
while true; do
    sleep 60
done
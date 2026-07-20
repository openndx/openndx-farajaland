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

# Load env variables from ndx/.env if it exists
if [ -f "${NDX_DIR}/.env" ]; then
    print_info "Loading environment variables from ndx/.env..."
    while IFS= read -r line || [ -n "$line" ]; do
        # Strip carriage returns for Windows compatibility
        line="${line//$'\r'/}"
        # Ignore comments and empty lines
        if [[ ! "$line" =~ ^[[:space:]]*# ]] && [[ -n "$line" ]]; then
            # Only export valid key=value assignments
            if [[ "$line" =~ ^([A-Za-z0-9_]+)=(.*)$ ]]; then
                var_name="${BASH_REMATCH[1]}"
                var_val="${BASH_REMATCH[2]}"
                # Strip trailing comments starting with space + #
                if [[ "$var_val" =~ ^(.*[^[:space:]])[[:space:]]+#.*$ ]]; then
                    var_val="${BASH_REMATCH[1]}"
                elif [[ "$var_val" =~ ^[[:space:]]*#.*$ ]]; then
                    var_val=""
                fi
                # Strip surrounding quotes if present
                var_val="${var_val#\"}"
                var_val="${var_val%\"}"
                var_val="${var_val#\'}"
                var_val="${var_val%\'}"
                # Trim trailing whitespace
                var_val="${var_val%"${var_val##*[![:space:]]}"}"
                # Only set if not already present in the environment (allows
                # overrides via `VAR=val ./init.sh`)
                if [ -z "${!var_name+x}" ]; then
                    export "$var_name=$var_val"
                fi
            fi
        fi
    done < "${NDX_DIR}/.env"
fi

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
ADMIN_CLI_SECRET="${ADMIN_CLI_SECRET:-1234}"

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

# Stop existing services and clean volumes if CLEAN_START is true
if [ "${CLEAN_START:-true}" = "true" ]; then
    print_info "CLEAN_START is enabled. Cleaning up existing containers and volumes..."
    docker-compose down -v --remove-orphans &> /dev/null || true
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

# Step 1: Mint a system-scoped management token from the admin-cli M2M client.
# admin-cli (client_id ADMIN_CLI) and its system-scoped role grant were already
# created by config/thunderid/bootstrap/02-admin-cli.yaml, imported by ThunderID's
# in-process bootstrap during the thunderid-setup phase, so no temporary throwaway
# app is needed here - this single call replaces WSO2's entire temp-DCR-app +
# scope-granting dance.
print_info "Minting admin-cli management token..."
TOKEN_RESPONSE=$(curl --silent -X POST https://"$THUNDERID_URL"/oauth2/token \
  --insecure \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "ADMIN_CLI:$ADMIN_CLI_SECRET" \
  -d "grant_type=client_credentials&scope=system")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
    print_error "Failed to mint admin-cli management token"
    print_error "Response was: $TOKEN_RESPONSE"
    exit 1
fi

print_success "Admin-cli management token obtained successfully!"
echo ""

# --- ThunderID Management API helpers -------------------------------------

extract_first_id() {
    echo "$1" | jq -r '.. | objects | .id // empty' 2>/dev/null | head -n 1
}

thunderid_api_call() {
    local method="$1" path="$2" body="${3:-}"
    local -a curl_args=(-s -S -X "$method" --insecure -H "Content-Type: application/json" \
        -H "Authorization: Bearer $ACCESS_TOKEN" -w '%{http_code}')
    [ -n "$body" ] && curl_args+=(-d "$body")
    curl "${curl_args[@]}" "https://$THUNDERID_URL${path}"
}

# Configure server-wide CORS allowed origins. ThunderID 0.48 removed the static
# `cors` block from deployment.yaml; CORS is now a server-config section. Only the
# Consent Portal (CONSENT_PORTAL_APP, http://localhost:5173) calls /oauth2/token
# cross-origin, so it is the only origin that needs allowing. The ThunderID Console
# is served from the issuer itself (https://localhost:8090), so its /oauth2/token
# calls are same-origin and need no CORS entry. This sets the writable layer
# (PUT /server-config/cors), which is DB-backed and read by the running server's
# dynamic CORS matcher.
configure_cors() {
    local CONSENT_PORTAL_ORIGIN="${CONSENT_PORTAL_URL:-http://localhost:5173}"
    local RESPONSE HTTP_CODE CORS_PAYLOAD
    read -r -d '' CORS_PAYLOAD <<JSON || true
{
    "allowedOrigins": [
        "${CONSENT_PORTAL_ORIGIN}"
    ]
}
JSON
    RESPONSE=$(thunderid_api_call PUT "/server-config/cors" "$CORS_PAYLOAD")
    HTTP_CODE="${RESPONSE: -3}"
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "204" ]; then
        print_success "Configured CORS allowed origins (Consent Portal)"
    else
        print_warning "Failed to configure CORS allowed origins (HTTP $HTTP_CODE) - browser apps may hit CORS errors"
    fi
}

get_ou_id_by_handle() {
    local OU_HANDLE="$1"
    local RESPONSE HTTP_CODE BODY
    RESPONSE=$(thunderid_api_call GET "/organization-units/tree/${OU_HANDLE}")
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    [ "$HTTP_CODE" != "200" ] && { echo ""; return; }
    extract_first_id "$BODY"
}

# Look up the image-provided "Classic" theme id so the SPA login screen is themed.
get_classic_theme_id() {
    local RESPONSE HTTP_CODE BODY
    RESPONSE=$(thunderid_api_call GET "/design/themes")
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    [ "$HTTP_CODE" != "200" ] && { echo ""; return; }
    echo "$BODY" | jq -r '.. | objects | select(.displayName == "Classic") | .id // empty' 2>/dev/null | head -n 1
}

# Create an M2M (client_credentials) application. On a 409 ("already exists")
# it's treated as an idempotent no-op rather than a failure.
create_m2m_application() {
    local APP_NAME="$1" APP_DESCRIPTION="$2" CLIENT_ID_NEW="$3" CLIENT_SECRET_NEW="$4" OU_ID="$5"
    local RESPONSE HTTP_CODE BODY

    read -r -d '' APP_PAYLOAD <<JSON || true
{
    "name": "${APP_NAME}",
    "description": "${APP_DESCRIPTION}",
    "ouId": "${OU_ID}",
    "isRegistrationFlowEnabled": false,
    "assertion": { "validityPeriod": 3600 },
    "inboundAuthConfig": [
        {
            "type": "oauth2",
            "config": {
                "clientId": "${CLIENT_ID_NEW}",
                "clientSecret": "${CLIENT_SECRET_NEW}",
                "grantTypes": ["client_credentials", "refresh_token", "urn:ietf:params:oauth:grant-type:token-exchange"],
                "tokenEndpointAuthMethod": "client_secret_basic",
                "pkceRequired": false,
                "publicClient": false,
                "token": { "accessToken": { "clientConfig": { "validityPeriod": 3600 } } }
            }
        }
    ],
    "allowedUserTypes": []
}
JSON

    RESPONSE=$(thunderid_api_call POST "/applications" "${APP_PAYLOAD}")
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"

    if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
        print_success "${APP_NAME} M2M application created successfully"
    elif [ "$HTTP_CODE" = "409" ] || echo "$BODY" | grep -qE "Application already exists|APP-1022"; then
        print_warning "${APP_NAME} M2M application already exists, reusing it"
    else
        print_error "Failed to create ${APP_NAME} M2M application (HTTP $HTTP_CODE)"
        print_error "Response: $BODY"
        exit 1
    fi
}

# Create a SPA (authorization_code + PKCE) application. Idempotent like above.
create_spa_application() {
    local APP_NAME="$1" APP_DESCRIPTION="$2" CLIENT_ID_NEW="$3" REDIRECT_URI="$4" OU_ID="$5"
    local RESPONSE HTTP_CODE BODY

    # Attach the Classic theme (top-level app field) when it was resolved, so
    # the login screen renders themed.
    local THEME_FIELD=""
    [ -n "$CLASSIC_THEME_ID" ] && THEME_FIELD="
    \"themeId\": \"${CLASSIC_THEME_ID}\","

    read -r -d '' APP_PAYLOAD <<JSON || true
{
    "name": "${APP_NAME}",
    "description": "${APP_DESCRIPTION}",${THEME_FIELD}
    "ouId": "${OU_ID}",
    "isRegistrationFlowEnabled": false,
    "inboundAuthConfig": [
        {
            "type": "oauth2",
            "config": {
                "clientId": "${CLIENT_ID_NEW}",
                "redirectUris": ["${REDIRECT_URI}"],
                "grantTypes": ["authorization_code", "refresh_token", "urn:ietf:params:oauth:grant-type:token-exchange"],
                "responseTypes": ["code"],
                "tokenEndpointAuthMethod": "none",
                "pkceRequired": true,
                "publicClient": true,
                "token": {
                    "accessToken": { "userConfig": { "validityPeriod": 3600, "attributes": ["email"] } },
                    "idToken": { "validityPeriod": 3600 }
                }
            }
        }
    ],
    "allowedUserTypes": ["Person"]
}
JSON

    RESPONSE=$(thunderid_api_call POST "/applications" "${APP_PAYLOAD}")
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"

    if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
        print_success "${APP_NAME} SPA application created successfully"
    elif [ "$HTTP_CODE" = "409" ] || echo "$BODY" | grep -qE "Application already exists|APP-1022"; then
        print_warning "${APP_NAME} SPA application already exists, reusing it"
    else
        print_error "Failed to create ${APP_NAME} SPA application (HTTP $HTTP_CODE)"
        print_error "Response: $BODY"
        exit 1
    fi
}
# ----------------------------------------------------------------------------

# Look up the default Organization Unit id (image-provided, created by
# 01-default-resources.sh) - needed as ouId for every application/user below.
# Allow the browser apps' origins to call ThunderID cross-origin before we create
# the apps they belong to.
configure_cors
echo ""

DEFAULT_OU_ID=$(get_ou_id_by_handle "default")
if [ -z "$DEFAULT_OU_ID" ]; then
    print_error "Failed to resolve default organization unit"
    exit 1
fi
print_success "Default OU id: $DEFAULT_OU_ID"
echo ""

# Look up the Classic theme so the Consent Portal login screen is themed.
# Non-fatal if not found.
CLASSIC_THEME_ID=$(get_classic_theme_id)
if [ -n "$CLASSIC_THEME_ID" ]; then
    print_success "Classic theme id: $CLASSIC_THEME_ID"
else
    print_warning "Classic theme not found; Consent Portal app will be created without a theme"
fi
echo ""

# Step 2: Create the API Gateway M2M application.
# The apisix routes below validate bearer tokens by verifying their RS256 signature
# locally against ThunderID's signing public key (extracted below). The app's
# client_id only satisfies the openid-connect plugin's config schema (client_id is
# a required field); its secret is not used, since local verification needs no
# token exchange or introspection call.
print_info "Creating M2M application for API Gateway..."
GATEWAY_CLIENT_ID="ndx-api-gateway"
GATEWAY_CLIENT_SECRET="${GATEWAY_CLIENT_SECRET:-$(openssl rand -hex 16)}"
create_m2m_application "NDX_API_GATEWAY" "M2M client used by APISIX to validate bearer tokens" \
    "$GATEWAY_CLIENT_ID" "$GATEWAY_CLIENT_SECRET" "$DEFAULT_OU_ID"
CLIENT_ID="$GATEWAY_CLIENT_ID"
print_info "API Gateway Client ID: $CLIENT_ID"
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
  --arg discovery "https://thunderid:${IDP_PORT}/.well-known/openid-configuration" \
  --arg issuer "$ISSUER_URL" \
  '{
    uri: "/public/*",
    methods: ["GET", "POST"],
    upstream: { type: "roundrobin", nodes: { "orchestration-engine:4000": 1 } },
    plugins: {
      "openid-connect": {
        client_id: $client_id,
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


# Create M2M Application (Passport Application) using the Management API.
# ThunderID lets us choose the clientId/clientSecret directly, so there's no
# separate "retrieve generated credentials" round trip needed.
print_info "Creating M2M application (Passport Application)..."
M2M_CLIENT_ID="passport-application"
M2M_CLIENT_SECRET="${PASSPORT_CLIENT_SECRET:-$(openssl rand -hex 16)}"
create_m2m_application "Passport Application" "M2M client used by the Online Passport App" \
    "$M2M_CLIENT_ID" "$M2M_CLIENT_SECRET" "$DEFAULT_OU_ID"

print_success "M2M application (Passport Application) created successfully!"
echo ""
print_success "=========================================="
print_success "M2M Application Credentials"
print_success "=========================================="
print_info "Application Name: Passport Application"
print_info "Client ID:        $M2M_CLIENT_ID"
print_info "Client Secret:    $M2M_CLIENT_SECRET"
print_success "=========================================="
echo ""

# Define the Consent Portal client ID (unchanged from the WSO2 setup)
PORTAL_CLIENT_ID="CONSENT_PORTAL_APP"

print_info "Creating SPA application for Consent Portal..."
create_spa_application "NDX_CONSENT_PORTAL" "Single-Page Application for NDX Consent Portal" \
    "$PORTAL_CLIENT_ID" "http://localhost:5173" "$DEFAULT_OU_ID"

print_success "Consent Portal application created successfully!"
print_info "Consent Portal Client ID: $PORTAL_CLIENT_ID"

echo ""


echo ""
print_success "=========================================="
print_success "Application Setup Completed!"
print_success "=========================================="
echo ""
print_info "API Gateway Client ID: $CLIENT_ID"
print_info "Consent Portal Client ID: $PORTAL_CLIENT_ID"
echo ""

# Enable token exchange on the Google IDP. ThunderID's declarative bootstrap
# doesn't accept token_exchange_enabled/trusted_token_audience as IDP
# properties, so we patch the IDP record in the config database directly
# and restart ThunderID to pick up the change.
if [ -n "${GOOGLE_CLIENT_ID}" ]; then
    print_info "Enabling token exchange for Google IDP..."

    GOOGLE_IDP_ID="01900000-0000-7000-8000-000000000080"
    IDP_CONTAINER="thunderid-${ENVIRONMENT:-local}"

    # Read current properties, inject token_exchange_enabled + trusted_token_audience
    CURRENT_PROPS=$(docker exec -i "$IDP_CONTAINER" sqlite3 database/configdb.db \
        "SELECT properties FROM IDP WHERE id='${GOOGLE_IDP_ID}';" 2>/dev/null || echo "")

    if [ -n "$CURRENT_PROPS" ]; then
        # Build new properties JSON with token exchange fields added
        NEW_PROPS=$(echo "$CURRENT_PROPS" | python3 -c "
import json, sys
props = json.loads(sys.stdin.read().strip())
props['token_exchange_enabled'] = {'value': 'true', 'isSecret': False}
props['trusted_token_audience'] = {'value': '${GOOGLE_CLIENT_ID}', 'isSecret': False}
props['jwks_endpoint'] = {'value': 'https://www.googleapis.com/oauth2/v3/certs', 'isSecret': False}
print(json.dumps(props))
" 2>/dev/null || echo "")

        if [ -n "$NEW_PROPS" ]; then
            docker exec -i "$IDP_CONTAINER" sqlite3 database/configdb.db \
                "UPDATE IDP SET properties = '${NEW_PROPS}' WHERE id = '${GOOGLE_IDP_ID}';" 2>/dev/null
            if [ $? -eq 0 ]; then
                print_success "Token exchange enabled for Google IDP"
                # Restart ThunderID so it picks up the updated IDP config
                print_info "Restarting ThunderID to apply IDP configuration..."
                docker restart "$IDP_CONTAINER" > /dev/null 2>&1

                # Wait for ThunderID to be healthy again
                HEALTH_TIMEOUT=30
                HEALTH_ELAPSED=0
                while [ $HEALTH_ELAPSED -lt $HEALTH_TIMEOUT ]; do
                    if curl -k -s -o /dev/null "https://localhost:${IDP_PORT:-8090}/" 2>/dev/null; then
                        break
                    fi
                    sleep 2
                    HEALTH_ELAPSED=$((HEALTH_ELAPSED + 2))
                done
                if [ $HEALTH_ELAPSED -lt $HEALTH_TIMEOUT ]; then
                    print_success "ThunderID restarted successfully"
                else
                    print_warning "ThunderID may still be starting up"
                fi
            else
                print_warning "Failed to update IDP properties in database"
            fi
        else
            print_warning "Failed to build updated IDP properties JSON"
        fi
    else
        print_warning "Google IDP not found in database (skipping token exchange setup)"
    fi
else
    print_info "GOOGLE_CLIENT_ID not set, skipping Google IDP token exchange setup"
fi
echo ""

# Create a mock user via ThunderID's User Management API (no SCIM2 equivalent
# exists in ThunderID - this is its own custom user API, scoped by OU + user
# type; "Person" is the image-provided default user type).
print_info "Creating mock user..."
USER_RESPONSE=$(thunderid_api_call POST "/users" "$(cat <<EOF
{
  "type": "Person",
  "ouId": "${DEFAULT_OU_ID}",
  "attributes": {
    "username": "nayana",
    "password": "${MOCK_USER_PASSWORD:-Abc12#45}",
    "email": "nayana@opensource.lk",
    "given_name": "Nayana",
    "family_name": "Samaranayake",
    "openndx-uid": "${MOCK_USER_EMAIL:-nayana@opensource.lk}"
  }
}
EOF
)")
USER_HTTP_CODE="${USER_RESPONSE: -3}"
USER_BODY="${USER_RESPONSE%???}"

if [ "$USER_HTTP_CODE" = "201" ] || [ "$USER_HTTP_CODE" = "200" ]; then
    SCIM_USER_ID=$(extract_first_id "$USER_BODY")
    print_success "Mock user created successfully!"
    print_info "User ID: $SCIM_USER_ID"
    print_info "Username: nayana"
    print_info "Password: ${MOCK_USER_PASSWORD:-Abc12#45}"
elif [ "$USER_HTTP_CODE" = "409" ]; then
    print_warning "Mock user 'nayana' already exists, skipping"
else
    print_warning "Failed to create mock user (HTTP $USER_HTTP_CODE)"
    print_info "Response: $USER_BODY"
fi
echo ""

# Create a mock user for Google Federated Login OIDC testing if variables are configured in ndx/.env
if [ -n "$FED_USER_USERNAME" ] && [ "$FED_USER_USERNAME" != "your-google-username" ] && [ "$FED_USER_EMAIL" != "your-google-email@gmail.com" ]; then
    print_info "Creating mock federated user '${FED_USER_USERNAME}' for Google Account OIDC linking..."
    FED_USER_RESPONSE=$(thunderid_api_call POST "/users" "$(cat <<EOF
{
  "type": "Person",
  "ouId": "${DEFAULT_OU_ID}",
  "attributes": {
    "username": "${FED_USER_USERNAME}",
    "password": "${MOCK_USER_PASSWORD:-Abc12#45}",
    "email": "${FED_USER_EMAIL}",
    "given_name": "${FED_USER_GIVEN_NAME:-User}",
    "family_name": "${FED_USER_FAMILY_NAME:-Test}",
    "openndx-uid": "${FED_USER_EMAIL}"
  }
}
EOF
)")
    FED_USER_HTTP_CODE="${FED_USER_RESPONSE: -3}"
    FED_USER_BODY="${FED_USER_RESPONSE%???}"

    if [ "$FED_USER_HTTP_CODE" = "201" ] || [ "$FED_USER_HTTP_CODE" = "200" ]; then
        print_success "Federated user '${FED_USER_USERNAME}' created successfully!"
        print_info "This user will be linked when you sign in with Google (${FED_USER_EMAIL})"
    elif [ "$FED_USER_HTTP_CODE" = "409" ]; then
        print_warning "Federated user '${FED_USER_USERNAME}' already exists, skipping"
    else
        print_warning "Failed to create federated user '${FED_USER_USERNAME}' (HTTP $FED_USER_HTTP_CODE)"
        print_info "Response: $FED_USER_BODY"
    fi
    echo ""
else
    print_info "Skipping federated user creation (FED_USER_USERNAME not configured)"
    print_info "To test Google federation, set FED_USER_* variables in ndx/.env"
    print_info "See LOCAL_DEVELOPMENT.md for instructions."
    echo ""
fi

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
print_info "Next Step: Test the Application"
print_info "=========================================="
echo ""
print_info "Passport Application:  http://localhost:3000"
print_info "Consent Portal:        http://localhost:5173"
echo ""
print_info "Basic Login (username/password):"
print_info "  Username:   nayana"
print_info "  Password:   Abc12#45"
echo ""
if [ -n "$GOOGLE_CLIENT_ID" ] && [ "$GOOGLE_CLIENT_ID" != "your-google-client-id.apps.googleusercontent.com" ]; then
    print_success "Google Federation: Enabled ✓"
    print_info "  Click 'Sign in with Google' on the Passport App to test"
else
    print_warning "Google Federation: Not configured"
    print_info "  Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET in ndx/.env"
    print_info "  See LOCAL_DEVELOPMENT.md for setup instructions"
fi
print_info "=========================================="
echo ""
print_warning "Press Ctrl+C to stop all services"

# Keep script running until interrupted
print_info "All services are running. Monitoring..."
while true; do
    sleep 60
done
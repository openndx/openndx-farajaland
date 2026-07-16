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

print_info "Starting OpenDIF Farajaland - All Services"
print_info "==========================================="
echo ""

# Show cleanup behavior
if [ "${CLEAN_START:-true}" = "true" ]; then
    print_info "Volume cleanup: Enabled (set CLEAN_START=false to preserve data)"
else
    print_info "Volume cleanup: Disabled (data will be preserved between runs)"
fi
echo ""


# Detect machine IP address for Rancher Desktop compatibility
detect_host_ip() {
    local ip=""

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - try different interfaces
        for interface in en0 en1; do
            ip=$(ipconfig getifaddr "$interface" 2>/dev/null)
            # Validate IPv4 format
            if [ -n "$ip" ] && [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                echo "$ip"
                return 0
            fi
        done
    elif [[ "$OSTYPE" == msys* ]] || [[ "$OSTYPE" == cygwin* ]] || [[ "$OSTYPE" == win32 ]]; then
        # Windows (Git Bash / MSYS / Cygwin) - `ipconfig` output ordering isn't
        # stable (virtual adapters like Hyper-V/WSL can list before the real
        # LAN adapter), so parsing it is unreliable. Docker Desktop registers
        # host.docker.internal in the Windows hosts file too, so it resolves
        # correctly from both the host shell and from inside containers.
        echo "host.docker.internal"
        return 0
    else
        # Linux - get first IPv4 address (filter out IPv6)
        ip=$(hostname -I 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i ~ /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/) {print $i; exit}}')
        if [ -n "$ip" ]; then
            echo "$ip"
            return 0
        fi
    fi

    # Fallback: Try Docker gateway
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        ip=$(docker run --rm --net host alpine ip route 2>/dev/null | awk '/default/ {print $3}' | head -1)
        if [ -n "$ip" ] && [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "$ip"
            return 0
        fi
    fi

    return 1
}

print_info "Detecting host machine IP address..."
HOST_IP="${HOST_IP:-$(detect_host_ip)}"

if [ -z "$HOST_IP" ] || [ "$HOST_IP" = "null" ]; then
    print_error "Failed to detect host IP address"
    print_info "For Rancher Desktop, set HOST_IP manually:"
    print_info "  export HOST_IP=\$(hostname -I | awk '{print \$1}')"
    print_info "  # Or use: export HOST_IP=host.docker.internal"
    exit 1
fi

# Validate IP format
if [[ ! $HOST_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && [ "$HOST_IP" != "host.docker.internal" ]; then
    print_error "Invalid HOST_IP format: $HOST_IP"
    exit 1
fi

print_success "Detected the Host Machine IP: $HOST_IP"
export HOST_IP

# Initialize Variables
THUNDERID_URL=${HOST_IP}:${IDP_PORT:-8090}
ADMIN_CLI_SECRET="${ADMIN_CLI_SECRET:-1234}"
export IDP_PORT="${IDP_PORT:-8090}"

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
# `cors` block from deployment.yaml; CORS is now a server-config section. The
# browser-facing apps call /oauth2/token cross-origin - the Console served from
# https://localhost:8090 (and https://thunderid:8090) and the Consent Portal
# (CONSENT_PORTAL_APP) from http://localhost:5173 - so their origins must be
# allowed here. This sets the writable layer (PUT /server-config/cors), which is
# DB-backed and read by the running server's dynamic CORS matcher.
configure_cors() {
    local CONSENT_PORTAL_ORIGIN="${CONSENT_PORTAL_URL:-http://localhost:5173}"
    local RESPONSE HTTP_CODE CORS_PAYLOAD
    read -r -d '' CORS_PAYLOAD <<JSON || true
{
    "allowedOrigins": [
        "${CONSENT_PORTAL_ORIGIN}",
        "https://localhost:${IDP_PORT}",
        "https://thunderid:${IDP_PORT}"
    ]
}
JSON
    RESPONSE=$(thunderid_api_call PUT "/server-config/cors" "$CORS_PAYLOAD")
    HTTP_CODE="${RESPONSE: -3}"
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "204" ]; then
        print_success "Configured CORS allowed origins (Console + Consent Portal)"
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
                "grantTypes": ["client_credentials", "refresh_token"],
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
                "grantTypes": ["authorization_code", "refresh_token"],
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
# No role/scope grant is needed on this app: the apisix routes below run in
# bearer_only + use_jwks mode, so its client_id/client_secret only satisfy the
# openid-connect plugin's config schema, not an actual token exchange.
print_info "Creating M2M application for API Gateway..."
GATEWAY_CLIENT_ID="ndx-api-gateway"
GATEWAY_CLIENT_SECRET="${GATEWAY_CLIENT_SECRET:-$(openssl rand -hex 16)}"
create_m2m_application "NDX_API_GATEWAY" "M2M client used by APISIX to validate bearer tokens" \
    "$GATEWAY_CLIENT_ID" "$GATEWAY_CLIENT_SECRET" "$DEFAULT_OU_ID"
CLIENT_ID="$GATEWAY_CLIENT_ID"
CLIENT_SECRET="$GATEWAY_CLIENT_SECRET"
print_info "API Gateway Client ID: $CLIENT_ID"
echo ""


# Register Orchestration Engine Routes
print_info "Exposing OE Endpoints Publicly with OpenID Connect Authentication"
curl --location --request PUT http://localhost:9180/apisix/admin/routes \
  --header "Content-Type: application/json" \
  --header "X-API-KEY: QuNGwapKysRvHfUtNkQFbUaGiiYeOcGo" \
  --data @- <<EOF
  {
    "uri": "/public/*",
    "methods": ["GET", "POST"],
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "orchestration-engine:4000": 1
      }
    },
    "plugins": {
      "openid-connect": {
        "discovery": "https://thunderid:${IDP_PORT}/.well-known/openid-configuration",
        "bearer_only": true,
        "token_signing_alg_values_expected": "RS256",
        "set_userinfo_header": true,
        "client_id": "$CLIENT_ID",
        "client_secret": "$CLIENT_SECRET",
        "use_jwks": true,
        "ssl_verify": false
      }
    },
    "id": "oe-endpoint"
  }
EOF

if [ $? -ne 0 ]; then
    print_error "Failed to register OE public routes"
    exit 1
fi

print_info "Exposing Required Consent Engine Endpoints Publicly with OpenID Connect Authentication"

curl --location --request PUT 'http://localhost:9180/apisix/admin/routes' \
--header 'Content-Type: application/json' \
--header 'X-API-KEY: QuNGwapKysRvHfUtNkQFbUaGiiYeOcGo' \
--data @- <<EOF
{
    "uri": "/api/v1/consents/*",
    "methods": [
        "GET",
        "PUT",
        "OPTIONS"
    ],
    "upstream": {
        "type": "roundrobin",
        "nodes": {
            "consent-engine:8081": 1
        }
    },
    "plugins": {
        "openid-connect": {
            "discovery": "https://thunderid:${IDP_PORT}/.well-known/openid-configuration",
            "bearer_only": true,
            "token_signing_alg_values_expected": "RS256",
            "set_userinfo_header": true,
            "client_id": "$CLIENT_ID",
            "client_secret": "$CLIENT_SECRET",
            "use_jwks": true,
            "ssl_verify": false,
            "access_token_in_authorization_header": true
        },
        "cors": {
            "allow_origins": "http://localhost:5173",
            "allow_headers": "*",
            "allow_methods": "GET,PUT,OPTIONS"
        }
    },
    "id": "consent-endpoint"
}
EOF



if [ $? -ne 0 ]; then
    print_error "Failed to register consent engine routes"
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
    "family_name": "Samaranayake"
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
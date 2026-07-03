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
WSO2IS_URL=${HOST_IP}:9444

WSO2_ADMIN_USERNAME="${WSO2_ADMIN_USERNAME:-admin}"
WSO2_ADMIN_PASSWORD="${WSO2_ADMIN_PASSWORD:-admin}"
WSO2_ADMIN_AUTH_HEADER=$(echo -n "$WSO2_ADMIN_USERNAME:$WSO2_ADMIN_PASSWORD" | base64)
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

print_info "Checking WSO2 Identity Server health..."

WSO2IS_HEALTH_CHECK_ATTEMPTS=30

for i in $(seq 1 $WSO2IS_HEALTH_CHECK_ATTEMPTS); do
    # Use curl with error handling - don't exit on failure
    if STATUS_CODE=$(curl -o /dev/null -s -w "%{http_code}" --connect-timeout 5 --max-time 10 --insecure \
        https://"$WSO2IS_URL"/console 2>/dev/null); then

        if [ "$STATUS_CODE" = "200" ] || [ "$STATUS_CODE" = "302" ]; then
            print_success "WSO2 Identity Server is ready (HTTP $STATUS_CODE)"
            break
        else
            print_info "WSO2 IS responded with HTTP $STATUS_CODE, retrying... ($i/$WSO2IS_HEALTH_CHECK_ATTEMPTS)"
        fi
    else
        print_info "WSO2 IS not reachable yet, retrying... ($i/$WSO2IS_HEALTH_CHECK_ATTEMPTS)"
    fi

    if [ "$i" -eq $WSO2IS_HEALTH_CHECK_ATTEMPTS ]; then
        print_error "WSO2 Identity Server health check failed after $WSO2IS_HEALTH_CHECK_ATTEMPTS attempts"
        print_error "Please check if WSO2 IS container is running properly:"
        print_error "  docker-compose -f $NDX_DIR/docker-compose.yml logs wso2is"
        print_error ""
        print_error "The script will now exit. Please resolve the issue and try again."
        exit 1
    fi

    sleep 3
done

# Step 1: Create initial DCR application to obtain credentials for Management API access
print_info "Creating temporary DCR application for Management API access..."
DCR_RESPONSE=$(curl --silent -X POST https://"$WSO2IS_URL"/api/identity/oauth2/dcr/v1.1/register \
  --insecure \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic $WSO2_ADMIN_AUTH_HEADER" \
  -d '{
    "client_name": "TEMPORARY_DCR_APP",
    "grant_types": ["client_credentials"],
    "token_type": "OAUTH",
    "scope": "internal_application_mgt_view internal_application_mgt_create internal_application_mgt_update internal_application_mgt_delete"
  }')

CURL_EXIT_CODE=$?

if [ $CURL_EXIT_CODE -ne 0 ]; then
    print_error "Failed to create temporary DCR application (curl exit code: $CURL_EXIT_CODE)"
    exit 1
fi

DCR_CLIENT_ID=$(echo "$DCR_RESPONSE" | jq -r '.client_id')
DCR_CLIENT_SECRET=$(echo "$DCR_RESPONSE" | jq -r '.client_secret')

if [ "$DCR_CLIENT_ID" = "null" ] || [ -z "$DCR_CLIENT_ID" ]; then
    print_error "Failed to extract Client ID from DCR response"
    print_error "Response was: $DCR_RESPONSE"
    exit 1
fi

print_success "Temporary DCR application created successfully!"
print_info "Temporary Client ID: $DCR_CLIENT_ID"
echo ""

# Get the ApplicationId, use the endpoint to search for the created application.
APPLICATION_RESPONSE=$(curl --silent -X GET "https://$WSO2IS_URL/api/server/v1/applications?filter=clientId+eq+$DCR_CLIENT_ID" \
  --insecure \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic $WSO2_ADMIN_AUTH_HEADER"
)

DCR_APPLICATION_ID=$(echo "$APPLICATION_RESPONSE" | jq -r '.applications[0].id')

if [ "$DCR_APPLICATION_ID" = "null" ] || [ -z "$DCR_APPLICATION_ID" ]; then
    print_error "Failed to extract Client ID from DCR response"
    print_error "Response was: $APPLICATION_RESPONSE"
    exit 1
fi

print_success "Successfully Obtained Application Id of TEMPORARY_DCR_APP"
print_info "TEMPORARY_DCR_APP Application ID: $DCR_APPLICATION_ID"
echo ""

# Fetch the id of the Application Authorization category
APPLICATION_RESOURCE_RESPONSE=$(curl --silent -X GET "https://${WSO2IS_URL}/api/server/v1/api-resources?filter=identifier+eq+%2Fapi%2Fserver%2Fv1%2Fapplications" \
  --insecure \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic $WSO2_ADMIN_AUTH_HEADER"
)

APPLICATION_MANAGEMENT_RESOURCE_ID=$(echo "$APPLICATION_RESOURCE_RESPONSE" | jq -r '.apiResources[0].id')

if [ "$APPLICATION_MANAGEMENT_RESOURCE_ID" = "null" ] || [ -z "$APPLICATION_MANAGEMENT_RESOURCE_ID" ]; then
    print_error "Failed to extract Application Resource ID From Response"
    print_error "Response was: $APPLICATION_RESPONSE"
    exit 1
fi

print_info "Granting application management permissions to temporary app..."

HTTP_STATUS=$(curl --silent -o /dev/null -w "%{http_code}" -X POST "https://${WSO2IS_URL}/api/server/v1/applications/$DCR_APPLICATION_ID/authorized-apis" \
  --insecure \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic $WSO2_ADMIN_AUTH_HEADER" \
  -d '{
    "id": "'"$APPLICATION_MANAGEMENT_RESOURCE_ID"'",
    "policyIdentifier": "RBAC",
    "scopes": [
      "internal_application_mgt_create",
      "internal_application_mgt_update",
      "internal_application_mgt_view",
      "internal_application_mgt_delete",
      "internal_application_mgt_client_secret_create",
      "internal_application_internal_api_update",
      "internal_application_business_api_update",
      "internal_application_mgt_client_secret_view"
    ]
  }'
)

if [ "$HTTP_STATUS" != "201" ] && [ "$HTTP_STATUS" != "200" ]; then
    print_error "Failed to grant application management permissions (HTTP $HTTP_STATUS)"
    exit 1
fi
print_success "Granted application management permissions to temporary app."

# Enabling SCIM2 USER CREATION ACCESS FOR THE TEMPORARY DCR APP
USER_MANAGEMENT_RESOURCE_RESPONSE=$(curl --silent -X GET "https://${WSO2IS_URL}/api/server/v1/api-resources?filter=identifier+eq+%2Fscim2%2FUsers" \
  --insecure \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic $WSO2_ADMIN_AUTH_HEADER"
)

USER_MANAGEMENT_RESOURCE_ID=$(echo "$USER_MANAGEMENT_RESOURCE_RESPONSE" | jq -r '.apiResources[0].id')

if [ "$USER_MANAGEMENT_RESOURCE_ID" = "null" ] || [ -z "$USER_MANAGEMENT_RESOURCE_ID" ]; then
    print_error "Failed to extract User Management Resource ID From Response"
    print_error "Response was: $USER_MANAGEMENT_RESOURCE_RESPONSE"
    exit 1
fi

USER_AUTHORIZATION_RESPONSE=$(curl --silent -X POST "https://${WSO2IS_URL}/api/server/v1/applications/$DCR_APPLICATION_ID/authorized-apis" \
  --insecure \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic $WSO2_ADMIN_AUTH_HEADER" \
  -d '{
    "id": "'"$USER_MANAGEMENT_RESOURCE_ID"'",
    "policyIdentifier": "RBAC",
    "scopes": [
      "internal_user_mgt_create"
    ]
  }'
)

echo "$USER_AUTHORIZATION_RESPONSE"

# Step 2: Create API Gateway application using DCR endpoint
print_info "Creating M2M application for API Gateway using DCR endpoint..."
GATEWAY_DCR_RESPONSE=$(curl --silent -X POST https://${WSO2IS_URL}/api/identity/oauth2/dcr/v1.1/register \
  --insecure \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic $WSO2_ADMIN_AUTH_HEADER" \
  -d '{
    "client_name": "NDX_API_GATEWAY",
    "grant_types": ["client_credentials", "refresh_token"],
    "token_type": "OAUTH"
  }')

CLIENT_ID=$(echo "$GATEWAY_DCR_RESPONSE" | jq -r '.client_id')
CLIENT_SECRET=$(echo "$GATEWAY_DCR_RESPONSE" | jq -r '.client_secret')

if [ "$CLIENT_ID" = "null" ] || [ -z "$CLIENT_ID" ]; then
    print_error "Failed to create API Gateway application via DCR"
    print_error "Response was: $GATEWAY_DCR_RESPONSE"
    exit 1
fi

print_success "API Gateway application created successfully via DCR!"
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
        "discovery": "https://wso2is:9444/oauth2/token/.well-known/openid-configuration",
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
            "discovery": "https://wso2is:9444/oauth2/token/.well-known/openid-configuration",
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


print_info "Obtaining Access token for performing application operations"
# First, obtain a new access token with the updated permissions
TOKEN_RESPONSE=$(curl --silent -X POST https://"$WSO2IS_URL"/oauth2/token \
  --insecure \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "$DCR_CLIENT_ID:$DCR_CLIENT_SECRET" \
  -d "grant_type=client_credentials&scope=internal_application_mgt_view internal_application_mgt_create internal_application_mgt_update internal_application_mgt_client_secret_view internal_user_mgt_create")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
    print_error "Failed to obtain access token with updated permissions"
    print_error "Response was: $TOKEN_RESPONSE"
    exit 1
fi

print_success "Access token obtained successfully!"
echo ""

# Create M2M Application using Management API
print_info "Creating M2M application (Passport Application) using Management API..."

M2M_APP_RESPONSE=$(curl --silent --insecure -i \
  -X POST https://"$WSO2IS_URL"/api/server/v1/applications \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d @- <<EOF
{
  "name": "Passport Application",
  "templateId": "m2m-application",
  "associatedRoles": {
    "allowedAudience": "APPLICATION",
    "roles": []
  },
  "inboundProtocolConfiguration": {
    "oidc": {
      "grantTypes": ["client_credentials"],
      "accessToken": {
        "accessTokenAttributes": [],
        "applicationAccessTokenExpiryInSeconds": 3600,
        "revokeTokensWhenIDPSessionTerminated": false,
        "type": "JWT",
        "userAccessTokenExpiryInSeconds": 0,
        "validateTokenBinding": false
      }
    }
  }
}
EOF
)

M2M_HTTP_STATUS=$(echo "$M2M_APP_RESPONSE" | grep "HTTP/" | head -1 | awk '{print $2}')
M2M_LOCATION=$(echo "$M2M_APP_RESPONSE" | grep -i "^location:" | cut -d: -f2- | tr -d '\r' | xargs)
M2M_APP_BODY=$(echo "$M2M_APP_RESPONSE" | sed -n '/^{/,/^}/p')

if [ "$M2M_HTTP_STATUS" != "201" ]; then
    print_error "Failed to create M2M application via Management API (HTTP $M2M_HTTP_STATUS)"
    print_error "Response: $M2M_APP_BODY"
    exit 1
fi

# Extract application ID from Location header
# Location format: https://${WSO2IS_URL}/api/server/v1/applications/{app-id}
M2M_APP_ID=$(echo "$M2M_LOCATION" | sed 's|.*/applications/||')

if [ -z "$M2M_APP_ID" ]; then
    print_error "Failed to extract application ID from Location header"
    print_error "Location header was: $M2M_LOCATION"
    exit 1
fi

# Retrieve the full application details to get client ID and secret
print_info "Retrieving M2M application credentials..."
M2M_DETAILS_RESPONSE=$(curl --silent -w "\nHTTP_STATUS:%{http_code}" -X GET "https://$WSO2IS_URL/api/server/v1/applications/$M2M_APP_ID/inbound-protocols/oidc" \
  --insecure \
  -H "Authorization: Bearer $ACCESS_TOKEN")

M2M_DETAILS_HTTP_STATUS=$(echo "$M2M_DETAILS_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
M2M_DETAILS_BODY=$(echo "$M2M_DETAILS_RESPONSE" | sed '/HTTP_STATUS:/d')

# Print the body for debugging
print_info "M2M Application Details Response (HTTP $M2M_DETAILS_HTTP_STATUS):"
echo "$M2M_DETAILS_BODY"

if [ "$M2M_DETAILS_HTTP_STATUS" != "200" ]; then
    print_error "Failed to retrieve M2M application details (HTTP $M2M_DETAILS_HTTP_STATUS)"
    exit 1
fi

M2M_CLIENT_ID=$(echo "$M2M_DETAILS_BODY" | jq -r '.clientId')
M2M_CLIENT_SECRET=$(echo "$M2M_DETAILS_BODY" | jq -r '.clientSecret')

if [ "$M2M_CLIENT_ID" = "null" ] || [ -z "$M2M_CLIENT_ID" ]; then
    print_error "Failed to extract M2M Client ID from application details"
    print_error "Response: $M2M_DETAILS_BODY"
    exit 1
fi

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

# Define the Consent Portal client ID
PORTAL_CLIENT_ID="Mpjt5VUqDPL8iVByyFcMDregz6Ea"

# Now attempt to create the Consent Portal SPA application using the Management API
print_info "Creating SPA application for Consent Portal using Management API..."

# Create the Consent Portal SPA application with predefined client_id
print_info "Creating Consent Portal application with client ID: $PORTAL_CLIENT_ID"

PORTAL_APP_RESPONSE=$(curl --silent -w "\nHTTP_STATUS:%{http_code}" -X POST https://"${WSO2IS_URL}"/api/server/v1/applications \
  --insecure \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d @- <<EOF
{
  "name": "NDX_CONSENT_PORTAL",
  "templateId": "6a90e4b0-fbff-42d7-bfde-1efd98f07cd7",
  "description": "Single-Page Application for NDX Consent Portal",
  "inboundProtocolConfiguration": {
    "oidc": {
      "clientId": "$PORTAL_CLIENT_ID",
      "grantTypes": ["authorization_code", "refresh_token"],
      "callbackURLs": ["http://localhost:5173"],
      "allowedOrigins": ["http://localhost:5173"],
      "publicClient": true,
      "pkce": {
        "mandatory": true,
        "supportPlainTransformAlgorithm": false
      },
      "accessToken": {
        "type": "JWT",
        "userAccessTokenExpiryInSeconds": 3600,
        "applicationAccessTokenExpiryInSeconds": 3600,
        "accessTokenAttributes": [
          "email"
        ]
      },
      "refreshToken": {
        "expiryInSeconds": 86400,
        "renewRefreshToken": true
      },
      "idToken": {
        "expiryInSeconds": 3600
      }
    }
  }
}
EOF
)

HTTP_STATUS=$(echo "$PORTAL_APP_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
PORTAL_APP_BODY=$(echo "$PORTAL_APP_RESPONSE" | sed '/HTTP_STATUS:/d')

print_info "Consent Portal Application Creation Response (HTTP $HTTP_STATUS):"
echo "$PORTAL_APP_BODY"

if [ "$HTTP_STATUS" != "201" ]; then
    print_error "Failed to create Consent Portal application via Management API (HTTP $HTTP_STATUS)"
    print_error "Response: $PORTAL_APP_BODY"
    exit 1
fi

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

# Create a mock user using SCIM2 API
print_info "Creating mock user via SCIM2 API..."
SCIM_USER_RESPONSE=$(
  curl --silent -X POST https://"$WSO2IS_URL"/scim2/Users \
    --insecure \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -d @- <<EOF
{
  "schemas": ["urn:ietf:params:scim:schemas:core:2.0:User"],
  "userName": "nayana",
  "name": {
    "givenName": "Nayana",
    "familyName": "Samaranayake"
  },
  "emails": [
    {
      "value": "nayana@opensource.lk",
      "primary": true
    }
  ],
  "password": "${MOCK_USER_PASSWORD:-Abc12#45}",
  "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User": {
    "employeeNumber": "EMP001"
  }
}
EOF
)

SCIM_USER_ID=$(echo "$SCIM_USER_RESPONSE" | jq -r '.id')

if [ "$SCIM_USER_ID" = "null" ] || [ -z "$SCIM_USER_ID" ]; then
    print_warning "Failed to create user via SCIM2 API (user may already exist)"
    print_info "Response: $SCIM_USER_RESPONSE"
else
    print_success "Mock user created successfully via SCIM2 API!"
    print_info "User ID: $SCIM_USER_ID"
    print_info "Username: nayana@opensource.lk"
    print_info "Password: Abc12#45"
fi
echo ""

# Delete the temporary DCR application now that setup is complete
if [ -n "$DCR_CLIENT_ID" ]; then
    print_info "Deleting temporary DCR application..."
    DELETE_STATUS=$(curl --silent -o /dev/null -w "%{http_code}" -X DELETE "https://${WSO2IS_URL}/api/identity/oauth2/dcr/v1.1/register/$DCR_CLIENT_ID" \
      --insecure \
      -H "Authorization: Basic $WSO2_ADMIN_AUTH_HEADER")
    if [ "$DELETE_STATUS" = "204" ]; then
        print_success "Temporary DCR application deleted successfully"
        print_info "  Client ID: $DCR_CLIENT_ID"
    else
        print_warning "Failed to delete temporary DCR application (HTTP status: $DELETE_STATUS)"
        print_info "  Client ID: $DCR_CLIENT_ID"
        print_info "  You can delete it manually: DELETE https://$WSO2IS_URL/api/identity/oauth2/dcr/v1.1/register/$DCR_CLIENT_ID"
    fi
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
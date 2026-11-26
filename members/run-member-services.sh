#!/bin/bash

# Script to pull and run the Identity Registry, Identity Registry Adapter and
# Civil Registry data source services and the passport app using Docker
# Usage: ./run-member-services.sh [identity-registry|identity-registry-adapter|civil-registry|passport-app|all|build|build-run|stop|status|help]

set -e

# Track started containers for cleanup
STARTED_CONTAINERS=()

# Cleanup function to stop containers on script interruption
cleanup_on_interrupt() {
    local exit_code=$?
    if [ ${#STARTED_CONTAINERS[@]} -gt 0 ]; then
        echo ""
        print_warning "Script interrupted. Stopping containers started by this script..."
        for container in "${STARTED_CONTAINERS[@]}"; do
            if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
                print_step "Stopping container: $container"
                docker stop "$container" &> /dev/null || true
                docker rm "$container" &> /dev/null || true
            fi
        done
        print_success "Cleanup complete"
    fi
    exit $exit_code
}

# Set up trap to catch script interruption only (not normal exit)
trap cleanup_on_interrupt INT TERM

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IDENTITY_REGISTRY_DIR="${SCRIPT_DIR}/identity-registry/data-sources/identity-registry-api"
IDENTITY_REGISTRY_ADAPTER_DIR="${SCRIPT_DIR}/identity-registry/data-sources/identity-registry-adapter"
CIVIL_REGISTRY_DIR="${SCRIPT_DIR}/civil-registry/data-sources/civil-registry-api"
PASSPORT_APP_DIR="${SCRIPT_DIR}/immigration/applications/online-passport-app"

# setting NAME default: from the environment, then ndx/.env, then the default.
. "${SCRIPT_DIR}/../scripts/settings.sh"

# Member images. Each service runs its image published to ghcr.io/openndx (for
# linux/amd64 and linux/arm64, by .github/workflows/release-images.yml) unless
# its *_BUILD_LOCAL setting is true, which builds the image from this checkout
# instead. Set these in ndx/.env or the environment.
setting IDENTITY_REGISTRY_IMAGE ghcr.io/openndx/identity-registry-api:v0.1.0
setting IDENTITY_REGISTRY_ADAPTER_IMAGE ghcr.io/openndx/identity-registry-adapter:v0.1.0
setting CIVIL_REGISTRY_IMAGE ghcr.io/openndx/civil-registry-api:v0.1.0
setting PASSPORT_APP_IMAGE ghcr.io/openndx/online-passport-app:v0.1.1
setting IDENTITY_REGISTRY_BUILD_LOCAL false
setting IDENTITY_REGISTRY_ADAPTER_BUILD_LOCAL false
setting CIVIL_REGISTRY_BUILD_LOCAL false
setting PASSPORT_APP_BUILD_LOCAL false
BUILD_LOCAL_SETTINGS="IDENTITY_REGISTRY_BUILD_LOCAL IDENTITY_REGISTRY_ADAPTER_BUILD_LOCAL CIVIL_REGISTRY_BUILD_LOCAL PASSPORT_APP_BUILD_LOCAL"

# Images built from this checkout get a local tag, so a local build never
# replaces a published image in Docker's image cache.
IDENTITY_REGISTRY_LOCAL_IMAGE="farajaland/identity-registry-api:local"
IDENTITY_REGISTRY_ADAPTER_LOCAL_IMAGE="farajaland/identity-registry-adapter:local"
CIVIL_REGISTRY_LOCAL_IMAGE="farajaland/civil-registry-api:local"
PASSPORT_APP_LOCAL_IMAGE="farajaland/online-passport-app:local"

# Container names
IDENTITY_REGISTRY_CONTAINER="identity-registry-api"
IDENTITY_REGISTRY_ADAPTER_CONTAINER="identity-registry-adapter"
CIVIL_REGISTRY_CONTAINER="civil-registry-api"
PASSPORT_APP_CONTAINER="online-passport-app"

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

print_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# Function to check if Docker is installed and running
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker to use this script."
        print_info "Visit: https://docs.docker.com/get-docker/"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running. Please start Docker and try again."
        exit 1
    fi

    print_success "Docker is installed and running"
}

# Function to stop and remove a container if it exists
cleanup_container() {
    local container_name=$1
    if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        print_step "Stopping and removing existing container: $container_name"
        docker stop "$container_name" &> /dev/null || true
        docker rm "$container_name" &> /dev/null || true
        print_success "Container removed: $container_name"
    fi
}

# Function to pull Docker image
pull_image() {
    local image=$1
    print_step "Pulling Docker image: $image"
    if docker pull "$image"; then
        print_success "Image pulled successfully: $image"
        return 0
    else
        print_error "Failed to pull image: $image"
        return 1
    fi
}

# Function to build Docker image locally
build_image() {
    local service_name=$1
    local service_dir=$2
    local image_name=$3

    print_step "Building Docker image for $service_name..."

    if [ ! -d "$service_dir" ]; then
        print_error "Service directory not found: $service_dir"
        return 1
    fi

    if [ ! -f "$service_dir/Dockerfile" ]; then
        print_error "Dockerfile not found in: $service_dir"
        return 1
    fi

    cd "$service_dir"

    # Build Docker image. The Ballerina services' Dockerfiles compile the
    # project inside Docker, so no local Ballerina install is needed.
    docker build -t "$image_name" . || {
        print_error "Docker build failed for $service_name"
        return 1
    }

    cd "$SCRIPT_DIR"
    print_success "Image built successfully: $image_name"
    return 0
}

# Gets the image a service runs and stores it in PREPARED_IMAGE: builds it from
# this checkout when the service's *_BUILD_LOCAL setting is true, otherwise pulls
# the published image, falling back to a copy already in Docker's image cache.
# Usage: prepare_image <label> <dir> <published image> <local image> <setting name>
prepare_image() {
    local label=$1 dir=$2 published=$3 local_image=$4 setting_name=$5
    if [ "${!setting_name}" = true ]; then
        build_image "$label" "$dir" "$local_image" || return 1
        PREPARED_IMAGE=$local_image
        return 0
    fi
    if ! pull_image "$published"; then
        print_warning "Failed to pull image. Checking if local image exists..."
        if ! docker image inspect "$published" &> /dev/null; then
            print_error "Image not found locally or in registry: $published"
            print_info "Set ${setting_name}=true in ndx/.env to build it from this checkout"
            return 1
        fi
    fi
    PREPARED_IMAGE=$published
}

# Exits if a *_BUILD_LOCAL setting is anything other than true or false.
check_settings() {
    local name
    for name in $BUILD_LOCAL_SETTINGS; do
        case "${!name}" in
            true|false) ;;
            *)
                print_error "$name must be true or false, not '${!name}' (set in ndx/.env or the environment)"
                exit 1
                ;;
        esac
    done
}

# Function to run the Identity Registry API service
run_identity_registry() {
    print_info "Starting Identity Registry API service..."

    cleanup_container "$IDENTITY_REGISTRY_CONTAINER"

    prepare_image "Identity Registry API" "$IDENTITY_REGISTRY_DIR" "$IDENTITY_REGISTRY_IMAGE" "$IDENTITY_REGISTRY_LOCAL_IMAGE" IDENTITY_REGISTRY_BUILD_LOCAL

    print_step "Starting Identity Registry API container..."
    # MSYS_NO_PATHCONV avoids Git Bash mangling the -v host:container:mode volume spec on Windows.
    MSYS_NO_PATHCONV=1 docker run -d \
        --name "$IDENTITY_REGISTRY_CONTAINER" \
        -p 9090:9090 \
        -v "${IDENTITY_REGISTRY_DIR}/Config.toml:/home/ballerina/Config.toml:ro" \
        -v "${IDENTITY_REGISTRY_DIR}/mock_data.json:/home/ballerina/mock_data.json:ro" \
        --restart unless-stopped \
        "$PREPARED_IMAGE"

    STARTED_CONTAINERS+=("$IDENTITY_REGISTRY_CONTAINER")
    print_success "Identity Registry API started at http://localhost:9090"
    print_info "Container name: $IDENTITY_REGISTRY_CONTAINER"
}

# Function to run Identity Registry Adapter service
run_identity_registry_adapter() {
    print_info "Starting Identity Registry Adapter service..."

    cleanup_container "$IDENTITY_REGISTRY_ADAPTER_CONTAINER"

    prepare_image "Identity Registry Adapter" "$IDENTITY_REGISTRY_ADAPTER_DIR" "$IDENTITY_REGISTRY_ADAPTER_IMAGE" "$IDENTITY_REGISTRY_ADAPTER_LOCAL_IMAGE" IDENTITY_REGISTRY_ADAPTER_BUILD_LOCAL

    print_step "Starting Identity Registry Adapter container..."
    docker run -d \
        --name "$IDENTITY_REGISTRY_ADAPTER_CONTAINER" \
        -p 9091:9091 \
        -e "BAL_CONFIG_VAR_SERVICEURL=http://host.docker.internal:9090" \
        -e "BAL_CONFIG_VAR_CHOREOAPIKEY=your-api-key" \
        -e "BAL_CONFIG_VAR_PORT=9091" \
        --restart unless-stopped \
        "$PREPARED_IMAGE"

    STARTED_CONTAINERS+=("$IDENTITY_REGISTRY_ADAPTER_CONTAINER")
    print_success "Identity Registry Adapter started at http://localhost:9091"
    print_info "GraphQL endpoint: http://localhost:9091/"
    print_info "Container name: $IDENTITY_REGISTRY_ADAPTER_CONTAINER"
}

# Function to run the Civil Registry API service
run_civil_registry() {
    print_info "Starting Civil Registry API service..."

    cleanup_container "$CIVIL_REGISTRY_CONTAINER"

    prepare_image "Civil Registry API" "$CIVIL_REGISTRY_DIR" "$CIVIL_REGISTRY_IMAGE" "$CIVIL_REGISTRY_LOCAL_IMAGE" CIVIL_REGISTRY_BUILD_LOCAL

    print_step "Starting Civil Registry API container..."
    # MSYS_NO_PATHCONV avoids Git Bash mangling the -v host:container:mode volume spec on Windows.
    MSYS_NO_PATHCONV=1 docker run -d \
        --name "$CIVIL_REGISTRY_CONTAINER" \
        -p 8080:8080 \
        -v "${CIVIL_REGISTRY_DIR}/mock_data.json:/app/mock_data.json:ro" \
        --restart unless-stopped \
        "$PREPARED_IMAGE"

    STARTED_CONTAINERS+=("$CIVIL_REGISTRY_CONTAINER")
    print_success "Civil Registry API started at http://localhost:8080"
    print_info "GraphQL endpoint: http://localhost:8080/graphql"
    print_info "API docs: http://localhost:8080/docs"
    print_info "Container name: $CIVIL_REGISTRY_CONTAINER"
}

# Function to run the passport app
run_passport_app() {
    print_info "Starting Online Passport App..."

    cleanup_container "$PASSPORT_APP_CONTAINER"

    prepare_image "Online Passport App" "$PASSPORT_APP_DIR" "$PASSPORT_APP_IMAGE" "$PASSPORT_APP_LOCAL_IMAGE" PASSPORT_APP_BUILD_LOCAL

    print_step "Starting Online Passport App container..."
    # This container is NOT on the exchange-network. Like any outside consumer it
    # uses only the exchange's public entry point, the gateway on 9081, for both
    # its token and its queries. It reaches the gateway via host.docker.internal
    # (the same host alias the orchestration engine uses for data sources in
    # ndx/config/openndx/oe.yaml); `localhost` here would mean the container itself.
    docker run -d \
        --name "$PASSPORT_APP_CONTAINER" \
        -p 3000:3000 \
        -e "CLIENT_ID=${M2M_CLIENT_ID}" \
        -e "CLIENT_SECRET=${M2M_CLIENT_SECRET}" \
        -e "NDX_GRAPHQL_API_URL=http://host.docker.internal:9081/public/graphql" \
        -e "TOKEN_URL=http://host.docker.internal:9081/oauth2/token" \
        -e "TOKEN_RESOURCE=http://api.openndx.local" \
        -e "TOKEN_SCOPE=getdata" \
        --add-host=host.docker.internal:host-gateway \
        --restart unless-stopped \
        "$PREPARED_IMAGE"

    STARTED_CONTAINERS+=("$PASSPORT_APP_CONTAINER")
    print_success "Online Passport App started at http://localhost:3000"
    print_info "Container name: $PASSPORT_APP_CONTAINER"
}

# Function to build all services locally
build_all() {
    print_info "Building all services locally..."

    local build_success=true

    # Build the Identity Registry API
    print_info "=== Building Identity Registry API ==="
    if ! build_image "Identity Registry API" "$IDENTITY_REGISTRY_DIR" "$IDENTITY_REGISTRY_LOCAL_IMAGE"; then
        build_success=false
        print_error "Failed to build Identity Registry API"
    fi

    # Build the Identity Registry Adapter
    print_info "=== Building Identity Registry Adapter ==="
    if ! build_image "Identity Registry Adapter" "$IDENTITY_REGISTRY_ADAPTER_DIR" "$IDENTITY_REGISTRY_ADAPTER_LOCAL_IMAGE"; then
        build_success=false
        print_error "Failed to build Identity Registry Adapter"
    fi

    # Build the Civil Registry API
    print_info "=== Building Civil Registry API ==="
    if ! build_image "Civil Registry API" "$CIVIL_REGISTRY_DIR" "$CIVIL_REGISTRY_LOCAL_IMAGE"; then
        build_success=false
        print_error "Failed to build Civil Registry API"
    fi

    # Build the passport app
    print_info "=== Building Online Passport App ==="
    if ! build_image "Online Passport App" "$PASSPORT_APP_DIR" "$PASSPORT_APP_LOCAL_IMAGE"; then
        build_success=false
        print_error "Failed to build Online Passport App"
    fi

    if [ "$build_success" = true ]; then
        print_success "All images built successfully!"
        print_info "Run them with: $0 build-run, or set the *_BUILD_LOCAL settings in ndx/.env to true"
    else
        print_error "Some builds failed. Please check the errors above."
        exit 1
    fi
}

# Function to run all services
run_all() {
    print_info "Starting all services..."
    print_warning "Services will run in Docker containers"

    # Run all services
    run_identity_registry
    sleep 2
    run_identity_registry_adapter
    sleep 2
    run_civil_registry
    sleep 2
    run_passport_app

    echo ""
    print_success "All services started successfully!"
    echo ""
    print_info "Service URLs:"
    print_info "  Identity Registry API:               http://localhost:9090"
    print_info "  Identity Registry Adapter (GraphQL): http://localhost:9091/"
    print_info "  Civil Registry API:                  http://localhost:8080"
    print_info "  Civil Registry GraphQL:              http://localhost:8080/graphql"
    print_info "  Civil Registry API Docs:             http://localhost:8080/docs"
    print_info "  Online Passport App:                 http://localhost:3000"
    echo ""
    print_info "To view logs:"
    print_info "  docker logs -f $IDENTITY_REGISTRY_CONTAINER"
    print_info "  docker logs -f $IDENTITY_REGISTRY_ADAPTER_CONTAINER"
    print_info "  docker logs -f $CIVIL_REGISTRY_CONTAINER"
    print_info "  docker logs -f $PASSPORT_APP_CONTAINER"
    echo ""
    print_info "To stop all services:"
    print_info "  docker stop $IDENTITY_REGISTRY_CONTAINER $IDENTITY_REGISTRY_ADAPTER_CONTAINER $CIVIL_REGISTRY_CONTAINER $PASSPORT_APP_CONTAINER"
}

# Function to stop all services
stop_all() {
    print_info "Stopping all services..."

    cleanup_container "$IDENTITY_REGISTRY_CONTAINER"
    cleanup_container "$IDENTITY_REGISTRY_ADAPTER_CONTAINER"
    cleanup_container "$CIVIL_REGISTRY_CONTAINER"
    cleanup_container "$PASSPORT_APP_CONTAINER"

    print_success "All services stopped"
}

# Function to show service status
show_status() {
    print_info "Service Status:"
    echo ""

    for container in "$IDENTITY_REGISTRY_CONTAINER" "$IDENTITY_REGISTRY_ADAPTER_CONTAINER" "$CIVIL_REGISTRY_CONTAINER" "$PASSPORT_APP_CONTAINER"; do
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            local uptime
            uptime=$(docker inspect -f '{{.State.StartedAt}}' "$container")
            print_success "$container: Running (since $uptime)"
        else
            print_warning "$container: Not running"
        fi
    done
}

# Function to display usage
show_usage() {
    cat << EOF
Usage: $0 [COMMAND]

Commands:
  identity-registry          Run only the Identity Registry API (port 9090)
  identity-registry-adapter  Run only the Identity Registry Adapter (GraphQL, port 9091)
  civil-registry             Run only the Civil Registry API (port 8080)
  passport-app               Run only the Online Passport App (port 3000)
  all                        Run all services (default)
  build                      Build all images from this checkout (tagged farajaland/<name>:local)
  build-run                  Build all images from this checkout and run them
  stop                       Stop all running services
  status                     Show status of all services
  help                       Show this help message

Settings (read from the environment, then ndx/.env):
  IDENTITY_REGISTRY_BUILD_LOCAL          true builds the Identity Registry API from this checkout; false pulls its image (default: false)
  IDENTITY_REGISTRY_ADAPTER_BUILD_LOCAL  Same for the Identity Registry Adapter (default: false)
  CIVIL_REGISTRY_BUILD_LOCAL             Same for the Civil Registry API (default: false)
  PASSPORT_APP_BUILD_LOCAL               Same for the passport app (default: false)
  IDENTITY_REGISTRY_IMAGE                Image pulled for the Identity Registry API (default: ghcr.io/openndx/identity-registry-api:v0.1.0)
  IDENTITY_REGISTRY_ADAPTER_IMAGE        Image pulled for the Identity Registry Adapter (default: ghcr.io/openndx/identity-registry-adapter:v0.1.0)
  CIVIL_REGISTRY_IMAGE                   Image pulled for the Civil Registry API (default: ghcr.io/openndx/civil-registry-api:v0.1.0)
  PASSPORT_APP_IMAGE                     Image pulled for the passport app (default: ghcr.io/openndx/online-passport-app:v0.1.1)

Examples:
  $0 identity-registry                      # Run only the Identity Registry API
  $0 all                                    # Run all services
  $0 build                                  # Build all images locally
  $0 build-run                              # Build and run all services
  $0 stop                                   # Stop all services
  PASSPORT_APP_BUILD_LOCAL=true $0 all      # Run all services, building only the passport app from this checkout
  CIVIL_REGISTRY_IMAGE=ghcr.io/openndx/civil-registry-api:v0.2.0 $0 civil-registry  # Run another version

Service Information:
  Identity Registry API:      Mock identity registry REST API (Ballerina)
  Identity Registry Adapter:  GraphQL adapter for the Identity Registry API (Ballerina)
  Civil Registry API:         Mock birth registration GraphQL API (Python/FastAPI)

Docker Images (pulled / built locally):
  Identity Registry API:      $IDENTITY_REGISTRY_IMAGE / $IDENTITY_REGISTRY_LOCAL_IMAGE
  Identity Registry Adapter:  $IDENTITY_REGISTRY_ADAPTER_IMAGE / $IDENTITY_REGISTRY_ADAPTER_LOCAL_IMAGE
  Civil Registry API:         $CIVIL_REGISTRY_IMAGE / $CIVIL_REGISTRY_LOCAL_IMAGE
  Passport App:               $PASSPORT_APP_IMAGE / $PASSPORT_APP_LOCAL_IMAGE

EOF
}

# Main script logic
main() {
    local command="${1:-all}"

    # Always check the settings and Docker first (except for help)
    if [ "$command" != "help" ] && [ "$command" != "-h" ] && [ "$command" != "--help" ]; then
        check_settings
        check_docker
    fi

    case "$command" in
        identity-registry)
            run_identity_registry
            ;;
        identity-registry-adapter)
            run_identity_registry_adapter
            ;;
        civil-registry)
            run_civil_registry
            ;;
        passport-app)
            run_passport_app
            ;;
        all)
            run_all
            ;;
        build)
            build_all
            ;;
        build-run)
            # Build every service from this checkout as it starts. prepare_image
            # reads these settings by name, which shellcheck cannot follow.
            # shellcheck disable=SC2034
            {
                IDENTITY_REGISTRY_BUILD_LOCAL=true
                IDENTITY_REGISTRY_ADAPTER_BUILD_LOCAL=true
                CIVIL_REGISTRY_BUILD_LOCAL=true
                PASSPORT_APP_BUILD_LOCAL=true
            }
            run_all
            ;;
        stop)
            stop_all
            ;;
        status)
            show_status
            ;;
        -h|--help|help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown command: $command"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"

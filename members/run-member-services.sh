#!/bin/bash

# Script to pull and run DRP, DRP Adapter, and RGD data source services using Docker
# Usage: ./run-member-services.sh [drp|adapter|rgd|all|build]

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

# Docker image configuration
DOCKER_REGISTRY="${DOCKER_REGISTRY:-docker.io}"
IMAGE_PREFIX="${IMAGE_PREFIX:-mushrafmim}"
# Member data-source services (DRP, DRP Adapter, RGD) are published as v0.1.0.
IMAGE_TAG="${IMAGE_TAG:-v0.1.0}"
# The passport app is still published under 'latest'; keep it on its own tag.
DIE_IMAGE_TAG="${DIE_IMAGE_TAG:-latest}"

# Image names
DRP_IMAGE="${DOCKER_REGISTRY}/${IMAGE_PREFIX}/drp-api:${IMAGE_TAG}"
DRP_ADAPTER_IMAGE="${DOCKER_REGISTRY}/${IMAGE_PREFIX}/drp-api-adapter:${IMAGE_TAG}"
RGD_IMAGE="${DOCKER_REGISTRY}/${IMAGE_PREFIX}/rgd-api:${IMAGE_TAG}"
DIE_IMAGE="${DOCKER_REGISTRY}/${IMAGE_PREFIX}/online-passport-app:${DIE_IMAGE_TAG}"

# Container names
DRP_CONTAINER="drp-api"
DRP_ADAPTER_CONTAINER="drp-adapter"
RGD_CONTAINER="rgd-api"
DIE_CONTAINER="online-passport-app"

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRP_DIR="${SCRIPT_DIR}/drp/data-sources/drp-api"
DRP_ADAPTER_DIR="${SCRIPT_DIR}/drp/data-sources/drp-api-adapter"
RGD_DIR="${SCRIPT_DIR}/rgd/data-sources/rgd-api"
DIE_DIR="${SCRIPT_DIR}/die/applications/online-passport-app"

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

    # Special handling for Ballerina services
    if [ -f "Ballerina.toml" ]; then
        print_info "Building Ballerina project first..."
        if command -v bal &> /dev/null; then
            bal build --cloud=docker || {
                print_error "Ballerina build failed"
                return 1
            }
        else
            print_error "Ballerina is not installed. Cannot build Ballerina service."
            print_info "Visit: https://ballerina.io/downloads/"
            return 1
        fi
    fi

    # Build Docker image
    docker build -t "$image_name" . || {
        print_error "Docker build failed for $service_name"
        return 1
    }

    cd "$SCRIPT_DIR"
    print_success "Image built successfully: $image_name"
    return 0
}

# Function to run DRP service
run_drp() {
    local skip_pull=${1:-false}

    print_info "Starting DRP API service..."

    cleanup_container "$DRP_CONTAINER"

    if [ "$skip_pull" = false ]; then
        if ! pull_image "$DRP_IMAGE"; then
            print_warning "Failed to pull image. Checking if local image exists..."
            if ! docker image inspect "$DRP_IMAGE" &> /dev/null; then
                print_error "Image not found locally or in registry: $DRP_IMAGE"
                print_info "Try running with 'build' command to build images locally"
                return 1
            fi
        fi
    fi

    print_step "Starting DRP API container..."
    # MSYS_NO_PATHCONV avoids Git Bash mangling the -v host:container:mode volume spec on Windows.
    MSYS_NO_PATHCONV=1 docker run -d \
        --name "$DRP_CONTAINER" \
        -p 9090:9090 \
        -v "${DRP_DIR}/Config.toml:/home/ballerina/Config.toml:ro" \
        -v "${DRP_DIR}/mock_data.json:/home/ballerina/mock_data.json:ro" \
        --restart unless-stopped \
        "$DRP_IMAGE"

    STARTED_CONTAINERS+=("$DRP_CONTAINER")
    print_success "DRP API started at http://localhost:9090"
    print_info "Container name: $DRP_CONTAINER"
}

# Function to run DRP Adapter service
run_drp_adapter() {
    local skip_pull=${1:-false}

    print_info "Starting DRP API Adapter service..."

    cleanup_container "$DRP_ADAPTER_CONTAINER"

    if [ "$skip_pull" = false ]; then
        if ! pull_image "$DRP_ADAPTER_IMAGE"; then
            print_warning "Failed to pull image. Checking if local image exists..."
            if ! docker image inspect "$DRP_ADAPTER_IMAGE" &> /dev/null; then
                print_error "Image not found locally or in registry: $DRP_ADAPTER_IMAGE"
                print_info "Try running with 'build' command to build images locally"
                return 1
            fi
        fi
    fi

    print_step "Starting DRP API Adapter container..."
    docker run -d \
        --name "$DRP_ADAPTER_CONTAINER" \
        -p 9091:9091 \
        -e "CHOREO_MOCK_DRP_CONNECTION_SERVICEURL=http://host.docker.internal:9090" \
        -e "CHOREO_MOCK_DRP_CONNECTION_APIKEY=your-api-key" \
        -e "PORT=9091" \
        --restart unless-stopped \
        "$DRP_ADAPTER_IMAGE"

    STARTED_CONTAINERS+=("$DRP_ADAPTER_CONTAINER")
    print_success "DRP API Adapter started at http://localhost:9091"
    print_info "GraphQL endpoint: http://localhost:9091/graphql"
    print_info "Container name: $DRP_ADAPTER_CONTAINER"
}

# Function to run RGD service
run_rgd() {
    local skip_pull=${1:-false}

    print_info "Starting RGD API service..."

    cleanup_container "$RGD_CONTAINER"

    if [ "$skip_pull" = false ]; then
        if ! pull_image "$RGD_IMAGE"; then
            print_warning "Failed to pull image. Checking if local image exists..."
            if ! docker image inspect "$RGD_IMAGE" &> /dev/null; then
                print_error "Image not found locally or in registry: $RGD_IMAGE"
                print_info "Try running with 'build' command to build images locally"
                return 1
            fi
        fi
    fi

    print_step "Starting RGD API container..."
    # MSYS_NO_PATHCONV avoids Git Bash mangling the -v host:container:mode volume spec on Windows.
    MSYS_NO_PATHCONV=1 docker run -d \
        --name "$RGD_CONTAINER" \
        -p 8080:8080 \
        -v "${RGD_DIR}/mock_data.json:/app/mock_data.json:ro" \
        --restart unless-stopped \
        "$RGD_IMAGE"

    STARTED_CONTAINERS+=("$RGD_CONTAINER")
    print_success "RGD API started at http://localhost:8080"
    print_info "GraphQL endpoint: http://localhost:8080/graphql"
    print_info "API docs: http://localhost:8080/docs"
    print_info "Container name: $RGD_CONTAINER"
}

# Function to run DIE service
run_die() {
    local skip_pull=${1:-false}

    print_info "Starting Online Passport App (DIE)..."

    cleanup_container "$DIE_CONTAINER"

    if [ "$skip_pull" = false ]; then
        if ! pull_image "$DIE_IMAGE"; then
            print_warning "Failed to pull image. Checking if local image exists..."
            if ! docker image inspect "$DIE_IMAGE" &> /dev/null; then
                print_error "Image not found locally or in registry: $DIE_IMAGE"
                print_info "Try running with 'build' command to build images locally"
                return 1
            fi
        fi
    fi

    print_step "Starting Online Passport App container..."
    # This container is NOT on the exchange-network, so it reaches the published
    # NDX ports via host.docker.internal (the same host alias the orchestration
    # engine uses for data sources in ndx/fl-config.json). `localhost` here would
    # mean the container itself, and we no longer detect a host IP.
    docker run -d \
        --name "$DIE_CONTAINER" \
        -p 3000:3000 \
        -e "CLIENT_ID=${M2M_CLIENT_ID}" \
        -e "CLIENT_SECRET=${M2M_CLIENT_SECRET}" \
        -e "NDX_GRAPHQL_API_URL=http://host.docker.internal:9081/public/graphql" \
        -e "TOKEN_URL=https://host.docker.internal:${IDP_PORT:-8090}/oauth2/token" \
        --add-host=host.docker.internal:host-gateway \
        --restart unless-stopped \
        "$DIE_IMAGE"

    STARTED_CONTAINERS+=("$DIE_CONTAINER")
    print_success "Online Passport App started at http://localhost:3000"
    print_info "Container name: $DIE_CONTAINER"
}

# Function to build all services locally
build_all() {
    print_info "Building all services locally..."

    local build_success=true

    # Build DRP
    print_info "=== Building DRP API ==="
    if ! build_image "DRP API" "$DRP_DIR" "$DRP_IMAGE"; then
        build_success=false
        print_error "Failed to build DRP API"
    fi

    # Build DRP Adapter
    print_info "=== Building DRP API Adapter ==="
    if ! build_image "DRP API Adapter" "$DRP_ADAPTER_DIR" "$DRP_ADAPTER_IMAGE"; then
        build_success=false
        print_error "Failed to build DRP API Adapter"
    fi

    # Build RGD
    print_info "=== Building RGD API ==="
    if ! build_image "RGD API" "$RGD_DIR" "$RGD_IMAGE"; then
        build_success=false
        print_error "Failed to build RGD API"
    fi

    # Build DIE
    print_info "=== Building Online Passport App (DIE) ==="
    if ! build_image "Online Passport App" "$DIE_DIR" "$DIE_IMAGE"; then
        build_success=false
        print_error "Failed to build Online Passport App"
    fi

    if [ "$build_success" = true ]; then
        print_success "All images built successfully!"
        print_info "You can now run services with: $0 all"
    else
        print_error "Some builds failed. Please check the errors above."
        exit 1
    fi
}

# Function to run all services
run_all() {
    local skip_pull=${1:-false}

    print_info "Starting all services..."
    print_warning "Services will run in Docker containers"

    # Run all services
    run_drp "$skip_pull"
    sleep 2
    run_drp_adapter "$skip_pull"
    sleep 2
    run_rgd "$skip_pull"
    sleep 2
    run_die "$skip_pull"

    echo ""
    print_success "All services started successfully!"
    echo ""
    print_info "Service URLs:"
    print_info "  DRP API:             http://localhost:9090"
    print_info "  DRP Adapter (GraphQL): http://localhost:9091/graphql"
    print_info "  RGD API:             http://localhost:8080"
    print_info "  RGD GraphQL:         http://localhost:8080/graphql"
    print_info "  RGD API Docs:        http://localhost:8080/docs"
    print_info "  Online Passport App: http://localhost:3000"
    echo ""
    print_info "To view logs:"
    print_info "  docker logs -f $DRP_CONTAINER"
    print_info "  docker logs -f $DRP_ADAPTER_CONTAINER"
    print_info "  docker logs -f $RGD_CONTAINER"
    print_info "  docker logs -f $DIE_CONTAINER"
    echo ""
    print_info "To stop all services:"
    print_info "  docker stop $DRP_CONTAINER $DRP_ADAPTER_CONTAINER $RGD_CONTAINER $DIE_CONTAINER"
}

# Function to stop all services
stop_all() {
    print_info "Stopping all services..."

    cleanup_container "$DRP_CONTAINER"
    cleanup_container "$DRP_ADAPTER_CONTAINER"
    cleanup_container "$RGD_CONTAINER"
    cleanup_container "$DIE_CONTAINER"

    print_success "All services stopped"
}

# Function to show service status
show_status() {
    print_info "Service Status:"
    echo ""

    for container in "$DRP_CONTAINER" "$DRP_ADAPTER_CONTAINER" "$RGD_CONTAINER" "$DIE_CONTAINER"; do
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            local status=$(docker inspect -f '{{.State.Status}}' "$container")
            local uptime=$(docker inspect -f '{{.State.StartedAt}}' "$container")
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
  drp           Pull and run only the DRP API service (port 9090)
  adapter       Pull and run only the DRP API Adapter (GraphQL, port 9091)
  rgd           Pull and run only the RGD API service (port 8080)
  die           Pull and run only the Online Passport App (port 3000)
  all           Pull and run all services (default)
  build         Build all Docker images locally
  build-run     Build all images locally and run them
  stop          Stop all running services
  status        Show status of all services
  help          Show this help message

Environment Variables:
  DOCKER_REGISTRY  Docker registry to use (default: docker.io)
  IMAGE_PREFIX     Image prefix/namespace (default: mushrafmim)
  IMAGE_TAG        Tag for DRP, DRP Adapter and RGD images (default: v0.1.0)
  DIE_IMAGE_TAG    Tag for the passport app image (default: latest)

Examples:
  $0 drp                                    # Run only DRP service
  $0 all                                    # Run all services
  $0 build                                  # Build all images locally
  $0 build-run                              # Build and run all services
  $0 stop                                   # Stop all services
  IMAGE_TAG=v1.0.0 $0 all                   # Run all services with tag v1.0.0
  IMAGE_PREFIX=myorg $0 all                 # Use custom image prefix

Service Information:
  DRP API:         Mock Digital Registration Provider API (Ballerina)
  DRP Adapter:     GraphQL adapter for DRP API (Ballerina)
  RGD API:         Mock Registration Gateway Directory API (Python/FastAPI)

Docker Images:
  DRP API:         $DRP_IMAGE
  DRP Adapter:     $DRP_ADAPTER_IMAGE
  RGD API:         $RGD_IMAGE
  Passport App:    $DIE_IMAGE

EOF
}

# Main script logic
main() {
    local command="${1:-all}"

    # Always check Docker first (except for help)
    if [ "$command" != "help" ] && [ "$command" != "-h" ] && [ "$command" != "--help" ]; then
        check_docker
    fi

    case "$command" in
        drp)
            run_drp false
            ;;
        adapter)
            run_drp_adapter false
            ;;
        rgd)
            run_rgd false
            ;;
        die)
            run_die false
            ;;
        all)
            run_all false
            ;;
        build)
            build_all
            ;;
        build-run)
            build_all
            print_info "Starting services with locally built images..."
            run_all true
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
#!/bin/bash

################################################################################
# NetPulse Consolidated Docker Build Script
# 
# This script builds all NetPulse components and creates a unified Docker
# environment for the entire microservices stack.
#
# Usage:
#   ./build-all.sh [OPTIONS]
#
# Options:
#   --mode <dev|prod|all>    Build mode (default: all)
#   --parallel               Build independent services in parallel
#   --no-cache               Build without using cache
#   --dry-run                Show what would be built without building
#   --skip-submodules        Skip submodule initialization
#   --help                   Show this help message
################################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"
BUILD_MODE="all"
PARALLEL_BUILD=false
NO_CACHE=""
DRY_RUN=false
SKIP_SUBMODULES=false
BUILD_ACTION=false
AUTO_DEPLOY=true
COMPOSE_FILES="-f docker-compose.yml"
BUILD_LOG="${ROOT_DIR}/build.log"
VERSION="${VERSION:-latest}"
SELECTED_SERVICES=()  # Array to hold specific services to build
CLIENT_ID="${CLIENT_ID:-default}"

# Component lists
# BACKEND_SERVICES=("nms-server" "nms-scheduler" "device-manager" "api-gateway" "telemetry")
BACKEND_SERVICES=("nms-server" "device-manager" "api-gateway" "telemetry" "kong" "keycloak")
FRONTEND_SERVICES=("nms-client" "frontend")
ALL_SERVICES=("${BACKEND_SERVICES[@]}" "${FRONTEND_SERVICES[@]}")


################################################################################
# Client Management
################################################################################

validate_client() {
    local client=$1
    local config_dir="${ROOT_DIR}/netpulse-frontend/configs/clients"
    local config_file="${config_dir}/${client}.json"
    
    if [ ! -d "$config_dir" ]; then
        print_info "Client config directory not found, skipping validation"
        return 0
    fi
    
    if [ ! -f "$config_file" ]; then
        print_error "Invalid CLIENT_ID: $client"
        print_info "Configuration file not found: $config_file"
        echo ""
        print_info "Available clients:"
        ls -1 "${ROOT_DIR}/netpulse-frontend/configs/clients"/*.json 2>/dev/null | xargs -n 1 basename | sed 's/.json$//' | sed 's/^/  - /'
        return 1
    fi
    return 0
}

list_clients() {
    print_header "Available Clients"
    ls -1 "${ROOT_DIR}/netpulse-frontend/configs/clients"/*.json 2>/dev/null | while read -r file; do
        local client=$(basename "$file" .json)
        local name=$(cat "$file" | grep -o '"clientName"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        local ver=$(cat "$file" | grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        echo "  - ${client} (${name:-Unknown} v${ver:-?})"
    done
}
################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_step() {
    echo -e "\n${CYAN}▶${NC} $1"
}

show_help() {
    cat << EOF
NetPulse Consolidated Docker Build Script

Usage: ./build-all.sh [ACTION] [OPTIONS]

Actions (required - choose one):
  --build                  Start the build process
  --dry-run                Show what would be built without actually building
  --help                   Show this help message

Options:
  --service <name>         Build specific service only (can be used multiple times)
                           Available services:
                             nms-server, device-manager, api-gateway, frontend
                             telemetry-influxdb, telemetry-telegraf, telemetry-api, telemetry-automation
                             postgres, redis, dhcp-autodiscovery, kong, keycloak

  --mode <dev|prod|all>    Build mode (default: all)
                           dev  - Build development images
                           prod - Build production images
                           all  - Build both dev and prod images
 --client <id>            Client ID for frontend build (default: default)
                           Use --list-clients to see available options
  --parallel               Build independent services in parallel (faster)
  --no-cache               Build without using Docker cache
  --skip-submodules        Skip Git submodule initialization
  --no-deploy              Skip automatic deployment after build
  --compose-file <files>   Compose files to use (default: "-f docker-compose.yml")

Environment Variables:
  VERSION                  Image version tag (default: latest)
  DOCKER_REGISTRY          Docker registry prefix (optional)

Examples:
  # Show help menu
  ./build-all.sh
  ./build-all.sh --help

  # Build all services
  ./build-all.sh --build

  # Build individual service
  ./build-all.sh --build --service nms-server
  ./build-all.sh --build --service device-manager
  ./build-all.sh --build --service api-gateway
  ./build-all.sh --build --service frontend

  # Build multiple specific services
  ./build-all.sh --build --service nms-server --service api-gateway

  # Build telemetry stack only
  ./build-all.sh --build --service telemetry-influxdb --service telemetry-telegraf --service telemetry-api

  # Build database services only
  ./build-all.sh --build --service postgres --service redis

  # Build individual service with no cache
  ./build-all.sh --build --service nms-server --no-cache

  # Build all services in development mode
  ./build-all.sh --build --mode dev

  # Build with specific version and no cache
  VERSION=1.0.0 ./build-all.sh --build --no-cache

  # Dry run to see what would be built
  ./build-all.sh --dry-run

  # Build in parallel for faster builds
  ./build-all.sh --build --parallel

  # Skip submodule initialization
  ./build-all.sh --build --skip-submodules

  # Build without auto-deployment
  ./build-all.sh --build --no-deploy

  # Build with custom compose files
  ./build-all.sh --build --compose-file "-f docker-compose.yml"

EOF
    exit 0
}

################################################################################
# Dependency Checks
################################################################################

check_dependencies() {
    print_step "Checking dependencies..."

    local missing_deps=()

    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi

    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        missing_deps+=("docker-compose")
    fi

    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi

    if ! command -v mvn &> /dev/null; then
        missing_deps+=("maven")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        echo ""
        echo "Please install the missing dependencies:"
        echo "  - Docker: https://docs.docker.com/get-docker/"
        echo "  - Docker Compose: https://docs.docker.com/compose/install/"
        echo "  - Git: https://git-scm.com/downloads"
        echo "  - Maven: sudo apt install maven"
        exit 1
    fi

    print_success "All dependencies are installed"
}

################################################################################
# Submodule Management
################################################################################

init_submodules() {
    if [ "$SKIP_SUBMODULES" = true ]; then
        print_warning "Skipping submodule initialization (--skip-submodules)"
        return
    fi
    
    print_step "Initializing Git submodules..."
    print_info "Note: Preserving current branch/commit in submodules"
    
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would initialize submodules"
        return
    fi
    
    # Initialize submodules without checking out to registered commits
    # This preserves the developer's current branch
    git submodule init 2>&1 | tee -a "$BUILD_LOG"
    
    print_success "Submodules initialized (current branches preserved)"
}

check_submodule_content() {
    print_step "Checking submodule content..."
    
    local empty_submodules=()
    
    # Check each submodule
    if [ ! -f "core/netpulse-api-gateway/README.md" ] && [ ! -d "core/netpulse-api-gateway/.git" ]; then
        empty_submodules+=("netpulse-api-gateway")
    fi
    
    if [ ! -d "core/netpulse-device-manager/netpulse-device-mngr" ] || [ -z "$(ls -A core/netpulse-device-manager/netpulse-device-mngr 2>/dev/null | grep -v '^\.git$')" ]; then
        empty_submodules+=("netpulse-device-mngr")
    fi
    
    if [ ! -d "core/netpulse-nms/netpulse-nms-server" ] || [ -z "$(ls -A core/netpulse-nms/netpulse-nms-server 2>/dev/null | grep -v '^\.git$')" ]; then
        empty_submodules+=("netpulse-nms-server")
    fi
    
    # if [ ! -d "core/netpulse-nms/netpulse-nms-scheduler" ] || [ -z "$(ls -A core/netpulse-nms/netpulse-nms-scheduler 2>/dev/null | grep -v '^\.git$')" ]; then
    #     empty_submodules+=("netpulse-nms-scheduler")
    # fi
    
    if [ ${#empty_submodules[@]} -ne 0 ]; then
        print_warning "The following submodules appear to be empty:"
        for submodule in "${empty_submodules[@]}"; do
            echo "    - $submodule"
        done
        print_warning "Builds for these components may fail. Continue anyway? (y/N)"
        
        if [ "$DRY_RUN" = false ]; then
            read -r response
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                print_error "Build cancelled by user"
                exit 1
            fi
        fi
    else
        print_success "All submodules have content"
    fi
}

################################################################################
# Compilation Functions (Java, Go, Rust)
################################################################################

install_local_dependencies() {
    local lib_dir="${ROOT_DIR}/core/netpulse-nms/lib"
    local netconf_jar="${lib_dir}/netconf-java-2.1.1.7.jar"

    print_step "Installing local Maven dependencies..."

    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would install local dependencies"
        return 0
    fi

    # Check if netconf-java is already in local Maven repo
    local maven_jar="$HOME/.m2/repository/net/juniper/netconf/netconf-java/2.1.1.7/netconf-java-2.1.1.7.jar"

    if [ -f "$maven_jar" ]; then
        print_info "netconf-java already installed in Maven local repo"
        return 0
    fi

    # Install from lib directory if available
    if [ -f "$netconf_jar" ]; then
        print_info "Installing netconf-java-2.1.1.7.jar to Maven local repository..."
        if mvn install:install-file \
            -Dfile="$netconf_jar" \
            -DgroupId=net.juniper.netconf \
            -DartifactId=netconf-java \
            -Dversion=2.1.1.7 \
            -Dpackaging=jar \
            -DgeneratePom=true 2>&1 | tee -a "$BUILD_LOG"; then
            print_success "netconf-java installed successfully"
            return 0
        else
            print_error "Failed to install netconf-java"
            return 1
        fi
    else
        print_error "netconf-java JAR not found at: $netconf_jar"
        print_info "Please place the JAR file at: $netconf_jar"
        print_info "This dependency is not available in Maven Central"
        return 1
    fi
}

compile_nms_server_jar() {
    local nms_server_dir="${ROOT_DIR}/core/netpulse-nms/netpulse-nms-server"

    print_step "Compiling NMS Server JAR..."

    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would compile: mvn clean package -DskipTests in $nms_server_dir"
        return 0
    fi

    # Install local dependencies first
    if ! install_local_dependencies; then
        print_error "Failed to install local dependencies"
        return 1
    fi

    if [ ! -f "$nms_server_dir/pom.xml" ]; then
        print_error "pom.xml not found in $nms_server_dir"
        return 1
    fi

    # Clean target directory (may be owned by root from previous Docker builds)
    if [ -d "$nms_server_dir/target" ]; then
        print_info "Cleaning target directory..."
        rm -rf "$nms_server_dir/target" 2>/dev/null || sudo rm -rf "$nms_server_dir/target"
    fi

    # Compile with Maven
    print_info "Running Maven build..."
    echo "Compiling NMS Server JAR at $(date)" >> "$BUILD_LOG"

    if (cd "$nms_server_dir" && mvn clean package -DskipTests -B) 2>&1 | tee -a "$BUILD_LOG"; then
        # Copy JAR to app.jar for Docker build
        if [ -f "$nms_server_dir/target/server-0.0.1-SNAPSHOT.jar" ]; then
            cp "$nms_server_dir/target/server-0.0.1-SNAPSHOT.jar" "$nms_server_dir/app.jar"
            print_success "NMS Server JAR compiled and copied to app.jar"
            return 0
        else
            print_error "JAR file not found after Maven build"
            return 1
        fi
    else
        print_error "Maven build failed for NMS Server"
        return 1
    fi
}

compile_telegraf_binary() {
    local telegraf_dir="${ROOT_DIR}/core/netpulse-telemetry/netpulse-telemetry-telegraf"
    local binary_path="${telegraf_dir}/target/release/telegraf.gz"

    print_step "Compiling Telegraf binary (Go)..."

    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would compile: go build in $telegraf_dir"
        return 0
    fi

    # Check if pre-built binary already exists
    if [ -f "$binary_path" ]; then
        print_info "Pre-built telegraf.gz found, skipping compilation"
        return 0
    fi

    # Check if Go is installed
    if ! command -v go &> /dev/null; then
        print_error "Go is not installed. Cannot compile Telegraf."
        print_info "Install Go or provide pre-built binary at: $binary_path"
        return 1
    fi

    if [ ! -f "$telegraf_dir/go.mod" ]; then
        print_error "go.mod not found in $telegraf_dir"
        return 1
    fi

    # Create target directory
    mkdir -p "${telegraf_dir}/target/release"

    # Compile with Go
    print_info "Running Go build..."
    echo "Compiling Telegraf at $(date)" >> "$BUILD_LOG"

    if (cd "$telegraf_dir" && go build -o target/release/telegraf ./cmd/telegraf) 2>&1 | tee -a "$BUILD_LOG"; then
        # Compress the binary
        print_info "Compressing telegraf binary..."
        gzip -f "${telegraf_dir}/target/release/telegraf"
        print_success "Telegraf binary compiled and compressed"
        return 0
    else
        print_error "Go build failed for Telegraf"
        return 1
    fi
}

compile_influxdb3_binary() {
    local influxdb_dir="${ROOT_DIR}/core/netpulse-telemetry/netpulse-telemetry-influxDB"
    local binary_path="${influxdb_dir}/target/release/influxdb3.gz"

    print_step "Compiling InfluxDB3 binary (Rust)..."

    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would compile: cargo build --release in $influxdb_dir"
        return 0
    fi

    # Check if pre-built binary already exists
    if [ -f "$binary_path" ]; then
        print_info "Pre-built influxdb3.gz found, skipping compilation"
        return 0
    fi

    # Check if Rust/Cargo is installed
    if ! command -v cargo &> /dev/null; then
        print_error "Rust/Cargo is not installed. Cannot compile InfluxDB3."
        print_info "Install Rust or provide pre-built binary at: $binary_path"
        return 1
    fi

    if [ ! -f "$influxdb_dir/Cargo.toml" ]; then
        print_error "Cargo.toml not found in $influxdb_dir"
        return 1
    fi

    # Create target directory
    mkdir -p "${influxdb_dir}/target/release"

    # Compile with Cargo
    print_info "Running Cargo build (this may take a while)..."
    echo "Compiling InfluxDB3 at $(date)" >> "$BUILD_LOG"

    if (cd "$influxdb_dir" && cargo build --release) 2>&1 | tee -a "$BUILD_LOG"; then
        # Compress the binary
        print_info "Compressing influxdb3 binary..."
        gzip -f "${influxdb_dir}/target/release/influxdb3"
        print_success "InfluxDB3 binary compiled and compressed"
        return 0
    else
        print_error "Cargo build failed for InfluxDB3"
        return 1
    fi
}

verify_telemetry_binaries() {
    local telegraf_binary="${ROOT_DIR}/core/netpulse-telemetry/netpulse-telemetry-telegraf/target/release/telegraf.gz"
    local influxdb_binary="${ROOT_DIR}/core/netpulse-telemetry/netpulse-telemetry-influxDB/target/release/influxdb3.gz"
    local missing=()

    print_step "Verifying telemetry binaries..."

    if [ ! -f "$telegraf_binary" ]; then
        missing+=("telegraf.gz")
    fi

    if [ ! -f "$influxdb_binary" ]; then
        missing+=("influxdb3.gz")
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        print_error "Missing pre-built binaries: ${missing[*]}"
        print_info "Either:"
        print_info "  1. Run compilation (requires Go/Rust toolchains)"
        print_info "  2. Provide pre-built binaries in target/release/ directories"
        return 1
    fi

    print_success "All telemetry binaries found"
    return 0
}

################################################################################
# Build Functions
################################################################################

build_service() {
    local service_name=$1
    local dockerfile_path=$2
    local context_path=$3
    local image_tag=$4

    print_step "Building $service_name..."

    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would build: docker build --network=host $NO_CACHE -f $dockerfile_path -t $image_tag $context_path"
        return 0
    fi

    if [ ! -f "$dockerfile_path" ]; then
        print_warning "Dockerfile not found: $dockerfile_path - Skipping"
        return 1
    fi

    echo "Building $service_name at $(date)" >> "$BUILD_LOG"

    if docker build --network=host $NO_CACHE -f "$dockerfile_path" -t "$image_tag" "$context_path" 2>&1 | tee -a "$BUILD_LOG"; then
        print_success "Built $service_name → $image_tag"
        return 0
    else
        print_error "Failed to build $service_name"
        return 1
    fi
}

build_nms_server() {
    # First compile the JAR from source
    if ! compile_nms_server_jar; then
        print_error "Failed to compile NMS Server JAR"
        return 1
    fi

    # Then build the Docker image
    build_service "NMS Server" \
        "${ROOT_DIR}/core/netpulse-nms/netpulse-nms-server/Dockerfile" \
        "${ROOT_DIR}/core/netpulse-nms/netpulse-nms-server" \
        "netpulse/nms-server:${VERSION}"
}

# build_nms_scheduler() {
#     build_service "NMS Scheduler" \
#         "${ROOT_DIR}/docker/scheduler/Dockerfile" \
#         "${ROOT_DIR}/core/netpulse-nms/netpulse-nms-scheduler" \
#         "netpulse/nms-scheduler:${VERSION}"
# }

build_device_manager() {
    build_service "Device Manager" \
        "${ROOT_DIR}/docker/netpulse-device-mngr/Dockerfile" \
        "${ROOT_DIR}" \
        "netpulse/device-manager:${VERSION}"
}

build_api_gateway() {
    build_service "API Gateway" \
        "${ROOT_DIR}/docker/netpulse-api-gateway/Dockerfile" \
        "${ROOT_DIR}/core/netpulse-api-gateway" \
        "netpulse/api-gateway:${VERSION}"
}

build_frontend() {
    local build_client="${CLIENT_ID:-default}"
    
    print_step "Building Frontend for client: ${build_client}..."
    
    if ! validate_client "$build_client"; then
        return 1
    fi
    
    local config_file="${ROOT_DIR}/netpulse-frontend/configs/clients/${build_client}.json"
    print_info "Using config: $config_file"
    
    if [ -f "$config_file" ]; then
        local client_name=$(cat "$config_file" | grep -o '"clientName"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        local version=$(cat "$config_file" | grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        print_info "Client Name: ${client_name:-Unknown}"
        print_info "Version: ${version:-Unknown}"
    fi
    
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would build frontend with CLIENT_ID=${build_client}"
        return 0
    fi
    
    build_service "Frontend (${build_client})" \
        "${ROOT_DIR}/docker/netpulse-frontend/Dockerfile" \
        "${ROOT_DIR}/netpulse-frontend" \
        "netpulse/frontend-${build_client}:${VERSION}" \
        --build-arg CLIENT_ID="${build_client}" \
        --build-arg VITE_APP_API_URL="http://${NETPULSE_HOST_IP:-10.4.160.240}:8081" \
        --build-arg VITE_APP_IP="${NETPULSE_HOST_IP:-10.4.160.240}"
}

build_telemetry_influxdb() {
    # First compile/verify binary
    if ! compile_influxdb3_binary; then
        print_error "Failed to prepare InfluxDB3 binary"
        return 1
    fi

    # Then build the Docker image
    build_service "Telemetry InfluxDB" \
        "${ROOT_DIR}/docker/netpulse-telemetry/Dockerfile.influxdb" \
        "${ROOT_DIR}" \
        "netpulse/telemetry-influxdb:${VERSION}"
}

build_telemetry_telegraf() {
    # First compile/verify binary
    if ! compile_telegraf_binary; then
        print_error "Failed to prepare Telegraf binary"
        return 1
    fi

    # Then build the Docker image
    build_service "Telemetry Telegraf" \
        "${ROOT_DIR}/docker/netpulse-telemetry/Dockerfile.telegraf" \
        "${ROOT_DIR}" \
        "netpulse/telemetry-telegraf:${VERSION}"
}

build_telemetry_api() {
    build_service "Telemetry API" \
        "${ROOT_DIR}/docker/netpulse-telemetry/Dockerfile-api" \
        "${ROOT_DIR}" \
        "netpulse/telemetry-api:${VERSION}"
}

build_telemetry_automation() {
    build_service "telemetry-automation" \
        "${ROOT_DIR}/docker/netpulse-telemetry/Dockerfile.automation" \
        "${ROOT_DIR}" \
        "netpulse/telemetry-automation:${VERSION}"
}

build_postgres() {
    build_service "PostgreSQL" \
        "${ROOT_DIR}/docker/postgres/Dockerfile" \
        "${ROOT_DIR}" \
        "netpulse/postgres:${VERSION}"
}

build_redis() {
    build_service "Redis" \
        "${ROOT_DIR}/docker/redis/Dockerfile" \
        "${ROOT_DIR}" \
        "netpulse/redis:${VERSION}"
}

build_dhcp_autodiscovery() {
    build_service "DHCP Autodiscovery" \
        "${ROOT_DIR}/docker/DHCP-autodiscovery/Dockerfile" \
        "${ROOT_DIR}/core/netpulse-device-manager/agent" \
        "netpulse/dhcp-autodiscovery:${VERSION}"
}

build_arangodb() {
    build_service "ArangoDB" \
        "${ROOT_DIR}/docker/netpulse-nms/nms-arangodb/Dockerfile" \
        "${ROOT_DIR}/docker/netpulse-nms/nms-arangodb" \
        "netpulse/arangodb:${VERSION}"
}

build_kong() {
    build_service "Kong API Gateway" \
        "${ROOT_DIR}/docker/netpulse-api-gateway/Dockerfile.kong" \
        "${ROOT_DIR}" \
        "netpulse/kong:${VERSION}"
}

build_keycloak() {
    build_service "Keycloak Auth Server" \
        "${ROOT_DIR}/docker/netpulse-auth/Dockerfile.keycloak" \
        "${ROOT_DIR}" \
        "netpulse/keycloak:${VERSION}"
}

################################################################################
# Main Build Orchestration
################################################################################

# Map service names from CLI to build function names
get_build_function_name() {
    local service_name=$1
    case $service_name in
        nms-server)       echo "nms_server" ;;
        device-manager)   echo "device_manager" ;;
        api-gateway)      echo "api_gateway" ;;
        frontend)         echo "frontend" ;;
        telemetry-influxdb)   echo "telemetry_influxdb" ;;
        telemetry-telegraf)   echo "telemetry_telegraf" ;;
        telemetry-api)        echo "telemetry_api" ;;
        telemetry-automation) echo "telemetry_automation" ;;
        postgres)         echo "postgres" ;;
        redis)            echo "redis" ;;
        dhcp-autodiscovery)   echo "dhcp_autodiscovery" ;;
        kong)                 echo "kong" ;;
        keycloak)             echo "keycloak" ;;
        *)
            print_error "Unknown service: $service_name"
            print_info "Available services: nms-server, device-manager, api-gateway, frontend"
            print_info "                    telemetry-influxdb, telemetry-telegraf, telemetry-api, telemetry-automation"
            print_info "                    postgres, redis, dhcp-autodiscovery, kong, keycloak"
            return 1
            ;;
    esac
}

build_selected_services() {
    print_header "Building Selected NetPulse Components"

    local failed_builds=()
    local successful_builds=()

    print_info "Building ${#SELECTED_SERVICES[@]} selected service(s)..."

    for service_name in "${SELECTED_SERVICES[@]}"; do
        local func_name
        func_name=$(get_build_function_name "$service_name")
        if [ $? -ne 0 ]; then
            failed_builds+=("$service_name")
            continue
        fi

        if build_$func_name; then
            successful_builds+=("$service_name")
        else
            failed_builds+=("$service_name")
        fi
    done

    # Print summary
    print_header "Build Summary"

    if [ ${#successful_builds[@]} -gt 0 ]; then
        print_success "Successfully built ${#successful_builds[@]} service(s):"
        for service in "${successful_builds[@]}"; do
            echo "    ✓ $service"
        done
    fi

    if [ ${#failed_builds[@]} -gt 0 ]; then
        echo ""
        print_error "Failed to build ${#failed_builds[@]} service(s):"
        for service in "${failed_builds[@]}"; do
            echo "    ✗ $service"
        done
        echo ""
        print_info "Check the build log for details: $BUILD_LOG"
        return 1
    fi

    return 0
}

build_all_services() {
    print_header "Building NetPulse Components"

    local failed_builds=()
    local successful_builds=()

    # Build backend services
    print_info "Building backend services..."

    if [ "$PARALLEL_BUILD" = true ] && [ "$DRY_RUN" = false ]; then
        print_info "Building in parallel mode..."
        # Note: Parallel builds would require more complex implementation
        # For now, we'll build sequentially
        print_warning "Parallel build not yet implemented, building sequentially"
    fi

    # Build in dependency order
    # for service in nms_server nms_scheduler device_manager telemetry_influxdb telemetry_telegraf telemetry_api telemetry_automation; do
    for service in postgres redis nms_server device_manager api_gateway keycloak kong telemetry_influxdb telemetry_telegraf telemetry_api telemetry_automation dhcp_autodiscovery; do
        if build_$service; then
            successful_builds+=("$service")
        else
            failed_builds+=("$service")
        fi
    done

    # Build frontend services
    print_info "Building frontend services..."

    for service in frontend; do
        if build_$service; then
            successful_builds+=("$service")
        else
            failed_builds+=("$service")
        fi
    done

    # Print summary
    print_header "Build Summary"

    if [ ${#successful_builds[@]} -gt 0 ]; then
        print_success "Successfully built ${#successful_builds[@]} service(s):"
        for service in "${successful_builds[@]}"; do
            echo "    ✓ $service"
        done
    fi

    if [ ${#failed_builds[@]} -gt 0 ]; then
        echo ""
        print_error "Failed to build ${#failed_builds[@]} service(s):"
        for service in "${failed_builds[@]}"; do
            echo "    ✗ $service"
        done
        echo ""
        print_info "Check the build log for details: $BUILD_LOG"
        return 1
    fi

    return 0
}

################################################################################
# Parse Arguments
################################################################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --build)
                BUILD_ACTION=true
                shift
                ;;
            --client)
                CLIENT_ID="$2"
                shift 2
                ;;
            --list-clients)
                list_clients
                exit 0
                ;;
            --mode)
                BUILD_MODE="$2"
                if [[ ! "$BUILD_MODE" =~ ^(dev|prod|all)$ ]]; then
                    print_error "Invalid mode: $BUILD_MODE. Must be dev, prod, or all"
                    exit 1
                fi
                shift 2
                ;;
            --parallel)
                PARALLEL_BUILD=true
                shift
                ;;
            --no-cache)
                NO_CACHE="--no-cache"
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                BUILD_ACTION=true
                shift
                ;;
            --skip-submodules)
                SKIP_SUBMODULES=true
                shift
                ;;
            --no-deploy)
                AUTO_DEPLOY=false
                shift
                ;;
            --compose-file)
                COMPOSE_FILES="$2"
                shift 2
                ;;
            --service)
                SELECTED_SERVICES+=("$2")
                shift 2
                ;;
            --help)
                show_help
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

################################################################################
# Main Execution
################################################################################

main() {
    parse_arguments "$@"

    # Set default if CLIENT_ID is empty
    if [ -z "$CLIENT_ID" ]; then
        CLIENT_ID="default"
        print_info "No CLIENT_ID specified, using 'default'"
    fi
    
    # Show help if no action flag is provided
    if [ "$BUILD_ACTION" = false ]; then
        show_help
    fi

    print_header "NetPulse Consolidated Build System"

    print_info "Build Configuration:"
    echo "  Mode:           $BUILD_MODE"
    echo "  Client ID:      $CLIENT_ID"
    echo "  Version:        $VERSION"
    echo "  Parallel:       $PARALLEL_BUILD"
    echo "  Cache:          $([ -z "$NO_CACHE" ] && echo "enabled" || echo "disabled")"
    echo "  Dry Run:        $DRY_RUN"
    echo "  Build Log:      $BUILD_LOG"
    if [ ${#SELECTED_SERVICES[@]} -gt 0 ]; then
        echo "  Services:       ${SELECTED_SERVICES[*]}"
    else
        echo "  Services:       all"
    fi
    echo ""

    # Initialize build log
    if [ "$DRY_RUN" = false ]; then
        echo "NetPulse Build Log - $(date)" > "$BUILD_LOG"
        echo "Client ID: $CLIENT_ID" >> "$BUILD_LOG"
        echo "======================================" >> "$BUILD_LOG"
    fi

        # Validate client before starting build
    if ! validate_client "$CLIENT_ID"; then
        exit 1
    fi
    
    # Show client info
    print_info "Available clients:"
    list_clients | tail -n +2
    echo ""
    
    # Export CLIENT_ID for docker-compose
    export CLIENT_ID
    export VERSION
    
    # Run build steps
    check_dependencies
    init_submodules
    check_submodule_content

    # Build selected services or all services
    local build_result
    if [ ${#SELECTED_SERVICES[@]} -gt 0 ]; then
        build_selected_services
        build_result=$?
    else
        build_all_services
        build_result=$?
    fi

    if [ $build_result -eq 0 ]; then
        print_header "Build Complete! 🎉"
        print_success "All images built successfully"
        echo ""
        
        # Auto-deploy if enabled
        if [ "$AUTO_DEPLOY" = true ] && [ "$DRY_RUN" = false ]; then
            print_header "Starting Services"
            print_step "Deploying with docker compose..."
            print_info "Compose files: $COMPOSE_FILES"
            
            if docker compose $COMPOSE_FILES up -d 2>&1 | tee -a "$BUILD_LOG"; then
                print_success "Services started successfully"
                echo ""
                print_info "Next steps:"
                echo "  1. Check status: docker compose ps"
                echo "  2. View logs: docker compose logs -f"
                echo "  3. Review build log: $BUILD_LOG"
            else
                print_error "Failed to start services"
                echo ""
                print_info "You can manually start services with:"
                echo "  docker compose $COMPOSE_FILES up -d"
                exit 1
            fi
        else
            if [ "$DRY_RUN" = true ]; then
                print_info "[DRY RUN] Would deploy with: docker compose $COMPOSE_FILES up -d"
            else
                print_info "Auto-deploy skipped (use --no-deploy to disable)"
                echo ""
                print_info "Next steps:"
                echo "  1. Review the build log: $BUILD_LOG"
                echo "  2. Start services: docker compose $COMPOSE_FILES up -d"
                echo "  3. Check status: docker compose ps"
                echo "  4. View logs: docker compose logs -f"
            fi
        fi
        exit 0
    else
        print_header "Build Failed ❌"
        print_error "Some services failed to build"
        echo ""
        print_info "Check the build log for details: $BUILD_LOG"
        exit 1
    fi
}

# Run main function
main "$@"
#!/bin/bash

# Build NewStart OS YUM repositories using Docker container
# This script manages ISO downloads and container-based repository creation

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_ROOT/config/build-config.json"
ISO_DIR="$PROJECT_ROOT/iso"
YUM_REPO_DIR="$PROJECT_ROOT/yum-repo"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get version information from config
get_version_info() {
    local version_key="$1"
    local field="$2"
    
    if command -v jq &> /dev/null; then
        jq -r ".newstart_os.versions[\"${version_key}\"].${field}" "$CONFIG_FILE"
    else
        log_error "jq is required but not installed"
        return 1
    fi
}

# Check if ISO exists and download if needed
check_and_download_iso() {
    local version_key="$1"
    local iso_filename download_url expected_size
    
    iso_filename=$(get_version_info "$version_key" "iso_filename")
    download_url=$(get_version_info "$version_key" "download_url")
    expected_size=$(get_version_info "$version_key" "expected_size_bytes")
    
    if [[ "$iso_filename" == "null" || "$download_url" == "null" ]]; then
        log_error "Missing ISO filename or download URL for version $version_key"
        return 1
    fi
    
    # Ensure ISO directory exists
    mkdir -p "$ISO_DIR"
    
    local iso_path="$ISO_DIR/$iso_filename"
    
    # Check if ISO already exists and has correct size
    if [[ -f "$iso_path" ]]; then
        if [[ "$expected_size" != "null" && "$expected_size" != "0" ]]; then
            local actual_size=$(stat -c%s "$iso_path" 2>/dev/null || echo "0")
            if [[ "$actual_size" == "$expected_size" ]]; then
                log_info "ISO file already exists with correct size: $iso_filename"
                return 0
            else
                log_warning "ISO file exists but size mismatch (expected: $expected_size, actual: $actual_size)"
                log_info "Re-downloading ISO file..."
            fi
        else
            log_info "ISO file already exists: $iso_filename"
            return 0
        fi
    fi
    
    log_info "Downloading ISO: $iso_filename"
    log_info "From: $download_url"
    
    # Create temporary download path
    local temp_path="${iso_path}.tmp"
    
    # Download with wget (preferred) or curl as fallback
    if command -v wget &> /dev/null; then
        if wget --progress=bar:force --timeout=30 --tries=3 -O "$temp_path" "$download_url"; then
            mv "$temp_path" "$iso_path"
            log_success "ISO downloaded successfully: $iso_filename"
        else
            rm -f "$temp_path"
            log_error "Failed to download ISO with wget"
            return 1
        fi
    elif command -v curl &> /dev/null; then
        if curl -L --progress-bar --connect-timeout 30 --retry 3 -o "$temp_path" "$download_url"; then
            mv "$temp_path" "$iso_path"
            log_success "ISO downloaded successfully: $iso_filename"
        else
            rm -f "$temp_path"
            log_error "Failed to download ISO with curl"
            return 1
        fi
    else
        log_error "Neither wget nor curl available for downloading"
        return 1
    fi
    
    # Verify file size if expected size is provided
    if [[ "$expected_size" != "null" && "$expected_size" != "0" ]]; then
        local actual_size=$(stat -c%s "$iso_path" 2>/dev/null || echo "0")
        if [[ "$actual_size" != "$expected_size" ]]; then
            log_warning "Downloaded file size mismatch:"
            log_warning "  Expected: $(numfmt --to=iec $expected_size 2>/dev/null || echo $expected_size)"
            log_warning "  Actual:   $(numfmt --to=iec $actual_size 2>/dev/null || echo $actual_size)"
        else
            log_success "File size verification passed ($(numfmt --to=iec $actual_size 2>/dev/null || echo $actual_size))"
        fi
    fi
    
    return 0
}

# Show usage information
usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS] [versions...]

Build NewStart OS YUM repositories using Docker container.

COMMANDS:
  build [OPTIONS] [versions...]  Build repositories (default)
  clean                         Clean all repositories and ISOs
  shell                         Start interactive shell in container
  
OPTIONS:
  --baseurl-type TYPE          Set baseurl type: file (default), http, https
  --baseurl-prefix PREFIX      Base URL prefix for http/https
  -h, --help                  Show this help message

Available versions:
  v6.06.11b10    NewStart OS V6.06.11B10
  v7.02.03b9     NewStart OS V7.02.03B9

Examples:
  $0 build                                    # Build repositories for all versions
  $0 build v6.06.11b10                        # Build repository for V6.06.11B10 only
  $0 build --baseurl-type=http --baseurl-prefix=http://repo.example.com/newstartos v6.06.11b10
  $0 clean                                    # Clean all repositories and ISOs
  $0 shell                                    # Start interactive shell in container

Requirements:
  - Docker or Podman
  - Internet connection for ISO downloads
  - Sufficient disk space for ISOs and repositories

Output:
  - ISOs: $ISO_DIR/
  - Repositories: $YUM_REPO_DIR/
EOF
}

# Build container image
build_image() {
    log_info "Building container image for YUM repository builder..."
    
    local container_cmd=""
    if command -v podman &> /dev/null; then
        container_cmd="podman"
        log_info "Using Podman as container runtime"
    elif command -v docker &> /dev/null; then
        container_cmd="docker"
        log_info "Using Docker as container runtime"
    else
        log_error "Neither Docker nor Podman is installed or in PATH"
        return 1
    fi
    
    # Build the image
    log_info "Building image: newstartos-yum-builder"
    if $container_cmd build -f "$PROJECT_ROOT/dockerfiles/yum-repo-builder/Dockerfile" -t newstartos-yum-builder "$PROJECT_ROOT"; then
        log_success "Container image built successfully"
    else
        log_error "Failed to build container image"
        return 1
    fi
}

# Run repository build in container
run_build() {
    local args=("$@")
    local versions=()
    
    # Parse arguments to extract versions
    for arg in "${args[@]}"; do
        case $arg in
            --baseurl-type|--baseurl-type=*|--baseurl-prefix|--baseurl-prefix=*)
                # Skip options
                ;;
            *)
                # This is a version
                if [[ "$arg" != --* ]]; then
                    versions+=("$arg")
                fi
                ;;
        esac
    done
    
    # Default versions if none specified
    if [[ ${#versions[@]} -eq 0 ]]; then
        versions=("v6.06.11b10" "v7.02.03b9")
    fi
    
    log_info "Starting YUM repository build in container..."
    log_info "Versions to process: ${versions[*]}"
    
    # Check and download ISOs for each version
    for version in "${versions[@]}"; do
        log_info "Checking ISO for version: $version"
        if ! check_and_download_iso "$version"; then
            log_error "Failed to prepare ISO for version $version"
            return 1
        fi
    done
    
    # Ensure directories exist with correct permissions
    mkdir -p "$PROJECT_ROOT/iso" "$PROJECT_ROOT/yum-repo"
    chmod 755 "$PROJECT_ROOT/iso" "$PROJECT_ROOT/yum-repo"
    
    # Check for container runtime
    local container_cmd=""
    if command -v podman &> /dev/null; then
        container_cmd="podman"
    elif command -v docker &> /dev/null; then
        container_cmd="docker"
    else
        log_error "Neither Docker nor Podman is available"
        return 1
    fi
    
    # Mount ISO on host first to avoid container permission issues
    local iso_mount_point="/tmp/newstartos-iso-mount-$$"
    local mounted_isos=()
    
    # Mount all required ISOs on host
    for version in "${versions[@]}"; do
        local iso_filename=$(get_version_info "$version" "iso_filename")
        local iso_path="$PROJECT_ROOT/iso/$iso_filename"
        
        if [[ -f "$iso_path" ]]; then
            local version_mount_point="$iso_mount_point/$version"
            sudo mkdir -p "$version_mount_point"
            if sudo mount -o loop,ro "$iso_path" "$version_mount_point"; then
                log_info "Mounted ISO for $version at $version_mount_point"
                mounted_isos+=("$version:$version_mount_point")
            else
                log_error "Failed to mount ISO for $version"
                # Cleanup any mounted ISOs
                for mounted in "${mounted_isos[@]}"; do
                    local mount_path="${mounted#*:}"
                    sudo umount "$mount_path" 2>/dev/null || true
                done
                sudo rm -rf "$iso_mount_point"
                return 1
            fi
        fi
    done
    
    # Run the container with mounted ISOs
    if $container_cmd run --rm --privileged \
        -v "$iso_mount_point:/workspace/iso-mount:ro" \
        -v "$PROJECT_ROOT/yum-repo:/workspace/yum-repo" \
        -v "$PROJECT_ROOT/config:/workspace/config" \
        -v "$PROJECT_ROOT/scripts:/workspace/scripts" \
        newstartos-yum-builder bash -c "
            for version in ${versions[*]}; do
                echo '[INFO] Processing version: '\$version
                mkdir -p /workspace/yum-repo/\$version/Packages
                mkdir -p /workspace/yum-repo/\$version/repodata
                
                # Copy RPM packages from different directories
                for rpm_dir in BaseOS/Packages AppStream/Packages PowerTools/Packages Extras/Packages; do
                    if [[ -d /workspace/iso-mount/\$version/\$rpm_dir ]]; then
                        echo '[INFO] Copying RPMs from '\$rpm_dir
                        find /workspace/iso-mount/\$version/\$rpm_dir -name '*.rpm' -exec cp {} /workspace/yum-repo/\$version/Packages/ \; 2>/dev/null || true
                    fi
                done
                
                # Create repository metadata
                echo '[INFO] Creating repository metadata for '\$version
                createrepo /workspace/yum-repo/\$version/
                
                # Create repo config file
                cat > /workspace/yum-repo/\$version/newstartos-\$version.repo << EOF
[newstartos-\$version]
name=NewStart OS \$version Repository
baseurl=file:///workspace/yum-repo/\$version
enabled=1
gpgcheck=0
EOF
                
                echo '[INFO] Repository created for '\$version
            done
        "; then
        
        # Cleanup mounted ISOs
        for mounted in "${mounted_isos[@]}"; do
            local mount_path="${mounted#*:}"
            sudo umount "$mount_path" 2>/dev/null || true
        done
        sudo rm -rf "$iso_mount_point"
        log_success "Repository build completed successfully"
        log_info "Results available in:"
        log_info "  - ISOs: $PROJECT_ROOT/iso/"
        log_info "  - Repositories: $PROJECT_ROOT/yum-repo/"
    else
        log_error "Repository build failed"
        return 1
    fi
}

# Clean repositories using container
run_clean() {
    log_info "Cleaning repositories using container..."
    
    # Check for container runtime
    local container_cmd=""
    if command -v podman &> /dev/null; then
        container_cmd="podman"
    elif command -v docker &> /dev/null; then
        container_cmd="docker"
    else
        log_error "Neither Docker nor Podman is available"
        return 1
    fi
    
    # Run clean in container
    if $container_cmd run --rm --privileged \
        -v "$PROJECT_ROOT/iso:/workspace/iso" \
        -v "$PROJECT_ROOT/yum-repo:/workspace/yum-repo" \
        -v "$PROJECT_ROOT/config:/workspace/config" \
        -v "$PROJECT_ROOT/scripts:/workspace/scripts" \
        newstartos-yum-builder /workspace/scripts/create-yum-repo.sh clean; then
        log_success "Clean completed successfully"
    else
        log_error "Clean operation failed"
        return 1
    fi
}

# Start interactive shell in container
run_shell() {
    log_info "Starting interactive shell in container..."
    
    # Check for container runtime
    local container_cmd=""
    if command -v podman &> /dev/null; then
        container_cmd="podman"
    elif command -v docker &> /dev/null; then
        container_cmd="docker"
    else
        log_error "Neither Docker nor Podman is available"
        return 1
    fi
    
    # Run interactive shell
    $container_cmd run --rm -it --privileged \
        -v "$PROJECT_ROOT/iso:/workspace/iso" \
        -v "$PROJECT_ROOT/yum-repo:/workspace/yum-repo" \
        -v "$PROJECT_ROOT/config:/workspace/config" \
        -v "$PROJECT_ROOT/scripts:/workspace/scripts" \
        newstartos-yum-builder /bin/bash
}

# Main function
main() {
    local command="build"
    
    # Parse command
    if [[ $# -gt 0 ]]; then
        case "$1" in
            build|clean|shell)
                command="$1"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
        esac
    fi
    
    # Build image first
    if ! build_image; then
        log_error "Failed to build container image"
        exit 1
    fi
    
    # Execute command
    case "$command" in
        build)
            run_build "$@"
            ;;
        clean)
            run_clean
            ;;
        shell)
            run_shell
            ;;
        *)
            log_error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
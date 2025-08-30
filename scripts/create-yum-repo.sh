#!/bin/bash

# Create YUM repository from NewStart OS ISO
# This script extracts RPM packages and creates yum repository metadata

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_ROOT/config/build-config.json"
YUM_REPO_DIR="$PROJECT_ROOT/yum-repo"
ISO_DIR="$PROJECT_ROOT/iso"
MOUNT_POINT="/tmp/newstartos-iso-mount"

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

# Cleanup function
cleanup() {
    if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
        log_info "Unmounting ISO..."
        sudo umount "$MOUNT_POINT" || log_warning "Failed to unmount $MOUNT_POINT"
    fi
    if [[ -d "$MOUNT_POINT" ]]; then
        rmdir "$MOUNT_POINT" 2>/dev/null || true
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Check dependencies
check_dependencies() {
    local deps=("jq" "createrepo" "rsync" "wget" "curl")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_info "Please install: sudo yum install -y ${missing[*]}"
        return 1
    fi
}

# Parse JSON config
get_version_info() {
    local version_key="$1"
    local field="$2"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Config file not found: $CONFIG_FILE"
        return 1
    fi
    
    jq -r ".newstart_os.versions[\"${version_key}\"].${field}" "$CONFIG_FILE"
}

# Download ISO file if not exists
download_iso() {
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

# Create yum repository for a specific version
create_version_repo() {
    local version_key="$1"
    local baseurl_type="$2"
    local baseurl_prefix="$3"
    local iso_filename version architecture
    
    log_info "Processing version: $version_key"
    
    # Get version information from config
    iso_filename=$(get_version_info "$version_key" "iso_filename")
    version=$(get_version_info "$version_key" "version")
    architecture=$(get_version_info "$version_key" "architecture")
    
    if [[ "$iso_filename" == "null" || "$version" == "null" ]]; then
        log_error "Invalid version configuration for $version_key"
        return 1
    fi
    
    local iso_path="$ISO_DIR/$iso_filename"
    local repo_dir="$YUM_REPO_DIR/$version_key"
    local packages_dir="$repo_dir/Packages"
    local repodata_dir="$repo_dir/repodata"
    
    # Download ISO file if not exists
    if ! download_iso "$version_key"; then
        log_error "Failed to download ISO for version $version_key"
        return 1
    fi
    
    # Check if ISO file exists after download attempt
    if [[ ! -f "$iso_path" ]]; then
        log_error "ISO file not found: $iso_path"
        return 1
    fi
    
    log_info "Creating repository directory structure..."
    mkdir -p "$packages_dir" "$repodata_dir"
    
    # Create mount point
    mkdir -p "$MOUNT_POINT"
    
    # Mount ISO
    log_info "Mounting ISO: $iso_filename"
    if ! sudo mount -o loop,ro "$iso_path" "$MOUNT_POINT"; then
        log_error "Failed to mount ISO file"
        return 1
    fi
    
    # Find and copy RPM packages
    log_info "Extracting RPM packages..."
    local rpm_count=0
    
    # Look for common RPM package locations in the ISO
    local rpm_dirs=("Packages" "BaseOS/Packages" "AppStream/Packages" "packages" "RPMS")
    local found_rpms=false
    
    for rpm_dir in "${rpm_dirs[@]}"; do
        local full_rpm_path="$MOUNT_POINT/$rpm_dir"
        if [[ -d "$full_rpm_path" ]]; then
            log_info "Found RPM directory: $rpm_dir"
            found_rpms=true
            
            # Copy all RPM files
            find "$full_rpm_path" -name "*.rpm" -type f | while read -r rpm_file; do
                local rpm_name=$(basename "$rpm_file")
                if [[ ! -f "$packages_dir/$rpm_name" ]]; then
                    cp "$rpm_file" "$packages_dir/"
                    ((rpm_count++))
                fi
            done
        fi
    done
    
    if [[ "$found_rpms" == "false" ]]; then
        log_warning "No standard RPM directories found, searching entire ISO..."
        find "$MOUNT_POINT" -name "*.rpm" -type f | while read -r rpm_file; do
            local rpm_name=$(basename "$rpm_file")
            if [[ ! -f "$packages_dir/$rpm_name" ]]; then
                cp "$rpm_file" "$packages_dir/"
                ((rpm_count++))
            fi
        done
    fi
    
    # Count actual copied RPMs and fix permissions
    rpm_count=$(find "$packages_dir" -name "*.rpm" -type f | wc -l)
    log_info "Extracted $rpm_count RPM packages"
    
    if [[ $rpm_count -eq 0 ]]; then
        log_error "No RPM packages found in ISO"
        return 1
    fi
    
    # Fix permissions for RPM packages
    log_info "Fixing file permissions..."
    find "$packages_dir" -type f -name "*.rpm" -exec chmod 644 {} \;
    find "$packages_dir" -type d -exec chmod 755 {} \;
    
    # Copy repository metadata if exists
    log_info "Looking for existing repository metadata..."
    local metadata_dirs=("repodata" "BaseOS/repodata" "AppStream/repodata")
    
    for metadata_dir in "${metadata_dirs[@]}"; do
        local full_metadata_path="$MOUNT_POINT/$metadata_dir"
        if [[ -d "$full_metadata_path" ]]; then
            log_info "Found metadata directory: $metadata_dir"
            rsync -av "$full_metadata_path/" "$repodata_dir/"
            # Fix permissions for copied metadata files
            find "$repodata_dir" -type f -exec chmod 644 {} \;
            find "$repodata_dir" -type d -exec chmod 755 {} \;
        fi
    done
    
    # Unmount ISO
    sudo umount "$MOUNT_POINT"
    
    # Create/update repository metadata
    log_info "Creating repository metadata..."
    if ! createrepo --update "$repo_dir"; then
        log_error "Failed to create repository metadata"
        return 1
    fi
    
    # Create repository configuration file
    local repo_config="$repo_dir/newstartos-$version_key.repo"
    local baseurl
    
    # Generate baseurl based on type
    case $baseurl_type in
        file)
            baseurl="file://$repo_dir"
            ;;
        http|https)
            baseurl="$baseurl_prefix/$version_key"
            ;;
    esac
    
    cat > "$repo_config" << EOF
[newstartos-$version_key]
name=NewStart OS $version - \$basearch
baseurl=$baseurl
enabled=1
gpgcheck=0
priority=1

[newstartos-$version_key-updates]
name=NewStart OS $version Updates - \$basearch
baseurl=$baseurl
enabled=1
gpgcheck=0
priority=1
EOF
    
    # Create repository information file
    local repo_info="$repo_dir/REPO_INFO.txt"
    cat > "$repo_info" << EOF
NewStart OS YUM Repository
==========================

Version: $version
Architecture: $architecture
Created: $(date)
Source ISO: $iso_filename
Package Count: $rpm_count

Repository Configuration:
- Copy $repo_config to /etc/yum.repos.d/
- Or use: yum-config-manager --add-repo file://$repo_dir

Usage Examples:
- yum search <package>
- yum install <package>
- yum update

Local Mount Command:
sudo mount --bind $repo_dir /var/local-repo
EOF
    
    log_success "Repository created successfully: $repo_dir"
    log_info "Repository info: $repo_info"
    log_info "Repository config: $repo_config"
    
    return 0
}

# Clean function - remove downloaded ISOs and created repositories
clean_repos() {
    log_info "Cleaning NewStart OS repositories and ISOs..."
    
    # Remove yum repositories
    if [[ -d "$YUM_REPO_DIR" ]]; then
        log_info "Removing repository directory: $YUM_REPO_DIR"
        rm -rf "$YUM_REPO_DIR"
        log_success "Repository directory removed"
    else
        log_info "Repository directory does not exist: $YUM_REPO_DIR"
    fi
    
    # Remove ISO files
    if [[ -d "$ISO_DIR" ]]; then
        log_info "Removing ISO directory: $ISO_DIR"
        rm -rf "$ISO_DIR"
        log_success "ISO directory removed"
    else
        log_info "ISO directory does not exist: $ISO_DIR"
    fi
    
    log_success "Clean completed successfully"
}

# Main function
main() {
    local versions=()
    local baseurl_type="file"
    local baseurl_prefix=""
    local clean_mode=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            clean)
                clean_mode=true
                shift
                ;;
            --baseurl-type)
                baseurl_type="$2"
                shift 2
                ;;
            --baseurl-type=*)
                baseurl_type="${1#*=}"
                shift
                ;;
            --baseurl-prefix)
                baseurl_prefix="$2"
                shift 2
                ;;
            --baseurl-prefix=*)
                baseurl_prefix="${1#*=}"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                versions+=("$1")
                shift
                ;;
        esac
    done
    
    # Handle clean mode
    if [[ "$clean_mode" == "true" ]]; then
        clean_repos
        return 0
    fi
    
    # Default versions if none specified
    if [[ ${#versions[@]} -eq 0 ]]; then
        versions=("v6.06.11b10" "v7.02.03b9")
    fi
    
    # Validate baseurl_type
    case $baseurl_type in
        file|http|https)
            ;;
        *)
            log_error "Invalid baseurl type: $baseurl_type. Must be 'file', 'http', or 'https'"
            exit 1
            ;;
    esac
    
    # Set default baseurl_prefix for http/https if not provided
    if [[ "$baseurl_type" != "file" && -z "$baseurl_prefix" ]]; then
        log_error "baseurl-prefix is required when using http/https baseurl type"
        log_info "Example: --baseurl-type=http --baseurl-prefix=http://repo.example.com/newstartos"
        exit 1
    fi
    
    log_info "NewStart OS YUM Repository Creator"
    log_info "=================================="
    
    # Check dependencies
    if ! check_dependencies; then
        exit 1
    fi
    
    # Create base repository directory
    mkdir -p "$YUM_REPO_DIR"
    
    # Process each version
    local success_count=0
    local total_count=${#versions[@]}
    
    for version in "${versions[@]}"; do
        log_info "Processing version $version..."
        if create_version_repo "$version" "$baseurl_type" "$baseurl_prefix"; then
            ((success_count++))
        else
            log_error "Failed to create repository for version $version"
        fi
        echo
    done
    
    # Summary
    log_info "Repository creation completed"
    log_info "Success: $success_count/$total_count versions"
    
    if [[ $success_count -gt 0 ]]; then
        log_success "YUM repositories created in: $YUM_REPO_DIR"
        log_info "Next steps:"
        log_info "1. Review repository configurations in each version directory"
        log_info "2. Copy .repo files to /etc/yum.repos.d/ in your NewStart OS containers"
        log_info "3. Run 'yum clean all && yum makecache' to refresh repository cache"
    fi
    
    return $((total_count - success_count))
}

# Show usage information
usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS] [version1] [version2] ...

Create YUM repositories from NewStart OS ISO files.

COMMANDS:
  clean                        Clean all repositories and downloaded ISOs
  [versions...]               Create repositories for specified versions (default)

OPTIONS:
  --baseurl-type TYPE         Set baseurl type: file (default), http, https
  --baseurl-prefix PREFIX     Base URL prefix for http/https (required for http/https)
  -h, --help                 Show this help message

Available versions:
  v6.06.11b10    NewStart OS V6.06.11B10
  v7.02.03b9     NewStart OS V7.02.03B9

Examples:
  $0                                    # Create repositories for all versions (file baseurl)
  $0 v6.06.11b10                        # Create repository for V6.06.11B10 only
  $0 --baseurl-type=http --baseurl-prefix=http://repo.example.com/newstartos v6.06.11b10
  $0 --baseurl-type=https --baseurl-prefix=https://repo.example.com/newstartos
  $0 clean                              # Clean all repositories and ISOs

Requirements:
  - ISO files will be downloaded to: $ISO_DIR/
  - Dependencies: jq, createrepo_c, rsync, wget/curl, numfmt
  - Root privileges for mounting ISO files
  - For container usage: Docker and Docker Compose

Container Usage:
  Use scripts/build-repo-docker.sh for containerized builds:
  - ./scripts/build-repo-docker.sh build [OPTIONS] [versions...]
  - ./scripts/build-repo-docker.sh clean
  - ./scripts/build-repo-docker.sh shell

Output:
  - Repositories created in: $YUM_REPO_DIR/
  - Each version gets its own subdirectory
  - Repository configuration files (.repo) included
EOF
}

# Handle help flag
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

# Run main function
main "$@"

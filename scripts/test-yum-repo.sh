#!/bin/bash

# Test YUM repository functionality in NewStart OS Docker container
# This script validates local filesystem yum source configuration and operations

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
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

# Test yum repository in container
test_yum_repo() {
    local version="$1"
    local image_tag="$2"
    local repo_path="$YUM_REPO_DIR/$version"
    
    log_info "Testing YUM repository for version: $version"
    
    # Check if repository exists
    if [[ ! -d "$repo_path" ]]; then
        log_error "Repository not found: $repo_path"
        log_info "Please run ./scripts/create-yum-repo.sh first"
        return 1
    fi
    
    # Check if Docker image exists
    if ! docker image inspect "$image_tag" &>/dev/null; then
        log_error "Docker image not found: $image_tag"
        log_info "Please build the NewStart OS Docker image first"
        return 1
    fi
    
    local container_name="newstartos-yum-test-$version"
    local test_script="/tmp/yum-test-script.sh"
    
    # Create test script for container
    cat > "$test_script" << 'EOF'
#!/bin/bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

VERSION="$1"
REPO_PATH="/var/yum-repo/$VERSION"

log_info "=== YUM Repository Test in Container ==="
log_info "Version: $VERSION"
log_info "Repository Path: $REPO_PATH"

# Check if repository directory is mounted
if [[ ! -d "$REPO_PATH" ]]; then
    log_error "Repository directory not found: $REPO_PATH"
    exit 1
fi

# Check repository contents
PKG_COUNT=$(find "$REPO_PATH/Packages" -name "*.rpm" 2>/dev/null | wc -l || echo "0")
log_info "Found $PKG_COUNT RPM packages in repository"

if [[ $PKG_COUNT -eq 0 ]]; then
    log_error "No RPM packages found in repository"
    exit 1
fi

# Configure YUM repository
log_info "Configuring YUM repository..."
cat > /etc/yum.repos.d/newstartos-local.repo << EOL
[newstartos-local]
name=NewStart OS Local Repository - $VERSION
baseurl=file://$REPO_PATH
enabled=1
gpgcheck=0
priority=1
skip_if_unavailable=1

[newstartos-local-updates]
name=NewStart OS Local Updates - $VERSION
baseurl=file://$REPO_PATH
enabled=1
gpgcheck=0
priority=1
skip_if_unavailable=1
EOL

log_success "Repository configuration created"

# Test YUM operations
log_info "Testing YUM operations..."

# Clean and make cache
log_info "Cleaning YUM cache..."
yum clean all >/dev/null 2>&1 || true

log_info "Making YUM cache..."
if ! yum makecache 2>/dev/null; then
    log_error "Failed to make YUM cache"
    exit 1
fi

# List repositories
log_info "Listing YUM repositories..."
yum repolist 2>/dev/null | grep -E "(newstartos-local|repo id)" || true

# Search for common packages
log_info "Testing package search..."
SEARCH_PACKAGES=("gcc" "python" "bash" "glibc" "kernel")
FOUND_PACKAGES=0

for pkg in "${SEARCH_PACKAGES[@]}"; do
    if yum search "$pkg" 2>/dev/null | grep -q "$pkg"; then
        log_success "Found package: $pkg"
        ((FOUND_PACKAGES++))
    else
        log_warning "Package not found: $pkg"
    fi
done

log_info "Found $FOUND_PACKAGES/${#SEARCH_PACKAGES[@]} test packages"

# Test package information
log_info "Testing package info command..."
if yum info bash >/dev/null 2>&1; then
    log_success "Package info command works"
else
    log_warning "Package info command failed"
fi

# Test dependency resolution
log_info "Testing dependency resolution..."
if yum deplist bash >/dev/null 2>&1; then
    log_success "Dependency resolution works"
else
    log_warning "Dependency resolution failed"
fi

# List available packages (limited output)
log_info "Listing available packages (first 10)..."
yum list available 2>/dev/null | head -20 || true

# Test whatprovides
log_info "Testing whatprovides functionality..."
if yum whatprovides "*/bin/bash" >/dev/null 2>&1; then
    log_success "Whatprovides functionality works"
else
    log_warning "Whatprovides functionality failed"
fi

# Summary
log_info "=== Test Summary ==="
log_success "YUM repository test completed successfully"
log_info "Repository is properly configured and functional"
log_info "Found $PKG_COUNT RPM packages"
log_info "Found $FOUND_PACKAGES/${#SEARCH_PACKAGES[@]} common packages"

# Optional: Test package installation (commented out to avoid system changes)
# log_info "Testing package installation (dry-run)..."
# yum install --assumeno bash-completion 2>/dev/null || log_info "Dry-run installation test completed"

exit 0
EOF

    chmod +x "$test_script"
    
    # Remove existing container if it exists
    docker rm -f "$container_name" 2>/dev/null || true
    
    # Run test in container
    log_info "Starting container: $container_name"
    if docker run --rm \
        --name "$container_name" \
        -v "$YUM_REPO_DIR:/var/yum-repo:ro" \
        -v "$test_script:/tmp/test-script.sh:ro" \
        "$image_tag" \
        /tmp/test-script.sh "$version"; then
        log_success "YUM repository test passed for $version"
        return 0
    else
        log_error "YUM repository test failed for $version"
        return 1
    fi
}

# Test package installation
test_package_installation() {
    local version="$1"
    local image_tag="$2"
    local test_package="$3"
    local repo_path="$YUM_REPO_DIR/$version"
    
    log_info "Testing package installation: $test_package"
    
    local container_name="newstartos-install-test-$version"
    local install_script="/tmp/install-test.sh"
    
    # Create installation test script
    cat > "$install_script" << EOF
#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "\${BLUE}[INFO]\${NC} \$1"; }
log_success() { echo -e "\${GREEN}[SUCCESS]\${NC} \$1"; }
log_error() { echo -e "\${RED}[ERROR]\${NC} \$1"; }

VERSION="\$1"
PACKAGE="\$2"
REPO_PATH="/var/yum-repo/\$VERSION"

log_info "=== Package Installation Test ==="
log_info "Package: \$PACKAGE"
log_info "Version: \$VERSION"

# Configure repository
cat > /etc/yum.repos.d/newstartos-local.repo << EOL
[newstartos-local]
name=NewStart OS Local Repository
baseurl=file://\$REPO_PATH
enabled=1
gpgcheck=0
priority=1
skip_if_unavailable=1
EOL

# Clean cache and make cache
yum clean all >/dev/null 2>&1
yum makecache >/dev/null 2>&1

# Check if package is available
if ! yum list available "\$PACKAGE" >/dev/null 2>&1; then
    log_error "Package \$PACKAGE is not available in repository"
    exit 1
fi

log_info "Package \$PACKAGE is available"

# Test installation (dry-run first)
log_info "Testing installation (dry-run)..."
if yum install --assumeno "\$PACKAGE" 2>&1 | grep -q "Nothing to do\|Complete"; then
    log_success "Package installation dry-run successful"
else
    log_info "Dry-run completed (expected behavior)"
fi

# Actual installation test
log_info "Attempting actual installation..."
if yum install -y "\$PACKAGE" >/dev/null 2>&1; then
    log_success "Package \$PACKAGE installed successfully"
    
    # Verify installation
    if rpm -q "\$PACKAGE" >/dev/null 2>&1; then
        log_success "Package \$PACKAGE verified in RPM database"
    else
        log_error "Package \$PACKAGE not found in RPM database after installation"
        exit 1
    fi
else
    log_error "Failed to install package \$PACKAGE"
    exit 1
fi

log_success "Package installation test completed successfully"
EOF

    chmod +x "$install_script"
    
    # Remove existing container
    docker rm -f "$container_name" 2>/dev/null || true
    
    # Run installation test
    if docker run --rm \
        --name "$container_name" \
        -v "$YUM_REPO_DIR:/var/yum-repo:ro" \
        -v "$install_script:/tmp/install-test.sh:ro" \
        "$image_tag" \
        /tmp/install-test.sh "$version" "$test_package"; then
        log_success "Package installation test passed: $test_package"
        return 0
    else
        log_error "Package installation test failed: $test_package"
        return 1
    fi
}

# Main function
main() {
    local version="${1:-v6.06.11b10}"
    local test_type="${2:-basic}"
    
    log_info "NewStart OS YUM Repository Test"
    log_info "==============================="
    log_info "Version: $version"
    log_info "Test Type: $test_type"
    
    # Determine image tag based on version
    local image_tag
    case "$version" in
        "v6.06.11b10")
            image_tag="newstartos:v6.06.11b10"
            ;;
        "v7.02.03b9")
            image_tag="newstartos:v7.02.03b9"
            ;;
        *)
            log_error "Unsupported version: $version"
            log_info "Supported versions: v6.06.11b10, v7.02.03b9"
            exit 1
            ;;
    esac
    
    # Check prerequisites
    if ! command -v docker &>/dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker info &>/dev/null; then
        log_error "Docker daemon is not running or not accessible"
        exit 1
    fi
    
    # Run tests based on type
    case "$test_type" in
        "basic")
            if test_yum_repo "$version" "$image_tag"; then
                log_success "Basic YUM repository test completed successfully"
            else
                log_error "Basic YUM repository test failed"
                exit 1
            fi
            ;;
        "install")
            local test_packages=("bash-completion" "wget" "curl")
            local success_count=0
            
            for pkg in "${test_packages[@]}"; do
                if test_package_installation "$version" "$image_tag" "$pkg"; then
                    ((success_count++))
                fi
            done
            
            log_info "Installation tests completed: $success_count/${#test_packages[@]} successful"
            
            if [[ $success_count -eq ${#test_packages[@]} ]]; then
                log_success "All package installation tests passed"
            else
                log_warning "Some package installation tests failed"
                exit 1
            fi
            ;;
        "full")
            log_info "Running full test suite..."
            
            # Basic test
            if ! test_yum_repo "$version" "$image_tag"; then
                log_error "Basic test failed"
                exit 1
            fi
            
            # Installation test
            if ! test_package_installation "$version" "$image_tag" "wget"; then
                log_error "Installation test failed"
                exit 1
            fi
            
            log_success "Full test suite completed successfully"
            ;;
        *)
            log_error "Unknown test type: $test_type"
            log_info "Available test types: basic, install, full"
            exit 1
            ;;
    esac
    
    # Cleanup
    rm -f /tmp/yum-test-script.sh /tmp/install-test.sh
    
    log_success "YUM repository testing completed successfully"
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [version] [test_type]

Test YUM repository functionality in NewStart OS Docker containers.

Arguments:
  version     Version to test (default: v6.06.11b10)
              Available: v6.06.11b10, v7.02.03b9
  
  test_type   Type of test to run (default: basic)
              basic   - Basic YUM operations test
              install - Package installation test
              full    - Complete test suite

Examples:
  $0                          # Basic test for v6.06.11b10
  $0 v6.06.11b10 basic        # Basic test for specific version
  $0 v6.06.11b10 install      # Installation test
  $0 v6.06.11b10 full         # Full test suite

Prerequisites:
  - Docker installed and running
  - NewStart OS Docker image built
  - YUM repository created (run create-yum-repo.sh first)

Output:
  - Test results with colored output
  - Success/failure status for each test
  - Summary of test execution
EOF
}

# Handle help flag
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

# Run main function
main "$@"

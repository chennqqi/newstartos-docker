#!/bin/bash

# NewStart OS Podman兼容构建脚本
# 修复BuildKit兼容性问题

set -euo pipefail

# 陷阱处理，确保清理工作
trap cleanup EXIT

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 配置文件
CONFIG_FILE="$PROJECT_ROOT/config/build-config.json"

# 全局变量
BUILD_CACHE_DIR=""
TEMP_FILES=()

# 清理函数
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Build failed with exit code $exit_code. Cleaning up..."
    fi
    
    # 清理临时文件
    for temp_file in "${TEMP_FILES[@]}"; do
        if [[ -f "$temp_file" ]]; then
            rm -f "$temp_file"
            log_info "Removed temp file: $temp_file"
        fi
    done
}

# 添加临时文件到清理列表
add_temp_file() {
    TEMP_FILES+=("$1")
}

# 日志函数
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

# 检查依赖（Podman兼容）
check_dependencies() {
    log_info "Checking dependencies for Podman..."
    
    # 检查容器引擎
    if command -v podman &> /dev/null; then
        CONTAINER_ENGINE="podman"
        log_success "Using Podman as container engine"
    elif command -v docker &> /dev/null; then
        CONTAINER_ENGINE="docker"
        log_success "Using Docker as container engine"
    else
        log_error "Neither Podman nor Docker is installed"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Please install jq for JSON parsing"
        exit 1
    fi
    
    if ! $CONTAINER_ENGINE info &> /dev/null; then
        log_error "$CONTAINER_ENGINE daemon is not running"
        exit 1
    fi
    
    # 对于Podman，不启用BuildKit相关功能
    if [[ "$CONTAINER_ENGINE" == "podman" ]]; then
        log_info "Podman detected - BuildKit features disabled"
        USE_BUILDKIT=false
    else
        export DOCKER_BUILDKIT=1
        USE_BUILDKIT=true
        log_info "Docker detected - BuildKit features enabled"
    fi
    
    log_success "Dependencies check passed"
}

# 加载配置
load_config() {
    log_info "Loading build configuration..."
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    # 读取配置
    DEFAULT_VERSION=$(jq -r '.newstart_os.default_version' "$CONFIG_FILE")
    VERSION=${BUILD_VERSION:-$DEFAULT_VERSION}
    
    # 验证版本是否存在
    if ! jq -e ".newstart_os.versions[\"$VERSION\"]" "$CONFIG_FILE" >/dev/null 2>&1; then
        log_error "Version $VERSION not found in configuration"
        log_info "Available versions:"
        jq -r '.newstart_os.versions | keys[]' "$CONFIG_FILE" | while read -r ver; do
            log_info "  - $ver"
        done
        exit 1
    fi
    
    # 读取版本特定配置
    ISO_FILENAME=$(jq -r ".newstart_os.versions[\"$VERSION\"].iso_filename" "$CONFIG_FILE")
    VERSION_NAME=$(jq -r ".newstart_os.versions[\"$VERSION\"].version" "$CONFIG_FILE")
    ARCHITECTURE=$(jq -r ".newstart_os.versions[\"$VERSION\"].architecture" "$CONFIG_FILE")
    TAG_PREFIX=$(jq -r ".newstart_os.versions[\"$VERSION\"].tag_prefix" "$CONFIG_FILE")
    
    log_success "Configuration loaded: $VERSION_NAME ($ARCHITECTURE) - Version: $VERSION"
}

# 检查ISO文件
check_iso_file() {
    log_info "Checking ISO file..."
    
    local iso_path="$PROJECT_ROOT/iso/$ISO_FILENAME"
    
    if [[ -f "$iso_path" ]]; then
        local actual_size=$(stat -c%s "$iso_path" 2>/dev/null || stat -f%z "$iso_path" 2>/dev/null)
        local size_gb=$(echo "scale=1; $actual_size/1024/1024/1024" | bc -l 2>/dev/null || echo "$((actual_size / 1024 / 1024 / 1024))")
        log_success "ISO file found: $iso_path (${size_gb}GB)"
        return 0
    else
        log_error "ISO file not found: $iso_path"
        return 1
    fi
}

# 创建Podman兼容的Dockerfile
create_podman_dockerfile() {
    local original_dockerfile="$1"
    local podman_dockerfile="$2"
    
    log_info "Creating Podman-compatible Dockerfile..."
    
    # 移除BuildKit特定的语法
    sed 's/--mount=[^\\]*//' "$original_dockerfile" > "$podman_dockerfile.tmp"
    
    # 替换为传统的COPY指令
    cat > "$podman_dockerfile" << EOF
# NewStart OS Docker Image - Podman Compatible
# Build arguments for version support
ARG BUILD_VERSION=v6.06.11b10
ARG ISO_FILENAME

# Stage 1: ISO extraction and package preparation
FROM debian:bookworm-slim AS iso-processor

# Install required tools for package extraction
RUN apt-get update && \\
    DEBIAN_FRONTEND=noninteractive apt-get install -y \\
        squashfs-tools \\
        genisoimage \\
        xorriso \\
        rpm \\
        createrepo-c \\
        rsync \\
        tar \\
        gzip \\
        xz-utils \\
        util-linux \\
        cpio \\
        file \\
        bash \\
        coreutils \\
        procps \\
        && apt-get clean && \\
        rm -rf /var/lib/apt/lists/*

# Create essential directories structure
RUN mkdir -p /{bin,boot,dev,etc,home,lib,lib64,media,mnt,opt,proc,root,run,sbin,srv,sys,tmp,usr,var} \\
    && mkdir -p /usr/{bin,lib,lib64,sbin,share,local} \\
    && mkdir -p /var/{lib,log,cache,run,spool,tmp} \\
    && mkdir -p /etc/{sysconfig,init.d,rc.d} \\
    && mkdir -p /tmp/{extract,packages,iso-content}

# Copy ISO file (traditional method for Podman)
COPY iso/\${ISO_FILENAME} /tmp/newstart.iso

# Extract and process ISO in optimized RUN layer
RUN set -ex; \\
    echo "Extracting ISO contents..."; \\
    xorriso -osirrox on -indev /tmp/newstart.iso -extract / /tmp/iso-content/ && \\
    \\
    echo "Processing extracted content..."; \\
    rsync -a /tmp/iso-content/ /tmp/extract/ && \\
    \\
    echo "Collecting RPM packages..."; \\
    find /tmp/extract -name "*.rpm" -exec cp {} /tmp/packages/ \\; 2>/dev/null || true && \\
    \\
    if [ -f /tmp/extract/LiveOS/squashfs.img ]; then \\
        echo "Extracting squashfs..."; \\
        unsquashfs -d /tmp/squashfs-root /tmp/extract/LiveOS/squashfs.img && \\
        rsync -a /tmp/squashfs-root/ /tmp/extract/ && \\
        rm -rf /tmp/squashfs-root; \\
    fi && \\
    \\
    echo "Cleaning up intermediate files..."; \\
    rm -f /tmp/newstart.iso && \\
    rm -rf /tmp/iso-content && \\
    \\
    echo "Setting up RPM database..."; \\
    rpm --initdb && \\
    \\
    echo "Installing essential packages..."; \\
    find /tmp/packages -name "*.rpm" -exec rpm -ivh --nodeps --root / {} \\; 2>/dev/null || true && \\
    \\
    echo "NewStart OS \${BUILD_VERSION}" > /etc/issue && \\
    echo "NewStart OS \${BUILD_VERSION}" > /etc/os-release && \\
    echo "NewStart OS \${BUILD_VERSION}" > /etc/redhat-release && \\
    \\
    echo '#!/bin/bash\\n\\
echo "Starting NewStart OS Optimized '"'\${BUILD_VERSION}'"' container..."\\n\\
\\n\\
mkdir -p /var/run /var/lock /tmp /var/tmp\\n\\
\\n\\
if [ -f /etc/init.d/sshd ]; then\\n\\
    /etc/init.d/sshd start\\n\\
fi\\n\\
\\n\\
exec "\$@"' > /usr/local/bin/init.sh && \\
    chmod +x /usr/local/bin/init.sh && \\
    \\
    echo "Final cleanup..."; \\
    rm -rf /tmp/packages

# Stage 2: Final optimized image from scratch
FROM scratch

# Set comprehensive metadata
LABEL maintainer="NewStart OS Team"
LABEL description="NewStart OS Optimized Docker Image - Podman Compatible"
LABEL version="\${BUILD_VERSION}"
LABEL architecture="x86_64"
LABEL vendor="NewStart OS"
LABEL variant="optimized"
LABEL build.optimized="true"
LABEL build.engine="podman-compatible"

# Copy the complete prepared and optimized system root
COPY --from=iso-processor / /

# Set environment variables optimized for minimal resources
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV LANG="C"
ENV LC_ALL="C"
ENV TERM="xterm"
ENV NEWSTART_VERSION="\${BUILD_VERSION}"

# Expose SSH port
EXPOSE 22

# Optimized health check for minimal resource usage
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \\
    CMD test -x /usr/local/bin/init.sh || exit 1

# Default command - use optimized init script
CMD ["/usr/local/bin/init.sh", "/bin/bash"]
EOF

    add_temp_file "$podman_dockerfile"
    log_success "Podman-compatible Dockerfile created"
}

# 构建优化版本（Podman兼容）
build_optimized_podman() {
    log_info "Building optimized version with Podman compatibility..."
    
    local original_dockerfile="$PROJECT_ROOT/dockerfiles/optimized/Dockerfile"
    local podman_dockerfile="$PROJECT_ROOT/dockerfiles/optimized/Dockerfile.podman"
    local tag="newstartos:${TAG_PREFIX}-optimized"
    
    # 创建Podman兼容的Dockerfile
    create_podman_dockerfile "$original_dockerfile" "$podman_dockerfile"
    
    log_info "Building with tag: $tag"
    log_info "Using ISO file: $ISO_FILENAME"
    log_info "Container engine: $CONTAINER_ENGINE"
    
    # 设置构建超时（2小时，因为Podman可能比Docker慢一些）
    local build_timeout=7200
    
    if timeout $build_timeout $CONTAINER_ENGINE build -f "$podman_dockerfile" \
        --build-arg BUILD_VERSION="$VERSION" \
        --build-arg ISO_FILENAME="$ISO_FILENAME" \
        -t "$tag" "$PROJECT_ROOT"; then
        log_success "Optimized version built successfully: $tag"
        
        # 显示镜像信息
        $CONTAINER_ENGINE images "$tag"
        
        # 显示存储使用情况
        log_info "Storage usage:"
        $CONTAINER_ENGINE system df || true
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            log_error "Build timeout after $build_timeout seconds"
        else
            log_error "Failed to build optimized version (exit code: $exit_code)"
        fi
        exit 1
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
Usage: $0 [OPTION] [TARGET] [VERSION]

Build NewStart OS Docker images with Podman compatibility.

TARGETS:
    optimized    Build volume-optimized version (recommended for Podman)

VERSIONS:
    v6.06.11b10  Build NewStart OS V6.06.11B10
    v7.02.03b9   Build NewStart OS 7.02.03B9

OPTIONS:
    -h, --help   Show this help message
    -v, --version Show version information

EXAMPLES:
    $0 optimized v6.06.11b10     # Build optimized version for V6.06.11B10

EOF
}

# 主函数
main() {
    local target="optimized"  # 默认只构建优化版本
    local version=""
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "NewStart OS Podman Builder v1.0.0"
                exit 0
                ;;
            optimized)
                target="$1"
                shift
                ;;
            v6.06.11b10|v7.02.03b9)
                version="$1"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    if [[ -z "$version" ]]; then
        log_warning "No version specified, using default version"
    else
        export BUILD_VERSION="$version"
    fi
    
    log_info "Starting NewStart OS Podman-compatible build process..."
    log_info "Target: $target"
    log_info "Version: ${BUILD_VERSION:-default}"
    
    # 检查依赖
    check_dependencies
    
    # 加载配置
    load_config
    
    # 检查ISO文件
    if ! check_iso_file; then
        log_error "ISO file is required for building"
        exit 1
    fi
    
    # 构建镜像
    build_optimized_podman
    
    log_success "Build process completed successfully!"
    log_info "You can now run: $CONTAINER_ENGINE run --privileged -it newstartos:${TAG_PREFIX}-optimized"
}

# 执行主函数
main "$@"
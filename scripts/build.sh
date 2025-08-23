#!/bin/bash

# NewStart OS Docker镜像构建脚本
# 支持从scratch构建标准版本和体积优化版本

set -euo pipefail

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

# 检查依赖
check_dependencies() {
    log_info "Checking dependencies..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Please install jq for JSON parsing"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running or user is not in docker group"
        exit 1
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
    DOWNLOAD_URL=$(jq -r ".newstart_os.versions[\"$VERSION\"].download_url" "$CONFIG_FILE")
    EXPECTED_SIZE=$(jq -r ".newstart_os.versions[\"$VERSION\"].expected_size_bytes" "$CONFIG_FILE")
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
        
        if [[ "$actual_size" == "$EXPECTED_SIZE" ]]; then
            log_success "ISO file found and size matches: $iso_path"
            return 0
        else
            log_warning "ISO file size mismatch. Expected: $EXPECTED_SIZE, Actual: $actual_size"
            return 1
        fi
    else
        log_warning "ISO file not found: $iso_path"
        return 1
    fi
}

# 下载ISO文件
download_iso() {
    log_info "Downloading ISO file from: $DOWNLOAD_URL"
    
    local iso_path="$PROJECT_ROOT/iso/$ISO_FILENAME"
    local temp_path="$iso_path.tmp"
    
    # 创建iso目录
    mkdir -p "$(dirname "$iso_path")"
    
    # 下载文件
    if curl -L -o "$temp_path" "$DOWNLOAD_URL"; then
        # 验证大小
        local actual_size=$(stat -c%s "$temp_path" 2>/dev/null || stat -f%z "$temp_path" 2>/dev/null)
        
        if [[ "$actual_size" == "$EXPECTED_SIZE" ]]; then
            mv "$temp_path" "$iso_path"
            log_success "ISO file downloaded successfully: $iso_path"
        else
            rm -f "$temp_path"
            log_error "Downloaded file size mismatch. Expected: $EXPECTED_SIZE, Actual: $actual_size"
            exit 1
        fi
    else
        rm -f "$temp_path"
        log_error "Failed to download ISO file"
        exit 1
    fi
}

# 构建标准版本
build_standard() {
    log_info "Building standard version..."
    
    local dockerfile="$PROJECT_ROOT/dockerfiles/standard/Dockerfile"
    local tag="newstartos:${TAG_PREFIX}-standard"
    
    if [[ ! -f "$dockerfile" ]]; then
        log_error "Standard Dockerfile not found: $dockerfile"
        exit 1
    fi
    
    log_info "Building with tag: $tag"
    
    if docker build -f "$dockerfile" -t "$tag" "$PROJECT_ROOT"; then
        log_success "Standard version built successfully: $tag"
        
        # 显示镜像信息
        docker images "$tag"
    else
        log_error "Failed to build standard version"
        exit 1
    fi
}

# 构建优化版本
build_optimized() {
    log_info "Building optimized version..."
    
    local dockerfile="$PROJECT_ROOT/dockerfiles/optimized/Dockerfile"
    local tag="newstartos:${TAG_PREFIX}-optimized"
    
    if [[ ! -f "$dockerfile" ]]; then
        log_error "Optimized Dockerfile not found: $dockerfile"
        exit 1
    fi
    
    log_info "Building with tag: $tag"
    
    if docker build -f "$dockerfile" -t "$tag" "$PROJECT_ROOT"; then
        log_success "Optimized version built successfully: $tag"
        
        # 显示镜像信息
        docker images "$tag"
    else
        log_error "Failed to build optimized version"
        exit 1
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
Usage: $0 [OPTION] [TARGET] [VERSION]

Build NewStart OS Docker images from scratch.

TARGETS:
    standard     Build standard version
    optimized    Build volume-optimized version
    all          Build both versions

VERSIONS:
    v6.06.11b10  Build NewStart OS V6.06.11B10
    v7.02.03b9   Build NewStart OS 7.02.03B9

OPTIONS:
    -h, --help   Show this help message
    -v, --version Show version information

EXAMPLES:
    $0 standard v6.06.11b10     # Build standard version for V6.06.11B10
    $0 optimized v7.02.03b9     # Build optimized version for 7.02.03B9
    $0 all v6.06.11b10          # Build both versions for V6.06.11B10

EOF
}

# 主函数
main() {
    local target=""
    local version=""
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "NewStart OS Docker Builder v1.0.0"
                exit 0
                ;;
            standard|optimized|all)
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
    
    if [[ -z "$target" ]]; then
        log_error "No target specified"
        show_help
        exit 1
    fi
    
    if [[ -z "$version" ]]; then
        log_warning "No version specified, using default version"
    else
        export BUILD_VERSION="$version"
    fi
    
    log_info "Starting NewStart OS Docker image build process..."
    log_info "Target: $target"
    log_info "Version: ${BUILD_VERSION:-default}"
    
    # 检查依赖
    check_dependencies
    
    # 加载配置
    load_config
    
    # 检查或下载ISO文件
    if ! check_iso_file; then
        download_iso
    fi
    
    # 构建镜像
    case "$target" in
        standard)
            build_standard
            ;;
        optimized)
            build_optimized
            ;;
        all)
            build_standard
            build_optimized
            ;;
    esac
    
    log_success "Build process completed successfully!"
}

# 执行主函数
main "$@"

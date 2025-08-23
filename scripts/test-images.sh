#!/bin/bash

# NewStart OS Docker镜像测试脚本
# 测试构建的镜像是否正常工作

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
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

# 加载配置
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    # 获取默认版本或使用指定版本
    local version=${BUILD_VERSION:-$(jq -r '.newstart_os.default_version' "$CONFIG_FILE")}
    
    # 验证版本是否存在
    if ! jq -e ".newstart_os.versions[\"$version\"]" "$CONFIG_FILE" >/dev/null 2>&1; then
        log_error "Version $version not found in configuration"
        exit 1
    fi
    
    TAG_PREFIX=$(jq -r ".newstart_os.versions[\"$version\"].tag_prefix" "$CONFIG_FILE")
    VERSION_NAME=$(jq -r ".newstart_os.versions[\"$version\"].version" "$CONFIG_FILE")
    
    log_info "Using version: $VERSION_NAME ($version) with tag prefix: $TAG_PREFIX"
}

# 测试镜像基本信息
test_image_info() {
    local image_tag="$1"
    local test_name="$2"
    
    log_info "Testing $test_name: $image_tag"
    
    # 检查镜像是否存在
    if ! docker image inspect "$image_tag" >/dev/null 2>&1; then
        log_error "Image not found: $image_tag"
        return 1
    fi
    
    # 显示镜像信息
    log_info "Image details:"
    docker image inspect "$image_tag" | jq '.[0] | {Id, RepoTags, Size, Architecture, Os, Created}'
    
    # 检查镜像大小
    local size=$(docker image inspect "$image_tag" | jq -r '.[0].Size')
    local size_mb=$((size / 1024 / 1024))
    log_info "Image size: ${size_mb}MB"
    
    return 0
}

# 测试容器启动
test_container_startup() {
    local image_tag="$1"
    local test_name="$2"
    local container_name="test-${test_name}-$$"
    
    log_info "Testing container startup for $test_name"
    
    # 启动容器
    if docker run -d --name "$container_name" --privileged "$image_tag"; then
        log_success "Container started successfully: $container_name"
        
        # 等待系统启动
        sleep 10
        
        # 检查容器状态
        if docker ps | grep -q "$container_name"; then
            log_success "Container is running: $container_name"
            
            # 测试基本命令
            if docker exec "$container_name" systemctl --version >/dev/null 2>&1; then
                log_success "systemctl command works in $test_name"
            else
                log_warning "systemctl command failed in $test_name"
            fi
            
            # 测试shell
            if docker exec "$container_name" bash -c "echo 'Hello from $test_name'" >/dev/null 2>&1; then
                log_success "Shell access works in $test_name"
            else
                log_warning "Shell access failed in $test_name"
            fi
            
            # 停止并删除容器
            docker stop "$container_name" >/dev/null 2>&1 || true
            docker rm "$container_name" >/dev/null 2>&1 || true
            
            return 0
        else
            log_error "Container failed to start: $container_name"
            docker logs "$container_name" || true
            docker rm "$container_name" >/dev/null 2>&1 || true
            return 1
        fi
    else
        log_error "Failed to start container: $container_name"
        return 1
    fi
}

# 测试网络连接
test_network() {
    local image_tag="$1"
    local test_name="$2"
    local container_name="test-net-${test_name}-$$"
    
    log_info "Testing network connectivity for $test_name"
    
    # 启动容器
    if docker run -d --name "$container_name" --privileged "$image_tag"; then
        # 等待系统启动
        sleep 10
        
        # 测试网络配置
        if docker exec "$container_name" ip addr show >/dev/null 2>&1; then
            log_success "Network configuration works in $test_name"
        else
            log_warning "Network configuration failed in $test_name"
        fi
        
        # 测试DNS解析
        if docker exec "$container_name" nslookup google.com >/dev/null 2>&1; then
            log_success "DNS resolution works in $test_name"
        else
            log_warning "DNS resolution failed in $test_name"
        fi
        
        # 清理
        docker stop "$container_name" >/dev/null 2>&1 || true
        docker rm "$container_name" >/dev/null 2>&1 || true
        
        return 0
    else
        log_error "Failed to start container for network test: $container_name"
        return 1
    fi
}

# 运行所有测试
run_all_tests() {
    local standard_tag="newstartos:${TAG_PREFIX}-standard"
    local optimized_tag="newstartos:${TAG_PREFIX}-optimized"
    
    log_info "Starting comprehensive image testing..."
    
    # 测试标准版本
    log_info "=== Testing Standard Version ==="
    if test_image_info "$standard_tag" "Standard"; then
        test_container_startup "$standard_tag" "Standard"
        test_network "$standard_tag" "Standard"
    fi
    
    echo ""
    
    # 测试优化版本
    log_info "=== Testing Optimized Version ==="
    if test_image_info "$optimized_tag" "Optimized"; then
        test_container_startup "$optimized_tag" "Optimized"
        test_network "$optimized_tag" "Optimized"
    fi
    
    echo ""
    
    log_info "=== Testing Summary ==="
    log_info "Standard version: $standard_tag"
    log_info "Optimized version: $optimized_tag"
    
    # 显示镜像列表
    log_info "Available images:"
    docker images | grep newstartos || log_warning "No NewStart OS images found"
}

# 显示帮助信息
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Test NewStart OS Docker images for functionality and compatibility.

OPTIONS:
    -h, --help    Show this help message
    -v, --version Show version information
    --quick       Run quick tests only
    --full        Run full comprehensive tests

EXAMPLES:
    $0              # Run all tests
    $0 --quick      # Run quick tests only
    $0 --full       # Run full tests

EOF
}

# 主函数
main() {
    local test_mode="full"
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "NewStart OS Image Tester v1.0.0"
                exit 0
                ;;
            --quick)
                test_mode="quick"
                shift
                ;;
            --full)
                test_mode="full"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    log_info "NewStart OS Docker Image Testing Tool"
    log_info "Test mode: $test_mode"
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running or user is not in docker group"
        exit 1
    fi
    
    # 加载配置
    load_config
    
    # 运行测试
    if [[ "$test_mode" == "quick" ]]; then
        log_info "Running quick tests..."
        # 只运行基本镜像信息测试
        local standard_tag="newstartos:${TAG_PREFIX}-standard"
        local optimized_tag="newstartos:${TAG_PREFIX}-optimized"
        
        test_image_info "$standard_tag" "Standard"
        test_image_info "$optimized_tag" "Optimized"
    else
        run_all_tests
    fi
    
    log_success "Testing completed!"
}

# 执行主函数
main "$@"

#!/bin/bash

# NewStart OS快速测试脚本
# 测试Alpine基础镜像和基本功能

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

# 测试Alpine基础镜像
test_alpine_base() {
    log_info "Testing Alpine base image..."
    
    # 测试Alpine镜像拉取
    if docker pull alpine:3.19; then
        log_success "Alpine 3.19 image pulled successfully"
    else
        log_error "Failed to pull Alpine 3.19 image"
        return 1
    fi
    
    # 测试Alpine基本功能
    if docker run --rm alpine:3.19 echo "Alpine test successful"; then
        log_success "Alpine basic functionality test passed"
    else
        log_error "Alpine basic functionality test failed"
        return 1
    fi
    
    # 测试Alpine包管理
    if docker run --rm alpine:3.19 sh -c "apk update && apk add --no-cache curl"; then
        log_success "Alpine package management test passed"
    else
        log_error "Alpine package management test failed"
        return 1
    fi
    
    return 0
}

# 测试Docker构建环境
test_docker_build() {
    log_info "Testing Docker build environment..."
    
    # 检查Docker版本
    local docker_version=$(docker --version)
    log_info "Docker version: $docker_version"
    
    # 检查Docker BuildKit
    if docker buildx version >/dev/null 2>&1; then
        log_success "Docker BuildKit is available"
    else
        log_warning "Docker BuildKit not available, using legacy builder"
    fi
    
    # 测试简单构建
    local test_dockerfile="/tmp/test-alpine.Dockerfile"
    cat > "$test_dockerfile" << 'EOF'
FROM alpine:3.19
RUN apk add --no-cache curl
CMD ["echo", "Test build successful"]
EOF
    
    if docker build -f "$test_dockerfile" -t test-alpine /tmp; then
        log_success "Simple Docker build test passed"
        docker rmi test-alpine >/dev/null 2>&1 || true
    else
        log_error "Simple Docker build test failed"
        rm -f "$test_dockerfile"
        return 1
    fi
    
    rm -f "$test_dockerfile"
    return 0
}

# 测试项目配置
test_project_config() {
    log_info "Testing project configuration..."
    
    local config_file="$PROJECT_ROOT/config/build-config.json"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        return 1
    fi
    
    # 检查JSON格式
    if jq . "$config_file" >/dev/null 2>&1; then
        log_success "Configuration file JSON format is valid"
    else
        log_error "Configuration file JSON format is invalid"
        return 1
    fi
    
    # 检查必要字段
    local required_fields=("newstart_os" "docker" "build" "packages")
    for field in "${required_fields[@]}"; do
        if jq -e ".$field" "$config_file" >/dev/null 2>&1; then
            log_success "Required field '$field' found in configuration"
        else
            log_error "Required field '$field' missing from configuration"
            return 1
        fi
    done
    
    # 显示配置摘要
    log_info "Configuration summary:"
    local version=$(jq -r '.newstart_os.version' "$config_file")
    local arch=$(jq -r '.newstart_os.architecture' "$config_file")
    local base_image=$(jq -r '.build.base_image' "$config_file")
    
    log_info "  NewStart OS Version: $version"
    log_info "  Architecture: $arch"
    log_info "  Base Image: $base_image"
    
    return 0
}

# 测试ISO文件
test_iso_file() {
    log_info "Testing ISO file..."
    
    local iso_file="$PROJECT_ROOT/iso/NewStart-CGS-Linux-MAIN.V6.06.11B10-x86_64.dvd.iso"
    
    if [[ ! -f "$iso_file" ]]; then
        log_error "ISO file not found: $iso_file"
        return 1
    fi
    
    # 检查文件大小
    local file_size=$(stat -c%s "$iso_file" 2>/dev/null || stat -f%z "$iso_file" 2>/dev/null)
    local file_size_mb=$((file_size / 1024 / 1024))
    log_info "ISO file size: ${file_size_mb}MB"
    
    # 检查文件类型
    if command -v file &> /dev/null; then
        local file_type=$(file "$iso_file")
        log_info "ISO file type: $file_type"
    fi
    
    # 检查文件权限
    local file_perms=$(ls -la "$iso_file" | awk '{print $1}')
    log_info "ISO file permissions: $file_perms"
    
    log_success "ISO file test passed"
    return 0
}

# 运行所有测试
run_all_tests() {
    log_info "Starting comprehensive project testing..."
    
    local tests=(
        "test_alpine_base"
        "test_docker_build"
        "test_project_config"
        "test_iso_file"
    )
    
    local passed=0
    local total=${#tests[@]}
    
    for test in "${tests[@]}"; do
        log_info "Running test: $test"
        if "$test"; then
            log_success "Test passed: $test"
            ((passed++))
        else
            log_error "Test failed: $test"
        fi
        echo ""
    done
    
    log_info "=== Test Results ==="
    log_info "Total tests: $total"
    log_info "Passed: $passed"
    log_info "Failed: $((total - passed))"
    
    if [[ $passed -eq $total ]]; then
        log_success "All tests passed! Project is ready for building."
        return 0
    else
        log_error "Some tests failed. Please fix issues before building."
        return 1
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Quick test script for NewStart OS Docker project.

OPTIONS:
    -h, --help    Show this help message
    -v, --version Show version information
    --alpine      Test Alpine base image only
    --docker      Test Docker build environment only
    --config      Test project configuration only
    --iso         Test ISO file only

EXAMPLES:
    $0              # Run all tests
    $0 --alpine     # Test Alpine base image only
    $0 --docker     # Test Docker build environment only

EOF
}

# 主函数
main() {
    local test_type="all"
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "NewStart OS Quick Tester v1.0.0"
                exit 0
                ;;
            --alpine)
                test_type="alpine"
                shift
                ;;
            --docker)
                test_type="docker"
                shift
                ;;
            --config)
                test_type="config"
                shift
                ;;
            --iso)
                test_type="iso"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    log_info "NewStart OS Quick Testing Tool"
    log_info "Test type: $test_type"
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running or user is not in docker group"
        exit 1
    fi
    
    # 运行指定测试
    case "$test_type" in
        alpine)
            test_alpine_base
            ;;
        docker)
            test_docker_build
            ;;
        config)
            test_project_config
            ;;
        iso)
            test_iso_file
            ;;
        all)
            run_all_tests
            ;;
        *)
            log_error "Unknown test type: $test_type"
            exit 1
            ;;
    esac
    
    log_success "Testing completed!"
}

# 执行主函数
main "$@"

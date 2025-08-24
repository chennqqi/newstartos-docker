#!/bin/bash

# NewStart OS BuildKit缓存测试脚本
# 验证ISO处理缓存优化效果

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

# 测试BuildKit缓存功能
test_buildkit_cache() {
    log_info "Testing BuildKit cache optimization..."
    
    # 启用BuildKit
    export DOCKER_BUILDKIT=1
    export BUILDKIT_PROGRESS=plain
    
    # 检查BuildKit是否可用
    if docker buildx version &> /dev/null; then
        log_success "Docker BuildKit is available"
    else
        log_error "Docker BuildKit is not available"
        return 1
    fi
    
    # 检查ISO文件
    local iso_file="$PROJECT_ROOT/iso/NewStart-CGS-Linux-MAIN.V6.06.11B10-x86_64.dvd.iso"
    if [[ ! -f "$iso_file" ]]; then
        log_error "ISO file not found: $iso_file"
        return 1
    fi
    
    local file_size=$(stat -c%s "$iso_file" 2>/dev/null || stat -f%z "$iso_file" 2>/dev/null)
    local file_size_gb=$((file_size / 1024 / 1024 / 1024))
    log_info "ISO file size: ${file_size_gb}GB"
    
    return 0
}

# 测试缓存挂载
test_cache_mount() {
    log_info "Testing cache mount functionality..."
    
    # 创建测试Dockerfile
    local test_dockerfile="$PROJECT_ROOT/test-cache.Dockerfile"
    cat > "$test_dockerfile" << 'EOF'
FROM debian:bookworm-slim

# Test cache mount
RUN --mount=type=cache,target=/tmp/test-cache \
    echo "Testing cache mount..." && \
    echo "Cache test $(date)" > /tmp/test-cache/test.txt && \
    ls -la /tmp/test-cache/

CMD ["echo", "Cache test completed"]
EOF
    
    # 构建测试镜像
    if docker build -f "$test_dockerfile" -t cache-test "$PROJECT_ROOT"; then
        log_success "Cache mount test passed"
        docker rmi cache-test >/dev/null 2>&1 || true
        rm -f "$test_dockerfile"
        return 0
    else
        log_error "Cache mount test failed"
        rm -f "$test_dockerfile"
        return 1
    fi
}

# 显示缓存统计
show_cache_stats() {
    log_info "Docker cache statistics:"
    
    # 显示系统空间使用
    docker system df
    
    # 显示构建缓存
    if docker buildx du >/dev/null 2>&1; then
        log_info "BuildKit cache usage:"
        docker buildx du
    else
        log_warning "BuildKit cache information not available"
    fi
}

# 清理缓存（可选）
cleanup_cache() {
    log_info "Cleaning up Docker cache..."
    
    # 清理未使用的构建缓存
    docker builder prune -f
    
    # 显示清理后的状态
    docker system df
}

# 主函数
main() {
    local action="test"
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean)
                action="clean"
                shift
                ;;
            --stats)
                action="stats"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    log_info "NewStart OS BuildKit Cache Testing Tool"
    
    case "$action" in
        test)
            log_info "Running cache tests..."
            test_buildkit_cache
            test_cache_mount
            show_cache_stats
            ;;
        stats)
            show_cache_stats
            ;;
        clean)
            cleanup_cache
            ;;
    esac
    
    log_success "Cache testing completed!"
}

# 执行主函数
main "$@"
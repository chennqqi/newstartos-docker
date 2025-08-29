#!/bin/bash

# NewStart OS ISO文件处理工具
# 提供ISO文件下载、验证和提取功能

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
    
    # 支持版本参数
    local version=${1:-$(jq -r '.newstart_os.default_version' "$CONFIG_FILE")}
    
    # 验证版本是否存在
    if ! jq -e ".newstart_os.versions[\"$version\"]" "$CONFIG_FILE" >/dev/null 2>&1; then
        log_error "Version $version not found in configuration"
        log_info "Available versions:"
        jq -r '.newstart_os.versions | keys[]' "$CONFIG_FILE" | while read -r ver; do
            log_info "  - $ver"
        done
        exit 1
    fi
    
    ISO_FILENAME=$(jq -r ".newstart_os.versions[\"$version\"].iso_filename" "$CONFIG_FILE")
    DOWNLOAD_URL=$(jq -r ".newstart_os.versions[\"$version\"].download_url" "$CONFIG_FILE")
    EXPECTED_SIZE=$(jq -r ".newstart_os.versions[\"$version\"].expected_size_bytes" "$CONFIG_FILE")
    VERSION_NAME=$(jq -r ".newstart_os.versions[\"$version\"].version" "$CONFIG_FILE")
    TAG_PREFIX=$(jq -r ".newstart_os.versions[\"$version\"].tag_prefix" "$CONFIG_FILE")
    
    log_info "Loaded configuration for version: $VERSION_NAME ($version)"
}

# 验证ISO文件
verify_iso() {
    local iso_path="$1"
    
    if [[ ! -f "$iso_path" ]]; then
        log_error "ISO file not found: $iso_path"
        return 1
    fi
    
    local actual_size=$(stat -c%s "$iso_path" 2>/dev/null || stat -f%z "$iso_path" 2>/dev/null)
    
    if [[ "$actual_size" == "$EXPECTED_SIZE" ]]; then
        log_success "ISO file verification passed: $iso_path"
        log_info "Size: $actual_size bytes"
        return 0
    else
        log_error "ISO file size mismatch"
        log_info "Expected: $EXPECTED_SIZE bytes"
        log_info "Actual: $actual_size bytes"
        return 1
    fi
}

# 下载ISO文件
download_iso() {
    local iso_path="$PROJECT_ROOT/iso/$ISO_FILENAME"
    local temp_path="$iso_path.tmp"
    
    log_info "Downloading ISO file from: $DOWNLOAD_URL"
    log_info "Target path: $iso_path"
    
    # 创建iso目录
    mkdir -p "$(dirname "$iso_path")"
    
    # 下载文件
    if curl -L -o "$temp_path" "$DOWNLOAD_URL"; then
        # 验证大小
        if verify_iso "$temp_path"; then
            mv "$temp_path" "$iso_path"
            log_success "ISO file downloaded successfully"
            return 0
        else
            rm -f "$temp_path"
            log_error "Downloaded file verification failed"
            return 1
        fi
    else
        rm -f "$temp_path"
        log_error "Failed to download ISO file"
        return 1
    fi
}

# 提取ISO内容
extract_iso() {
    local iso_path="$PROJECT_ROOT/iso/$ISO_FILENAME"
    local extract_dir="$PROJECT_ROOT/build-cache/extract"
    
    if [[ ! -f "$iso_path" ]]; then
        log_error "ISO file not found: $iso_path"
        return 1
    fi
    
    log_info "Extracting ISO content to: $extract_dir"
    
    # 创建提取目录
    mkdir -p "$extract_dir"
    
    # 挂载ISO文件
    local mount_point="/tmp/iso-mount-$$"
    mkdir -p "$mount_point"
    
    if mount -o loop "$iso_path" "$mount_point" 2>/dev/null; then
        # 复制内容
        rsync -av "$mount_point/" "$extract_dir/"
        umount "$mount_point"
        rmdir "$mount_point"
        
        log_success "ISO content extracted successfully"
        return 0
    else
        log_error "Failed to mount ISO file"
        rmdir "$mount_point" 2>/dev/null || true
        return 1
    fi
}

# 显示ISO信息
show_iso_info() {
    local iso_path="$PROJECT_ROOT/iso/$ISO_FILENAME"
    
    if [[ ! -f "$iso_path" ]]; then
        log_warning "ISO file not found: $iso_path"
        return 1
    fi
    
    log_info "ISO File Information:"
    log_info "Path: $iso_path"
    log_info "Version: $VERSION_NAME"
    log_info "Expected Size: $EXPECTED_SIZE bytes"
    
    local actual_size=$(stat -c%s "$iso_path" 2>/dev/null || stat -f%z "$iso_path" 2>/dev/null)
    log_info "Actual Size: $actual_size bytes"
    
    if [[ "$actual_size" == "$EXPECTED_SIZE" ]]; then
        log_success "Size verification: PASSED"
    else
        log_error "Size verification: FAILED"
    fi
    
    # 显示文件类型
    if command -v file &> /dev/null; then
        local file_type=$(file "$iso_path")
        log_info "File Type: $file_type"
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
Usage: $0 [COMMAND] [VERSION] [OPTIONS]

NewStart OS ISO file management utility.

COMMANDS:
    verify      Verify existing ISO file
    download    Download ISO file from official source
    extract     Extract ISO content to build cache
    info        Show ISO file information
    help        Show this help message

VERSIONS:
    v6.06.11b10  NewStart OS V6.06.11B10
    v7.02.03b9   NewStart OS 7.02.03B9

OPTIONS:
    -h, --help  Show help message

EXAMPLES:
    $0 verify v6.06.11b10          # Verify V6.06.11B10 ISO file
    $0 download v7.02.03b9         # Download V7.02.03B9 ISO file
    $0 extract v6.06.11b10         # Extract V6.06.11B10 ISO content
    $0 info v6.06.11b10            # Show V6.06.11B10 ISO information

EOF
}

# 主函数
main() {
    local command=""
    local version=""
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            verify|download|extract|info)
                command="$1"
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
    
    if [[ -z "$command" ]]; then
        log_error "No command specified"
        show_help
        exit 1
    fi
    
    # 加载配置
    load_config "$version"
    
    # 执行命令
    case "$command" in
        verify)
            verify_iso "$PROJECT_ROOT/iso/$ISO_FILENAME"
            ;;
        download)
            download_iso
            ;;
        extract)
            extract_iso
            ;;
        info)
            show_iso_info
            ;;
        *)
            log_error "Unknown command: $command"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"

#!/bin/bash

# NewStart OS Root Filesystem Creation Script
# Creates layer.tar.xz for simplified Docker image building
# Reference: rocky-linux/sig-cloud-instance-images

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
PACKAGES_FILE="$PROJECT_ROOT/packages.txt"

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
    log_info "Checking dependencies for rootfs creation..."
    
    local required_tools=("rpm" "tar" "xz" "mount" "umount")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "$tool is not installed"
            exit 1
        fi
    done
    
    # 检查是否有sudo权限
    if ! sudo -n true 2>/dev/null; then
        log_error "This script requires sudo privileges for mounting ISO"
        exit 1
    fi
    
    log_success "All required tools are available"
}

# 加载配置
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    local version=${1:-"v6.06.11b10"}
    
    if command -v jq &> /dev/null; then
        ISO_FILENAME=$(jq -r ".newstart_os.versions[\"$version\"].iso_filename" "$CONFIG_FILE" 2>/dev/null || echo "")
        VERSION_NAME=$(jq -r ".newstart_os.versions[\"$version\"].version" "$CONFIG_FILE" 2>/dev/null || echo "")
        TAG_PREFIX=$(jq -r ".newstart_os.versions[\"$version\"].tag_prefix" "$CONFIG_FILE" 2>/dev/null || echo "")
    fi
    
    # 如果jq失败或不存在，使用默认值
    if [[ -z "$ISO_FILENAME" ]]; then
        ISO_FILENAME="NewStart-CGS-Linux-MAIN.V6.06.11B10-x86_64.dvd.iso"
        VERSION_NAME="V6.06.11B10"
        TAG_PREFIX="v6.06.11b10"
    fi
    
    log_info "Loaded configuration for version: $VERSION_NAME ($version)"
}

# 挂载ISO文件
mount_iso() {
    local iso_path="$1"
    local mount_point="$2"
    
    log_info "Mounting ISO: $iso_path"
    sudo mkdir -p "$mount_point"
    sudo mount -o loop,ro "$iso_path" "$mount_point"
}

# 卸载ISO文件
umount_iso() {
    local mount_point="$1"
    
    if mountpoint -q "$mount_point" 2>/dev/null; then
        log_info "Unmounting ISO: $mount_point"
        # 尝试正常卸载
        if ! sudo umount "$mount_point" 2>/dev/null; then
            log_warning "Normal unmount failed, trying lazy unmount..."
            sudo umount -l "$mount_point" 2>/dev/null || true
        fi
        sudo rmdir "$mount_point" 2>/dev/null || true
    fi
}

# 安装包列表中的RPM包
install_packages_from_list() {
    local rootfs_dir="$1"
    local iso_mount="$2"
    local packages_file="$3"
    
    log_info "Installing packages from list: $packages_file"
    
    if [[ ! -f "$packages_file" ]]; then
        log_error "Packages file not found: $packages_file"
        return 1
    fi
    
    # 读取包列表（忽略注释和空行）
    local packages=()
    while IFS= read -r line; do
        # 跳过注释和空行
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        packages+=("$line")
    done < "$packages_file"
    
    log_info "Found ${#packages[@]} packages to install"
    
    # 为每个包查找并安装RPM文件
    local installed_count=0
    for pkg in "${packages[@]}"; do
        log_info "Looking for package: $pkg"
        
        # 在ISO中查找匹配的RPM包
        local rpm_files
        rpm_files=$(find "$iso_mount" -name "${pkg}-[0-9]*.rpm" 2>/dev/null | head -1)
        
        if [[ -n "$rpm_files" ]]; then
            log_info "Installing: $(basename "$rpm_files")"
            # 尝试安装包，包括依赖
            if sudo rpm --root "$rootfs_dir" -ivh --force "$rpm_files" &>/dev/null; then
                ((installed_count++))
            elif sudo rpm --root "$rootfs_dir" -ivh --nodeps --force "$rpm_files" &>/dev/null; then
                ((installed_count++))
                log_warning "Installed $(basename "$rpm_files") without dependencies"
            else
                log_warning "Failed to install: $(basename "$rpm_files")"
            fi
        else
            log_warning "Package not found: $pkg"
        fi
    done
    
    log_success "Successfully installed $installed_count packages"
}

# 创建根文件系统
create_rootfs() {
    local version="$1"
    local iso_path="$PROJECT_ROOT/iso/$ISO_FILENAME"
    local work_dir="$PROJECT_ROOT/build-cache/rootfs-$version"
    local rootfs_dir="$work_dir/rootfs"
    local iso_mount="$work_dir/iso-mount"
    local output_file="$PROJECT_ROOT/rootfs/newstartos-${TAG_PREFIX}-rootfs.tar.xz"
    local filelist_file="$PROJECT_ROOT/filelist.txt"
    
    log_info "Creating root filesystem for NewStart OS $VERSION_NAME"
    log_info "ISO file: $iso_path"
    log_info "Output: $output_file"
    
    # 检查ISO文件
    if [[ ! -f "$iso_path" ]]; then
        log_error "ISO file not found: $iso_path"
        exit 1
    fi
    
    # 清理和创建工作目录
    sudo rm -rf "$work_dir" 2>/dev/null || true
    mkdir -p "$rootfs_dir" "$(dirname "$output_file")"
    
    # 设置清理陷阱
    trap "umount_iso '$iso_mount'" EXIT
    
    # 挂载ISO
    mount_iso "$iso_path" "$iso_mount"
    
    # 创建基础目录结构
    log_info "Creating base directory structure..."
    sudo mkdir -p "$rootfs_dir"/{bin,boot,dev,etc,home,lib,lib64,media,mnt,opt,proc,root,run,sbin,srv,sys,tmp,usr,var}
    sudo mkdir -p "$rootfs_dir/usr"/{bin,lib,lib64,sbin,share,local}
    sudo mkdir -p "$rootfs_dir/var"/{lib,log,cache,run,spool,tmp}
    sudo mkdir -p "$rootfs_dir/etc"/{sysconfig,init.d,rc.d,systemd,yum.repos.d}
    
    # 初始化RPM数据库
    log_info "Initializing RPM database..."
    sudo rpm --root "$rootfs_dir" --initdb
    
    
    # 安装包列表中的包
    install_packages_from_list "$rootfs_dir" "$iso_mount" "$PACKAGES_FILE"
    
    # 创建基本的yum仓库配置
    log_info "Creating yum repository configuration..."
    sudo tee "$rootfs_dir/etc/yum.repos.d/newstartos.repo" > /dev/null << EOF
[newstartos-base]
name=NewStart OS Base Repository
baseurl=file:///media/repo
enabled=1
gpgcheck=0
EOF
    
    # 创建NewStart OS系统文件
    log_info "Creating NewStart OS system files..."
    sudo tee "$rootfs_dir/etc/os-release" > /dev/null << EOF
NAME="NewStart OS"
VERSION="$VERSION_NAME"
ID="newstartos"
VERSION_ID="$VERSION_NAME"
PRETTY_NAME="NewStart OS $VERSION_NAME"
ANSI_COLOR="0;31"
CPE_NAME="cpe:/o:newstart:os:$VERSION_NAME:GA:server"
HOME_URL="https://www.newstartos.com/"
BUG_REPORT_URL="https://www.newstartos.com/"
EOF
    
    echo "NewStart OS $VERSION_NAME" | sudo tee "$rootfs_dir/etc/redhat-release" > /dev/null
    echo "NewStart OS $VERSION_NAME" | sudo tee "$rootfs_dir/etc/issue" > /dev/null
    
    # 创建容器初始化脚本
    sudo mkdir -p "$rootfs_dir/usr/local/bin"
    sudo tee "$rootfs_dir/usr/local/bin/init.sh" > /dev/null << 'EOF'
#!/bin/bash
# NewStart OS Container Init Script
echo "Starting NewStart OS container..."

# Create necessary directories
mkdir -p /var/run /var/lock /tmp /var/tmp

# Start essential services if they exist
if [ -f /etc/init.d/sshd ]; then
    /etc/init.d/sshd start
fi

# Execute command
exec "$@"
EOF
    sudo chmod +x "$rootfs_dir/usr/local/bin/init.sh"
    
    # 生成文件列表
    log_info "Generating file list..."
    (cd "$rootfs_dir" && find . -type f | sort) > "$filelist_file"
    log_info "File list saved to: $filelist_file"
    
    # Create essential symlinks and directories
    log_info "Creating essential symlinks and directories..."
    sudo mkdir -p "$rootfs_dir/bin" "$rootfs_dir/sbin" "$rootfs_dir/lib" "$rootfs_dir/lib64"
    
    # Create critical symlinks for compatibility
    sudo ln -sf /usr/bin/bash "$rootfs_dir/bin/bash" 2>/dev/null || true
    sudo ln -sf /usr/bin/bash "$rootfs_dir/bin/sh" 2>/dev/null || true
    sudo ln -sf /usr/sbin/init "$rootfs_dir/sbin/init" 2>/dev/null || true
    
    # Copy ALL dynamic libraries from ISO to ensure completeness
    log_info "Copying all dynamic libraries from ISO..."
    
    # Copy all lib64 directories and files
    if [[ -d "$iso_mount/lib64" ]]; then
        sudo mkdir -p "$rootfs_dir/lib64"
        sudo cp -a "$iso_mount/lib64/"* "$rootfs_dir/lib64/" 2>/dev/null || true
    fi
    
    if [[ -d "$iso_mount/usr/lib64" ]]; then
        sudo mkdir -p "$rootfs_dir/usr/lib64"
        sudo cp -a "$iso_mount/usr/lib64/"* "$rootfs_dir/usr/lib64/" 2>/dev/null || true
    fi
    
    # Copy lib directories as well
    if [[ -d "$iso_mount/lib" ]]; then
        sudo mkdir -p "$rootfs_dir/lib"
        sudo cp -a "$iso_mount/lib/"* "$rootfs_dir/lib/" 2>/dev/null || true
    fi
    
    if [[ -d "$iso_mount/usr/lib" ]]; then
        sudo mkdir -p "$rootfs_dir/usr/lib"
        sudo cp -a "$iso_mount/usr/lib/"* "$rootfs_dir/usr/lib/" 2>/dev/null || true
    fi
    
    # Ensure critical system libraries are present
    log_info "Verifying critical system libraries..."
    for lib_pattern in "ld-linux*.so*" "libc.so*" "libdl.so*" "libpthread.so*" "libm.so*" "librt.so*"; do
        sudo find "$iso_mount" -name "$lib_pattern" -exec cp {} "$rootfs_dir/lib64/" \; 2>/dev/null || true
    done
    
    # 清理和优化
    log_info "Cleaning and optimizing rootfs..."
    # 移除Debian/Ubuntu相关配置（确保RHEL兼容性）
    sudo rm -rf "$rootfs_dir/etc/apt" 2>/dev/null || true
    sudo rm -rf "$rootfs_dir/etc/dpkg" 2>/dev/null || true
    sudo rm -rf "$rootfs_dir/var/lib/apt" 2>/dev/null || true
    sudo rm -rf "$rootfs_dir/var/lib/dpkg" 2>/dev/null || true
    
    # 标准清理
    sudo rm -rf "$rootfs_dir/usr/share/doc"/* 2>/dev/null || true
    sudo rm -rf "$rootfs_dir/usr/share/man"/* 2>/dev/null || true
    sudo rm -rf "$rootfs_dir/usr/share/info"/* 2>/dev/null || true
    sudo rm -rf "$rootfs_dir/var/cache"/* 2>/dev/null || true
    sudo rm -rf "$rootfs_dir/var/log"/* 2>/dev/null || true
    sudo rm -rf "$rootfs_dir/tmp"/* 2>/dev/null || true
    
    # 创建必要的设备节点和目录
    sudo mkdir -p "$rootfs_dir"/{dev,proc,sys,tmp,var/tmp,var/run,var/lock}
    
    # 卸载ISO
    umount_iso "$iso_mount"
    trap - EXIT
    
    # 打包rootfs
    log_info "Creating rootfs archive..."
    (cd "$rootfs_dir" && sudo tar -cJf "$output_file" --numeric-owner .)
    
    # 修改文件权限
    sudo chown "$USER:$USER" "$output_file"
    
    # 清理工作目录
    sudo rm -rf "$work_dir"
    
    local file_size
    file_size=$(du -h "$output_file" | cut -f1)
    log_success "Root filesystem created successfully: $output_file ($file_size)"
    log_success "File list saved to: $filelist_file"
}

# 显示帮助信息
show_help() {
    cat << EOF
Usage: $0 [VERSION]

Create NewStart OS root filesystem layer.tar.xz for Docker image building.

VERSIONS:
    v6.06.11b10  NewStart OS V6.06.11B10
    v7.02.03b9   NewStart OS 7.02.03B9

EXAMPLES:
    $0 v6.06.11b10     # Create rootfs for V6.06.11B10
    $0 v7.02.03b9      # Create rootfs for 7.02.03B9

EOF
}

# 主函数
main() {
    local version=""
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
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
        version="v6.06.11b10"
        log_warning "No version specified, using default: $version"
    fi
    
    log_info "Starting NewStart OS rootfs creation process..."
    log_info "Version: $version"
    
    # 检查依赖
    check_dependencies
    
    # 加载配置
    load_config "$version"
    
    # 创建rootfs
    create_rootfs "$version"
    
    log_success "Rootfs creation completed successfully!"
}

# 执行主函数
main "$@"

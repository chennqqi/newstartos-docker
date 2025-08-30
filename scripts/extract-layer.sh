#!/bin/bash

# Simple NewStart OS Layer Extraction Script
# Creates layer.tar.xz from existing Docker image

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 使用已构建的镜像创建layer
create_layer_from_image() {
    local image_name="newstartos:v6.06.11b10-optimized"
    local output_file="$PROJECT_ROOT/rootfs/newstartos-v6.06.11b10-rootfs.tar.xz"
    
    echo "Creating layer from existing image: $image_name"
    
    # 创建输出目录
    mkdir -p "$(dirname "$output_file")"
    
    # 从现有镜像导出rootfs
    echo "Exporting rootfs from container..."
    local container_id
    container_id=$(podman create "$image_name")
    
    # 导出并压缩
    echo "Creating compressed layer..."
    podman export "$container_id" | xz -9 > "$output_file"
    
    # 清理容器
    podman rm "$container_id"
    
    local file_size
    file_size=$(du -h "$output_file" | cut -f1)
    echo "Layer created successfully: $output_file ($file_size)"
}

# 主函数
main() {
    echo "Starting layer extraction from existing image..."
    create_layer_from_image
    echo "Layer extraction completed!"
}

main "$@"

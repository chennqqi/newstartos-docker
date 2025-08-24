#!/bin/bash

# 构建状态监控脚本

echo "=== NewStart OS 构建状态检查 ==="
echo "时间: $(date)"
echo ""

echo "1. 检查Podman进程:"
podman ps -a | grep -E "(build|newstartos)" || echo "  没有发现构建相关的容器"
echo ""

echo "2. 检查构建进程:"
ps aux | grep -E "(podman|build)" | grep -v grep | grep -v monitor || echo "  没有发现构建进程"
echo ""

echo "3. 检查镜像状态:"
podman images | grep newstartos || echo "  还没有构建完成的镜像"
echo ""

echo "4. 检查存储使用:"
podman system df
echo ""

echo "5. 检查临时文件:"
ls -la /home/chenq/dev/github.com/chennqqi/newstartos-docker/dockerfiles/optimized/ | grep podman || echo "  没有临时Dockerfile文件"
echo ""

echo "6. 系统资源:"
echo "  CPU: $(nproc) cores"
echo "  内存使用: $(free -h | awk 'NR==2{printf "%.1f/%.1f GB", $3/1024/1024, $2/1024/1024}')"
echo "  磁盘使用: $(df -h . | awk 'NR==2{print $3 "/" $2 " (" $5 ")"}')"
echo ""

echo "=== 状态检查完成 ==="
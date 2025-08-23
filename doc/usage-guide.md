# NewStart OS Docker镜像使用指南

## 快速开始

### 1. 环境准备

确保您的系统满足以下要求：
- Linux操作系统（推荐Ubuntu 20.04+、CentOS 8+或RHEL 8+）
- Docker 20.10+
- 至少10GB可用磁盘空间
- 网络连接（用于下载依赖）

### 2. 安装依赖

```bash
# 使用Makefile自动安装依赖
make install-deps

# 或手动安装
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y jq curl rsync squashfs-tools

# CentOS/RHEL
sudo yum install -y jq curl rsync squashfs-tools

# Fedora
sudo dnf install -y jq curl rsync squashfs-tools
```

### 3. 验证环境

```bash
# 检查项目状态
make status

# 检查依赖
make check-deps
```

## 构建镜像

### 构建标准版本

```bash
# 使用Makefile
make build-standard

# 或直接使用脚本
./scripts/build.sh standard
```

### 构建体积优化版本

```bash
# 使用Makefile
make build-optimized

# 或直接使用脚本
./scripts/build.sh optimized
```

### 构建所有版本

```bash
# 使用Makefile
make build-all

# 或直接使用脚本
./scripts/build.sh all
```

## 测试镜像

### 运行测试

```bash
# 运行完整测试
./scripts/test-images.sh

# 运行快速测试
./scripts/test-images.sh --quick

# 使用Makefile测试
make test
```

### 手动测试

```bash
# 启动标准版本容器
docker run -it --rm --privileged newstartos:v6.06.11b10-standard

# 启动优化版本容器
docker run -it --rm --privileged newstartos:v6.06.11b10-optimized

# 测试systemd功能
docker run -it --rm --privileged newstartos:v6.06.11b10-standard systemctl --version
```

## 使用Docker Compose

### 启动服务

```bash
# 启动所有服务
docker-compose up -d

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f
```

### 服务访问

- 标准版本SSH: `ssh -p 2222 root@localhost`
- 标准版本HTTP: `http://localhost:8080`
- 标准版本HTTPS: `https://localhost:8443`
- 优化版本SSH: `ssh -p 2223 root@localhost`

## 镜像管理

### 查看镜像信息

```bash
# 列出所有镜像
docker images | grep newstartos

# 查看镜像详情
docker image inspect newstartos:v6.06.11b10-standard

# 查看镜像大小
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep newstartos
```

### 清理镜像

```bash
# 清理构建缓存
make clean

# 完全清理（包括镜像）
make clean-all

# 手动清理特定镜像
docker rmi newstartos:v6.06.11b10-standard
docker rmi newstartos:v6.06.11b10-optimized
```

## 高级用法

### 自定义构建

1. 修改配置文件 `config/build-config.json`
2. 调整包列表和优化选项
3. 重新构建镜像

### 版本更新

1. 下载新版本的ISO文件
2. 更新配置文件中的版本信息
3. 重新构建镜像

### 故障排除

#### 常见问题

1. **构建失败**
   - 检查Docker服务状态
   - 确保有足够的磁盘空间
   - 检查网络连接

2. **容器启动失败**
   - 确保使用 `--privileged` 标志
   - 检查系统是否支持systemd
   - 查看容器日志

3. **ISO文件问题**
   - 验证ISO文件完整性
   - 重新下载ISO文件
   - 检查文件权限

#### 调试命令

```bash
# 查看构建日志
docker build --progress=plain -f dockerfiles/standard/Dockerfile .

# 进入容器调试
docker run -it --rm --privileged newstartos:v6.06.11b10-standard /bin/bash

# 查看系统信息
docker run --rm --privileged newstartos:v6.06.11b10-standard cat /etc/os-release
```

## 配置说明

### 配置文件结构

```json
{
  "newstart_os": {
    "version": "V6.06.11B10",
    "architecture": "x86_64",
    "iso_filename": "NewStart-CGS-Linux-MAIN.V6.06.11B10-x86_64.dvd.iso",
    "download_url": "https://nsosmirrors.gd-linux.com/CGSLV6/NDECGSL/V6.06.11/x86_64/NewStart-CGS-Linux-MAIN.V6.06.11B10-x86_64.dvd.iso",
    "expected_size_bytes": 3597217792
  },
  "docker": {
    "base_image": "scratch",
    "registry": "localhost",
    "namespace": "newstartos",
    "tag_prefix": "v6.06.11b10"
  }
}
```

### 环境变量

- `LANG`: 系统语言设置
- `LC_ALL`: 本地化设置
- `PATH`: 可执行文件路径

## 技术支持

如果遇到问题，请：

1. 查看项目文档
2. 检查错误日志
3. 验证环境配置
4. 提交Issue到项目仓库

## 许可证

本项目采用MIT许可证，详见[LICENSE](../LICENSE)文件。

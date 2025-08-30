# NewStart OS YUM Repository Builder - Docker版本

这个Docker容器提供了一个完整的环境来构建NewStart OS的YUM仓库，无需在主机系统上安装依赖。

## 功能特性

- 🐳 **容器化构建**: 无需在主机安装createrepo、jq等依赖
- 📦 **自动下载**: 从配置文件中的URL自动下载ISO文件
- 🔄 **智能缓存**: 基于文件大小验证，避免重复下载
- 🧹 **清理功能**: 支持清理下载的ISO和生成的仓库
- 🌐 **多种baseurl**: 支持file、http、https类型的baseurl
- 📁 **数据持久化**: ISO和仓库数据保存在主机目录

## 快速开始

### 1. 构建并运行（推荐）

使用提供的脚本：

```bash
# 构建所有版本的仓库
./scripts/build-repo-docker.sh build

# 构建特定版本
./scripts/build-repo-docker.sh build v6.06.11b10

# 使用HTTP baseurl
./scripts/build-repo-docker.sh build --baseurl-type=http --baseurl-prefix=http://repo.example.com/newstartos

# 清理所有数据
./scripts/build-repo-docker.sh clean

# 进入交互式shell
./scripts/build-repo-docker.sh shell
```

### 2. 使用Docker Compose

```bash
cd dockerfiles/yum-repo-builder

# 构建镜像
docker-compose build

# 运行构建
docker-compose run --rm yum-repo-builder /workspace/scripts/create-yum-repo.sh

# 交互式shell
docker-compose run --rm yum-repo-builder /bin/bash
```

### 3. 直接使用Docker

```bash
# 构建镜像
docker build -f dockerfiles/yum-repo-builder/Dockerfile -t newstartos-yum-builder .

# 运行构建
docker run --rm --privileged \
  -v $(pwd)/iso:/workspace/iso \
  -v $(pwd)/yum-repo:/workspace/yum-repo \
  -v $(pwd)/config:/workspace/config \
  newstartos-yum-builder /workspace/scripts/create-yum-repo.sh
```

## 目录结构

构建完成后，项目目录结构如下：

```
newstartos-docker/
├── iso/                          # ISO文件存储目录
│   ├── NewStart-CGS-Linux-MAIN.V6.06.11B10-x86_64.dvd.iso
│   └── NewStart-CGSL-7.02.03B9-x86_64-dvd.iso
├── yum-repo/                     # YUM仓库目录
│   ├── v6.06.11b10/
│   │   ├── Packages/             # RPM包
│   │   ├── repodata/             # 仓库元数据
│   │   ├── newstartos-v6.06.11b10.repo  # 仓库配置文件
│   │   └── REPO_INFO.txt         # 仓库信息
│   └── v7.02.03b9/
│       ├── Packages/
│       ├── repodata/
│       ├── newstartos-v7.02.03b9.repo
│       └── REPO_INFO.txt
└── dockerfiles/yum-repo-builder/
    ├── Dockerfile
    ├── docker-compose.yml
    └── README.md
```

## 配置说明

### baseurl类型

- **file** (默认): 生成本地文件路径
  ```
  baseurl=file:///path/to/repo
  ```

- **http**: 生成HTTP URL
  ```bash
  --baseurl-type=http --baseurl-prefix=http://repo.example.com/newstartos
  # 结果: baseurl=http://repo.example.com/newstartos/v6.06.11b10
  ```

- **https**: 生成HTTPS URL
  ```bash
  --baseurl-type=https --baseurl-prefix=https://secure-repo.example.com/newstartos
  # 结果: baseurl=https://secure-repo.example.com/newstartos/v6.06.11b10
  ```

### 清理功能

```bash
# 清理所有ISO文件和仓库
./scripts/build-repo-docker.sh clean

# 或者在容器内
/workspace/scripts/create-yum-repo.sh clean
```

## 系统要求

- Docker 和 Docker Compose
- 足够的磁盘空间（ISO文件总计约7GB+）
- 网络连接（用于下载ISO文件）

## 故障排除

### 1. 权限问题

如果遇到权限问题，确保Docker有足够权限：

```bash
# 添加用户到docker组
sudo usermod -aG docker $USER
# 重新登录或运行
newgrp docker
```

### 2. 磁盘空间不足

检查可用磁盘空间：

```bash
df -h .
```

每个ISO文件约3-4GB，确保有足够空间。

### 3. 网络问题

如果下载失败，可以：

1. 检查网络连接
2. 手动下载ISO文件到 `iso/` 目录
3. 重新运行构建命令

### 4. 挂载问题

如果看到"target is busy"错误，这通常是正常的清理警告，不影响功能。

## 高级用法

### 自定义配置

修改 `config/build-config.json` 来添加新版本或更改下载URL。

### 批量构建

```bash
# 构建多个特定版本
./scripts/build-repo-docker.sh build v6.06.11b10 v7.02.03b9
```

### 调试模式

```bash
# 进入容器shell进行调试
./scripts/build-repo-docker.sh shell

# 在容器内手动运行命令
/workspace/scripts/create-yum-repo.sh --help
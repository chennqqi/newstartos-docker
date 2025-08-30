# NewStart OS Docker镜像制作工程

本项目用于制作NewStart OS的Docker镜像，支持从scratch构建标准版本和体积优化版本。

## 项目结构

```
.
├── doc/                          # 项目文档
│   ├── requirements.md           # 需求文档
│   └── requirements-analysis.md  # 需求分析文档
├── docs/                         # 详细文档
│   └── YUM_REPO_README.md        # YUM源配置说明
├── dockerfiles/                  # Dockerfile目录
│   ├── standard/                 # 标准版本
│   └── optimized/                # 体积优化版本
├── scripts/                      # 构建脚本
│   ├── create-yum-repo.sh        # YUM源创建脚本
│   └── test-yum-repo.sh          # YUM源测试脚本
├── config/                       # 配置文件
├── yum-repo/                     # YUM源目录（生成）
└── README.md                     # 项目说明
```

## 快速开始

### 前置要求
- Docker 20.10+
- Linux环境（推荐Ubuntu 20.04+或CentOS 8+）
- 至少10GB可用磁盘空间

### 构建镜像

1. **构建标准版本**
```bash
./scripts/build.sh standard
```

2. **构建体积优化版本**
```bash
./scripts/build.sh optimized
```

3. **构建所有版本**
```bash
./scripts/build.sh all
```

### 创建YUM源

1. **创建所有版本的YUM源**
```bash
./scripts/create-yum-repo.sh
```

2. **创建特定版本的YUM源**
```bash
./scripts/create-yum-repo.sh v6.06.11b10
./scripts/create-yum-repo.sh v7.02.03b9
```

3. **测试YUM源功能**
```bash
# 基础测试
./scripts/test-yum-repo.sh v6.06.11b10 basic

# 包安装测试
./scripts/test-yum-repo.sh v6.06.11b10 install

# 完整测试套件
./scripts/test-yum-repo.sh v6.06.11b10 full
```

## 支持的版本

- **V6.06.11B10**: NewStart OS V6.06.11B10 x86_64
- **V7.02.03B9**: NewStart OS V7.02.03B9 x86_64

## 技术特性

### Docker镜像构建
- 从scratch构建，最小化基础镜像
- 支持systemd服务管理
- RHEL兼容的包管理系统
- 自动化构建和验证
- 支持版本更新和配置管理

### YUM源管理
- 从ISO自动提取RPM包和元数据
- 支持本地文件系统和HTTP源
- 多版本并行支持
- 完整的测试验证流程
- 详细的配置文档和使用说明

## 详细文档

- [YUM源配置说明](docs/YUM_REPO_README.md) - 详细的YUM源创建、配置和使用指南

## 许可证

本项目采用MIT许可证，详见[LICENSE](LICENSE)文件。

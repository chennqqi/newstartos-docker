# NewStart OS Docker镜像制作工程

本项目用于制作NewStart OS的Docker镜像，支持从scratch构建标准版本和体积优化版本。

## 项目结构

```
.
├── doc/                          # 项目文档
│   ├── requirements.md           # 需求文档
│   └── requirements-analysis.md  # 需求分析文档
├── dockerfiles/                  # Dockerfile目录
│   ├── standard/                 # 标准版本
│   └── optimized/                # 体积优化版本
├── scripts/                      # 构建脚本
├── config/                       # 配置文件
├── iso/                          # ISO文件目录
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

## 技术特性

- 从scratch构建，最小化基础镜像
- 支持systemd服务管理
- RHEL兼容的包管理系统
- 自动化构建和验证
- 支持版本更新和配置管理

## 许可证

本项目采用MIT许可证，详见[LICENSE](LICENSE)文件。

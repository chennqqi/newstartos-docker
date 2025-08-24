# NewStart OS Docker 构建优化指南

## 概述

本指南介绍了针对大型ISO文件（3.4GB-3.7GB）的构建优化措施，显著减少构建时间。

## 优化措施

### 1. BuildKit缓存挂载优化

#### 核心改进
- **避免重复复制ISO**：使用 `--mount=type=bind` 直接挂载ISO目录
- **智能缓存策略**：使用 `--mount=type=cache` 缓存提取结果
- **增量构建支持**：首次提取后，后续构建直接使用缓存

#### 技术实现
```dockerfile
RUN --mount=type=bind,source=iso,target=/mnt/iso,readonly \
    --mount=type=cache,target=/tmp/iso-cache,sharing=locked \
    set -ex; \
    # 检查缓存
    if [ -f "/tmp/iso-cache/${ISO_FILENAME}.extracted" ]; then \
        echo "Using cached ISO extraction..."; \
        # 使用缓存内容
    else \
        echo "Processing ISO file with cache optimization..."; \
        # 首次提取并缓存
    fi
```

### 2. 构建性能优化

#### 超时处理
- **构建超时**：设置3小时超时（10800秒）
- **错误处理**：区分超时错误和构建错误
- **重试机制**：支持构建失败后的智能重试

#### BuildKit支持
```bash
# 启用BuildKit
export DOCKER_BUILDKIT=1
export BUILDKIT_PROGRESS=plain

# 使用优化的构建命令
timeout $build_timeout docker build \
    --build-arg BUILD_VERSION="$VERSION" \
    --build-arg ISO_FILENAME="$ISO_FILENAME" \
    --progress=plain \
    -t "$tag" "$PROJECT_ROOT"
```

### 3. 存储优化

#### 缓存管理
- **持久化缓存**：ISO提取结果自动缓存
- **空间管理**：自动清理中间文件
- **共享锁机制**：避免并行构建冲突

#### 镜像层优化
- **单层处理**：将ISO处理合并到单个RUN层
- **即时清理**：提取后立即删除大型中间文件
- **最小化传输**：只复制必要的文件到最终镜像

## 使用方法

### 基本构建
```bash
# 构建优化版本（推荐）
./scripts/build.sh optimized v6.06.11b10

# 构建标准版本
./scripts/build.sh standard v6.06.11b10

# 构建所有版本
./scripts/build.sh all v6.06.11b10
```

### 缓存管理
```bash
# 查看缓存统计
./scripts/test-cache.sh --stats

# 清理构建缓存
./scripts/test-cache.sh --clean

# 测试缓存功能
./scripts/test-cache.sh
```

## 性能提升

### 首次构建
- **预期时间**：30-45分钟（取决于系统性能）
- **主要耗时**：ISO提取和RPM安装

### 后续构建
- **缓存命中**：5-10分钟
- **增量更新**：仅处理变更的层
- **空间节省**：避免重复存储ISO内容

## 故障排除

### 常见问题

#### 1. BuildKit不可用
```bash
# 检查BuildKit支持
docker buildx version

# 如果不可用，使用传统构建器
unset DOCKER_BUILDKIT
```

#### 2. 缓存空间不足
```bash
# 清理未使用的缓存
docker builder prune -f

# 查看空间使用
docker system df
```

#### 3. 构建超时
```bash
# 增加超时时间（在build.sh中修改）
local build_timeout=14400  # 4小时
```

### 监控构建进度
```bash
# 实时查看构建日志
docker build --progress=plain ...

# 监控系统资源
htop
iostat -x 1
```

## 配置参数

### 环境变量
- `DOCKER_BUILDKIT=1`：启用BuildKit
- `BUILDKIT_PROGRESS=plain`：显示详细进度
- `BUILD_VERSION`：指定构建版本

### 缓存配置
- **缓存目录**：`/tmp/iso-cache`
- **共享模式**：`sharing=locked`
- **缓存标记**：`${ISO_FILENAME}.extracted`

## 最佳实践

### 1. 预建准备
- 确保有足够的磁盘空间（至少15GB）
- 检查Docker daemon配置
- 验证ISO文件完整性

### 2. 构建策略
- 首选优化版本（镜像更小）
- 使用缓存进行增量构建
- 定期清理未使用的缓存

### 3. 性能监控
- 监控构建时间变化
- 跟踪缓存命中率
- 观察磁盘I/O性能

## 技术细节

### 缓存架构
```
项目根目录/
├── iso/                    # ISO文件目录（bind mount）
├── docker-cache/           # BuildKit缓存
└── /tmp/iso-cache/         # 提取结果缓存
    ├── extract/            # 提取的文件
    ├── packages/           # RPM包
    └── *.extracted         # 缓存标记
```

### 构建流程
1. **挂载检查**：检查ISO文件和缓存
2. **缓存验证**：验证提取缓存是否存在
3. **条件处理**：根据缓存状态选择处理路径
4. **增量构建**：仅处理变更的内容
5. **结果缓存**：保存提取结果供后续使用

这些优化措施将显著减少ISO复制时间，特别是在重复构建时效果明显。
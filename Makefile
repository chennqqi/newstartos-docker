# NewStart OS Docker镜像构建Makefile

.PHONY: help build-standard build-optimized build-all clean test verify-iso download-iso

# 默认目标
.DEFAULT_GOAL := help

# 变量定义
BUILD_SCRIPT := scripts/build.sh
ISO_SCRIPT := scripts/iso-utils.sh
CONFIG_FILE := config/build-config.json

# 帮助信息
help: ## 显示帮助信息
	@echo "NewStart OS Docker镜像构建工具"
	@echo ""
	@echo "可用目标:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "示例:"
	@echo "  make build-standard    # 构建标准版本"
	@echo "  make build-optimized   # 构建优化版本"
	@echo "  make build-all         # 构建所有版本"

# 检查依赖
check-deps: ## 检查构建依赖
	@echo "检查构建依赖..."
	@command -v docker >/dev/null 2>&1 || { echo "错误: 需要安装Docker"; exit 1; }
	@command -v jq >/dev/null 2>&1 || { echo "错误: 需要安装jq"; exit 1; }
	@docker info >/dev/null 2>&1 || { echo "错误: Docker守护进程未运行或用户不在docker组"; exit 1; }
	@echo "依赖检查通过"

# 验证ISO文件
verify-iso: ## 验证ISO文件完整性
	@echo "验证ISO文件..."
	@chmod +x $(ISO_SCRIPT)
	@$(ISO_SCRIPT) verify

# 下载ISO文件
download-iso: ## 下载ISO文件
	@echo "下载ISO文件..."
	@chmod +x $(ISO_SCRIPT)
	@$(ISO_SCRIPT) download

# 构建标准版本
build-standard: check-deps verify-iso ## 构建标准版本镜像
	@echo "构建标准版本镜像..."
	@chmod +x $(BUILD_SCRIPT)
	@$(BUILD_SCRIPT) standard

# 构建优化版本
build-optimized: check-deps verify-iso ## 构建体积优化版本镜像
	@echo "构建优化版本镜像..."
	@chmod +x $(BUILD_SCRIPT)
	@$(BUILD_SCRIPT) optimized

# 构建所有版本
build-all: check-deps verify-iso ## 构建所有版本镜像
	@echo "构建所有版本镜像..."
	@chmod +x $(BUILD_SCRIPT)
	@$(BUILD_SCRIPT) all

# 测试镜像
test: ## 测试构建的镜像
	@echo "测试镜像..."
	@echo "测试标准版本..."
	@docker run --rm --privileged newstartos:v6.06.11b10-standard systemctl --version || echo "标准版本测试失败"
	@echo "测试优化版本..."
	@docker run --rm --privileged newstartos:v6.06.11b10-optimized systemctl --version || echo "优化版本测试失败"

# 显示镜像信息
images: ## 显示构建的镜像信息
	@echo "已构建的镜像:"
	@docker images | grep newstartos || echo "未找到NewStart OS镜像"

# 清理构建缓存
clean: ## 清理构建缓存和临时文件
	@echo "清理构建缓存..."
	@rm -rf build-cache/
	@rm -rf .dockerignore
	@docker system prune -f || true
	@echo "清理完成"

# 完全清理
clean-all: clean ## 完全清理（包括镜像）
	@echo "完全清理..."
	@docker images | grep newstartos | awk '{print $$3}' | xargs -r docker rmi -f || true
	@echo "完全清理完成"

# 显示项目状态
status: ## 显示项目状态
	@echo "项目状态:"
	@echo "配置文件: $(CONFIG_FILE)"
	@if [ -f "$(CONFIG_FILE)" ]; then \
		echo "配置状态: 已加载"; \
		VERSION=$$(jq -r '.newstart_os.version' "$(CONFIG_FILE)" 2>/dev/null); \
		ARCH=$$(jq -r '.newstart_os.architecture' "$(CONFIG_FILE)" 2>/dev/null); \
		echo "NewStart OS版本: $$VERSION ($$ARCH)"; \
	else \
		echo "配置状态: 未找到"; \
	fi
	@echo ""
	@echo "ISO文件状态:"
	@$(ISO_SCRIPT) info 2>/dev/null || echo "ISO文件未验证"
	@echo ""
	@echo "Docker镜像状态:"
	@make images

# 安装依赖
install-deps: ## 安装构建依赖
	@echo "安装构建依赖..."
	@if command -v apk >/dev/null 2>&1; then \
		sudo apk update && sudo apk add --no-cache jq curl rsync squashfs-tools genisoimage xorriso rpm createrepo util-linux bash shadow; \
	elif command -v apt-get >/dev/null 2>&1; then \
		sudo apt-get update && sudo apt-get install -y jq curl rsync squashfs-tools genisoimage xorriso rpm createrepo; \
	elif command -v yum >/dev/null 2>&1; then \
		sudo yum install -y jq curl rsync squashfs-tools genisoimage xorriso rpm createrepo; \
	elif command -v dnf >/dev/null 2>&1; then \
		sudo dnf install -y jq curl rsync squashfs-tools genisoimage xorriso rpm createrepo; \
	else \
		echo "错误: 不支持的包管理器"; \
		exit 1; \
	fi
	@echo "依赖安装完成"

# 显示构建配置
config: ## 显示构建配置
	@echo "构建配置:"
	@if [ -f "$(CONFIG_FILE)" ]; then \
		jq . "$(CONFIG_FILE)"; \
	else \
		echo "配置文件未找到"; \
	fi

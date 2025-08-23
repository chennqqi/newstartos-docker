# NewStart OS Docker镜像制作需求

## 项目目标
开发制作NewStart OS Docker镜像的工程

## 核心需求
1. 从scratch生成标准NewStart OS Docker镜像
2. 从scratch生成标准NewStart OS Docker体积优化的镜像
3. 未来有新的镜像之后可以继续使用本项目制作新版本的docker镜像
4. 为了加速镜像构建，手动下载ISO文件，构建脚本默认从URL下载镜像后构建，如果本地已存在则不下载，但需检查大小是否一致

## 技术规格
- NewStart OS版本: V6.06.11B10-x86_64
- 系统架构: x86_64
- 系统类型: RHEL兼容，采用systemd
- ISO文件: NewStart-CGS-Linux-MAIN.V6.06.11B10-x86_64.dvd.iso
- 下载地址: https://nsosmirrors.gd-linux.com/CGSLV6/NDECGSL/V6.06.11/x86_64/NewStart-CGS-Linux-MAIN.V6.06.11B10-x86_64.dvd.iso

## 创建时间
2024年12月19日

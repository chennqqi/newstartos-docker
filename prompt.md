## 目标: 开放制作NewStart OS Docker镜像的工程

## 一些辅助信息供你参考
1. NewStart OS 维护当前目录下 名称为NewStart-CGS-Linux-MAIN.V6.06.11B10-x86_64.dvd.iso
2. NewStart OS 采用systemd，是RHEL兼容的系统

## 要求
1. 从scratch生成标准NewStart OS Docker镜像
2. 从scratch生成标准NewStart OS Docker体积优化的镜像
3. 未来有新的镜像之后可以继续使用本项目制作新版本的docker镜像
4. 为了加速镜像构建我已手动下载ISO，下载地址为https://nsosmirrors.gd-linux.com/CGSLV6/NDECGSL/V6.06.11/x86_64/NewStart-CGS-Linux-MAIN.V6.06.11B10-x86_64.dvd.iso; 构建脚本默认从URL下载镜像后构建，如果本地已存在则不下载，但需检查大小是否一致。

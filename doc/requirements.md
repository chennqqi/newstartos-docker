# NewStart OS Docker镜像制作需求

## 项目目标
开发制作NewStart OS Docker镜像的工程

## 用户需求记录

### 2024-08-30 需求1：分析和修复NewStart OS Docker镜像构建过程
- 从零开始分析NewStart OS Docker镜像构建
- 修复ISO处理问题
- 简化Dockerfile
- 使用Podman进行镜像验证
- 重点创建最小、高效、可重用的Docker镜像

### 2024-08-30 需求2：修复create-rootfs.sh脚本独立工作
- 修复create-rootfs.sh脚本使其能够独立工作
- 实现ISO挂载以访问RPM包
- 创建包含基本包的packages.txt
- 生成filelist.txt记录最终文件内容
- 包含yum/dnf、gcc、python、bind-utils等包

### 2024-08-30 需求3：继续完善独立根文件系统创建
- 验证独立创建的根文件系统功能
- 测试layer-based Docker镜像构建
- 确保所有必需包正确安装
- 生成完整的文件列表文档

## 技术规格
- NewStart OS版本: V6.06.11B10-x86_64
- 系统架构: x86_64
- 系统类型: RHEL兼容，采用systemd
- ISO文件: NewStart-CGS-Linux-MAIN.V6.06.11B10-x86_64.dvd.iso
- 下载地址: https://nsosmirrors.gd-linux.com/CGSLV6/NDECGSL/V6.06.11/x86_64/NewStart-CGS-Linux-MAIN.V6.06.11B10-x86_64.dvd.iso

### 2024-08-30 需求4：制作NewStart OS的yum源
**目标2: 制作NewStart OS的yum源**
> NewStartOS ISO较大，Docker制作完成之后可能需要在使用时安装一些RPM
从ISO中提取yum源，将数据提取到目录，作为yum源，在本项目中可以使用本地文件系统源，也可以发布到public s3上作为http源

要求:
1. 编写脚本来生成对应镜像的yum源目录；便于后续支持的镜像；
2. 当前同时支持制作当前两个版本镜像的yum源；
3. 编写README.md文件，说明源的配置说明；
4. 使用本地文件系统源，在NewStartOS docker容器中进行测试源；

## 创建时间
2024年12月19日

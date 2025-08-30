# NewStart OS YUM Repository Configuration Guide

本文档说明如何配置和使用从NewStart OS ISO提取的YUM源。

## 概述

NewStart OS YUM Repository提供了从官方ISO文件中提取的RPM包，支持在NewStart OS Docker容器中进行包管理操作。

## 支持的版本

- **V6.06.11B10**: NewStart OS V6.06.11B10 x86_64
- **V7.02.03B9**: NewStart OS V7.02.03B9 x86_64

## 目录结构

```
yum-repo/
├── v6.06.11b10/
│   ├── Packages/           # RPM包文件
│   ├── repodata/          # 仓库元数据
│   ├── newstartos-v6.06.11b10.repo  # 仓库配置文件
│   └── REPO_INFO.txt      # 仓库信息
├── v7.02.03b9/
│   ├── Packages/
│   ├── repodata/
│   ├── newstartos-v7.02.03b9.repo
│   └── REPO_INFO.txt
```

## 创建YUM源

### 前置条件

1. **系统依赖**：
   ```bash
   # RHEL/CentOS/NewStart OS
   sudo yum install -y jq createrepo rsync
   
   # 或者使用dnf
   sudo dnf install -y jq createrepo_c rsync
   ```

2. **ISO文件**：
   - 将NewStart OS ISO文件放置在项目根目录
   - 确保文件名与配置文件中的定义一致

### 执行脚本

```bash
# 创建所有版本的YUM源
./scripts/create-yum-repo.sh

# 创建特定版本的YUM源
./scripts/create-yum-repo.sh v6.06.11b10

# 创建多个指定版本
./scripts/create-yum-repo.sh v6.06.11b10 v7.02.03b9
```

## 配置YUM源

### 方法1: 复制仓库配置文件

```bash
# 复制对应版本的.repo文件到系统目录
sudo cp yum-repo/v6.06.11b10/newstartos-v6.06.11b10.repo /etc/yum.repos.d/

# 刷新仓库缓存
sudo yum clean all
sudo yum makecache
```

### 方法2: 手动创建配置文件

创建 `/etc/yum.repos.d/newstartos-local.repo`：

```ini
[newstartos-v6.06.11b10]
name=NewStart OS V6.06.11B10 - $basearch
baseurl=file:///path/to/yum-repo/v6.06.11b10
enabled=1
gpgcheck=0
priority=1

[newstartos-v6.06.11b10-updates]
name=NewStart OS V6.06.11B10 Updates - $basearch
baseurl=file:///path/to/yum-repo/v6.06.11b10
enabled=1
gpgcheck=0
priority=1
```

### 方法3: 使用yum-config-manager

```bash
# 添加本地仓库
sudo yum-config-manager --add-repo file:///path/to/yum-repo/v6.06.11b10
```

## Docker容器中的配置

### 挂载本地YUM源

```bash
# 启动容器时挂载yum源目录
docker run -it \
  -v /path/to/yum-repo:/var/yum-repo:ro \
  newstartos:v6.06.11b10 \
  /bin/bash
```

### 容器内配置

```bash
# 在容器内创建仓库配置
cat > /etc/yum.repos.d/local-repo.repo << EOF
[newstartos-local]
name=NewStart OS Local Repository
baseurl=file:///var/yum-repo/v6.06.11b10
enabled=1
gpgcheck=0
priority=1
EOF

# 刷新仓库缓存
yum clean all
yum makecache
```

## 使用示例

### 基本包管理操作

```bash
# 搜索包
yum search gcc
yum search python

# 查看包信息
yum info gcc
yum info python3

# 安装包
yum install -y gcc
yum install -y python3 python3-pip

# 更新包
yum update

# 列出可用包
yum list available

# 列出已安装包
yum list installed
```

### 依赖管理

```bash
# 查看包依赖
yum deplist gcc

# 查找提供特定文件的包
yum provides /usr/bin/gcc
yum whatprovides "*/libssl.so*"

# 查看包组
yum grouplist
yum groupinfo "Development Tools"
```

## 高级配置

### HTTP服务器配置

如果需要通过HTTP提供YUM源服务：

```bash
# 使用nginx提供HTTP服务
sudo yum install -y nginx

# 配置nginx
sudo cat > /etc/nginx/conf.d/yum-repo.conf << EOF
server {
    listen 8080;
    server_name localhost;
    root /path/to/yum-repo;
    autoindex on;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

# 启动nginx
sudo systemctl start nginx
sudo systemctl enable nginx
```

然后修改仓库配置使用HTTP URL：
```ini
baseurl=http://localhost:8080/v6.06.11b10
```

### S3配置示例

上传到AWS S3并配置HTTP访问：

```bash
# 上传到S3 (需要配置AWS CLI)
aws s3 sync yum-repo/ s3://your-bucket/newstartos-repo/ --acl public-read

# 仓库配置使用S3 URL
baseurl=https://your-bucket.s3.amazonaws.com/newstartos-repo/v6.06.11b10
```

## 故障排除

### 常见问题

1. **权限问题**：
   ```bash
   # 确保仓库目录有正确权限
   sudo chmod -R 755 /path/to/yum-repo
   ```

2. **SELinux问题**：
   ```bash
   # 设置SELinux上下文
   sudo setsebool -P httpd_can_network_connect 1
   sudo semanage fcontext -a -t httpd_exec_t "/path/to/yum-repo(/.*)?"
   sudo restorecon -R /path/to/yum-repo
   ```

3. **仓库缓存问题**：
   ```bash
   # 清理并重建缓存
   sudo yum clean all
   sudo yum clean metadata
   sudo yum makecache
   ```

4. **GPG签名问题**：
   ```bash
   # 临时禁用GPG检查
   yum install --nogpgcheck package-name
   
   # 或在仓库配置中设置
   gpgcheck=0
   ```

### 调试命令

```bash
# 查看仓库列表
yum repolist all

# 查看仓库详细信息
yum repoinfo newstartos-local

# 测试仓库连接
yum --enablerepo=newstartos-local list available

# 查看yum日志
tail -f /var/log/yum.log
```

## 维护和更新

### 更新仓库

```bash
# 重新创建仓库元数据
createrepo --update /path/to/yum-repo/v6.06.11b10

# 添加新的RPM包后更新
createrepo --update /path/to/yum-repo/v6.06.11b10
```

### 监控和统计

```bash
# 查看仓库统计信息
find /path/to/yum-repo/v6.06.11b10/Packages -name "*.rpm" | wc -l

# 查看仓库大小
du -sh /path/to/yum-repo/v6.06.11b10
```

## 安全考虑

1. **文件权限**：确保仓库文件只有必要的读权限
2. **网络访问**：如使用HTTP服务，考虑访问控制
3. **包完整性**：定期验证RPM包的完整性
4. **更新策略**：建立定期更新仓库的流程

## 参考资料

- [YUM Configuration Reference](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/system_administrators_guide/sec-configuring_yum_and_yum_repositories)
- [CreateRepo Documentation](https://createrepo.baseurl.org/)
- [RPM Package Manager](https://rpm.org/)

---

**创建日期**: 2024年12月19日  
**版本**: 1.0  
**维护者**: NewStart OS Docker Project

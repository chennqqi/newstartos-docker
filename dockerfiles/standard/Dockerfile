# NewStart OS Standard Docker Image
# Optimized build process to handle large ISO files efficiently

# Build arguments for version support
ARG BUILD_VERSION=v6.06.11b10
ARG ISO_FILENAME

# Stage 1: ISO extraction and package preparation (single stage for efficiency)
FROM debian:bookworm-slim AS iso-processor-initial

# Install required tools for package extraction
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        squashfs-tools \
        genisoimage \
        xorriso \
        rpm \
        createrepo-c \
        rsync \
        tar \
        gzip \
        xz-utils \
        util-linux \
        cpio \
        file \
        bash \
        coreutils \
        procps \
        systemd \
        && apt-get clean && \
        rm -rf /var/lib/apt/lists/*

# Create all necessary directories in one step
RUN mkdir -p /{bin,boot,dev,etc,home,lib,lib64,media,mnt,opt,proc,root,run,sbin,srv,sys,tmp,usr,var} \
    && mkdir -p /usr/{bin,lib,lib64,sbin,share,local} \
    && mkdir -p /var/{lib,log,cache,run,spool,tmp} \
    && mkdir -p /etc/{sysconfig,init.d,rc.d,systemd} \
    && mkdir -p /tmp/{extract,packages,iso-content}

# NewStart OS Standard Docker Image
# BuildKit cache-optimized build process to handle large ISO files efficiently

# Build arguments for version support
ARG BUILD_VERSION=v6.06.11b10
ARG ISO_FILENAME

# Stage 1: ISO extraction and package preparation with BuildKit cache mount
FROM debian:bookworm-slim AS iso-processor-main

# Install required tools for package extraction
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        squashfs-tools \
        genisoimage \
        xorriso \
        rpm \
        createrepo-c \
        rsync \
        tar \
        gzip \
        xz-utils \
        util-linux \
        cpio \
        file \
        bash \
        coreutils \
        procps \
        systemd \
        && apt-get clean && \
        rm -rf /var/lib/apt/lists/*

# Create all necessary directories in one step
RUN mkdir -p /{bin,boot,dev,etc,home,lib,lib64,media,mnt,opt,proc,root,run,sbin,srv,sys,tmp,usr,var} \
    && mkdir -p /usr/{bin,lib,lib64,sbin,share,local} \
    && mkdir -p /var/{lib,log,cache,run,spool,tmp} \
    && mkdir -p /etc/{sysconfig,init.d,rc.d,systemd} \
    && mkdir -p /tmp/{extract,packages,iso-content}

# Process ISO with BuildKit cache mount to avoid repeated copies
RUN --mount=type=bind,source=iso,target=/mnt/iso,readonly \
    --mount=type=cache,target=/tmp/iso-cache,sharing=locked \
    set -ex; \
    \
    # Check if ISO is already cached \
    if [ -f "/tmp/iso-cache/${ISO_FILENAME}.extracted" ]; then \
        echo "Using cached ISO extraction..."; \
        cp -r /tmp/iso-cache/extract/* /tmp/extract/ 2>/dev/null || true; \
        cp -r /tmp/iso-cache/packages/* /tmp/packages/ 2>/dev/null || true; \
    else \
        echo "Processing ISO file with cache optimization..."; \
        \
        # Extract ISO contents directly using xorriso \
        echo "Extracting ISO contents..."; \
        xorriso -osirrox on -indev "/mnt/iso/${ISO_FILENAME}" -extract / /tmp/iso-content/ && \
        \
        # Copy essential content to extract directory \
        echo "Processing extracted content..."; \
        rsync -a /tmp/iso-content/ /tmp/extract/ && \
        \
        # Find and copy RPM packages efficiently \
        echo "Collecting RPM packages..."; \
        find /tmp/extract -name "*.rpm" -exec cp {} /tmp/packages/ \; 2>/dev/null || true && \
        \
        # Extract squashfs if present \
        if [ -f /tmp/extract/LiveOS/squashfs.img ]; then \
            echo "Extracting squashfs..."; \
            unsquashfs -d /tmp/squashfs-root /tmp/extract/LiveOS/squashfs.img && \
            rsync -a /tmp/squashfs-root/ /tmp/extract/ && \
            rm -rf /tmp/squashfs-root; \
        fi && \
        \
        # Cache extracted content for future builds \
        echo "Caching extraction results..."; \
        mkdir -p /tmp/iso-cache/extract /tmp/iso-cache/packages && \
        cp -r /tmp/extract/* /tmp/iso-cache/extract/ 2>/dev/null || true && \
        cp -r /tmp/packages/* /tmp/iso-cache/packages/ 2>/dev/null || true && \
        touch "/tmp/iso-cache/${ISO_FILENAME}.extracted"; \
    fi && \
    \
    # Clean up iso-content to save space \
    rm -rf /tmp/iso-content && \
    \
    # Initialize RPM database and install packages \
    echo "Setting up RPM database..."; \
    rpm --initdb && \
    \
    # Install essential packages from extracted RPMs \
    echo "Installing essential packages...";
    find /tmp/packages -name "*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true && \
    # 安装yum和必要的包管理工具
    find /tmp/packages -name "yum-*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true && \
    find /tmp/packages -name "python-*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true && \
    find /tmp/packages -name "python3-*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true && \
    find /tmp/packages -name "dnf-*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true && \
    # 安装基本系统工具
    find /tmp/packages -name "coreutils-*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true && \
    find /tmp/packages -name "bash-*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true && \
    find /tmp/packages -name "util-linux-*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true && \
    find /tmp/packages -name "procps-*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true && \
    find /tmp/packages -name "iproute-*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true && \
    find /tmp/packages -name "iputils-*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true && \
    find /tmp/packages -name "openssh-*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true && \
    find /tmp/packages -name "vim-*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true && \
    find /tmp/packages -name "less-*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true && \
    find /tmp/packages -name "which-*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true && \
    find /tmp/packages -name "tar-*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true && \
    find /tmp/packages -name "gzip-*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true && \
    find /tmp/packages -name "bzip2-*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true && \
    find /tmp/packages -name "grep-*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true && \
    find /tmp/packages -name "sed-*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true && \
    find /tmp/packages -name "gawk-*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true && \
    \
    # Configure systemd for container use \
    echo "Configuring systemd..."; \
    systemctl set-default multi-user.target 2>/dev/null || true && \
    systemctl enable systemd-remount-fs.service 2>/dev/null || true && \
    systemctl enable systemd-sysctl.service 2>/dev/null || true

# Create NewStart OS specific files
RUN echo "NewStart OS V6.06.11B10" > /etc/issue && \
    echo "NAME=\"NewStart OS\"" > /etc/os-release && \
    echo "VERSION=\"V6.06.11B10\"" >> /etc/os-release && \
    echo "ID=\"newstartos\"" >> /etc/os-release && \
    echo "VERSION_ID=\"V6.06.11B10\"" >> /etc/os-release && \
    echo "PRETTY_NAME=\"NewStart OS V6.06.11B10\"" >> /etc/os-release && \
    echo "ANSI_COLOR=\"0;31\"" >> /etc/os-release && \
    echo "CPE_NAME=\"cpe:/o:newstart:os:V6.06.11B10:GA:server\"" >> /etc/os-release && \
    echo "HOME_URL=\"https://www.newstartos.com/\"" >> /etc/os-release && \
    echo "BUG_REPORT_URL=\"https://www.newstartos.com/\"" >> /etc/os-release && \
    echo "REDHAT_BUGZILLA_PRODUCT=\"NewStart OS\"" >> /etc/os-release && \
    echo "REDHAT_BUGZILLA_PRODUCT_VERSION=V6.06.11B10" >> /etc/os-release && \
    echo "REDHAT_SUPPORT_PRODUCT=\"NewStart OS\"" >> /etc/os-release && \
    echo "REDHAT_SUPPORT_PRODUCT_VERSION=V6.06.11B10" >> /etc/os-release && \
    echo "NewStart OS V6.06.11B10" > /etc/redhat-release && \
    \
    # Create optimized init script \
    echo '#!/bin/bash\n\
echo "Starting NewStart OS Standard '"${BUILD_VERSION}"' container..."\n\
\n\
# Create necessary runtime directories\n\
mkdir -p /var/run /var/lock /tmp /var/tmp\n\
\n\
# Start systemd as init system\n\
exec /usr/lib/systemd/systemd' > /usr/local/bin/init.sh && \
    chmod +x /usr/local/bin/init.sh && \
    \
    # Clean up package files and unnecessary files to reduce image size \
    echo "Cleaning up package files and optimizing image size...";\
    # 保留yum相关的配置文件和缓存目录\
    mkdir -p /var/cache/yum && \
    mkdir -p /var/lib/yum && \
    # 删除不必要的文件以减小镜像大小\
    rm -rf /tmp/packages \
           /usr/share/doc/* \
           /usr/share/man/* \
           /usr/share/info/* \
           /var/cache/apt/* \
           /var/lib/apt/lists/* \
           /var/tmp/* \
           /tmp/* \
    && find /var/log -type f -delete \
    && find /usr -name "*.a" -delete \
    && find /lib -name "*.a" -delete \
    && find /usr -name "*.la" -delete \
    && find /lib -name "*.la" -delete \
    && find /usr -type f -name "*.py[co]" -delete \
    && find /usr -type d -name "__pycache__" -delete

# Stage 2: Final optimized image 
FROM scratch

# Set comprehensive metadata
LABEL maintainer="NewStart OS Team"
LABEL description="NewStart OS Standard Docker Image - BuildKit Cache Optimized"
LABEL version="${BUILD_VERSION}"
LABEL architecture="x86_64"
LABEL variant="standard"
LABEL build.optimized="true"
LABEL build.cache="enabled"
LABEL build.iso-handling="cache-optimized"

# Copy the complete prepared system root in one operation
COPY --from=iso-processor-main / /

# Set environment variables for NewStart OS
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV LANG="en_US.UTF-8"
ENV LC_ALL="en_US.UTF-8"
ENV TERM="xterm"
ENV NEWSTART_VERSION="${BUILD_VERSION}"

# Expose standard ports
EXPOSE 22 80 443

# Optimized health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD test -x /usr/local/bin/init.sh && systemctl is-system-running --quiet || exit 1

# Use optimized init script
CMD ["/usr/local/bin/init.sh"]
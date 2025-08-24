# NewStart OS Optimized Docker Image
# BuildKit cache-optimized build process with minimal footprint for RHEL-compatible system

# Build arguments for version support
ARG BUILD_VERSION=v6.06.11b10
ARG ISO_FILENAME

# Stage 1: Optimized ISO processing with BuildKit cache mount
FROM debian:bookworm-slim AS iso-processor

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
        && apt-get clean && \
        rm -rf /var/lib/apt/lists/*

# Create essential directories structure
RUN mkdir -p /{bin,boot,dev,etc,home,lib,lib64,media,mnt,opt,proc,root,run,sbin,srv,sys,tmp,usr,var} \
    && mkdir -p /usr/{bin,lib,lib64,sbin,share,local} \
    && mkdir -p /var/{lib,log,cache,run,spool,tmp} \
    && mkdir -p /etc/{sysconfig,init.d,rc.d} \
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
        # Extract ISO contents efficiently \
        echo "Extracting ISO contents..."; \
        xorriso -osirrox on -indev "/mnt/iso/${ISO_FILENAME}" -extract / /tmp/iso-content/ && \
        \
        # Process extracted content \
        echo "Processing extracted content..."; \
        rsync -a /tmp/iso-content/ /tmp/extract/ && \
        \
        # Collect RPM packages \
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
    # Initialize RPM database \
    echo "Setting up RPM database..."; \
    rpm --initdb && \
    \
    # Install essential packages (optimized selection) \
    echo "Installing essential packages..."; \
    find /tmp/packages -name "*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true && \
    \
    # Create NewStart OS specific files \
    echo "NewStart OS ${BUILD_VERSION}" > /etc/issue && \
    echo "NewStart OS ${BUILD_VERSION}" > /etc/os-release && \
    echo "NewStart OS ${BUILD_VERSION}" > /etc/redhat-release && \
    \
    # Create optimized init system \
    echo '#!/bin/bash\n\
echo "Starting NewStart OS Optimized '"${BUILD_VERSION}"' container..."\n\
\n\
# Create necessary runtime directories\n\
mkdir -p /var/run /var/lock /tmp /var/tmp\n\
\n\
# Start essential services if they exist\n\
if [ -f /etc/init.d/sshd ]; then\n\
    /etc/init.d/sshd start\n\
fi\n\
\n\
# Keep container running with provided command or default\n\
exec "$@"' > /usr/local/bin/init.sh && \
    chmod +x /usr/local/bin/init.sh && \
    \
    # Final cleanup to minimize layer size 
    echo "Final cleanup..."; 
    # 保留yum相关的配置文件和缓存目录
    mkdir -p /var/cache/yum && \
    mkdir -p /var/lib/yum && \
    # 删除不必要的文件以减小镜像大小
    rm -rf /tmp/packages

# Stage 2: Final optimized image from scratch (truly minimal)
FROM scratch

# Set comprehensive metadata
LABEL maintainer="NewStart OS Team"
LABEL description="NewStart OS Optimized Docker Image - Minimal Footprint with BuildKit Cache"
LABEL version="${BUILD_VERSION}"
LABEL architecture="x86_64"
LABEL vendor="NewStart OS"
LABEL variant="optimized"
LABEL build.optimized="true"
LABEL build.cache="enabled"
LABEL build.iso-handling="cache-optimized"
LABEL officialsite="https://www.gd-linux.com/"
LABEL org.opencontainers.image.title="NewStart OS Optimized"
LABEL org.opencontainers.image.description="NewStart OS Optimized Docker Image - Minimal Footprint with BuildKit Cache"
LABEL org.opencontainers.image.version="${BUILD_VERSION}"
LABEL org.opencontainers.image.architecture="x86_64"
LABEL org.opencontainers.image.vendor="NewStart OS"
LABEL org.opencontainers.image.source="https://github.com/chennqqi/newstartos-docker"

# Copy the complete prepared and optimized system root
COPY --from=iso-processor / /

# Set environment variables optimized for minimal resources
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV LANG="C"
ENV LC_ALL="C"
ENV TERM="xterm"
ENV NEWSTART_VERSION="${BUILD_VERSION}"

# Expose SSH port
EXPOSE 22

# Optimized health check for minimal resource usage
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD test -x /usr/local/bin/init.sh || exit 1

# Default command - use optimized init script
CMD ["/usr/local/bin/init.sh", "/bin/bash"] \
        bash \
        coreutils \
        procps \
        && apt-get clean && \
        rm -rf /var/lib/apt/lists/*

# Create essential directories structure
RUN mkdir -p /{bin,boot,dev,etc,home,lib,lib64,media,mnt,opt,proc,root,run,sbin,srv,sys,tmp,usr,var} \
    && mkdir -p /usr/{bin,lib,lib64,sbin,share,local} \
    && mkdir -p /var/{lib,log,cache,run,spool,tmp} \
    && mkdir -p /etc/{sysconfig,init.d,rc.d}

# Copy extracted system files from ISO
COPY --from=package-extract-optimized /tmp/extract/ /

# Initialize RPM database
RUN rpm --initdb

# Install essential packages from extracted RPMs
RUN find /tmp/packages -name "*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true && \
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
    find /tmp/packages -name "gawk-*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true

# Create NewStart OS specific files and prepare init system
RUN echo "NewStart OS ${BUILD_VERSION}" > /etc/issue && \
    echo "NewStart OS ${BUILD_VERSION}" > /etc/os-release && \
    echo "NewStart OS ${BUILD_VERSION}" > /etc/redhat-release && \
    mkdir -p /dev /proc /sys /tmp /var/tmp /var/run /var/lock /usr/local/bin

# Create minimal init system
RUN echo '#!/bin/bash\n\
# NewStart OS Container Init Script\n\
echo "Starting NewStart OS '"${BUILD_VERSION}"' container..."\n\
\n\
# Create necessary directories\n\
mkdir -p /var/run /var/lock /tmp /var/tmp\n\
\n\
# Start essential services if they exist\n\
if [ -f /etc/init.d/sshd ]; then\n\
    /etc/init.d/sshd start\n\
fi\n\
\n\
# Keep container running\n\
exec "$@"' > /usr/local/bin/init.sh && \
    chmod +x /usr/local/bin/init.sh

# Stage 4: Final optimized image from scratch
FROM scratch

# Set metadata
LABEL maintainer="NewStart OS Team"
LABEL description="NewStart OS Optimized Docker Image - RHEL Compatible (Minimal Size)"
LABEL version="${BUILD_VERSION}"
LABEL architecture="x86_64"
LABEL vendor="NewStart OS"
LABEL officialsite="https://www.gd-linux.com/"
LABEL optimization="true"
LABEL size="minimal"
LABEL org.opencontainers.image.title="NewStart OS Optimized"
LABEL org.opencontainers.image.description="NewStart OS Optimized Docker Image - RHEL Compatible (Minimal Size)"
LABEL org.opencontainers.image.version="${BUILD_VERSION}"
LABEL org.opencontainers.image.architecture="x86_64"
LABEL org.opencontainers.image.vendor="NewStart OS"
LABEL org.opencontainers.image.source="https://github.com/chennqqi/newstartos-docker"

# Copy the complete prepared system root
COPY --from=system-root-optimized / /

# Set environment variables
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV LANG="C"
ENV LC_ALL="C"
ENV TERM="xterm"

# Expose SSH port
EXPOSE 22

# Health check using simple file existence check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD test -f /usr/local/bin/init.sh || exit 1

# Default command - use init script
CMD ["/usr/local/bin/init.sh", "/bin/bash"]
# NewStart OS Optimized Docker Image
# Built from scratch with minimal footprint for RHEL-compatible system

# Build arguments for version support
ARG BUILD_VERSION=v6.06.11b10
ARG ISO_FILENAME

# Multi-stage build to extract packages from ISO
FROM scratch AS iso-extract-final2-optimized

# Copy ISO file to extract packages
COPY iso/${ISO_FILENAME} /tmp/newstart.iso

# Stage 2: Package extraction and system preparation
FROM debian:bookworm-slim AS package-extract-final2-final-optimized

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
        curl \
        wget \
        util-linux \
        mount \
        && apt-get clean && \
        rm -rf /var/lib/apt/lists/*

# Create mount point and extract ISO
RUN mkdir -p /mnt/iso /tmp/extract /tmp/packages
COPY iso/${ISO_FILENAME} /tmp/newstart.iso

# Extract ISO contents using loop mount (more reliable than 7z)
RUN mount -o loop /tmp/newstart.iso /mnt/iso && \
    rsync -av /mnt/iso/ /tmp/extract/ && \
    umount /mnt/iso && \
    find /tmp/extract -name "*.rpm" -exec cp {} /tmp/packages/ \; 2>/dev/null || true

# Extract squashfs if present
RUN if [ -f /tmp/extract/LiveOS/squashfs.img ]; then \
        mkdir -p /mnt/squashfs && \
        mount -o loop /tmp/extract/LiveOS/squashfs.img /mnt/squashfs && \
        rsync -av /mnt/squashfs/ /tmp/extract/ && \
        umount /mnt/squashfs; \
    fi

# Stage 3: System root preparation
FROM debian:bookworm-slim AS system-root-stage5-stage4-stage3-stage2-stage1

# Install RPM tools for package installation
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        rpm \
        bash \
        coreutils \
        procps \
        && apt-get clean && \
        rm -rf /var/lib/apt/lists/*

# Create essential directories structure
RUN mkdir -p /{bin,boot,dev,etc,home,lib,lib64,media,mnt,opt,proc,root,run,sbin,srv,sys,tmp,usr,var} \
    && mkdir -p /usr/{bin,lib,lib64,sbin,share,local} \
    && mkdir -p /var/{lib,log,cache,run,spool,tmp} \
    && mkdir -p /etc/{sysconfig,init.d,rc.d}

# Copy extracted system files from ISO
COPY --from=iso-processor /tmp/extract/ /

# Initialize RPM database
RUN rpm --initdb

# Install essential packages from extracted RPMs
RUN find /tmp/packages -name "*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true

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
    echo "NewStart OS V6.06.11B10" > /etc/redhat-release

# Optimize image size by removing unnecessary files
RUN rm -rf /usr/share/doc/* \
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

# Stage 4: Final optimized image from scratch
FROM scratch

# Set metadata
LABEL maintainer="NewStart OS Team"
LABEL description="NewStart OS Optimized Docker Image - RHEL Compatible"
LABEL version="${BUILD_VERSION}"
LABEL architecture="x86_64"
LABEL vendor="NewStart OS"
LABEL officialsite="https://www.gd-linux.com/"
LABEL org.opencontainers.image.title="NewStart OS"
LABEL org.opencontainers.image.description="NewStart OS Optimized Docker Image - RHEL Compatible"
LABEL org.opencontainers.image.version="${BUILD_VERSION}"
LABEL org.opencontainers.image.architecture="x86_64"
LABEL org.opencontainers.image.vendor="NewStart OS"
LABEL org.opencontainers.image.source="https://github.com/chennqqi/newstartos-docker"

# Copy the complete system root
COPY --from=system-root-stage1 / /

# Set environment variables
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV LANG="C"
ENV LC_ALL="C"
ENV TERM="xterm"

# Create essential device nodes and directories
RUN mkdir -p /dev /proc /sys /tmp /var/tmp /var/run /var/lock

# Create minimal init system
RUN echo '#!/bin/bash\n\
# NewStart OS Container Init Script\n\
echo "Starting NewStart OS '"${BUILD_VERSION}"' container..."\n\
\n\
# Create necessary directories\n\
mkdir -p /var/run /var/lock /tmp /var/tmp\n\
\n\
# Start essential services if they exist\n\
if [ -f /etc/init.d/sshd ]; then\n\
    /etc/init.d/sshd start\n\
fi\n\
\n\
# Keep container running\n\
exec "$@"' > /usr/local/bin/init.sh && \
    chmod +x /usr/local/bin/init.sh

# Expose SSH port
EXPOSE 22

# Health check using simple process check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD ps aux | grep -v grep | grep -q "bash\|sshd" || exit 1

# Default command - use init script
CMD ["/usr/local/bin/init.sh", "/bin/bash"]
# NewStart OS Optimized Docker Image
# Built from scratch with minimal footprint for RHEL-compatible system

# Build arguments for version support
ARG BUILD_VERSION=v6.06.11b10
ARG ISO_FILENAME

# Multi-stage build to extract packages from ISO
FROM scratch AS iso-extract-alt

# Copy ISO file to extract packages
COPY iso/${ISO_FILENAME} /tmp/newstart.iso

# Stage 2: Package extraction and system preparation
FROM debian:bookworm-slim AS package-extract-alt

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
        curl \
        wget \
        util-linux \
        cpio \
        file \
        && apt-get clean && \
        rm -rf /var/lib/apt/lists/*

# Create extraction directories  
RUN mkdir -p /tmp/extract /tmp/packages /tmp/iso-content
COPY iso/${ISO_FILENAME} /tmp/newstart.iso

# Extract ISO contents using xorriso (more reliable in containers)
RUN xorriso -osirrox on -indev /tmp/newstart.iso -extract / /tmp/iso-content/ && \
    rsync -av /tmp/iso-content/ /tmp/extract/ && \
    find /tmp/extract -name "*.rpm" -exec cp {} /tmp/packages/ \; 2>/dev/null || true

# Extract squashfs if present using unsquashfs
RUN if [ -f /tmp/extract/LiveOS/squashfs.img ]; then \
        unsquashfs -d /tmp/squashfs-root /tmp/extract/LiveOS/squashfs.img && \
        rsync -av /tmp/squashfs-root/ /tmp/extract/ && \
        rm -rf /tmp/squashfs-root; \
    fi

# Stage 3: System root preparation
FROM debian:bookworm-slim AS system-root

# Install RPM tools for package installation
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        rpm \
        bash \
        coreutils \
        procps \
        && apt-get clean && \
        rm -rf /var/lib/apt/lists/*

# Create essential directories structure
RUN mkdir -p /{bin,boot,dev,etc,home,lib,lib64,media,mnt,opt,proc,root,run,sbin,srv,sys,tmp,usr,var} \
    && mkdir -p /usr/{bin,lib,lib64,sbin,share,local} \
    && mkdir -p /var/{lib,log,cache,run,spool,tmp} \
    && mkdir -p /etc/{sysconfig,init.d,rc.d}

# Copy extracted system files from ISO
COPY --from=iso-processor /tmp/extract/ /

# Initialize RPM database
RUN rpm --initdb

# Install essential packages from extracted RPMs
RUN find /tmp/packages -name "*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true

# Create NewStart OS specific files
RUN echo "NewStart OS ${BUILD_VERSION}" > /etc/issue && \
    echo "NewStart OS ${BUILD_VERSION}" > /etc/os-release && \
    echo "NewStart OS ${BUILD_VERSION}" > /etc/redhat-release

# Stage 4: Final optimized image from scratch
FROM scratch

# Set metadata
LABEL maintainer="NewStart OS Team"
LABEL description="NewStart OS Optimized Docker Image - RHEL Compatible"
LABEL version="${BUILD_VERSION}"
LABEL architecture="x86_64"
LABEL vendor="NewStart OS"
LABEL officialsite="https://www.gd-linux.com/"
LABEL org.opencontainers.image.title="NewStart OS"
LABEL org.opencontainers.image.description="NewStart OS Optimized Docker Image - RHEL Compatible"
LABEL org.opencontainers.image.version="${BUILD_VERSION}"
LABEL org.opencontainers.image.architecture="x86_64"
LABEL org.opencontainers.image.vendor="NewStart OS"
LABEL org.opencontainers.image.source="https://github.com/chennqqi/newstartos-docker"

# Copy the complete system root
COPY --from=iso-processor / /

# Set environment variables
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV LANG="C"
ENV LC_ALL="C"
ENV TERM="xterm"

# Create essential device nodes and directories
RUN mkdir -p /dev /proc /sys /tmp /var/tmp /var/run /var/lock

# Create minimal init system
RUN echo '#!/bin/bash\n\
# NewStart OS Container Init Script\n\
echo "Starting NewStart OS '"${BUILD_VERSION}"' container..."\n\
\n\
# Create necessary directories\n\
mkdir -p /var/run /var/lock /tmp /var/tmp\n\
\n\
# Start essential services if they exist\n\
if [ -f /etc/init.d/sshd ]; then\n\
    /etc/init.d/sshd start\n\
fi\n\
\n\
# Keep container running\n\
exec "$@"' > /usr/local/bin/init.sh && \
    chmod +x /usr/local/bin/init.sh

# Expose SSH port
EXPOSE 22

# Health check using simple process check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD ps aux | grep -v grep | grep -q "bash\|sshd" || exit 1

# Default command - use init script
CMD ["/usr/local/bin/init.sh", "/bin/bash"]
# NewStart OS Optimized Docker Image
# Built from scratch with minimal footprint for RHEL-compatible system

# Build arguments for version support
ARG BUILD_VERSION=v6.06.11b10
ARG ISO_FILENAME

# Multi-stage build to extract packages from ISO
FROM scratch AS iso-extract-final

# Copy ISO file to extract packages
COPY iso/${ISO_FILENAME} /tmp/newstart.iso

# Stage 2: Package extraction and system preparation
FROM debian:bookworm-slim AS package-extract-final

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
        curl \
        wget \
        util-linux \
        mount \
        && apt-get clean && \
        rm -rf /var/lib/apt/lists/*

# Create mount point and extract ISO
RUN mkdir -p /mnt/iso /tmp/extract /tmp/packages
COPY iso/${ISO_FILENAME} /tmp/newstart.iso

# Extract ISO contents using loop mount (more reliable than 7z)
RUN mount -o loop /tmp/newstart.iso /mnt/iso && \
    rsync -av /mnt/iso/ /tmp/extract/ && \
    umount /mnt/iso && \
    find /tmp/extract -name "*.rpm" -exec cp {} /tmp/packages/ \; 2>/dev/null || true

# Extract squashfs if present
RUN if [ -f /tmp/extract/LiveOS/squashfs.img ]; then \
        mkdir -p /mnt/squashfs && \
        mount -o loop /tmp/extract/LiveOS/squashfs.img /mnt/squashfs && \
        rsync -av /mnt/squashfs/ /tmp/extract/ && \
        umount /mnt/squashfs; \
    fi

# Stage 3: System root preparation
FROM debian:bookworm-slim AS system-root

# Install RPM tools for package installation
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        rpm \
        bash \
        coreutils \
        procps \
        && apt-get clean && \
        rm -rf /var/lib/apt/lists/*

# Create essential directories structure
RUN mkdir -p /{bin,boot,dev,etc,home,lib,lib64,media,mnt,opt,proc,root,run,sbin,srv,sys,tmp,usr,var} \
    && mkdir -p /usr/{bin,lib,lib64,sbin,share,local} \
    && mkdir -p /var/{lib,log,cache,run,spool,tmp} \
    && mkdir -p /etc/{sysconfig,init.d,rc.d}

# Copy extracted system files from ISO
COPY --from=iso-processor /tmp/extract/ /

# Initialize RPM database
RUN rpm --initdb

# Install essential packages from extracted RPMs
RUN find /tmp/packages -name "*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true

# Create NewStart OS specific files and prepare init system
RUN echo "NewStart OS ${BUILD_VERSION}" > /etc/issue && \
    echo "NewStart OS ${BUILD_VERSION}" > /etc/os-release && \
    echo "NewStart OS ${BUILD_VERSION}" > /etc/redhat-release && \
    mkdir -p /dev /proc /sys /tmp /var/tmp /var/run /var/lock /usr/local/bin

# Create minimal init system
RUN echo '#!/bin/bash\n\
# NewStart OS Container Init Script\n\
echo "Starting NewStart OS '"${BUILD_VERSION}"' container..."\n\
\n\
# Create necessary directories\n\
mkdir -p /var/run /var/lock /tmp /var/tmp\n\
\n\
# Start essential services if they exist\n\
if [ -f /etc/init.d/sshd ]; then\n\
    /etc/init.d/sshd start\n\
fi\n\
\n\
# Keep container running\n\
exec "$@"' > /usr/local/bin/init.sh && \
    chmod +x /usr/local/bin/init.sh

# Stage 4: Final optimized image from scratch
FROM scratch

# Set metadata
LABEL maintainer="NewStart OS Team"
LABEL description="NewStart OS Optimized Docker Image - RHEL Compatible (Minimal Size)"
LABEL version="${BUILD_VERSION}"
LABEL architecture="x86_64"
LABEL vendor="NewStart OS"
LABEL officialsite="https://www.gd-linux.com/"
LABEL optimization="true"
LABEL size="minimal"
LABEL org.opencontainers.image.title="NewStart OS Optimized"
LABEL org.opencontainers.image.description="NewStart OS Optimized Docker Image - RHEL Compatible (Minimal Size)"
LABEL org.opencontainers.image.version="${BUILD_VERSION}"
LABEL org.opencontainers.image.architecture="x86_64"
LABEL org.opencontainers.image.vendor="NewStart OS"
LABEL org.opencontainers.image.source="https://github.com/chennqqi/newstartos-docker"

# Copy the complete prepared system root
COPY --from=iso-processor / /

# Set environment variables
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV LANG="C"
ENV LC_ALL="C"
ENV TERM="xterm"

# Expose SSH port
EXPOSE 22

# Health check using simple file existence check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD test -f /usr/local/bin/init.sh || exit 1

# Default command - use init script
CMD ["/usr/local/bin/init.sh", "/bin/bash"]
# NewStart OS Optimized Docker Image
# Built from scratch with minimal footprint for RHEL-compatible system

# Build arguments for version support
ARG BUILD_VERSION=v6.06.11b10
ARG ISO_FILENAME

# Multi-stage build to extract packages from ISO
FROM scratch AS iso-extract

# Copy ISO file to extract packages
COPY iso/${ISO_FILENAME} /tmp/newstart.iso

# Stage 2: Package extraction and system preparation
FROM debian:bookworm-slim AS package-extract

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
        curl \
        wget \
        util-linux \
        mount \
        && apt-get clean && \
        rm -rf /var/lib/apt/lists/*

# Create mount point and extract ISO
RUN mkdir -p /mnt/iso /tmp/extract /tmp/packages
COPY iso/${ISO_FILENAME} /tmp/newstart.iso

# Extract ISO contents using loop mount (more reliable than 7z)
RUN mount -o loop /tmp/newstart.iso /mnt/iso && \
    rsync -av /mnt/iso/ /tmp/extract/ && \
    umount /mnt/iso && \
    find /tmp/extract -name "*.rpm" -exec cp {} /tmp/packages/ \; 2>/dev/null || true

# Extract squashfs if present
RUN if [ -f /tmp/extract/LiveOS/squashfs.img ]; then \
        mkdir -p /mnt/squashfs && \
        mount -o loop /tmp/extract/LiveOS/squashfs.img /mnt/squashfs && \
        rsync -av /mnt/squashfs/ /tmp/extract/ && \
        umount /mnt/squashfs; \
    fi

# Stage 3: System root preparation
FROM debian:bookworm-slim AS system-root

# Install RPM tools for package installation
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        rpm \
        bash \
        coreutils \
        procps \
        && apt-get clean && \
        rm -rf /var/lib/apt/lists/*

# Create essential directories structure
RUN mkdir -p /{bin,boot,dev,etc,home,lib,lib64,media,mnt,opt,proc,root,run,sbin,srv,sys,tmp,usr,var} \
    && mkdir -p /usr/{bin,lib,lib64,sbin,share,local} \
    && mkdir -p /var/{lib,log,cache,run,spool,tmp} \
    && mkdir -p /etc/{sysconfig,init.d,rc.d}

# Copy extracted system files from ISO
COPY --from=iso-processor /tmp/extract/ /

# Initialize RPM database
RUN rpm --initdb

# Install essential packages from extracted RPMs
RUN find /tmp/packages -name "*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true

# Create NewStart OS specific files
RUN echo "NewStart OS ${BUILD_VERSION}" > /etc/issue && \
    echo "NewStart OS ${BUILD_VERSION}" > /etc/os-release && \
    echo "NewStart OS ${BUILD_VERSION}" > /etc/redhat-release

# Stage 4: Final optimized image from scratch
FROM scratch

# Set metadata
LABEL maintainer="NewStart OS Team"
LABEL description="NewStart OS Optimized Docker Image - RHEL Compatible"
LABEL version="${BUILD_VERSION}"
LABEL architecture="x86_64"
LABEL vendor="NewStart OS"
LABEL officialsite="https://www.gd-linux.com/"
LABEL org.opencontainers.image.title="NewStart OS"
LABEL org.opencontainers.image.description="NewStart OS Optimized Docker Image - RHEL Compatible"
LABEL org.opencontainers.image.version="${BUILD_VERSION}"
LABEL org.opencontainers.image.architecture="x86_64"
LABEL org.opencontainers.image.vendor="NewStart OS"
LABEL org.opencontainers.image.source="https://github.com/chennqqi/newstartos-docker"

# Copy the complete system root
COPY --from=system-root-stage2 / /

# Set environment variables
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV LANG="C"
ENV LC_ALL="C"
ENV TERM="xterm"

# Create essential device nodes and directories
RUN mkdir -p /dev /proc /sys /tmp /var/tmp /var/run /var/lock

# Create minimal init system
RUN echo '#!/bin/bash\n\
# NewStart OS Container Init Script\n\
echo "Starting NewStart OS '"${BUILD_VERSION}"' container..."\n\
\n\
# Create necessary directories\n\
mkdir -p /var/run /var/lock /tmp /var/tmp\n\
\n\
# Start essential services if they exist\n\
if [ -f /etc/init.d/sshd ]; then\n\
    /etc/init.d/sshd start\n\
fi\n\
\n\
# Keep container running\n\
exec "$@"' > /usr/local/bin/init.sh && \
    chmod +x /usr/local/bin/init.sh

# Expose SSH port
EXPOSE 22

# Health check using simple process check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD ps aux | grep -v grep | grep -q "bash\|sshd" || exit 1

# Default command - use init script
CMD ["/usr/local/bin/init.sh", "/bin/bash"]

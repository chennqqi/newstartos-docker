# NewStart OS Optimized Docker Image
# Built from scratch with minimal footprint for RHEL-compatible system

# Build arguments for version support
ARG BUILD_VERSION=V6.06.11B10
ARG ISO_FILENAME=NewStart-CGS-Linux-MAIN.V6.06.11B10-x86_64.dvd.iso

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
RUN mkdir -p /mnt/iso /mnt/squashfs /tmp/extract /tmp/packages
COPY iso/${ISO_FILENAME} /tmp/newstart.iso

# Extract ISO contents using xorriso (works in containers)
RUN xorriso -osirrox on -indev /tmp/newstart.iso -extract / /tmp/extract/ && \
    find /tmp/extract -name "*.rpm" -exec cp {} /tmp/packages/ \; 2>/dev/null || true

# Extract squashfs if present
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
COPY --from=package-extract /tmp/extract/ /

# Initialize RPM database
RUN rpm --initdb

# Install essential packages from extracted RPMs
RUN find /tmp/packages -name "*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true

# Create NewStart OS specific files
RUN echo "NewStart OS ${BUILD_VERSION}" > /etc/issue && \
    echo "NAME=\"NewStart OS\"" > /etc/os-release && \
    echo "VERSION=\"${BUILD_VERSION}\"" >> /etc/os-release && \
    echo "ID=\"newstartos\"" >> /etc/os-release && \
    echo "VERSION_ID=\"${BUILD_VERSION}\"" >> /etc/os-release && \
    echo "PRETTY_NAME=\"NewStart OS ${BUILD_VERSION}\"" >> /etc/os-release && \
    echo "ANSI_COLOR=\"0;31\"" >> /etc/os-release && \
    echo "NewStart OS ${BUILD_VERSION}" > /etc/redhat-release

# Stage 4: Optimization and cleanup
FROM debian:bookworm-slim AS optimization

# Install cleanup tools
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        findutils \
        && apt-get clean && \
        rm -rf /var/lib/apt/lists/*

# Copy system root for optimization
COPY --from=system-root / /

# Remove unnecessary components for optimization
RUN find /usr/share -name "*.doc" -o -name "*.pdf" -o -name "*.txt" | xargs rm -f 2>/dev/null || true && \
    find /usr/share -name "*.man" -o -name "*.info" | xargs rm -f 2>/dev/null || true && \
    find /usr/share -name "*.html" -o -name "*.xml" | xargs rm -f 2>/dev/null || true && \
    rm -rf /usr/share/doc /usr/share/man /usr/share/info /usr/share/locale 2>/dev/null || true && \
    rm -rf /usr/share/gnome /usr/share/kde /usr/share/applications 2>/dev/null || true && \
    rm -rf /usr/share/icons /usr/share/pixmaps /usr/share/backgrounds 2>/dev/null || true && \
    rm -rf /usr/share/sounds /usr/share/themes /usr/share/fonts 2>/dev/null || true && \
    rm -rf /var/cache/yum /var/cache/dnf /var/cache/man 2>/dev/null || true && \
    rm -rf /tmp/* /var/tmp/* 2>/dev/null || true && \
    find /usr -name "*.pyc" -o -name "*.pyo" | xargs rm -f 2>/dev/null || true && \
    find /usr -name "__pycache__" -type d | xargs rm -rf 2>/dev/null || true

# Stage 5: Final optimized image from scratch
FROM scratch

# Set metadata
LABEL maintainer="NewStart OS Team"
LABEL description="NewStart OS Optimized Docker Image - RHEL Compatible"
LABEL version="V6.06.11B10"
LABEL architecture="x86_64"
LABEL vendor="NewStart OS"
LABEL org.opencontainers.image.source="https://github.com/newstartos/newstartos-docker"
LABEL org.opencontainers.image.created="2025-08-23T15:00:00Z"

# Copy the complete optimized system root
COPY --from=optimization / /

# Set environment variables
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV LANG="zh_CN.UTF-8"
ENV LC_ALL="zh_CN.UTF-8"
ENV TERM="xterm"
ENV HOME="/root"
ENV USER="root"

# Create essential device nodes and directories
RUN mkdir -p /dev /proc /sys /tmp /var/tmp /var/run /var/lock

# Create minimal init system
RUN echo '#!/bin/bash\n\
# NewStart OS Container Init Script\n\
echo "Starting NewStart OS V6.06.11B10 container..."\n\
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

# Create a simple health check script
RUN echo '#!/bin/bash\n\
# Health check for NewStart OS container\n\
if ps aux | grep -v grep | grep -q "bash\|sshd"; then\n\
    exit 0\n\
else\n\
    exit 1\n\
fi' > /usr/local/bin/healthcheck.sh && \
    chmod +x /usr/local/bin/healthcheck.sh

# Expose SSH port
EXPOSE 22

# Health check using custom script
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

# Default command - use init script
CMD ["/usr/local/bin/init.sh", "/bin/bash"]

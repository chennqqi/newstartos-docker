# NewStart OS Optimized Docker Image
# Built from scratch with minimal footprint for RHEL-compatible system

# Multi-stage build to extract packages from ISO
FROM scratch AS iso-extract

# Copy ISO file to extract packages
COPY iso/NewStart-CGS-Linux-MAIN.V6.06.11B10-x86_64.dvd.iso /tmp/newstart.iso

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
        p7zip-full \
        && apt-get clean && \
        rm -rf /var/lib/apt/lists/*

# Create mount point and extract ISO
RUN mkdir -p /mnt/iso /mnt/squashfs /tmp/extract /tmp/packages
COPY iso/NewStart-CGS-Linux-MAIN.V6.06.11B10-x86_64.dvd.iso /tmp/newstart.iso

# Extract ISO contents using 7z
RUN 7z x /tmp/newstart.iso -o/tmp/extract -y && \
    if [ -f /tmp/extract/LiveOS/squashfs.img ]; then \
        7z x /tmp/extract/LiveOS/squashfs.img -o/tmp/extract -y; \
    fi

# Extract RPM packages and system files
RUN find /tmp/extract -name "*.rpm" -exec cp {} /tmp/packages/ \; 2>/dev/null || true

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
RUN echo "NewStart OS V6.06.11B10" > /etc/issue && \
    echo "NewStart OS V6.06.11B10" > /etc/os-release && \
    echo "NewStart OS V6.06.11B10" > /etc/redhat-release

# Stage 4: Final optimized image from scratch
FROM scratch

# Set metadata
LABEL maintainer="NewStart OS Team"
LABEL description="NewStart OS Optimized Docker Image - RHEL Compatible"
LABEL version="V6.06.11B10"
LABEL architecture="x86_64"
LABEL vendor="NewStart OS"
LABEL officialsite="https://www.gd-linux.com/"
LABEL org.opencontainers.image.title="NewStart OS"
LABEL org.opencontainers.image.description="NewStart OS Optimized Docker Image - RHEL Compatible"
LABEL org.opencontainers.image.version="V6.06.11B10"
LABEL org.opencontainers.image.architecture="x86_64"
LABEL org.opencontainers.image.vendor="NewStart OS"
LABEL org.opencontainers.image.source="https://github.com/chennqqi/newstartos-docker"

# Copy the complete system root
COPY --from=system-root / /

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

# Expose SSH port
EXPOSE 22

# Health check using simple process check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD ps aux | grep -v grep | grep -q "bash\|sshd" || exit 1

# Default command - use init script
CMD ["/usr/local/bin/init.sh", "/bin/bash"]

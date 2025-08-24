# NewStart OS Standard Docker Image
# Optimized build process to handle large ISO files efficiently

# Build arguments for version support
ARG BUILD_VERSION=v6.06.11b10
ARG ISO_FILENAME

# Stage 1: ISO extraction and package preparation (single stage for efficiency)
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
    echo "Installing essential packages..."; \
    find /tmp/packages -name "*.rpm" -exec rpm -ivh --nodeps --root / {} \; 2>/dev/null || true && \
    \
    # Configure systemd for container use \
    echo "Configuring systemd..."; \
    systemctl set-default multi-user.target 2>/dev/null || true && \
    systemctl enable systemd-remount-fs.service 2>/dev/null || true && \
    systemctl enable systemd-sysctl.service 2>/dev/null || true

# Create NewStart OS specific files and init system in the same layer
RUN echo "NewStart OS ${BUILD_VERSION}" > /etc/issue && \
    echo "NewStart OS ${BUILD_VERSION}" > /etc/os-release && \
    echo "NewStart OS ${BUILD_VERSION}" > /etc/redhat-release && \
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
    # Clean up package files to reduce layer size \
    echo "Cleaning up package files..."; \
    rm -rf /tmp/packages

# Stage 2: Final optimized image 
FROM debian:bookworm-slim

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
COPY --from=iso-processor / /

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
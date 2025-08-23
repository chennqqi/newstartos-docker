# NewStart OS Standard Docker Image
# Built from scratch for maximum compatibility

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

# Extract squashfs if present and prepare system
RUN if [ -f /tmp/extract/LiveOS/squashfs.img ]; then \
        mkdir -p /mnt/squashfs && \
        mount -o loop /tmp/extract/LiveOS/squashfs.img /mnt/squashfs && \
        rsync -av /mnt/squashfs/ /tmp/extract/ && \
        umount /mnt/squashfs; \
    fi

# Create essential directories and initialize system in extract directory
RUN mkdir -p /tmp/extract/{var/lib/rpm,var/lib/dnf,var/cache/dnf,var/log,tmp,var/tmp,dev,proc,sys} && \
    mkdir -p /tmp/extract/etc/systemd/{system,user} && \
    mkdir -p /tmp/extract/run/systemd/system && \
    mkdir -p /tmp/extract/usr/local/bin

# Initialize RPM database in extract directory
RUN chroot /tmp/extract rpm --initdb || true

# Install essential packages from extracted RPMs
RUN find /tmp/packages -name "*.rpm" -exec chroot /tmp/extract rpm -ivh --nodeps {} \; 2>/dev/null || true

# Configure systemd in extract directory
RUN chroot /tmp/extract systemctl enable systemd-remount-fs.service 2>/dev/null || true && \
    chroot /tmp/extract systemctl enable systemd-sysctl.service 2>/dev/null || true && \
    chroot /tmp/extract systemctl enable systemd-udev-trigger.service 2>/dev/null || true

# Set default target in extract directory
RUN ln -sf /lib/systemd/system/multi-user.target /tmp/extract/etc/systemd/system/default.target 2>/dev/null || true

# Create init script in extract directory
RUN echo '#!/bin/bash\n\
echo "Starting NewStart OS '"${BUILD_VERSION}"' container..."\n\
exec "/usr/lib/systemd/systemd"' > /tmp/extract/usr/local/bin/init.sh && \
    chmod +x /tmp/extract/usr/local/bin/init.sh

# Stage 3: Final image from scratch (truly minimal)
FROM scratch

# Set metadata
LABEL maintainer="NewStart OS Team"
LABEL description="NewStart OS Standard Docker Image - Built from Scratch"
LABEL version="${BUILD_VERSION}"
LABEL architecture="x86_64"

# Copy the complete prepared system root
COPY --from=package-extract /tmp/extract/ /

# Set environment variables
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV LANG="en_US.UTF-8"
ENV LC_ALL="en_US.UTF-8"

# Expose common ports
EXPOSE 22 80 443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD test -f /usr/lib/systemd/systemd || exit 1

# Default command
CMD ["/usr/local/bin/init.sh"]

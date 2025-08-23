# NewStart OS Standard Docker Image
# Built from scratch for maximum compatibility

# Multi-stage build to extract packages from ISO
FROM scratch AS iso-extract

# Copy ISO file to extract packages
COPY iso/NewStart-CGS-Linux-MAIN.V6.06.11B10-x86_64.dvd.iso /tmp/newstart.iso

# Stage 2: Package extraction and system preparation
FROM alpine:3.19 AS package-extract

# Install required tools for package extraction
RUN apk update && \
    apk add --no-cache \
        squashfs-tools \
        genisoimage \
        xorriso \
        util-linux \
        rpm \
        createrepo \
        rsync \
        tar \
        gzip \
        xz \
        curl \
        wget \
        bash \
        shadow \
        && rm -rf /var/cache/apk/*

# Create mount point and extract ISO
RUN mkdir -p /mnt/iso /mnt/squashfs /tmp/extract
COPY iso/NewStart-CGS-Linux-MAIN.V6.06.11B10-x86_64.dvd.iso /tmp/newstart.iso

# Mount and extract ISO contents
RUN mount -o loop /tmp/newstart.iso /mnt/iso && \
    if [ -f /mnt/iso/LiveOS/squashfs.img ]; then \
        mount -o loop /mnt/iso/LiveOS/squashfs.img /mnt/squashfs; \
        rsync -av /mnt/squashfs/ /tmp/extract/; \
        umount /mnt/squashfs; \
    else \
        rsync -av /mnt/iso/ /tmp/extract/; \
    fi && \
    umount /mnt/iso

# Extract RPM packages
RUN find /tmp/extract -name "*.rpm" -exec cp {} /tmp/packages/ \; 2>/dev/null || true

# Stage 3: System root preparation
FROM scratch AS system-root

# Copy extracted system files
COPY --from=package-extract /tmp/extract/ /

# Stage 4: Final image
FROM scratch

# Set metadata
LABEL maintainer="NewStart OS Team"
LABEL description="NewStart OS Standard Docker Image"
LABEL version="V6.06.11B10"
LABEL architecture="x86_64"

# Copy system root
COPY --from=system-root / /

# Set environment variables
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV LANG="en_US.UTF-8"
ENV LC_ALL="en_US.UTF-8"

# Create essential directories
RUN mkdir -p /var/lib/rpm /var/lib/dnf /var/cache/dnf /var/log /tmp /var/tmp

# Initialize RPM database
RUN rpm --initdb

# Install essential packages from extracted RPMs
RUN find /tmp/packages -name "*.rpm" -exec rpm -ivh --nodeps {} \; 2>/dev/null || true

# Configure systemd
RUN systemctl enable systemd-remount-fs.service && \
    systemctl enable systemd-sysctl.service && \
    systemctl enable systemd-udev-trigger.service

# Create systemd directories
RUN mkdir -p /etc/systemd/system /etc/systemd/user /run/systemd/system

# Set default target
RUN ln -sf /lib/systemd/system/multi-user.target /etc/systemd/system/default.target

# Expose common ports
EXPOSE 22 80 443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD systemctl is-system-running || exit 1

# Default command
CMD ["/usr/lib/systemd/systemd"]

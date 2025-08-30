# NewStart OS Docker Image - Layer Method
# Simplified build using pre-created rootfs layer

# Stage 1: Prepare rootfs with fixes
FROM rockylinux:8-minimal AS rootfs-fixer

# Build arguments for version support
ARG BUILD_VERSION=V6.06.11B10
ARG LAYER_FILE=newstartos-v6.06.11b10-rootfs.tar.xz

# Add the complete root filesystem layer
ADD rootfs/${LAYER_FILE} /tmp/rootfs/

# Fix essential symlinks and library paths for compatibility
RUN mkdir -p /tmp/rootfs/bin /tmp/rootfs/sbin /tmp/rootfs/lib /tmp/rootfs/lib64 && \
    ln -sf /usr/bin/bash /tmp/rootfs/bin/bash && \
    ln -sf /usr/bin/bash /tmp/rootfs/bin/sh && \
    ln -sf /usr/sbin/init /tmp/rootfs/sbin/init

# Stage 2: Final image
FROM scratch

# Copy the fixed rootfs from stage 1
COPY --from=rootfs-fixer /tmp/rootfs/ /

# Set metadata
LABEL maintainer="NewStart OS Team"
LABEL description="NewStart OS Docker Image - Layer Method"
LABEL version="${BUILD_VERSION}"
LABEL architecture="x86_64"
LABEL variant="layer"
LABEL build.method="rootfs-layer"

# Set environment variables
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV LANG="zh_CN.UTF-8"
ENV LC_ALL="zh_CN.UTF-8"
ENV TERM="xterm"
ENV NEWSTART_VERSION="${BUILD_VERSION}"

# Expose standard ports
EXPOSE 22 80 443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD test -x /usr/local/bin/init.sh || exit 1

# Use init script as entrypoint
CMD ["/usr/local/bin/init.sh", "/bin/bash"]

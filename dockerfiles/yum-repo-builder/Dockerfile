# Dockerfile for NewStart OS YUM Repository Builder
# This container provides all necessary tools to create YUM repositories from NewStart OS ISOs

FROM rockylinux:8

# Install required packages
# Install EPEL repository first for additional packages
RUN dnf install -y epel-release && \
    dnf install -y --allowerasing \
        createrepo_c \
        jq \
        rsync \
        wget \
        curl \
        util-linux \
        coreutils \
        findutils \
        gzip \
        tar \
        sudo \
        p7zip \
        && dnf clean all

# Create working directory
WORKDIR /workspace

# Create directories for ISOs and repositories
RUN mkdir -p /workspace/iso /workspace/yum-repo /workspace/config /workspace/scripts

# Copy configuration and scripts
COPY config/ /workspace/config/
COPY scripts/create-yum-repo.sh /workspace/scripts/

# Make script executable
RUN chmod +x /workspace/scripts/create-yum-repo.sh

# Keep running as root to avoid permission issues with mounting and directory creation
# The container is run with --rm so security is not a major concern

# Set environment variables
ENV PATH="/workspace/scripts:$PATH"
ENV PROJECT_ROOT="/workspace"

# Default command
CMD ["/workspace/scripts/create-yum-repo.sh", "--help"]
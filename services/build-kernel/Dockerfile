FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install kernel build dependencies
RUN apt-get update && apt-get install -y \
    bc \
    bison \
    flex \
    libelf-dev \
    libssl-dev \
    gcc \
    make \
    cpio \
    kmod \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Copy build script
# Copy common utilities
COPY common /usr/local/lib/easylfs-common

COPY build-kernel/scripts/build_kernel.sh /usr/local/bin/build_kernel.sh
RUN chmod +x /usr/local/bin/build_kernel.sh

WORKDIR /

ENTRYPOINT ["/usr/local/bin/build_kernel.sh"]

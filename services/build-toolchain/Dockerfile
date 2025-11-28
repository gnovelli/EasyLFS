FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install host dependencies (LFS Chapter 2 requirements)
RUN apt-get update && apt-get install -y \
    bash \
    binutils \
    bison \
    coreutils \
    diffutils \
    findutils \
    gawk \
    gcc \
    g++ \
    grep \
    gzip \
    m4 \
    make \
    patch \
    perl \
    python3 \
    sed \
    tar \
    texinfo \
    xz-utils \
    file \
    && rm -rf /var/lib/apt/lists/*

# Create lfs user (UID 1000)
RUN groupadd lfs && \
    useradd -s /bin/bash -g lfs -m -k /dev/null lfs

# Create necessary directories
RUN mkdir -pv /lfs /tools && \
    chown -v lfs:lfs /lfs /tools

# Copy common utilities
COPY common /usr/local/lib/easylfs-common

# Copy build script
COPY build-toolchain/scripts/build_toolchain.sh /usr/local/bin/build_toolchain.sh
RUN chmod +x /usr/local/bin/build_toolchain.sh

# Switch to lfs user for building
USER lfs

WORKDIR /lfs

ENTRYPOINT ["/usr/local/bin/build_toolchain.sh"]

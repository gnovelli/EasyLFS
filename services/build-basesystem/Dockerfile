FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
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
    util-linux \
    && rm -rf /var/lib/apt/lists/*

# Copy build script
# Copy common utilities
COPY common /usr/local/lib/easylfs-common

COPY build-basesystem/scripts/build_system.sh /usr/local/bin/build_system.sh
COPY build-basesystem/scripts/build_in_chroot.sh /usr/local/bin/build_in_chroot.sh
RUN chmod +x /usr/local/bin/build_system.sh /usr/local/bin/build_in_chroot.sh

WORKDIR /

ENTRYPOINT ["/usr/local/bin/build_system.sh"]

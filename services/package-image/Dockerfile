FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install image creation tools
RUN apt-get update && apt-get install -y \
    grub-pc-bin \
    grub-efi-amd64-bin \
    grub-common \
    xorriso \
    mtools \
    dosfstools \
    parted \
    e2fsprogs \
    rsync \
    squashfs-tools \
    udev \
    && rm -rf /var/lib/apt/lists/*

# Copy packaging script
# Copy common utilities
COPY common /usr/local/lib/easylfs-common

COPY package-image/scripts/package_image.sh /usr/local/bin/package_image.sh
RUN chmod +x /usr/local/bin/package_image.sh

WORKDIR /

ENTRYPOINT ["/usr/local/bin/package_image.sh"]

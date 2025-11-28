FROM ubuntu:22.04

# Install minimal utilities
RUN apt-get update && apt-get install -y \
    bash \
    coreutils \
    && rm -rf /var/lib/apt/lists/*

# Copy configuration script
# Copy common utilities
COPY common /usr/local/lib/easylfs-common

COPY configure-system/scripts/configure_system.sh /usr/local/bin/configure_system.sh
RUN chmod +x /usr/local/bin/configure_system.sh

WORKDIR /

ENTRYPOINT ["/usr/local/bin/configure_system.sh"]

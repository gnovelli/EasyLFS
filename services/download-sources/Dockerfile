FROM alpine:3.19

# Install download tools
RUN apk add --no-cache \
    wget \
    ca-certificates \
    gnupg \
    coreutils \
    bash \
    parallel

WORKDIR /sources

# Copy common utilities
COPY common /usr/local/lib/easylfs-common

# Copy download script
COPY download-sources/scripts/download.sh /usr/local/bin/download.sh
RUN chmod +x /usr/local/bin/download.sh

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/download.sh"]

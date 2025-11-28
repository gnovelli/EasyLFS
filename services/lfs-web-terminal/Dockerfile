FROM alpine:3.19

# Install ttyd, QEMU, and required tools
RUN apk add --no-cache \
    ttyd \
    qemu-system-x86_64 \
    bash \
    coreutils

# Create directory for LFS image
RUN mkdir -p /lfs-dist

# Copy startup script
COPY lfs-web-terminal/scripts/start-web-terminal.sh /usr/local/bin/start-web-terminal.sh
RUN chmod +x /usr/local/bin/start-web-terminal.sh

# Expose ttyd default port
EXPOSE 7681

# Set working directory
WORKDIR /lfs-dist

# Start ttyd server
CMD ["/usr/local/bin/start-web-terminal.sh"]

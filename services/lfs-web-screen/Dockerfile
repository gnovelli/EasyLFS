FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install QEMU, VNC server, noVNC and dependencies
RUN apt-get update && apt-get install -y \
    qemu-system-x86 \
    tigervnc-standalone-server \
    tigervnc-common \
    novnc \
    websockify \
    python3 \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

# Create directory for LFS image
RUN mkdir -p /lfs-dist

# Copy startup script
COPY lfs-web-screen/scripts/start-web-screen.sh /usr/local/bin/start-web-screen.sh
RUN chmod +x /usr/local/bin/start-web-screen.sh

# Expose noVNC port
EXPOSE 6080

# Set working directory
WORKDIR /lfs-dist

# Start web screen service
CMD ["/usr/local/bin/start-web-screen.sh"]

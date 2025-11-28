FROM docker:24-cli

# Install test utilities
RUN apk add --no-cache \
    bash \
    coreutils \
    grep \
    sed \
    findutils \
    util-linux \
    curl \
    jq

# Install docker-compose
RUN apk add --no-cache docker-compose

# Copy test scripts
COPY scripts/ /tests/

# Make scripts executable
RUN chmod +x /tests/*.sh

WORKDIR /tests

# Default entrypoint
ENTRYPOINT ["/tests/test_runner.sh"]

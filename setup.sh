#!/bin/bash
# EasyLFS Setup Script
# Automatically initializes Docker volumes and prepares the environment

set -e

echo "========================================="
echo "EasyLFS - Easy Linux From Scratch"
echo "Environment Setup"
echo "========================================="
echo ""

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed or not in PATH"
    exit 1
fi

# Check if Docker Compose is available
if ! command -v docker compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "ERROR: Docker Compose is not installed"
    exit 1
fi

echo -e "${YELLOW}[1/3]${NC} Checking Docker volumes..."

# List of required volumes
VOLUMES=(
    "easylfs_lfs-sources"
    "easylfs_lfs-tools"
    "easylfs_lfs-rootfs"
    "easylfs_lfs-dist"
    "easylfs_lfs-logs"
)

# Create volumes if they don't exist
for vol in "${VOLUMES[@]}"; do
    if docker volume inspect "$vol" &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} Volume $vol already exists"
    else
        echo -e "  ${YELLOW}→${NC} Creating volume $vol..."
        docker volume create "$vol" > /dev/null
        echo -e "  ${GREEN}✓${NC} Volume $vol created"
    fi
done

echo ""
echo -e "${YELLOW}[2/3]${NC} Setting volume permissions..."

# Set correct permissions on logs volume (recursive)
docker run --rm -v easylfs_lfs-logs:/logs alpine chmod -R 777 /logs 2>/dev/null
echo -e "  ${GREEN}✓${NC} Log volume permissions set"

echo ""
echo -e "${YELLOW}[3/3]${NC} Building Docker images (no cache to ensure fresh common scripts)..."

# Build each service image individually to show progress
SERVICES=("download-sources" "build-toolchain" "build-basesystem" "configure-system" "build-kernel" "package-image")
for service in "${SERVICES[@]}"; do
    echo -e "  ${YELLOW}→${NC} Building $service..."
    docker compose build --no-cache "$service" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} $service rebuilt successfully"
    else
        echo -e "  ${RED}✗${NC} $service build failed"
        exit 1
    fi
done

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Setup complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "You can now run the build pipeline with:"
echo "  ./build.sh          # Run entire pipeline"
echo "  make build          # Alternative using Make"
echo ""
echo "Or run services individually:"
echo "  docker compose run --rm download-sources"
echo "  docker compose run --rm build-toolchain"
echo "  docker compose run --rm build-basesystem"
echo "  docker compose run --rm configure-system"
echo "  docker compose run --rm build-kernel"
echo "  docker compose run --rm package-image"
echo ""

#!/bin/bash
# EasyLFS Build Script
# Executes the complete LFS build pipeline automatically

set -e

echo "========================================="
echo "EasyLFS - Easy Linux From Scratch"
echo "Complete Build Pipeline"
echo "========================================="
echo ""

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Timestamp function
timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Log function
log_stage() {
    echo ""
    echo -e "${BLUE}[$(timestamp)]${NC} ========================================="
    echo -e "${BLUE}[$(timestamp)]${NC} $1"
    echo -e "${BLUE}[$(timestamp)]${NC} ========================================="
    echo ""
}

# Error handler
trap 'echo -e "${RED}ERROR: Build failed at stage: $CURRENT_STAGE${NC}"; exit 1' ERR

# Run setup if volumes don't exist
if ! docker volume inspect easylfs_lfs-sources &> /dev/null; then
    echo -e "${YELLOW}Volumes not initialized. Running setup...${NC}"
    ./setup.sh
fi

# Build pipeline stages
STAGES=(
    "download-sources:Downloading LFS source packages (Chapter 3):5-10 minutes"
    "build-toolchain:Building cross-compilation toolchain (Chapters 5-6):2-4 hours"
    "build-basesystem:Building base LFS system (Chapters 7-8):3-6 hours"
    "configure-system:Configuring system files (Chapter 9):10-20 minutes"
    "build-kernel:Compiling Linux kernel (Chapter 10):20-60 minutes"
    "package-image:Creating bootable disk image (Chapter 11):15-30 minutes"
)

TOTAL_STAGES=${#STAGES[@]}
CURRENT_STAGE_NUM=0

for stage_info in "${STAGES[@]}"; do
    IFS=':' read -r service description duration <<< "$stage_info"
    CURRENT_STAGE_NUM=$((CURRENT_STAGE_NUM + 1))
    CURRENT_STAGE="$service"

    log_stage "Stage $CURRENT_STAGE_NUM/$TOTAL_STAGES: $description"
    echo -e "${YELLOW}Service:${NC} $service"
    echo -e "${YELLOW}Estimated duration:${NC} $duration"
    echo ""

    START_TIME=$(date +%s)

    # Run the service
    docker compose run --rm "$service"

    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    ELAPSED_MIN=$((ELAPSED / 60))
    ELAPSED_SEC=$((ELAPSED % 60))

    echo ""
    echo -e "${GREEN}✓ Stage $CURRENT_STAGE_NUM completed in ${ELAPSED_MIN}m ${ELAPSED_SEC}s${NC}"
done

# Final summary
echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}BUILD COMPLETE!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Your LFS system has been built successfully!"
echo ""
echo "Final artifacts are in the 'lfs-dist' volume:"
docker run --rm -v easylfs_lfs-dist:/dist alpine ls -lh /dist 2>/dev/null || echo "  (No files yet - check logs)"
echo ""
echo "To boot your LFS system:"
echo "  1. Extract the disk image from the volume:"
echo "     docker run --rm -v easylfs_lfs-dist:/dist -v \$(pwd):/output alpine cp /dist/lfs-12.4-sysv.img /output/"
echo "  2. Boot with QEMU:"
echo "     qemu-system-x86_64 -m 2G -hda lfs-12.4-sysv.img"
echo ""
echo "To inspect build logs:"
echo "     docker run --rm -v easylfs_lfs-logs:/logs alpine ls -lh /logs"
echo ""

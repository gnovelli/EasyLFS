#!/bin/bash
set -e

# =============================================================================
# EasyLFS Volume Validator
# Provides detailed information about Docker volumes
# =============================================================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "EasyLFS Volume Validation Report"
echo "=========================================="
echo ""

for vol in lfs-sources lfs-tools lfs-rootfs lfs-dist; do
    full_name="easylfs_${vol}"

    echo -e "${BLUE}Volume: ${full_name}${NC}"

    if docker volume inspect "$full_name" >/dev/null 2>&1; then
        # Size
        size=$(docker run --rm -v "${full_name}:/v" alpine du -sh /v 2>/dev/null | awk '{print $1}')
        echo "  Size: $size"

        # File count
        file_count=$(docker run --rm -v "${full_name}:/v" alpine \
            sh -c 'find /v -type f 2>/dev/null | wc -l')
        echo "  Files: $file_count"

        # Top-level contents
        echo "  Contents:"
        docker run --rm -v "${full_name}:/v" alpine ls -lh /v 2>/dev/null | head -10 | sed 's/^/    /'

    else
        echo "  Status: NOT FOUND"
    fi

    echo ""
done

echo "=========================================="
echo "Total Docker Volume Usage"
echo "=========================================="
docker system df -v | grep "easylfs_" || echo "No EasyLFS volumes found"

#!/bin/bash
set -e

# =============================================================================
# EasyLFS Full Pipeline Test
# Runs complete build and validation
# Duration: 6-11 hours
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_test() { echo -e "${BLUE}[TEST]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((PASSED++)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAILED++)); }

echo "=========================================="
echo "EasyLFS Full Pipeline Test"
echo "=========================================="
echo "Start time: $(date)"
echo ""

# Cleanup previous state
log_info "Cleaning up previous test state..."
docker compose down -v 2>/dev/null || true

echo ""

# =============================================================================
# Service 1: download-sources
# =============================================================================
log_test "Service 1/6: download-sources"

start=$(date +%s)
if docker compose run --rm download-sources; then
    end=$(date +%s)
    duration=$((end - start))
    log_pass "download-sources completed in ${duration}s"

    # Validate
    file_count=$(docker run --rm -v easylfs_lfs-sources:/sources alpine \
        sh -c 'ls /sources/*.tar.* 2>/dev/null | wc -l')

    if [ "$file_count" -ge 90 ]; then
        log_pass "Found $file_count source files"
    else
        log_fail "Only $file_count source files (expected ~100)"
    fi
else
    log_fail "download-sources failed"
fi

echo ""

# =============================================================================
# Service 2: build-toolchain
# =============================================================================
log_test "Service 2/6: build-toolchain (this takes 2-4 hours)"

start=$(date +%s)
if docker compose run --rm build-toolchain; then
    end=$(date +%s)
    duration=$((end - start))
    hours=$((duration / 3600))
    minutes=$(((duration % 3600) / 60))
    log_pass "build-toolchain completed in ${hours}h ${minutes}m"

    # Validate
    if docker run --rm -v easylfs_lfs-tools:/tools alpine test -f /tools/bin/gcc; then
        log_pass "Cross-compiler found"
    else
        log_fail "Cross-compiler not found"
    fi
else
    log_fail "build-toolchain failed"
fi

echo ""

# =============================================================================
# Service 3: build-basesystem
# =============================================================================
log_test "Service 3/6: build-basesystem (this takes 3-6 hours)"

start=$(date +%s)
if docker compose run --rm build-basesystem; then
    end=$(date +%s)
    duration=$((end - start))
    hours=$((duration / 3600))
    minutes=$(((duration % 3600) / 60))
    log_pass "build-basesystem completed in ${hours}h ${minutes}m"

    # Validate
    if docker run --rm -v easylfs_lfs-rootfs:/lfs alpine test -f /lfs/bin/bash; then
        log_pass "Bash found in base system"
    else
        log_fail "Bash not found"
    fi
else
    log_fail "build-basesystem failed"
fi

echo ""

# =============================================================================
# Service 4: configure-system
# =============================================================================
log_test "Service 4/6: configure-system"

start=$(date +%s)
if docker compose run --rm configure-system; then
    end=$(date +%s)
    duration=$((end - start))
    log_pass "configure-system completed in ${duration}s"

    # Validate
    if docker run --rm -v easylfs_lfs-rootfs:/lfs alpine test -f /lfs/etc/fstab; then
        log_pass "System configuration files created"
    else
        log_fail "Configuration files missing"
    fi
else
    log_fail "configure-system failed"
fi

echo ""

# =============================================================================
# Service 5: build-kernel
# =============================================================================
log_test "Service 5/6: build-kernel (this takes 20-60 minutes)"

start=$(date +%s)
if docker compose run --rm build-kernel; then
    end=$(date +%s)
    duration=$((end - start))
    minutes=$((duration / 60))
    log_pass "build-kernel completed in ${minutes}m"

    # Validate
    if docker run --rm -v easylfs_lfs-rootfs:/lfs alpine test -f /lfs/boot/vmlinuz; then
        log_pass "Kernel image created"
    else
        log_fail "Kernel image not found"
    fi
else
    log_fail "build-kernel failed"
fi

echo ""

# =============================================================================
# Service 6: package-image
# =============================================================================
log_test "Service 6/6: package-image"

start=$(date +%s)
if docker compose run --rm package-image; then
    end=$(date +%s)
    duration=$((end - start))
    minutes=$((duration / 60))
    log_pass "package-image completed in ${minutes}m"

    # Validate
    if docker run --rm -v easylfs_lfs-dist:/dist alpine test -f /dist/lfs-12.4-sysv.img.gz; then
        log_pass "Bootable image created"
    else
        log_fail "Bootable image not found"
    fi
else
    log_fail "package-image failed"
fi

echo ""
echo "=========================================="
echo "Pipeline Test Summary"
echo "=========================================="
echo "End time: $(date)"
echo ""
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo "=========================================="

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}FULL PIPELINE TEST PASSED!${NC}"
    exit 0
else
    echo -e "${RED}PIPELINE TEST FAILED!${NC}"
    exit 1
fi

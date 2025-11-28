#!/bin/bash
set -e

# =============================================================================
# EasyLFS Quick Test - Fast Validation (No Build)
# Verifies that volumes contain expected files
# Duration: ~5 minutes
# =============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0

log_test() { echo -e "${BLUE}[TEST]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((PASSED++)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAILED++)); }
log_skip() { echo -e "${YELLOW}[SKIP]${NC} $1"; }

echo "=========================================="
echo "Quick Validation Test"
echo "=========================================="
echo ""

# Test 1: Check if volumes exist
log_test "Checking Docker volumes..."

for vol in lfs-sources lfs-tools lfs-rootfs lfs-dist; do
    if docker volume inspect "easylfs_${vol}" >/dev/null 2>&1; then
        log_pass "Volume easylfs_${vol} exists"
    else
        log_skip "Volume easylfs_${vol} not found (run pipeline first)"
    fi
done

echo ""

# Test 2: Validate lfs-sources
log_test "Validating lfs-sources volume..."

if docker volume inspect easylfs_lfs-sources >/dev/null 2>&1; then
    file_count=$(docker run --rm -v easylfs_lfs-sources:/v alpine \
        sh -c 'ls /v/*.tar.* 2>/dev/null | wc -l' || echo "0")

    if [ "$file_count" -ge 90 ]; then
        log_pass "Found $file_count source files (expected ~100)"
    elif [ "$file_count" -gt 0 ]; then
        log_fail "Only $file_count source files found (expected ~100)"
    else
        log_skip "No source files found (run download-sources)"
    fi

    if docker run --rm -v easylfs_lfs-sources:/v alpine test -f /v/md5sums; then
        log_pass "Checksum file (md5sums) present"
    else
        log_skip "Checksum file not found"
    fi
else
    log_skip "lfs-sources volume not found"
fi

echo ""

# Test 3: Validate lfs-tools
log_test "Validating lfs-tools volume..."

if docker volume inspect easylfs_lfs-tools >/dev/null 2>&1; then
    if docker run --rm -v easylfs_lfs-tools:/v alpine test -f /v/bin/gcc; then
        log_pass "Cross-compiler (gcc) found in tools"
    else
        log_skip "Cross-compiler not found (run build-toolchain)"
    fi
else
    log_skip "lfs-tools volume not found"
fi

echo ""

# Test 4: Validate lfs-rootfs
log_test "Validating lfs-rootfs volume..."

if docker volume inspect easylfs_lfs-rootfs >/dev/null 2>&1; then
    # Check essential files
    for file in bin/bash etc/passwd usr/bin/gcc; do
        if docker run --rm -v easylfs_lfs-rootfs:/v alpine test -f "/v/$file"; then
            log_pass "File /$file exists"
        else
            log_skip "File /$file not found"
        fi
    done

    # Check kernel
    if docker run --rm -v easylfs_lfs-rootfs:/v alpine test -f /v/boot/vmlinuz; then
        log_pass "Kernel image (vmlinuz) found"

        # Check kernel size
        size=$(docker run --rm -v easylfs_lfs-rootfs:/v alpine stat -c%s /v/boot/vmlinuz)
        if [ "$size" -gt 5000000 ] && [ "$size" -lt 20000000 ]; then
            log_pass "Kernel size OK ($(($size / 1024 / 1024))MB)"
        else
            log_fail "Kernel size unexpected: $(($size / 1024 / 1024))MB"
        fi
    else
        log_skip "Kernel not found (run build-kernel)"
    fi

    # Check modules
    module_count=$(docker run --rm -v easylfs_lfs-rootfs:/v alpine \
        sh -c 'find /v/lib/modules -name "*.ko" 2>/dev/null | wc -l' || echo "0")

    if [ "$module_count" -gt 0 ]; then
        log_pass "Found $module_count kernel modules"
    else
        log_skip "No kernel modules found"
    fi
else
    log_skip "lfs-rootfs volume not found"
fi

echo ""

# Test 5: Validate lfs-dist
log_test "Validating lfs-dist volume..."

if docker volume inspect easylfs_lfs-dist >/dev/null 2>&1; then
    if docker run --rm -v easylfs_lfs-dist:/v alpine test -f /v/lfs-12.4-sysv.img.gz; then
        log_pass "Disk image found (lfs-12.4-sysv.img.gz)"

        size=$(docker run --rm -v easylfs_lfs-dist:/v alpine stat -c%s /v/lfs-12.4-sysv.img.gz)
        log_pass "Image size: $(($size / 1024 / 1024))MB"
    else
        log_skip "Disk image not found (run package-image)"
    fi

    if docker run --rm -v easylfs_lfs-dist:/v alpine test -f /v/lfs-12.4-sysv.tar.gz; then
        log_pass "System tarball found"
    else
        log_skip "System tarball not found"
    fi
else
    log_skip "lfs-dist volume not found"
fi

echo ""

# Test 6: Disk usage
log_test "Checking disk usage..."

for vol in lfs-sources lfs-tools lfs-rootfs lfs-dist; do
    if docker volume inspect "easylfs_${vol}" >/dev/null 2>&1; then
        size=$(docker run --rm -v "easylfs_${vol}:/v" alpine du -sh /v 2>/dev/null | awk '{print $1}')
        echo "  easylfs_${vol}: $size"
    fi
done

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo "=========================================="

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}Quick validation PASSED!${NC}"
    exit 0
else
    echo -e "${RED}Some validations FAILED!${NC}"
    exit 1
fi

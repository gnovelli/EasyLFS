#!/bin/bash
set -euo pipefail

# =============================================================================
# EasyLFS Build Base System Script - MINIMAL VERSION
# Builds essential LFS system in chroot (LFS Chapters 7-8)
# MINIMAL - ~20 essential packages for bootable SysV init system
# Duration: ~30 minutes (reduced from 6-12 hours)
# =============================================================================

# Environment
export LFS="${LFS:-/lfs}"
export MAKEFLAGS="${MAKEFLAGS:--j$(nproc)}"

SOURCES_DIR="/sources"
BUILD_DIR="/build"

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Load common utilities
COMMON_DIR="/usr/local/lib/easylfs-common"
if [ -d "$COMMON_DIR" ]; then
    source "$COMMON_DIR/logging.sh" 2>/dev/null || true
    source "$COMMON_DIR/checkpointing.sh" 2>/dev/null || true
else
    # Fallback for development/local testing
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/../../common/logging.sh" 2>/dev/null || true
    source "$SCRIPT_DIR/../../common/checkpointing.sh" 2>/dev/null || true
fi

# Fallback logging if common module not available
if ! type log_info &>/dev/null; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
    log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
    log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
    log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
    log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
fi

# Verify prerequisites
verify_prerequisites() {
    log_info "Verifying prerequisites..."

    if [ ! -d "$LFS" ]; then
        log_error "LFS directory not found: $LFS"
        exit 1
    fi

    if [ ! -f "$LFS/tools/bin/x86_64-lfs-linux-gnu-gcc" ] && [ ! -f "$LFS/usr/bin/gcc" ]; then
        log_error "Neither temporary toolchain nor final gcc found. Run build-toolchain first!"
        exit 1
    fi

    if [ -f "$LFS/usr/bin/gcc" ]; then
        log_info "Final gcc found - resuming partially completed build"
    else
        log_info "Temporary toolchain found - starting fresh build"
    fi

    log_info "Prerequisites OK"
}

# Prepare chroot environment
prepare_chroot() {
    log_info "Preparing chroot environment..."

    # Create essential directories
    mkdir -pv $LFS/{dev,proc,sys,run,tmp}

    # Create essential device nodes
    if [ ! -c "$LFS/dev/null" ]; then
        mknod -m 600 $LFS/dev/console c 5 1 2>/dev/null || true
        mknod -m 666 $LFS/dev/null c 1 3 2>/dev/null || true
    fi

    # Mount virtual filesystems
    log_info "Mounting virtual filesystems..."
    mount --bind /dev $LFS/dev || log_warn "Failed to mount /dev"
    mount -t devpts devpts $LFS/dev/pts -o gid=5,mode=620 || log_warn "Failed to mount /dev/pts"
    mount -t proc proc $LFS/proc || log_warn "Failed to mount /proc"
    mount -t sysfs sysfs $LFS/sys || log_warn "Failed to mount /sys"
    mount -t tmpfs tmpfs $LFS/run || log_warn "Failed to mount /run"

    # Bind mount sources
    mkdir -p $LFS/sources
    if [ -d "$SOURCES_DIR" ]; then
        mount --bind $SOURCES_DIR $LFS/sources || log_warn "Failed to mount sources"
    fi

    # Copy common utilities into chroot
    log_info "Copying common utilities into chroot..."
    mkdir -p $LFS/tmp/easylfs-common

    # Copy checkpointing module
    if [ -f "/usr/local/lib/easylfs-common/checkpointing.sh" ]; then
        cp "/usr/local/lib/easylfs-common/checkpointing.sh" $LFS/tmp/easylfs-common/ && log_info "✓ Checkpointing module copied"
    elif [ -f "$SCRIPT_DIR/../../common/checkpointing.sh" ]; then
        cp "$SCRIPT_DIR/../../common/checkpointing.sh" $LFS/tmp/easylfs-common/ && log_info "✓ Checkpointing module copied (fallback)"
    else
        log_warn "⚠ Failed to copy checkpointing.sh - file not found"
    fi

    # Copy logging module
    if [ -f "/usr/local/lib/easylfs-common/logging.sh" ]; then
        cp "/usr/local/lib/easylfs-common/logging.sh" $LFS/tmp/easylfs-common/ && log_info "✓ Logging module copied"
    elif [ -f "$SCRIPT_DIR/../../common/logging.sh" ]; then
        cp "$SCRIPT_DIR/../../common/logging.sh" $LFS/tmp/easylfs-common/ && log_info "✓ Logging module copied (fallback)"
    else
        log_warn "⚠ Failed to copy logging.sh - file not found"
    fi

    # Initialize checkpoint system
    init_checkpointing
    log_info "Checkpoint system initialized"

    log_info "Chroot environment ready"
}

# Cleanup chroot mounts
cleanup_chroot() {
    log_info "Cleaning up chroot mounts..."

    umount -l $LFS/sources 2>/dev/null || true
    umount -l $LFS/dev/pts 2>/dev/null || true
    umount -l $LFS/dev 2>/dev/null || true
    umount -l $LFS/proc 2>/dev/null || true
    umount -l $LFS/sys 2>/dev/null || true
    umount -l $LFS/run 2>/dev/null || true

    log_info "Cleanup complete"
}

# Trap to ensure cleanup on exit
trap cleanup_chroot EXIT INT TERM

# Enter chroot and build system
build_in_chroot() {
    log_info "Entering chroot environment..."

    # Copy the chroot build script into the chroot environment
    log_info "Copying chroot build script..."
    cp "$SCRIPT_DIR/build_in_chroot.sh" $LFS/tmp/build_in_chroot.sh

    chmod +x $LFS/tmp/build_in_chroot.sh

    # Execute chroot with unbuffered output for real-time logging
    log_info "Executing chroot build script..."
    log_info "Output will be shown in real-time (unbuffered)..."

    # Create log file with proper permissions
    touch $LFS/tmp/chroot_build.log
    chmod 666 $LFS/tmp/chroot_build.log

    set +e  # Don't exit on error, we want to capture the exit code

    # Use stdbuf to disable buffering for real-time output
    # Save to both console and log file
    stdbuf -oL -eL chroot "$LFS" /usr/bin/env -i \
        HOME=/root \
        TERM="$TERM" \
        PS1='(lfs chroot) \u:\w\$ ' \
        PATH=/usr/bin:/usr/sbin:/bin:/sbin:/tools/bin \
        MAKEFLAGS="$MAKEFLAGS" \
        LC_ALL=POSIX \
        BUILD_STAGE="${BUILD_STAGE:-all}" \
        /bin/bash /tmp/build_in_chroot.sh 2>&1 | stdbuf -oL -eL tee $LFS/tmp/chroot_build.log

    CHROOT_EXIT_CODE=${PIPESTATUS[0]}
    set -e

    echo ""
    echo "========================================"
    log_info "Chroot script exited with code: $CHROOT_EXIT_CODE"
    echo "========================================"
    echo ""

    # Check if build was successful
    if [ $CHROOT_EXIT_CODE -eq 0 ]; then
        log_info "✓✓✓ CHROOT SCRIPT COMPLETED SUCCESSFULLY ✓✓✓"

        # Verify success marker exists
        if [ -f "$LFS/tmp/build_status" ]; then
            log_info "✓ Build status marker found:"
            cat "$LFS/tmp/build_status" | while read line; do
                log_info "  $line"
            done
        else
            log_warn "⚠ Build status marker not found - build may have failed silently"
            log_warn "Checking for essential files..."

            # Additional verification
            if chroot "$LFS" /usr/bin/env -i bash -c "test -f /sbin/init" 2>/dev/null; then
                log_info "✓ /sbin/init found - build likely succeeded"
            else
                log_error "✗ /sbin/init NOT found - build incomplete"
                CHROOT_EXIT_CODE=1
            fi
        fi
    else
        log_error "✗✗✗ CHROOT BUILD FAILED ✗✗✗"
        log_error "Exit code: $CHROOT_EXIT_CODE"
        log_error ""
        log_error "To view the full log:"
        log_error "  docker run --rm -v easylfs_lfs-rootfs:/lfs alpine cat /lfs/tmp/chroot_build.log"
        log_error ""
        log_error "To view last 50 lines:"
        log_error "  docker run --rm -v easylfs_lfs-rootfs:/lfs alpine tail -50 /lfs/tmp/chroot_build.log"
        echo ""
        rm -f $LFS/tmp/build_in_chroot.sh
        exit $CHROOT_EXIT_CODE
    fi

    rm -f $LFS/tmp/build_in_chroot.sh

    # Final exit with the captured code
    if [ $CHROOT_EXIT_CODE -ne 0 ]; then
        exit $CHROOT_EXIT_CODE
    fi
}

# Main
main() {
    log_info "=========================================="
    log_info "EasyLFS Base System Build Starting (MINIMAL)"
    log_info "~43 essential packages will be built"
    log_info "=========================================="

    # Idempotency check - look for build success marker
    if [ -f "$LFS/tmp/build_status" ]; then
        log_info ""
        log_info "=========================================="
        log_info "Minimal Base System Already Built - Skipping"
        log_info "=========================================="
        log_info "Build status:"
        cat "$LFS/tmp/build_status" | while read line; do
            log_info "  $line"
        done
        log_info ""
        log_info "To force rebuild, remove $LFS/tmp/build_status"
        log_info "=========================================="
        exit 0
    fi

    verify_prerequisites
    prepare_chroot
    build_in_chroot

    log_info ""
    log_info "=========================================="
    log_info "Minimal Base System Build Finished!"
    log_info "=========================================="
    log_info "~43 essential packages from Chapter 8 installed"
    log_info "Next: run build-kernel and package-image"
    log_info "=========================================="

    exit 0
}

main "$@"

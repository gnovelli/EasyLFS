#!/bin/bash
set -euo pipefail

# =============================================================================
# EasyLFS Build Kernel Script
# Compiles the Linux kernel (LFS Chapter 10)
# Duration: 20-60 minutes
# =============================================================================

export LFS="${LFS:-/lfs}"
export MAKEFLAGS="${MAKEFLAGS:--j$(nproc)}"
export KERNEL_VERSION="${KERNEL_VERSION:-6.12.6}"

SOURCES_DIR="/sources"
BUILD_DIR="/tmp/kernel-build"

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

# Fallback logging functions if not loaded
if ! type log_info &>/dev/null; then
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    NC='\033[0m'
    log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
    log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
fi

main() {
    log_info "=========================================="
    log_info "Building Linux Kernel $KERNEL_VERSION"
    log_info "=========================================="

    # Initialize checkpoint system
    init_checkpointing

    # Check if kernel already built
    # Use "linux" as package name since source file is linux-*.tar.xz
    if should_skip_package "linux" "$SOURCES_DIR"; then
        log_info "Kernel $KERNEL_VERSION already built - skipping"
        exit 0
    fi

    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    # Extract kernel source
    log_step "Extracting kernel source..."
    tar -xf $SOURCES_DIR/linux-*.tar.xz
    cd linux-*/

    # Clean build environment
    log_step "Preparing build environment..."
    make mrproper

    # Configure kernel
    log_step "Configuring kernel..."

    # Use defconfig as base
    make defconfig

    # Apply essential configurations for LFS + SysVinit
    log_info "Applying essential kernel configurations..."

    # Enable required features
    scripts/config --enable CONFIG_DEVTMPFS
    scripts/config --enable CONFIG_CGROUPS
    scripts/config --enable CONFIG_INOTIFY_USER
    scripts/config --enable CONFIG_SIGNALFD
    scripts/config --enable CONFIG_TIMERFD
    scripts/config --enable CONFIG_EPOLL
    scripts/config --enable CONFIG_NET
    scripts/config --enable CONFIG_SYSFS
    scripts/config --enable CONFIG_PROC_FS
    scripts/config --enable CONFIG_FHANDLE
    scripts/config --enable CONFIG_CRYPTO_USER_API_HASH
    scripts/config --enable CONFIG_CRYPTO_HMAC
    scripts/config --enable CONFIG_CRYPTO_SHA256
    scripts/config --enable CONFIG_TMPFS_XATTR
    scripts/config --enable CONFIG_TMPFS_POSIX_ACL
    scripts/config --enable CONFIG_EXT4_FS
    scripts/config --enable CONFIG_EXT4_FS_POSIX_ACL
    scripts/config --enable CONFIG_EXT4_FS_SECURITY
    scripts/config --enable CONFIG_AUTOFS4_FS
    scripts/config --enable CONFIG_UNIX

    # Enable EFI support
    scripts/config --enable CONFIG_EFI
    scripts/config --enable CONFIG_EFI_STUB
    scripts/config --enable CONFIG_EFI_VARS

    # Network support
    scripts/config --enable CONFIG_PACKET
    scripts/config --enable CONFIG_INET

    # Storage support
    scripts/config --enable CONFIG_BLK_DEV_SD
    scripts/config --enable CONFIG_ATA
    scripts/config --enable CONFIG_ATA_PIIX
    scripts/config --enable CONFIG_SATA_AHCI

    # VirtIO support (required for QEMU/KVM)
    scripts/config --enable CONFIG_VIRTIO
    scripts/config --enable CONFIG_VIRTIO_PCI
    scripts/config --enable CONFIG_VIRTIO_BLK
    scripts/config --enable CONFIG_VIRTIO_NET
    scripts/config --enable CONFIG_VIRTIO_CONSOLE

    # Ensure kernel is relocatable and BIOS-bootable
    scripts/config --enable CONFIG_RELOCATABLE

    # Serial console support for -nographic
    scripts/config --enable CONFIG_SERIAL_8250
    scripts/config --enable CONFIG_SERIAL_8250_CONSOLE

    # Save configuration
    make olddefconfig

    # Show configuration summary
    log_info "Kernel configuration summary:"
    grep -E "CONFIG_(DEVTMPFS|CGROUPS|EXT4_FS|VIRTIO)=" .config || true

    # Build kernel
    log_step "Compiling kernel (this may take 20-60 minutes)..."
    make $MAKEFLAGS

    # Install modules
    log_step "Installing kernel modules..."
    make INSTALL_MOD_PATH=$LFS modules_install

    # Install kernel
    log_step "Installing kernel image..."

    # Create boot directory if it doesn't exist
    mkdir -p $LFS/boot

    # Copy kernel image (using command to bypass aliases)
    command cp -fv arch/x86/boot/bzImage $LFS/boot/vmlinuz-$KERNEL_VERSION-lfs
    command cp -fv System.map $LFS/boot/System.map-$KERNEL_VERSION
    command cp -fv .config $LFS/boot/config-$KERNEL_VERSION

    # Create symlinks (remove existing first to avoid prompts)
    rm -f $LFS/boot/vmlinuz $LFS/boot/System.map $LFS/boot/config
    ln -sf vmlinuz-$KERNEL_VERSION-lfs $LFS/boot/vmlinuz
    ln -sf System.map-$KERNEL_VERSION $LFS/boot/System.map
    ln -sf config-$KERNEL_VERSION $LFS/boot/config

    # Install kernel headers
    log_step "Installing kernel documentation..."
    install -d $LFS/usr/share/doc/linux-$KERNEL_VERSION
    command cp -rf Documentation/* $LFS/usr/share/doc/linux-$KERNEL_VERSION/ 2>/dev/null || true

    # Cleanup
    cd /
    rm -rf "$BUILD_DIR"

    log_info ""
    log_info "=========================================="
    log_info "Kernel Build Complete!"
    log_info "=========================================="
    log_info "Kernel: $LFS/boot/vmlinuz-$KERNEL_VERSION-lfs"
    log_info "Modules: $LFS/lib/modules/$KERNEL_VERSION"

    # Verify kernel image
    if [ -f "$LFS/boot/vmlinuz-$KERNEL_VERSION-lfs" ]; then
        log_info "Kernel image size: $(du -h $LFS/boot/vmlinuz-$KERNEL_VERSION-lfs | cut -f1)"
    fi

    # Create checkpoint
    # Use "linux" as package name to match source file linux-*.tar.xz
    create_checkpoint "linux" "$SOURCES_DIR" "kernel"
    log_info "✓ Kernel checkpoint created"

    exit 0
}

main "$@"

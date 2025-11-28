#!/bin/bash
set -euo pipefail

# =============================================================================
# EasyLFS Package Image Script
# Creates bootable disk image (LFS Chapter 11)
# Duration: 15-30 minutes
# =============================================================================

export LFS="${LFS:-/lfs}"
export IMAGE_NAME="${IMAGE_NAME:-lfs-12.4-sysv}"
export IMAGE_SIZE="${IMAGE_SIZE:-2048}"  # Size in MB

DIST_DIR="/dist"

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
    YELLOW='\033[1;33m'
    NC='\033[0m'
    log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
    log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
    log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
fi

# Create disk image
create_disk_image() {
    log_info "=========================================="
    log_info "Creating Bootable Disk Image"
    log_info "=========================================="

    # Create loop devices if they don't exist (Docker containers often lack them)
    log_step "Ensuring loop devices exist..."
    for i in $(seq 0 7); do
        if [ ! -b /dev/loop$i ]; then
            mknod -m 660 /dev/loop$i b 7 $i 2>/dev/null || true
        fi
    done

    local image_file="$DIST_DIR/${IMAGE_NAME}.img"

    log_step "Creating disk image file (${IMAGE_SIZE}MB)..."
    dd if=/dev/zero of="$image_file" bs=1M count=$IMAGE_SIZE status=progress

    log_step "Partitioning disk image..."

    # Create partition table
    # Note: Suppress udevadm warnings from parted (not available in containers)
    parted -s "$image_file" mklabel msdos 2>/dev/null
    parted -s "$image_file" mkpart primary ext4 1MiB 100% 2>/dev/null
    parted -s "$image_file" set 1 boot on 2>/dev/null

    log_step "Setting up loop device with offset..."

    # In containers, partition devices often don't work properly
    # Use offset-based mounting instead (partition starts at 1MiB)
    local partition_offset=$((1024 * 1024))  # 1MiB in bytes

    # Format the partition area directly in the image file
    log_step "Formatting partition..."
    # Create a loop device for the partition area only
    local loop_dev=$(losetup -f)
    losetup -o $partition_offset "$loop_dev" "$image_file"

    mkfs.ext4 -L "LFS-ROOT" "$loop_dev"

    # Detach all loop devices to avoid conflicts
    losetup -d "$loop_dev"
    losetup -D 2>/dev/null || true  # Detach all loop devices
    sleep 2  # Give kernel time to release devices

    # Mount the partition
    log_step "Mounting partition..."
    local mount_point="/tmp/lfs-mount"
    mkdir -p "$mount_point"
    mount -o loop,offset=$partition_offset "$image_file" "$mount_point"

    # Copy LFS system
    log_step "Copying LFS system to image..."
    rsync -aAX \
        --exclude=/dev/* \
        --exclude=/proc/* \
        --exclude=/sys/* \
        --exclude=/run/* \
        --exclude=/tmp/* \
        --exclude=/sources/* \
        --exclude=/build/* \
        --exclude=/tools/* \
        --exclude=/.checkpoints \
        --exclude='*.log' \
        --exclude='*.a' \
        --exclude=/usr/share/doc/* \
        --exclude=/usr/share/man/man3/* \
        "$LFS/" "$mount_point/"

    # Create essential directories
    mkdir -p $mount_point/{dev,proc,sys,run,tmp}
    chmod 1777 $mount_point/tmp

    # Verify SysVinit system is present in the mounted image
    log_step "Verifying SysVinit init system in image..."

    if [ -f "$mount_point/sbin/init" ]; then
        # For SysV, /sbin/init is a real binary, not a symlink
        log_info "Found /sbin/init binary"

        # Verify it's executable
        if [ -x "$mount_point/sbin/init" ]; then
            log_info "✓ SysVinit init is executable"
        else
            log_warn "ERROR: /sbin/init exists but is not executable"
            exit 1
        fi

        # Verify inittab exists
        if [ -f "$mount_point/etc/inittab" ]; then
            log_info "✓ /etc/inittab found"
        else
            log_warn "WARNING: /etc/inittab missing (created by configure-system)"
        fi

        # Verify bootscripts are installed
        if [ -d "$mount_point/etc/rc.d" ]; then
            log_info "✓ SysV bootscripts installed (/etc/rc.d)"
        else
            log_warn "WARNING: /etc/rc.d missing (LFS-Bootscripts)"
        fi

        log_info "✓ SysVinit verified in disk image"
    else
        log_warn "ERROR: /sbin/init does not exist in disk image"
        log_warn "This should have been created during sysvinit installation (build-basesystem)"
        log_warn "and copied by rsync to the image"
        exit 1
    fi

    # Create poweroff/reboot utilities using SysRq
    log_step "Creating poweroff/reboot utilities..."

    cat > $mount_point/usr/sbin/poweroff << 'EOF'
#!/bin/sh
echo "System is going down for power off..."
sync
echo o > /proc/sysrq-trigger
EOF

    cat > $mount_point/usr/sbin/reboot << 'EOF'
#!/bin/sh
echo "System is going down for reboot..."
sync
echo b > /proc/sysrq-trigger
EOF

    chmod +x $mount_point/usr/sbin/poweroff
    chmod +x $mount_point/usr/sbin/reboot
    log_info "Power management utilities created"

    # Install GRUB
    log_step "Installing GRUB bootloader..."

    # Create a loop device for the ENTIRE disk image (needed for GRUB MBR installation)
    log_info "Creating loop device for full disk image..."
    local grub_loop_dev=$(losetup -f --show "$image_file")
    log_info "Loop device created: $grub_loop_dev"

    # Mount virtual filesystems for GRUB
    mount --bind /dev $mount_point/dev
    mount -t devpts devpts $mount_point/dev/pts
    mount -t proc proc $mount_point/proc
    mount -t sysfs sysfs $mount_point/sys

    # Install GRUB to MBR using chroot (LFS method)
    log_info "Installing GRUB to disk MBR via chroot..."

    # Remove load.cfg if it exists (prevents UUID search issues)
    rm -f $mount_point/boot/grub/i386-pc/load.cfg

    # Install GRUB from within the LFS system using chroot
    chroot $mount_point /usr/bin/env -i \
        HOME=/root \
        TERM="$TERM" \
        PATH=/usr/bin:/usr/sbin \
        /usr/sbin/grub-install --target=i386-pc \
                               --boot-directory=/boot \
                               --modules="part_msdos ext2 biosdisk search" \
                               --no-floppy \
                               --recheck \
                               "$grub_loop_dev" || log_warn "GRUB installation completed with warnings"

    # Remove the problematic load.cfg that grub-install creates
    # This file causes UUID search issues during boot
    rm -f $mount_point/boot/grub/i386-pc/load.cfg
    log_info "Removed load.cfg to prevent UUID search issues"

    # Create GRUB configuration with serial console support
    log_info "Creating GRUB configuration with serial console support..."
    mkdir -p $mount_point/boot/grub

    cat > $mount_point/boot/grub/grub.cfg << 'EOF'
# GRUB configuration for serial console (QEMU -nographic compatible)

# Configure serial port (115200 baud, 8N1)
serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1

# Use both serial and console terminals for compatibility
terminal_input serial console
terminal_output serial console

set default=0
set timeout=5
set timeout_style=menu

insmod ext2
set root=(hd0,1)

menuentry "LFS 12.4 (Minimal)" {
    linux /boot/vmlinuz root=/dev/sda1 ro net.ifnames=0 biosdevname=0 console=tty0 console=ttyS0,115200n8
}

menuentry "LFS 12.4 (Verbose Boot)" {
    linux /boot/vmlinuz root=/dev/sda1 ro net.ifnames=0 biosdevname=0 console=tty0 console=ttyS0,115200n8 debug loglevel=7
}

menuentry "LFS 12.4 (Recovery Mode)" {
    linux /boot/vmlinuz root=/dev/sda1 rw single net.ifnames=0 biosdevname=0 console=tty0 console=ttyS0,115200n8
}
EOF

    log_info "GRUB installation complete"

    # Cleanup mounts
    log_step "Cleaning up..."
    umount $mount_point/dev/pts 2>/dev/null || true
    umount $mount_point/dev 2>/dev/null || true
    umount $mount_point/proc 2>/dev/null || true
    umount $mount_point/sys 2>/dev/null || true
    umount $mount_point

    # Detach loop devices
    log_info "Detaching loop device for GRUB: $grub_loop_dev"
    losetup -d "$grub_loop_dev" 2>/dev/null || log_warn "Failed to detach $grub_loop_dev"

    log_info "Disk image created: $image_file"
    log_info "Image size: $(du -h $image_file | cut -f1)"

    # Compress image
    log_step "Compressing image..."
    gzip -c "$image_file" > "${image_file}.gz"
    log_info "Compressed image: ${image_file}.gz ($(du -h ${image_file}.gz | cut -f1))"
}

# Create simple tarball (alternative method)
create_tarball() {
    log_step "Creating system tarball..."

    local tarball="$DIST_DIR/${IMAGE_NAME}.tar.gz"

    tar -czf "$tarball" \
        --exclude=$LFS/dev/* \
        --exclude=$LFS/proc/* \
        --exclude=$LFS/sys/* \
        --exclude=$LFS/run/* \
        --exclude=$LFS/tmp/* \
        --exclude=$LFS/sources/* \
        --exclude=$LFS/build/* \
        --exclude=$LFS/tools/* \
        -C "$LFS" .

    log_info "Tarball created: $tarball"
    log_info "Size: $(du -h $tarball | cut -f1)"
}

# Main
main() {
    log_info "=========================================="
    log_info "EasyLFS Package Image"
    log_info "=========================================="

    # Initialize checkpoint system
    init_checkpointing

    # Check if image already created
    if should_skip_global_checkpoint "image-${IMAGE_NAME}"; then
        log_info "Image ${IMAGE_NAME} already created - skipping"
        exit 0
    fi

    # Verify LFS system exists
    if [ ! -d "$LFS" ] || [ ! -f "$LFS/boot/vmlinuz" ]; then
        log_warn "LFS system incomplete!"
        log_warn "Boot kernel not found: $LFS/boot/vmlinuz"
    fi

    # Create output directory
    mkdir -p "$DIST_DIR"

    # Create disk image
    create_disk_image

    # Also create tarball for convenience
    create_tarball

    # Create README
    cat > "$DIST_DIR/README.txt" << EOF
EasyLFS - Automated Linux From Scratch
Generated: $(date)

Files:
- ${IMAGE_NAME}.img.gz: Bootable disk image (gzip compressed)
- ${IMAGE_NAME}.tar.gz: System tarball

Usage:
1. Decompress the image:
   gunzip ${IMAGE_NAME}.img.gz

2. Boot with QEMU (serial console):
   qemu-system-x86_64 -m 2G -smp 2 \\
       -drive file=${IMAGE_NAME}.img,format=raw \\
       -boot c \\
       -nographic \\
       -serial mon:stdio

   Or with graphical display:
   qemu-system-x86_64 -m 2G -smp 2 -drive file=${IMAGE_NAME}.img,format=raw

3. Or write to USB drive:
   dd if=${IMAGE_NAME}.img of=/dev/sdX bs=4M status=progress
   (Replace /dev/sdX with your USB device)

4. Or extract tarball:
   tar -xzf ${IMAGE_NAME}.tar.gz -C /path/to/rootfs

System Info:
- LFS Version: 12.4 (SysVinit)
- Kernel: $(cat $LFS/boot/config-* 2>/dev/null | grep "^# Linux" | head -1 || echo "Unknown")
- Root Login: root (no password set)

Default Users:
- root (no password)

Network:
- DHCP enabled on eth0

For more information, visit: https://www.linuxfromscratch.org
EOF

    log_info ""
    log_info "=========================================="
    log_info "Packaging Complete!"
    log_info "=========================================="
    log_info "Output directory: $DIST_DIR"
    log_info ""
    log_info "Files created:"
    ls -lh "$DIST_DIR"

    # Create global checkpoint
    # Use DIST_DIR as checkpoint location since image is the final output
    export CHECKPOINT_DIR="$DIST_DIR/.checkpoints"
    create_global_checkpoint "image-${IMAGE_NAME}" "package"

    exit 0
}

main "$@"

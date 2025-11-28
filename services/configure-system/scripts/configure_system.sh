#!/bin/bash
set -euo pipefail

# =============================================================================
# EasyLFS Configure System Script
# Creates essential system configuration files (LFS Chapter 9)
# Duration: 10-20 minutes
# =============================================================================

export LFS="${LFS:-/lfs}"
export HOSTNAME="${HOSTNAME:-lfs-system}"
export TIMEZONE="${TIMEZONE:-Europe/Rome}"

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
    log_info "Configuring LFS System"
    log_info "=========================================="

    # Initialize checkpoint system
    init_checkpointing

    # Check if configuration already completed
    if should_skip_global_checkpoint "configure-system-complete"; then
        log_info "System configuration already completed - skipping"
        exit 0
    fi

    # Network configuration
    log_step "Configuring network..."

    cat > $LFS/etc/hostname << EOF
$HOSTNAME
EOF

    cat > $LFS/etc/hosts << "EOF"
127.0.0.1  localhost
127.0.1.1  lfs-system
::1        localhost ip6-localhost ip6-loopback
ff02::1    ip6-allnodes
ff02::2    ip6-allrouters
EOF

    # SysV network configuration
    log_step "Configuring network (SysV style)..."
    mkdir -p $LFS/etc/sysconfig

    # Configure network with static IP (dhcpcd not in base LFS)
    # Using QEMU's default network: 10.0.2.0/24, gateway 10.0.2.2
    cat > $LFS/etc/sysconfig/ifconfig.eth0 << "EOF"
ONBOOT=yes
IFACE=eth0
SERVICE=ipv4-static
IP=10.0.2.15
GATEWAY=10.0.2.2
PREFIX=24
BROADCAST=10.0.2.255
EOF

    # Create DNS configuration
    cat > $LFS/etc/resolv.conf << "EOF"
# QEMU default DNS
nameserver 10.0.2.3
nameserver 8.8.8.8
EOF

    log_info "✓ Network configuration created (Static IP 10.0.2.15/24)"

    # Fstab
    log_step "Creating /etc/fstab..."

    cat > $LFS/etc/fstab << "EOF"
# file system  mount-point  type     options             dump  fsck
#                                                               order
/dev/sda1      /            ext4     defaults            1     1
proc           /proc        proc     nosuid,noexec,nodev 0     0
sysfs          /sys         sysfs    nosuid,noexec,nodev 0     0
devpts         /dev/pts     devpts   gid=5,mode=620      0     0
tmpfs          /run         tmpfs    defaults            0     0
devtmpfs       /dev         devtmpfs mode=0755,nosuid    0     0
tmpfs          /dev/shm     tmpfs    nosuid,nodev        0     0
cgroup2        /sys/fs/cgroup cgroup2 nosuid,noexec,nodev 0  0
EOF

    # Console configuration
    log_step "Configuring console..."

    mkdir -p $LFS/etc/sysconfig

    cat > $LFS/etc/sysconfig/console << "EOF"
# Console configuration for LFS
KEYMAP="us"
FONT="lat1-16"
EOF

    # Shell configuration
    log_step "Configuring shell..."

    # Ensure root home directory exists
    mkdir -p $LFS/root

    cat > $LFS/etc/profile << "EOF"
# /etc/profile - System-wide environment and startup scripts

export PATH=/usr/bin:/usr/sbin:/bin:/sbin

if [ -f "$HOME/.bashrc" ] ; then
    source $HOME/.bashrc
fi

if [ -d /etc/profile.d ]; then
    for script in /etc/profile.d/*.sh; do
        if [ -r $script ]; then
            . $script
        fi
    done
    unset script
fi

export HISTSIZE=1000
export HISTFILESIZE=1000
export EDITOR=vi
EOF

    cat > $LFS/root/.bash_profile << "EOF"
# ~/.bash_profile - Personal environment variables

if [ -f "$HOME/.bashrc" ] ; then
    source $HOME/.bashrc
fi
EOF

    cat > $LFS/root/.bashrc << "EOF"
# ~/.bashrc - Personal aliases and functions

alias ls='ls --color=auto'
alias ll='ls -la'
alias grep='grep --color=auto'

PS1='\u@\h:\w\$ '
EOF

    cat > $LFS/etc/inputrc << "EOF"
# /etc/inputrc - Readline configuration

set horizontal-scroll-mode Off
set meta-flag On
set input-meta On
set convert-meta Off
set output-meta On
set bell-style none

"\eOd": backward-word
"\eOc": forward-word
"\e[1~": beginning-of-line
"\e[4~": end-of-line
"\e[5~": beginning-of-history
"\e[6~": end-of-history
"\e[3~": delete-char
"\e[2~": quoted-insert
"\eOH": beginning-of-line
"\eOF": end-of-line
"\e[H": beginning-of-line
"\e[F": end-of-line
EOF

    # Shells
    log_step "Configuring valid shells..."

    cat > $LFS/etc/shells << "EOF"
/bin/sh
/bin/bash
/usr/bin/sh
/usr/bin/bash
EOF

    # SysV Init configuration
    log_step "Configuring /etc/inittab..."

    cat > $LFS/etc/inittab << "EOF"
# Begin /etc/inittab

id:3:initdefault:

si::sysinit:/etc/rc.d/init.d/rc S

l0:0:wait:/etc/rc.d/init.d/rc 0
l1:S1:wait:/etc/rc.d/init.d/rc 1
l2:2:wait:/etc/rc.d/init.d/rc 2
l3:3:wait:/etc/rc.d/init.d/rc 3
l4:4:wait:/etc/rc.d/init.d/rc 4
l5:5:wait:/etc/rc.d/init.d/rc 5
l6:6:wait:/etc/rc.d/init.d/rc 6

ca:12345:ctrlaltdel:/sbin/shutdown -t1 -a -r now

su:S06:once:/sbin/sulogin
s1:1:respawn:/sbin/sulogin

1:2345:respawn:/sbin/agetty --noclear tty1 9600
2:2345:respawn:/sbin/agetty tty2 9600
3:2345:respawn:/sbin/agetty tty3 9600
4:2345:respawn:/sbin/agetty tty4 9600
5:2345:respawn:/sbin/agetty tty5 9600
6:2345:respawn:/sbin/agetty tty6 9600

# Serial console (for QEMU -nographic mode)
s0:2345:respawn:/sbin/agetty -L 115200 ttyS0 vt100

# End /etc/inittab
EOF

    log_info "✓ Inittab configured (runlevel 3 - multi-user)"

    # System clock configuration
    log_step "Configuring system clock..."

    cat > $LFS/etc/sysconfig/clock << "EOF"
# Begin /etc/sysconfig/clock

UTC=1

# Set to recognized timezone (already configured via symlink)
TIMEZONE=$TIMEZONE

# End /etc/sysconfig/clock
EOF

    log_info "✓ System clock configured (UTC)"

    # Locale configuration
    log_step "Configuring locale..."

    cat > $LFS/etc/locale.conf << "EOF"
LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8
EOF

    # Timezone
    log_step "Setting timezone to $TIMEZONE..."
    ln -sf /usr/share/zoneinfo/$TIMEZONE $LFS/etc/localtime

    # Root password configuration
    log_step "Setting root password..."

    # Enable SHA-512 password hashing in login.defs
    if [ -f "$LFS/etc/login.defs" ]; then
        sed -i 's/^#ENCRYPT_METHOD.*/ENCRYPT_METHOD SHA512/' $LFS/etc/login.defs
        log_info "✓ Enabled SHA-512 password encryption"
    fi

    # Default password: "lfs" (SHA-512 hash with salt "lfs12.4")
    # Users should change this after first login with: passwd root
    ROOT_PASSWORD_HASH='$6$lfs12.4$ZMkKaNupdspxqvTCf/tUTE6jDrI/Uctm4Srhck7svUxIlHt/364RrIner1zclJnsC0ECppp61rijU630uq7rT0'

    if [ -f "$LFS/etc/shadow" ]; then
        # Replace root's password hash in existing shadow file
        sed -i "s|^root:[^:]*:|root:$ROOT_PASSWORD_HASH:|" $LFS/etc/shadow
        log_info "✓ Root password set (default: 'lfs')"
    else
        log_info "⚠ Warning: /etc/shadow not found - password not set"
        log_info "  Run: echo 'root:lfs' | chpasswd inside the LFS system"
    fi

    log_info ""
    log_info "=========================================="
    log_info "System Configuration Complete!"
    log_info "=========================================="
    log_info "Hostname: $HOSTNAME"
    log_info "Timezone: $TIMEZONE"
    log_info "Init system: SysVinit"
    log_info "Default runlevel: 3 (multi-user)"
    log_info "Network: /etc/sysconfig/ifconfig.eth0 (Static IP)"
    log_info "Root password: lfs (CHANGE AFTER FIRST LOGIN!)"

    # Create global checkpoint
    create_global_checkpoint "configure-system-complete" "configure"

    exit 0
}

main "$@"

#!/bin/bash
set -euo pipefail

# =============================================================================
# EasyLFS Chroot Build Script
# Builds LFS system packages inside chroot environment (LFS Chapters 7-8)
# This script is executed inside the chroot, NOT on the host
# =============================================================================

# Chroot environment setup
export HOME=/root
export TERM="${TERM:-linux}"
export PS1='(lfs chroot) \u:\w\$ '
export PATH=/usr/bin:/usr/sbin:/bin:/sbin:/tools/bin
export MAKEFLAGS="-j$(nproc)"
export LC_ALL=POSIX
export BUILD_STAGE="${BUILD_STAGE:-all}"  # all, glibc, or remaining
export LFS="/"  # Inside chroot, LFS root is /
export SERVICE_NAME="${SERVICE_NAME:-build-basesystem}"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Load common utilities from chroot
CHROOT_COMMON_DIR="/tmp/easylfs-common"

# Load checkpointing module if available
if [ -f "$CHROOT_COMMON_DIR/checkpointing.sh" ]; then
    source "$CHROOT_COMMON_DIR/checkpointing.sh"
    init_checkpointing
    log_info "✓ Checkpoint system enabled"
else
    log_warn "⚠ Checkpointing module not found at $CHROOT_COMMON_DIR - builds will not be cached"
    # Define stub functions if checkpointing unavailable
    should_skip_package() { return 1; }
    create_checkpoint() { :; }
fi

# Build directory
mkdir -p /build
cd /build

# Helper function to build packages
build_package() {
    local pattern="$1"
    local name="$2"
    shift 2

    # Extract base package name for checkpoint (e.g., "gettext" from "gettext-*.tar.xz")
    local base_name=$(echo "$pattern" | sed 's/-\*.*$//')

    # Check checkpoint
    should_skip_package "$base_name" "/sources" && return 0

    log_step "Building $name..."

    local tarball=$(ls /sources/$pattern 2>/dev/null | head -1)
    if [ -z "$tarball" ]; then
        echo "ERROR: Package not found: $pattern"
        return 1
    fi

    # Extract to /build
    cd /build
    tar -xf "$tarball"
    local dir=$(tar -tf "$tarball" | head -1 | cut -d'/' -f1)
    cd "$dir"

    # Execute build commands
    "$@"

    cd /build
    rm -rf "$dir"

    log_info "$name complete"

    # Create checkpoint
    create_checkpoint "$base_name" "/sources" "chapter8"
}

# =============================================================================
# CHAPTER 7: Entering Chroot and Building Essential Tools
# =============================================================================

# Skip Chapter 7 if final GCC already exists (resume mode)
if [ ! -f /usr/bin/gcc ]; then
    log_step "===== CHAPTER 7: Building Essential Tools ====="
else
    log_info "===== CHAPTER 7: SKIPPED (Final GCC found - resuming from Chapter 8) ====="
fi

# Only execute Chapter 7 if GCC final doesn't exist
if [ ! -f /usr/bin/gcc ]; then

# Create essential directories
mkdir -pv /{boot,home,mnt,opt,srv}
mkdir -pv /etc/{opt,sysconfig}
mkdir -pv /lib/firmware
mkdir -pv /media/{floppy,cdrom}
mkdir -pv /usr/{,local/}{include,src}
mkdir -pv /usr/local/{bin,lib,sbin}
mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
mkdir -pv /usr/{,local/}share/{misc,terminfo,zoneinfo}
mkdir -pv /usr/{,local/}share/man/man{1..8}
mkdir -pv /var/{cache,local,log,mail,opt,spool}
mkdir -pv /var/lib/{color,misc,locate}

ln -sfv /run /var/run
ln -sfv /run/lock /var/lock

install -dv -m 0750 /root
install -dv -m 1777 /tmp /var/tmp

# Essential files
ln -sfv /proc/self/mounts /etc/mtab

cat > /etc/hosts << "EOF"
127.0.0.1  localhost
::1        localhost
EOF

cat > /etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/usr/bin/false
daemon:x:6:6:Daemon User:/dev/null:/usr/bin/false
uuidd:x:80:80:UUID Generator Daemon User:/dev/null:/usr/bin/false
tester:x:101:101::/home/tester:/bin/bash
nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
EOF

cat > /etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
cdrom:x:15:
adm:x:16:
input:x:24:
mail:x:34:
kvm:x:61:
uuidd:x:80:
tester:x:101:
wheel:x:97:
users:x:999:
nogroup:x:65534:
EOF

# Create tester home directory
mkdir -pv /home/tester
chown -v tester:tester /home/tester

touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664  /var/log/lastlog
chmod -v 600  /var/log/btmp

# Gettext (temporary) - skip if tools already available from previous build
if ! command -v msgfmt >/dev/null 2>&1; then
    log_step "Building minimal Gettext tools..."
    # For bootstrap we only need msgfmt, msgmerge, xgettext
    # Use pre-built binaries from host if available, or skip
    log_warn "Gettext tools not found but required. Build may need existing gettext."
    log_warn "Skipping Gettext temporary build - will use final Gettext in Chapter 8"
else
    log_info "Gettext tools already available, skipping temporary build"
fi

# Bison (temporary)
build_package "bison-*.tar.xz" "Bison (temporary)" bash -c '
    ./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2
    make
    make install
'

# Perl (temporary) - skip test suite for bootstrap phase
build_package "perl-*.tar.xz" "Perl (temporary)" bash -c '
    sh Configure -des \
        -D prefix=/usr \
        -D vendorprefix=/usr \
        -D useshrplib \
        -D privlib=/usr/lib/perl5/5.42/core_perl \
        -D archlib=/usr/lib/perl5/5.42/core_perl \
        -D sitelib=/usr/lib/perl5/5.42/site_perl \
        -D sitearch=/usr/lib/perl5/5.42/site_perl \
        -D vendorlib=/usr/lib/perl5/5.42/vendor_perl \
        -D vendorarch=/usr/lib/perl5/5.42/vendor_perl
    make
    # Force install even if tests would fail (this is temporary toolchain)
    make install || make -i install
'

# Python (temporary)
build_package "Python-*.tar.xz" "Python (temporary)" bash -c '
    ./configure --prefix=/usr \
                --enable-shared \
                --without-ensurepip
    make
    make install
'

# Texinfo (temporary)
build_package "texinfo-*.tar.xz" "Texinfo (temporary)" bash -c '
    ./configure --prefix=/usr
    make
    make install
'

# Util-linux (temporary)
build_package "util-linux-*.tar.xz" "Util-linux (temporary)" bash -c '
    mkdir -pv /var/lib/hwclock
    ./configure --libdir=/usr/lib \
                --runstatedir=/run \
                --disable-chfn-chsh \
                --disable-login \
                --disable-nologin \
                --disable-su \
                --disable-setpriv \
                --disable-runuser \
                --disable-pylibmount \
                --disable-static \
                --disable-liblastlog2 \
                --without-python \
                ADJTIME_PATH=/var/lib/hwclock/adjtime \
                --docdir=/usr/share/doc/util-linux-2.41.1
    make
    make install
'

fi  # End of Chapter 7 conditional block

# =============================================================================
# Ensure essential system files exist (must run even when Chapter 7 is skipped)
# =============================================================================
if ! grep -q "^root:" /etc/passwd 2>/dev/null; then
    log_info "Creating /etc/passwd (Chapter 7 was skipped)..."
    cat > /etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/usr/bin/false
daemon:x:6:6:Daemon User:/dev/null:/usr/bin/false
uuidd:x:80:80:UUID Generator Daemon User:/dev/null:/usr/bin/false
tester:x:101:101::/home/tester:/bin/bash
nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
EOF
fi

if ! grep -q "^root:" /etc/group 2>/dev/null; then
    log_info "Creating /etc/group (Chapter 7 was skipped)..."
    cat > /etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
cdrom:x:15:
adm:x:16:
input:x:24:
mail:x:34:
kvm:x:61:
uuidd:x:80:
tester:x:101:
wheel:x:97:
users:x:999:
nogroup:x:65534:
EOF
fi

# Ensure tester home directory exists
if [ ! -d /home/tester ]; then
    mkdir -pv /home/tester
    chown -v tester:tester /home/tester
fi

# =============================================================================
# CHAPTER 8: Installing Basic System Software (COMPLETE)
# =============================================================================

log_step "===== CHAPTER 8: Installing Basic System Software ====="
log_info "Build stage: $BUILD_STAGE"

# Cleanup /tools now that we're building final system
rm -rf /tools

# Skip to remaining packages if BUILD_STAGE=remaining
if [ "$BUILD_STAGE" = "remaining" ]; then
    log_info "Skipping to remaining packages (after Glibc)..."
    # Jump to Zlib section - we'll use a marker
    goto_remaining_packages=true
else
    goto_remaining_packages=false
fi

if [ "$goto_remaining_packages" = "false" ]; then
    # =====================================================================
    # 8.3 Man-pages-6.15
    # =====================================================================
build_package "man-pages-*.tar.xz" "Man-pages" bash -c '
    rm -v man3/crypt*
    make -R GIT=false prefix=/usr install
'

# =====================================================================
# 8.4 Iana-Etc-20250807
# =====================================================================
build_package "iana-etc-*.tar.gz" "Iana-Etc" bash -c '
    command cp -fv services protocols /etc
'

# =====================================================================
# 8.4.1 Bison-3.8.2 (Prerequisite for Glibc)
# NOTE: Minimal build for Glibc configure. Full build happens at 8.34
# =====================================================================
if ! command -v bison &>/dev/null; then
    build_package "bison-*.tar.xz" "Bison (minimal for Glibc)" bash -c '
        ./configure --prefix=/usr
        make
        make install
    '
fi

# =====================================================================
# 8.4.2 Python-3.13.7 (Prerequisite for Glibc)
# NOTE: Minimal build for Glibc configure. Full build happens at 8.52
# =====================================================================
if ! command -v python3 &>/dev/null; then
    build_package "Python-*.tar.xz" "Python (minimal for Glibc)" bash -c '
        ./configure --prefix=/usr --without-ensurepip
        make
        make install
    '
fi

# =====================================================================
# 8.5 Glibc-2.42 (Final)
# =====================================================================
build_package "glibc-*.tar.xz" "Glibc (final)" bash -c '
    patch -Np1 -i /sources/glibc-*-fhs-1.patch || true

    # Workaround for Glibc 2.42: Create stub timezone utilities
    # tzselect.ksh is needed but missing - we install tzdata separately
    cd timezone
    touch tzselect.ksh zdump.c zic.c
    chmod +x tzselect.ksh
    cd ..

    mkdir -v build
    cd build
    echo "rootsbindir=/usr/sbin" > configparms
    ../configure --prefix=/usr \
                 --disable-werror \
                 --enable-kernel=4.19 \
                 --enable-stack-protector=strong \
                 --disable-nscd \
                 libc_cv_slibdir=/usr/lib

    # Create timezone stamp files to skip timezone compilation
    mkdir -p timezone
    touch timezone/stamp.o timezone/stamp.os timezone/stamp.oS

    # Also create the expected timezone utility files to satisfy dependencies
    touch timezone/tzselect timezone/zdump timezone/zic

    make

    # Replace timezone Makefile with stub to prevent tzselect.ksh errors
    # We install timezone data separately using zic
    cat > timezone/Makefile << "TZSTUB"
.PHONY: all install subdir_lib others clean mostlyclean distclean
all install subdir_lib others clean mostlyclean distclean:
	@echo "Timezone utilities disabled - will be installed separately"
TZSTUB

    # Skip locale installation to avoid msgfmt dependency
    touch ../SUPPORTED  # Prevent install from trying to install locales
    make install LOCALES=""
    sed "/RTLDLIST=/s@/usr@@g" -i /usr/bin/ldd
    mkdir -pv /usr/lib/locale
    localedef -i C -f UTF-8 C.UTF-8
    localedef -i en_US -f UTF-8 en_US.UTF-8
'

# Configure Glibc
cat > /etc/nsswitch.conf << "EOF"
passwd: files
group: files
shadow: files
hosts: files dns
networks: files
protocols: files
services: files
ethers: files
rpc: files
EOF

# Timezone data
log_step "Configuring timezone data..."
cd /build
rm -rf tzdata-work
mkdir -p tzdata-work
cd tzdata-work
tar -xf /sources/tzdata*.tar.gz && rm -f Makefile *.ksh *.awk

ZONEINFO=/usr/share/zoneinfo
mkdir -pv $ZONEINFO/{posix,right}
for tz in etcetera southamerica northamerica europe africa antarctica asia australasia backward; do
    zic -L /dev/null   -d $ZONEINFO       ${tz}
    zic -L /dev/null   -d $ZONEINFO/posix ${tz}
    zic -L leapseconds -d $ZONEINFO/right ${tz}
done
command cp -fv zone.tab zone1970.tab iso3166.tab $ZONEINFO
zic -d $ZONEINFO -p America/New_York
ln -sfv /usr/share/zoneinfo/Europe/Rome /etc/localtime
cd /build
rm -rf tzdata-work

# End of Glibc build section
fi  # End of if [ "$goto_remaining_packages" = "false" ]

# Exit if BUILD_STAGE=glibc (Glibc-only build)
if [ "$BUILD_STAGE" = "glibc" ]; then
    log_info "===== GLIBC BUILD COMPLETE (BUILD_STAGE=glibc) ====="
    log_info "Glibc, timezone data, and prerequisites installed successfully"
    exit 0
fi

# Continue with remaining packages if BUILD_STAGE=remaining or BUILD_STAGE=all
if [ "$BUILD_STAGE" = "remaining" ] || [ "$BUILD_STAGE" = "all" ]; then
    log_info "===== BUILDING REMAINING PACKAGES ====="

# =====================================================================
# 8.6 Zlib-1.3.1
# =====================================================================
build_package "zlib-*.tar.gz" "Zlib" bash -c '
    ./configure --prefix=/usr
    make
    make install
    rm -fv /usr/lib/libz.a
'

# =====================================================================
# 8.7 Bzip2-1.0.8
# =====================================================================
build_package "bzip2-*.tar.gz" "Bzip2" bash -c '
    patch -Np1 -i /sources/bzip2-1.0.8-install_docs-1.patch
    sed -i "s@\\(ln -s -f \\)\$(PREFIX)/bin/@\\1@" Makefile
    sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
    make -f Makefile-libbz2_so
    make clean
    make
    make PREFIX=/usr install
    cp -av libbz2.so.* /usr/lib
    ln -sv libbz2.so.1.0.8 /usr/lib/libbz2.so
    cp -v bzip2-shared /usr/bin/bzip2
    for i in /usr/bin/{bzcat,bunzip2}; do
        ln -sfv bzip2 $i
    done
    rm -fv /usr/lib/libbz2.a
'

# =====================================================================
# 8.8 Xz-5.8.1
# =====================================================================
build_package "xz-*.tar.xz" "Xz" bash -c '
    ./configure --prefix=/usr \
                --disable-static \
                --docdir=/usr/share/doc/xz-5.8.1
    make
    make install
'

# =====================================================================
# 8.9 Lz4-1.10.0
# =====================================================================
build_package "lz4-*.tar.gz" "Lz4" bash -c '
    make BUILD_STATIC=no PREFIX=/usr
    make BUILD_STATIC=no PREFIX=/usr install
'

# =====================================================================
# 8.10 Zstd-1.5.7
# =====================================================================
build_package "zstd-*.tar.gz" "Zstd" bash -c '
    make prefix=/usr
    make prefix=/usr install
    rm -v /usr/lib/libzstd.a
'

# =====================================================================
# 8.11 File-5.46
# =====================================================================
build_package "file-*.tar.gz" "File" bash -c '
    ./configure --prefix=/usr
    make
    make install
'

# =====================================================================
# 8.13 Libxcrypt-4.4.37
# =====================================================================
# Ensure Perl is available (required by libxcrypt configure)
if ! command -v perl &>/dev/null; then
    log_warn "Perl not found, building from Chapter 7..."
    build_package "perl-*.tar.xz" "Perl (for libxcrypt)" bash -c '
        sh Configure -des \
            -D prefix=/usr \
            -D vendorprefix=/usr \
            -D useshrplib \
            -D privlib=/usr/lib/perl5/5.42/core_perl \
            -D archlib=/usr/lib/perl5/5.42/core_perl \
            -D sitelib=/usr/lib/perl5/5.42/site_perl \
            -D sitearch=/usr/lib/perl5/5.42/site_perl \
            -D vendorlib=/usr/lib/perl5/5.42/vendor_perl \
            -D vendorarch=/usr/lib/perl5/5.42/vendor_perl
        make
        make install || make -i install
    '
fi

build_package "libxcrypt-*.tar.xz" "Libxcrypt" bash -c '
    ./configure --prefix=/usr \
                --enable-hashes=strong,glibc \
                --enable-obsolete-api=no \
                --disable-static \
                --disable-failure-tokens
    make
    make install
'

# =====================================================================
# 8.27 Shadow-4.18.0
# =====================================================================
build_package "shadow-*.tar.xz" "Shadow" bash -c '
    touch /usr/bin/passwd

    ./configure --sysconfdir=/etc \
                --disable-static \
                --with-{b,yes}crypt \
                --without-libbsd \
                --with-group-name-max-length=32

    make
    make exec_prefix=/usr install
    make -C man install-man

    # Enable shadowed passwords
    pwconv
    grpconv
'

# =====================================================================
# 8.17 Pkgconf-2.5.1 (Required by Kbd and many other packages)
# =====================================================================
build_package "pkgconf-*.tar.xz" "Pkgconf" bash -c '
    ./configure --prefix=/usr \
                --disable-static \
                --docdir=/usr/share/doc/pkgconf-2.5.1
    make
    make install
    ln -sv pkgconf /usr/bin/pkg-config
    ln -sv pkgconf.1 /usr/share/man/man1/pkg-config.1
'

# =====================================================================
# 8.13 Flex-2.6.4 (Required by Kbd)
# =====================================================================
build_package "flex-*.tar.gz" "Flex" bash -c '
    ./configure --prefix=/usr \
                --docdir=/usr/share/doc/flex-2.6.4 \
                --disable-static
    make
    make install
    ln -sv flex /usr/bin/lex
    ln -sv flex.1 /usr/share/man/man1/lex.1
'

# =====================================================================
# 8.30 Ncurses-6.5-20250809
# =====================================================================
build_package "ncurses-*.t*z" "Ncurses" bash -c '
    ./configure --prefix=/usr \
                --mandir=/usr/share/man \
                --with-shared \
                --without-debug \
                --without-normal \
                --with-cxx-shared \
                --enable-pc-files \
                --with-pkg-config-libdir=/usr/lib/pkgconfig
    make
    make DESTDIR=$PWD/dest install
    install -vm755 dest/usr/lib/libncursesw.so.6.5 /usr/lib
    rm -v dest/usr/lib/libncursesw.so.6.5
    sed -e "s/^#if.*XOPEN.*\$/#if 1/" -i dest/usr/include/curses.h
    cp -av dest/* /
    for lib in ncurses form panel menu ; do
        ln -sfv lib${lib}w.so /usr/lib/lib${lib}.so
        ln -sfv ${lib}w.pc /usr/lib/pkgconfig/${lib}.pc
    done
    ln -sfv libncursesw.so /usr/lib/libcurses.so
'

# =====================================================================
# 8.31 Sed-4.9
# =====================================================================
build_package "sed-*.tar.xz" "Sed" bash -c '
    ./configure --prefix=/usr
    make
    chown -R tester .
    su tester -c "PATH=$PATH make check" || true
    make install
    # HTML documentation requires makeinfo (from Texinfo, built later)
    make html 2>/dev/null || true
    if [ -f doc/sed.html ]; then
        install -d -m755 /usr/share/doc/sed-4.9
        install -m644 doc/sed.html /usr/share/doc/sed-4.9
    fi
'


# =====================================================================
# 8.35 Grep-3.12
# =====================================================================
build_package "grep-*.tar.xz" "Grep" bash -c '
    sed -i "s/echo/#echo/" src/egrep.sh
    ./configure --prefix=/usr
    make
    make install
'

fi  # End of if [ "$BUILD_STAGE" = "remaining" ] || [ "$BUILD_STAGE" = "all" ]

# Continue with remaining packages
log_info "Continuing with remaining packages..."

# Re-check BUILD_STAGE for remaining packages
if [ "$BUILD_STAGE" = "remaining" ] || [ "$BUILD_STAGE" = "all" ]; then

# =====================================================================
# 8.49 Kmod-34.2
# =====================================================================
build_package "kmod-*.tar.xz" "Kmod" bash -c '
    ./configure --prefix=/usr \
                --sysconfdir=/etc \
                --with-xz \
                --with-zstd \
                --with-zlib \
                --disable-manpages
    make
    make install
    for target in depmod insmod modinfo modprobe rmmod; do
        ln -sfv ../bin/kmod /usr/sbin/$target
        rm -fv /usr/bin/$target
    done
'

# =====================================================================
# 8.66 IPRoute2-6.13.0
# =====================================================================
build_package "iproute2-*.tar.xz" "IPRoute2" bash -c '
    sed -i /ARPD/d Makefile
    rm -fv man/man8/arpd.8
    make NETNS_RUN_DIR=/run/netns
    make SBINDIR=/usr/sbin install
    mkdir -pv /usr/share/doc/iproute2-6.13.0
    cp -v COPYING README* /usr/share/doc/iproute2-6.13.0
'

# =====================================================================
# 8.59 Coreutils-9.7
# =====================================================================
build_package "coreutils-*.tar.xz" "Coreutils" bash -c '
    # Apply patches with forward flag to skip if already applied
    patch -N -p1 -i /sources/coreutils-9.7-upstream_fix-1.patch || echo "Patch already applied, skipping"
    patch -N -p1 -i /sources/coreutils-9.7-i18n-1.patch || echo "Patch already applied, skipping"
    autoreconf -fv
    automake -af
    FORCE_UNSAFE_CONFIGURE=1 ./configure \
        --prefix=/usr \
        --enable-no-install-program=kill,uptime
    make
    chown -R tester .
    su tester -c "PATH=$PATH make -k RUN_EXPENSIVE_TESTS=yes check" || true
    make install
    mv -v /usr/bin/chroot /usr/sbin
    mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
    sed -i "s/\"1\"/\"8\"/" /usr/share/man/man8/chroot.8
'

# =====================================================================
# 8.60 Diffutils-3.12
# =====================================================================
should_skip_package "diffutils" "/sources" && { log_info "⊙ Skipping diffutils (already built, checkpoint valid)"; } || {
log_step "Building Diffutils-3.12..."
tar -xf /sources/diffutils-*.tar.xz
cd diffutils-*
./configure --prefix=/usr
make
make install
cd /build
rm -rf diffutils-*
log_info "Diffutils complete"
create_checkpoint "diffutils" "/sources" "chapter8"
}

# =====================================================================
# 8.61 Gawk-5.3.2 - SKIPPED (non essenziale per boot, tests hung in container)
# =====================================================================
log_info "Gawk skipped (non-essential for minimal bootable system)"

# =====================================================================
# 8.62 Findutils-4.10.0
# =====================================================================
should_skip_package "findutils" "/sources" && { log_info "⊙ Skipping findutils (already built, checkpoint valid)"; } || {
log_step "Building Findutils-4.10.0..."
tar -xf /sources/findutils-*.tar.xz
cd findutils-*
./configure --prefix=/usr --localstatedir=/var/lib/locate
make
chown -R tester .
su tester -c "PATH=$PATH make check" || true
make install
cd /build
rm -rf findutils-*
log_info "Findutils complete"
create_checkpoint "findutils" "/sources" "chapter8"
}


# =====================================================================
# 8.65 Gzip-1.14
# =====================================================================
should_skip_package "gzip" "/sources" && { log_info "⊙ Skipping gzip (already built, checkpoint valid)"; } || {
log_step "Building Gzip-1.14..."
tar -xf /sources/gzip-*.tar.xz
cd gzip-*
./configure --prefix=/usr
make
make install
cd /build
rm -rf gzip-*
log_info "Gzip complete"
create_checkpoint "gzip" "/sources" "chapter8"
}


# =====================================================================
# 8.67 Kbd-2.8.0
# =====================================================================
should_skip_package "kbd" "/sources" && { log_info "⊙ Skipping kbd (already built, checkpoint valid)"; } || {
log_step "Building Kbd-2.8.0..."
tar -xf /sources/kbd-*.tar.xz
cd kbd-*
sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
./configure --prefix=/usr --disable-vlock

# Prevent autotools from trying to regenerate test files (autom4te not available)
# Tests will fail in chroot anyway (require valgrind), so skip them entirely
# Create a dummy testsuite file and touch all test dependencies to prevent regeneration
touch tests/testsuite tests/package.m4 tests/atconfig tests/atlocal 2>/dev/null || true
find tests -type f -name "*.at" -exec touch {} \; 2>/dev/null || true

# Build only the main programs, skip tests subdirectory
make -C src
make -C data
make -C po
make -C docs
make install
cd /build
rm -rf kbd-*
log_info "Kbd complete"
create_checkpoint "kbd" "/sources" "chapter8"
}


# =====================================================================
# 8.71 Tar-1.35
# =====================================================================
should_skip_package "tar" "/sources" && { log_info "⊙ Skipping tar (already built, checkpoint valid)"; } || {
log_step "Building Tar-1.35..."
tar -xf /sources/tar-*.tar.xz
cd tar-*
FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr --without-ncurses
make
make install
# HTML documentation requires makeinfo (from Texinfo, built next)
make -C doc install-html docdir=/usr/share/doc/tar-1.35 2>/dev/null || true
cd /build
rm -rf tar-*
log_info "Tar complete"
create_checkpoint "tar" "/sources" "chapter8"
}


# =====================================================================
# 8.73 Vim-9.1.1629 - SKIPPED (non essenziale, test suite lenta, utente preferisce nano)
# =====================================================================
log_info "Vim skipped (non-essential, user prefers nano)"


# =====================================================================
# 8.79 Procps-ng-4.0.5
# =====================================================================
should_skip_package "procps-ng" "/sources" && { log_info "⊙ Skipping procps-ng (already built, checkpoint valid)"; } || {
log_step "Building Procps-ng-4.0.5..."
tar -xf /sources/procps-ng-*.tar.xz
cd procps-ng-*
./configure --prefix=/usr \
            --docdir=/usr/share/doc/procps-ng-4.0.5 \
            --disable-static \
            --disable-kill \
            --without-ncurses
make
chown -R tester .
su tester -c "PATH=$PATH make check" || true
make install
cd /build
rm -rf procps-ng-*
log_info "Procps-ng complete"
create_checkpoint "procps-ng" "/sources" "chapter8"
}

# =====================================================================
# 8.80 Sysvinit-3.12
# =====================================================================
should_skip_package "sysvinit" "/sources" && { log_info "⊙ Skipping sysvinit (already built, checkpoint valid)"; } || {
log_step "Building Sysvinit-3.12..."
tar -xf /sources/sysvinit-*.tar.xz
cd sysvinit-*
patch -Np1 -i /sources/sysvinit-*-consolidated-*.patch
make
make install
cd /build
rm -rf sysvinit-*
log_info "Sysvinit complete"
create_checkpoint "sysvinit" "/sources" "chapter8"
}

# =====================================================================
# 8.81 Util-linux-2.41.1 (Final)
# =====================================================================
should_skip_package "util-linux" "/sources" && { log_info "⊙ Skipping util-linux (already built, checkpoint valid)"; } || {
log_step "Building Util-linux-2.41.1 (final)..."
tar -xf /sources/util-linux-*.tar.xz
cd util-linux-*
mkdir -pv /var/lib/hwclock
./configure --libdir=/usr/lib \
            --runstatedir=/run \
            --disable-chfn-chsh \
            --disable-login \
            --disable-nologin \
            --disable-su \
            --disable-setpriv \
            --disable-runuser \
            --disable-pylibmount \
            --disable-liblastlog2 \
            --disable-static \
            --without-python \
            ADJTIME_PATH=/var/lib/hwclock/adjtime \
            --docdir=/usr/share/doc/util-linux-2.41.1
make
chown -R tester .
su tester -c "PATH=$PATH make -k check" || true
make install
cd /build
rm -rf util-linux-*
log_info "Util-linux complete"
create_checkpoint "util-linux" "/sources" "chapter8"
}

# =====================================================================
# 8.81 E2fsprogs-1.47.3
# =====================================================================
should_skip_package "e2fsprogs" "/sources" && { log_info "⊙ Skipping e2fsprogs (already built, checkpoint valid)"; } || {
log_step "Building E2fsprogs-1.47.3..."
tar -xf /sources/e2fsprogs-*.tar.gz
cd e2fsprogs-*
rm -rf build
mkdir -v build
cd build
../configure --prefix=/usr \
             --sysconfdir=/etc \
             --enable-elf-shlibs \
             --disable-libblkid \
             --disable-libuuid \
             --disable-uuidd \
             --disable-fsck
make
make install
rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
# Only install info if it exists (may not be built in minimal configuration)
if [ -f /usr/share/info/libext2fs.info.gz ]; then
    gunzip -v /usr/share/info/libext2fs.info.gz
    install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info
fi
cd /build
rm -rf e2fsprogs-*
log_info "E2fsprogs complete"
create_checkpoint "e2fsprogs" "/sources" "chapter8"
}

# =====================================================================
# 8.15 Expat-2.7.1 (Required by Python)
# =====================================================================
build_package "expat-*.tar.xz" "Expat" bash -c '
    ./configure --prefix=/usr \
                --disable-static \
                --docdir=/usr/share/doc/expat-2.7.1
    make
    make install
    install -v -m644 doc/*.{html,css} /usr/share/doc/expat-2.7.1 2>/dev/null || true
'

# =====================================================================
# 8.49 Python-3.13.7 (Final - with pip)
# =====================================================================
# Use custom checkpoint name to avoid conflict with temporary Python
should_skip_package "Python-final" "/sources" && { log_info "⊙ Skipping Python-final (already built, checkpoint valid)"; } || {
log_step "Building Python-3.13.7 (final with pip)..."
tar -xf /sources/Python-*.tar.xz
cd Python-*
./configure --prefix=/usr \
            --enable-shared \
            --with-system-expat
make
make install
cd /build
rm -rf Python-*
log_info "Python (final) complete"
create_checkpoint "Python-final" "/sources" "chapter8"
}

# =====================================================================
# 8.54 Ninja-1.13.1 (Required by Meson)
# =====================================================================
build_package "ninja-*.tar.gz" "Ninja" bash -c '
    python3 configure.py --bootstrap --verbose
    install -vm755 ninja /usr/bin/
    install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
    install -vDm644 misc/zsh-completion /usr/share/zsh/site-functions/_ninja
'

# =====================================================================
# 8.50 Flit-Core-3.12.0 (Required by Meson)
# =====================================================================
build_package "flit_core-*.tar.gz" "Flit-Core" bash -c '
    pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
    pip3 install --no-index --find-links dist flit_core
'

# =====================================================================
# 8.51 Packaging-25.0 (Required by Wheel)
# =====================================================================
build_package "packaging-*.tar.gz" "Packaging" bash -c '
    pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
    pip3 install --no-index --find-links dist packaging
'

# =====================================================================
# 8.52 Wheel-0.46.1 (Required by Meson)
# =====================================================================
build_package "wheel-*.tar.gz" "Wheel" bash -c '
    pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
    pip3 install --no-index --find-links dist wheel
'

# =====================================================================
# 8.53 Setuptools-80.9.0 (Required by Meson)
# =====================================================================
build_package "setuptools-*.tar.gz" "Setuptools" bash -c '
    pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
    pip3 install --no-index --find-links dist setuptools
'

# =====================================================================
# 8.55 Meson-1.8.3 (Required by Udev)
# =====================================================================
build_package "meson-*.tar.gz" "Meson" bash -c '
    pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
    pip3 install --no-index --find-links dist meson
    install -vDm644 data/shell-completions/bash/meson /usr/share/bash-completion/completions/meson
    install -vDm644 data/shell-completions/zsh/_meson /usr/share/zsh/site-functions/_meson
'

# =====================================================================
# 8.56 Libcap-2.70 (Required by Udev)
# =====================================================================
build_package "libcap-*.tar.xz" "Libcap" bash -c '
    sed -i "/^lib=/s/lib64/lib/" Make.Rules
    make prefix=/usr lib=lib
    make test || true
    make prefix=/usr lib=lib install
'

# =====================================================================
# 8.58 MarkupSafe-3.0.2 (Required by Jinja2)
# =====================================================================
build_package "markupsafe-*.tar.gz" "MarkupSafe" bash -c '
    pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
    pip3 install --no-index --no-deps --find-links dist MarkupSafe
'

# =====================================================================
# 8.57 Jinja2-3.1.6 (Required by Udev)
# =====================================================================
build_package "jinja2-*.tar.gz" "Jinja2" bash -c '
    pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
    pip3 install --no-index --find-links dist Jinja2
'

# =====================================================================
# 8.48 Gperf-3.3 (Required by Udev)
# =====================================================================
build_package "gperf-*.tar.gz" "Gperf" bash -c '
    ./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.3
    make
    make install
'

# =====================================================================
# 8.74 Udev from Systemd-257.8
# =====================================================================
should_skip_package "udev" "/sources" && { log_info "⊙ Skipping udev (already built, checkpoint valid)"; } || {
log_step "Building Udev from Systemd-257.8..."
tar -xf /sources/systemd-*.tar.gz
cd systemd-*

# Apply LFS-specific patches
sed -e 's/GROUP="render"/GROUP="video"/' \
    -e 's/GROUP="sgx", //' \
    -i rules.d/50-udev-default.rules.in

sed -i '/systemd-sysctl/s/^/#/' rules.d/99-systemd.rules.in

sed -e '/NETWORK_DIRS/s/systemd/udev/' \
    -i src/libsystemd/sd-network/network-util.h

mkdir -p build
cd build

# Configure with meson (udev-only build)
meson setup .. \
      --prefix=/usr \
      --buildtype=release \
      -D mode=release \
      -D dev-kvm-mode=0660 \
      -D link-udev-shared=false \
      -D logind=false \
      -D vconsole=false

# Build only udev components
export udev_helpers=$(grep "'name' :" ../src/udev/meson.build | \
                      awk '{print $3}' | tr -d ",'" | grep -v 'udevadm')

ninja udevadm systemd-hwdb \
      $(ninja -n | grep -Eo '(src/(lib)?udev|rules.d|hwdb.d)/[^ ]*') \
      $(realpath libudev.so --relative-to .) \
      $udev_helpers

# Install udev components manually
install -vm755 -d {/usr/lib,/etc}/udev/{hwdb.d,rules.d,network}
install -vm755 -d /usr/{lib,share}/pkgconfig
install -vm755 udevadm /usr/bin/
install -vm755 systemd-hwdb /usr/bin/udev-hwdb
ln -svfn ../bin/udevadm /usr/sbin/udevd
cp -av libudev.so{,*[0-9]} /usr/lib/
install -vm644 ../src/libudev/libudev.h /usr/include/
install -vm644 src/libudev/*.pc /usr/lib/pkgconfig/
install -vm644 src/udev/*.pc /usr/share/pkgconfig/
install -vm644 ../src/udev/udev.conf /etc/udev/
install -vm644 rules.d/* ../rules.d/README /usr/lib/udev/rules.d/
install -vm644 $(find ../rules.d/*.rules -not -name '*power-switch*') /usr/lib/udev/rules.d/
install -vm644 hwdb.d/* ../hwdb.d/{*.hwdb,README} /usr/lib/udev/hwdb.d/
install -vm755 $udev_helpers /usr/lib/udev
install -vm644 ../network/99-default.link /usr/lib/udev/network

# Install LFS-specific udev configuration
tar -xvf /sources/udev-lfs-*.tar.xz
make -f udev-lfs-*/Makefile.lfs install

# Install man pages
tar -xf /sources/systemd-man-pages-*.tar.xz \
    --no-same-owner --strip-components=1 \
    -C /usr/share/man --wildcards '*/udev*' '*/libudev*' \
                                  '*/systemd.link.5' \
                                  '*/systemd-'{hwdb,udevd.service}.8

sed 's|systemd/network|udev/network|' \
    /usr/share/man/man5/systemd.link.5 \
  > /usr/share/man/man5/udev.link.5

sed 's/systemd\\(\\?-\\)/udev\\1/' /usr/share/man/man8/systemd-hwdb.8 \
                               > /usr/share/man/man8/udev-hwdb.8

sed 's|lib.*udevd|sbin/udevd|' \
    /usr/share/man/man8/systemd-udevd.service.8 \
  > /usr/share/man/man8/udevd.8

rm -f /usr/share/man/man*/systemd*

unset udev_helpers

# Initialize hardware database
udev-hwdb update

cd /build
rm -rf systemd-*
log_info "Udev complete"
create_checkpoint "udev" "/sources" "chapter8"
}

# =====================================================================
# 8.78 Sysklogd-2.7.2
# =====================================================================
should_skip_package "sysklogd" "/sources" && { log_info "⊙ Skipping sysklogd (already built, checkpoint valid)"; } || {
log_step "Building Sysklogd-2.7.2..."
tar -xf /sources/sysklogd-*.tar.gz
cd sysklogd-*

./configure --prefix=/usr      \
            --sysconfdir=/etc  \
            --runstatedir=/run \
            --without-logger   \
            --disable-static   \
            --docdir=/usr/share/doc/sysklogd-2.7.2

make
make install

# Create syslog configuration
cat > /etc/syslog.conf << "EOF"
# Begin /etc/syslog.conf

auth,authpriv.* -/var/log/auth.log
*.*;auth,authpriv.none -/var/log/sys.log
daemon.* -/var/log/daemon.log
kern.* -/var/log/kern.log
mail.* -/var/log/mail.log
user.* -/var/log/user.log
*.emerg *

# Do not open any internet ports.
secure_mode 2

# End /etc/syslog.conf
EOF

# Create log directory
mkdir -pv /var/log

cd /build
rm -rf sysklogd-*
log_info "Sysklogd complete"
create_checkpoint "sysklogd" "/sources" "chapter8"
}

# =====================================================================
# 8.83 GRUB-2.12
# =====================================================================
should_skip_package "grub" "/sources" && { log_info "⊙ Skipping grub (already built, checkpoint valid)"; } || {
log_step "Building GRUB-2.12..."
tar -xf /sources/grub-*.tar.xz
cd grub-*

# Fix for GRUB 2.12 build issue - create missing extra_deps.lst
echo "depends bli part_gpt" > grub-core/extra_deps.lst

# Disable features we don't need
./configure --prefix=/usr \
            --sysconfdir=/etc \
            --disable-efiemu \
            --disable-werror

make
make install

# Move grub-mkconfig template files
mv -v /etc/grub.d/README /usr/share/doc/grub-2.12

cd /build
rm -rf grub-*
log_info "GRUB complete"
create_checkpoint "grub" "/sources" "chapter8"
}

# =====================================================================
# 8.82 LFS-Bootscripts-20250501
# =====================================================================
should_skip_package "lfs-bootscripts" "/sources" && { log_info "⊙ Skipping lfs-bootscripts (already built, checkpoint valid)"; } || {
log_step "Installing LFS-Bootscripts-20250501..."
tar -xf /sources/lfs-bootscripts-*.tar.xz
cd lfs-bootscripts-*
make install
cd /build
rm -rf lfs-bootscripts-*
log_info "LFS-Bootscripts complete"
create_checkpoint "lfs-bootscripts" "/sources" "chapter8"
}

fi  # End of if [ "$BUILD_STAGE" = "remaining" ] || [ "$BUILD_STAGE" = "all" ]

# =====================================================================
# VERIFY BUILD COMPLETENESS
# =====================================================================
log_info ""
log_info "=========================================="
log_info "Verifying build completeness..."
log_info "=========================================="

# Critical checks
VERIFICATION_FAILED=0

# 1. Check for /sbin/init (sysvinit)
if [ ! -f /sbin/init ]; then
    log_error "✗ CRITICAL: /sbin/init not found!"
    log_error "  Sysvinit installation failed or incomplete"
    VERIFICATION_FAILED=1
else
    log_info "✓ /sbin/init exists"
fi

# 2. Check for essential binaries
ESSENTIAL_BINS="/usr/bin/gcc /usr/bin/bash /bin/ls /sbin/init /usr/bin/make"
for bin in $ESSENTIAL_BINS; do
    if [ ! -f "$bin" ] && [ ! -L "$bin" ]; then
        log_error "✗ Essential binary missing: $bin"
        VERIFICATION_FAILED=1
    fi
done

# 3. Count installed packages by checkpoints
EXPECTED_PACKAGES=43  # Base packages + additions: pkgconf, flex, libxcrypt, expat, Python-final, ninja, flit-core, packaging, wheel, setuptools, meson, libcap, MarkupSafe, jinja2, gperf, udev, sysklogd, grub, iproute2
CHECKPOINT_COUNT=$(ls -1 /.checkpoints/*.checkpoint 2>/dev/null | grep -v "toolchain\|download\|configure" | wc -l)

log_info "Packages installed: $CHECKPOINT_COUNT / $EXPECTED_PACKAGES (minimal build)"

if [ "$CHECKPOINT_COUNT" -lt "$EXPECTED_PACKAGES" ]; then
    # Find where the build stopped
    LAST_SUCCESSFUL=$(ls -1t /.checkpoints/*.checkpoint 2>/dev/null | grep -v "toolchain\|download\|configure" | head -1 | sed 's|/.checkpoints/||; s|.checkpoint||')
    MISSING_COUNT=$((EXPECTED_PACKAGES - CHECKPOINT_COUNT))

    # Package build order (Chapter 8 - MINIMAL, gawk and vim skipped)
    PACKAGE_ORDER=(
        "man-pages" "iana-etc" "glibc" "zlib" "bzip2" "xz" "lz4" "zstd"
        "file" "libxcrypt" "pkgconf" "flex" "ncurses" "sed" "grep" "kmod" "iproute2" "coreutils" "diffutils"
        "findutils" "gzip" "kbd" "tar" "procps-ng" "sysvinit"
        "util-linux" "e2fsprogs" "expat" "Python-final" "ninja" "flit-core" "packaging" "wheel" "setuptools" "meson" "libcap" "MarkupSafe" "jinja2" "gperf" "udev" "sysklogd" "grub" "lfs-bootscripts"
    )

    # Find failed package by looking for the next one after last successful
    FAILED_PACKAGE="unknown"
    for i in "${!PACKAGE_ORDER[@]}"; do
        # Normalize checkpoint name (lowercase, remove version numbers)
        PKG_NORMALIZED=$(echo "${PACKAGE_ORDER[$i]}" | tr 'A-Z' 'a-z')
        LAST_NORMALIZED=$(echo "$LAST_SUCCESSFUL" | sed 's/-[0-9].*//' | tr 'A-Z' 'a-z')

        if [[ "$LAST_NORMALIZED" == *"$PKG_NORMALIZED"* ]] || [[ "$PKG_NORMALIZED" == *"$LAST_NORMALIZED"* ]]; then
            # Found the last successful package in the order
            NEXT_INDEX=$((i + 1))
            if [ $NEXT_INDEX -lt ${#PACKAGE_ORDER[@]} ]; then
                FAILED_PACKAGE="${PACKAGE_ORDER[$NEXT_INDEX]}"
            fi
            break
        fi
    done

    log_error "✗ BUILD FAILED!"
    log_error ""
    log_error "  Last successful package: $LAST_SUCCESSFUL"
    if [ "$FAILED_PACKAGE" != "unknown" ]; then
        log_error "  Build failed on package: $FAILED_PACKAGE"
    else
        log_error "  Build failed on the package AFTER this one"
    fi
    log_error ""
    log_error "  Completed: $CHECKPOINT_COUNT / $EXPECTED_PACKAGES packages"
    log_error "  Missing: $MISSING_COUNT packages"

    VERIFICATION_FAILED=1
fi

# Fail if critical checks failed
if [ "$VERIFICATION_FAILED" -eq 1 ]; then
    log_error ""
    log_error "=========================================="
    log_error "BUILD VERIFICATION FAILED!"
    log_error "=========================================="
    log_error "The build stopped before completion"
    log_error ""
    log_error "To debug, check the build log for errors:"
    log_error "  docker run --rm -v easylfs_lfs-logs:/logs alpine cat /logs/build-basesystem.log"
    log_error ""
    log_error "Or view recent log entries:"
    log_error "  docker run --rm -v easylfs_lfs-logs:/logs alpine tail -100 /logs/build-basesystem.log"
    log_error "=========================================="
    exit 1
fi

# Final success message
log_info ""
log_info "=========================================="
log_info "MINIMAL LFS BASE SYSTEM BUILD FINISHED!"
log_info "=========================================="
log_info "Packages installed: $CHECKPOINT_COUNT checkpoints created"
log_info "Essential packages for bootable SysV init system"
log_info "System is ready for kernel build"
log_info "=========================================="

# Create success marker
cat > /tmp/build_status << EOF
BUILD_SUCCESS=true
BUILD_TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
BUILD_STAGE=$BUILD_STAGE
PACKAGES_INSTALLED=$CHECKPOINT_COUNT
EOF

log_info "✓ SUCCESS: Build completed and verified"
exit 0

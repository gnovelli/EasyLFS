#!/bin/bash
set -euo pipefail

# =============================================================================
# EasyLFS Build Toolchain Script
# Builds the temporary cross-compilation toolchain (LFS Chapters 5-6)
# Duration: 2-4 hours
# =============================================================================

# Environment setup
export LFS="${LFS:-/lfs}"
export LFS_TGT="${LFS_TGT:-x86_64-lfs-linux-gnu}"
export LC_ALL=POSIX
export PATH=$LFS/tools/bin:/bin:/usr/bin
export MAKEFLAGS="${MAKEFLAGS:--j$(nproc)}"

SOURCES_DIR="/sources"
BUILD_DIR="$LFS/build"
TOOLS_DIR="$LFS/tools"

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

# Package build helper
build_package() {
    local package_pattern="$1"
    local package_name="$2"
    local configure_cmd="$3"
    local make_cmd="${4:-make $MAKEFLAGS}"
    local install_cmd="${5:-make install}"

    # Extract base package name from pattern (e.g., "m4" from "m4-*.tar.xz")
    local base_name=$(echo "$package_pattern" | sed 's/-\*.*$//')

    # Check checkpoint
    should_skip_package "$base_name" "$SOURCES_DIR" && return 0

    log_step "Building $package_name..."

    cd "$BUILD_DIR"
    local tarball=$(ls $SOURCES_DIR/$package_pattern 2>/dev/null | head -1)

    if [ -z "$tarball" ]; then
        log_error "Package not found: $package_pattern"
        return 1
    fi

    log_info "Extracting $tarball"
    tar -xf "$tarball"

    local extract_dir=$(tar -tf "$tarball" | head -1 | cut -d'/' -f1)
    cd "$extract_dir"

    log_info "Configuring $package_name..."
    eval "$configure_cmd"

    log_info "Compiling $package_name..."
    eval "$make_cmd"

    log_info "Installing $package_name..."
    eval "$install_cmd"

    cd "$BUILD_DIR"
    chmod -R +w "$extract_dir" 2>/dev/null || true
    rm -rf "$extract_dir" || log_warn "Could not remove build directory for $package_name (non-critical)"

    log_info "$package_name build complete"

    # Create checkpoint
    create_checkpoint "$base_name" "$SOURCES_DIR" "chapter6"
}

# Verify prerequisites
verify_prerequisites() {
    log_info "Verifying prerequisites..."

    if [ ! -d "$SOURCES_DIR" ] || [ -z "$(ls -A $SOURCES_DIR/*.tar.* 2>/dev/null)" ]; then
        log_error "Sources directory is empty. Run download-sources first!"
        exit 1
    fi

    mkdir -p "$BUILD_DIR"
    mkdir -p "$TOOLS_DIR"

    # Create initial directory structure (LFS Chapter 4.2)
    mkdir -pv $LFS/{etc,var} $LFS/usr/{bin,lib,sbin}

    # Create symlinks for bin, lib, sbin (unified /usr hierarchy)
    for i in bin lib sbin; do
        if [ ! -e "$LFS/$i" ]; then
            ln -sv usr/$i $LFS/$i
        fi
    done

    # Create lib64 directory for x86_64 (required before Glibc installation)
    # Remove if it exists as a symlink from previous failed run
    case $(uname -m) in
        x86_64)
            if [ -L "$LFS/lib64" ]; then
                log_warn "Removing existing lib64 symlink (from previous run)"
                rm -f "$LFS/lib64"
            fi
            mkdir -pv "$LFS/lib64"
            ;;
    esac

    log_info "LFS: $LFS"
    log_info "LFS_TGT: $LFS_TGT"
    log_info "MAKEFLAGS: $MAKEFLAGS"
    log_info "Build directory: $BUILD_DIR"
}

# =============================================================================
# CHAPTER 5: Cross-Toolchain
# =============================================================================

build_binutils_pass1() {
    # Check checkpoint
    should_skip_package "binutils-pass1" "$SOURCES_DIR" && return 0

    log_step "===== Binutils Pass 1 ====="

    cd "$BUILD_DIR"
    # Clean up any existing directory from previous failed builds
    rm -rf binutils-*/
    tar -xf $SOURCES_DIR/binutils-*.tar.xz
    cd binutils-*/

    mkdir -v build
    cd build

    ../configure --prefix=$TOOLS_DIR \
                 --with-sysroot=$LFS \
                 --target=$LFS_TGT \
                 --disable-nls \
                 --enable-gprofng=no \
                 --disable-werror \
                 --enable-default-hash-style=gnu

    make $MAKEFLAGS
    make install

    cd "$BUILD_DIR"
    rm -rf binutils-*/

    log_info "Binutils Pass 1 complete"

    # Create checkpoint
    create_checkpoint "binutils-pass1" "$SOURCES_DIR" "pass1"
}

build_gcc_pass1() {
    # Check checkpoint
    should_skip_package "gcc-pass1" "$SOURCES_DIR" && return 0

    log_step "===== GCC Pass 1 ====="

    cd "$BUILD_DIR"
    # Clean up any existing GCC directory from previous failed builds
    rm -rf gcc-*/
    tar -xf $SOURCES_DIR/gcc-*.tar.xz
    cd gcc-*/

    # Extract GMP, MPFR, MPC
    tar -xf $SOURCES_DIR/mpfr-*.tar.xz
    mv -v mpfr-* mpfr
    tar -xf $SOURCES_DIR/gmp-*.tar.xz
    mv -v gmp-* gmp
    tar -xf $SOURCES_DIR/mpc-*.tar.gz
    mv -v mpc-* mpc

    # Configure for x86_64
    case $(uname -m) in
      x86_64)
        sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
      ;;
    esac

    mkdir -v build
    cd build

    ../configure \
        --target=$LFS_TGT \
        --prefix=$TOOLS_DIR \
        --with-glibc-version=2.42 \
        --with-sysroot=$LFS \
        --with-newlib \
        --without-headers \
        --enable-default-pie \
        --enable-default-ssp \
        --disable-nls \
        --disable-shared \
        --disable-multilib \
        --disable-threads \
        --disable-libatomic \
        --disable-libgomp \
        --disable-libquadmath \
        --disable-libssp \
        --disable-libvtv \
        --disable-libstdcxx \
        --enable-languages=c,c++

    log_info "Starting GCC Pass 1 compilation (this will take 30-60 minutes)..."
    log_info "Building in-tree dependencies: GMP, MPFR, MPC..."
    if ! make $MAKEFLAGS 2>&1 | tee /tmp/gcc-pass1-build.log; then
        log_error "GCC Pass 1 compilation failed!"
        log_error "Showing last 100 lines of build log:"
        tail -100 /tmp/gcc-pass1-build.log
        log_error "Full log saved to /tmp/gcc-pass1-build.log"
        exit 1
    fi
    make install

    # Create limits.h
    cd ..
    cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
      `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include/limits.h

    cd "$BUILD_DIR"
    rm -rf gcc-*/

    log_info "GCC Pass 1 complete"

    # Create checkpoint
    create_checkpoint "gcc-pass1" "$SOURCES_DIR" "pass1"
}

build_linux_headers() {
    # Check checkpoint
    should_skip_package "linux-headers" "$SOURCES_DIR" && return 0

    log_step "===== Linux API Headers ====="

    cd "$BUILD_DIR"
    # Clean up any existing directory from previous failed builds
    rm -rf linux-*/
    tar -xf $SOURCES_DIR/linux-*.tar.xz
    cd linux-*/

    make mrproper
    make headers
    find usr/include -type f ! -name '*.h' -delete
    command cp -rfv usr/include $LFS/usr

    cd "$BUILD_DIR"
    rm -rf linux-*/

    log_info "Linux API Headers complete"

    # Create checkpoint
    create_checkpoint "linux-headers" "$SOURCES_DIR" "headers"
}

build_glibc() {
    # Check checkpoint
    should_skip_package "glibc" "$SOURCES_DIR" && return 0

    log_step "===== Glibc ====="

    cd "$BUILD_DIR"
    # Clean up any existing directory from previous failed builds
    rm -rf glibc-*/
    tar -xf $SOURCES_DIR/glibc-*.tar.xz
    cd glibc-*/

    case $(uname -m) in
        i?86)   ln -sfv ld-linux.so.2 $LFS/lib/ld-lsb.so.3
        ;;
        x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
                ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3
        ;;
    esac

    # Apply patch if exists
    patch -Np1 -i $SOURCES_DIR/glibc-*-fhs-1.patch 2>/dev/null || true

    mkdir -v build
    cd build

    echo "rootsbindir=/usr/sbin" > configparms

    ../configure \
        --prefix=/usr \
        --host=$LFS_TGT \
        --build=$(../scripts/config.guess) \
        --enable-kernel=4.19 \
        --with-headers=$LFS/usr/include \
        --disable-nscd \
        libc_cv_slibdir=/usr/lib

    make $MAKEFLAGS
    make DESTDIR=$LFS install

    # Fix ldd script
    sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd

    # Sanity check
    log_info "Testing toolchain..."
    echo 'int main(){}' | $LFS_TGT-gcc -xc -
    readelf -l a.out | grep ld-linux
    rm -v a.out

    cd "$BUILD_DIR"
    rm -rf glibc-*/

    log_info "Glibc complete"

    # Create checkpoint
    create_checkpoint "glibc" "$SOURCES_DIR" "pass1"
}

build_libstdcxx_pass1() {
    # Check checkpoint
    should_skip_package "libstdcxx-pass1" "$SOURCES_DIR" && return 0

    log_step "===== Libstdc++ Pass 1 =====  "

    cd "$BUILD_DIR"
    # Clean up any existing directory from previous failed builds
    rm -rf gcc-*/
    tar -xf $SOURCES_DIR/gcc-*.tar.xz
    cd gcc-*/

    mkdir -v build
    cd build

    ../libstdc++-v3/configure \
        --host=$LFS_TGT \
        --build=$(../config.guess) \
        --prefix=/usr \
        --disable-multilib \
        --disable-nls \
        --disable-libstdcxx-pch \
        --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/15.2.0

    make $MAKEFLAGS
    make DESTDIR=$LFS install

    # Remove libtool files
    rm -v $LFS/usr/lib/lib{stdc++{,exp,fs},supc++}.la

    cd "$BUILD_DIR"
    rm -rf gcc-*/

    log_info "Libstdc++ Pass 1 complete"

    # Create checkpoint
    create_checkpoint "libstdcxx-pass1" "$SOURCES_DIR" "pass1"
}

# =============================================================================
# CHAPTER 6: Cross-Compiling Temporary Tools
# =============================================================================

build_chapter6_tools() {
    log_step "===== Building Chapter 6 Tools ====="

    # M4
    build_package "m4-*.tar.xz" "M4" \
        "./configure --prefix=/usr --host=$LFS_TGT --build=\$(build-aux/config.guess)" \
        "make $MAKEFLAGS" \
        "make DESTDIR=$LFS install"

    # Ncurses (manual build with checkpoint)
    if ! should_skip_package "ncurses" "$SOURCES_DIR"; then
        cd "$BUILD_DIR"
        # Clean up any existing directory from previous failed builds
        rm -rf ncurses-*/
        tar -xf $SOURCES_DIR/ncurses-*.tgz
        cd ncurses-*/

        sed -i s/mawk// configure

        mkdir build
        pushd build
          ../configure
          make -C include
          make -C progs tic
        popd

        ./configure --prefix=/usr \
                    --host=$LFS_TGT \
                    --build=$(./config.guess) \
                    --mandir=/usr/share/man \
                    --with-manpage-format=normal \
                    --with-shared \
                    --without-normal \
                    --with-cxx-shared \
                    --without-debug \
                    --without-ada \
                    --disable-stripping

        make $MAKEFLAGS
        make DESTDIR=$LFS TIC_PATH=$(pwd)/build/progs/tic install
        ln -sfv libncursesw.so $LFS/usr/lib/libncurses.so
        sed -e 's/^#if.*XOPEN.*$/#if 1/' -i $LFS/usr/include/curses.h

        cd "$BUILD_DIR"
        rm -rf ncurses-*/

        create_checkpoint "ncurses" "$SOURCES_DIR" "chapter6"
    fi

    # Bash
    build_package "bash-*.tar.gz" "Bash" \
        "./configure --prefix=/usr --build=\$(sh support/config.guess) --host=$LFS_TGT --without-bash-malloc" \
        "make $MAKEFLAGS" \
        "make DESTDIR=$LFS install"

    ln -sfv bash $LFS/usr/bin/sh

    # Coreutils
    build_package "coreutils-*.tar.xz" "Coreutils" \
        "./configure --prefix=/usr --host=$LFS_TGT --build=\$(build-aux/config.guess) --enable-install-program=hostname --enable-no-install-program=kill,uptime" \
        "make $MAKEFLAGS" \
        "make DESTDIR=$LFS install"

    # Diffutils
    build_package "diffutils-*.tar.xz" "Diffutils" \
        "./configure --prefix=/usr --host=$LFS_TGT --build=\$(./build-aux/config.guess) gl_cv_func_strcasecmp_works=y" \
        "make $MAKEFLAGS" \
        "make DESTDIR=$LFS install"

    # File (manual build with checkpoint)
    if ! should_skip_package "file" "$SOURCES_DIR"; then
        cd "$BUILD_DIR"
        # Clean up any existing directory from previous failed builds
        rm -rf file-*/
        tar -xf $SOURCES_DIR/file-*.tar.gz
        cd file-*/

        mkdir build
        pushd build
          ../configure --disable-bzlib --disable-libseccomp --disable-xzlib --disable-zlib
          make
        popd

        ./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess)
        make FILE_COMPILE=$(pwd)/build/src/file $MAKEFLAGS
        make DESTDIR=$LFS install
        rm -v $LFS/usr/lib/libmagic.la

        cd "$BUILD_DIR"
        rm -rf file-*/

        create_checkpoint "file" "$SOURCES_DIR" "chapter6"
    fi

    # Findutils
    build_package "findutils-*.tar.xz" "Findutils" \
        "./configure --prefix=/usr --localstatedir=/var/lib/locate --host=$LFS_TGT --build=\$(build-aux/config.guess)" \
        "make $MAKEFLAGS" \
        "make DESTDIR=$LFS install"

    # Gawk
    build_package "gawk-*.tar.xz" "Gawk" \
        "sed -i 's/extras//' Makefile.in && ./configure --prefix=/usr --host=$LFS_TGT --build=\$(build-aux/config.guess)" \
        "make $MAKEFLAGS" \
        "make DESTDIR=$LFS install"

    # Grep
    build_package "grep-*.tar.xz" "Grep" \
        "./configure --prefix=/usr --host=$LFS_TGT --build=\$(./build-aux/config.guess)" \
        "make $MAKEFLAGS" \
        "make DESTDIR=$LFS install"

    # Gzip
    build_package "gzip-*.tar.xz" "Gzip" \
        "./configure --prefix=/usr --host=$LFS_TGT" \
        "make $MAKEFLAGS" \
        "make DESTDIR=$LFS install"

    # Make
    build_package "make-*.tar.gz" "Make" \
        "./configure --prefix=/usr --without-guile --host=$LFS_TGT --build=\$(build-aux/config.guess)" \
        "make $MAKEFLAGS" \
        "make DESTDIR=$LFS install"

    # Patch
    build_package "patch-*.tar.xz" "Patch" \
        "./configure --prefix=/usr --host=$LFS_TGT --build=\$(build-aux/config.guess)" \
        "make $MAKEFLAGS" \
        "make DESTDIR=$LFS install"

    # Sed
    build_package "sed-*.tar.xz" "Sed" \
        "./configure --prefix=/usr --host=$LFS_TGT --build=\$(./build-aux/config.guess)" \
        "make $MAKEFLAGS" \
        "make DESTDIR=$LFS install"

    # Tar
    build_package "tar-*.tar.xz" "Tar" \
        "./configure --prefix=/usr --host=$LFS_TGT --build=\$(build-aux/config.guess)" \
        "make $MAKEFLAGS" \
        "make DESTDIR=$LFS install"

    # Xz
    build_package "xz-*.tar.xz" "Xz" \
        "./configure --prefix=/usr --host=$LFS_TGT --build=\$(build-aux/config.guess) --disable-static --docdir=/usr/share/doc/xz-5.4.6" \
        "make $MAKEFLAGS" \
        "make DESTDIR=$LFS install"
}

build_binutils_pass2() {
    # Check checkpoint
    should_skip_package "binutils-pass2" "$SOURCES_DIR" && return 0

    log_step "===== Binutils Pass 2 ====="

    cd "$BUILD_DIR"
    # Clean up any existing directory from previous failed builds
    rm -rf binutils-*/
    tar -xf $SOURCES_DIR/binutils-*.tar.xz
    cd binutils-*/

    sed '6009s/$add_dir//' -i ltmain.sh

    mkdir -v build
    cd build

    ../configure \
        --prefix=/usr \
        --build=$(../config.guess) \
        --host=$LFS_TGT \
        --disable-nls \
        --enable-shared \
        --enable-gprofng=no \
        --disable-werror \
        --enable-64-bit-bfd \
        --enable-default-hash-style=gnu

    make $MAKEFLAGS
    make DESTDIR=$LFS install

    # Remove libtool files
    rm -v $LFS/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}

    cd "$BUILD_DIR"
    rm -rf binutils-*/

    log_info "Binutils Pass 2 complete"

    # Create checkpoint
    create_checkpoint "binutils-pass2" "$SOURCES_DIR" "pass2"
}

build_gcc_pass2() {
    # Check checkpoint
    should_skip_package "gcc-pass2" "$SOURCES_DIR" && return 0

    log_step "===== GCC Pass 2 ====="

    cd "$BUILD_DIR"
    # Clean up any existing directory from previous failed builds
    rm -rf gcc-*/
    tar -xf $SOURCES_DIR/gcc-*.tar.xz
    cd gcc-*/

    # Extract dependencies
    tar -xf $SOURCES_DIR/mpfr-*.tar.xz
    mv -v mpfr-* mpfr
    tar -xf $SOURCES_DIR/gmp-*.tar.xz
    mv -v gmp-* gmp
    tar -xf $SOURCES_DIR/mpc-*.tar.gz
    mv -v mpc-* mpc

    # Apply fixes
    case $(uname -m) in
      x86_64)
        sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
      ;;
    esac

    sed '/thread_header =/s/@.*@/gthr-posix.h/' \
        -i libgcc/Makefile.in libstdc++-v3/include/Makefile.in

    mkdir -v build
    cd build

    ../configure \
        --build=$(../config.guess) \
        --host=$LFS_TGT \
        --target=$LFS_TGT \
        LDFLAGS_FOR_TARGET=-L$PWD/$LFS_TGT/libgcc \
        --prefix=/usr \
        --with-build-sysroot=$LFS \
        --enable-default-pie \
        --enable-default-ssp \
        --disable-nls \
        --disable-multilib \
        --disable-libatomic \
        --disable-libgomp \
        --disable-libquadmath \
        --disable-libsanitizer \
        --disable-libssp \
        --disable-libvtv \
        --enable-languages=c,c++

    log_info "Starting GCC Pass 2 compilation (this will take 1-2 hours)..."
    log_info "Building in-tree dependencies: GMP, MPFR, MPC..."
    if ! make $MAKEFLAGS 2>&1 | tee /tmp/gcc-pass2-build.log; then
        log_error "GCC Pass 2 compilation failed!"
        log_error "Showing last 100 lines of build log:"
        tail -100 /tmp/gcc-pass2-build.log
        log_error "Full log saved to /tmp/gcc-pass2-build.log"
        exit 1
    fi
    make DESTDIR=$LFS install

    # Create cc symlink
    ln -sfv gcc $LFS/usr/bin/cc

    cd "$BUILD_DIR"
    rm -rf gcc-*/

    log_info "GCC Pass 2 complete"

    # Create checkpoint
    create_checkpoint "gcc-pass2" "$SOURCES_DIR" "pass2"
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    log_info "=========================================="
    log_info "EasyLFS Toolchain Build Starting"
    log_info "=========================================="
    log_info "Target: LFS 12.4 (SysVinit)"
    log_info "Architecture: $LFS_TGT"

    # Initialize checkpoint system
    init_checkpointing
    log_info "Checkpoint system initialized"

    # Idempotency check: Skip if toolchain is already built
    if [ -f "$LFS/usr/bin/gcc" ] && [ -f "$LFS/usr/bin/bash" ] && [ -f "$LFS/usr/bin/cc" ]; then
        log_info ""
        log_info "=========================================="
        log_info "Toolchain Already Built - Skipping"
        log_info "=========================================="
        log_info "✓ GCC exists at $LFS/usr/bin/gcc"
        log_info "✓ Bash exists at $LFS/usr/bin/bash"
        log_info "✓ CC symlink exists at $LFS/usr/bin/cc"
        log_info ""
        log_info "To force rebuild, remove these files or clear checkpoints:"
        log_info "  docker run --rm -v easylfs_lfs-rootfs:/lfs alpine rm -rf /lfs/.checkpoints"
        log_info "=========================================="
        exit 0
    fi

    verify_prerequisites

    # Chapter 5: Cross-Toolchain
    log_info ""
    log_info "========== CHAPTER 5: Cross-Toolchain =========="
    build_binutils_pass1
    build_gcc_pass1
    build_linux_headers
    build_glibc
    build_libstdcxx_pass1

    # Chapter 6: Temporary Tools
    log_info ""
    log_info "========== CHAPTER 6: Temporary Tools =========="
    build_chapter6_tools
    build_binutils_pass2
    build_gcc_pass2

    # Cleanup (fix permissions first to handle files created during builds)
    chmod -R +w "$BUILD_DIR" 2>/dev/null || true
    rm -rf "$BUILD_DIR" || log_warn "Could not remove some build artifacts (non-critical)"

    log_info ""
    log_info "=========================================="
    log_info "Toolchain Build Complete!"
    log_info "=========================================="
    log_info "Tools installed in: $TOOLS_DIR"
    log_info "LFS root: $LFS"

    exit 0
}

main "$@"

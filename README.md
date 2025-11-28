# EasyLFS - Easy Linux From Scratch

> A Docker Compose-based pipeline for building Linux From Scratch 12.4 (SysVinit)

[![LFS Version](https://img.shields.io/badge/LFS-12.4--sysv-blue)](https://www.linuxfromscratch.org/)
[![Docker](https://img.shields.io/badge/Docker-24.0%2B-blue)](https://www.docker.com/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

## Overview

EasyLFS is a modern, containerized implementation of the Linux From Scratch build process. It transforms the traditional manual LFS build into a modular, repeatable Docker Compose pipeline designed for both educational purposes and reproducible builds.

**Key Features:**
- **Modular Pipeline**: 6 sequential Docker services mapping to LFS chapters
- **Reproducible**: Same inputs produce identical outputs
- **Educational**: Learn LFS concepts without host system pollution
- **Portable**: Works on any Docker-enabled system
- **Stateful**: Named volumes preserve build artifacts between stages

## Architecture

```
┌─────────────────┐
│ download-sources│──> lfs-sources (volume)
└────────┬────────┘
         │
         v
┌─────────────────┐
│ build-toolchain │──> lfs-tools + lfs-rootfs
└────────┬────────┘
         │
         v
┌─────────────────┐
│build-basesystem │──> lfs-rootfs (chroot)
└────────┬────────┘
         │
         v
┌─────────────────┐
│configure-system │──> lfs-rootfs
└────────┬────────┘
         │
         v
┌─────────────────┐
│  build-kernel   │──> lfs-rootfs (/boot)
└────────┬────────┘
         │
         v
┌─────────────────┐
│ package-image   │──> lfs-dist (bootable .img)
└─────────────────┘
```

## Requirements

- **Docker**: 24.0 or higher
- **Docker Compose**: 2.20 or higher
- **Disk Space**: 20GB minimum (30GB recommended)
- **RAM**: 4GB minimum (8GB recommended for faster builds)
- **CPU**: Multi-core recommended (affects build time)

## Quick Start (Simplified Interface)

The easiest way to build your LFS system is using the unified `easylfs` command:

```bash
# Clone and enter the project
git clone https://github.com/gnovelli/easylfs.git
cd easylfs

# Build the complete LFS system (automatic setup included)
./easylfs build

# That's it! The script will:
# ✓ Auto-initialize Docker volumes
# ✓ Build all service images
# ✓ Run the complete 6-stage pipeline
# ✓ Create a bootable LFS system
```

### Other Useful Commands

```bash
./easylfs status     # Check build progress and volume status
./easylfs logs       # View build logs
./easylfs export     # Export final disk image to current directory
./easylfs shell      # Open shell in LFS rootfs
./easylfs clean      # Remove containers (keep volumes)
./easylfs reset      # Complete reset (removes everything)
./easylfs help       # Show all available commands
```

### Alternative: Using Make

```bash
make setup        # Initialize environment
make build        # Build complete LFS system
make status       # Check progress
make export       # Export disk image
```

## Web Access to Built LFS System

After building your LFS system, you can access it directly from your browser using two web interfaces:

### Quick Start

```bash
# Start both interfaces
make web

# Or start individually
make web-terminal    # Text-based terminal (http://localhost:7681)
make web-screen      # Graphical console (http://localhost:6080/vnc.html)

# Stop interfaces
make web-stop
```

### Web Terminal (ttyd)
- **Lightweight and fast** text-based shell access
- **URL**: http://localhost:7681
- Perfect for command-line operations and testing
- Low resource usage

### Web Screen (noVNC)
- **Full graphical console** with VNC streaming
- **URL**: http://localhost:6080/vnc.html
- See complete boot process and visual output
- Supports graphics applications

### Custom Ports

```bash
# Use custom ports
WEB_TERMINAL_PORT=8080 make web-terminal
WEB_SCREEN_PORT=8888 make web-screen

# Or set both
WEB_TERMINAL_PORT=7777 WEB_SCREEN_PORT=8888 make web
```

**See [WEB_INTERFACE.md](WEB_INTERFACE.md) for complete documentation**, troubleshooting, and advanced usage.

## Advanced: Manual Step-by-Step Build

For advanced users who want full control over each build stage:

### 1. Clone Repository

```bash
git clone https://github.com/gnovelli/easylfs.git
cd easylfs
```

### 2. Initialize Environment

Option A - Automatic (recommended):
```bash
./setup.sh
```

Option B - Manual:
```bash
docker volume create easylfs_lfs-sources
docker volume create easylfs_lfs-tools
docker volume create easylfs_lfs-rootfs
docker volume create easylfs_lfs-dist
docker volume create easylfs_lfs-logs

# Fix log volume permissions
docker run --rm -v easylfs_lfs-logs:/logs alpine chmod 777 /logs

# Build service images
docker compose build
```

### 3. Run Pipeline Manually

Execute services **sequentially** (not in parallel):

```bash
# Step 1: Download sources (~5-15 min)
docker compose run --rm download-sources

# Step 2: Build toolchain (~2-4 hours)
docker compose run --rm build-toolchain

# Step 3: Build base system (~3-6 hours)
docker compose run --rm build-basesystem

# Step 4: Configure system (~10-20 min)
docker compose run --rm configure-system

# Step 5: Build kernel (~20-60 min)
docker compose run --rm build-kernel

# Step 6: Package image (~15-30 min)
docker compose run --rm package-image
```

### 3. Extract LFS System

```bash
# Extract rootfs tarball from Docker volume
docker run --rm -v easylfs_lfs-dist:/dist -v $(pwd):/out alpine \
    cp /dist/lfs-12.4-sysv-rootfs.tar.gz /out/

# Verify tarball
tar -tzf lfs-12.4-sysv-rootfs.tar.gz | head -20
```

### 4. Deploy LFS System

**Option A: Extract to chroot environment**
```bash
# Create target directory
sudo mkdir -p /mnt/lfs

# Extract rootfs
sudo tar -xzf lfs-12.4-sysv-rootfs.tar.gz -C /mnt/lfs

# Chroot into the system
sudo chroot /mnt/lfs /bin/bash
```

**Option B: Create bootable disk image (requires bare metal or VM)**
```bash
# Create disk image
dd if=/dev/zero of=lfs-disk.img bs=1M count=2048

# Partition and format
sudo losetup -fP lfs-disk.img
sudo mkfs.ext4 /dev/loop0

# Extract and install GRUB
sudo mount /dev/loop0 /mnt
sudo tar -xzf lfs-12.4-sysv-rootfs.tar.gz -C /mnt
sudo grub-install --boot-directory=/mnt/boot /dev/loop0
sudo grub-mkconfig -o /mnt/boot/grub/grub.cfg
```

### 5. Boot with QEMU

```bash
# Console mode (recommended for SSH/remote)
qemu-system-x86_64 \
    -m 2G \
    -smp 2 \
    -drive file=lfs-12.4-sysv.img,format=raw \
    -boot c \
    -nographic \
    -serial mon:stdio

# Or with GUI (if running locally)
qemu-system-x86_64 \
    -m 2G \
    -smp 2 \
    -drive file=lfs-12.4-sysv.img,format=raw \
    -boot c
```

## Detailed Usage

### Individual Service Descriptions

#### download-sources
Downloads all LFS source packages and patches from linuxfromscratch.org mirrors.

```bash
docker compose run --rm download-sources
```

**Output**: Populates `lfs-sources` volume (~500MB, ~100 packages)

#### build-toolchain
Builds the temporary cross-compilation toolchain (LFS Chapters 5-6).

```bash
docker compose run --rm build-toolchain
```

**Duration**: 2-4 hours
**Output**: `lfs-tools` and initial `lfs-rootfs` volumes

#### build-basesystem
Enters chroot and builds the final LFS system (Chapters 7-8).

```bash
docker compose run --rm build-basesystem
```

**Duration**: 3-6 hours
**Requires**: `SYS_CHROOT` capability (configured in docker compose.yml)

#### configure-system
Creates system configuration files (Chapter 9).

```bash
docker compose run --rm configure-system
```

**Creates**: `/etc/fstab`, `/etc/hosts`, `/etc/inittab`, SysV bootscripts, etc.

#### build-kernel
Compiles the Linux kernel with essential features for LFS.

```bash
docker compose run --rm build-kernel
```

**Duration**: 20-60 minutes
**Output**: `/boot/vmlinuz-*` and kernel modules

#### package-image
Creates bootable disk image with GRUB2 bootloader and tarball.

```bash
docker compose run --rm package-image
```

**Duration**: 15-30 minutes
**Output**:
- `lfs-12.4-sysv.img.gz` (bootable disk image with GRUB2)
- `lfs-12.4-sysv.tar.gz` (rootfs tarball)

**Note**: The image is immediately bootable. GRUB is automatically installed to the MBR and configured to detect available kernels.

### Managing Volumes

#### Inspect Volume Contents

```bash
# List volumes
docker volume ls | grep easylfs

# Inspect sources
docker run --rm -v easylfs_lfs-sources:/sources alpine ls -lh /sources

# Inspect rootfs
docker run --rm -v easylfs_lfs-rootfs:/lfs alpine ls -lh /lfs
```

#### Viewing Build Logs

All services write detailed logs to the `lfs-logs` volume. Logs persist across container restarts and include timestamps, command output, and exit status.

```bash
# View a specific service log
docker run --rm -v easylfs_lfs-logs:/logs alpine cat /logs/build-toolchain.log

# View the master log (all services combined)
docker run --rm -v easylfs_lfs-logs:/logs alpine cat /logs/easylfs-master.log

# Copy all logs to current directory
docker run --rm -v easylfs_lfs-logs:/logs -v $(pwd):/out alpine \
    cp -r /logs /out/

# Tail logs in real-time (while service is running)
docker run --rm -v easylfs_lfs-logs:/logs alpine tail -f /logs/build-basesystem.log
```

Available log files:
- `download-sources.log` - Source download phase
- `build-toolchain.log` - Toolchain compilation (2-4 hours of output)
- `build-basesystem.log` - Base system build
- `configure-system.log` - System configuration
- `build-kernel.log` - Kernel compilation
- `package-image.log` - Image creation
- `easylfs-master.log` - Combined log from all services

#### Backup Volumes

```bash
# Backup lfs-rootfs volume
docker run --rm -v easylfs_lfs-rootfs:/lfs -v $(pwd):/backup alpine \
    tar -czf /backup/lfs-rootfs-backup.tar.gz -C /lfs .
```

#### Clean Up

```bash
# Remove all containers and volumes (complete reset)
docker compose down -v

# Remove only containers (keep volumes for resume)
docker compose down
```

## Build Times

Approximate durations on modern hardware (Intel i5/Ryzen 5, 8GB RAM):

| Service | Duration |
|---------|----------|
| download-sources | 5-15 min |
| build-toolchain | 2-4 hours |
| build-basesystem | 3-6 hours |
| configure-system | 10-20 min |
| build-kernel | 20-60 min |
| package-image | 15-30 min |
| **Total** | **6-11 hours** |

**Tip**: Run toolchain and basesystem builds overnight.

## Testing

### Automated Test Suite

EasyLFS includes a containerized test suite for validation and QA.

#### Quick Validation (5 minutes)

Verify volumes contain expected files without running builds:

```bash
docker compose run --rm test quick
```

#### Test Specific Service

```bash
docker compose run --rm test download-sources
docker compose run --rm test build-kernel
```

#### Full Pipeline Test

Run complete build with validation (6-11 hours):

```bash
docker compose run --rm test full
```

#### Volume Inspection

```bash
docker compose run --rm test validate
```

### Test Reports

Tests provide colored output with pass/fail status:

```
[TEST] Checking Docker volumes...
[PASS] Volume easylfs_lfs-sources exists
[PASS] Found 98 source files (expected ~100)
[PASS] Checksum file (md5sums) present
```

Exit codes:
- `0` = All tests passed
- `1` = One or more tests failed

### CI/CD Integration

Use in automated pipelines:

```yaml
# .github/workflows/test.yml
- name: Test EasyLFS Pipeline
  run: docker compose run --rm test quick
```

## Troubleshooting

### Error: "Permission denied" in chroot

**Cause**: Missing `SYS_CHROOT` capability

**Solution**: Verify `docker compose.yml` has:
```yaml
cap_add:
  - SYS_CHROOT
```

### Error: "No space left on device"

**Cause**: Insufficient Docker storage

**Solution**:
```bash
# Check Docker disk usage
docker system df

# Clean up unused images/containers
docker system prune -a
```

### Error: "Toolchain not found"

**Cause**: build-toolchain service didn't complete successfully

**Solution**: Re-run `docker compose run --rm build-toolchain` and check logs

### Slow Build Times

**Solutions**:
- Increase `MAKEFLAGS` parallelism: `export MAKEFLAGS=-j$(nproc)`
- Allocate more resources to Docker Desktop
- Use faster storage (SSD recommended)

### Build Fails Mid-Process

**Solution**: Check the service log to identify the failure point

```bash
# View the failed service log
docker run --rm -v easylfs_lfs-logs:/logs alpine cat /logs/<service-name>.log

# Search for errors
docker run --rm -v easylfs_lfs-logs:/logs alpine grep -i error /logs/<service-name>.log
```

Use volume backups to resume from last successful stage:

```bash
# After each major stage completes
docker compose run --rm <service>
docker run --rm -v easylfs_lfs-rootfs:/lfs -v $(pwd):/backup alpine \
    tar -czf /backup/checkpoint-<service>.tar.gz -C /lfs .
```

## Advanced Usage

### Customizing Build

#### Change Kernel Version

Edit `docker compose.yml`:
```yaml
environment:
  - KERNEL_VERSION=6.8.1
```

#### Adjust Parallelism

```bash
# Use 8 cores for compilation
export MAKEFLAGS=-j8
docker compose run --rm build-toolchain
```

#### Custom Hostname/Timezone

```yaml
configure-system:
  environment:
    - HOSTNAME=my-lfs-box
    - TIMEZONE=America/New_York
```

### Running Specific Build Stages

```bash
# Debug a service with bash shell
docker compose run --rm --entrypoint /bin/bash build-toolchain

# View service logs
docker compose logs download-sources
```

### Creating a Live USB

```bash
# Write image to USB drive (CAREFUL: This will erase the drive!)
sudo dd if=lfs-12.4-sysv.img of=/dev/sdX bs=4M status=progress sync

# Replace /dev/sdX with your actual USB device (check with lsblk)
```

## Project Structure

```
easylfs/
├── docker compose.yml          # Main orchestration file
├── services/                   # Service implementations
│   ├── common/                 # Shared utilities
│   │   ├── logging.sh          # Centralized logging system
│   │   └── README.md           # Logging documentation
│   ├── download-sources/
│   │   ├── Dockerfile
│   │   └── scripts/download.sh
│   ├── build-toolchain/
│   │   ├── Dockerfile
│   │   └── scripts/build_toolchain.sh
│   ├── build-basesystem/
│   ├── configure-system/
│   ├── build-kernel/
│   └── package-image/
├── tests/                      # Automated test suite
│   ├── Dockerfile
│   ├── README.md
│   └── scripts/
│       ├── test_runner.sh
│       ├── quick_test.sh
│       ├── test_pipeline.sh
│       ├── test_service.sh
│       └── validate_volumes.sh
├── volumes/                    # Bind mount points
│   └── sources/
└── dist/                       # Output images
```

## Educational Use

This project was designed as a teaching tool for Linux User Groups (LUGs) to demonstrate:

1. **Advanced Docker Patterns**: Multi-stage builds, named volumes, sequential orchestration
2. **LFS Concepts**: Cross-compilation, chroot, system bootstrap process
3. **DevOps Practices**: Reproducible builds, infrastructure as code
4. **Linux Internals**: Kernel configuration, SysVinit boot process, runlevels

## Implementation Status

### Current Build Status (2025-11-06)

✅ **PRODUCTION READY** - Complete pipeline fully functional and verified!

**Service Status**:
- ✅ **download-sources**: Complete and tested
- ✅ **build-toolchain**: Complete and verified
- ✅ **build-basesystem**: **COMPLETE** - All 59 packages build successfully
- ✅ **configure-system**: **COMPLETE** - System configuration applied
- ✅ **build-kernel**: **COMPLETE** - Linux 6.12.6 compiled and installed
- ✅ **package-image**: **COMPLETE** - Bootable images and tarball created

**Current Version**: v1.1.2

**Final Deliverables**:
- `lfs-12.4-sysv.img` (5GB) - Bootable disk image with GRUB
- `lfs-12.4-sysv.img.gz` (~1GB) - Compressed bootable image
- `lfs-12.4-sysv-rootfs.tar.gz` (~1GB) - Complete LFS root filesystem
- Linux kernel 6.12.6 with SysVinit support
- 59 essential packages from LFS Chapter 8
- Full system configuration (fstab, hostname, network, shell profiles)

### Recent Releases

**v1.1.2 (2025-11-06)** - Current Release
- Comprehensive documentation updates
- All services verified and production-ready
- Complete test coverage

**v1.1.1 (2025-11-06)**
- Fixed kbd package build issue (autom4te dependency)
- Improved timestamp handling to prevent testsuite regeneration
- Enhanced build reliability

**v1.1.0 (2025-11-05)**
- Enhanced security with SHA-512 password encryption
- Increased web-screen resolution to Full HD (1920x1080)
- Improved testing experience

**v1.0.0 (2025-11-05)** - First Production Release
- Complete LFS 12.4 (SysVinit) build pipeline
- 59 essential packages in base system
- Reproducible builds with checkpoint system
- Bootable disk images with GRUB

### Key Features

- ✅ **Complete Build Pipeline**: All 6 services functional and tested
- ✅ **Reproducible Builds**: Hash-based checkpoint system working perfectly
- ✅ **Bootable System**: Creates working LFS 12.4 (SysVinit) systems
- ✅ **Resume Capability**: Can resume from any failure point
- ✅ **Web Access**: Terminal and graphical console interfaces
- ✅ **Production Ready**: Fully tested and documented

### ~~Known Issues~~ ✅ All Critical Issues Resolved

All critical issues have been completely resolved:
- ~~Chroot logging~~ ✅ Fixed with explicit output redirection
- ~~Checkpointing in chroot~~ ✅ Fixed module copy path
- ~~Silent exits~~ ✅ Added success markers and exit codes
- ~~Kbd package build~~ ✅ Fixed autom4te dependency issue

**Minor Limitations**:
- Initial build takes 6-10 hours (hardware dependent)
- 5 files without upstream MD5 checksums re-download (~5s impact)
- Text console only (X11 not included in minimal system)

## Publishing to GitHub

EasyLFS includes a publishing system to share production-ready files on GitHub while keeping development files private.

### Quick Start

```bash
# First time setup
make publish-setup
# Enter your GitHub repository URL when prompted

# Publish production files
make publish
```

### What Gets Published

Only essential production files are published:
- Core pipeline (docker-compose.yml, setup.sh, easylfs, build.sh)
- Essential documentation (README.md, QUICKSTART.md)
- All services and tests
- No development notes, status reports, or debug files

### Publishing Workflow

```bash
# Interactive publishing (recommended)
make publish

# See what would be published (dry run)
make publish-dry-run

# Setup GitHub remote
make publish-setup
```

The script will:
1. Copy only production files to a separate worktree
2. Show you the changes (diff)
3. Ask for confirmation and commit message
4. Push to GitHub with clean history

**See [PUBLISHING.md](PUBLISHING.md) for complete documentation.**

---

## Contributing

Contributions welcome! The core pipeline is production-ready. Current priorities:

**✅ Completed**:
1. ~~Debug and fix chroot logging issues~~ ✅
2. ~~Implement checkpointing module copy to chroot~~ ✅
3. ~~Add explicit success/failure status reporting~~ ✅
4. ~~Complete all 6 pipeline services~~ ✅
5. ~~Comprehensive testing and validation~~ ✅
6. ~~Production-ready documentation~~ ✅

**High Priority** (Enhancements):
1. Implement local checksum storage for files without upstream MD5
2. Add comprehensive error handling and retry logic
3. Expand automated test suite with boot testing
4. CI/CD pipeline integration

**Medium Priority** (Extensions):
5. Add BLFS (Beyond Linux From Scratch) package extensions
6. Package manager integration (optional)
7. Build caching with ccache for faster rebuilds
8. Improved logging and progress reporting

**Low Priority** (Future Features):
9. Multi-architecture support (ARM64, RISC-V)
10. Parallel package builds where possible
11. ISO image generation
12. Network installation support
13. Alternative init system variants

## References

- **[Linux From Scratch Book](https://www.linuxfromscratch.org/lfs/view/12.4/)** - Primary source for build instructions
- **[LFS Credits](https://www.linuxfromscratch.org/lfs/credits.html)** - Contributors to the LFS project
- [SysVinit Documentation](https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/sysvinit.html)
- [Docker Multi-Stage Builds](https://docs.docker.com/build/building/multi-stage/)

## License

*License to be determined* - See [CREDITS.md](CREDITS.md) for attribution and third-party licenses

## Acknowledgments

This project is built upon the [Linux From Scratch (LFS)](https://www.linuxfromscratch.org/) project, utilizing the **build instructions and commands** from LFS 12.4, which are provided under the **MIT License**.

EasyLFS automates and containerizes these instructions while preserving the educational value of the LFS approach. **We strongly recommend reading the [original LFS book](https://www.linuxfromscratch.org/lfs/view/12.4/)** to understand the concepts behind each step.

**Credits:**
- **Linux From Scratch Project Team** - https://www.linuxfromscratch.org/

See [CREDITS.md](CREDITS.md) for detailed attribution, licensing information, and third-party components.

---

**Built with**: Docker, Bash, and the wisdom of the LFS community ☕

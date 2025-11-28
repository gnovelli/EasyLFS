# EasyLFS Quick Start Guide

**Build Linux From Scratch in 3 commands!**

## Prerequisites

- Docker 24.0+
- Docker Compose 2.20+
- 20GB free disk space
- 6-12 hours of build time

## Build Your LFS System

```bash
# 1. Clone the repository
git clone https://github.com/gnovelli/easylfs.git
cd easylfs

# 2. Build the complete system (auto-setup included)
./easylfs build

# 3. Export the bootable image
./easylfs export
```

That's it! You now have a bootable LFS system.

## Boot Your LFS System

### Option 1: Local QEMU

```bash
# Boot with QEMU
qemu-system-x86_64 -m 2G -hda lfs-12.4-sysv.img
```

### Option 2: Web Browser (No Export Needed!)

Access your LFS system directly from your browser:

```bash
# Start web interfaces
make web

# Access in browser:
# Terminal: http://localhost:7681
# Screen:   http://localhost:6080/vnc.html
```

**Benefits**:
- No need to export the image
- No QEMU installation required on host
- Access from any device on your network
- Perfect for demos and teaching

See [WEB_INTERFACE.md](WEB_INTERFACE.md) for complete documentation.

## Common Commands

```bash
./easylfs status     # Check build progress
./easylfs logs       # View build logs
./easylfs shell      # Explore LFS filesystem
./easylfs clean      # Remove containers
./easylfs reset      # Start fresh
./easylfs help       # Show all commands
```

## Alternative: Using Make

```bash
make setup        # Initialize environment
make build        # Build LFS system
make status       # Check progress
make export       # Export image
make help         # Show all targets
```

## Build Stages

The build process runs 6 sequential stages:

1. **download-sources** (5-15 min) - Download LFS packages
2. **build-toolchain** (2-4 hours) - Build cross-compilation toolchain
3. **build-basesystem** (3-6 hours) - Build core LFS system
4. **configure-system** (10-20 min) - Configure system files
5. **build-kernel** (20-60 min) - Compile Linux kernel
6. **package-image** (15-30 min) - Create bootable image

**Total time: 6-12 hours** (depending on hardware)

## Run Individual Stages

```bash
./easylfs download     # Just download sources
./easylfs toolchain    # Just build toolchain
./easylfs basesystem   # Just build base system
./easylfs configure    # Just configure system
./easylfs kernel       # Just build kernel
./easylfs package      # Just create image
```

## Troubleshooting

**Build fails mid-process?**
```bash
./easylfs logs         # Check what went wrong
./easylfs <stage>      # Re-run failed stage
```

**Want to start over?**
```bash
./easylfs reset        # Complete reset
./easylfs build        # Start fresh
```

**Need help?**
```bash
./easylfs help         # Show all commands
cat README.md       # Full documentation
```

## What Makes This Special?

- ✅ **Automatic setup** - No manual volume creation
- ✅ **Resume capability** - Failed builds can be resumed
- ✅ **Portable** - Works identically everywhere
- ✅ **Educational** - Learn Docker + LFS concepts
- ✅ **Transparent** - All scripts are readable

## Next Steps

- Read `README.md` for advanced usage

---

**Questions?** Check the full `README.md` or open an issue!

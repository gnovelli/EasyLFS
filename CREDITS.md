# Credits and Acknowledgments

## Linux From Scratch (LFS) Project

EasyLFS is built upon the foundation of the **Linux From Scratch** project, which provides comprehensive instructions for building a Linux system from source code.

### What We Use

This project utilizes the **computer instructions and build commands** from [Linux From Scratch 12.4 (SysVinit)](https://www.linuxfromscratch.org/lfs/view/12.4/), which are licensed under the **MIT License** as stated in the LFS book.

Specifically, we use:
- Build commands and sequences from LFS Chapters 5-10
- Package compilation instructions (configure, make, install)
- System configuration commands
- Kernel build procedures
- Bootloader installation steps

These instructions have been:
- Automated and containerized using Docker
- Organized into modular, sequential services
- Enhanced with checkpointing for idempotent builds
- Wrapped with error handling and logging
- Adapted for reproducible, non-interactive execution

### What We Don't Use

EasyLFS does **not** copy or redistribute the **narrative text, explanations, or editorial content** of the LFS book, which is licensed under Creative Commons Attribution-NonCommercial-ShareAlike 2.0.

The LFS book contains extensive educational content explaining:
- Why each step is necessary
- How Linux internals work
- Design decisions and alternatives
- Troubleshooting guidance

**We strongly encourage users to read the original [LFS Book](https://www.linuxfromscratch.org/lfs/view/12.4/)** to understand the concepts and rationale behind each step. The book is an invaluable educational resource.

### Attribution

- **Project**: Linux From Scratch (LFS)
- **Version**: 12.4 (SysVinit)
- **Website**: https://www.linuxfromscratch.org/
- **Book URL**: https://www.linuxfromscratch.org/lfs/view/12.4/
- **License (Build Instructions)**: MIT License
- **License (Book Content)**: CC BY-NC-SA 2.0

### Why LFS Matters

The Linux From Scratch project has been teaching people how Linux works since 1999. It provides:
- Deep understanding of Linux internals
- Knowledge of package management and dependencies
- Appreciation for distribution maintainers' work
- Foundation for creating custom Linux distributions

EasyLFS aims to make this educational experience more accessible through automation, while preserving the learning value.

---

## EasyLFS Original Contributions

The following are **original contributions** of the EasyLFS project:

### Architecture & Design
- Docker containerization strategy
- Multi-service pipeline architecture
- Named volume usage for artifact persistence
- Sequential service orchestration with Docker Compose
- Git worktree-based publishing system

### Automation & Tooling
- Checkpoint system for idempotent builds
- Centralized logging infrastructure
- Automated setup and build scripts
- Interactive publishing workflow
- Unified command interface (`easylfs`)

### Services
All service implementations in `services/`:
- Service Dockerfiles and configurations
- Build automation scripts
- Error handling and validation
- Progress reporting

### Features
- Resume capability after failures
- Hash-based checkpoint validation
- Web-based terminal access (ttyd)
- Web-based graphical console (noVNC)
- Automated testing framework
- Selective GitHub publishing

### Documentation
- All README files and guides
- QUICKSTART guide
- Publishing system documentation
- Troubleshooting guides
- This credits file

### Infrastructure
- Makefile targets
- Test suite implementation
- CI/CD integration templates
- Volume management utilities

---

## Third-Party Components

### Docker
- **Purpose**: Containerization platform
- **Website**: https://www.docker.com/
- **License**: Apache License 2.0
- **Usage**: Base infrastructure for all services

### Docker Compose
- **Purpose**: Multi-container orchestration
- **Website**: https://docs.docker.com/compose/
- **License**: Apache License 2.0
- **Usage**: Pipeline service coordination

### Alpine Linux
- **Purpose**: Minimal base images
- **Website**: https://alpinelinux.org/
- **License**: Various (mostly MIT)
- **Usage**: Base for utility containers and testing

### Ubuntu
- **Purpose**: Build environment base image
- **Website**: https://ubuntu.com/
- **License**: Various open source licenses
- **Usage**: Base for LFS build services

### ttyd
- **Purpose**: Web-based terminal
- **Website**: https://github.com/tsl0922/ttyd
- **License**: MIT License
- **Usage**: Web terminal service (optional)

### noVNC
- **Purpose**: Web-based VNC client
- **Website**: https://novnc.com/
- **License**: MPL 2.0
- **Usage**: Web console service (optional)

### QEMU
- **Purpose**: System emulator
- **Website**: https://www.qemu.org/
- **License**: GPL v2
- **Usage**: Testing bootable images (optional)

---

## Educational Context

### Learning Resources

EasyLFS is designed as an **educational tool** to complement the LFS book, not replace it. We recommend:

1. **Start with LFS Book**: Read [LFS 12.4](https://www.linuxfromscratch.org/lfs/view/12.4/) to understand concepts
2. **Use EasyLFS for Practice**: Automate the build to focus on understanding rather than manual execution
3. **Experiment**: Modify services to learn how changes affect the build
4. **Compare**: Look at our automation to understand how to script LFS builds

### Related Projects

Other automation approaches for LFS:
- **jhalfs** (https://www.linuxfromscratch.org/alfs/) - Official LFS automation using XML parsing
- **LFScript** (https://lfscript.org/) - Alternative LFS automation
- **BLFS** (https://www.linuxfromscratch.org/blfs/) - Beyond Linux From Scratch (additional packages)

Each approach has different goals and trade-offs. EasyLFS focuses on:
- Docker-native architecture
- Educational transparency (readable scripts)
- Modern DevOps practices
- Easy experimentation

---

## License Information

### EasyLFS Code
The original code and automation in this project is licensed under the **MIT License**.
See [LICENSE](LICENSE) for the full license text.

### LFS Instructions (MIT License)
The build commands and instructions derived from LFS are used under the MIT License as provided by the LFS project.

### LFS Book Content (CC BY-NC-SA 2.0)
Any narrative text from the LFS book (if quoted) would be under Creative Commons Attribution-NonCommercial-ShareAlike 2.0. However, EasyLFS intentionally avoids copying such content—instead referring users to the original book.

---

## Contributing

### To EasyLFS
See [README.md](README.md) for contribution guidelines.

---

**Last Updated**: 2025-11-25
**EasyLFS Version**: 1.2.0
**LFS Version**: 12.4 (SysVinit)

For updates to this attribution, see the project repository: https://github.com/gnovelli/easylfs

# EasyLFS Web Interface Guide

Access your built LFS system through a web browser!

## Overview

EasyLFS provides two web-based interfaces to interact with the built LFS system:

1. **Web Terminal (ttyd)** - Text-based shell in your browser
2. **Web Screen (noVNC)** - Full graphical console in your browser

Both interfaces run the LFS system in QEMU and stream the output to your browser.

## Quick Start

After building your LFS system (`make build`), start the web interfaces:

```bash
# Start both interfaces
make web

# Or start individually
make web-terminal    # Terminal only
make web-screen      # Screen only
```

Then access in your browser:
- **Terminal**: http://localhost:7681
- **Screen**: http://localhost:6080/vnc.html

## Web Terminal (ttyd)

### Features
- Lightweight and fast
- Direct serial console access
- Perfect for command-line operations
- Low resource usage

### Access
```bash
make web-terminal
```

Open: **http://localhost:7681**

### Usage
- The LFS system will boot automatically
- Login: `root` (no password)
- Exit QEMU: Press `Ctrl+A` then `X`
- Reload page to restart the system

### Customizing Port
```bash
# Use custom port
WEB_TERMINAL_PORT=8080 make web-terminal

# Or set in environment
export WEB_TERMINAL_PORT=8080
make web-terminal
```

## Web Screen (noVNC)

### Features
- Full graphical console
- VNC-based display
- See complete boot process
- Supports graphics (if installed)

### Access
```bash
make web-screen
```

Open: **http://localhost:6080/vnc.html**

### Usage
- Click "Connect" in the noVNC interface
- The LFS system will boot automatically
- Login: `root` (no password)
- Full keyboard and mouse support

### Customizing Port
```bash
# Use custom port
WEB_SCREEN_PORT=8888 make web-screen

# Or set in environment
export WEB_SCREEN_PORT=8888
make web-screen
```

## Starting Both Interfaces

```bash
# Start both with default ports
make web

# Start both with custom ports
WEB_TERMINAL_PORT=7777 WEB_SCREEN_PORT=8888 make web
```

Access:
- Terminal: http://localhost:7777
- Screen: http://localhost:8888/vnc.html

## Stopping Web Interfaces

```bash
make web-stop
```

This stops and removes both web interface containers.

## What If Image Doesn't Exist?

If you start the web interfaces before building the LFS system:

### Web Terminal
Shows a helpful message:
```
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║              LFS System Image Not Found                        ║
║                                                                ║
║  The LFS system image has not been built yet.                  ║
║                                                                ║
║  To build the LFS system, run:                                 ║
║    make build                                                  ║
║                                                                ║
║  Then access this web terminal at:                             ║
║    http://localhost:7681                                       ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
```

### Web Screen
Waits for the image to appear and shows status messages.

## Architecture

### How It Works

**Web Terminal (ttyd)**:
```
Browser → ttyd (port 7681) → QEMU -nographic → LFS System
```

**Web Screen (noVNC)**:
```
Browser → noVNC (port 6080) → websockify → VNC Server → QEMU -vnc → LFS System
```

### Docker Services

Both services are defined in `docker-compose.yml`:

```yaml
lfs-web-terminal:
  - Runs ttyd web server
  - Executes QEMU with serial console
  - Streams to browser via WebSocket

lfs-web-screen:
  - Runs VNC server (Xvnc)
  - Runs noVNC/websockify
  - Executes QEMU with VNC output
  - Streams graphical console to browser
```

## Troubleshooting

### Port Already in Use

```bash
# Check what's using the port
lsof -i :7681

# Use a different port
WEB_TERMINAL_PORT=7777 make web-terminal
```

### Cannot Connect to Web Interface

1. Check if container is running:
   ```bash
   docker compose ps
   ```

2. Check logs:
   ```bash
   docker compose logs lfs-web-terminal
   docker compose logs lfs-web-screen
   ```

3. Ensure image exists:
   ```bash
   docker run --rm -v easylfs_lfs-dist:/dist alpine ls -lh /dist
   ```

### Performance Issues

**Web Screen (noVNC)** uses more resources than **Web Terminal**.

For better performance:
- Use Web Terminal for command-line work
- Use Web Screen only when you need visual output
- Allocate more memory to QEMU if needed (edit startup scripts)

## Integration with Build Pipeline

The web interfaces are independent of the build pipeline. They:
- Read the built image from `lfs-dist` volume (read-only)
- Do not modify any build artifacts
- Can run while builds are in progress (different containers)

## Network Configuration

The LFS system boots with DHCP enabled on `eth0` via `/etc/sysconfig/ifconfig.eth0`.

Inside QEMU's virtual network:
- QEMU provides DHCP
- LFS system gets an IP automatically
- No external network access (isolated)

## Advanced Usage

### Running Multiple Instances

You can run multiple instances with different ports:

```bash
# Terminal instance 1
WEB_TERMINAL_PORT=7681 docker compose up -d lfs-web-terminal

# Terminal instance 2 (need to edit service name in compose)
# Not supported by default - requires manual compose modification
```

### Accessing from Another Machine

The web interfaces bind to `0.0.0.0` inside the container.

To access from another machine on your network:

```bash
# Find your machine's IP
ip addr show

# Access from another machine
http://<your-machine-ip>:7681      # Terminal
http://<your-machine-ip>:6080      # Screen
```

**Security Note**: No authentication is configured. Use only in trusted networks.

### Customizing QEMU Parameters

Edit the startup scripts:
- `services/lfs-web-terminal/scripts/start-web-terminal.sh`
- `services/lfs-web-screen/scripts/start-web-screen.sh`

Then rebuild the images:
```bash
docker compose build lfs-web-terminal lfs-web-screen
```

## Educational Use

The web interfaces are perfect for:
- **Live Demos**: Show LFS boot process to an audience
- **Remote Teaching**: Share browser access with students
- **Testing**: Quick access without local QEMU installation
- **Debugging**: Easy log capture via browser tools

## Comparison: Terminal vs Screen

| Feature | Web Terminal | Web Screen |
|---------|-------------|------------|
| Technology | ttyd + serial | noVNC + VNC |
| Resource Usage | Low | Medium |
| Boot Visibility | Text only | Full graphics |
| Performance | Faster | Slower |
| Best For | Command-line | Visual/GUI work |
| Browser Support | Modern browsers | Modern browsers |

## See Also

- [README.md](README.md) - Main project documentation
- [QUICKSTART.md](QUICKSTART.md) - Quick start guide
- [run-lfs.sh](run-lfs.sh) - Local QEMU script (no web interface)

## Support

For issues or questions:
- Check logs: `docker compose logs lfs-web-terminal lfs-web-screen`
- Review troubleshooting section above
- Open an issue on GitHub

---

**Happy exploring your LFS system!** 🎉

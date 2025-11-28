# EasyLFS Common Logging System

This directory contains shared utilities used by all EasyLFS services.

## Logging System

The `logging.sh` script provides centralized logging functionality for all EasyLFS build services.

### Features

- **Dual Output**: All logs are written to both console (with colors) and persistent log files
- **Service-Specific Logs**: Each service has its own log file (`/logs/<service-name>.log`)
- **Master Log**: All services append to a master log (`/logs/easylfs-master.log`) for complete audit trail
- **Timestamps**: All log entries include timestamps
- **Automatic Finalization**: Exit handlers ensure logs are properly closed with status information

### Log Files

Logs are stored in the `lfs-logs` Docker volume and persist across container runs:

- `/logs/download-sources.log` - Source download service
- `/logs/build-toolchain.log` - Toolchain build service
- `/logs/build-basesystem.log` - Base system build service
- `/logs/configure-system.log` - System configuration service
- `/logs/build-kernel.log` - Kernel build service
- `/logs/package-image.log` - Image packaging service
- `/logs/easylfs-master.log` - Combined log from all services

### Accessing Logs

View logs from the host:

```bash
# View a specific service log
docker run --rm -v easylfs_lfs-logs:/logs alpine cat /logs/build-toolchain.log

# View the master log
docker run --rm -v easylfs_lfs-logs:/logs alpine cat /logs/easylfs-master.log

# Copy all logs to host
docker run --rm -v easylfs_lfs-logs:/logs -v $(pwd):/out alpine \
    cp -r /logs /out/
```

## Usage in Service Scripts

### Integration Steps

1. **Source the logging library** at the top of your script:

```bash
#!/bin/bash
set -euo pipefail

# Load common logging functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../common/logging.sh"

# Setup exit trap
trap 'finalize_logging $?' EXIT
```

2. **Initialize logging** at the start of your main function:

```bash
main() {
    init_logging

    log_info "Starting my service..."
    # ...
}
```

3. **Remove local logging function definitions**:

   Delete any existing `log_info()`, `log_warn()`, `log_error()` functions from your script.

### Available Logging Functions

#### `init_logging()`
Initialize the logging system. Creates log files with headers. Call once at the start of your service.

#### `log_info "message"`
Log informational messages (shown in green on console).

```bash
log_info "Downloading source packages..."
```

#### `log_step "message"`
Log major steps/milestones (shown in blue on console).

```bash
log_step "Compiling GCC pass 1..."
```

#### `log_warn "message"`
Log warning messages (shown in yellow on console).

```bash
log_warn "Package already exists, skipping..."
```

#### `log_error "message"`
Log error messages (shown in red on console, written to stderr).

```bash
log_error "Failed to compile package"
```

#### `log_exec command [args...]`
Execute a command and capture all output to log file while still showing on console.

```bash
log_exec make -j4
log_exec ./configure --prefix=/usr
```

#### `finalize_logging [exit_code]`
Finalize logging with status summary. Automatically called by exit trap.

### Example: Converting an Existing Script

**Before:**
```bash
#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

main() {
    log_info "Starting build..."
    make -j4
    log_info "Build complete"
}

main "$@"
```

**After:**
```bash
#!/bin/bash
set -euo pipefail

# Load common logging
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../common/logging.sh"
trap 'finalize_logging $?' EXIT

main() {
    init_logging

    log_info "Starting build..."
    log_exec make -j4
    log_info "Build complete"
}

main "$@"
```

### Log Format

#### Service Log Format
```
========================================================================
EasyLFS Build Log - Service: build-toolchain
Started: 2025-10-22 14:30:15 UTC
Hostname: easylfs-build-toolchain
========================================================================

[2025-10-22 14:30:15] [INFO] Starting toolchain build...
[2025-10-22 14:30:16] [STEP] Compiling Binutils Pass 1...
[2025-10-22 14:35:42] [INFO] Binutils Pass 1 completed
...
========================================================================
Service build-toolchain completed with status: SUCCESS
Finished: 2025-10-22 18:45:30 UTC
Exit code: 0
========================================================================
```

#### Master Log Format
```
========================================================================
Service: download-sources started at 2025-10-22 14:00:00 UTC
========================================================================
[2025-10-22 14:00:01] [INFO] [download-sources] Starting download...
[2025-10-22 14:05:23] [INFO] [download-sources] Download complete
Service: download-sources finished at 2025-10-22 14:05:24 UTC - Status: SUCCESS
------------------------------------------------------------------------

========================================================================
Service: build-toolchain started at 2025-10-22 14:30:15 UTC
========================================================================
[2025-10-22 14:30:15] [INFO] [build-toolchain] Starting toolchain build...
...
```

## Benefits

1. **Debugging**: Full output of all commands captured for post-mortem analysis
2. **Audit Trail**: Complete record of what was built, when, and with what parameters
3. **Progress Tracking**: Real-time console output + persistent logs
4. **Troubleshooting**: Easily identify which service failed and why
5. **CI/CD**: Logs can be extracted and analyzed by automation tools

## Environment Variables

- `SERVICE_NAME`: Set automatically by docker compose.yml for each service
- `LOG_DIR`: Log directory (default: `/logs`)

## Maintenance

When adding a new service:

1. Add `lfs-logs:/logs` volume mount in docker compose.yml
2. Add `SERVICE_NAME=<service-name>` environment variable
3. Source `logging.sh` in your script
4. Call `init_logging` and use the logging functions

#!/bin/bash
# =============================================================================
# EasyLFS Common Logging Utility
# Provides centralized logging functions for all services
# =============================================================================

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Log directory
LOG_DIR="${LOG_DIR:-/logs}"
SERVICE_NAME="${SERVICE_NAME:-unknown}"
LOG_FILE="$LOG_DIR/${SERVICE_NAME}.log"
MASTER_LOG="$LOG_DIR/easylfs-master.log"

# Initialize logging
init_logging() {
    mkdir -p "$LOG_DIR"
    chmod 777 "$LOG_DIR" 2>/dev/null || true

    # Create service log with header
    {
        echo "========================================================================"
        echo "EasyLFS Build Log - Service: $SERVICE_NAME"
        echo "Started: $(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo "Hostname: $(hostname)"
        echo "User: $(whoami) (UID: $(id -u))"
        echo "========================================================================"
        echo ""
    } > "$LOG_FILE"

    # Append to master log
    {
        echo ""
        echo "========================================================================"
        echo "Service: $SERVICE_NAME started at $(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo "========================================================================"
    } >> "$MASTER_LOG"

    # Ensure log files are writable
    chmod 666 "$LOG_FILE" "$MASTER_LOG" 2>/dev/null || true
}

# Log with timestamp
_log_with_timestamp() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$timestamp] [$level] $message"
}

# Log info message
log_info() {
    local msg="$1"

    # Print to console with color
    echo -e "${GREEN}[INFO]${NC} $msg"

    # Write to logs without color codes
    _log_with_timestamp "INFO" "$msg" >> "$LOG_FILE"
    _log_with_timestamp "INFO" "[$SERVICE_NAME] $msg" >> "$MASTER_LOG"
}

# Log step message (major operation)
log_step() {
    local msg="$1"

    # Print to console with color
    echo -e "${BLUE}[STEP]${NC} $msg"

    # Write to logs without color codes
    _log_with_timestamp "STEP" "$msg" >> "$LOG_FILE"
    _log_with_timestamp "STEP" "[$SERVICE_NAME] $msg" >> "$MASTER_LOG"
}

# Log warning message
log_warn() {
    local msg="$1"

    # Print to console with color
    echo -e "${YELLOW}[WARN]${NC} $msg"

    # Write to logs without color codes
    _log_with_timestamp "WARN" "$msg" >> "$LOG_FILE"
    _log_with_timestamp "WARN" "[$SERVICE_NAME] $msg" >> "$MASTER_LOG"
}

# Log error message
log_error() {
    local msg="$1"

    # Print to console with color
    echo -e "${RED}[ERROR]${NC} $msg" >&2

    # Write to logs without color codes
    _log_with_timestamp "ERROR" "$msg" >> "$LOG_FILE"
    _log_with_timestamp "ERROR" "[$SERVICE_NAME] $msg" >> "$MASTER_LOG"
}

# Log command execution with full output capture
log_exec() {
    local cmd="$*"

    log_info "Executing: $cmd"

    # Execute command and capture output
    if eval "$cmd" 2>&1 | tee -a "$LOG_FILE"; then
        log_info "Command completed successfully"
        return 0
    else
        local exit_code=$?
        log_error "Command failed with exit code $exit_code"
        return $exit_code
    fi
}

# Finalize logging
finalize_logging() {
    local exit_code="${1:-0}"
    local status

    if [ "$exit_code" -eq 0 ]; then
        status="SUCCESS"
    else
        status="FAILED"
    fi

    {
        echo ""
        echo "========================================================================"
        echo "Service $SERVICE_NAME completed with status: $status"
        echo "Finished: $(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo "Exit code: $exit_code"
        echo "========================================================================"
    } >> "$LOG_FILE"

    {
        echo "Service: $SERVICE_NAME finished at $(date '+%Y-%m-%d %H:%M:%S %Z') - Status: $status"
        echo "------------------------------------------------------------------------"
    } >> "$MASTER_LOG"

    # Ensure log files remain world-readable/writable
    chmod 666 "$LOG_FILE" "$MASTER_LOG" 2>/dev/null || true

    if [ "$exit_code" -eq 0 ]; then
        log_info "Service completed successfully. Log saved to: $LOG_FILE"
    else
        log_error "Service failed. Check log for details: $LOG_FILE"
    fi
}

# Export functions for use in other scripts
export -f init_logging
export -f log_info
export -f log_step
export -f log_warn
export -f log_error
export -f log_exec
export -f finalize_logging

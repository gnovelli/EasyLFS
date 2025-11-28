#!/bin/bash
# =============================================================================
# EasyLFS Boot Test Script
# Tests the bootable LFS image with QEMU and runs comprehensive system tests
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_test() { echo -e "${BLUE}[TEST]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }

# Configuration
IMAGE_PATH="${1:-/workspace/lfs-12.4-sysv.img}"
TEST_TIMEOUT=60
QEMU_MEMORY="2G"
QEMU_CPUS="2"

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function to run test
run_test() {
    local test_name="$1"
    local test_command="$2"

    ((TESTS_TOTAL++))
    log_test "$test_name"

    if eval "$test_command" >/dev/null 2>&1; then
        log_pass "$test_name"
        ((TESTS_PASSED++))
        return 0
    else
        log_fail "$test_name"
        ((TESTS_FAILED++))
        return 1
    fi
}

# =============================================================================
# Pre-Boot Tests
# =============================================================================

log_info "===== PRE-BOOT TESTS ====="

# Test 1: Image file exists
run_test "Image file exists" "test -f '$IMAGE_PATH'"

# Test 2: Image is not empty
run_test "Image is not empty" "test -s '$IMAGE_PATH'"

# Test 3: Image size is reasonable (> 500MB)
run_test "Image size > 500MB" "[ \$(stat -c %s '$IMAGE_PATH') -gt 524288000 ]"

# Test 4: QEMU is available
run_test "QEMU is installed" "command -v qemu-system-x86_64"

# =============================================================================
# Boot Test
# =============================================================================

log_info "===== BOOT TEST ====="

log_info "Attempting to boot LFS image with QEMU..."
log_info "Image: $IMAGE_PATH"
log_info "Memory: $QEMU_MEMORY, CPUs: $QEMU_CPUS"

# Create expect script for automated testing
cat > /tmp/qemu_boot_test.exp << 'EOF'
#!/usr/bin/expect -f

set timeout 120
set image_path [lindex $argv 0]

# Start QEMU
spawn qemu-system-x86_64 \
    -m 2G \
    -smp 2 \
    -drive file=$image_path,format=raw \
    -boot c \
    -nographic \
    -serial mon:stdio

# Wait for boot
expect {
    "Welcome to" {
        send_user "\n[BOOT] System booted successfully\n"
    }
    "Kernel panic" {
        send_user "\n[BOOT ERROR] Kernel panic detected\n"
        exit 1
    }
    timeout {
        send_user "\n[BOOT ERROR] Boot timeout\n"
        exit 1
    }
}

# Wait for login prompt
expect {
    "login:" {
        send_user "\n[BOOT] Login prompt reached\n"
        send "root\r"
    }
    timeout {
        send_user "\n[BOOT ERROR] No login prompt\n"
        exit 1
    }
}

# Wait for shell prompt
expect {
    "#" {
        send_user "\n[BOOT] Shell prompt reached\n"
    }
    timeout {
        send_user "\n[BOOT ERROR] No shell prompt\n"
        exit 1
    }
}

# Run basic system tests
send "uname -a\r"
expect "#"

send "cat /etc/os-release\r"
expect "#"

send "systemctl status\r"
expect "#"

send "ls -la /bin /usr/bin | head -20\r"
expect "#"

# Shutdown
send "poweroff\r"
expect eof

send_user "\n[BOOT] All boot tests passed\n"
exit 0
EOF

chmod +x /tmp/qemu_boot_test.exp

# Run boot test if expect is available
if command -v expect >/dev/null 2>&1; then
    if /tmp/qemu_boot_test.exp "$IMAGE_PATH"; then
        log_pass "QEMU boot test"
        ((TESTS_PASSED++))
    else
        log_fail "QEMU boot test"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))
else
    log_warn "Expect not installed - skipping automated boot test"
    log_info "Manual boot test command:"
    log_info "  qemu-system-x86_64 -m 2G -smp 2 -drive file=$IMAGE_PATH,format=raw -boot c -nographic -serial mon:stdio"
fi

# Cleanup
rm -f /tmp/qemu_boot_test.exp

# =============================================================================
# Summary
# =============================================================================

log_info ""
log_info "=========================================="
log_info "BOOT TEST SUMMARY"
log_info "=========================================="
log_info "Total Tests:  $TESTS_TOTAL"
log_pass "Passed:       $TESTS_PASSED"
log_fail "Failed:       $TESTS_FAILED"

if [ $TESTS_FAILED -eq 0 ]; then
    log_info "=========================================="
    log_pass "ALL TESTS PASSED"
    log_info "=========================================="
    exit 0
else
    log_info "=========================================="
    log_fail "SOME TESTS FAILED"
    log_info "=========================================="
    exit 1
fi

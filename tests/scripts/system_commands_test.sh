#!/bin/bash
# =============================================================================
# EasyLFS System Commands Test
# Tests all essential system commands in the built LFS system
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_test() { echo -e "${BLUE}[TEST]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function to test command existence
test_command() {
    local cmd="$1"
    ((TESTS_TOTAL++))

    if command -v "$cmd" >/dev/null 2>&1; then
        log_pass "Command exists: $cmd"
        ((TESTS_PASSED++))
        return 0
    else
        log_fail "Command missing: $cmd"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Helper function to test command execution
test_command_exec() {
    local cmd="$1"
    local description="$2"
    ((TESTS_TOTAL++))

    log_test "$description"
    if eval "$cmd" >/dev/null 2>&1; then
        log_pass "$description"
        ((TESTS_PASSED++))
        return 0
    else
        log_fail "$description"
        ((TESTS_FAILED++))
        return 1
    fi
}

echo "=========================================="
echo "EasyLFS SYSTEM COMMANDS TEST"
echo "=========================================="

# =============================================================================
# Coreutils Commands (Priority 1)
# =============================================================================

echo ""
echo "===== COREUTILS COMMANDS ====="

test_command ls
test_command cp
test_command mv
test_command rm
test_command cat
test_command echo
test_command pwd
test_command mkdir
test_command rmdir
test_command chmod
test_command chown
test_command chgrp
test_command ln
test_command touch
test_command date
test_command df
test_command du
test_command wc
test_command sort
test_command uniq
test_command head
test_command tail
test_command cut
test_command tr
test_command basename
test_command dirname
test_command seq
test_command tee
test_command yes
test_command true
test_command false
test_command env
test_command printenv
test_command sleep
test_command uname
test_command whoami
test_command id
test_command groups
test_command who
test_command stat

# =============================================================================
# Shell and Scripting (Priority 1)
# =============================================================================

echo ""
echo "===== SHELL AND SCRIPTING ====="

test_command bash
test_command sh
test_command test
test_command [
test_command expr
test_command printf

# =============================================================================
# Text Processing (Priority 1)
# =============================================================================

echo ""
echo "===== TEXT PROCESSING ====="

test_command sed
test_command grep
test_command egrep
test_command fgrep
test_command awk
test_command gawk
test_command find
test_command xargs
test_command diff
test_command patch
test_command less
test_command more

# =============================================================================
# Compression Tools (Priority 1)
# =============================================================================

echo ""
echo "===== COMPRESSION TOOLS ====="

test_command gzip
test_command gunzip
test_command bzip2
test_command bunzip2
test_command xz
test_command unxz
test_command tar
test_command zstd

# =============================================================================
# Build Tools (Priority 1)
# =============================================================================

echo ""
echo "===== BUILD TOOLS ====="

test_command gcc
test_command g++
test_command cc
test_command make
test_command ar
test_command ranlib
test_command nm
test_command objdump
test_command strip
test_command ld
test_command as

# =============================================================================
# System Management (Priority 1)
# =============================================================================

echo ""
echo "===== SYSTEM MANAGEMENT ====="

test_command systemctl
test_command journalctl
test_command dbus-daemon
test_command mount
test_command umount
test_command ps
test_command top
test_command kill
test_command pkill
test_command nice
test_command renice
test_command free
test_command uptime

# =============================================================================
# File System Tools (Priority 1)
# =============================================================================

echo ""
echo "===== FILE SYSTEM TOOLS ====="

test_command mkfs.ext2
test_command mkfs.ext3
test_command mkfs.ext4
test_command fsck
test_command e2fsck
test_command tune2fs
test_command dumpe2fs

# =============================================================================
# Network Tools (Priority 2)
# =============================================================================

echo ""
echo "===== NETWORK TOOLS ====="

test_command ip
test_command ping
test_command hostname
test_command ifconfig

# =============================================================================
# Bootloader (Priority 1)
# =============================================================================

echo ""
echo "===== BOOTLOADER ====="

test_command grub-install
test_command grub-mkconfig
test_command update-grub

# =============================================================================
# Development Tools (Priority 2)
# =============================================================================

echo ""
echo "===== DEVELOPMENT TOOLS ====="

test_command perl
test_command python3
test_command pip3
test_command m4
test_command autoconf
test_command automake
test_command libtool
test_command pkg-config
test_command bison
test_command flex
test_command gperf
test_command ninja
test_command meson

# =============================================================================
# Editors (Priority 2)
# =============================================================================

echo ""
echo "===== EDITORS ====="

test_command vi
test_command vim

# =============================================================================
# Documentation (Priority 2)
# =============================================================================

echo ""
echo "===== DOCUMENTATION ====="

test_command man
test_command info
test_command groff

# =============================================================================
# Functional Tests
# =============================================================================

echo ""
echo "===== FUNCTIONAL TESTS ====="

# Test GCC compilation
test_command_exec "echo 'int main() { return 0; }' | gcc -x c - -o /tmp/test_gcc && /tmp/test_gcc" "GCC can compile and run programs"

# Test Make
test_command_exec "echo 'all:\n\techo test' | make -f -" "Make can execute Makefiles"

# Test Python
test_command_exec "python3 -c 'print(\"test\")'" "Python3 can execute scripts"

# Test Perl
test_command_exec "perl -e 'print \"test\"'" "Perl can execute scripts"

# Test tar/gzip
test_command_exec "tar -czf /tmp/test.tar.gz /etc/passwd && tar -tzf /tmp/test.tar.gz" "Tar with gzip compression works"

# Test systemctl
test_command_exec "systemctl list-units" "Systemctl can list units"

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "=========================================="
echo "TEST SUMMARY"
echo "=========================================="
echo "Total Tests:  $TESTS_TOTAL"
echo -e "${GREEN}Passed:       $TESTS_PASSED${NC}"
echo -e "${RED}Failed:       $TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo "=========================================="
    echo -e "${GREEN}ALL TESTS PASSED${NC}"
    echo "=========================================="
    exit 0
else
    PASS_RATE=$((TESTS_PASSED * 100 / TESTS_TOTAL))
    echo "=========================================="
    echo -e "${YELLOW}Pass Rate:    ${PASS_RATE}%${NC}"
    echo "=========================================="
    exit 1
fi

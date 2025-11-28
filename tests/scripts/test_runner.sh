#!/bin/bash
set -e

# =============================================================================
# EasyLFS Test Runner - Main Entry Point
# Runs containerized tests for the EasyLFS pipeline
# =============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_test() { echo -e "${BLUE}[TEST]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Display banner
echo "=============================================="
echo "  EasyLFS Automated Test Suite"
echo "  LFS 12.4 (SystemD) Pipeline Validation"
echo "=============================================="
echo ""

# Parse command
TEST_TYPE="${1:-full}"

case "$TEST_TYPE" in
    quick)
        log_info "Running QUICK validation test (file checks only)"
        exec /tests/quick_test.sh
        ;;

    validate)
        log_info "Running volume validation"
        exec /tests/validate_volumes.sh
        ;;

    download-sources|build-toolchain|build-basesystem|configure-system|build-kernel|package-image)
        log_info "Running test for service: $TEST_TYPE"
        exec /tests/test_service.sh "$TEST_TYPE"
        ;;

    full)
        log_info "Running FULL pipeline test (includes build)"
        exec /tests/test_pipeline.sh
        ;;

    help|--help|-h)
        cat << EOF
EasyLFS Test Runner

Usage: docker compose run --rm test [COMMAND]

Commands:
  quick              Quick validation (file checks only, ~5 min)
  validate           Validate volume contents
  full               Full pipeline test (build + validate, 6-11 hours)
  <service-name>     Test specific service (e.g., download-sources)
  help               Show this help message

Examples:
  docker compose run --rm test quick
  docker compose run --rm test download-sources
  docker compose run --rm test full

EOF
        exit 0
        ;;

    *)
        log_error "Unknown test type: $TEST_TYPE"
        echo "Run 'docker compose run --rm test help' for usage"
        exit 1
        ;;
esac

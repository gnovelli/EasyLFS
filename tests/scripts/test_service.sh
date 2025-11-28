#!/bin/bash
set -e

# =============================================================================
# EasyLFS Service Test
# Tests a single service in the pipeline
# =============================================================================

SERVICE="$1"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ -z "$SERVICE" ]; then
    echo -e "${RED}Error: Service name required${NC}"
    echo "Usage: test_service.sh <service-name>"
    echo ""
    echo "Available services:"
    echo "  - download-sources"
    echo "  - build-toolchain"
    echo "  - build-basesystem"
    echo "  - configure-system"
    echo "  - build-kernel"
    echo "  - package-image"
    exit 1
fi

echo "=========================================="
echo "Testing Service: $SERVICE"
echo "=========================================="
echo ""

# Check if service exists in docker compose.yml
if ! docker compose config --services | grep -q "^${SERVICE}$"; then
    echo -e "${RED}Error: Service '$SERVICE' not found in docker compose.yml${NC}"
    exit 1
fi

# Run the service
echo -e "${BLUE}[INFO]${NC} Running service: $SERVICE"
echo ""

if docker compose run --rm "$SERVICE"; then
    echo ""
    echo -e "${GREEN}[PASS]${NC} Service $SERVICE completed successfully"
    exit 0
else
    echo ""
    echo -e "${RED}[FAIL]${NC} Service $SERVICE failed"
    exit 1
fi

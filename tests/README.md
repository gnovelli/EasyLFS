# EasyLFS Automated Test Suite

Containerized testing framework for the EasyLFS pipeline.

## Quick Start

All tests run inside Docker containers - no host dependencies required!

```bash
# Quick validation (5 minutes)
docker compose run --rm test quick

# Full pipeline test (6-11 hours)
docker compose run --rm test full

# Test specific service
docker compose run --rm test download-sources
```

## Available Test Commands

### `quick` - Fast Validation
Validates volume contents without running builds.

**Duration**: ~5 minutes
**What it checks**:
- Volume existence
- File counts
- Essential file presence
- Kernel size validation

```bash
docker compose run --rm test quick
```

### `validate` - Volume Report
Detailed information about all Docker volumes.

```bash
docker compose run --rm test validate
```

### `<service-name>` - Single Service Test
Test a specific service in isolation.

**Available services**:
- `download-sources`
- `build-toolchain`
- `build-basesystem`
- `configure-system`
- `build-kernel`
- `package-image`

```bash
docker compose run --rm test download-sources
```

### `full` - Complete Pipeline Test
Runs entire build pipeline with validation.

**Duration**: 6-11 hours
**What it does**:
1. Cleans up previous state
2. Runs all 6 services sequentially
3. Validates each step
4. Reports timing and results

```bash
docker compose run --rm test full
```

## Test Scripts

Located in `tests/scripts/`:

| Script | Purpose |
|--------|---------|
| `test_runner.sh` | Main entry point, routes to other scripts |
| `quick_test.sh` | Fast validation without builds |
| `test_pipeline.sh` | Full end-to-end test |
| `test_service.sh` | Single service testing |
| `validate_volumes.sh` | Volume inspection |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All tests passed |
| 1 | One or more tests failed |

## CI/CD Integration

Use in GitHub Actions or similar:

```yaml
- name: Run EasyLFS Tests
  run: docker compose run --rm test quick
```

## Troubleshooting

### Error: "Cannot connect to Docker daemon"

The test container needs access to Docker socket:

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

This is already configured in `docker compose.yml`.

### Tests hang or timeout

Increase Docker resources:
- Memory: 8GB recommended
- Disk: 30GB free space

### Permission errors

Ensure Docker socket has correct permissions:

```bash
sudo chmod 666 /var/run/docker.sock
```

## Examples

### Development Workflow

```bash
# 1. Make changes to a service
vim services/download-sources/scripts/download.sh

# 2. Test only that service
docker compose run --rm test download-sources

# 3. If passes, run quick validation
docker compose run --rm test quick
```

### Pre-Commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "Running EasyLFS quick tests..."
docker compose run --rm test quick || {
    echo "Tests failed! Commit aborted."
    exit 1
}
```

### Nightly Build Validation

```bash
#!/bin/bash
# nightly_test.sh

docker compose down -v
docker compose run --rm test full > test-$(date +%Y%m%d).log 2>&1
```

## Architecture

```
┌─────────────────┐
│   test_runner   │ Entry point
└────────┬────────┘
         │
         ├──> quick_test.sh (file checks)
         ├──> validate_volumes.sh (volume info)
         ├──> test_service.sh (single service)
         └──> test_pipeline.sh (full build)
```

The test container has access to:
- Docker socket (to run docker commands)
- All EasyLFS volumes (read-only)
- docker compose.yml (to introspect services)

## Performance

### Quick Test Benchmark

| Hardware | Duration |
|----------|----------|
| 4 core, 8GB RAM | ~3 min |
| 2 core, 4GB RAM | ~7 min |

### Full Pipeline Test Benchmark

| Hardware | Duration |
|----------|----------|
| 8 core, 16GB RAM | ~6 hours |
| 4 core, 8GB RAM | ~9 hours |
| 2 core, 4GB RAM | ~14 hours |

## Contributing

To add new tests:

1. Create script in `tests/scripts/`
2. Make executable: `chmod +x tests/scripts/mytest.sh`
3. Add case in `test_runner.sh`
4. Update this README

---

**For detailed QA procedures, see**: [QA_plan.md](../QA_plan.md)

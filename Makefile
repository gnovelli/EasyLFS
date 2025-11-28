# EasyLFS Makefile
# Simplified interface for building Linux From Scratch

.PHONY: help setup build clean clean-all clean-basesystem clean-basesystem-light status logs inspect test rerun-download rerun-toolchain rerun-basesystem rerun-configure rerun-kernel rerun-package web-terminal web-screen web web-stop publish publish-dry-run publish-setup

# Docker Compose command (using v2 syntax)
DOCKER_COMPOSE := docker compose

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

help:
	@echo -e "$(BLUE)EasyLFS - Easy Linux From Scratch$(NC)"
	@echo ""
	@echo -e "$(YELLOW)Available targets:$(NC)"
	@echo "  make setup       - Initialize Docker volumes and build images"
	@echo "  make build       - Run complete build pipeline (takes 6-12 hours)"
	@echo "  make status      - Show build status and volume information"
	@echo "  make logs        - Display build logs"
	@echo "  make inspect     - Inspect volume contents"
	@echo "  make test        - Run validation tests"
	@echo "  make clean                 - Remove containers (keep volumes)"
	@echo "  make clean-basesystem-light- Clean checkpoints & temp files (fast)"
	@echo "  make clean-basesystem      - Reset rootfs volume (keep sources & toolchain)"
	@echo "  make clean-all             - Remove containers and ALL volumes (full reset)"
	@echo "                               Use FORCE_CLEAN=1 to skip confirmation"
	@echo ""
	@echo -e "$(YELLOW)Individual stages (with dependencies):$(NC)"
	@echo "  make download    - Download source packages only"
	@echo "  make toolchain   - Build toolchain only"
	@echo "  make basesystem  - Build base system only"
	@echo "  make configure   - Configure system only"
	@echo "  make kernel      - Build kernel only"
	@echo "  make package     - Create disk image only"
	@echo ""
	@echo -e "$(YELLOW)Re-run stages (skip dependencies):$(NC)"
	@echo "  make rerun-download    - Re-run download-sources only"
	@echo "  make rerun-toolchain   - Re-run build-toolchain only"
	@echo "  make rerun-basesystem  - Re-run build-basesystem only"
	@echo "  make rerun-configure   - Re-run configure-system only"
	@echo "  make rerun-kernel      - Re-run build-kernel only"
	@echo "  make rerun-package     - Re-run package-image only"
	@echo ""
	@echo -e "$(YELLOW)Force rebuild (ignore checkpoints):$(NC)"
	@echo "  FORCE=1 make rerun-<stage>  - Delete checkpoint and force rebuild"
	@echo "  Example: FORCE=1 make rerun-configure"
	@echo ""
	@echo -e "$(YELLOW)Web Interface (access built LFS system):$(NC)"
	@echo "  make web-terminal    - Start web terminal (http://localhost:7681)"
	@echo "  make web-screen      - Start web screen (http://localhost:6080)"
	@echo "  make web             - Start both web interfaces"
	@echo "  make web-stop        - Stop all web interfaces"
	@echo ""
	@echo -e "$(YELLOW)Publishing to GitHub (production files only):$(NC)"
	@echo "  make publish         - Publish production files to GitHub (interactive)"
	@echo "  make publish-dry-run - Show what would be published"
	@echo "  make publish-setup   - Configure GitHub remote"
	@echo ""
	@echo -e "$(YELLOW)Quick start:$(NC)"
	@echo "  make setup && make build"
	@echo ""

setup:
	@echo -e "$(YELLOW)Running setup...$(NC)"
	@./setup.sh

build: setup
	@echo -e "$(YELLOW)Starting complete build pipeline...$(NC)"
	@./build.sh

# Individual stage targets
download:
	@$(DOCKER_COMPOSE) run --rm download-sources

toolchain:
	@$(DOCKER_COMPOSE) run --rm build-toolchain

basesystem:
	@$(DOCKER_COMPOSE) run --rm build-basesystem

configure:
	@$(DOCKER_COMPOSE) run --rm configure-system

kernel:
	@$(DOCKER_COMPOSE) run --rm build-kernel

package:
	@$(DOCKER_COMPOSE) run --rm package-image

# Re-run individual stages WITHOUT dependencies (faster for testing/rebuilds)
rerun-download:
	@echo -e "$(YELLOW)Re-running download-sources (skipping dependencies)...$(NC)"
	@$(DOCKER_COMPOSE) run --rm --no-deps -e FORCE=$(FORCE) download-sources

rerun-toolchain:
	@echo -e "$(YELLOW)Re-running build-toolchain (skipping dependencies)...$(NC)"
	@$(DOCKER_COMPOSE) run --rm --no-deps -e FORCE=$(FORCE) build-toolchain

rerun-basesystem:
	@echo -e "$(YELLOW)Re-running build-basesystem (skipping dependencies)...$(NC)"
	@$(DOCKER_COMPOSE) run --rm --no-deps -e FORCE=$(FORCE) build-basesystem

rerun-configure:
	@echo -e "$(YELLOW)Re-running configure-system (skipping dependencies)...$(NC)"
	@$(DOCKER_COMPOSE) run --rm --no-deps -e FORCE=$(FORCE) configure-system

rerun-kernel:
	@echo -e "$(YELLOW)Re-running build-kernel (skipping dependencies)...$(NC)"
	@$(DOCKER_COMPOSE) run --rm --no-deps -e FORCE=$(FORCE) build-kernel

rerun-package:
	@echo -e "$(YELLOW)Re-running package-image (skipping dependencies)...$(NC)"
	@$(DOCKER_COMPOSE) run --rm --no-deps -e FORCE=$(FORCE) package-image

# Status and inspection
status:
	@echo -e "$(BLUE)=========================================$(NC)"
	@echo -e "$(BLUE)EasyLFS Build Status$(NC)"
	@echo -e "$(BLUE)=========================================$(NC)"
	@echo ""
	@echo -e "$(YELLOW)Docker Volumes:$(NC)"
	@docker volume ls | grep easylfs || echo "  No EasyLFS volumes found - run 'make setup' first"
	@echo ""
	@echo -e "$(YELLOW)Volume Sizes:$(NC)"
	@for vol in easylfs_lfs-sources easylfs_lfs-tools easylfs_lfs-rootfs easylfs_lfs-dist easylfs_lfs-logs; do \
		if docker volume inspect $$vol &> /dev/null; then \
			size=$$(docker run --rm -v $$vol:/data alpine du -sh /data 2>/dev/null | cut -f1); \
			printf "  %-20s %s\n" "$$vol:" "$$size"; \
		fi; \
	done
	@echo ""
	@echo -e "$(YELLOW)Checkpoints:$(NC)"
	@docker run --rm -v easylfs_lfs-rootfs:/lfs alpine sh -c 'if [ -d /lfs/.checkpoints ]; then ls -1 /lfs/.checkpoints 2>/dev/null | wc -l; else echo 0; fi' | xargs -I {} echo "  {} checkpoints found"
	@echo ""

logs:
	@echo -e "$(YELLOW)Available logs:$(NC)"
	@docker run --rm -v easylfs_lfs-logs:/logs alpine ls -lh /logs 2>/dev/null || echo "  No logs found"
	@echo ""
	@echo "To view a specific log:"
	@echo "  docker run --rm -v easylfs_lfs-logs:/logs alpine cat /logs/<service>.log"

inspect:
	@echo -e "$(YELLOW)Inspecting volumes...$(NC)"
	@echo ""
	@echo -e "$(BLUE)lfs-sources (downloaded packages):$(NC)"
	@docker run --rm -v easylfs_lfs-sources:/sources alpine ls -lh /sources 2>/dev/null | head -20 || echo "  Empty or not created"
	@echo ""
	@echo -e "$(BLUE)lfs-rootfs (LFS filesystem):$(NC)"
	@docker run --rm -v easylfs_lfs-rootfs:/lfs alpine ls -la /lfs 2>/dev/null || echo "  Empty or not created"
	@echo ""
	@echo -e "$(BLUE)lfs-dist (final images):$(NC)"
	@docker run --rm -v easylfs_lfs-dist:/dist alpine ls -lh /dist 2>/dev/null || echo "  Empty or not created"

test:
	@echo -e "$(YELLOW)Running validation tests...$(NC)"
	@$(DOCKER_COMPOSE) run --rm test

clean:
	@echo -e "$(YELLOW)Removing containers...$(NC)"
	@$(DOCKER_COMPOSE) down
	@echo -e "$(GREEN)Done. Volumes preserved.$(NC)"

clean-basesystem-light:
	@echo -e "$(YELLOW)Cleaning build-basesystem checkpoints & temp files...$(NC)"
	@echo "This will remove:"
	@echo "  - All checkpoints in /lfs/.checkpoints"
	@echo "  - Build logs in /lfs/tmp"
	@echo "  - Temporary build directories in /lfs/build"
	@echo ""
	@echo "Installed binaries will be preserved."
	@echo ""
	@read -p "Continue? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "Cleaning checkpoints..."; \
		docker run --rm -v easylfs_lfs-rootfs:/lfs alpine sh -c 'rm -rf /lfs/.checkpoints/*' 2>/dev/null || true; \
		echo "Cleaning temp files..."; \
		docker run --rm -v easylfs_lfs-rootfs:/lfs alpine sh -c 'rm -rf /lfs/tmp/* /lfs/build/*' 2>/dev/null || true; \
		echo -e "$(GREEN)Light clean complete.$(NC)"; \
		echo ""; \
		echo "Next: make rerun-basesystem"; \
	fi

clean-basesystem:
	@echo -e "$(YELLOW)Resetting rootfs volume (preserving sources & toolchain)...$(NC)"
	@echo "This will:"
	@echo "  - Remove the lfs-rootfs volume (build-basesystem state)"
	@echo "  - Preserve lfs-sources (downloaded packages)"
	@echo "  - Preserve lfs-tools (toolchain - 2-4 hours of work)"
	@echo ""
	@echo "You can then run: make rerun-basesystem"
	@echo ""
	@read -p "Continue? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "Stopping build-basesystem container..."; \
		docker stop easylfs-build-basesystem 2>/dev/null || true; \
		docker rm easylfs-build-basesystem 2>/dev/null || true; \
		echo "Removing lfs-rootfs volume..."; \
		docker volume rm easylfs_lfs-rootfs 2>/dev/null || echo "Volume already removed"; \
		echo "Recreating lfs-rootfs volume..."; \
		docker volume create easylfs_lfs-rootfs; \
		echo -e "$(GREEN)Rootfs volume reset complete.$(NC)"; \
		echo ""; \
		echo "Next steps:"; \
		echo "  1. Run: make rerun-toolchain  (to populate rootfs with toolchain)"; \
		echo "  2. Run: make rerun-basesystem (to build base system from scratch)"; \
	fi

clean-all:
ifndef FORCE_CLEAN
	@echo -e "$(YELLOW)WARNING: This will delete ALL build artifacts!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(MAKE) FORCE_CLEAN=1 clean-all; \
	fi
else
	@echo "Stopping and removing all containers..."
	@docker ps -a --filter "name=easylfs-" -q | xargs -r docker stop 2>/dev/null || true
	@docker ps -a --filter "name=easylfs-" -q | xargs -r docker rm 2>/dev/null || true
	@$(DOCKER_COMPOSE) down -v 2>/dev/null || true
	@echo "Removing volumes..."
	@docker volume rm easylfs_lfs-sources easylfs_lfs-tools easylfs_lfs-rootfs easylfs_lfs-dist easylfs_lfs-logs 2>/dev/null || true
	@echo -e "$(GREEN)Complete reset done.$(NC)"
endif

# Export final image to current directory
export:
	@echo -e "$(YELLOW)Exporting disk image to current directory...$(NC)"
	@docker run --rm -v easylfs_lfs-dist:/dist -v $(PWD):/output alpine cp /dist/lfs-12.4-sysv.img /output/ 2>/dev/null || echo -e "$(RED)No image found. Run 'make build' first.$(NC)"
	@if [ -f lfs-12.4-sysv.img ]; then \
		echo -e "$(GREEN)Image exported: lfs-12.4-sysv.img$(NC)"; \
		ls -lh lfs-12.4-sysv.img; \
	fi

# Web interface targets
web-terminal:
	@echo -e "$(YELLOW)Starting web terminal interface...$(NC)"
	@echo "Access at: http://localhost:${WEB_TERMINAL_PORT:-7681}"
	@$(DOCKER_COMPOSE) up -d lfs-web-terminal
	@echo -e "$(GREEN)Web terminal started!$(NC)"
	@echo "View logs: docker compose logs -f lfs-web-terminal"

web-screen:
	@echo -e "$(YELLOW)Starting web screen interface...$(NC)"
	@echo "Access at: http://localhost:${WEB_SCREEN_PORT:-6080}/vnc.html"
	@$(DOCKER_COMPOSE) up -d lfs-web-screen
	@echo -e "$(GREEN)Web screen started!$(NC)"
	@echo "View logs: docker compose logs -f lfs-web-screen"

web:
	@echo -e "$(YELLOW)Starting both web interfaces...$(NC)"
	@$(DOCKER_COMPOSE) up -d lfs-web-terminal lfs-web-screen
	@echo ""
	@echo -e "$(GREEN)Web interfaces started!$(NC)"
	@echo ""
	@echo "Terminal: http://localhost:${WEB_TERMINAL_PORT:-7681}"
	@echo "Screen:   http://localhost:${WEB_SCREEN_PORT:-6080}/vnc.html"
	@echo ""
	@echo "View logs:"
	@echo "  docker compose logs -f lfs-web-terminal"
	@echo "  docker compose logs -f lfs-web-screen"

web-stop:
	@echo -e "$(YELLOW)Stopping web interfaces...$(NC)"
	@$(DOCKER_COMPOSE) stop lfs-web-terminal lfs-web-screen
	@$(DOCKER_COMPOSE) rm -f lfs-web-terminal lfs-web-screen
	@echo -e "$(GREEN)Web interfaces stopped.$(NC)"

# ==============================================================================
# Publishing to GitHub (production files only)
# ==============================================================================

publish:
	@echo -e "$(YELLOW)Publishing production files to GitHub...$(NC)"
	@./publish.sh

publish-dry-run:
	@echo -e "$(YELLOW)Dry run: showing what would be published...$(NC)"
	@./publish.sh --dry-run

publish-setup:
	@echo -e "$(YELLOW)Setting up GitHub remote...$(NC)"
	@./publish.sh --setup

# Default target
.DEFAULT_GOAL := help

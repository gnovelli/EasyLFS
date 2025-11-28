#!/bin/bash
# =============================================================================
# EasyLFS Common Checkpointing Utility
# Provides granular, hash-based checkpoint tracking for idempotent builds
# =============================================================================

# Checkpoint directory (inside LFS volume for persistence)
CHECKPOINT_DIR="${LFS:-/lfs}/.checkpoints"
CHECKPOINT_VERSION="1.0"

# Initialize checkpoint system
init_checkpointing() {
    mkdir -p "$CHECKPOINT_DIR"

    # Create metadata file if it doesn't exist
    if [ ! -f "$CHECKPOINT_DIR/metadata.txt" ]; then
        {
            echo "EasyLFS Checkpoint Metadata"
            echo "Version: $CHECKPOINT_VERSION"
            echo "Created: $(date '+%Y-%m-%d %H:%M:%S %Z')"
        } > "$CHECKPOINT_DIR/metadata.txt"
    fi
}

# Calculate source hash for a package
# Usage: get_source_hash "binutils" "/sources"
get_source_hash() {
    local package_name="$1"
    local sources_dir="${2:-/sources}"

    # Find tarball matching pattern (handles version numbers)
    local tarball=$(find "$sources_dir" -maxdepth 1 -name "${package_name}-*.tar.*" -o -name "${package_name}-*.tgz" 2>/dev/null | head -1)

    if [ -z "$tarball" ]; then
        echo "NOTFOUND"
        return 1
    fi

    # Calculate MD5 hash
    md5sum "$tarball" 2>/dev/null | cut -d' ' -f1
}

# Check if a package checkpoint exists and is valid
# Usage: is_checkpoint_valid "binutils" "/sources"
# Returns: 0 if valid, 1 if invalid/missing
is_checkpoint_valid() {
    local package_name="$1"
    local sources_dir="${2:-/sources}"
    local checkpoint_file="$CHECKPOINT_DIR/${package_name}.checkpoint"

    # Check if checkpoint file exists
    [ -f "$checkpoint_file" ] || return 1

    # Extract saved hash
    local saved_hash=$(grep "^SOURCE_HASH=" "$checkpoint_file" | cut -d'=' -f2)

    # Calculate current source hash
    local current_hash=$(get_source_hash "$package_name" "$sources_dir")

    # Compare hashes
    if [ "$current_hash" = "NOTFOUND" ]; then
        return 1  # Source file missing
    fi

    [ "$saved_hash" = "$current_hash" ]
}

# Create a checkpoint for a completed package
# Usage: create_checkpoint "binutils" "/sources" "pass1"
create_checkpoint() {
    local package_name="$1"
    local sources_dir="${2:-/sources}"
    local build_stage="${3:-default}"
    local checkpoint_file="$CHECKPOINT_DIR/${package_name}.checkpoint"

    # Calculate source hash
    local source_hash=$(get_source_hash "$package_name" "$sources_dir")

    # Create checkpoint file with metadata
    {
        echo "PACKAGE=$package_name"
        echo "BUILD_STAGE=$build_stage"
        echo "SOURCE_HASH=$source_hash"
        echo "TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo "EPOCH=$(date +%s)"
        echo "SERVICE_NAME=${SERVICE_NAME:-unknown}"
        echo "LFS_TGT=${LFS_TGT:-unknown}"
        echo "CHECKPOINT_VERSION=$CHECKPOINT_VERSION"
    } > "$checkpoint_file"

    # Log checkpoint creation if logging is available
    if command -v log_info &>/dev/null; then
        log_info "✓ Checkpoint created: $package_name (stage: $build_stage)"
    fi
}

# Remove a checkpoint (force rebuild)
# Usage: remove_checkpoint "binutils"
remove_checkpoint() {
    local package_name="$1"
    local checkpoint_file="$CHECKPOINT_DIR/${package_name}.checkpoint"

    if [ -f "$checkpoint_file" ]; then
        rm -f "$checkpoint_file"
        if command -v log_info &>/dev/null; then
            log_info "Checkpoint removed: $package_name"
        fi
    fi
}

# Clear all checkpoints (nuclear option)
# Usage: clear_all_checkpoints [--confirm]
clear_all_checkpoints() {
    if [ "$1" = "--confirm" ]; then
        rm -rf "$CHECKPOINT_DIR"
        mkdir -p "$CHECKPOINT_DIR"
        init_checkpointing
        if command -v log_warn &>/dev/null; then
            log_warn "All checkpoints cleared"
        fi
    else
        echo "ERROR: Must pass --confirm flag to clear all checkpoints"
        return 1
    fi
}

# List all checkpoints with status
# Usage: list_checkpoints ["/sources"]
list_checkpoints() {
    local sources_dir="${1:-/sources}"

    echo "=========================================="
    echo "EasyLFS Checkpoints"
    echo "=========================================="

    if [ ! -d "$CHECKPOINT_DIR" ] || [ -z "$(ls -A $CHECKPOINT_DIR/*.checkpoint 2>/dev/null)" ]; then
        echo "No checkpoints found."
        return 0
    fi

    local total=0
    local valid=0
    local invalid=0

    for checkpoint in "$CHECKPOINT_DIR"/*.checkpoint; do
        [ -f "$checkpoint" ] || continue

        total=$((total + 1))
        local package=$(grep "^PACKAGE=" "$checkpoint" | cut -d'=' -f2)
        local stage=$(grep "^BUILD_STAGE=" "$checkpoint" | cut -d'=' -f2)
        local timestamp=$(grep "^TIMESTAMP=" "$checkpoint" | cut -d'=' -f2)

        if is_checkpoint_valid "$package" "$sources_dir"; then
            echo "✓ $package (stage: $stage) - $timestamp"
            valid=$((valid + 1))
        else
            echo "✗ $package (stage: $stage) - INVALID (source changed)"
            invalid=$((invalid + 1))
        fi
    done

    echo "=========================================="
    echo "Total: $total | Valid: $valid | Invalid: $invalid"
    echo "=========================================="
}

# Get checkpoint info for a package
# Usage: get_checkpoint_info "binutils"
get_checkpoint_info() {
    local package_name="$1"
    local checkpoint_file="$CHECKPOINT_DIR/${package_name}.checkpoint"

    if [ ! -f "$checkpoint_file" ]; then
        echo "No checkpoint found for: $package_name"
        return 1
    fi

    echo "Checkpoint: $package_name"
    cat "$checkpoint_file" | sed 's/^/  /'
}

# Check if package should be skipped (has valid checkpoint)
# This is the main function services should call
# Usage: should_skip_package "binutils" "/sources"
# Set FORCE=1 environment variable to ignore and delete checkpoint
should_skip_package() {
    local package_name="$1"
    local sources_dir="${2:-/sources}"
    local checkpoint_file="$CHECKPOINT_DIR/${package_name}.checkpoint"

    # Check if FORCE flag is set
    if [ "${FORCE:-0}" = "1" ]; then
        if [ -f "$checkpoint_file" ]; then
            if command -v log_warn &>/dev/null; then
                log_warn "⚠ FORCE mode: Deleting checkpoint for $package_name"
            else
                echo "[FORCE] Deleting checkpoint for $package_name"
            fi
            rm -f "$checkpoint_file"
        fi
        return 1  # Do not skip (force re-run)
    fi

    if is_checkpoint_valid "$package_name" "$sources_dir"; then
        if command -v log_info &>/dev/null; then
            log_info "⊙ Skipping $package_name (already built, checkpoint valid)"
        else
            echo "[SKIP] $package_name (checkpoint valid)"
        fi
        return 0  # Should skip (0 = true in bash)
    else
        return 1  # Should not skip (1 = false in bash)
    fi
}

# Check if a global checkpoint exists (no source validation)
# Use this for service-level checkpoints where there's no source tarball
# Usage: should_skip_global_checkpoint "service-name"
# Set FORCE=1 environment variable to ignore and delete checkpoint
should_skip_global_checkpoint() {
    local checkpoint_name="$1"
    local checkpoint_file="$CHECKPOINT_DIR/${checkpoint_name}.checkpoint"

    # Check if FORCE flag is set
    if [ "${FORCE:-0}" = "1" ]; then
        if [ -f "$checkpoint_file" ]; then
            if command -v log_warn &>/dev/null; then
                log_warn "⚠ FORCE mode: Deleting checkpoint for $checkpoint_name"
            else
                echo "[FORCE] Deleting checkpoint for $checkpoint_name"
            fi
            rm -f "$checkpoint_file"
        fi
        return 1  # Do not skip (force re-run)
    fi

    if [ -f "$checkpoint_file" ]; then
        if command -v log_info &>/dev/null; then
            log_info "⊙ Skipping $checkpoint_name (checkpoint exists)"
        else
            echo "[SKIP] $checkpoint_name (checkpoint exists)"
        fi
        return 0  # Should skip
    else
        return 1  # Should not skip
    fi
}

# Create a global checkpoint (no source hash validation)
# Use this for service-level checkpoints
# Usage: create_global_checkpoint "service-name" "stage-name" "custom-hash"
create_global_checkpoint() {
    local checkpoint_name="$1"
    local build_stage="${2:-default}"
    local custom_hash="${3:-none}"
    local checkpoint_file="$CHECKPOINT_DIR/${checkpoint_name}.checkpoint"

    # Ensure checkpoint directory exists
    mkdir -p "$CHECKPOINT_DIR"

    # Create checkpoint file with metadata
    {
        echo "PACKAGE=$checkpoint_name"
        echo "BUILD_STAGE=$build_stage"
        echo "SOURCE_HASH=$custom_hash"
        echo "TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo "EPOCH=$(date +%s)"
        echo "SERVICE_NAME=${SERVICE_NAME:-unknown}"
        echo "CHECKPOINT_VERSION=$CHECKPOINT_VERSION"
        echo "CHECKPOINT_TYPE=global"
    } > "$checkpoint_file"

    # Log checkpoint creation if logging is available
    if command -v log_info &>/dev/null; then
        log_info "✓ Global checkpoint created: $checkpoint_name"
    fi
}

# Wrapper for build functions with automatic checkpointing
# Usage: build_with_checkpoint "binutils" "pass1" build_binutils_pass1_function
build_with_checkpoint() {
    local package_name="$1"
    local build_stage="$2"
    local build_function="$3"
    local sources_dir="${4:-/sources}"

    # Check if we should skip
    if should_skip_package "$package_name" "$sources_dir"; then
        return 0
    fi

    # Run the build function
    if command -v log_step &>/dev/null; then
        log_step "Building $package_name (stage: $build_stage)..."
    fi

    if $build_function; then
        # Build succeeded, create checkpoint
        create_checkpoint "$package_name" "$sources_dir" "$build_stage"
        return 0
    else
        # Build failed, do not create checkpoint
        if command -v log_error &>/dev/null; then
            log_error "Build failed for $package_name - no checkpoint created"
        fi
        return 1
    fi
}

# Export functions for use in other scripts
export -f init_checkpointing
export -f get_source_hash
export -f is_checkpoint_valid
export -f create_checkpoint
export -f remove_checkpoint
export -f clear_all_checkpoints
export -f list_checkpoints
export -f get_checkpoint_info
export -f should_skip_package
export -f should_skip_global_checkpoint
export -f create_global_checkpoint
export -f build_with_checkpoint

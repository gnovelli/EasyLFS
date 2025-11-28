#!/bin/bash
set -euo pipefail

# =============================================================================
# EasyLFS Download Sources Script
# Downloads all LFS packages and patches for LFS 12.4 (SysVinit)
# =============================================================================

# Load common utilities
COMMON_DIR="/usr/local/lib/easylfs-common"
if [ -d "$COMMON_DIR" ]; then
    source "$COMMON_DIR/logging.sh"
    source "$COMMON_DIR/checkpointing.sh"
else
    # Fallback for development/local testing
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/../../common/logging.sh"
    source "$SCRIPT_DIR/../../common/checkpointing.sh"
fi

# Configuration
LFS_VERSION="${LFS_VERSION:-12.4}"
LFS_MIRROR="${LFS_MIRROR:-https://www.linuxfromscratch.org}"
SOURCES_DIR="/sources"
MAX_RETRIES=3
RETRY_DELAY=5
PARALLEL_DOWNLOADS="${PARALLEL_DOWNLOADS:-6}"  # Number of parallel downloads
DOWNLOAD_TIMEOUT=60  # Timeout for slow connections (seconds)
MIN_SPEED=50000     # Minimum speed: 50KB/s (will retry if slower)

# Note: LFS for download-sources points to /sources since we don't have /lfs yet
export LFS="${LFS:-/lfs}"

# Setup logging trap to ensure finalize_logging is called
trap 'finalize_logging $?' EXIT

# Download with retry and speed monitoring
download_with_retry() {
    local url="$1"
    local output="$2"
    local attempt=1

    while [ $attempt -le $MAX_RETRIES ]; do
        log_info "Downloading $output (attempt $attempt/$MAX_RETRIES)..."

        # Use wget with aggressive timeouts and resume support
        # --read-timeout: abort if no data received for 30 seconds
        # --dns-timeout: DNS lookup timeout
        # --continue: resume partial downloads
        if wget --continue \
                --progress=dot:giga \
                --timeout=$DOWNLOAD_TIMEOUT \
                --read-timeout=30 \
                --dns-timeout=20 \
                --tries=2 \
                -O "$output" \
                "$url"; then
            return 0
        fi

        log_warn "Download failed, retrying in $RETRY_DELAY seconds..."
        sleep $RETRY_DELAY
        ((attempt++))
    done

    log_error "Failed to download $url after $MAX_RETRIES attempts"
    return 1
}

# Download a single package (used by parallel jobs)
download_package() {
    local url="$1"
    local filename=$(basename "$url")
    local sources_dir="$2"

    cd "$sources_dir"

    # Optimize URL: use geographic mirror redirector for GNU FTP
    # ftpmirror.gnu.org redirects to closest mirror automatically
    url="${url//ftp.gnu.org/ftpmirror.gnu.org}"

    # Check if file already exists and is valid
    if [ -f "$filename" ]; then
        # Extract expected checksum for THIS file only (not all files)
        expected_checksum=$(grep " $filename\$" md5sums 2>/dev/null | cut -d' ' -f1)
        if [ -n "$expected_checksum" ]; then
            actual_checksum=$(md5sum "$filename" 2>/dev/null | cut -d' ' -f1)
            if [ "$expected_checksum" = "$actual_checksum" ]; then
                echo "[SKIP] $filename (already verified)"
                return 0
            fi
        fi
        # File exists but is invalid or has no expected checksum - remove and re-download
        rm -f "$filename"
    fi

    # Download the package
    if download_with_retry "$url" "$filename"; then
        echo "[OK] $filename"
        return 0
    else
        echo "[FAIL] $filename"
        return 1
    fi
}

# Main function
main() {
    # Initialize logging
    init_logging

    log_info "Starting LFS $LFS_VERSION sources download"
    log_info "Target directory: $SOURCES_DIR"

    # Create sources directory if it doesn't exist
    mkdir -p "$SOURCES_DIR"
    cd "$SOURCES_DIR"

    # Initialize checkpoint system (use SOURCES_DIR as LFS root for this service)
    export CHECKPOINT_DIR="$SOURCES_DIR/.checkpoints"
    init_checkpointing

    # Check if download was already completed successfully
    if should_skip_global_checkpoint "download-complete"; then
        log_info "========================================="
        log_info "All sources already downloaded and verified"
        log_info "========================================="
        exit 0
    fi

    # Download wget-list
    log_info "Downloading package list..."
    local wget_list_url="${LFS_MIRROR}/lfs/downloads/${LFS_VERSION}/wget-list"

    if ! download_with_retry "$wget_list_url" "wget-list"; then
        log_error "Failed to download wget-list"
        exit 1
    fi

    # Download md5sums
    log_info "Downloading MD5 checksums..."
    local md5sums_url="${LFS_MIRROR}/lfs/downloads/${LFS_VERSION}/md5sums"

    if ! download_with_retry "$md5sums_url" "md5sums"; then
        log_error "Failed to download md5sums"
        exit 1
    fi

    # Count total packages
    local total_packages=$(grep -v '^[[:space:]]*#' wget-list | grep -v '^[[:space:]]*$' | wc -l)
    log_info "Found $total_packages packages to download"
    log_info "Using $PARALLEL_DOWNLOADS parallel downloads"
    log_info "Using ftpmirror.gnu.org for automatic geographic mirror selection"

    # Export functions for parallel execution
    export -f download_with_retry
    export -f download_package
    export -f log_info
    export -f log_warn
    export -f log_error
    export SOURCES_DIR MAX_RETRIES RETRY_DELAY DOWNLOAD_TIMEOUT MIN_SPEED
    export RED GREEN YELLOW NC

    # Download all packages in parallel
    echo ""
    log_info "Starting parallel downloads..."

    # Filter out comments and empty lines, then download in parallel
    if command -v parallel >/dev/null 2>&1; then
        # Use GNU parallel if available (better progress tracking)
        log_info "Using GNU parallel for downloads"
        grep -v '^[[:space:]]*#' wget-list | grep -v '^[[:space:]]*$' | \
            parallel -j "$PARALLEL_DOWNLOADS" --line-buffer --tag \
                download_package {} "$SOURCES_DIR"
    else
        # Fallback to xargs -P
        log_info "Using xargs for parallel downloads"
        grep -v '^[[:space:]]*#' wget-list | grep -v '^[[:space:]]*$' | \
            xargs -P "$PARALLEL_DOWNLOADS" -I {} bash -c 'download_package "$@"' _ {} "$SOURCES_DIR"
    fi

    echo ""
    log_info "Download phase completed"
    log_info "Total packages: $total_packages"

    # Verify checksums
    log_info "Verifying MD5 checksums..."

    if md5sum -c md5sums 2>&1 | tee checksum-verify.log; then
        log_info "All checksums verified successfully!"
    else
        log_error "Some checksums failed verification!"
        log_error "Check checksum-verify.log for details"
        exit 1
    fi

    # Summary
    # Count all downloaded files (tarballs and patches)
    local downloaded_files=$(ls -1 *.tar.* *.tgz *.patch 2>/dev/null | wc -l)
    local total_size=$(du -sh . | cut -f1)

    echo ""
    log_info "========================================="
    log_info "Download Summary"
    log_info "========================================="
    log_info "LFS Version: $LFS_VERSION"
    log_info "Files downloaded: $downloaded_files/$total_packages"
    log_info "Total size: $total_size"
    log_info "Checksum verification: PASSED"
    log_info "========================================="

    # Check if all files were downloaded
    if [ "$downloaded_files" -lt "$total_packages" ]; then
        local missing=$((total_packages - downloaded_files))
        log_warn "Warning: $missing packages failed to download"
        exit 1
    fi

    log_info "All sources downloaded successfully!"

    # Create a global checkpoint using md5sums file hash
    # This ensures if the LFS version changes, downloads will re-run
    local md5sums_hash=$(md5sum md5sums | cut -d' ' -f1)
    create_global_checkpoint "download-complete" "download" "$md5sums_hash"

    exit 0
}

# Run main function
main "$@"

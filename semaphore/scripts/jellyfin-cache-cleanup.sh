#!/bin/bash

# Jellyfin Cache Cleanup Script
# Manages transcoding cache to prevent disk space issues

CACHE_DIR="/media/servarr/jellyfin/config/cache/transcodes"
MAX_CACHE_SIZE_GB=5
LOG_FILE="/var/log/jellyfin-cache-cleanup.log"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Check if cache directory exists
if [ ! -d "$CACHE_DIR" ]; then
    log_message "Cache directory $CACHE_DIR does not exist"
    exit 1
fi

# Get current cache size in GB
current_size_bytes=$(du -sb "$CACHE_DIR" 2>/dev/null | cut -f1)
current_size_gb=$((current_size_bytes / 1024 / 1024 / 1024))

log_message "Current cache size: ${current_size_gb}GB"

# If cache exceeds limit, clean old files
if [ "$current_size_gb" -gt "$MAX_CACHE_SIZE_GB" ]; then
    log_message "Cache size (${current_size_gb}GB) exceeds limit (${MAX_CACHE_SIZE_GB}GB). Cleaning old files..."
    
    # Remove files older than 7 days first
    find "$CACHE_DIR" -name "*.mp4" -mtime +7 -type f -delete 2>/dev/null
    
    # If still over limit, remove files older than 3 days
    current_size_bytes=$(du -sb "$CACHE_DIR" 2>/dev/null | cut -f1)
    current_size_gb=$((current_size_bytes / 1024 / 1024 / 1024))
    
    if [ "$current_size_gb" -gt "$MAX_CACHE_SIZE_GB" ]; then
        log_message "Still over limit. Removing files older than 3 days..."
        find "$CACHE_DIR" -name "*.mp4" -mtime +3 -type f -delete 2>/dev/null
    fi
    
    # If still over limit, remove files older than 1 day
    current_size_bytes=$(du -sb "$CACHE_DIR" 2>/dev/null | cut -f1)
    current_size_gb=$((current_size_bytes / 1024 / 1024 / 1024))
    
    if [ "$current_size_gb" -gt "$MAX_CACHE_SIZE_GB" ]; then
        log_message "Still over limit. Removing files older than 1 day..."
        find "$CACHE_DIR" -name "*.mp4" -mtime +1 -type f -delete 2>/dev/null
    fi
    
    # Final check
    final_size_bytes=$(du -sb "$CACHE_DIR" 2>/dev/null | cut -f1)
    final_size_gb=$((final_size_bytes / 1024 / 1024 / 1024))
    
    log_message "Cleanup complete. New cache size: ${final_size_gb}GB"
else
    log_message "Cache size within limits. No cleanup needed."
fi

# Show current disk usage
df_output=$(df -h / | tail -1)
log_message "Current disk usage: $df_output"

#!/bin/bash
# ============================================================
# Automated Backup & Cleanup System
# Author: Muhammad Hanzalah | DUET 23-AI-31
# Usage: sudo bash cleanup.sh
# ============================================================

# ─── CONFIG ─────────────────────────────────────────────────
PROJECT_DIR="/project"
BACKUP_BASE="/backup"
DATE=$(date +%Y-%m-%d)
BACKUP_DIR="$BACKUP_BASE/backup_$DATE"
LOG_FILE="$BACKUP_BASE/cleanup.log"
REPORT_FILE="$BACKUP_BASE/report.txt"
MIN_FREE_SPACE_MB=500          # Abort backup if /backup has less than this free

# ─── COUNTERS ───────────────────────────────────────────────
moved_count=0
deleted_count=0
space_cleared=0
perm_errors=()

# ─── HELPERS ────────────────────────────────────────────────
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_space() {
    local required_mb=$1
    local avail_mb
    avail_mb=$(df -m "$BACKUP_BASE" | awk 'NR==2 {print $4}')
    if [ "$avail_mb" -lt "$required_mb" ]; then
        log "ERROR: Not enough space in $BACKUP_BASE (${avail_mb}MB free, need ${required_mb}MB). Aborting."
        exit 1
    fi
}

# ─── INIT ───────────────────────────────────────────────────
mkdir -p "$BACKUP_DIR"
mkdir -p "$BACKUP_BASE"
log "===== Cleanup started ====="
log "PROJECT=$PROJECT_DIR  BACKUP=$BACKUP_DIR"

# ─── SPACE CHECK before doing anything ──────────────────────
check_space $MIN_FREE_SPACE_MB

# ─── STEP 1: Move files older than 30 days (excl. .tmp) ─────
log "--- Phase 1: Moving files older than 30 days ---"

while IFS= read -r -d '' file; do
    # Skip .tmp files (handled separately)
    [[ "$file" == *.tmp ]] && continue

    # Build destination path preserving subdirectory structure
    rel_path="${file#$PROJECT_DIR/}"
    dest="$BACKUP_DIR/$rel_path"
    dest_dir=$(dirname "$dest")

    # Permission check
    if [ ! -r "$file" ]; then
        log "PERMISSION ERROR: Cannot read $file"
        perm_errors+=("$file")
        continue
    fi

    # Name conflict resolution: append timestamp if file already exists
    if [ -e "$dest" ]; then
        ts=$(date +%s)
        dest="${dest%.}_conflict_$ts"
        log "CONFLICT: Renamed to $(basename "$dest")"
    fi

    # Pre-check space again (rough: file size in MB)
    file_size_mb=$(du -m "$file" | cut -f1)
    check_space $((file_size_mb + 50))   # +50MB buffer

    mkdir -p "$dest_dir"

    if mv "$file" "$dest" 2>/dev/null; then
        log "MOVED: $file → $dest"
        ((moved_count++))
        ((space_cleared += file_size_mb))
    else
        log "PERMISSION ERROR: Could not move $file (owned by $(stat -c '%U' "$file"))"
        perm_errors+=("$file")
    fi

done < <(find "$PROJECT_DIR" -type f -mtime +30 -print0)

# ─── STEP 2: Delete .tmp files older than 7 days ────────────
log "--- Phase 2: Deleting .tmp files older than 7 days ---"

while IFS= read -r -d '' file; do
    if [ ! -w "$file" ]; then
        log "PERMISSION ERROR: Cannot delete $file"
        perm_errors+=("$file")
        continue
    fi

    file_size_mb=$(du -m "$file" | cut -f1)

    if rm "$file" 2>/dev/null; then
        log "DELETED: $file"
        ((deleted_count++))
        ((space_cleared += file_size_mb))
    else
        log "PERMISSION ERROR: rm failed on $file"
        perm_errors+=("$file")
    fi

done < <(find "$PROJECT_DIR" -type f -name "*.tmp" -mtime +7 -print0)

# ─── STEP 3: Generate report.txt ────────────────────────────
log "--- Phase 3: Writing report ---"

{
    echo "========================================"
    echo "  CLEANUP REPORT — $DATE"
    echo "========================================"
    echo ""
    echo "Files Moved to Backup : $moved_count"
    echo "Files Deleted (.tmp)  : $deleted_count"
    echo "Total Space Cleared   : ~${space_cleared} MB"QS
    echo ""
    echo "--- Permission Errors (${#perm_errors[@]}) ---"
    if [ ${#perm_errors[@]} -eq 0 ]; then
        echo "None"
    else
        for e in "${perm_errors[@]}"; do
            echo "  [ERROR] $e"
        done
    fi
    echo ""
    echo "Backup location: $BACKUP_DIR"
    echo "Full log: $LOG_FILE"
    echo "========================================"
} > "$REPORT_FILE"

log "Report written to $REPORT_FILE"
log "===== Cleanup complete: Moved=$moved_count Deleted=$deleted_count Space=~${space_cleared}MB Errors=${#perm_errors[@]} ====="
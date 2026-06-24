#!/bin/bash
# =============================================================
# restore.sh — S3 Restore Script
# Downloads and extracts a backup from S3
# =============================================================
# Usage:
#   ./restore.sh                         → restore latest
#   ./restore.sh 20240615_120000         → restore specific backup
#   ./restore.sh 20240615_120000 config  → restore only config
# =============================================================

set -euo pipefail

BUCKET="s3://my-backup-bucket"
PREFIX="backups"
RESTORE_DIR="./restored"
LOG_FILE="./logs/restore.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

mkdir -p logs "$RESTORE_DIR"

# ── Step 1: Resolve which backup to restore ────────────────────
if [ -z "${1:-}" ]; then
    log "No backup ID given — finding latest..."
    BACKUP_ID=$(aws s3 ls "${BUCKET}/${PREFIX}/" \
        | awk '{print $2}' \
        | tr -d '/' \
        | sort \
        | tail -1)
    log "Latest backup: $BACKUP_ID"
else
    BACKUP_ID="$1"
    log "Restoring specific backup: $BACKUP_ID"
fi

FILTER="${2:-all}"   # "app", "config", or "all"

log "=============================="
log "Restore started  id=$BACKUP_ID"
log "=============================="

S3_PATH="${BUCKET}/${PREFIX}/${BACKUP_ID}"
LOCAL_TMP="/tmp/restore_${BACKUP_ID}"
mkdir -p "$LOCAL_TMP"

# ── Step 2: Download archives from S3 ─────────────────────────
download_and_extract() {
    local TYPE="$1"   # "app" or "config"
    local ARCHIVE="${TYPE}_${BACKUP_ID}.tar.gz"
    local DEST="${RESTORE_DIR}/${BACKUP_ID}/${TYPE}"

    log "Downloading ${TYPE} archive..."
    aws s3 cp "${S3_PATH}/${ARCHIVE}" "${LOCAL_TMP}/${ARCHIVE}"
    log "Download complete: ${ARCHIVE}"

    mkdir -p "$DEST"

    log "Extracting to ${DEST}..."
    tar -xzf "${LOCAL_TMP}/${ARCHIVE}" -C "$DEST"
    log "Extracted ${TYPE} files:"
    find "$DEST" -type f | sed 's/^/    ✓ /'
}

if [ "$FILTER" = "all" ] || [ "$FILTER" = "app" ]; then
    download_and_extract "app"
fi

if [ "$FILTER" = "all" ] || [ "$FILTER" = "config" ]; then
    download_and_extract "config"
fi

# ── Step 3: Cleanup temp ──────────────────────────────────────
rm -rf "$LOCAL_TMP"

log "=============================="
log "Restore complete → ${RESTORE_DIR}/${BACKUP_ID}/"
log "=============================="

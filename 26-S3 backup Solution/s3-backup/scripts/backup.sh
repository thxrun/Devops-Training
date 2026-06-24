#!/bin/bash
# =============================================================
# backup.sh — S3 Backup Script
# Backs up app/ and config/ directories to AWS S3
# =============================================================

set -euo pipefail   # exit on error, undefined var, pipe failure

# ── Config (override via environment or edit here) ────────────
BUCKET="s3://my-backup-bucket"
PREFIX="backups"
APP_DIR="./app"
CONFIG_DIR="./config"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="./logs/backup.log"

# ── Logging helper ─────────────────────────────────────────────
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

mkdir -p logs

log "=============================="
log "Backup started  id=$TIMESTAMP"
log "=============================="

# ── Step 1: Archive app files ──────────────────────────────────
log "Archiving app files..."
tar -czf "/tmp/app_${TIMESTAMP}.tar.gz" -C "$APP_DIR" .
log "Created: /tmp/app_${TIMESTAMP}.tar.gz"

# ── Step 2: Archive config files ──────────────────────────────
log "Archiving config files..."
tar -czf "/tmp/config_${TIMESTAMP}.tar.gz" -C "$CONFIG_DIR" .
log "Created: /tmp/config_${TIMESTAMP}.tar.gz"

# ── Step 3: Upload to S3 ───────────────────────────────────────
log "Uploading to S3..."

aws s3 cp "/tmp/app_${TIMESTAMP}.tar.gz" \
    "${BUCKET}/${PREFIX}/${TIMESTAMP}/app_${TIMESTAMP}.tar.gz" \
    --storage-class STANDARD_IA

aws s3 cp "/tmp/config_${TIMESTAMP}.tar.gz" \
    "${BUCKET}/${PREFIX}/${TIMESTAMP}/config_${TIMESTAMP}.tar.gz" \
    --storage-class STANDARD_IA

log "Uploaded to ${BUCKET}/${PREFIX}/${TIMESTAMP}/"

# ── Step 4: Cleanup temp files ─────────────────────────────────
rm -f "/tmp/app_${TIMESTAMP}.tar.gz" "/tmp/config_${TIMESTAMP}.tar.gz"
log "Temp files cleaned up"

log "Backup complete. id=$TIMESTAMP"

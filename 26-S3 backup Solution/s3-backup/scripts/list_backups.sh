#!/bin/bash
# list_backups.sh — Show all available backups in S3

BUCKET="s3://my-backup-bucket"
PREFIX="backups"

echo ""
echo "Available backups in ${BUCKET}/${PREFIX}/"
echo "─────────────────────────────────────────"
aws s3 ls "${BUCKET}/${PREFIX}/" | awk '{print "  " $2}' | tr -d '/'
echo ""
echo "To restore: ./scripts/restore.sh <BACKUP_ID>"

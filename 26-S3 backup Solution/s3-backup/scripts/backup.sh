#!/bin/bash

BUCKET="s3://tharun-s3-backup-2026"

aws s3 cp app/ "$BUCKET/app/" --recursive

echo "Backup completed."
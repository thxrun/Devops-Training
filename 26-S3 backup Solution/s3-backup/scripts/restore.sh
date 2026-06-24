#!/bin/bash

BUCKET="s3://tharun-s3-backup-2026"

aws s3 cp "$BUCKET/app/" app/ --recursive

echo "Restore completed."
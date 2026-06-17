# Exercise 26 — S3 Backup Solution

---

## What This Exercise Is Really About

As a DevOps engineer, backup is not about writing code — it's about answering these questions:

- **Where** do I store backups? (off-server, durable, accessible)
- **What** do I back up? (app files, configs — not logs, not temp)
- **How often?** (depends on RPO — Recovery Point Objective)
- **How long do I keep them?** (retention policy)
- **Can I actually restore?** (the only metric that matters)

S3 is the industry-standard answer to "where" — because it gives you 11 nines (99.999999999%) durability, versioning, lifecycle policies, and cross-region replication out of the box.

---

## Project Structure

```
s3-backup/
├── app/                   ← what we're backing up (application files)
│   └── app.py
├── config/                ← what we're backing up (config files)
│   └── nginx.conf
├── scripts/
│   ├── backup.sh          ← main backup script ⭐
│   ├── restore.sh         ← restore script ⭐
│   └── list_backups.sh    ← utility to see what's in S3
├── logs/                  ← auto-created; backup.log, restore.log
└── restored/              ← auto-created; restored files land here
```

---

## Prerequisites

### 1. AWS CLI installed and configured

```bash
# Install (Amazon Linux / RHEL)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip awscliv2.zip && sudo ./aws/install

# Configure
aws configure
# Prompts: AWS Access Key ID, Secret, Region, output format
```

> **In production:** Never use `aws configure` on a server. Attach an IAM Role to your EC2 instance instead. The AWS CLI automatically picks up role credentials — no keys needed.

### 2. IAM Permissions required

Your IAM user or role needs these S3 permissions on your bucket:

```json
{
  "Effect": "Allow",
  "Action": [
    "s3:PutObject",
    "s3:GetObject",
    "s3:ListBucket",
    "s3:DeleteObject"
  ],
  "Resource": [
    "arn:aws:s3:::my-backup-bucket",
    "arn:aws:s3:::my-backup-bucket/*"
  ]
}
```

> Give only what's needed — **least privilege**. The backup user doesn't need `s3:CreateBucket` or any EC2/RDS permissions.

---

## Step 1 — Create the S3 Bucket (One-Time Setup)

```bash
# Create bucket
aws s3 mb s3://my-backup-bucket --region us-east-1

# Enable versioning — lets you recover overwritten objects
aws s3api put-bucket-versioning \
    --bucket my-backup-bucket \
    --versioning-configuration Status=Enabled

# Block all public access — backups must never be public
aws s3api put-public-access-block \
    --bucket my-backup-bucket \
    --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Enable server-side encryption (AES-256 at rest)
aws s3api put-bucket-encryption \
    --bucket my-backup-bucket \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}
        }]
    }'
```

**Why each setting matters:**

| Setting | Why it's non-negotiable |
|---|---|
| Versioning | If backup.sh runs and overwrites yesterday's backup, you can still recover it |
| Block public access | Backup files contain configs, env vars — they must be private |
| Encryption at rest | If AWS storage is ever physically compromised, files are unreadable |

---

## Step 2 — Set Up Lifecycle Policy (Retention)

A lifecycle policy automatically deletes old backups. Without it, your bucket grows forever and costs money.

```bash
aws s3api put-bucket-lifecycle-configuration \
    --bucket my-backup-bucket \
    --lifecycle-configuration '{
        "Rules": [{
            "ID": "BackupRetention",
            "Status": "Enabled",
            "Filter": {"Prefix": "backups/"},
            "Transitions": [
                {"Days": 7, "StorageClass": "GLACIER"}
            ],
            "Expiration": {"Days": 30},
            "NoncurrentVersionExpiration": {"NoncurrentDays": 30}
        }]
    }'
```

**What this does:**

```
Day 0      → backup uploaded to S3 STANDARD_IA
             (same durability, ~58% cheaper — pay more to retrieve)
Day 7      → automatically moved to Glacier
             (archival tier, very cheap, but takes minutes to retrieve)
Day 30     → automatically deleted
```

> **RPO discussion:** If your team says "we need to recover any point in the last 30 days" → set `Expiration.Days = 30`. If compliance says 90 days → set it to 90. This is a business/SLA decision, not a technical one.

---

## Step 3 — Run a Backup

```bash
chmod +x scripts/*.sh

# Edit bucket name in backup.sh first
nano scripts/backup.sh   # change BUCKET="s3://my-backup-bucket"

# Run
./scripts/backup.sh
```

**What happens inside backup.sh:**

```
1. tar -czf /tmp/app_20240615_120000.tar.gz   ./app/
        ↑ compress app files into a single archive

2. tar -czf /tmp/config_20240615_120000.tar.gz  ./config/
        ↑ compress config files

3. aws s3 cp /tmp/app_*.tar.gz       s3://bucket/backups/20240615_120000/
   aws s3 cp /tmp/config_*.tar.gz    s3://bucket/backups/20240615_120000/
        ↑ upload both to S3 under a timestamped folder

4. rm /tmp/*.tar.gz
        ↑ clean up — don't leave archives on the server disk
```

**Expected output:**
```
[2024-06-15 12:00:00] ==============================
[2024-06-15 12:00:00] Backup started  id=20240615_120000
[2024-06-15 12:00:00] ==============================
[2024-06-15 12:00:00] Archiving app files...
[2024-06-15 12:00:00] Created: /tmp/app_20240615_120000.tar.gz
[2024-06-15 12:00:01] Archiving config files...
[2024-06-15 12:00:01] Created: /tmp/config_20240615_120000.tar.gz
[2024-06-15 12:00:01] Uploading to S3...
[2024-06-15 12:00:03] Uploaded to s3://my-backup-bucket/backups/20240615_120000/
[2024-06-15 12:00:03] Temp files cleaned up
[2024-06-15 12:00:03] Backup complete. id=20240615_120000
```

**Verify in S3:**
```bash
aws s3 ls s3://my-backup-bucket/backups/20240615_120000/
# 2024-06-15 12:00:03   12543  app_20240615_120000.tar.gz
# 2024-06-15 12:00:03    4231  config_20240615_120000.tar.gz
```

---

## Step 4 — Automate with Cron

```bash
crontab -e
```

Add these lines:

```cron
# Full backup every day at 2 AM
0 2 * * * /path/to/s3-backup/scripts/backup.sh >> /path/to/s3-backup/logs/backup.log 2>&1

# Config-only backup every hour
0 * * * * /path/to/s3-backup/scripts/backup.sh >> /path/to/s3-backup/logs/backup.log 2>&1
```

> **Why back up config hourly?** Config files (nginx.conf, app.conf) are small and change frequently. If someone edits nginx.conf wrong and the server breaks at 3 PM, you want to restore the 2 PM version — not yesterday's 2 AM version.

**Verify cron is running:**
```bash
# View crontab
crontab -l

# Check cron logs
grep CRON /var/log/syslog           # Ubuntu/Debian
grep CRON /var/log/cron             # RHEL/CentOS
```

---

## Step 5 — The Restore Process (Demonstrated)

This is the most important step. A backup that can't be restored is worthless.

### 5a. List what's available
```bash
./scripts/list_backups.sh
```
Output:
```
Available backups in s3://my-backup-bucket/backups/
─────────────────────────────────────────
  20240615_140000
  20240615_120000
  20240614_020000
```

### 5b. Restore the latest backup (both app + config)
```bash
./scripts/restore.sh
```

### 5c. Restore a specific backup
```bash
./scripts/restore.sh 20240615_120000
```

### 5d. Restore only config files
```bash
./scripts/restore.sh 20240615_120000 config
```

**What happens inside restore.sh:**

```
1. Query S3 for latest backup ID   (if none specified)
2. aws s3 cp  → download archives to /tmp/
3. tar -xzf   → extract to ./restored/<backup_id>/app/
                               ./restored/<backup_id>/config/
4. rm /tmp/   → clean up
```

**Expected output:**
```
[2024-06-15 13:00:00] Restoring specific backup: 20240615_120000
[2024-06-15 13:00:00] ==============================
[2024-06-15 13:00:00] Restore started  id=20240615_120000
[2024-06-15 13:00:00] ==============================
[2024-06-15 13:00:00] Downloading app archive...
[2024-06-15 13:00:02] Download complete: app_20240615_120000.tar.gz
[2024-06-15 13:00:02] Extracting to ./restored/20240615_120000/app...
    ✓ ./restored/20240615_120000/app/app.py
[2024-06-15 13:00:02] Downloading config archive...
[2024-06-15 13:00:03] Extracting to ./restored/20240615_120000/config...
    ✓ ./restored/20240615_120000/config/nginx.conf
[2024-06-15 13:00:03] ==============================
[2024-06-15 13:00:03] Restore complete → ./restored/20240615_120000/
[2024-06-15 13:00:03] ==============================
```

### After restoring — copy files back to their live locations

```bash
# Put app files back
cp -r ./restored/20240615_120000/app/* /var/www/myapp/

# Put config back
cp ./restored/20240615_120000/config/nginx.conf /etc/nginx/nginx.conf

# Reload services
systemctl reload nginx
systemctl restart myapp
```

---

## S3 Folder Structure (What It Looks Like in S3)

```
s3://my-backup-bucket/
└── backups/
    ├── 20240615_020000/                 ← Day 1 scheduled backup
    │   ├── app_20240615_020000.tar.gz
    │   └── config_20240615_020000.tar.gz
    │
    ├── 20240615_120000/                 ← Manual/triggered backup
    │   ├── app_20240615_120000.tar.gz
    │   └── config_20240615_120000.tar.gz
    │
    └── 20240616_020000/                 ← Day 2 scheduled backup
        ├── app_20240616_020000.tar.gz
        └── config_20240616_020000.tar.gz
```

Each backup is **self-contained** in its own timestamped folder. You can restore any point in time independently.

---

## Key DevOps Concepts in This Exercise

### RPO vs RTO

| Term | Full form | Meaning | This project |
|---|---|---|---|
| RPO | Recovery Point Objective | Max data loss acceptable | Hourly config backup = max 1hr of config changes lost |
| RTO | Recovery Time Objective | Max downtime to recover | Manual restore takes ~5min; automated could be faster |

These are **SLA commitments** you negotiate with the business — not technical choices.

### Storage Classes (why STANDARD_IA?)

| Class | Cost | Retrieval | Use case |
|---|---|---|---|
| STANDARD | $$$ | Instant | Frequently accessed data |
| STANDARD_IA | $$ | Instant | Backups (infrequent access) |
| GLACIER | $ | 1–5 min | Archives, compliance |
| GLACIER DEEP | ¢ | 12 hrs | Long-term cold storage |

Backups sit in STANDARD_IA until the lifecycle rule moves them to Glacier at day 7.

### Why NOT back up to the same server?

If the server dies (disk failure, accidental `rm -rf`, ransomware) — the backup dies too. S3 is **off-server, off-region capable, 11-nines durable**. It survives your server dying completely.

### What NOT to back up

- `/tmp/` — throwaway data
- Application logs — these go to CloudWatch or ELK, not S3 backup
- Node modules / Python virtualenvs / build artifacts — these are reproducible from source; back up `package.json` or `requirements.txt` instead
- `.env` files with real secrets — back up `.env.template`; secrets go in AWS Secrets Manager or SSM Parameter Store

---

## Quick Reference

```bash
# One-time setup
aws s3 mb s3://my-backup-bucket --region us-east-1
aws s3api put-bucket-versioning --bucket my-backup-bucket --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket my-backup-bucket --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Daily operations
./scripts/backup.sh                           # run backup now
./scripts/list_backups.sh                     # see what's in S3
./scripts/restore.sh                          # restore latest
./scripts/restore.sh 20240615_120000          # restore specific
./scripts/restore.sh 20240615_120000 config   # restore config only

# Check logs
tail -f logs/backup.log
tail -f logs/restore.log

# Manual S3 operations
aws s3 ls s3://my-backup-bucket/backups/               # list all backups
aws s3 ls s3://my-backup-bucket/backups/20240615_120000/ # inspect one backup
aws s3 rm s3://my-backup-bucket/backups/OLD_ID/ --recursive  # manual delete
```

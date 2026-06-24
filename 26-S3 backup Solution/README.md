# Exercise 26: S3 Backup Solution

> Implement a backup strategy that backs up application files and config files to S3, with a demonstrated restore process.

---

## Folder structure

```
exercises/ex26-s3-backup/
├── app/
│   ├── app.py
│   └── config/
│       └── app.conf
├── scripts/
│   ├── backup.sh
│   └── restore.sh
└── README.md
```

---

## Step 1 — Create the folder structure

```bash
mkdir -p exercises/ex26-s3-backup/app/config
mkdir -p exercises/ex26-s3-backup/scripts

cd exercises/ex26-s3-backup
```

---

## Step 2 — Create dummy app and config files

### app/app.py

```python
# Dummy application file
print("Payment service running...")
```

### app/config/app.conf

```ini
[server]
host = 0.0.0.0
port = 8080

[database]
url = postgres://localhost:5432/payments
pool_size = 10

[logging]
level = INFO
output = /var/log/app.log
```

---

## Step 3 — Create an S3 bucket

```bash
aws s3 mb s3://my-app-backups-ex26 --region us-east-1
```

Verify it was created:

```bash
aws s3 ls | grep my-app-backups-ex26
```

Expected:

```text
2024-01-01 00:00:00 my-app-backups-ex26
```

---

## Step 4 — Write the backup script

### scripts/backup.sh

```bash
#!/bin/bash
#!/bin/bash

BUCKET="s3://tharun-s3-backup-2026"

aws s3 cp app/ "$BUCKET/app/" --recursive

echo "Backup completed."

Make it executable:

```bash
chmod +x scripts/backup.sh
```

---

## Step 5 — Write the restore script

### scripts/restore.sh

```bash
#!/bin/bash

BUCKET="s3://tharun-s3-backup-2026"

aws s3 cp "$BUCKET/app/" app/ --recursive

echo "Restore completed."
```

Make it executable:

```bash
chmod +x scripts/restore.sh
```

---

## Step 6 — Run the backup

```bash
cd exercises/ex26-s3-backup
./scripts/backup.sh
```

Expected output:

```text
==> Starting backup at 2024-01-01T12-00-00
--> Backing up application files...
upload: app/app.py to s3://my-app-backups-ex26/backups/2024-01-01T12-00-00/app/app.py
upload: app/config/app.conf to s3://my-app-backups-ex26/backups/2024-01-01T12-00-00/app/config/app.conf
--> Backing up config files...
upload: app/config/app.conf to s3://my-app-backups-ex26/backups/2024-01-01T12-00-00/config/app.conf
--> Tagging latest backup pointer...
==> Backup complete: s3://my-app-backups-ex26/backups/2024-01-01T12-00-00
```

---

## Step 7 — Verify backup in S3

```bash
aws s3 ls s3://my-app-backups-ex26/backups/ --recursive
```

Expected:

```text
2024-01-01 12:00:00    123 backups/2024-01-01T12-00-00/app/app.py
2024-01-01 12:00:00    234 backups/2024-01-01T12-00-00/app/config/app.conf
2024-01-01 12:00:00    234 backups/2024-01-01T12-00-00/config/app.conf
```

Check the latest pointer:

```bash
aws s3 cp s3://my-app-backups-ex26/latest.txt -
```

Expected:

```text
backups/2024-01-01T12-00-00
```

---

## Step 8 — Demonstrate restore (latest)

```bash
# Restore the latest backup
./scripts/restore.sh
```

Expected output:

```text
--> No timestamp provided, restoring latest backup...
==> Restoring from: s3://my-app-backups-ex26/backups/2024-01-01T12-00-00
--> Restoring application files...
download: s3://my-app-backups-ex26/.../app/app.py to restored/app/app.py
download: s3://my-app-backups-ex26/.../app/config/app.conf to restored/app/config/app.conf
--> Restoring config files...
download: s3://my-app-backups-ex26/.../config/app.conf to restored/config/app.conf
==> Restore complete → restored/
restored/
restored/app
restored/app/app.py
restored/app/config
restored/app/config/app.conf
restored/config
restored/config/app.conf
```

---

## Step 9 — Demonstrate restore (specific timestamp)

```bash
# Restore a specific backup by timestamp
./scripts/restore.sh 2024-01-01T12-00-00
```

Expected output:

```text
--> Restoring specific backup: backups/2024-01-01T12-00-00
==> Restoring from: s3://my-app-backups-ex26/backups/2024-01-01T12-00-00
...
==> Restore complete → restored/
```

---

## Step 10 — Commit and push

```bash
git add exercises/ex26-s3-backup/
git commit -m "ex26: S3 backup and restore solution"
git push origin main
```

---

## Bonus — Enable S3 Versioning (extra safety)

```bash
aws s3api put-bucket-versioning \
  --bucket my-app-backups-ex26 \
  --versioning-configuration Status=Enabled
```

Verify:

```bash
aws s3api get-bucket-versioning --bucket my-app-backups-ex26
```

Expected:

```json
{
  "Status": "Enabled"
}
```

With versioning on, even if a backup is overwritten or deleted, S3 keeps all previous versions. Extra protection on top of timestamp-based backups.

---

## Key concepts to explain in interview

| Concept                      | What it does                                                             |
| ---------------------------- | ------------------------------------------------------------------------ |
| `aws s3 sync`                | Incrementally syncs only changed files — faster than full upload each time |
| `TIMESTAMP` in prefix        | Each backup is isolated under its own folder — no overwrites             |
| `latest.txt` pointer         | Stores the most recent backup path — restore script reads it automatically |
| `--exclude` flags            | Skips compiled/cache files like `.pyc` and `__pycache__`                 |
| `set -euo pipefail`          | Script fails fast on any error — no silent failures                      |
| S3 Versioning                | Adds another layer — S3 itself keeps object history even if files change |

---

## Interview answer (say this)

"I implemented an S3 backup solution with two shell scripts — backup.sh and restore.sh. The backup script uses aws s3 sync to upload application files and config files into timestamped prefixes in S3, so each backup is completely isolated. It also writes a latest.txt pointer so the restore script knows which backup to pull by default, without needing to specify a timestamp manually. The restore script supports two modes — restore latest, or restore a specific timestamp — which covers both day-to-day recovery and point-in-time recovery scenarios. I also enabled S3 versioning as an extra safety layer."




## 1. What does `aws s3 cp` do?

**Answer:**

`aws s3 cp` copies files between:

* Local → S3
* S3 → Local
* S3 → S3

Example:

```bash id="7hhljf"
aws s3 cp app.py s3://my-bucket/
```

This uploads `app.py` to the S3 bucket.

With `--recursive`:

```bash id="1m26em"
aws s3 cp app/ s3://my-bucket/app/ --recursive
```

it copies the entire folder.

---

## 2. Difference between `cp` and `sync`?

**Answer:**

### cp

Copies all specified files.

```bash id="jcypr6"
aws s3 cp app/ s3://bucket/app/ --recursive
```

Every run attempts to copy all files.

### sync

Compares source and destination.

```bash id="zz6x0u"
aws s3 sync app/ s3://bucket/app/
```

Only uploads changed/new files.

| Feature                     | cp | sync |
| --------------------------- | -- | ---- |
| Copy all files              | ✅  | ❌    |
| Incremental                 | ❌  | ✅    |
| Faster for repeated backups | ❌  | ✅    |

---

## 3. What is S3?

**Answer:**

S3 (Simple Storage Service) is AWS's object storage service used to store files, backups, logs, images, videos, and application data.

Features:

* Highly durable
* Scalable
* Pay-as-you-use
* Accessible via AWS CLI, SDKs, and Console

---

## 4. Why use S3 for backups?

**Answer:**

S3 is suitable for backups because:

* Highly durable (11 nines durability)
* Data is stored redundantly
* Low maintenance
* Scales automatically
* Supports versioning
* Easy integration with AWS services

Example:

```text id="0khfrx"
Application Files
      ↓
Backup Script
      ↓
S3 Bucket
```

---

## 5. How does AWS CLI authenticate?

**Answer:**

AWS CLI uses:

```text id="r5gh1u"
Access Key ID
Secret Access Key
```

stored via:

```bash id="2h1c4x"
aws configure
```

Flow:

```text id="cl6df8"
AWS CLI
   ↓
Access Key ID
Secret Access Key
   ↓
AWS IAM
   ↓
Permission Check
   ↓
Allow / Deny
```

---

# Level 2

## What happens if I run the backup twice?

Current script:

```bash id="zlkg2o"
aws s3 cp app/ "$BUCKET/app/" --recursive
```

**Answer:**

Running the script multiple times uploads the files again to the same location.

This can overwrite existing objects with the same names.

A better design is:

```text id="95d2zn"
backups/
 ├── 2026-06-24-10-00
 ├── 2026-06-24-11-00
 └── 2026-06-24-12-00
```

using timestamp-based folders.

---

# Level 3

## How would you make this production-ready?

### 1. Use `aws s3 sync`

```bash id="29dypq"
aws s3 sync app/ s3://bucket/
```

Reason:

Only changed files are uploaded.

---

### 2. Add timestamps

Example:

```text id="9x9on8"
backups/2026-06-24-10-30-00/
```

Reason:

Every backup is stored separately.

---

### 3. Enable S3 Versioning

Reason:

S3 stores previous versions of objects.

Recovery becomes easier.

---

### 4. Add logging

Example:

```bash id="9ms9ua"
./backup.sh >> backup.log 2>&1
```

Reason:

Track backup success and failures.

---

### 5. Add error handling

```bash id="cyzfrl"
set -euo pipefail
```

Reason:

Script stops immediately on errors.

---

### 6. Use IAM Roles

Instead of:

```text id="u7jlwm"
Access Key
Secret Key
```

attach an IAM Role to EC2.

Benefits:

* More secure
* No credential management

---

# Level 4 AWS Questions

## What is IAM?

**Answer:**

IAM (Identity and Access Management) is the AWS service used to manage:

* Users
* Roles
* Groups
* Policies

It controls who can access AWS resources and what actions they can perform.

---

## Difference between IAM User and IAM Role?

### IAM User

Permanent identity.

Example:

```text id="ig9fjw"
tharun-cli
```

Has:

* Password
* Access Keys

Used by people/applications.

---

### IAM Role

Temporary identity.

Has permissions but no permanent credentials.

Used by:

* EC2
* Lambda
* ECS
* Other AWS services

Example:

```text id="ksu6pf"
EC2BackupRole
```

---

### Interview answer

> IAM Users are long-term identities, whereas IAM Roles provide temporary permissions that can be assumed by users or AWS services.

---

## What is an ARN?

**Answer:**

ARN = Amazon Resource Name.

Unique identifier of an AWS resource.

Example:

```text id="d8h4jx"
arn:aws:iam::123456789012:user/tharun-cli
```

Breakdown:

```text id="v4l1pw"
arn
aws
iam
123456789012
user
tharun-cli
```

---

## What is an S3 Bucket?

**Answer:**

An S3 bucket is a container that stores objects (files) in S3.

Example:

```text id="d84kp6"
tharun-s3-backup-2026
```

Inside:

```text id="aymp7v"
app.py
backup.zip
logs.txt
```

A bucket is similar to a top-level folder.

---

## Difference between EC2 and S3?

| EC2               | S3              |
| ----------------- | --------------- |
| Compute service   | Storage service |
| Runs applications | Stores files    |
| Virtual server    | Object storage  |
| Has CPU/RAM       | No CPU/RAM      |

Interview answer:

> EC2 provides compute resources to run applications, while S3 provides object storage for files and backups.

---

## What is S3 Versioning?

**Answer:**

Versioning allows S3 to keep multiple versions of the same object.

Example:

```text id="avbk2g"
app.py v1
app.py v2
app.py v3
```

If someone accidentally deletes or overwrites a file:

```text id="j8hllk"
app.py
```

you can recover an older version.

Interview answer:

> S3 Versioning protects against accidental deletion and overwrites by maintaining historical versions of objects.

---

If you can explain these answers in your own words and also walk through your `backup.sh` line by line, you'll be well prepared for most fresher DevOps interviews.


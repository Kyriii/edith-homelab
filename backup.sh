#!/bin/bash
# Nightly backup of Edith to Amazon S3. Run from cron at 03:00:
#   0 3 * * * /home/kyri/backup.sh >> /home/kyri/backup.log 2>&1
# A root cron job at 02:55 first copies root-owned config into ~/edith-config:
#   55 2 * * * cp /opt/AdGuardHome/AdGuardHome.yaml /etc/ufw/user.rules /home/kyri/edith-config/ && chown kyri:kyri /home/kyri/edith-config/*
set -euo pipefail
BUCKET="s3://YOUR-BACKUP-BUCKET"   # versioned, SSE-S3, public access blocked
crontab -l > /home/kyri/edith-config/crontab.txt
cp /home/kyri/backup.sh /home/kyri/edith-config/
aws s3 sync /home/kyri/revitalroots-agents "$BUCKET/revitalroots-agents" \
  --profile edith-backup --delete --only-show-errors \
  --exclude ".venv/*" --exclude "*__pycache__*"
aws s3 sync /home/kyri/edith-config "$BUCKET/edith-config" \
  --profile edith-backup --only-show-errors
echo "$(date '+%F %T') backup ok"

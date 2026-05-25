#!/usr/bin/env bash
# Installs a cron job that runs the full pipeline daily at 2 PM.
# Run once: bash setup_cron.sh

PIPELINE_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON="$(which python3)"
LOGFILE="$PIPELINE_DIR/logs/cron.log"
CRON_CMD="0 14 * * * cd $PIPELINE_DIR && $PYTHON main.py run >> $LOGFILE 2>&1"

mkdir -p "$PIPELINE_DIR/logs"

# Check if already installed
if crontab -l 2>/dev/null | grep -q "main.py run"; then
    echo "Cron job already installed."
else
    (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
    echo "Cron job installed: runs daily at 14:00"
fi

echo ""
echo "Current crontab:"
crontab -l

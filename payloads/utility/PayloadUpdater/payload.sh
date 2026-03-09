#!/bin/bash
# Title: NullSec Payload Updater
# Author: bad-antics
# Description: Pull latest NullSec payloads from GitHub repo
# Category: nullsec

PROMPT "PAYLOAD UPDATER
━━━━━━━━━━━━━━━━━━━━━━━━━
Update NullSec payloads
from GitHub.

Requires internet
connection.

Press OK to check."

# Check connectivity
SPINNER_START "Checking connection..."
if ! ping -c 1 -W 3 github.com >/dev/null 2>&1; then
    SPINNER_STOP
    ERROR_DIALOG "No internet!\nConnect via client mode."
    exit 1
fi
SPINNER_STOP

REPO="https://raw.githubusercontent.com/bad-antics/nullsec-pineapple-suite/main"
PAYLOAD_DIR="/root/payloads/user/nullsec"
BACKUP_DIR="/mmc/nullsec/backup/payloads_$(date +%Y%m%d_%H%M%S)"

resp=$(CONFIRMATION_DIALOG "Update NullSec payloads?

Current payloads will
be backed up first.

Proceed?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

# Backup current
SPINNER_START "Backing up..."
mkdir -p "$BACKUP_DIR"
cp -r "$PAYLOAD_DIR"/* "$BACKUP_DIR/" 2>/dev/null
SPINNER_STOP

# Download manifest
SPINNER_START "Downloading updates..."
wget -q -O /tmp/payload_manifest.txt "$REPO/manifest.txt" 2>/dev/null

UPDATED=0
FAILED=0
if [ -f /tmp/payload_manifest.txt ]; then
    while read -r payload_path; do
        [ -z "$payload_path" ] && continue
        DIR=$(dirname "$payload_path")
        mkdir -p "$PAYLOAD_DIR/$DIR" 2>/dev/null
        if wget -q -O "$PAYLOAD_DIR/$payload_path" "$REPO/payloads/$payload_path" 2>/dev/null; then
            chmod +x "$PAYLOAD_DIR/$payload_path" 2>/dev/null
            UPDATED=$((UPDATED + 1))
        else
            FAILED=$((FAILED + 1))
        fi
    done < /tmp/payload_manifest.txt
fi
SPINNER_STOP

PROMPT "UPDATE COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━
Updated: $UPDATED payloads
Failed:  $FAILED
Backup:  $(basename $BACKUP_DIR)

Refresh payload list
to see new payloads."

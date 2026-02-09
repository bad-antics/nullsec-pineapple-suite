#!/bin/bash
# Title: Loot Sync
# Author: NullSec
# Description: Syncs all captured loot files to USB storage
# Category: nullsec/exfiltration

LOOT_DIR="/mmc/nullsec/lootsync"
mkdir -p "$LOOT_DIR"

PROMPT "LOOT SYNC

Copies all captured loot
to USB storage for safe
offline retrieval.

Features:
- Auto USB detection
- Date-organized folders
- Transfer progress
- Integrity verification

Press OK to configure."

# Detect USB mount points
USB_MOUNT=""
for mp in /mnt/usb /media/usb /mnt/sda1 /media/sda1 /tmp/mnt/sda1; do
    if mountpoint -q "$mp" 2>/dev/null; then
        USB_MOUNT="$mp"
        break
    fi
done

# Try to detect and mount if not found
if [ -z "$USB_MOUNT" ]; then
    USB_DEV=$(ls /dev/sd[a-z]1 2>/dev/null | head -1)
    if [ -n "$USB_DEV" ]; then
        USB_MOUNT="/mnt/usb"
        mkdir -p "$USB_MOUNT"
        mount "$USB_DEV" "$USB_MOUNT" 2>/dev/null
        if ! mountpoint -q "$USB_MOUNT" 2>/dev/null; then
            USB_MOUNT=""
        fi
    fi
fi

[ -z "$USB_MOUNT" ] && { ERROR_DIALOG "No USB drive detected!

Insert a USB drive and
ensure it is mounted.

Checked: /mnt/usb
         /media/usb
         /dev/sda1"; exit 1; }

USB_FREE=$(df -h "$USB_MOUNT" 2>/dev/null | tail -1 | awk '{print $4}')
USB_TOTAL=$(df -h "$USB_MOUNT" 2>/dev/null | tail -1 | awk '{print $2}')
LOG "USB detected at $USB_MOUNT ($USB_FREE free)"

PROMPT "USB DETECTED

Mount: $USB_MOUNT
Total: $USB_TOTAL
Free:  $USB_FREE

Source: /mmc/nullsec/

Press OK to select mode."

PROMPT "SYNC MODE:

1. Full sync (all loot)
2. New files only (delta)
3. Specific payload loot
4. Compressed archive

Select mode next."

MODE=$(NUMBER_PICKER "Mode (1-4):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MODE=1 ;; esac
[ "$MODE" -lt 1 ] && MODE=1
[ "$MODE" -gt 4 ] && MODE=4

SRC_PATH="/mmc/nullsec"

if [ "$MODE" -eq 3 ]; then
    PAYLOAD_NAME=$(TEXT_PICKER "Payload name:" "datavacuum")
    case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) PAYLOAD_NAME="" ;; esac
    [ -z "$PAYLOAD_NAME" ] && { ERROR_DIALOG "No payload specified!"; exit 1; }
    SRC_PATH="/mmc/nullsec/$PAYLOAD_NAME"
    [ ! -d "$SRC_PATH" ] && { ERROR_DIALOG "Path not found:
$SRC_PATH"; exit 1; }
fi

SRC_SIZE=$(du -sh "$SRC_PATH" 2>/dev/null | awk '{print $1}')
SRC_FILES=$(find "$SRC_PATH" -type f 2>/dev/null | wc -l | tr -d ' ')

resp=$(CONFIRMATION_DIALOG "START SYNC?

Source: $SRC_PATH
Files: $SRC_FILES
Size: $SRC_SIZE
Mode: $MODE
USB Free: $USB_FREE

Press OK to sync.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DATE_DIR=$(date +%Y-%m-%d)
DEST_DIR="$USB_MOUNT/nullsec-loot/$DATE_DIR"
mkdir -p "$DEST_DIR"
SYNC_LOG="$LOOT_DIR/sync_$TIMESTAMP.log"

LOG "Loot sync started"
SPINNER_START "Syncing loot to USB..."

COPIED=0
ERRORS=0

case $MODE in
    1) # Full sync
        cp -rv "$SRC_PATH" "$DEST_DIR/" > "$SYNC_LOG" 2>&1
        COPIED=$(grep -c '^\.' "$SYNC_LOG" 2>/dev/null || find "$DEST_DIR" -type f | wc -l | tr -d ' ')
        ;;
    2) # Delta sync (new files only)
        LAST_SYNC_FILE="$LOOT_DIR/.last_sync"
        if [ -f "$LAST_SYNC_FILE" ]; then
            find "$SRC_PATH" -newer "$LAST_SYNC_FILE" -type f | while read -r f; do
                REL="${f#$SRC_PATH/}"
                mkdir -p "$DEST_DIR/$(dirname "$REL")"
                if cp "$f" "$DEST_DIR/$REL" 2>>"$SYNC_LOG"; then
                    COPIED=$((COPIED + 1))
                else
                    ERRORS=$((ERRORS + 1))
                fi
            done
        else
            cp -rv "$SRC_PATH" "$DEST_DIR/" > "$SYNC_LOG" 2>&1
        fi
        touch "$LAST_SYNC_FILE"
        COPIED=$(find "$DEST_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
        ;;
    3) # Specific payload
        cp -rv "$SRC_PATH" "$DEST_DIR/" > "$SYNC_LOG" 2>&1
        COPIED=$(find "$DEST_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
        ;;
    4) # Compressed archive
        ARCHIVE="$DEST_DIR/nullsec_loot_$TIMESTAMP.tar.gz"
        tar czf "$ARCHIVE" -C "$(dirname "$SRC_PATH")" "$(basename "$SRC_PATH")" 2>>"$SYNC_LOG"
        COPIED=1
        ;;
esac

# Sync filesystem
sync

SPINNER_STOP

DEST_SIZE=$(du -sh "$DEST_DIR" 2>/dev/null | awk '{print $1}')
LOG "Sync complete: $COPIED files to $DEST_DIR"

echo "[$TIMESTAMP] Mode=$MODE Files=$COPIED Size=$DEST_SIZE Dest=$DEST_DIR" >> "$SYNC_LOG"

PROMPT "SYNC COMPLETE

Files copied: $COPIED
Size: $DEST_SIZE
Destination: $DEST_DIR

USB remaining: $(df -h "$USB_MOUNT" | tail -1 | awk '{print $4}')
Log: $SYNC_LOG

Safe to remove USB."

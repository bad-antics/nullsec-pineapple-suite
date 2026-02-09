#!/bin/bash
# Title: Handshake Alert
# Author: NullSec
# Description: Watch for WPA handshake captures and alert with SSID/BSSID info
# Category: nullsec/alerts

LOOT_DIR="/mmc/nullsec/handshakealert"
mkdir -p "$LOOT_DIR"

PROMPT "HANDSHAKE ALERT

Monitors capture directories
for new WPA handshake files
and alerts when found.

Features:
- .cap/.pcap file watching
- SSID/BSSID extraction
- Handshake validation
- Real-time notifications

Press OK to configure."

PROMPT "WATCH DIRECTORY:

1. /mmc/nullsec/handshakes
2. /mmc/nullsec/captures
3. /tmp/captures

Select directory next."

DIR_SEL=$(NUMBER_PICKER "Directory (1-3):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DIR_SEL=1 ;; esac

case $DIR_SEL in
    1) WATCH_DIR="/mmc/nullsec/handshakes" ;;
    2) WATCH_DIR="/mmc/nullsec/captures" ;;
    3) WATCH_DIR="/tmp/captures" ;;
    *) WATCH_DIR="/mmc/nullsec/handshakes" ;;
esac

mkdir -p "$WATCH_DIR"

if ! command -v aircrack-ng >/dev/null 2>&1; then
    ERROR_DIALOG "aircrack-ng not found!

Required for handshake
validation."
    exit 1
fi

DURATION=$(NUMBER_PICKER "Monitor (minutes):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac
[ "$DURATION" -lt 1 ] && DURATION=1
[ "$DURATION" -gt 1440 ] && DURATION=1440

VALIDATE=$(CONFIRMATION_DIALOG "Validate handshakes?

Run aircrack-ng to verify
each capture contains a
valid WPA handshake.")
[ "$VALIDATE" = "$DUCKYSCRIPT_USER_CONFIRMED" ] && DO_VALIDATE=1 || DO_VALIDATE=0

resp=$(CONFIRMATION_DIALOG "START WATCHING?

Directory: $WATCH_DIR
Duration: ${DURATION} min
Validate: $([ $DO_VALIDATE -eq 1 ] && echo YES || echo NO)

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG_FILE="$LOOT_DIR/hsalert_$(date +%Y%m%d_%H%M).log"
echo "=== HANDSHAKE ALERT LOG ===" > "$LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"
echo "Watch dir: $WATCH_DIR" >> "$LOG_FILE"
echo "===========================" >> "$LOG_FILE"

# Snapshot existing files
ls "$WATCH_DIR"/*.cap "$WATCH_DIR"/*.pcap 2>/dev/null | sort > /tmp/hs_known.txt

END_TIME=$(($(date +%s) + DURATION * 60))
HS_COUNT=0

LOG "Watching $WATCH_DIR for handshakes..."
SPINNER_START "Watching for captures..."

while [ $(date +%s) -lt $END_TIME ]; do
    # Check for new capture files
    ls "$WATCH_DIR"/*.cap "$WATCH_DIR"/*.pcap 2>/dev/null | sort > /tmp/hs_current.txt
    NEW_FILES=$(comm -13 /tmp/hs_known.txt /tmp/hs_current.txt 2>/dev/null)

    if [ -n "$NEW_FILES" ]; then
        while IFS= read -r CAPFILE; do
            [ -z "$CAPFILE" ] && continue
            TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
            FNAME=$(basename "$CAPFILE")
            VALID="unchecked"

            # Extract SSID/BSSID info
            SSID_INFO=$(aircrack-ng "$CAPFILE" 2>/dev/null | grep -E "^\s+[0-9]+" | head -1)
            BSSID=$(echo "$SSID_INFO" | awk '{print $2}')
            ESSID=$(echo "$SSID_INFO" | awk '{for(i=5;i<=NF;i++) printf $i" "; print ""}' | sed 's/[[:space:]]*$//')
            [ -z "$BSSID" ] && BSSID="unknown"
            [ -z "$ESSID" ] && ESSID="unknown"

            # Validate handshake if enabled
            if [ $DO_VALIDATE -eq 1 ]; then
                if aircrack-ng "$CAPFILE" 2>/dev/null | grep -q "1 handshake"; then
                    VALID="VALID"
                else
                    VALID="no handshake"
                fi
            fi

            HS_COUNT=$((HS_COUNT + 1))
            echo "[$TIMESTAMP] $FNAME SSID:$ESSID BSSID:$BSSID [$VALID]" >> "$LOG_FILE"
            LOG "Handshake found: $ESSID"

            SPINNER_STOP
            PROMPT "⚠ HANDSHAKE CAPTURED!

File: $FNAME
SSID: $ESSID
BSSID: $BSSID
Status: $VALID
Time: $TIMESTAMP

Total captures: $HS_COUNT

Press OK to continue."
            SPINNER_START "Watching..."
        done <<< "$NEW_FILES"

        cp /tmp/hs_current.txt /tmp/hs_known.txt
    fi

    sleep 5
done

SPINNER_STOP
rm -f /tmp/hs_known.txt /tmp/hs_current.txt

echo "===========================" >> "$LOG_FILE"
echo "Ended: $(date)" >> "$LOG_FILE"
echo "Handshakes found: $HS_COUNT" >> "$LOG_FILE"

PROMPT "WATCH COMPLETE

Duration: ${DURATION} min
Handshakes found: $HS_COUNT

Log saved to:
$LOG_FILE

Press OK to exit."

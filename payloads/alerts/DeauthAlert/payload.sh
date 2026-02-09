#!/bin/bash
# Title: Deauth Alert
# Author: NullSec
# Description: Monitor for deauthentication frames and alert the user
# Category: nullsec/alerts

LOOT_DIR="/mmc/nullsec/deauthalert"
mkdir -p "$LOOT_DIR"

PROMPT "DEAUTH ALERT

Monitors the airspace for
deauthentication frames and
alerts when attacks are
detected in real-time.

Features:
- Deauth frame detection
- Source MAC logging
- Channel & timestamp info
- Configurable sensitivity

Press OK to configure."

# Detect monitor interface
MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!

Run: airmon-ng start wlan1"; exit 1; }

LOG "Monitor interface: $MON_IF"

PROMPT "SENSITIVITY:

1. Low (10+ deauths/min)
2. Medium (5+ deauths/min)
3. High (1+ deauths/min)

Select threshold next."

SENSITIVITY=$(NUMBER_PICKER "Sensitivity (1-3):" 2)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SENSITIVITY=2 ;; esac
[ "$SENSITIVITY" -lt 1 ] && SENSITIVITY=1
[ "$SENSITIVITY" -gt 3 ] && SENSITIVITY=3

case $SENSITIVITY in
    1) THRESHOLD=10 ;;
    2) THRESHOLD=5 ;;
    3) THRESHOLD=1 ;;
esac

DURATION=$(NUMBER_PICKER "Monitor (minutes):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=30 ;; esac
[ "$DURATION" -lt 1 ] && DURATION=1
[ "$DURATION" -gt 1440 ] && DURATION=1440

resp=$(CONFIRMATION_DIALOG "START MONITORING?

Interface: $MON_IF
Threshold: $THRESHOLD deauths/min
Duration: ${DURATION} min

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG_FILE="$LOOT_DIR/deauth_$(date +%Y%m%d_%H%M).log"
echo "=== DEAUTH ALERT LOG ===" > "$LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"
echo "Threshold: $THRESHOLD deauths/min" >> "$LOG_FILE"
echo "========================" >> "$LOG_FILE"

END_TIME=$(($(date +%s) + DURATION * 60))
TOTAL_DEAUTHS=0
ALERT_COUNT=0

LOG "Monitoring for deauth attacks..."
SPINNER_START "Scanning for deauth frames..."

while [ $(date +%s) -lt $END_TIME ]; do
    DEAUTH_COUNT=0

    for CH in 1 6 11 2 3 4 5 7 8 9 10; do
        [ $(date +%s) -ge $END_TIME ] && break
        iwconfig "$MON_IF" channel "$CH" 2>/dev/null

        # Capture deauth/disassoc frames (type 0 subtype 12 = deauth, subtype 10 = disassoc)
        HITS=$(timeout 2 tcpdump -i "$MON_IF" -c 100 -e 2>/dev/null | \
            grep -ci "deauthentication\|disassoc" 2>/dev/null || echo 0)
        DEAUTH_COUNT=$((DEAUTH_COUNT + HITS))

        if [ "$HITS" -gt 0 ]; then
            TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
            # Extract source MACs from deauth frames
            SRC_MAC=$(timeout 1 tcpdump -i "$MON_IF" -c 5 -e 2>/dev/null | \
                grep -i "deauth" | awk '{print $2}' | head -1)
            [ -z "$SRC_MAC" ] && SRC_MAC="unknown"
            echo "[$TIMESTAMP] Ch:$CH Src:$SRC_MAC Count:$HITS" >> "$LOG_FILE"
        fi
    done

    TOTAL_DEAUTHS=$((TOTAL_DEAUTHS + DEAUTH_COUNT))

    if [ "$DEAUTH_COUNT" -ge "$THRESHOLD" ]; then
        ALERT_COUNT=$((ALERT_COUNT + 1))
        SPINNER_STOP
        LOG "ALERT: $DEAUTH_COUNT deauths detected!"
        echo "[ALERT $(date '+%H:%M:%S')] $DEAUTH_COUNT deauths in sweep" >> "$LOG_FILE"

        PROMPT "⚠ DEAUTH DETECTED!

$DEAUTH_COUNT deauth frames
found in last sweep.

Total alerts: $ALERT_COUNT
Total deauths: $TOTAL_DEAUTHS

Press OK to continue
monitoring."
        SPINNER_START "Monitoring..."
    fi

    sleep 1
done

SPINNER_STOP

echo "========================" >> "$LOG_FILE"
echo "Ended: $(date)" >> "$LOG_FILE"
echo "Total deauths: $TOTAL_DEAUTHS" >> "$LOG_FILE"
echo "Total alerts: $ALERT_COUNT" >> "$LOG_FILE"

PROMPT "MONITORING COMPLETE

Duration: ${DURATION} min
Total deauths: $TOTAL_DEAUTHS
Alerts triggered: $ALERT_COUNT

Log saved to:
$LOG_FILE

Press OK to exit."

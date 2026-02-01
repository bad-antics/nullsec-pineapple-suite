#!/bin/bash
# Title: Client Tracker
# Author: bad-antics
# Description: Track a specific device across networks
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/tracking"
mkdir -p "$LOOT_DIR"

PROMPT "CLIENT TRACKER

Monitor when a specific
device connects to any
WiFi network.

Track phones, laptops,
IoT devices, etc.

Press OK to configure."

[ ! -d "/sys/class/net/wlan0" ] && { ERROR_DIALOG "wlan0 not found!"; exit 1; }

TARGET_MAC=$(MAC_PICKER "Target Device MAC:")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) 
    ERROR_DIALOG "MAC required!"
    exit 1
    ;;
esac

DURATION=$(NUMBER_PICKER "Track duration (min):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=30 ;; esac

ALERT_MODE=$(CONFIRMATION_DIALOG "Alert on detection?

Vibrate/beep when
target is detected?")

LOG_FILE="$LOOT_DIR/track_${TARGET_MAC//:/}_$(date +%Y%m%d_%H%M).txt"

resp=$(CONFIRMATION_DIALOG "START TRACKING?

Target: $TARGET_MAC
Duration: ${DURATION} min
Log: $LOG_FILE

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

echo "=== CLIENT TRACKING LOG ===" > "$LOG_FILE"
echo "Target: $TARGET_MAC" >> "$LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"
echo "=========================" >> "$LOG_FILE"

END_TIME=$(($(date +%s) + DURATION * 60))
DETECTIONS=0
LAST_SEEN=""

LOG "Tracking $TARGET_MAC..."

while [ $(date +%s) -lt $END_TIME ]; do
    # Quick scan all channels
    for CH in 1 6 11; do
        iwconfig wlan0 channel $CH 2>/dev/null
        
        # Capture for 2 seconds
        timeout 2 tcpdump -i wlan0 -c 50 -e 2>/dev/null | grep -i "$TARGET_MAC" > /tmp/track_result.txt
        
        if [ -s /tmp/track_result.txt ]; then
            TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
            
            # Try to get BSSID
            BSSID=$(timeout 3 airodump-ng wlan0 --write-interval 1 -w /tmp/quickscan --output-format csv 2>/dev/null; grep -i "$TARGET_MAC" /tmp/quickscan*.csv 2>/dev/null | head -1 | cut -d',' -f6 | tr -d ' ')
            
            if [ "$LAST_SEEN" != "$CH-$BSSID" ]; then
                DETECTIONS=$((DETECTIONS + 1))
                LAST_SEEN="$CH-$BSSID"
                
                echo "[$TIMESTAMP] Ch:$CH BSSID:$BSSID" >> "$LOG_FILE"
                
                if [ "$ALERT_MODE" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
                    ALERT "Target detected! Ch:$CH"
                fi
                
                LOG "Detected on Ch:$CH"
            fi
        fi
    done
    
    sleep 1
done

echo "=========================" >> "$LOG_FILE"
echo "Ended: $(date)" >> "$LOG_FILE"
echo "Total Detections: $DETECTIONS" >> "$LOG_FILE"

PROMPT "TRACKING COMPLETE

Target: $TARGET_MAC
Duration: ${DURATION} min
Detections: $DETECTIONS

Log saved to:
$LOG_FILE

Press OK to exit."

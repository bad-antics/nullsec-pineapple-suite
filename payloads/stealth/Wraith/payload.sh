#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# WRAITH - Wireless Reconnaissance & Automated Information Tracking Hunter
# Developed by: bad-antics
# 
# Follow and track specific targets like a ghost - persistent surveillance
#═══════════════════════════════════════════════════════════════════════════════

source /mmc/nullsec/lib/nullsec-scanner.sh 2>/dev/null

LOOT_DIR="/mmc/nullsec/wraith"
mkdir -p "$LOOT_DIR"

PROMPT "    ╦ ╦╦═╗╔═╗╦╔╦╗╦ ╦
    ║║║╠╦╝╠═╣║ ║ ╠═╣
    ╚╩╝╩╚═╩ ╩╩ ╩ ╩ ╩
━━━━━━━━━━━━━━━━━━━━━━━━━
Persistent Target Tracker

Follow your target
across channels,
through time.

They cannot hide.
━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics
Press OK to haunt."

PROMPT "WRAITH TRACKING MODES:

1. Device Stalker
   (Track MAC address)

2. Network Watch
   (Monitor SSID)

3. Probe Hunter
   (Follow probes)

4. Full Haunt
   (All methods)"

MODE=$(NUMBER_PICKER "Mode (1-4):" 1)

if [ "$MODE" = "1" ] || [ "$MODE" = "4" ]; then
    nullsec_select_client
    TARGET_MAC="$SELECTED_CLIENT"
fi

if [ "$MODE" = "2" ] || [ "$MODE" = "4" ]; then
    nullsec_select_target
    TARGET_SSID="$SELECTED_SSID"
    TARGET_BSSID="$SELECTED_BSSID"
fi

DURATION=$(NUMBER_PICKER "Track (minutes):" 10)
DURATION_SEC=$((DURATION * 60))

INTERFACE="wlan0"
airmon-ng check kill 2>/dev/null
airmon-ng start $INTERFACE >/dev/null 2>&1
MON_IF="${INTERFACE}mon"
[ ! -d "/sys/class/net/$MON_IF" ] && MON_IF="$INTERFACE"

LOOT_FILE="$LOOT_DIR/wraith_$(date +%Y%m%d_%H%M%S).txt"
TRACK_LOG="$LOOT_DIR/tracking_live.log"

cat > "$LOOT_FILE" << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 WRAITH - Target Tracking Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Started: $(date)
 Mode: $MODE
 Duration: ${DURATION} minutes
 Target MAC: ${TARGET_MAC:-N/A}
 Target SSID: ${TARGET_SSID:-N/A}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 NullSec Pineapple Suite | Developed by: bad-antics
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

TRACKING LOG:
EOF

LOG "Wraith hunting..."
SPINNER_START "Haunting target..."

SIGHTINGS=0
> "$TRACK_LOG"

track_mac() {
    local MAC="$1"
    # Channel hop and look for MAC
    while true; do
        for ch in 1 2 3 4 5 6 7 8 9 10 11; do
            iwconfig $MON_IF channel $ch 2>/dev/null
            # Quick capture check
            timeout 2 tcpdump -i $MON_IF -c 5 "ether host $MAC" 2>/dev/null | while read line; do
                echo "[$(date '+%H:%M:%S')] CH$ch: $line" >> "$TRACK_LOG"
                echo "[$(date '+%H:%M:%S')] SIGHTING on Channel $ch" >> "$LOOT_FILE"
                ((SIGHTINGS++))
            done
        done
    done
}

track_ssid() {
    local BSSID="$1"
    # Monitor specific BSSID
    timeout $DURATION_SEC airodump-ng --bssid $BSSID -w /tmp/wraith_track $MON_IF --output-format csv 2>/dev/null &
    local PID=$!
    
    # Periodically check for activity
    while kill -0 $PID 2>/dev/null; do
        sleep 5
        CLIENTS=$(grep -c "Station" /tmp/wraith_track-01.csv 2>/dev/null || echo 0)
        echo "[$(date '+%H:%M:%S')] Clients on target: $CLIENTS" >> "$LOOT_FILE"
    done
}

track_probes() {
    # Listen for probe requests matching pattern
    timeout $DURATION_SEC tcpdump -i $MON_IF -l "type mgt subtype probe-req" 2>/dev/null | while read line; do
        echo "[$(date '+%H:%M:%S')] $line" >> "$TRACK_LOG"
        ((SIGHTINGS++))
    done
}

case $MODE in
    1) track_mac "$TARGET_MAC" & ;;
    2) track_ssid "$TARGET_BSSID" ;;
    3) track_probes ;;
    4)
        [ -n "$TARGET_MAC" ] && track_mac "$TARGET_MAC" &
        [ -n "$TARGET_BSSID" ] && track_ssid "$TARGET_BSSID" &
        track_probes &
        ;;
esac

sleep $DURATION_SEC

SPINNER_STOP

# Kill background processes
pkill -f "tcpdump\|airodump" 2>/dev/null

# Compile report
SIGHTINGS=$(wc -l < "$TRACK_LOG" 2>/dev/null || echo 0)

cat >> "$LOOT_FILE" << EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 TRACKING SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Ended: $(date)
 Total Sightings: $SIGHTINGS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DETAILED LOG:
$(cat "$TRACK_LOG" 2>/dev/null | head -50)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 NullSec Pineapple Suite | Developed by: bad-antics
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

# Cleanup
airmon-ng stop $MON_IF 2>/dev/null
rm -f /tmp/wraith_track*

PROMPT "WRAITH VANISHED
━━━━━━━━━━━━━━━━━━━━━━━━━
Tracking complete.

Duration: ${DURATION}min
Sightings: $SIGHTINGS

Target: ${TARGET_MAC:-$TARGET_SSID}

Report: $LOOT_FILE
━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics"

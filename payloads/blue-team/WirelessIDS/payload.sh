#!/bin/bash
# Title: NullSec Wireless IDS
# Author: bad-antics
# Description: Detect deauthentication attacks, evil twins, and rogue APs in real-time
# Category: nullsec

LOOT_DIR="/mmc/nullsec/logs/ids"
mkdir -p "$LOOT_DIR"

PROMPT "WIRELESS IDS
━━━━━━━━━━━━━━━━━━━━━━━━━
Real-time detection of:
- Deauth attacks
- Evil twin APs
- Rogue access points
- KARMA attacks

Press OK to start."

MONITOR_IF=""
for iface in wlan1mon wlan2mon mon0; do
    [ -d "/sys/class/net/$iface" ] && MONITOR_IF="$iface" && break
done
[ -z "$MONITOR_IF" ] && ERROR_DIALOG "No monitor interface!" && exit 1

DURATION=$(NUMBER_PICKER "Monitor (minutes):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=30 ;; esac
[ $DURATION -lt 1 ] && DURATION=1

LOGFILE="$LOOT_DIR/ids_$(date +%Y%m%d_%H%M%S).log"
echo "NullSec Wireless IDS - Started $(date)" > "$LOGFILE"

DEAUTH_COUNT=0
ROGUE_COUNT=0
ALERTS=0
END=$(($(date +%s) + DURATION * 60))

SPINNER_START "IDS Active - Monitoring..."

while [ $(date +%s) -lt $END ]; do
    # Capture 5 seconds of traffic
    timeout 5 tcpdump -i "$MONITOR_IF" -c 500 -w /tmp/ids_cap.pcap 2>/dev/null
    
    # Check for deauth frames (type 0, subtype 12)
    DEAUTHS=$(tcpdump -r /tmp/ids_cap.pcap 'type mgt subtype deauth' 2>/dev/null | wc -l)
    if [ "$DEAUTHS" -gt 5 ]; then
        DEAUTH_COUNT=$((DEAUTH_COUNT + DEAUTHS))
        ALERTS=$((ALERTS + 1))
        echo "[ALERT] Deauth storm detected: $DEAUTHS frames @ $(date +%H:%M:%S)" >> "$LOGFILE"
        LOG "⚠️ Deauth attack: $DEAUTHS frames"
    fi
    
    # Check for beacon anomalies (duplicate SSIDs on different BSSIDs)
    BEACONS=$(tcpdump -r /tmp/ids_cap.pcap 'type mgt subtype beacon' -e 2>/dev/null |         awk '{print $NF}' | sort | uniq -d | wc -l)
    if [ "$BEACONS" -gt 0 ]; then
        ROGUE_COUNT=$((ROGUE_COUNT + BEACONS))
        ALERTS=$((ALERTS + 1))
        echo "[ALERT] Possible evil twin: $BEACONS duplicate SSIDs @ $(date +%H:%M:%S)" >> "$LOGFILE"
    fi
    
    rm -f /tmp/ids_cap.pcap
done

SPINNER_STOP

PROMPT "IDS REPORT
━━━━━━━━━━━━━━━━━━━━━━━━━
Duration: ${DURATION}min
Alerts: $ALERTS
Deauth Frames: $DEAUTH_COUNT
Rogue APs: $ROGUE_COUNT

Log: $(basename $LOGFILE)"

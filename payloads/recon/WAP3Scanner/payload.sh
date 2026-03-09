#!/bin/bash
# Title: NullSec WPA3 Scanner
# Author: bad-antics
# Description: Scan for WPA3-capable networks and identify transition mode targets
# Category: nullsec

LOOT_DIR="/mmc/nullsec/loot"
mkdir -p "$LOOT_DIR"

PROMPT "WPA3 SCANNER
━━━━━━━━━━━━━━━━━━━━━━━━━
Identify WPA3 networks
and transition mode
targets.

Press OK to scan."

MONITOR_IF=""
for iface in wlan1mon wlan2mon mon0; do
    [ -d "/sys/class/net/$iface" ] && MONITOR_IF="$iface" && break
done

if [ -z "$MONITOR_IF" ]; then
    ERROR_DIALOG "No monitor interface!\nRun: airmon-ng start wlan1"
    exit 1
fi

SPINNER_START "Scanning for WPA3..."
rm -f /tmp/wpa3_scan*
timeout 20 airodump-ng "$MONITOR_IF" -w /tmp/wpa3_scan --output-format csv 2>/dev/null &
sleep 20
killall airodump-ng 2>/dev/null
SPINNER_STOP

WPA3_COUNT=0
TRANSITION_COUNT=0
RESULTS=""

while IFS=',' read -r bssid x1 x2 channel x3 cipher auth power x4 x5 x6 x7 essid rest; do
    bssid=$(echo "$bssid" | tr -d ' ')
    [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
    auth=$(echo "$auth" | tr -d ' ')
    essid=$(echo "$essid" | tr -d ' ' | head -c 16)
    [ -z "$essid" ] && essid="[Hidden]"

    if echo "$auth" | grep -qi "SAE"; then
        WPA3_COUNT=$((WPA3_COUNT + 1))
        if echo "$auth" | grep -qi "PSK"; then
            TRANSITION_COUNT=$((TRANSITION_COUNT + 1))
            RESULTS="${RESULTS}${essid} [TRANSITION]\n"
        else
            RESULTS="${RESULTS}${essid} [WPA3-ONLY]\n"
        fi
    fi
done < /tmp/wpa3_scan-01.csv

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
echo -e "$RESULTS" > "$LOOT_DIR/wpa3_scan_${TIMESTAMP}.txt"

PROMPT "WPA3 SCAN RESULTS
━━━━━━━━━━━━━━━━━━━━━━━━━
WPA3 Networks: $WPA3_COUNT
Transition Mode: $TRANSITION_COUNT

$(echo -e "$RESULTS" | head -8)

Saved to loot dir."

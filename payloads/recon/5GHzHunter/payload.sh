#!/bin/bash
# Title: NullSec 5GHz Hunter
# Author: bad-antics
# Description: Dedicated 5GHz band scanner for finding less-crowded high-bandwidth targets
# Category: nullsec

LOOT_DIR="/mmc/nullsec/loot"
mkdir -p "$LOOT_DIR"

PROMPT "5GHz HUNTER
━━━━━━━━━━━━━━━━━━━━━━━━━
Scan 5GHz band for
high-bandwidth targets.

Channels 36-165.

Press OK to scan."

MONITOR_IF=""
for iface in wlan1mon wlan2mon mon0; do
    [ -d "/sys/class/net/$iface" ] && MONITOR_IF="$iface" && break
done
[ -z "$MONITOR_IF" ] && ERROR_DIALOG "No monitor interface!" && exit 1

SPINNER_START "Scanning 5GHz band..."
rm -f /tmp/5ghz_scan*
timeout 25 airodump-ng "$MONITOR_IF" --band a -w /tmp/5ghz_scan --output-format csv 2>/dev/null &
sleep 25
killall airodump-ng 2>/dev/null
SPINNER_STOP

COUNT=0
RESULTS=""
while IFS=',' read -r bssid x1 x2 channel x3 x4 x5 x6 power x7 x8 x9 x10 essid rest; do
    bssid=$(echo "$bssid" | tr -d ' ')
    [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
    channel=$(echo "$channel" | tr -d ' ')
    essid=$(echo "$essid" | tr -d ' ' | head -c 16)
    [ -z "$essid" ] && essid="[Hidden]"
    power=$(echo "$power" | tr -d ' ')
    COUNT=$((COUNT + 1))
    RESULTS="${RESULTS}CH${channel} ${power}dBm ${essid}\n"
done < /tmp/5ghz_scan-01.csv

echo -e "$RESULTS" > "$LOOT_DIR/5ghz_$(date +%Y%m%d_%H%M%S).txt"

PROMPT "5GHz RESULTS
━━━━━━━━━━━━━━━━━━━━━━━━━
Networks found: $COUNT

$(echo -e "$RESULTS" | sort -t' ' -k2 -rn | head -8)

Saved to loot dir."

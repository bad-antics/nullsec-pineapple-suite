#!/bin/bash
# Title: Stealth Recon
# Author: bad-antics
# Description: Completely passive WiFi reconnaissance
# Category: nullsec/stealth

LOOT_DIR="/mmc/nullsec/stealth"
mkdir -p "$LOOT_DIR"

PROMPT "STEALTH RECON

100% passive monitoring.
No packets transmitted.
Completely undetectable.

Collects:
- All nearby networks
- All client devices
- Probe requests
- Signal analysis

Press OK to configure."

[ ! -d "/sys/class/net/wlan0" ] && { ERROR_DIALOG "wlan0 not found!"; exit 1; }

DURATION=$(NUMBER_PICKER "Duration (minutes):" 10)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=10 ;; esac

CHANNEL_HOP=$(CONFIRMATION_DIALOG "Channel hopping?

Scan all channels or
stay on one channel?")

if [ "$CHANNEL_HOP" != "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    CHANNEL=$(NUMBER_PICKER "Fixed channel:" 6)
fi

REPORT="$LOOT_DIR/stealth_$(date +%Y%m%d_%H%M).txt"

resp=$(CONFIRMATION_DIALOG "START RECON?

Duration: ${DURATION} min
Mode: Passive only
Channel: $([ \"$CHANNEL_HOP\" = \"$DUCKYSCRIPT_USER_CONFIRMED\" ] && echo Hopping || echo $CHANNEL)

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Starting stealth recon..."

DURATION_SEC=$((DURATION * 60))
CAP_FILE="/tmp/stealth_cap"

# Start passive capture
if [ "$CHANNEL_HOP" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    timeout $DURATION_SEC airodump-ng wlan0 --write-interval 5 -w "$CAP_FILE" --output-format csv 2>/dev/null &
else
    iwconfig wlan0 channel $CHANNEL
    timeout $DURATION_SEC airodump-ng wlan0 -c $CHANNEL --write-interval 5 -w "$CAP_FILE" --output-format csv 2>/dev/null &
fi

CAP_PID=$!

# Also capture probe requests
tcpdump -i wlan0 -e type mgt subtype probe-req -l 2>/dev/null > /tmp/probes.txt &
PROBE_PID=$!

sleep $DURATION_SEC

kill $CAP_PID $PROBE_PID 2>/dev/null

# Generate report
echo "=======================================" > "$REPORT"
echo "      NULLSEC STEALTH RECON REPORT     " >> "$REPORT"
echo "=======================================" >> "$REPORT"
echo "" >> "$REPORT"
echo "Scan Time: $(date)" >> "$REPORT"
echo "Duration: ${DURATION} minutes" >> "$REPORT"
echo "Mode: 100% Passive" >> "$REPORT"
echo "" >> "$REPORT"

# Count networks
AP_COUNT=$(grep -c "WPA\|WEP\|OPN" "${CAP_FILE}"*.csv 2>/dev/null || echo 0)
echo "--- NETWORKS DETECTED: $AP_COUNT ---" >> "$REPORT"
echo "" >> "$REPORT"

# List networks
grep "WPA\|WEP\|OPN" "${CAP_FILE}"*.csv 2>/dev/null | while IFS=',' read -r bssid first last channel speed privacy cipher auth power beacons iv lan_ip id_len essid key; do
    essid=$(echo "$essid" | tr -d ' ')
    bssid=$(echo "$bssid" | tr -d ' ')
    [ -n "$essid" ] && echo "SSID: $essid | BSSID: $bssid | Ch:$channel | $privacy" >> "$REPORT"
done

echo "" >> "$REPORT"

# Count clients
CLIENT_COUNT=$(grep -E "^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}," "${CAP_FILE}"*.csv 2>/dev/null | grep -v "BSSID" | wc -l || echo 0)
echo "--- CLIENTS DETECTED: $CLIENT_COUNT ---" >> "$REPORT"
echo "" >> "$REPORT"

# Probe requests
PROBE_COUNT=$(wc -l < /tmp/probes.txt 2>/dev/null || echo 0)
echo "--- PROBE REQUESTS: $PROBE_COUNT ---" >> "$REPORT"
echo "" >> "$REPORT"

# Extract unique probed SSIDs
grep -oE "Probe Request \([^)]+\)" /tmp/probes.txt 2>/dev/null | sort -u | head -20 >> "$REPORT"

echo "" >> "$REPORT"
echo "=======================================" >> "$REPORT"
echo "Full data: ${CAP_FILE}*.csv" >> "$REPORT"

PROMPT "STEALTH RECON COMPLETE

Networks: $AP_COUNT
Clients: $CLIENT_COUNT
Probes: $PROBE_COUNT

Report saved:
$REPORT

Press OK to exit."

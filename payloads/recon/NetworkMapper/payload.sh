#!/bin/bash
# Title: Network Mapper
# Author: bad-antics
# Description: Detailed reconnaissance of a specific network
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/recon"
mkdir -p "$LOOT_DIR"

PROMPT "NETWORK MAPPER

Deep recon of a specific
target network.

Collects:
- All connected clients
- Client device types
- Signal strengths
- Data rates
- Encryption details

Press OK to configure."

[ ! -d "/sys/class/net/wlan0" ] && { ERROR_DIALOG "wlan0 not found!"; exit 1; }

PROMPT "SELECT TARGET:

1. Scan and select
2. Enter BSSID manually
3. Enter SSID to find

Enter option next."

MODE=$(NUMBER_PICKER "Mode (1-3):" 1)

if [ "$MODE" -eq 1 ]; then
    SPINNER_START "Scanning networks..."
    timeout 10 airodump-ng wlan0 --write-interval 1 -w /tmp/netscan --output-format csv 2>/dev/null
    SPINNER_STOP
    
    # Count networks
    NET_COUNT=$(grep -c "WPA\|WEP\|OPN" /tmp/netscan*.csv 2>/dev/null || echo 0)
    
    PROMPT "Found $NET_COUNT networks

Select target by number
on next screen.

Networks are sorted by
signal strength."
    
    TARGET_NUM=$(NUMBER_PICKER "Network # (1-$NET_COUNT):" 1)
    
    # Get target info
    TARGET_LINE=$(grep "WPA\|WEP\|OPN" /tmp/netscan*.csv 2>/dev/null | sed -n "${TARGET_NUM}p")
    BSSID=$(echo "$TARGET_LINE" | cut -d',' -f1 | tr -d ' ')
    CHANNEL=$(echo "$TARGET_LINE" | cut -d',' -f4 | tr -d ' ')
    SSID=$(echo "$TARGET_LINE" | cut -d',' -f14 | tr -d ' ')
    
elif [ "$MODE" -eq 2 ]; then
    BSSID=$(MAC_PICKER "Target BSSID:")
    CHANNEL=$(NUMBER_PICKER "Channel:" 6)
    SSID="Unknown"
    
elif [ "$MODE" -eq 3 ]; then
    SSID=$(TEXT_PICKER "Target SSID:" "")
    SPINNER_START "Finding network..."
    timeout 10 airodump-ng wlan0 --essid "$SSID" --write-interval 1 -w /tmp/ssidscan --output-format csv 2>/dev/null
    SPINNER_STOP
    BSSID=$(grep "$SSID" /tmp/ssidscan*.csv 2>/dev/null | head -1 | cut -d',' -f1 | tr -d ' ')
    CHANNEL=$(grep "$SSID" /tmp/ssidscan*.csv 2>/dev/null | head -1 | cut -d',' -f4 | tr -d ' ')
fi

DURATION=$(NUMBER_PICKER "Scan duration (sec):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac

REPORT="$LOOT_DIR/netmap_${BSSID//:/}_$(date +%Y%m%d_%H%M).txt"

resp=$(CONFIRMATION_DIALOG "MAP NETWORK?

SSID: $SSID
BSSID: $BSSID
Channel: $CHANNEL
Duration: ${DURATION}s

Press OK to start.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Mapping $SSID..."

# Lock to target channel
iwconfig wlan0 channel $CHANNEL

# Deep scan
airodump-ng wlan0 --bssid "$BSSID" -c $CHANNEL --write-interval 1 -w /tmp/deepmap --output-format csv &
SCAN_PID=$!

sleep $DURATION
kill $SCAN_PID 2>/dev/null

# Generate report
echo "======================================" > "$REPORT"
echo "       NULLSEC NETWORK MAP            " >> "$REPORT"
echo "======================================" >> "$REPORT"
echo "" >> "$REPORT"
echo "Target: $SSID" >> "$REPORT"
echo "BSSID: $BSSID" >> "$REPORT"
echo "Channel: $CHANNEL" >> "$REPORT"
echo "Scanned: $(date)" >> "$REPORT"
echo "" >> "$REPORT"
echo "--- CONNECTED CLIENTS ---" >> "$REPORT"

# Parse clients
CLIENT_COUNT=0
while IFS=',' read -r mac firstseen lastseen power packets bssid probed; do
    mac=$(echo "$mac" | tr -d ' ')
    if [[ "$mac" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] && [ "$bssid" = "$BSSID" ]; then
        CLIENT_COUNT=$((CLIENT_COUNT + 1))
        echo "" >> "$REPORT"
        echo "Client #$CLIENT_COUNT" >> "$REPORT"
        echo "  MAC: $mac" >> "$REPORT"
        echo "  Signal: $power dBm" >> "$REPORT"
        echo "  Packets: $packets" >> "$REPORT"
        echo "  Last Seen: $lastseen" >> "$REPORT"
    fi
done < /tmp/deepmap*.csv 2>/dev/null

echo "" >> "$REPORT"
echo "======================================" >> "$REPORT"
echo "Total Clients: $CLIENT_COUNT" >> "$REPORT"
echo "======================================" >> "$REPORT"

PROMPT "MAPPING COMPLETE

SSID: $SSID
Clients Found: $CLIENT_COUNT

Report saved to:
$REPORT

Press OK to exit."

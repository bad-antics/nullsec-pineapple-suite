#!/bin/bash
# Title: Quick Scan
# Author: bad-antics
# Description: Fast 30-second WiFi environment scan
# Category: nullsec/recon

PROMPT "QUICK SCAN

Fast 30-second scan of
all nearby WiFi networks.

Shows:
- Network names
- Security types
- Signal strength
- Client count

Press OK to scan."

[ ! -d "/sys/class/net/wlan0" ] && { ERROR_DIALOG "wlan0 not found!"; exit 1; }

SPINNER_START "Scanning 30 seconds..."
timeout 30 airodump-ng wlan0 --write-interval 5 -w /tmp/quickscan --output-format csv 2>/dev/null
SPINNER_STOP

# Count results
AP_COUNT=$(grep -c "WPA\|WEP\|OPN" /tmp/quickscan*.csv 2>/dev/null || echo 0)
CLIENT_COUNT=$(grep -E "^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}," /tmp/quickscan*.csv 2>/dev/null | grep -v BSSID | wc -l || echo 0)

# Count by security
WPA3=$(grep -c "WPA3" /tmp/quickscan*.csv 2>/dev/null || echo 0)
WPA2=$(grep -c "WPA2" /tmp/quickscan*.csv 2>/dev/null || echo 0)
WPA=$(grep "WPA[^23]" /tmp/quickscan*.csv 2>/dev/null | grep -v WPA2 | grep -v WPA3 | wc -l || echo 0)
WEP=$(grep -c "WEP" /tmp/quickscan*.csv 2>/dev/null || echo 0)
OPEN=$(grep -c " OPN" /tmp/quickscan*.csv 2>/dev/null || echo 0)

PROMPT "SCAN COMPLETE

Networks: $AP_COUNT
Clients: $CLIENT_COUNT

Security breakdown:
WPA3: $WPA3
WPA2: $WPA2  
WPA: $WPA
WEP: $WEP
Open: $OPEN

Press OK for top 5."

# Show top 5 strongest
PROMPT "TOP 5 NETWORKS

$(grep "WPA\|WEP\|OPN" /tmp/quickscan*.csv 2>/dev/null | sort -t',' -k9 -nr | head -5 | while IFS=',' read -r bssid first last channel speed privacy cipher auth power beacons iv lan_ip id_len essid key; do
    essid=$(echo "$essid" | tr -d ' ')
    power=$(echo "$power" | tr -d ' ')
    privacy=$(echo "$privacy" | tr -d ' ')
    echo "$essid ($power dBm) $privacy"
done)

Press OK to exit."

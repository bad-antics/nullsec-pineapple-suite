#!/bin/bash
# Title: NullSec SSID Pranks
# Author: bad-antics
# Description: Broadcast funny/scary SSID names
# Category: nullsec

PROMPT "NULLSEC SSID PRANKS

Broadcast hilarious or
creepy WiFi network names!

Choose from preset packs or
create your own.

Press OK to configure."

# Check for wlan0
[ ! -d "/sys/class/net/wlan0" ] && { ERROR_DIALOG "wlan0 not found!"; exit 1; }

# SSID Packs
PROMPT "SELECT SSID PACK:

1. FBI Surveillance Van
2. Mom Click Here 4 Internet
3. Virus Distribution Center
4. Pretty Fly for a WiFi
5. Horror Movie Pack
6. Hacker Troll Pack
7. Custom SSIDs

Enter number next screen."

PACK=$(NUMBER_PICKER "Select pack (1-7):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) PACK=1 ;; esac

case $PACK in
    1) SSIDS="FBI Surveillance Van #42
CIA Stakeout Unit 7
NSA Mobile SIGINT
DEA Undercover Van
Police Surveillance 3
Homeland Security
Secret Service Detail"
       ;;
    2) SSIDS="Mom Click Here 4 Internet
Free Virus Download
Totally Not A Scam
Click 4 Free Money
Your Neighbor's WiFi
WiFi Password is 1234
Test Network Do Not Use"
       ;;
    3) SSIDS="Virus Distribution Center
Malware Test Lab
Trojan Deployment Node
Ransomware HQ
Botnet Command Server
Keylogger Network
Data Harvesting WiFi"
       ;;
    4) SSIDS="Pretty Fly for a WiFi
Wu-Tang LAN
LAN Solo
The LAN Before Time
LAN of the Free
Silence of the LANs
The Promised LAN
LANdo Calrissian"
       ;;
    5) SSIDS="It Follows
They're Watching
Behind You
Don't Look
The WiFi is Coming From Inside
Basement Network
I Can See You"
       ;;
    6) SSIDS="Hack Me If You Can
Loading Virus...
Connecting to your webcam
Your printer is hacked
I hacked your router
Deleting System32
NULLSEC_WAS_HERE"
       ;;
    7) 
       SSID1=$(TEXT_PICKER "SSID 1:" "NullSec Rules")
       SSID2=$(TEXT_PICKER "SSID 2:" "Hack The Planet")
       SSID3=$(TEXT_PICKER "SSID 3:" "Free WiFi")
       SSIDS="$SSID1
$SSID2
$SSID3"
       ;;
esac

# Duration
DURATION=$(NUMBER_PICKER "Duration (seconds):" 300)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=300 ;; esac
[ $DURATION -lt 30 ] && DURATION=30

# Channel
CHANNEL=$(NUMBER_PICKER "Channel (1-11):" 6)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) CHANNEL=6 ;; esac

resp=$(CONFIRMATION_DIALOG "Broadcast SSIDs?

Duration: ${DURATION}s
Channel: $CHANNEL

This will create fake APs!")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

# Broadcast each SSID
LOG "Starting SSID broadcast..."
killall hostapd 2>/dev/null

SSID_COUNT=0
echo "$SSIDS" | while read -r ssid; do
    [ -z "$ssid" ] && continue
    SSID_COUNT=$((SSID_COUNT + 1))
    
    # Create hostapd config
    cat > "/tmp/prank_${SSID_COUNT}.conf" << EOF
interface=wlan0
driver=nl80211
ssid=$ssid
hw_mode=g
channel=$CHANNEL
auth_algs=1
wpa=0
EOF
done

# Use mdk3/mdk4 if available for mass beacons
if command -v mdk4 >/dev/null 2>&1; then
    echo "$SSIDS" > /tmp/ssid_list.txt
    timeout $DURATION mdk4 wlan0 b -f /tmp/ssid_list.txt -c $CHANNEL &
    MDK_PID=$!
    sleep $DURATION
    kill $MDK_PID 2>/dev/null
elif command -v mdk3 >/dev/null 2>&1; then
    echo "$SSIDS" > /tmp/ssid_list.txt
    timeout $DURATION mdk3 wlan0 b -f /tmp/ssid_list.txt -c $CHANNEL &
    MDK_PID=$!
    sleep $DURATION
    kill $MDK_PID 2>/dev/null
else
    # Fallback: use hostapd (single SSID only)
    FIRST_SSID=$(echo "$SSIDS" | head -1)
    cat > /tmp/prank.conf << EOF
interface=wlan0
driver=nl80211
ssid=$FIRST_SSID
hw_mode=g
channel=$CHANNEL
auth_algs=1
wpa=0
EOF
    hostapd /tmp/prank.conf &
    sleep $DURATION
    killall hostapd 2>/dev/null
fi

killall mdk3 mdk4 hostapd 2>/dev/null

PROMPT "SSID PRANK COMPLETE

Broadcasted SSIDs for ${DURATION}s

Check nearby devices - they
should have seen the networks!

Press OK to exit."

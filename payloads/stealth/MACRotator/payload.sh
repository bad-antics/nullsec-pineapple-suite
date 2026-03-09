#!/bin/bash
# Title: NullSec MAC Rotator
# Author: bad-antics
# Description: Automatically rotate MAC address at configurable intervals
# Category: nullsec

PROMPT "MAC ROTATOR
━━━━━━━━━━━━━━━━━━━━━━━━━
Automatically change MAC
address at intervals to
avoid tracking.

Press OK to configure."

CURRENT_MAC=$(cat /sys/class/net/wlan0/address 2>/dev/null || echo "unknown")
PROMPT "Current MAC:\n$CURRENT_MAC"

INTERVAL=$(NUMBER_PICKER "Rotate interval (sec):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) INTERVAL=60 ;; esac
[ $INTERVAL -lt 10 ] && INTERVAL=10

ROTATIONS=$(NUMBER_PICKER "Total rotations (0=inf):" 10)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) ROTATIONS=10 ;; esac

resp=$(CONFIRMATION_DIALOG "MAC Rotation Config:
━━━━━━━━━━━━━━━━━━━━━━━━━
Interface: wlan0
Interval: ${INTERVAL}s
Rotations: $([ $ROTATIONS -eq 0 ] && echo Infinite || echo $ROTATIONS)

START?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

generate_mac() {
    printf '%02x:%02x:%02x:%02x:%02x:%02x'         $((RANDOM % 256 & 0xFE | 0x02))         $((RANDOM % 256)) $((RANDOM % 256))         $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256))
}

COUNT=0
while true; do
    NEW_MAC=$(generate_mac)
    ip link set wlan0 down 2>/dev/null
    ip link set wlan0 address "$NEW_MAC" 2>/dev/null
    ip link set wlan0 up 2>/dev/null
    COUNT=$((COUNT + 1))
    LOG "MAC #$COUNT: $NEW_MAC"
    
    [ $ROTATIONS -ne 0 ] && [ $COUNT -ge $ROTATIONS ] && break
    sleep "$INTERVAL"
done

FINAL_MAC=$(cat /sys/class/net/wlan0/address 2>/dev/null)
PROMPT "MAC ROTATION COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━
Rotations: $COUNT
Current MAC: $FINAL_MAC
Original: $CURRENT_MAC"

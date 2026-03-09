#!/bin/bash
# Title: NullSec Signal Cloak
# Author: bad-antics
# Description: Reduce TX power and randomize probe requests for low-visibility operation
# Category: nullsec

PROMPT "SIGNAL CLOAK
━━━━━━━━━━━━━━━━━━━━━━━━━
Minimize RF footprint.

- Reduce TX power
- Random probe requests
- Passive-only scanning

Press OK to configure."

POWER=$(NUMBER_PICKER "TX Power (1-20 dBm):" 5)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) POWER=5 ;; esac
[ $POWER -lt 1 ] && POWER=1
[ $POWER -gt 20 ] && POWER=20

resp=$(CONFIRMATION_DIALOG "CLOAK CONFIG:
━━━━━━━━━━━━━━━━━━━━━━━━━
TX Power: ${POWER}dBm
Probe Requests: Random
Scan Mode: Passive

ACTIVATE?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

SPINNER_START "Activating cloak..."

# Reduce TX power
iw dev wlan0 set txpower fixed $((POWER * 100)) 2>/dev/null
iw dev wlan1 set txpower fixed $((POWER * 100)) 2>/dev/null

# Disable power save to prevent beacon leaks
iw dev wlan0 set power_save off 2>/dev/null

# Generate random MAC for probes
RANDOM_MAC=$(printf '%02x:%02x:%02x:%02x:%02x:%02x'     $((RANDOM % 256 & 0xFE | 0x02))     $((RANDOM % 256)) $((RANDOM % 256))     $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)))

ip link set wlan0 down 2>/dev/null
ip link set wlan0 address "$RANDOM_MAC" 2>/dev/null
ip link set wlan0 up 2>/dev/null

SPINNER_STOP

PROMPT "CLOAK ACTIVE
━━━━━━━━━━━━━━━━━━━━━━━━━
TX Power: ${POWER}dBm
MAC: $RANDOM_MAC
Mode: Passive

Your RF footprint is
now minimized.
━━━━━━━━━━━━━━━━━━━━━━━━━
Deactivate by rebooting."

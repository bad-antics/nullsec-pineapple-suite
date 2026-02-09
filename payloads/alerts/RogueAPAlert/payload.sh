#!/bin/bash
# Title: Rogue AP Alert
# Author: NullSec
# Description: Detect rogue/evil twin access points and SSID spoofing
# Category: nullsec/alerts

LOOT_DIR="/mmc/nullsec/rogueapalert"
mkdir -p "$LOOT_DIR"

PROMPT "ROGUE AP ALERT

Detect evil twin and rogue
access points by comparing
scanned APs against a known
trusted list.

Features:
- SSID spoofing detection
- Duplicate BSSID detection
- New AP alerts
- Trusted AP baseline

Press OK to configure."

MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!

Run: airmon-ng start wlan1"; exit 1; }

TRUSTED_FILE="$LOOT_DIR/trusted_aps.txt"

PROMPT "BASELINE MODE:

1. Scan and set baseline now
2. Use existing trusted list
3. Monitor specific SSID

Select mode next."

MODE=$(NUMBER_PICKER "Mode (1-3):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MODE=1 ;; esac

WATCH_SSID=""

if [ "$MODE" -eq 1 ]; then
    SPINNER_START "Scanning trusted baseline..."
    rm -f /tmp/rogue_base*
    timeout 15 airodump-ng "$MON_IF" -w /tmp/rogue_base --output-format csv 2>/dev/null &
    sleep 15
    killall airodump-ng 2>/dev/null
    SPINNER_STOP

    echo "# Trusted AP Baseline - $(date)" > "$TRUSTED_FILE"
    BASE_COUNT=0
    if [ -f /tmp/rogue_base-01.csv ]; then
        while IFS=',' read -r bssid x1 x2 channel x3 privacy x5 x6 power x7 x8 x9 x10 essid rest; do
            bssid=$(echo "$bssid" | tr -d ' ')
            [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
            essid=$(echo "$essid" | sed 's/^[[:space:]]*//')
            channel=$(echo "$channel" | tr -d ' ')
            echo "$bssid|$essid|$channel" >> "$TRUSTED_FILE"
            BASE_COUNT=$((BASE_COUNT + 1))
        done < /tmp/rogue_base-01.csv
    fi
    rm -f /tmp/rogue_base*
    LOG "Baseline: $BASE_COUNT APs"
elif [ "$MODE" -eq 2 ]; then
    [ ! -f "$TRUSTED_FILE" ] && { ERROR_DIALOG "No trusted list found!

Run baseline scan first."; exit 1; }
    BASE_COUNT=$(grep -c '^[0-9A-Fa-f]' "$TRUSTED_FILE" 2>/dev/null || echo 0)
elif [ "$MODE" -eq 3 ]; then
    WATCH_SSID="NullSec"
    PROMPT "Enter the SSID to watch
for evil twins on next
screen."
    # Create minimal baseline for the watched SSID
    SPINNER_START "Scanning for $WATCH_SSID..."
    rm -f /tmp/rogue_base*
    timeout 10 airodump-ng "$MON_IF" -w /tmp/rogue_base --output-format csv 2>/dev/null &
    sleep 10
    killall airodump-ng 2>/dev/null
    SPINNER_STOP

    echo "# Watch SSID Baseline - $(date)" > "$TRUSTED_FILE"
    BASE_COUNT=0
    if [ -f /tmp/rogue_base-01.csv ]; then
        while IFS=',' read -r bssid x1 x2 channel x3 privacy x5 x6 power x7 x8 x9 x10 essid rest; do
            bssid=$(echo "$bssid" | tr -d ' ')
            [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
            echo "$bssid|$(echo "$essid" | sed 's/^[[:space:]]*//')|$(echo "$channel" | tr -d ' ')" >> "$TRUSTED_FILE"
            BASE_COUNT=$((BASE_COUNT + 1))
        done < /tmp/rogue_base-01.csv
    fi
    rm -f /tmp/rogue_base*
fi

DURATION=$(NUMBER_PICKER "Monitor (minutes):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=30 ;; esac
[ "$DURATION" -lt 1 ] && DURATION=1

resp=$(CONFIRMATION_DIALOG "START ROGUE AP WATCH?

Trusted APs: $BASE_COUNT
Duration: ${DURATION} min
$([ -n "$WATCH_SSID" ] && echo "Watch SSID: $WATCH_SSID")

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG_FILE="$LOOT_DIR/rogue_$(date +%Y%m%d_%H%M).log"
echo "=== ROGUE AP ALERT LOG ===" > "$LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"
echo "Baseline APs: $BASE_COUNT" >> "$LOG_FILE"
echo "==========================" >> "$LOG_FILE"

END_TIME=$(($(date +%s) + DURATION * 60))
ROGUE_COUNT=0

LOG "Watching for rogue APs..."
SPINNER_START "Scanning for rogues..."

while [ $(date +%s) -lt $END_TIME ]; do
    rm -f /tmp/rogue_scan*
    timeout 10 airodump-ng "$MON_IF" -w /tmp/rogue_scan --output-format csv 2>/dev/null &
    sleep 10
    killall airodump-ng 2>/dev/null

    if [ -f /tmp/rogue_scan-01.csv ]; then
        while IFS=',' read -r bssid x1 x2 channel x3 privacy x5 x6 power x7 x8 x9 x10 essid rest; do
            bssid=$(echo "$bssid" | tr -d ' ')
            [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
            essid=$(echo "$essid" | sed 's/^[[:space:]]*//')
            channel=$(echo "$channel" | tr -d ' ')

            # Check if BSSID is known
            if ! grep -qi "$bssid" "$TRUSTED_FILE" 2>/dev/null; then
                # Unknown BSSID - check if SSID matches a known one (evil twin)
                if grep -qi "|${essid}|" "$TRUSTED_FILE" 2>/dev/null; then
                    ROGUE_COUNT=$((ROGUE_COUNT + 1))
                    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
                    echo "[$TIMESTAMP] EVIL TWIN: $essid BSSID:$bssid Ch:$channel" >> "$LOG_FILE"
                    LOG "ROGUE: Evil twin $essid"

                    SPINNER_STOP
                    PROMPT "⚠ EVIL TWIN DETECTED!

SSID: $essid
Rogue BSSID: $bssid
Channel: $channel

This AP is spoofing a
trusted network name!

Rogues found: $ROGUE_COUNT

Press OK to continue."
                    SPINNER_START "Scanning..."
                fi
            fi
        done < /tmp/rogue_scan-01.csv
    fi
    rm -f /tmp/rogue_scan*
done

SPINNER_STOP

echo "==========================" >> "$LOG_FILE"
echo "Ended: $(date)" >> "$LOG_FILE"
echo "Rogues detected: $ROGUE_COUNT" >> "$LOG_FILE"

PROMPT "ROGUE AP WATCH COMPLETE

Duration: ${DURATION} min
Rogues detected: $ROGUE_COUNT

Log saved to:
$LOG_FILE

Press OK to exit."

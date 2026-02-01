#!/bin/sh
#####################################################
# NullSec GhostNetwork Payload
# Creates hidden covert network for stealthy C2
#####################################################
# Author: NullSec Team
# Target: WiFi Pineapple Pager
# Category: Stealth/Covert
#####################################################

PAYLOAD_NAME="GhostNetwork"
source /root/payloads/library/nullsec-lib.sh 2>/dev/null || true

# Configuration
GHOST_SSID="\x00\x00\x00\x00\x00\x00\x00\x00"  # Null bytes - invisible
GHOST_CHANNEL="${TARGET_CHANNEL:-6}"
GHOST_INTERFACE="wlan1"
BEACON_INTERVAL="1000"  # Less frequent = harder to detect
LOOT_DIR="/root/loot/ghost"
LOG_FILE="$LOOT_DIR/ghost_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$LOOT_DIR"

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

cleanup() {
    log "[!] Cleaning up ghost network..."
    killall hostapd 2>/dev/null
    ifconfig "$GHOST_INTERFACE" down 2>/dev/null
    log "[*] Ghost network terminated"
    exit 0
}

trap cleanup INT TERM

log "=========================================="
log "   NullSec GhostNetwork v1.0"
log "=========================================="
log "[*] Creating invisible covert network..."

# Check interface
if ! ifconfig "$GHOST_INTERFACE" >/dev/null 2>&1; then
    log "[!] Interface $GHOST_INTERFACE not found"
    exit 1
fi

# Create hostapd config for hidden network
HOSTAPD_CONF="/tmp/ghost_hostapd.conf"
cat > "$HOSTAPD_CONF" << EOF
interface=$GHOST_INTERFACE
driver=nl80211
ssid=$GHOST_SSID
channel=$GHOST_CHANNEL
hw_mode=g
ieee80211n=1
ignore_broadcast_ssid=2
beacon_int=$BEACON_INTERVAL
auth_algs=1
wpa=0
EOF

# Start ghost AP
log "[*] Starting ghost AP on channel $GHOST_CHANNEL..."
ifconfig "$GHOST_INTERFACE" up
hostapd -B "$HOSTAPD_CONF" 2>/dev/null

if [ $? -eq 0 ]; then
    log "[+] Ghost network active (hidden SSID)"
    log "[*] Pre-shared key for clients: nullsec_ghost"
    log "[*] Clients must know SSID to connect"
    
    # Setup simple DHCP
    ifconfig "$GHOST_INTERFACE" 10.66.66.1 netmask 255.255.255.0
    
    # Monitor connections
    log "[*] Monitoring for ghost clients..."
    while true; do
        CLIENTS=$(iw dev "$GHOST_INTERFACE" station dump 2>/dev/null | grep Station | wc -l)
        if [ "$CLIENTS" -gt 0 ]; then
            log "[+] Ghost clients connected: $CLIENTS"
            iw dev "$GHOST_INTERFACE" station dump >> "$LOG_FILE" 2>/dev/null
        fi
        sleep 30
    done
else
    log "[!] Failed to start ghost network"
    exit 1
fi

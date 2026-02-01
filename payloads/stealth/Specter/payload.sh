#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# SPECTER - Silent Passive Electronic Collection & Tracking Extraction Recon
# Developed by: bad-antics
# 
# Ghost-mode reconnaissance - completely passive, leaves no traces
#═══════════════════════════════════════════════════════════════════════════════

source /mmc/nullsec/lib/nullsec-scanner.sh 2>/dev/null

LOOT_DIR="/mmc/nullsec/specter"
mkdir -p "$LOOT_DIR"

PROMPT "    ╔═╗╔═╗╔═╗╔═╗╔╦╗╔═╗╦═╗
    ╚═╗╠═╝║╣ ║   ║ ║╣ ╠╦╝
    ╚═╝╩  ╚═╝╚═╝ ╩ ╚═╝╩╚═
━━━━━━━━━━━━━━━━━━━━━━━━━
Silent Intelligence
Gathering System

Zero footprint recon.
No packets transmitted.
Ghost mode active.

━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics
Press OK to haunt."

PROMPT "SPECTER MODES:

1. Shadow Watch (passive)
2. Whisper Collect (probes)
3. Ghost Profile (full)
4. Phantom Track (follow)

All modes are SILENT.
No transmission occurs."

MODE=$(NUMBER_PICKER "Mode (1-4):" 3)
DURATION=$(NUMBER_PICKER "Duration (min):" 5)
DURATION_SEC=$((DURATION * 60))

INTERFACE="wlan0"
airmon-ng check kill 2>/dev/null
airmon-ng start $INTERFACE >/dev/null 2>&1
MON_IF="${INTERFACE}mon"
[ ! -d "/sys/class/net/$MON_IF" ] && MON_IF="$INTERFACE"

LOOT_FILE="$LOOT_DIR/specter_$(date +%Y%m%d_%H%M%S).txt"

cat > "$LOOT_FILE" << HEADER
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 SPECTER - Silent Intelligence Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Timestamp: $(date)
 Mode: $MODE
 Duration: ${DURATION} minutes
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 NullSec Pineapple Suite | Developed by: bad-antics
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

HEADER

LOG "Specter active..."
SPINNER_START "Ghost mode engaged..."

TEMP_DIR="/tmp/specter_$$"
mkdir -p "$TEMP_DIR"

case $MODE in
    1) # Shadow Watch - networks only
        timeout $DURATION_SEC airodump-ng $MON_IF -w "$TEMP_DIR/shadow" --output-format csv 2>/dev/null &
        ;;
    2) # Whisper Collect - probe requests
        timeout $DURATION_SEC airodump-ng $MON_IF -w "$TEMP_DIR/whisper" --output-format csv 2>/dev/null &
        ;;
    3) # Ghost Profile - full capture
        timeout $DURATION_SEC airodump-ng $MON_IF -w "$TEMP_DIR/ghost" --output-format csv,pcap 2>/dev/null &
        ;;
    4) # Phantom Track - channel hop focusing on activity
        for ch in 1 6 11 2 3 4 5 7 8 9 10; do
            iwconfig $MON_IF channel $ch 2>/dev/null
            timeout 10 tcpdump -i $MON_IF -c 100 -w "$TEMP_DIR/phantom_ch${ch}.pcap" 2>/dev/null
        done &
        ;;
esac

sleep $DURATION_SEC

SPINNER_STOP

# Parse and analyze
echo "" >> "$LOOT_FILE"
echo "═══ NETWORK INTELLIGENCE ═══" >> "$LOOT_FILE"

# Count unique items
AP_COUNT=$(grep -E "^[0-9A-Fa-f]{2}:" "$TEMP_DIR"/*-01.csv 2>/dev/null | grep -v "Station" | wc -l)
CLIENT_COUNT=$(grep -E "^[0-9A-Fa-f]{2}:" "$TEMP_DIR"/*-01.csv 2>/dev/null | grep "Station" -A1000 | grep -E "^[0-9A-Fa-f]{2}:" | wc -l)

echo "Access Points: $AP_COUNT" >> "$LOOT_FILE"
echo "Clients: $CLIENT_COUNT" >> "$LOOT_FILE"
echo "" >> "$LOOT_FILE"

# Top networks
echo "═══ TOP NETWORKS ═══" >> "$LOOT_FILE"
grep -E "^[0-9A-Fa-f]{2}:" "$TEMP_DIR"/*-01.csv 2>/dev/null | head -20 | while IFS=',' read BSSID F2 F3 CH F5 F6 PRIV F8 F9 PWR F11 F12 F13 ESSID REST; do
    BSSID=$(echo "$BSSID" | tr -d ' ')
    ESSID=$(echo "$ESSID" | tr -d ' ')
    CH=$(echo "$CH" | tr -d ' ')
    PWR=$(echo "$PWR" | tr -d ' ')
    [ -n "$ESSID" ] && echo "  $ESSID ($BSSID) Ch:$CH Pwr:$PWR" >> "$LOOT_FILE"
done

# Probes collected
echo "" >> "$LOOT_FILE"
echo "═══ PROBE REQUESTS ═══" >> "$LOOT_FILE"
grep -A1000 "Station MAC" "$TEMP_DIR"/*-01.csv 2>/dev/null | grep -E "^[0-9A-Fa-f]{2}:" | while IFS=',' read MAC F2 F3 F4 F5 F6 PROBES; do
    MAC=$(echo "$MAC" | tr -d ' ')
    PROBES=$(echo "$PROBES" | tr -d ' ')
    [ -n "$PROBES" ] && echo "  $MAC probed: $PROBES" >> "$LOOT_FILE"
done

# Footer
cat >> "$LOOT_FILE" << FOOTER

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 End of Specter Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 NullSec Pineapple Suite | Developed by: bad-antics
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FOOTER

# Cleanup
airmon-ng stop $MON_IF 2>/dev/null
rm -rf "$TEMP_DIR"

PROMPT "SPECTER COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━
Ghost recon finished.

Networks: $AP_COUNT
Clients: $CLIENT_COUNT

Report: $LOOT_FILE

Zero packets transmitted.
No trace left behind.

━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics"

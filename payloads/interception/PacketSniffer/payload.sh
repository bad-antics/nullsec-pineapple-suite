#!/bin/bash
# Title: Packet Sniffer
# Author: NullSec
# Description: Advanced packet capture with protocol-aware filters and statistics
# Category: nullsec/interception

LOOT_DIR="/mmc/nullsec/packetsniffer"
mkdir -p "$LOOT_DIR"

PROMPT "PACKET SNIFFER

Advanced protocol-aware
packet capture engine.

Supports:
- HTTP/HTTPS traffic
- FTP credentials
- SMTP/IMAP email
- DNS queries
- Custom BPF filters
- Real-time stats

Press OK to configure."

# Find capture interface
IFACE=""
for i in wlan1mon wlan2mon mon0 br-lan eth0 wlan1 wlan0; do
    [ -d "/sys/class/net/$i" ] && IFACE=$i && break
done
[ -z "$IFACE" ] && { ERROR_DIALOG "No capture interface found!"; exit 1; }

PROMPT "CAPTURE MODE:

1. HTTP traffic
2. FTP sessions
3. Email (SMTP/IMAP)
4. DNS queries
5. All cleartext protocols
6. Full raw capture
7. Custom BPF filter

Interface: $IFACE

Select mode next."

CAP_MODE=$(NUMBER_PICKER "Mode (1-7):" 5)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) CAP_MODE=5 ;; esac

CUSTOM_FILTER=""
if [ "$CAP_MODE" -eq 7 ]; then
    CUSTOM_FILTER=$(TEXT_PICKER "BPF filter:" "tcp port 80 and host 192.168.1.1")
fi

# Build BPF filter
case $CAP_MODE in
    1) BPF="tcp port 80 or tcp port 8080"; PROTO_NAME="HTTP" ;;
    2) BPF="tcp port 21"; PROTO_NAME="FTP" ;;
    3) BPF="tcp port 25 or tcp port 110 or tcp port 143 or tcp port 993 or tcp port 587"; PROTO_NAME="Email" ;;
    4) BPF="udp port 53"; PROTO_NAME="DNS" ;;
    5) BPF="tcp port 21 or tcp port 23 or tcp port 25 or tcp port 80 or tcp port 110 or tcp port 143 or tcp port 8080"; PROTO_NAME="All Cleartext" ;;
    6) BPF=""; PROTO_NAME="Full Raw" ;;
    7) BPF="$CUSTOM_FILTER"; PROTO_NAME="Custom" ;;
esac

SNAP_LEN=$(NUMBER_PICKER "Snap length (0=full):" 0)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SNAP_LEN=0 ;; esac

DURATION=$(NUMBER_PICKER "Duration (seconds):" 300)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=300 ;; esac
[ $DURATION -lt 30 ] && DURATION=30
[ $DURATION -gt 3600 ] && DURATION=3600

OUTPUT_FORMAT=$(CONFIRMATION_DIALOG "Save as PCAP?

YES = Binary PCAP file
NO = Text log with
     extracted content")
[ "$OUTPUT_FORMAT" = "$DUCKYSCRIPT_USER_CONFIRMED" ] && SAVE_PCAP=1 || SAVE_PCAP=0

resp=$(CONFIRMATION_DIALOG "START CAPTURE?

Protocol: $PROTO_NAME
Interface: $IFACE
Duration: ${DURATION}s
Snap: $([ $SNAP_LEN -eq 0 ] && echo Full || echo ${SNAP_LEN}B)
Format: $([ $SAVE_PCAP -eq 1 ] && echo PCAP || echo Text)

Confirm?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M)
PCAP_FILE="$LOOT_DIR/capture_${PROTO_NAME}_$TIMESTAMP.pcap"
TEXT_LOG="$LOOT_DIR/capture_${PROTO_NAME}_$TIMESTAMP.log"
STATS_FILE="$LOOT_DIR/stats_$TIMESTAMP.txt"

LOG "Starting packet capture..."
SPINNER_START "Capturing $PROTO_NAME traffic..."

# Packet counter file
COUNTER_FILE="/tmp/pktsniff_counter_$$"
echo 0 > "$COUNTER_FILE"

if [ $SAVE_PCAP -eq 1 ]; then
    # Binary PCAP capture
    if [ -n "$BPF" ]; then
        timeout $DURATION tcpdump -i "$IFACE" -w "$PCAP_FILE" -s "$SNAP_LEN" $BPF 2>"$STATS_FILE" &
    else
        timeout $DURATION tcpdump -i "$IFACE" -w "$PCAP_FILE" -s "$SNAP_LEN" 2>"$STATS_FILE" &
    fi
    CAP_PID=$!
else
    # Text extraction mode
    if [ -n "$BPF" ]; then
        timeout $DURATION tcpdump -i "$IFACE" -A -s "$SNAP_LEN" -l $BPF 2>"$STATS_FILE" | \
            tee "$TEXT_LOG" | wc -l > "$COUNTER_FILE" &
    else
        timeout $DURATION tcpdump -i "$IFACE" -A -s "$SNAP_LEN" -l 2>"$STATS_FILE" | \
            tee "$TEXT_LOG" | wc -l > "$COUNTER_FILE" &
    fi
    CAP_PID=$!
fi

# Background stats collector
(
    while kill -0 $CAP_PID 2>/dev/null; do
        sleep 15
        if [ -f "$TEXT_LOG" ]; then
            {
                echo "--- Live Stats @ $(date '+%H:%M:%S') ---"
                echo "Lines captured: $(wc -l < "$TEXT_LOG" 2>/dev/null | tr -d ' ')"
                echo "Log size: $(du -h "$TEXT_LOG" 2>/dev/null | awk '{print $1}')"
                echo ""
            } >> "${STATS_FILE}.live"
        fi
    done
) &
STATS_PID=$!

# Wait for capture
wait $CAP_PID 2>/dev/null
kill $STATS_PID 2>/dev/null

SPINNER_STOP

# Generate final stats
PKT_COUNT=0
if [ -f "$PCAP_FILE" ]; then
    PKT_COUNT=$(tcpdump -r "$PCAP_FILE" 2>/dev/null | wc -l | tr -d ' ')
    FILE_SIZE=$(du -h "$PCAP_FILE" | awk '{print $1}')
    OUTPUT_FILE="$PCAP_FILE"
elif [ -f "$TEXT_LOG" ]; then
    PKT_COUNT=$(wc -l < "$TEXT_LOG" | tr -d ' ')
    FILE_SIZE=$(du -h "$TEXT_LOG" | awk '{print $1}')
    OUTPUT_FILE="$TEXT_LOG"

    # Extract interesting items
    CRED_FILE="$LOOT_DIR/extracted_$TIMESTAMP.txt"
    grep -iE "user|pass|login|auth|cookie|token|session" "$TEXT_LOG" 2>/dev/null | \
        sort -u > "$CRED_FILE"
    CRED_COUNT=$(wc -l < "$CRED_FILE" 2>/dev/null | tr -d ' ')
else
    FILE_SIZE="0"
    OUTPUT_FILE="(none)"
fi

# Tcpdump stderr stats
TCPDUMP_STATS=""
[ -f "$STATS_FILE" ] && TCPDUMP_STATS=$(tail -3 "$STATS_FILE" 2>/dev/null)

PROMPT "CAPTURE COMPLETE

Protocol: $PROTO_NAME
Duration: ${DURATION}s
Packets: $PKT_COUNT
File size: $FILE_SIZE
$([ -n "$CRED_COUNT" ] && [ "$CRED_COUNT" -gt 0 ] && echo "Creds found: $CRED_COUNT")

$TCPDUMP_STATS

Saved to: $LOOT_DIR/

Press OK to exit."

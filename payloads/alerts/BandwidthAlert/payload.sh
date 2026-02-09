#!/bin/bash
# Title: Bandwidth Alert
# Author: NullSec
# Description: Monitor bandwidth usage and alert when thresholds are exceeded
# Category: nullsec/alerts

LOOT_DIR="/mmc/nullsec/bandwidthalert"
mkdir -p "$LOOT_DIR"

PROMPT "BANDWIDTH ALERT

Monitor network bandwidth
usage and alert when
thresholds are exceeded.

Features:
- Per-client tracking
- TX/RX monitoring
- Threshold alerts
- Usage logging

Press OK to configure."

# Detect network interface
NET_IF=""
for iface in br-lan wlan0 eth0; do
    [ -d "/sys/class/net/$iface" ] && NET_IF="$iface" && break
done
[ -z "$NET_IF" ] && { ERROR_DIALOG "No network interface!"; exit 1; }

LOG "Interface: $NET_IF"

PROMPT "ALERT THRESHOLD:

Set bandwidth limit in KB/s.
Alert triggers when any
client exceeds this rate.

1. 100 KB/s (low)
2. 500 KB/s (medium)
3. 1000 KB/s (high)
4. Custom

Select next."

THRESH_SEL=$(NUMBER_PICKER "Threshold (1-4):" 2)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) THRESH_SEL=2 ;; esac

case $THRESH_SEL in
    1) BW_THRESH=100 ;;
    2) BW_THRESH=500 ;;
    3) BW_THRESH=1000 ;;
    4)
        BW_THRESH=$(NUMBER_PICKER "KB/s limit:" 500)
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) BW_THRESH=500 ;; esac
        ;;
    *) BW_THRESH=500 ;;
esac
[ "$BW_THRESH" -lt 10 ] && BW_THRESH=10

DURATION=$(NUMBER_PICKER "Monitor (minutes):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=30 ;; esac
[ "$DURATION" -lt 1 ] && DURATION=1
[ "$DURATION" -gt 1440 ] && DURATION=1440

INTERVAL=$(NUMBER_PICKER "Check interval (sec):" 10)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) INTERVAL=10 ;; esac
[ "$INTERVAL" -lt 5 ] && INTERVAL=5
[ "$INTERVAL" -gt 60 ] && INTERVAL=60

resp=$(CONFIRMATION_DIALOG "START MONITORING?

Interface: $NET_IF
Threshold: ${BW_THRESH} KB/s
Duration: ${DURATION} min
Interval: ${INTERVAL}s

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG_FILE="$LOOT_DIR/bw_$(date +%Y%m%d_%H%M).log"
echo "=== BANDWIDTH ALERT LOG ===" > "$LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"
echo "Threshold: ${BW_THRESH} KB/s" >> "$LOG_FILE"
echo "============================" >> "$LOG_FILE"

# Get initial byte counts per client
get_client_bytes() {
    local tmpfile="$1"
    > "$tmpfile"
    # Use iptables accounting or /proc/net/arp + interface stats
    while read -r ip mac; do
        [ -z "$ip" ] && continue
        # Get byte count via iptables or nf_conntrack
        bytes=$(iptables -L FORWARD -v -n -x 2>/dev/null | grep "$ip" | awk '{sum+=$2} END{print sum+0}')
        echo "$ip $mac $bytes" >> "$tmpfile"
    done < <(arp -i "$NET_IF" -n 2>/dev/null | awk '/ether/{print $1,$4}')
}

get_client_bytes /tmp/bw_prev.txt

END_TIME=$(($(date +%s) + DURATION * 60))
ALERT_COUNT=0
TOTAL_BYTES=0

LOG "Bandwidth monitoring started..."
SPINNER_START "Monitoring bandwidth..."

while [ $(date +%s) -lt $END_TIME ]; do
    sleep "$INTERVAL"

    # Get interface-level stats
    RX1=$(cat "/sys/class/net/$NET_IF/statistics/rx_bytes" 2>/dev/null || echo 0)
    TX1=$(cat "/sys/class/net/$NET_IF/statistics/tx_bytes" 2>/dev/null || echo 0)
    sleep 1
    RX2=$(cat "/sys/class/net/$NET_IF/statistics/rx_bytes" 2>/dev/null || echo 0)
    TX2=$(cat "/sys/class/net/$NET_IF/statistics/tx_bytes" 2>/dev/null || echo 0)

    RX_RATE=$(( (RX2 - RX1) / 1024 ))
    TX_RATE=$(( (TX2 - TX1) / 1024 ))
    TOTAL_RATE=$((RX_RATE + TX_RATE))
    TOTAL_BYTES=$((TOTAL_BYTES + RX2 - RX1 + TX2 - TX1))

    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

    # Per-client check via station dump
    TOP_CLIENT=""
    TOP_RATE=0
    while read -r line; do
        [[ "$line" =~ Station ]] && CUR_MAC=$(echo "$line" | awk '{print $2}')
        if [[ "$line" =~ "rx bytes" ]]; then
            CUR_RX=$(echo "$line" | awk '{print $3}')
        fi
        if [[ "$line" =~ "tx bytes" ]]; then
            CUR_TX=$(echo "$line" | awk '{print $3}')
            CUR_TOTAL=$(( (CUR_RX + CUR_TX) / 1024 ))
            if [ "$CUR_TOTAL" -gt "$TOP_RATE" ]; then
                TOP_RATE=$CUR_TOTAL
                TOP_CLIENT=$CUR_MAC
            fi
        fi
    done < <(iw dev "$NET_IF" station dump 2>/dev/null)

    # Log current rates
    echo "[$TIMESTAMP] Total: ${TOTAL_RATE} KB/s (RX:${RX_RATE} TX:${TX_RATE})" >> "$LOG_FILE"

    # Check threshold
    if [ "$TOTAL_RATE" -ge "$BW_THRESH" ]; then
        ALERT_COUNT=$((ALERT_COUNT + 1))
        echo "[$TIMESTAMP] ALERT: ${TOTAL_RATE} KB/s exceeds ${BW_THRESH} KB/s" >> "$LOG_FILE"
        [ -n "$TOP_CLIENT" ] && echo "  Top client: $TOP_CLIENT" >> "$LOG_FILE"
        LOG "BW alert: ${TOTAL_RATE} KB/s"

        SPINNER_STOP
        PROMPT "⚠ BANDWIDTH EXCEEDED!

Current: ${TOTAL_RATE} KB/s
Limit: ${BW_THRESH} KB/s
RX: ${RX_RATE} KB/s
TX: ${TX_RATE} KB/s
$([ -n "$TOP_CLIENT" ] && echo "Top: $TOP_CLIENT")

Alerts: $ALERT_COUNT

Press OK to continue."
        SPINNER_START "Monitoring..."
    fi
done

SPINNER_STOP
rm -f /tmp/bw_prev.txt

TOTAL_MB=$((TOTAL_BYTES / 1048576))

echo "============================" >> "$LOG_FILE"
echo "Ended: $(date)" >> "$LOG_FILE"
echo "Total data: ${TOTAL_MB} MB" >> "$LOG_FILE"
echo "Alerts: $ALERT_COUNT" >> "$LOG_FILE"

PROMPT "BW MONITORING COMPLETE

Duration: ${DURATION} min
Total data: ${TOTAL_MB} MB
Alerts triggered: $ALERT_COUNT

Log saved to:
$LOG_FILE

Press OK to exit."

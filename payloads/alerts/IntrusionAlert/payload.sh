#!/bin/bash
# Title: Intrusion Alert
# Author: NullSec
# Description: Network intrusion detection for port scans, ARP spoofing, and suspicious traffic
# Category: nullsec/alerts

LOOT_DIR="/mmc/nullsec/intrusionalert"
mkdir -p "$LOOT_DIR"

PROMPT "INTRUSION ALERT

Lightweight network IDS
for the WiFi Pineapple.

Detects:
- Port scanning activity
- ARP spoofing attacks
- SYN flood attempts
- Unusual traffic patterns

Press OK to configure."

# Detect network interface
NET_IF=""
for iface in br-lan eth0 wlan0; do
    [ -d "/sys/class/net/$iface" ] && NET_IF="$iface" && break
done
[ -z "$NET_IF" ] && { ERROR_DIALOG "No network interface!"; exit 1; }

LOG "Network interface: $NET_IF"

PROMPT "DETECTION MODULES:

All modules enabled:
- Port scan detection
- ARP spoof detection
- SYN flood detection
- DNS anomaly detection

Press OK to set duration."

DURATION=$(NUMBER_PICKER "Monitor (minutes):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=30 ;; esac
[ "$DURATION" -lt 1 ] && DURATION=1
[ "$DURATION" -gt 1440 ] && DURATION=1440

SCAN_THRESH=$(NUMBER_PICKER "Port scan threshold:" 20)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SCAN_THRESH=20 ;; esac
[ "$SCAN_THRESH" -lt 5 ] && SCAN_THRESH=5

resp=$(CONFIRMATION_DIALOG "START IDS?

Interface: $NET_IF
Duration: ${DURATION} min
Scan threshold: $SCAN_THRESH

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG_FILE="$LOOT_DIR/ids_$(date +%Y%m%d_%H%M).log"
echo "=== INTRUSION ALERT LOG ===" > "$LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"
echo "Interface: $NET_IF" >> "$LOG_FILE"
echo "===========================" >> "$LOG_FILE"

# Take ARP baseline
arp -i "$NET_IF" -n 2>/dev/null | awk '/ether/{print $1,$4}' | sort > /tmp/ids_arp_base.txt

END_TIME=$(($(date +%s) + DURATION * 60))
ALERT_COUNT=0
CYCLE=0

LOG "IDS monitoring started..."
SPINNER_START "Monitoring network..."

while [ $(date +%s) -lt $END_TIME ]; do
    CYCLE=$((CYCLE + 1))
    ALERTS_THIS_CYCLE=0
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

    # --- Port Scan Detection ---
    SYN_COUNT=$(timeout 5 tcpdump -i "$NET_IF" -c 200 'tcp[tcpflags] & tcp-syn != 0' 2>/dev/null | \
        awk '{print $3}' | sort | uniq -c | sort -rn | head -1 | awk '{print $1}')
    SYN_COUNT=${SYN_COUNT:-0}

    if [ "$SYN_COUNT" -ge "$SCAN_THRESH" ]; then
        SRC_IP=$(timeout 3 tcpdump -i "$NET_IF" -c 50 'tcp[tcpflags] & tcp-syn != 0' 2>/dev/null | \
            awk '{print $3}' | cut -d'.' -f1-4 | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
        ALERT_COUNT=$((ALERT_COUNT + 1))
        ALERTS_THIS_CYCLE=$((ALERTS_THIS_CYCLE + 1))
        echo "[$TIMESTAMP] PORT_SCAN from $SRC_IP ($SYN_COUNT SYNs)" >> "$LOG_FILE"
        LOG "Port scan: $SRC_IP"
    fi

    # --- ARP Spoof Detection ---
    arp -i "$NET_IF" -n 2>/dev/null | awk '/ether/{print $1,$4}' | sort > /tmp/ids_arp_now.txt
    while read -r ip mac; do
        OLD_MAC=$(grep "^$ip " /tmp/ids_arp_base.txt 2>/dev/null | awk '{print $2}')
        if [ -n "$OLD_MAC" ] && [ "$OLD_MAC" != "$mac" ]; then
            ALERT_COUNT=$((ALERT_COUNT + 1))
            ALERTS_THIS_CYCLE=$((ALERTS_THIS_CYCLE + 1))
            echo "[$TIMESTAMP] ARP_SPOOF IP:$ip was:$OLD_MAC now:$mac" >> "$LOG_FILE"
            LOG "ARP spoof: $ip"
        fi
    done < /tmp/ids_arp_now.txt
    cp /tmp/ids_arp_now.txt /tmp/ids_arp_base.txt

    # --- SYN Flood Detection ---
    FLOOD=$(timeout 3 tcpdump -i "$NET_IF" -c 500 'tcp[tcpflags] == tcp-syn' 2>/dev/null | wc -l)
    if [ "$FLOOD" -ge 100 ]; then
        ALERT_COUNT=$((ALERT_COUNT + 1))
        ALERTS_THIS_CYCLE=$((ALERTS_THIS_CYCLE + 1))
        echo "[$TIMESTAMP] SYN_FLOOD $FLOOD SYNs in 3s" >> "$LOG_FILE"
        LOG "SYN flood detected!"
    fi

    # --- DNS Anomaly Detection ---
    DNS_COUNT=$(timeout 3 tcpdump -i "$NET_IF" -c 200 'port 53' 2>/dev/null | wc -l)
    if [ "$DNS_COUNT" -ge 150 ]; then
        ALERT_COUNT=$((ALERT_COUNT + 1))
        ALERTS_THIS_CYCLE=$((ALERTS_THIS_CYCLE + 1))
        echo "[$TIMESTAMP] DNS_ANOMALY $DNS_COUNT queries in 3s" >> "$LOG_FILE"
    fi

    # Show alert if anything triggered
    if [ "$ALERTS_THIS_CYCLE" -gt 0 ]; then
        SPINNER_STOP
        PROMPT "⚠ INTRUSION DETECTED!

$ALERTS_THIS_CYCLE alerts this cycle
Total alerts: $ALERT_COUNT

Check log for details.

Press OK to continue."
        SPINNER_START "Monitoring..."
    fi

    sleep 5
done

SPINNER_STOP
rm -f /tmp/ids_arp_base.txt /tmp/ids_arp_now.txt

echo "===========================" >> "$LOG_FILE"
echo "Ended: $(date)" >> "$LOG_FILE"
echo "Total alerts: $ALERT_COUNT" >> "$LOG_FILE"
echo "Cycles run: $CYCLE" >> "$LOG_FILE"

PROMPT "IDS MONITORING COMPLETE

Duration: ${DURATION} min
Total alerts: $ALERT_COUNT
Scan cycles: $CYCLE

Log saved to:
$LOG_FILE

Press OK to exit."

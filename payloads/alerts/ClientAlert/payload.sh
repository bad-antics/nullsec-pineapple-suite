#!/bin/bash
# Title: Client Alert
# Author: NullSec
# Description: Alerts when new clients connect to the Pineapple AP
# Category: nullsec/alerts

LOOT_DIR="/mmc/nullsec/clientalert"
mkdir -p "$LOOT_DIR"

PROMPT "CLIENT ALERT

Monitor for new clients
connecting to your AP.

Features:
- Connection detection
- MAC address logging
- Vendor identification
- Real-time alerts

Press OK to configure."

# Check AP interface
AP_IF=""
for iface in wlan0 br-lan; do
    [ -d "/sys/class/net/$iface" ] && AP_IF="$iface" && break
done
[ -z "$AP_IF" ] && { ERROR_DIALOG "No AP interface found!

Ensure the Pineapple AP
is running."; exit 1; }

LOG "AP interface: $AP_IF"

DURATION=$(NUMBER_PICKER "Monitor (minutes):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=30 ;; esac
[ "$DURATION" -lt 1 ] && DURATION=1
[ "$DURATION" -gt 1440 ] && DURATION=1440

POLL_RATE=$(NUMBER_PICKER "Check interval (sec):" 10)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) POLL_RATE=10 ;; esac
[ "$POLL_RATE" -lt 3 ] && POLL_RATE=3
[ "$POLL_RATE" -gt 60 ] && POLL_RATE=60

resp=$(CONFIRMATION_DIALOG "START CLIENT ALERT?

Interface: $AP_IF
Duration: ${DURATION} min
Poll rate: ${POLL_RATE}s

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG_FILE="$LOOT_DIR/clients_$(date +%Y%m%d_%H%M).log"
echo "=== CLIENT ALERT LOG ===" > "$LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"
echo "Interface: $AP_IF" >> "$LOG_FILE"
echo "========================" >> "$LOG_FILE"

# Vendor lookup function
get_vendor() {
    local mac_prefix=$(echo "$1" | tr -d ':' | head -c 6 | tr 'a-f' 'A-F')
    local vendor=""
    if [ -f /usr/share/ieee-oui.txt ]; then
        vendor=$(grep -i "$mac_prefix" /usr/share/ieee-oui.txt 2>/dev/null | head -1 | cut -d')' -f2 | sed 's/^[[:space:]]*//')
    elif [ -f /etc/oui.txt ]; then
        vendor=$(grep -i "$mac_prefix" /etc/oui.txt 2>/dev/null | head -1 | awk -F'\t' '{print $NF}')
    fi
    [ -z "$vendor" ] && vendor="Unknown"
    echo "$vendor" | head -c 20
}

# Snapshot current clients
arp -i "$AP_IF" -n 2>/dev/null | awk '/ether/{print $4}' | sort -u > /tmp/ca_known.txt
iw dev "$AP_IF" station dump 2>/dev/null | awk '/Station/{print $2}' | sort -u >> /tmp/ca_known.txt
sort -u /tmp/ca_known.txt -o /tmp/ca_known.txt

KNOWN=$(wc -l < /tmp/ca_known.txt)
NEW_COUNT=0
END_TIME=$(($(date +%s) + DURATION * 60))

LOG "Monitoring clients (${KNOWN} initial)..."
SPINNER_START "Watching for new clients..."

while [ $(date +%s) -lt $END_TIME ]; do
    sleep "$POLL_RATE"

    # Get current clients from ARP and station dump
    arp -i "$AP_IF" -n 2>/dev/null | awk '/ether/{print $4}' | sort -u > /tmp/ca_current.txt
    iw dev "$AP_IF" station dump 2>/dev/null | awk '/Station/{print $2}' | sort -u >> /tmp/ca_current.txt
    sort -u /tmp/ca_current.txt -o /tmp/ca_current.txt

    # Find new clients
    NEW_MACS=$(comm -13 /tmp/ca_known.txt /tmp/ca_current.txt 2>/dev/null)

    if [ -n "$NEW_MACS" ]; then
        while IFS= read -r MAC; do
            [ -z "$MAC" ] && continue
            TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
            VENDOR=$(get_vendor "$MAC")
            IP=$(arp -n 2>/dev/null | grep -i "$MAC" | awk '{print $1}' | head -1)
            [ -z "$IP" ] && IP="pending"

            NEW_COUNT=$((NEW_COUNT + 1))
            echo "[$TIMESTAMP] NEW: $MAC ($VENDOR) IP:$IP" >> "$LOG_FILE"
            LOG "New client: $MAC"

            SPINNER_STOP
            PROMPT "⚠ NEW CLIENT!

MAC: $MAC
Vendor: $VENDOR
IP: $IP
Time: $TIMESTAMP

Total new: $NEW_COUNT

Press OK to continue."
            SPINNER_START "Watching..."
        done <<< "$NEW_MACS"

        cp /tmp/ca_current.txt /tmp/ca_known.txt
    fi
done

SPINNER_STOP
rm -f /tmp/ca_known.txt /tmp/ca_current.txt

echo "========================" >> "$LOG_FILE"
echo "Ended: $(date)" >> "$LOG_FILE"
echo "New clients: $NEW_COUNT" >> "$LOG_FILE"

PROMPT "CLIENT ALERT COMPLETE

Duration: ${DURATION} min
Initial clients: $KNOWN
New clients: $NEW_COUNT

Log saved to:
$LOG_FILE

Press OK to exit."

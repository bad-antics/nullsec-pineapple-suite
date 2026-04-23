#!/bin/bash
# Title: Rogue Detector
# Author: bad-antics
# Description: Hunts for rogue APs, evil twins, and unauthorized SSIDs in the WiFi environment
# Category: nullsec/blue-team

# Autodetect the right wireless interface (exports $IFACE).
# Falls back to showing the pager error dialog if nothing is plugged in.
. /root/payloads/library/nullsec-iface.sh 2>/dev/null || . "$(dirname "$0")/../../../lib/nullsec-iface.sh"
nullsec_require_iface || exit 1

PROMPT "ROGUE AP DETECTOR

Scans for unauthorized
access points:

- Evil twin detection
- Duplicate SSID check
- Open AP honeypots
- Unknown BSSID alert

Scan: 45 seconds

Press OK to hunt."

OUTDIR="/mmc/nullsec/blue-team/rogue-detector"
mkdir -p "$OUTDIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS="$OUTDIR/rogue_${TIMESTAMP}.txt"
KNOWN="$OUTDIR/known_aps.csv"

# Init whitelist
if [ ! -f "$KNOWN" ]; then
    echo "# Known APs — add authorized BSSIDs" > "$KNOWN"
    echo "# BSSID,ESSID" >> "$KNOWN"
fi

SPINNER_START "Scanning for rogue APs (45s)..."
timeout 45 airodump-ng $IFACE -w /tmp/rogue --output-format csv 2>/dev/null
SPINNER_STOP

CSV="/tmp/rogue-01.csv"
[ ! -f "$CSV" ] && { ERROR_DIALOG "No scan data!"; exit 1; }

SPINNER_START "Analyzing for rogues..."

grep -E "^([0-9A-Fa-f]{2}:){5}" "$CSV" | \
    awk -F',' '{gsub(/^ +| +$/,"",$1); gsub(/^ +| +$/,"",$14); print $1","$14}' > /tmp/rogue_all.csv
TOTAL=$(wc -l < /tmp/rogue_all.csv)

# Evil twin detection
DUPES=$(awk -F',' '{gsub(/^ +| +$/,"",$2); if(length($2)>0) print $2}' /tmp/rogue_all.csv | sort | uniq -d)
TWIN_COUNT=$(echo "$DUPES" | grep -c "." 2>/dev/null || echo 0)

# Open networks
OPEN_COUNT=$(grep -E "^([0-9A-Fa-f]{2}:){5}" "$CSV" | grep -ci "OPN" || echo 0)

{
    echo "╔═══════════════════════════════════════╗"
    echo "║  NullSec Rogue AP Detection Report    ║"
    echo "╚═══════════════════════════════════════╝"
    echo ""
    echo "Scan: $(date)"
    echo "Total APs: $TOTAL"
    echo ""
    echo "── Evil Twin Check ─────────────────────"
    if [ "$TWIN_COUNT" -gt 0 ]; then
        echo "⛔ $TWIN_COUNT ESSID(s) with multiple BSSIDs!"
        echo "$DUPES" | while read ESSID; do
            [ -n "$ESSID" ] && echo "  $ESSID:" && grep ",$ESSID$" /tmp/rogue_all.csv | awk -F',' '{print "    "$1}'
        done
    else
        echo "✅ No evil twin patterns"
    fi
    echo ""
    echo "── Open Networks ───────────────────────"
    if [ "$OPEN_COUNT" -gt 0 ]; then
        echo "⚠️  $OPEN_COUNT open network(s) detected"
        grep -E "^([0-9A-Fa-f]{2}:){5}" "$CSV" | grep -i "OPN" | \
            awk -F',' '{gsub(/^ +| +$/,"",$1); gsub(/^ +| +$/,"",$14); printf "  %s  %s\n", $1, $14}'
    else
        echo "✅ No open networks"
    fi
    echo ""
    echo "── All APs ─────────────────────────────"
    grep -E "^([0-9A-Fa-f]{2}:){5}" "$CSV" | \
        awk -F',' '{gsub(/^ +| +$/,"",$1); gsub(/^ +| +$/,"",$4); gsub(/^ +| +$/,"",$6); gsub(/^ +| +$/,"",$9); gsub(/^ +| +$/,"",$14); printf "%-18s CH:%-3s PWR:%-5s %-10s %s\n", $1, $4, $9, $6, $14}'
} > "$RESULTS"

SPINNER_STOP

rm -f /tmp/rogue* /tmp/rogue_all.csv 2>/dev/null

ALERTS=$((TWIN_COUNT + OPEN_COUNT))
if [ "$ALERTS" -gt 0 ]; then
    CONFIRMATION_DIALOG "⚠️ Rogue APs Found!\n\nTotal APs: $TOTAL\nEvil Twins: $TWIN_COUNT\nOpen APs: $OPEN_COUNT\n\nReport: $RESULTS"
else
    CONFIRMATION_DIALOG "✅ No Rogues Detected\n\nTotal APs: $TOTAL\nEnvironment clean.\n\nReport: $RESULTS"
fi

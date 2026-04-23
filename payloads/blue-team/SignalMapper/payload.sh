#!/bin/bash
# Title: Signal Mapper
# Author: bad-antics
# Description: Maps WiFi signal strength from multiple sample points to identify coverage gaps
# Category: nullsec/blue-team

# Autodetect the right wireless interface (exports $IFACE).
# Falls back to showing the pager error dialog if nothing is plugged in.
. /root/payloads/library/nullsec-iface.sh 2>/dev/null || . "$(dirname "$0")/../../../lib/nullsec-iface.sh"
nullsec_require_iface || exit 1

PROMPT "SIGNAL MAPPER

Multi-point WiFi signal
strength mapper.

Captures 3 sample points
to map coverage.

Move device between scans
to map different areas.

Press OK to start."

OUTDIR="/mmc/nullsec/blue-team/signal-mapper"
mkdir -p "$OUTDIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
MAPFILE="$OUTDIR/signal_map_${TIMESTAMP}.csv"
REPORT="$OUTDIR/signal_report_${TIMESTAMP}.txt"

echo "sample,timestamp,bssid,essid,channel,power,security" > "$MAPFILE"

SAMPLES=3
SAMPLE_TIME=10

for POINT in 1 2 3; do
    if [ "$POINT" -gt 1 ]; then
        PROMPT "POINT $POINT of $SAMPLES\n\nMove to a new location,\nthen press OK to scan."
    fi

    SPINNER_START "Point $POINT/$SAMPLES (${SAMPLE_TIME}s)..."
    timeout $SAMPLE_TIME airodump-ng $IFACE -w /tmp/sigmap_${POINT} --output-format csv 2>/dev/null
    SPINNER_STOP

    CSV="/tmp/sigmap_${POINT}-01.csv"
    if [ -f "$CSV" ]; then
        grep -E "^([0-9A-Fa-f]{2}:){5}" "$CSV" | \
            awk -F',' -v pt="$POINT" -v ts="$(date +%H:%M:%S)" '{
                gsub(/^ +| +$/,"",$1); gsub(/^ +| +$/,"",$14);
                gsub(/^ +| +$/,"",$4); gsub(/^ +| +$/,"",$9); gsub(/^ +| +$/,"",$6);
                printf "%s,%s,%s,%s,%s,%s,%s\n", pt, ts, $1, $14, $4, $9, $6
            }' >> "$MAPFILE"
    fi
    rm -f /tmp/sigmap_${POINT}* 2>/dev/null
done

SPINNER_START "Analyzing coverage..."

UNIQUE_APS=$(tail -n +2 "$MAPFILE" | awk -F',' '{print $3}' | sort -u | wc -l)
FULL_COV=$(tail -n +2 "$MAPFILE" | awk -F',' '{print $1","$3}' | sort -u | \
    awk -F',' '{count[$2]++} END {for(k in count) if(count[k]>=3) c++; print c+0}')

{
    echo "╔═══════════════════════════════════════╗"
    echo "║  NullSec Signal Map Report            ║"
    echo "╚═══════════════════════════════════════╝"
    echo ""
    echo "Date: $(date)"
    echo "Sample Points: $SAMPLES"
    echo "Unique APs: $UNIQUE_APS"
    echo "Full Coverage: $FULL_COV"
    echo "Partial: $((UNIQUE_APS - FULL_COV))"
    echo ""
    echo "── Signal by AP ──────────────────────"
    tail -n +2 "$MAPFILE" | awk -F',' '{key=$3; name[$3]=$4; sum[key]+=$6; count[key]++; if(!max[key]||$6>max[key]) max[key]=$6; if(!min[key]||$6<min[key]) min[key]=$6} END {for(k in sum) printf "%-18s %-15s AVG:%4.0f MIN:%d MAX:%d (%d pts)\n", k, name[k], sum[k]/count[k], min[k], max[k], count[k]}'
    echo ""
    echo "CSV: $MAPFILE"
} > "$REPORT"

SPINNER_STOP

CONFIRMATION_DIALOG "📊 Signal Map Complete\n\nSample Points: $SAMPLES\nUnique APs: $UNIQUE_APS\nFull Coverage: $FULL_COV\nPartial: $((UNIQUE_APS - FULL_COV))\n\nReport: $REPORT"

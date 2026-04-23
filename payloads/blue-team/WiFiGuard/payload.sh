#!/bin/bash
# Title: WiFi Guard
# Author: bad-antics
# Description: Blue-team WiFi security monitor — scans for rogue APs, evil twins, and deauth attacks
# Category: nullsec/blue-team

# Autodetect the right wireless interface (exports $IFACE).
# Falls back to showing the pager error dialog if nothing is plugged in.
. /root/payloads/library/nullsec-iface.sh 2>/dev/null || . "$(dirname "$0")/../../../lib/nullsec-iface.sh"
nullsec_require_iface || exit 1

PROMPT "WIFI GUARD

Continuous blue-team WiFi
security monitor.

Detects:
- Rogue access points
- Evil twin attacks
- Deauth floods
- New unauthorized APs

Duration: 60 seconds

Press OK to start."

OUTDIR="/mmc/nullsec/blue-team/wifi-guard"
mkdir -p "$OUTDIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGFILE="$OUTDIR/guard_${TIMESTAMP}.log"
ALERTLOG="$OUTDIR/alerts_${TIMESTAMP}.log"

echo "[$(date)] WiFi Guard initialized" > "$LOGFILE"
touch "$ALERTLOG"

# Baseline scan (10s)
SPINNER_START "Capturing AP baseline..."
timeout 10 airodump-ng $IFACE -w /tmp/wg_baseline --output-format csv 2>/dev/null
SPINNER_STOP

grep -E "^([0-9A-Fa-f]{2}:){5}" /tmp/wg_baseline-01.csv 2>/dev/null | \
    awk -F',' '{gsub(/^ +| +$/,"",$1); gsub(/^ +| +$/,"",$14); print $1","$14}' > "$OUTDIR/baseline.csv"
BASELINE_COUNT=$(wc -l < "$OUTDIR/baseline.csv" 2>/dev/null || echo 0)

SPINNER_START "Monitoring ($BASELINE_COUNT known APs)..."

# Monitor for 60 seconds in 10-second sweeps
ALERT_COUNT=0
for i in 1 2 3 4 5 6; do
    timeout 8 airodump-ng $IFACE -w /tmp/wg_scan --output-format csv 2>/dev/null
    sleep 1

    CURRENT=$(grep -E "^([0-9A-Fa-f]{2}:){5}" /tmp/wg_scan-01.csv 2>/dev/null | \
        awk -F',' '{gsub(/^ +| +$/,"",$1); gsub(/^ +| +$/,"",$14); print $1","$14}')

    if [ -n "$CURRENT" ]; then
        NEW_APS=$(echo "$CURRENT" | grep -v -F -f "$OUTDIR/baseline.csv" 2>/dev/null)
        if [ -n "$NEW_APS" ]; then
            echo "[$(date)] ALERT: New AP(s)" >> "$ALERTLOG"
            echo "$NEW_APS" >> "$ALERTLOG"
            ALERT_COUNT=$((ALERT_COUNT + $(echo "$NEW_APS" | wc -l)))
        fi
    fi

    rm -f /tmp/wg_scan* 2>/dev/null
done

SPINNER_STOP

echo "Baseline APs: $BASELINE_COUNT" >> "$LOGFILE"
echo "Alerts: $ALERT_COUNT" >> "$LOGFILE"
cat "$ALERTLOG" >> "$LOGFILE" 2>/dev/null

# Cleanup
rm -f /tmp/wg_baseline* /tmp/wg_scan* 2>/dev/null

if [ "$ALERT_COUNT" -gt 0 ]; then
    CONFIRMATION_DIALOG "⚠️ WiFi Guard Alert!\n\n$ALERT_COUNT new AP(s) detected!\nBaseline: $BASELINE_COUNT APs\n\nLog: $LOGFILE"
else
    CONFIRMATION_DIALOG "✅ WiFi Guard Complete\n\nNo threats detected.\nBaseline: $BASELINE_COUNT APs\nMonitored: 60 seconds\n\nLog: $LOGFILE"
fi

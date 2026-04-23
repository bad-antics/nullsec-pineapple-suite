#!/bin/bash
# Title: Compliance Auditor
# Author: bad-antics
# Description: Audits WiFi networks against security best practices — WPA3, WEP, open networks, WPS
# Category: nullsec/blue-team

# Autodetect the right wireless interface (exports $IFACE).
# Falls back to showing the pager error dialog if nothing is plugged in.
. /root/payloads/library/nullsec-iface.sh 2>/dev/null || . "$(dirname "$0")/../../../lib/nullsec-iface.sh"
nullsec_require_iface || exit 1

PROMPT "COMPLIANCE AUDITOR

WiFi security policy audit.

Checks for:
- WEP (broken encryption)
- Open networks (no auth)
- WPA3 adoption
- Hidden SSIDs

Scan: 30 seconds

Press OK to audit."

OUTDIR="/mmc/nullsec/blue-team/compliance"
mkdir -p "$OUTDIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT="$OUTDIR/audit_${TIMESTAMP}.txt"

SPINNER_START "Scanning all channels (30s)..."
timeout 30 airodump-ng $IFACE -w /tmp/compliance --output-format csv 2>/dev/null
SPINNER_STOP

CSV="/tmp/compliance-01.csv"
[ ! -f "$CSV" ] && { ERROR_DIALOG "No scan data captured!"; exit 1; }

SPINNER_START "Analyzing compliance..."

TOTAL=$(grep -cE "^([0-9A-Fa-f]{2}:){5}" "$CSV" 2>/dev/null || echo 0)
WPA3=$(grep -ci "WPA3" "$CSV" 2>/dev/null || echo 0)
WPA2=$(grep -i "WPA2" "$CSV" 2>/dev/null | grep -cvi "WPA3" || echo 0)
WEP=$(grep -ci "WEP" "$CSV" 2>/dev/null || echo 0)
OPEN=$(grep -E "^([0-9A-Fa-f]{2}:){5}" "$CSV" 2>/dev/null | grep -cE ",\s*OPN\s*," || echo 0)
HIDDEN=$(grep -E "^([0-9A-Fa-f]{2}:){5}" "$CSV" 2>/dev/null | awk -F',' '{gsub(/^ +| +$/,"",$14); if(length($14)<1) c++} END{print c+0}')
FAILS=$((WEP + OPEN))

{
    echo "╔═══════════════════════════════════════╗"
    echo "║  NullSec Compliance Audit Report      ║"
    echo "╚═══════════════════════════════════════╝"
    echo ""
    echo "Date: $(date)"
    echo ""
    echo "── Summary ─────────────────────────────"
    echo "Total Networks:    $TOTAL"
    echo "WPA3 (Strongest):  $WPA3"
    echo "WPA2 (Standard):   $WPA2"
    echo "WEP (Broken):      $WEP"
    echo "Open (No Auth):    $OPEN"
    echo "Hidden SSIDs:      $HIDDEN"
    echo ""
    echo "── Findings ────────────────────────────"
    [ "$WEP" -gt 0 ] && echo "⛔ FAIL: $WEP WEP network(s)"
    [ "$OPEN" -gt 0 ] && echo "⛔ FAIL: $OPEN open network(s)"
    [ "$WPA3" -eq 0 ] && [ "$TOTAL" -gt 0 ] && echo "⚠️  WARN: No WPA3 adoption"
    [ "$HIDDEN" -gt 0 ] && echo "ℹ️  INFO: $HIDDEN hidden network(s)"
    [ "$FAILS" -eq 0 ] && echo "✅ PASS: No critical issues"
    echo ""
    echo "── Network Inventory ─────────────────"
    grep -E "^([0-9A-Fa-f]{2}:){5}" "$CSV" | sort -t',' -k9 -n -r | \
        awk -F',' '{gsub(/^ +| +$/,"",$1); gsub(/^ +| +$/,"",$4); gsub(/^ +| +$/,"",$6); gsub(/^ +| +$/,"",$9); gsub(/^ +| +$/,"",$14); printf "%-18s CH:%-3s PWR:%-5s %-12s %s\n", $1, $4, $9, $6, $14}'
} > "$REPORT"

SPINNER_STOP

rm -f /tmp/compliance* 2>/dev/null

if [ "$FAILS" -gt 0 ]; then
    CONFIRMATION_DIALOG "⛔ Compliance FAILED\n\nNetworks: $TOTAL\nFailures: $FAILS\n- WEP: $WEP\n- Open: $OPEN\n\nReport: $REPORT"
else
    CONFIRMATION_DIALOG "✅ Compliance PASSED\n\nNetworks: $TOTAL\nWPA3: $WPA3\nWPA2: $WPA2\n\nReport: $REPORT"
fi

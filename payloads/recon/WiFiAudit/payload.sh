#!/bin/bash
# Title: NullSec WiFi Audit
# Author: bad-antics
# Description: Comprehensive WiFi security assessment
# Category: nullsec

LOOT_DIR="/mmc/nullsec"
mkdir -p "$LOOT_DIR"/{reports,logs}

PROMPT "NULLSEC WIFI AUDIT

Security assessment tool:
- Network discovery
- Encryption analysis
- Client enumeration
- Vulnerability scan

Press OK to configure."

# Find interface
MONITOR_IF=""
for iface in wlan1mon wlan2mon mon0; do
    [ -d "/sys/class/net/$iface" ] && MONITOR_IF="$iface" && break
done
[ -z "$MONITOR_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

# Scan duration
DURATION=$(NUMBER_PICKER "Scan duration (seconds):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac
[ $DURATION -lt 20 ] && DURATION=20
[ $DURATION -gt 300 ] && DURATION=300

resp=$(CONFIRMATION_DIALOG "Start WiFi Audit?

Interface: $MONITOR_IF
Duration: ${DURATION}s

This is passive scanning.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

# Scan
LOG "Starting WiFi audit..."
SPINNER_START "Scanning environment..."

rm -f /tmp/audit_scan*
timeout $DURATION airodump-ng "$MONITOR_IF" -w /tmp/audit_scan --output-format csv 2>/dev/null &
sleep $DURATION
killall airodump-ng 2>/dev/null

SPINNER_STOP

# Generate report
REPORT="$LOOT_DIR/reports/audit_$(date +%Y%m%d_%H%M%S).txt"

{
    echo "======================================"
    echo "  NULLSEC WIFI SECURITY AUDIT"
    echo "  $(date)"
    echo "======================================"
    echo ""
    
    # Count networks
    TOTAL=0; OPEN=0; WEP=0; WPA=0; WPA2=0; WPA3=0
    
    while IFS=',' read -r bssid x1 x2 channel x3 priv cipher x4 power x5 x6 x7 x8 essid rest; do
        bssid=$(echo "$bssid" | tr -d ' ')
        [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
        
        TOTAL=$((TOTAL + 1))
        priv=$(echo "$priv" | tr -d ' ')
        
        case "$priv" in
            *OPN*) OPEN=$((OPEN + 1)) ;;
            *WEP*) WEP=$((WEP + 1)) ;;
            *WPA3*) WPA3=$((WPA3 + 1)) ;;
            *WPA2*) WPA2=$((WPA2 + 1)) ;;
            *WPA*) WPA=$((WPA + 1)) ;;
        esac
    done < /tmp/audit_scan-01.csv
    
    echo "NETWORK SUMMARY"
    echo "---------------"
    echo "Total Networks: $TOTAL"
    echo ""
    echo "ENCRYPTION BREAKDOWN:"
    echo "  Open (NONE):  $OPEN"
    echo "  WEP:          $WEP"
    echo "  WPA:          $WPA"  
    echo "  WPA2:         $WPA2"
    echo "  WPA3:         $WPA3"
    echo ""
    
    # Security assessment
    echo "SECURITY ASSESSMENT"
    echo "-------------------"
    
    VULNS=0
    if [ $OPEN -gt 0 ]; then
        echo "[CRITICAL] $OPEN open networks detected"
        VULNS=$((VULNS + OPEN))
    fi
    if [ $WEP -gt 0 ]; then
        echo "[CRITICAL] $WEP WEP networks (easily cracked)"
        VULNS=$((VULNS + WEP))
    fi
    if [ $WPA -gt 0 ]; then
        echo "[WARNING] $WPA WPA1 networks (weak)"
        VULNS=$((VULNS + WPA))
    fi
    
    echo ""
    if [ $VULNS -eq 0 ]; then
        echo "RESULT: Environment appears secure"
    else
        echo "RESULT: $VULNS vulnerable networks found"
    fi
    
    echo ""
    echo "======================================"
    echo "  Full scan data saved"
    echo "======================================"
    
} > "$REPORT"

# Display summary
PROMPT "AUDIT COMPLETE

Networks found: $TOTAL
Vulnerable: $VULNS

Open: $OPEN
WEP: $WEP
WPA: $WPA
WPA2: $WPA2
WPA3: $WPA3

Report: $REPORT"

#!/bin/bash
# Title: NullSec Scheduled Scan
# Author: bad-antics
# Description: Run automated recon scans at scheduled intervals with logging
# Category: nullsec

LOOT_DIR="/mmc/nullsec/scheduled"
mkdir -p "$LOOT_DIR"

PROMPT "SCHEDULED SCAN
━━━━━━━━━━━━━━━━━━━━━━━━━
Automated periodic WiFi
scanning with logging.

Perfect for site surveys
and monitoring.

Press OK to configure."

INTERVAL=$(NUMBER_PICKER "Scan interval (min):" 15)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) INTERVAL=15 ;; esac
[ $INTERVAL -lt 1 ] && INTERVAL=1

TOTAL_SCANS=$(NUMBER_PICKER "Total scans (0=inf):" 10)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) TOTAL_SCANS=10 ;; esac

SCAN_DUR=$(NUMBER_PICKER "Scan duration (sec):" 15)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SCAN_DUR=15 ;; esac
[ $SCAN_DUR -lt 5 ] && SCAN_DUR=5
[ $SCAN_DUR -gt 60 ] && SCAN_DUR=60

resp=$(CONFIRMATION_DIALOG "SCHEDULE CONFIG:
━━━━━━━━━━━━━━━━━━━━━━━━━
Interval: ${INTERVAL}min
Scans: $([ $TOTAL_SCANS -eq 0 ] && echo Infinite || echo $TOTAL_SCANS)
Duration: ${SCAN_DUR}s each

START?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

MONITOR_IF=""
for iface in wlan1mon wlan2mon mon0; do
    [ -d "/sys/class/net/$iface" ] && MONITOR_IF="$iface" && break
done
[ -z "$MONITOR_IF" ] && ERROR_DIALOG "No monitor interface!" && exit 1

SCAN_NUM=0
MASTER_LOG="$LOOT_DIR/schedule_$(date +%Y%m%d_%H%M%S).csv"
echo "scan_num,timestamp,networks,clients" > "$MASTER_LOG"

while true; do
    SCAN_NUM=$((SCAN_NUM + 1))
    LOG "Scheduled scan #$SCAN_NUM"
    
    rm -f /tmp/sched_scan*
    timeout $SCAN_DUR airodump-ng "$MONITOR_IF" -w /tmp/sched_scan --output-format csv 2>/dev/null &
    sleep $SCAN_DUR
    killall airodump-ng 2>/dev/null
    
    NET_COUNT=$(grep -c "^[0-9A-Fa-f]" /tmp/sched_scan-01.csv 2>/dev/null || echo "0")
    CLIENT_COUNT=$(awk '/Station MAC/,0' /tmp/sched_scan-01.csv 2>/dev/null | grep -c "^[0-9A-Fa-f]" || echo "0")
    
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$SCAN_NUM,$TIMESTAMP,$NET_COUNT,$CLIENT_COUNT" >> "$MASTER_LOG"
    
    cp /tmp/sched_scan-01.csv "$LOOT_DIR/scan_${SCAN_NUM}_$(date +%H%M%S).csv" 2>/dev/null
    
    [ $TOTAL_SCANS -ne 0 ] && [ $SCAN_NUM -ge $TOTAL_SCANS ] && break
    sleep $((INTERVAL * 60))
done

PROMPT "SCHEDULE COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━
Scans completed: $SCAN_NUM
Log: $(basename $MASTER_LOG)
━━━━━━━━━━━━━━━━━━━━━━━━━
All results saved to:
$LOOT_DIR"

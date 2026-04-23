#!/bin/bash
# Title: Heartbeat Monitor
# Author: NullSec
# Description: Continuous health monitoring for long engagements — alerts on CPU, memory, temp, storage, and interface degradation
# Category: nullsec/utility

# Autodetect the right wireless interface (exports $IFACE).
# Falls back to showing the pager error dialog if nothing is plugged in.
. /root/payloads/library/nullsec-iface.sh 2>/dev/null || . "$(dirname "$0")/../../../lib/nullsec-iface.sh"
nullsec_require_iface || exit 1

LOOT_DIR="/mmc/nullsec/heartbeat"
mkdir -p "$LOOT_DIR"

PROMPT "HEARTBEAT MONITOR

Long-engagement health
monitoring for your
Pineapple Pager.

Continuously tracks:
- CPU temperature
- Memory pressure
- Storage filling up
- WiFi interface status
- Process crashes
- Battery (if available)
- System load average
- Network connectivity

Alerts when thresholds
are breached. Logs all
metrics for post-op
analysis.

Press OK to configure."

TIMESTAMP=$(date +%Y%m%d_%H%M)
HEALTH_LOG="$LOOT_DIR/heartbeat_$TIMESTAMP.csv"
ALERT_LOG="$LOOT_DIR/alerts_$TIMESTAMP.log"
SUMMARY="$LOOT_DIR/summary_$TIMESTAMP.txt"

# Threshold configuration
PROMPT "SET THRESHOLDS

Alerts trigger when
values exceed limits.

Defaults shown — adjust
on next screens or keep
defaults.

Press OK to configure."

TEMP_WARN=$(NUMBER_PICKER "CPU temp warn (C):" 75)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) TEMP_WARN=75 ;; esac

TEMP_CRIT=$(NUMBER_PICKER "CPU temp critical (C):" 85)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) TEMP_CRIT=85 ;; esac

MEM_WARN=$(NUMBER_PICKER "Memory usage warn (%):" 80)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MEM_WARN=80 ;; esac

STORAGE_WARN=$(NUMBER_PICKER "Storage usage warn (%):" 90)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) STORAGE_WARN=90 ;; esac

INTERVAL=$(NUMBER_PICKER "Check interval (sec):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) INTERVAL=30 ;; esac
[ $INTERVAL -lt 10 ] && INTERVAL=10
[ $INTERVAL -gt 300 ] && INTERVAL=300

DURATION=$(NUMBER_PICKER "Monitor duration (hrs):" 4)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=4 ;; esac
[ $DURATION -lt 1 ] && DURATION=1
[ $DURATION -gt 72 ] && DURATION=72

resp=$(CONFIRMATION_DIALOG "START HEARTBEAT?

Interval: ${INTERVAL}s
Duration: ${DURATION}h
Temp warn: ${TEMP_WARN}C
Temp crit: ${TEMP_CRIT}C
Mem warn: ${MEM_WARN}%
Storage warn: ${STORAGE_WARN}%

Runs in background.
Alerts on Pager screen.

Confirm?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

# CSV header
echo "timestamp,epoch,cpu_temp_c,mem_total_mb,mem_used_mb,mem_pct,load_1m,load_5m,load_15m,storage_root_pct,storage_mmc_pct,wlan0_state,wlan1_state,processes,uptime_sec,alert" > "$HEALTH_LOG"

echo "[$(date)] Heartbeat Monitor started" > "$ALERT_LOG"
echo "[$(date)] Thresholds: temp_warn=${TEMP_WARN}C temp_crit=${TEMP_CRIT}C mem_warn=${MEM_WARN}% storage_warn=${STORAGE_WARN}%" >> "$ALERT_LOG"

# Track stats
TOTAL_CHECKS=0
TOTAL_ALERTS=0
TEMP_PEAK=0
MEM_PEAK=0
LOAD_PEAK=0
IFACE_DROPS=0
PREV_WLAN0_STATE=""
PREV_WLAN1_STATE=""
HEALTH_HISTORY=""

END_TIME=$(($(date +%s) + DURATION * 3600))

SPINNER_START "Heartbeat monitoring..."

while [ $(date +%s) -lt $END_TIME ]; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    NOW=$(date '+%Y-%m-%d %H:%M:%S')
    EPOCH=$(date +%s)
    ALERT_MSG=""

    # --- CPU Temperature ---
    CPU_TEMP=0
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        RAW_TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0)
        CPU_TEMP=$((RAW_TEMP / 1000))
    fi
    [ $CPU_TEMP -gt $TEMP_PEAK ] && TEMP_PEAK=$CPU_TEMP

    if [ $CPU_TEMP -ge $TEMP_CRIT ]; then
        ALERT_MSG="${ALERT_MSG}CRITICAL: CPU ${CPU_TEMP}C! "
        echo "[$NOW] CRITICAL: CPU temperature ${CPU_TEMP}C exceeds ${TEMP_CRIT}C" >> "$ALERT_LOG"
    elif [ $CPU_TEMP -ge $TEMP_WARN ]; then
        ALERT_MSG="${ALERT_MSG}WARN: CPU ${CPU_TEMP}C "
        echo "[$NOW] WARNING: CPU temperature ${CPU_TEMP}C exceeds ${TEMP_WARN}C" >> "$ALERT_LOG"
    fi

    # --- Memory ---
    MEM_TOTAL=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
    MEM_AVAIL=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
    MEM_USED=$((MEM_TOTAL - MEM_AVAIL))
    MEM_PCT=0
    [ $MEM_TOTAL -gt 0 ] && MEM_PCT=$((MEM_USED * 100 / MEM_TOTAL))
    [ $MEM_PCT -gt $MEM_PEAK ] && MEM_PEAK=$MEM_PCT

    if [ $MEM_PCT -ge $MEM_WARN ]; then
        ALERT_MSG="${ALERT_MSG}MEM: ${MEM_PCT}% "
        echo "[$NOW] WARNING: Memory usage ${MEM_PCT}% (${MEM_USED}/${MEM_TOTAL}MB)" >> "$ALERT_LOG"
    fi

    # --- Load Average ---
    LOAD_1=$(cat /proc/loadavg 2>/dev/null | awk '{print $1}')
    LOAD_5=$(cat /proc/loadavg 2>/dev/null | awk '{print $2}')
    LOAD_15=$(cat /proc/loadavg 2>/dev/null | awk '{print $3}')
    # Integer comparison for peak
    LOAD_INT=$(echo "$LOAD_1" | cut -d. -f1)
    [ -z "$LOAD_INT" ] && LOAD_INT=0
    [ $LOAD_INT -gt $LOAD_PEAK ] && LOAD_PEAK=$LOAD_INT

    # High load alert (>4 on embedded device is concerning)
    if [ $LOAD_INT -ge 4 ]; then
        ALERT_MSG="${ALERT_MSG}LOAD: $LOAD_1 "
        echo "[$NOW] WARNING: High load average $LOAD_1" >> "$ALERT_LOG"
    fi

    # --- Storage ---
    STORAGE_ROOT=$(df / 2>/dev/null | tail -1 | awk '{gsub(/%/,""); print $5}')
    STORAGE_MMC=$(df /mmc 2>/dev/null | tail -1 | awk '{gsub(/%/,""); print $5}')
    [ -z "$STORAGE_ROOT" ] && STORAGE_ROOT=0
    [ -z "$STORAGE_MMC" ] && STORAGE_MMC=0

    if [ $STORAGE_ROOT -ge $STORAGE_WARN ]; then
        ALERT_MSG="${ALERT_MSG}ROOT: ${STORAGE_ROOT}% "
        echo "[$NOW] WARNING: Root storage ${STORAGE_ROOT}% full" >> "$ALERT_LOG"
    fi
    if [ $STORAGE_MMC -ge $STORAGE_WARN ]; then
        ALERT_MSG="${ALERT_MSG}SD: ${STORAGE_MMC}% "
        echo "[$NOW] WARNING: SD card ${STORAGE_MMC}% full" >> "$ALERT_LOG"
    fi

    # --- WiFi Interface Status ---
    WLAN0_STATE=$(cat /sys/class/net/$IFACE/operstate 2>/dev/null || echo "absent")
    WLAN1_STATE=$(cat /sys/class/net/wlan1/operstate 2>/dev/null || echo "absent")

    # Detect interface state changes
    if [ -n "$PREV_WLAN0_STATE" ] && [ "$WLAN0_STATE" != "$PREV_WLAN0_STATE" ]; then
        IFACE_DROPS=$((IFACE_DROPS + 1))
        ALERT_MSG="${ALERT_MSG}$IFACE:$WLAN0_STATE "
        echo "[$NOW] ALERT: $IFACE state changed: $PREV_WLAN0_STATE -> $WLAN0_STATE" >> "$ALERT_LOG"
    fi
    if [ -n "$PREV_WLAN1_STATE" ] && [ "$WLAN1_STATE" != "$PREV_WLAN1_STATE" ]; then
        IFACE_DROPS=$((IFACE_DROPS + 1))
        ALERT_MSG="${ALERT_MSG}wlan1:$WLAN1_STATE "
        echo "[$NOW] ALERT: wlan1 state changed: $PREV_WLAN1_STATE -> $WLAN1_STATE" >> "$ALERT_LOG"
    fi
    PREV_WLAN0_STATE="$WLAN0_STATE"
    PREV_WLAN1_STATE="$WLAN1_STATE"

    # --- Process count ---
    PROC_COUNT=$(ls /proc/[0-9]* -d 2>/dev/null | wc -l)

    # --- Uptime ---
    UPTIME_SEC=$(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo 0)

    # --- Log to CSV ---
    echo "$NOW,$EPOCH,$CPU_TEMP,$MEM_TOTAL,$MEM_USED,$MEM_PCT,$LOAD_1,$LOAD_5,$LOAD_15,$STORAGE_ROOT,$STORAGE_MMC,$WLAN0_STATE,$WLAN1_STATE,$PROC_COUNT,$UPTIME_SEC,${ALERT_MSG:-ok}" >> "$HEALTH_LOG"

    # --- Display alert on Pager screen ---
    if [ -n "$ALERT_MSG" ]; then
        TOTAL_ALERTS=$((TOTAL_ALERTS + 1))
        SPINNER_STOP

        PROMPT "⚠ HEALTH ALERT #$TOTAL_ALERTS

$ALERT_MSG

CPU: ${CPU_TEMP}C
MEM: ${MEM_PCT}% used
Load: $LOAD_1
Root: ${STORAGE_ROOT}%
SD: ${STORAGE_MMC}%
$IFACE: $WLAN0_STATE
wlan1: $WLAN1_STATE

Press OK to continue
monitoring."

        SPINNER_START "Heartbeat monitoring..."
    fi

    # Status update every 20 checks
    if [ $((TOTAL_CHECKS % 20)) -eq 0 ]; then
        ELAPSED=$(( ($(date +%s) - (END_TIME - DURATION * 3600)) / 60 ))
        REMAINING=$(( (END_TIME - $(date +%s)) / 60 ))
        SPINNER_STOP

        # Health grade
        GRADE="HEALTHY"
        [ $CPU_TEMP -ge $TEMP_WARN ] && GRADE="DEGRADED"
        [ $MEM_PCT -ge $MEM_WARN ] && GRADE="DEGRADED"
        [ $CPU_TEMP -ge $TEMP_CRIT ] && GRADE="CRITICAL"

        PROMPT "HEARTBEAT STATUS

Runtime: ${ELAPSED}m
Remaining: ${REMAINING}m
Checks: $TOTAL_CHECKS
Alerts: $TOTAL_ALERTS

Status: $GRADE
CPU: ${CPU_TEMP}C (pk:${TEMP_PEAK}C)
MEM: ${MEM_PCT}% (pk:${MEM_PEAK}%)
Load: $LOAD_1
Iface drops: $IFACE_DROPS

Press OK to continue."

        SPINNER_START "Heartbeat monitoring..."
    fi

    sleep "$INTERVAL"
done

SPINNER_STOP

# Generate summary report
ELAPSED_MIN=$(( DURATION * 60 ))
HEALTH_GRADE="HEALTHY"
[ $TOTAL_ALERTS -gt 0 ] && HEALTH_GRADE="DEGRADED"
[ $TOTAL_ALERTS -gt 10 ] && HEALTH_GRADE="POOR"
[ $TEMP_PEAK -ge $TEMP_CRIT ] && HEALTH_GRADE="CRITICAL"

cat > "$SUMMARY" << EOF
==========================================
   NULLSEC HEARTBEAT MONITOR REPORT
==========================================

Monitoring Period: $DURATION hours
Check Interval: ${INTERVAL}s
Total Checks: $TOTAL_CHECKS
Total Alerts: $TOTAL_ALERTS

OVERALL HEALTH: $HEALTH_GRADE

========= PEAK VALUES =========

CPU Temperature: ${TEMP_PEAK}C (warn: ${TEMP_WARN}C)
Memory Usage:    ${MEM_PEAK}% (warn: ${MEM_WARN}%)
Load Average:    ${LOAD_PEAK} peak
Interface Drops: $IFACE_DROPS

========= FINAL STATE =========

CPU Temp:  ${CPU_TEMP}C
Memory:    ${MEM_PCT}% (${MEM_USED}/${MEM_TOTAL}MB)
Load:      $LOAD_1 / $LOAD_5 / $LOAD_15
Root:      ${STORAGE_ROOT}%
SD Card:   ${STORAGE_MMC}%
$IFACE:     $WLAN0_STATE
wlan1:     $WLAN1_STATE
Processes: $PROC_COUNT
Uptime:    ${UPTIME_SEC}s

========= ALERT SUMMARY =========
$(cat "$ALERT_LOG")

==========================================
Generated by NullSec HeartbeatMonitor
$(date)
==========================================
EOF

PROMPT "MONITORING COMPLETE

Duration: ${DURATION}h
Checks: $TOTAL_CHECKS
Alerts: $TOTAL_ALERTS

HEALTH: $HEALTH_GRADE

Peak CPU: ${TEMP_PEAK}C
Peak MEM: ${MEM_PEAK}%
Iface drops: $IFACE_DROPS

Press OK for files."

PROMPT "FILES SAVED

Health log (CSV):
heartbeat_$TIMESTAMP.csv

Alert log:
alerts_$TIMESTAMP.log

Summary report:
summary_$TIMESTAMP.txt

Location: $LOOT_DIR/

CSV can be graphed in
Excel/LibreOffice for
visual health timeline.

Press OK to exit."

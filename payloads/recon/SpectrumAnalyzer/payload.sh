#!/bin/bash
# Title: Spectrum Analyzer
# Author: NullSec
# Description: WiFi spectrum analysis with channel utilization and signal mapping
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/spectrum"
mkdir -p "$LOOT_DIR"

PROMPT "SPECTRUM ANALYZER

WiFi spectrum analysis
for channels 1-14.

Features:
- Channel utilization
- Interference mapping
- Signal strength survey
- AP density per channel
- Best channel finder

Press OK to configure."

# Find monitor interface
MONITOR_IF=""
for iface in wlan1mon wlan2mon mon0 wlan1 wlan0; do
    [ -d "/sys/class/net/$iface" ] && MONITOR_IF="$iface" && break
done
[ -z "$MONITOR_IF" ] && { ERROR_DIALOG "No interface found!"; exit 1; }

PROMPT "ANALYSIS MODE:

1. Quick channel survey
2. Deep spectrum scan
3. Interference finder
4. Best channel advisor

Interface: $MONITOR_IF

Select mode next."

SCAN_MODE=$(NUMBER_PICKER "Mode (1-4):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SCAN_MODE=1 ;; esac

BAND=$(CONFIRMATION_DIALOG "Include 5GHz?

YES = 2.4GHz + 5GHz
NO = 2.4GHz only

Note: 5GHz requires
supported hardware.")
if [ "$BAND" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    CHANNELS="1-14,36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140,149,153,157,161,165"
    BAND_NAME="2.4+5GHz"
else
    CHANNELS="1-14"
    BAND_NAME="2.4GHz"
fi

SCAN_TIME=$(NUMBER_PICKER "Scan time (seconds):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SCAN_TIME=60 ;; esac
[ $SCAN_TIME -lt 20 ] && SCAN_TIME=20
[ $SCAN_TIME -gt 300 ] && SCAN_TIME=300

resp=$(CONFIRMATION_DIALOG "START SPECTRUM SCAN?

Mode: $SCAN_MODE
Band: $BAND_NAME
Duration: ${SCAN_TIME}s
Interface: $MONITOR_IF

Confirm?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M)
REPORT="$LOOT_DIR/spectrum_$TIMESTAMP.txt"
CAP_PREFIX="/tmp/spectrum_$$"

LOG "Starting spectrum analysis..."
SPINNER_START "Analyzing WiFi spectrum..."

# Run airodump to collect AP data
timeout "$SCAN_TIME" airodump-ng "$MONITOR_IF" -c "$CHANNELS" \
    --write-interval 3 -w "$CAP_PREFIX" --output-format csv 2>/dev/null &
SCAN_PID=$!
sleep "$SCAN_TIME"
kill $SCAN_PID 2>/dev/null
wait $SCAN_PID 2>/dev/null

# Parse results
CSV_FILE=$(ls -t "${CAP_PREFIX}"*.csv 2>/dev/null | head -1)
[ -z "$CSV_FILE" ] && { SPINNER_STOP; ERROR_DIALOG "No scan data collected!"; exit 1; }

echo "=======================================" > "$REPORT"
echo "    NULLSEC SPECTRUM ANALYSIS REPORT   " >> "$REPORT"
echo "=======================================" >> "$REPORT"
echo "" >> "$REPORT"
echo "Scan Time: $(date)" >> "$REPORT"
echo "Duration: ${SCAN_TIME}s" >> "$REPORT"
echo "Band: $BAND_NAME" >> "$REPORT"
echo "Interface: $MONITOR_IF" >> "$REPORT"
echo "" >> "$REPORT"

# Channel utilization analysis
echo "--- CHANNEL UTILIZATION ---" >> "$REPORT"
echo "" >> "$REPORT"

declare -A CH_COUNT
declare -A CH_POWER
TOTAL_APS=0

while IFS=',' read -r bssid first last channel speed privacy cipher auth power beacons iv lanip idlen essid rest; do
    channel=$(echo "$channel" | tr -d ' ')
    power=$(echo "$power" | tr -d ' ')
    [[ "$channel" =~ ^[0-9]+$ ]] || continue
    [ -z "$channel" ] && continue

    CH_COUNT[$channel]=$(( ${CH_COUNT[$channel]:-0} + 1 ))
    TOTAL_APS=$((TOTAL_APS + 1))

    # Track max signal per channel
    if [ -n "$power" ] && [ "$power" -ne -1 ] 2>/dev/null; then
        if [ -z "${CH_POWER[$channel]}" ] || [ "$power" -gt "${CH_POWER[$channel]}" ]; then
            CH_POWER[$channel]=$power
        fi
    fi
done < "$CSV_FILE"

# Print channel histogram
echo "Ch | APs | Signal | Utilization" >> "$REPORT"
echo "---|-----|--------|------------" >> "$REPORT"

BEST_CH=""
BEST_CH_COUNT=999

for ch in 1 2 3 4 5 6 7 8 9 10 11 12 13 14; do
    count=${CH_COUNT[$ch]:-0}
    power=${CH_POWER[$ch]:-"n/a"}

    # Build text bar
    BAR=""
    for i in $(seq 1 $count); do
        BAR="${BAR}#"
    done
    [ $count -eq 0 ] && BAR="-"

    printf "%2d | %3d | %6s | %s\n" "$ch" "$count" "$power" "$BAR" >> "$REPORT"

    # Track least crowded channel (1, 6, 11 preferred)
    if [ $count -lt $BEST_CH_COUNT ]; then
        BEST_CH_COUNT=$count
        BEST_CH=$ch
    fi
done

echo "" >> "$REPORT"

# 5GHz channels if scanned
if [ "$BAND" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    echo "--- 5GHz CHANNELS ---" >> "$REPORT"
    echo "" >> "$REPORT"
    for ch in 36 40 44 48 52 56 60 64 100 104 108 112 116 120 124 128 132 136 140 149 153 157 161 165; do
        count=${CH_COUNT[$ch]:-0}
        [ $count -gt 0 ] && printf "Ch %3d | %3d APs\n" "$ch" "$count" >> "$REPORT"
    done
    echo "" >> "$REPORT"
fi

# Interference analysis
if [ "$SCAN_MODE" -ge 3 ]; then
    echo "--- INTERFERENCE ANALYSIS ---" >> "$REPORT"
    echo "" >> "$REPORT"

    # Overlapping channels on 2.4GHz
    for ch in 1 6 11; do
        OVERLAP=0
        case $ch in
            1) for o in 2 3 4 5; do OVERLAP=$((OVERLAP + ${CH_COUNT[$o]:-0})); done ;;
            6) for o in 3 4 5 7 8 9; do OVERLAP=$((OVERLAP + ${CH_COUNT[$o]:-0})); done ;;
            11) for o in 8 9 10 12 13; do OVERLAP=$((OVERLAP + ${CH_COUNT[$o]:-0})); done ;;
        esac
        echo "Ch $ch: ${CH_COUNT[$ch]:-0} APs, $OVERLAP overlapping" >> "$REPORT"
    done
    echo "" >> "$REPORT"
fi

# Best channel recommendation
echo "--- RECOMMENDATION ---" >> "$REPORT"
echo "" >> "$REPORT"

# Check non-overlapping channels specifically
for ch in 1 6 11; do
    count=${CH_COUNT[$ch]:-0}
    if [ $count -le ${BEST_CH_COUNT:-999} ]; then
        BEST_CH=$ch
        BEST_CH_COUNT=$count
    fi
done

echo "Best channel: $BEST_CH ($BEST_CH_COUNT APs)" >> "$REPORT"
echo "Total APs: $TOTAL_APS" >> "$REPORT"
echo "" >> "$REPORT"
echo "=======================================" >> "$REPORT"

# Cleanup
rm -f "${CAP_PREFIX}"* 2>/dev/null

SPINNER_STOP

PROMPT "SPECTRUM ANALYSIS DONE

Total APs: $TOTAL_APS
Best channel: $BEST_CH
  ($BEST_CH_COUNT APs)

Ch 1: ${CH_COUNT[1]:-0} APs
Ch 6: ${CH_COUNT[6]:-0} APs
Ch 11: ${CH_COUNT[11]:-0} APs

Report: $REPORT

Press OK to exit."

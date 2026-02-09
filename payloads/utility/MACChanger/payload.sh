#!/bin/bash
# Title: MAC Changer
# Author: NullSec
# Description: Changes MAC address on interfaces with multiple modes
# Category: nullsec/utility

LOOT_DIR="/mmc/nullsec/macchanger"
mkdir -p "$LOOT_DIR"

PROMPT "MAC CHANGER

Change MAC addresses on
network interfaces.

Modes:
- Random MAC
- Specific MAC
- Vendor spoof
- Restore original

Press OK to configure."

# List available interfaces
IFACE_LIST=""
IFACE_COUNT=0
for iface in $(ls /sys/class/net/ 2>/dev/null | grep -v lo); do
    CURRENT_MAC=$(cat /sys/class/net/$iface/address 2>/dev/null)
    IFACE_LIST="${IFACE_LIST}${iface}: ${CURRENT_MAC}\n"
    IFACE_COUNT=$((IFACE_COUNT + 1))
done

[ $IFACE_COUNT -eq 0 ] && { ERROR_DIALOG "No interfaces found!"; exit 1; }

PROMPT "INTERFACES:

$(echo -e "$IFACE_LIST")
Total: $IFACE_COUNT

Press OK to select
interface."

TARGET_IFACE=$(TEXT_PICKER "Interface:" "wlan0")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) TARGET_IFACE="wlan0" ;; esac

if [ ! -d "/sys/class/net/$TARGET_IFACE" ]; then
    ERROR_DIALOG "Interface $TARGET_IFACE
not found!"
    exit 1
fi

ORIGINAL_MAC=$(cat /sys/class/net/$TARGET_IFACE/address 2>/dev/null)

PROMPT "CHANGE MODE:

1. Random MAC
2. Specific MAC
3. Vendor spoof
4. Restore original

Current MAC:
$ORIGINAL_MAC

Select mode next."

CHANGE_MODE=$(NUMBER_PICKER "Mode (1-4):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) CHANGE_MODE=1 ;; esac

# Generate new MAC based on mode
NEW_MAC=""
case $CHANGE_MODE in
    1) # Random MAC
        NEW_MAC=$(printf '%02x:%02x:%02x:%02x:%02x:%02x' \
            $((RANDOM%256 & 0xFE | 0x02)) $((RANDOM%256)) $((RANDOM%256)) \
            $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
        ;;
    2) # Specific MAC
        NEW_MAC=$(TEXT_PICKER "New MAC:" "AA:BB:CC:DD:EE:FF")
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac
        if ! echo "$NEW_MAC" | grep -qE '^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$'; then
            ERROR_DIALOG "Invalid MAC format!

Use: XX:XX:XX:XX:XX:XX"
            exit 1
        fi
        ;;
    3) # Vendor spoof
        PROMPT "VENDOR SPOOF:

1. Apple (iPhone)
2. Samsung Galaxy
3. Google Pixel
4. Intel laptop
5. Cisco device
6. Random vendor

Select vendor next."
        VENDOR=$(NUMBER_PICKER "Vendor (1-6):" 1)
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) VENDOR=1 ;; esac
        case $VENDOR in
            1) OUI="F0:D4:F7" ;; # Apple
            2) OUI="AC:5F:3E" ;; # Samsung
            3) OUI="3C:28:6D" ;; # Google
            4) OUI="A4:34:D9" ;; # Intel
            5) OUI="00:1A:2B" ;; # Cisco
            *) OUI=$(printf '%02x:%02x:%02x' $((RANDOM%256 & 0xFE)) $((RANDOM%256)) $((RANDOM%256))) ;;
        esac
        NEW_MAC=$(printf '%s:%02x:%02x:%02x' "$OUI" $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
        ;;
    4) # Restore - read saved original
        if [ -f "$LOOT_DIR/original_${TARGET_IFACE}.mac" ]; then
            NEW_MAC=$(cat "$LOOT_DIR/original_${TARGET_IFACE}.mac")
        else
            ERROR_DIALOG "No saved original MAC
for $TARGET_IFACE!"
            exit 1
        fi
        ;;
esac

resp=$(CONFIRMATION_DIALOG "CHANGE MAC?

Interface: $TARGET_IFACE
Current:  $ORIGINAL_MAC
New MAC:  $NEW_MAC

Interface will be
briefly taken down.

Confirm?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

# Save original MAC
echo "$ORIGINAL_MAC" > "$LOOT_DIR/original_${TARGET_IFACE}.mac"

LOG "Changing MAC on $TARGET_IFACE..."
SPINNER_START "Changing MAC address..."

# Bring interface down, change MAC, bring back up
ip link set "$TARGET_IFACE" down 2>/dev/null
sleep 1

if command -v macchanger >/dev/null 2>&1; then
    macchanger -m "$NEW_MAC" "$TARGET_IFACE" 2>/dev/null
else
    ip link set "$TARGET_IFACE" address "$NEW_MAC" 2>/dev/null
fi

RESULT=$?
ip link set "$TARGET_IFACE" up 2>/dev/null
sleep 2

SPINNER_STOP

VERIFY_MAC=$(cat /sys/class/net/$TARGET_IFACE/address 2>/dev/null)

# Log change
echo "$(date) | $TARGET_IFACE | $ORIGINAL_MAC -> $VERIFY_MAC" >> "$LOOT_DIR/mac_history.log"

if [ "$VERIFY_MAC" = "$NEW_MAC" ] || [ "$VERIFY_MAC" = "$(echo "$NEW_MAC" | tr 'A-F' 'a-f')" ]; then
    PROMPT "MAC CHANGED!

Interface: $TARGET_IFACE
Old MAC: $ORIGINAL_MAC
New MAC: $VERIFY_MAC

Original saved for
restore. Log updated.

Press OK to exit."
else
    ERROR_DIALOG "MAC change may have
failed!

Expected: $NEW_MAC
Got:      $VERIFY_MAC

Some drivers restrict
MAC changes."
fi

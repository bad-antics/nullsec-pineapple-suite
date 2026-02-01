#!/bin/bash
# Title: Vendor Hunt
# Author: bad-antics
# Description: Find devices by manufacturer
# Category: nullsec/recon

# OUI database (common manufacturers)
OUI_DB="00:50:F2:Microsoft
00:1A:11:Google
00:0A:95:Apple
00:1C:B3:Apple
00:03:93:Apple
00:17:F2:Apple
AC:DE:48:Apple
3C:06:30:Apple
00:23:12:Apple
FC:FC:48:Apple
00:26:BB:Apple
70:56:81:Apple
40:33:1A:Apple
A4:D1:8C:Apple
00:1E:C2:Apple
64:20:0C:Apple
78:CA:39:Apple
00:0D:93:Apple
00:17:FA:Amazon
40:B4:CD:Amazon
44:65:0D:Amazon
68:54:FD:Amazon
74:C2:46:Amazon
A0:02:DC:Amazon
FC:A6:67:Amazon
18:74:2E:Amazon
B0:FC:36:Amazon
00:26:5E:Samsung
00:1A:8A:Samsung
00:12:47:Samsung
00:15:99:Samsung
00:1D:F6:Samsung
00:21:D2:Samsung
00:24:91:Samsung
00:26:37:Samsung
5C:0A:5B:Samsung
84:25:DB:Samsung
E4:7C:F9:Samsung
78:D6:F0:Samsung
00:0C:29:VMware
00:50:56:VMware
00:0C:76:Cisco
00:40:96:Cisco
00:50:0F:Cisco
00:17:94:Cisco
00:21:1C:Cisco
00:24:C3:Cisco
00:18:74:Cisco
B8:27:EB:Raspberry Pi
DC:A6:32:Raspberry Pi
E4:5F:01:Raspberry Pi
28:CD:C1:Raspberry Pi
D8:3A:DD:Raspberry Pi
00:22:55:Cisco
18:33:9D:Cisco
F4:CF:E2:Cisco
00:24:BE:Netgear
20:4E:7F:Netgear
30:46:9A:Netgear
44:94:FC:Netgear
9C:3D:CF:Netgear
A4:2B:B0:Netgear
C0:3F:0E:Netgear
E0:91:F5:Netgear"

PROMPT "VENDOR HUNT

Find devices by their
manufacturer (Apple,
Samsung, Cisco, etc).

Useful for targeting
specific device types.

Press OK to continue."

PROMPT "CHOOSE TARGET VENDOR:

1. Apple
2. Samsung
3. Amazon
4. Google/Nest
5. Cisco/Linksys
6. Raspberry Pi
7. Custom OUI

Enter choice next."

VENDOR_CHOICE=$(NUMBER_PICKER "Vendor (1-7):" 1)

case $VENDOR_CHOICE in
    1) VENDOR="Apple"; OUI_FILTER="Apple" ;;
    2) VENDOR="Samsung"; OUI_FILTER="Samsung" ;;
    3) VENDOR="Amazon"; OUI_FILTER="Amazon" ;;
    4) VENDOR="Google"; OUI_FILTER="Google" ;;
    5) VENDOR="Cisco"; OUI_FILTER="Cisco" ;;
    6) VENDOR="Raspberry Pi"; OUI_FILTER="Raspberry" ;;
    7) 
        VENDOR="Custom"
        OUI_FILTER=$(TEXT_PICKER "OUI prefix:" "00:50:F2")
        ;;
esac

INTERFACE="wlan0"

# Prepare
airmon-ng check kill 2>/dev/null
sleep 1
airmon-ng start $INTERFACE >/dev/null 2>&1
MON_IF="${INTERFACE}mon"
[ ! -d "/sys/class/net/$MON_IF" ] && MON_IF="$INTERFACE"

SPINNER_START "Hunting $VENDOR devices..."

# Scan
TEMP_DIR="/tmp/vendorhunt_$$"
mkdir -p "$TEMP_DIR"
timeout 20 airodump-ng $MON_IF -w "$TEMP_DIR/scan" --output-format csv 2>/dev/null &
sleep 20

SPINNER_STOP

# Parse for vendor
LOOT_DIR="/mmc/nullsec/vendor_hunt"
mkdir -p "$LOOT_DIR"
LOOT_FILE="$LOOT_DIR/${VENDOR}_$(date +%Y%m%d_%H%M%S).txt"

echo "Vendor Hunt: $VENDOR" > "$LOOT_FILE"
echo "Date: $(date)" >> "$LOOT_FILE"
echo "---" >> "$LOOT_FILE"

FOUND=0

# Check APs
while IFS=',' read -r BSSID F2 F3 CHANNEL F5 F6 F7 F8 F9 F10 F11 F12 F13 ESSID REST; do
    BSSID=$(echo "$BSSID" | tr -d ' ')
    
    if [ -n "$BSSID" ] && echo "$BSSID" | grep -qE "^[0-9A-Fa-f]{2}:"; then
        OUI=$(echo "$BSSID" | cut -d':' -f1-3 | tr '[:lower:]' '[:upper:]')
        
        if echo "$OUI_DB" | grep -i "$OUI_FILTER" | grep -qi "$OUI"; then
            echo "AP: $BSSID - $ESSID (Ch: $CHANNEL)" >> "$LOOT_FILE"
            ((FOUND++))
        fi
    fi
done < "$TEMP_DIR/scan-01.csv"

# Check Stations
while IFS=',' read -r STATION_MAC F2 F3 F4 F5 F6 PROBES; do
    STATION_MAC=$(echo "$STATION_MAC" | tr -d ' ')
    
    if [ -n "$STATION_MAC" ] && echo "$STATION_MAC" | grep -qE "^[0-9A-Fa-f]{2}:"; then
        OUI=$(echo "$STATION_MAC" | cut -d':' -f1-3 | tr '[:lower:]' '[:upper:]')
        
        if echo "$OUI_DB" | grep -i "$OUI_FILTER" | grep -qi "$OUI"; then
            echo "Client: $STATION_MAC" >> "$LOOT_FILE"
            ((FOUND++))
        fi
    fi
done < "$TEMP_DIR/scan-01.csv"

# Cleanup
airmon-ng stop $MON_IF 2>/dev/null
rm -rf "$TEMP_DIR"

PROMPT "$VENDOR HUNT COMPLETE

Found: $FOUND devices

Results saved to:
$LOOT_FILE

Press OK to exit."

#!/bin/bash
# Title: NullSec Range Extender
# Author: bad-antics
# Description: Connect to network and broadcast spoofed hotspot with internet
# Category: nullsec/utility

PROMPT "NULLSEC RANGE EXTENDER

Connect to your network
and broadcast a hotspot
with spoofed SSID.

Works with:
- Home WiFi
- Phone Hotspot
- Any WPA network

Internet passes through!

Press OK to configure."

[ ! -d "/sys/class/net/wlan0" ] && { ERROR_DIALOG "wlan0 not found!"; exit 1; }

PROMPT "SELECT SOURCE:

1. Scan for network
2. Enter SSID manually
3. Phone hotspot mode

Enter option next."

SOURCE_MODE=$(NUMBER_PICKER "Source (1-3):" 1)

case $SOURCE_MODE in
    1) # Scan
        SPINNER_START "Scanning networks..."
        timeout 12 airodump-ng wlan0 --encrypt wpa --write-interval 1 -w /tmp/extscan --output-format csv 2>/dev/null
        SPINNER_STOP
        
        NET_COUNT=$(grep -c "WPA" /tmp/extscan*.csv 2>/dev/null || echo 0)
        PROMPT "Found $NET_COUNT networks"
        
        TARGET_NUM=$(NUMBER_PICKER "Network #:" 1)
        TARGET_LINE=$(grep "WPA" /tmp/extscan*.csv 2>/dev/null | sed -n "${TARGET_NUM}p")
        SOURCE_SSID=$(echo "$TARGET_LINE" | cut -d',' -f14 | tr -d ' ')
        SOURCE_CHANNEL=$(echo "$TARGET_LINE" | cut -d',' -f4 | tr -d ' ')
        ;;
    2) # Manual
        SOURCE_SSID=$(TEXT_PICKER "Source SSID:" "MyNetwork")
        SOURCE_CHANNEL=$(NUMBER_PICKER "Channel:" 6)
        ;;
    3) # Phone hotspot
        PROMPT "PHONE HOTSPOT MODE

Common hotspot names:
- iPhone (Your Name)
- AndroidAP
- Galaxy S## (XXXX)

Enter your hotspot name."
        SOURCE_SSID=$(TEXT_PICKER "Hotspot SSID:" "iPhone")
        SOURCE_CHANNEL=$(NUMBER_PICKER "Channel (usually 1,6,11):" 6)
        ;;
esac

SOURCE_PASS=$(TEXT_PICKER "Source Password:" "")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) 
    ERROR_DIALOG "Password required!"
    exit 1
    ;;
esac

PROMPT "HOTSPOT SSID OPTIONS:

1. Custom SSID
2. Clone nearby network
3. Preset names

Enter option next."

SSID_MODE=$(NUMBER_PICKER "SSID Mode (1-3):" 1)

case $SSID_MODE in
    1) # Custom
        HOTSPOT_SSID=$(TEXT_PICKER "Hotspot SSID:" "Free_WiFi")
        ;;
    2) # Clone nearby
        SPINNER_START "Finding SSIDs..."
        timeout 8 airodump-ng wlan0 --write-interval 1 -w /tmp/clonescan --output-format csv 2>/dev/null
        SPINNER_STOP
        
        CLONE_COUNT=$(grep -c "WPA\|OPN" /tmp/clonescan*.csv 2>/dev/null || echo 0)
        PROMPT "Found $CLONE_COUNT networks to clone"
        
        CLONE_NUM=$(NUMBER_PICKER "Clone network #:" 1)
        CLONE_LINE=$(grep "WPA\|OPN" /tmp/clonescan*.csv 2>/dev/null | sed -n "${CLONE_NUM}p")
        HOTSPOT_SSID=$(echo "$CLONE_LINE" | cut -d',' -f14 | tr -d ' ')
        ;;
    3) # Presets
        PROMPT "PRESET SSIDs:

1. xfinitywifi
2. attwifi
3. Starbucks WiFi
4. McDonald's Free WiFi
5. Airport_Free_WiFi
6. Hotel_Guest

Enter choice next."
        PRESET=$(NUMBER_PICKER "Preset (1-6):" 1)
        case $PRESET in
            1) HOTSPOT_SSID="xfinitywifi" ;;
            2) HOTSPOT_SSID="attwifi" ;;
            3) HOTSPOT_SSID="Starbucks WiFi" ;;
            4) HOTSPOT_SSID="McDonald's Free WiFi" ;;
            5) HOTSPOT_SSID="Airport_Free_WiFi" ;;
            6) HOTSPOT_SSID="Hotel_Guest" ;;
        esac
        ;;
esac

PROMPT "HOTSPOT SECURITY:

1. Open (no password)
2. WPA2 with password

Enter choice next."

SEC_MODE=$(NUMBER_PICKER "Security (1-2):" 1)

if [ "$SEC_MODE" -eq 2 ]; then
    HOTSPOT_PASS=$(TEXT_PICKER "Hotspot Password:" "nullsec123")
fi

# Different channel for hotspot
if [ "$SOURCE_CHANNEL" -le 6 ]; then
    HOTSPOT_CHANNEL=11
else
    HOTSPOT_CHANNEL=1
fi

resp=$(CONFIRMATION_DIALOG "START EXTENDER?

Source: $SOURCE_SSID
Hotspot: $HOTSPOT_SSID
Security: $([ \"$SEC_MODE\" -eq 2 ] && echo WPA2 || echo Open)

Press OK to launch.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

killall wpa_supplicant hostapd dnsmasq 2>/dev/null

LOG "Connecting to $SOURCE_SSID..."

# Create wpa_supplicant config
cat > /tmp/wpa_source.conf << EOF
network={
    ssid="$SOURCE_SSID"
    psk="$SOURCE_PASS"
    key_mgmt=WPA-PSK
}
EOF

# Need two interfaces - check if wlan1 exists or use virtual
if [ -d "/sys/class/net/wlan1" ]; then
    CLIENT_IF="wlan1"
    AP_IF="wlan0"
else
    # Create virtual interface
    iw dev wlan0 interface add wlan0_ap type __ap 2>/dev/null || {
        ERROR_DIALOG "Cannot create AP interface. Need 2 WiFi adapters or AP mode support."
        exit 1
    }
    CLIENT_IF="wlan0"
    AP_IF="wlan0_ap"
fi

# Connect to source network
wpa_supplicant -B -i $CLIENT_IF -c /tmp/wpa_source.conf
sleep 5
dhclient $CLIENT_IF 2>/dev/null || udhcpc -i $CLIENT_IF 2>/dev/null

# Check connection
if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    ERROR_DIALOG "Failed to connect to $SOURCE_SSID

Check password and try again."
    killall wpa_supplicant 2>/dev/null
    exit 1
fi

LOG "Connected! Starting hotspot..."

# Configure hotspot
if [ "$SEC_MODE" -eq 2 ]; then
cat > /tmp/hotspot.conf << EOF
interface=$AP_IF
driver=nl80211
ssid=$HOTSPOT_SSID
hw_mode=g
channel=$HOTSPOT_CHANNEL
auth_algs=1
wpa=2
wpa_passphrase=$HOTSPOT_PASS
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF
else
cat > /tmp/hotspot.conf << EOF
interface=$AP_IF
driver=nl80211
ssid=$HOTSPOT_SSID
hw_mode=g
channel=$HOTSPOT_CHANNEL
auth_algs=1
wpa=0
EOF
fi

# Start hostapd
hostapd /tmp/hotspot.conf &
sleep 2

# Configure AP interface
ifconfig $AP_IF 192.168.50.1 netmask 255.255.255.0 up

# DHCP for hotspot clients
cat > /tmp/hotspot_dhcp.conf << EOF
interface=$AP_IF
dhcp-range=192.168.50.10,192.168.50.200,12h
dhcp-option=3,192.168.50.1
dhcp-option=6,8.8.8.8,8.8.4.4
EOF
dnsmasq -C /tmp/hotspot_dhcp.conf &

# Enable NAT/forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -o $CLIENT_IF -j MASQUERADE
iptables -A FORWARD -i $AP_IF -o $CLIENT_IF -j ACCEPT
iptables -A FORWARD -i $CLIENT_IF -o $AP_IF -m state --state RELATED,ESTABLISHED -j ACCEPT

LOG "Range Extender ACTIVE!"

PROMPT "RANGE EXTENDER ACTIVE

Source: $SOURCE_SSID ✓
Hotspot: $HOTSPOT_SSID
Password: $([ \"$SEC_MODE\" -eq 2 ] && echo $HOTSPOT_PASS || echo 'None (Open)')

Internet: CONNECTED

Press OK to STOP."

# Cleanup
killall hostapd dnsmasq wpa_supplicant 2>/dev/null
iptables -t nat -F
iptables -F FORWARD
echo 0 > /proc/sys/net/ipv4/ip_forward

# Remove virtual interface if created
[ "$AP_IF" = "wlan0_ap" ] && iw dev wlan0_ap del 2>/dev/null

PROMPT "RANGE EXTENDER STOPPED

Press OK to exit."

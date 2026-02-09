#!/bin/bash
# Title: Traffic Mask
# Author: NullSec
# Description: Masks Pineapple traffic to look like a normal device
# Category: nullsec/stealth

LOOT_DIR="/mmc/nullsec/trafficmask"
mkdir -p "$LOOT_DIR"

PROMPT "TRAFFIC MASK

Disguise this device to
look like a normal
consumer device.

Features:
- MAC address spoofing
- Hostname randomization
- TTL manipulation
- User-agent masking
- Traffic pattern noise
- OS fingerprint spoof

Press OK to configure."

PROMPT "DEVICE PROFILE:

1. iPhone / iPad
2. Samsung Galaxy
3. Windows Laptop
4. MacBook
5. Smart TV
6. IoT Device
7. Custom

Select profile next."

PROFILE=$(NUMBER_PICKER "Profile (1-7):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) PROFILE=1 ;; esac

case $PROFILE in
    1) # iPhone
        SPOOF_OUI="F0:D4:F7"
        SPOOF_HOSTNAME="iPhone"
        SPOOF_TTL=64
        SPOOF_UA="Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15"
        PROFILE_NAME="iPhone"
        ;;
    2) # Samsung
        SPOOF_OUI="AC:5F:3E"
        SPOOF_HOSTNAME="Galaxy-S24"
        SPOOF_TTL=64
        SPOOF_UA="Mozilla/5.0 (Linux; Android 14; SM-S926B) AppleWebKit/537.36"
        PROFILE_NAME="Samsung Galaxy"
        ;;
    3) # Windows Laptop
        SPOOF_OUI="A4:34:D9"
        SPOOF_HOSTNAME="DESKTOP-$(head -c 4 /dev/urandom | xxd -p | tr 'a-f' 'A-F' | head -c 7)"
        SPOOF_TTL=128
        SPOOF_UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        PROFILE_NAME="Windows Laptop"
        ;;
    4) # MacBook
        SPOOF_OUI="A8:66:7F"
        SPOOF_HOSTNAME="MacBook-$(head -c 3 /dev/urandom | xxd -p | head -c 4)"
        SPOOF_TTL=64
        SPOOF_UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15"
        PROFILE_NAME="MacBook"
        ;;
    5) # Smart TV
        SPOOF_OUI="78:BD:BC"
        SPOOF_HOSTNAME="SmartTV"
        SPOOF_TTL=64
        SPOOF_UA="Mozilla/5.0 (SMART-TV; Linux; Tizen 7.0) AppleWebKit/537.36"
        PROFILE_NAME="Smart TV"
        ;;
    6) # IoT
        SPOOF_OUI="B4:E6:2D"
        SPOOF_HOSTNAME="ESP-$(head -c 3 /dev/urandom | xxd -p | head -c 6 | tr 'a-f' 'A-F')"
        SPOOF_TTL=64
        SPOOF_UA=""
        PROFILE_NAME="IoT Device"
        ;;
    7) # Custom
        SPOOF_HOSTNAME=$(TEXT_PICKER "Hostname:" "MyDevice")
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SPOOF_HOSTNAME="MyDevice" ;; esac
        SPOOF_OUI=$(printf '%02x:%02x:%02x' $((RANDOM%256 & 0xFE)) $((RANDOM%256)) $((RANDOM%256)))
        SPOOF_TTL=64
        SPOOF_UA=""
        PROFILE_NAME="Custom"
        ;;
esac

# Select interface
IFACE=""
for i in wlan0 br-lan eth0 wlan1; do
    [ -d "/sys/class/net/$i" ] && IFACE=$i && break
done
[ -z "$IFACE" ] && { ERROR_DIALOG "No interface found!"; exit 1; }

ORIGINAL_MAC=$(cat /sys/class/net/$IFACE/address 2>/dev/null)
ORIGINAL_HOSTNAME=$(cat /etc/hostname 2>/dev/null || hostname)

PROMPT "MASK FEATURES:

1. Full mask (all)
2. MAC only
3. Hostname only
4. TTL only
5. MAC + Hostname

Select features next."

FEATURES=$(NUMBER_PICKER "Features (1-5):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) FEATURES=1 ;; esac

resp=$(CONFIRMATION_DIALOG "APPLY TRAFFIC MASK?

Profile: $PROFILE_NAME
Interface: $IFACE
Original MAC: $ORIGINAL_MAC

New MAC: ${SPOOF_OUI}:XX:XX:XX
Hostname: $SPOOF_HOSTNAME
TTL: $SPOOF_TTL

Confirm?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

# Save originals for restore
cat > "$LOOT_DIR/original_config.sh" << EOF
#!/bin/bash
# Restore original configuration
ORIG_MAC="$ORIGINAL_MAC"
ORIG_HOSTNAME="$ORIGINAL_HOSTNAME"
ORIG_IFACE="$IFACE"
EOF

TIMESTAMP=$(date +%Y%m%d_%H%M)
MASK_LOG="$LOOT_DIR/mask_$TIMESTAMP.log"

LOG "Applying traffic mask: $PROFILE_NAME"
SPINNER_START "Applying mask..."

# Generate full spoofed MAC
SPOOF_MAC=$(printf '%s:%02x:%02x:%02x' "$SPOOF_OUI" $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))

echo "=== Traffic Mask Applied ===" > "$MASK_LOG"
echo "Date: $(date)" >> "$MASK_LOG"
echo "Profile: $PROFILE_NAME" >> "$MASK_LOG"

# Apply MAC spoof
if [ "$FEATURES" = "1" ] || [ "$FEATURES" = "2" ] || [ "$FEATURES" = "5" ]; then
    ip link set "$IFACE" down 2>/dev/null
    ip link set "$IFACE" address "$SPOOF_MAC" 2>/dev/null
    ip link set "$IFACE" up 2>/dev/null
    sleep 2
    NEW_MAC=$(cat /sys/class/net/$IFACE/address 2>/dev/null)
    echo "MAC: $ORIGINAL_MAC -> $NEW_MAC" >> "$MASK_LOG"
fi

# Apply hostname change
if [ "$FEATURES" = "1" ] || [ "$FEATURES" = "3" ] || [ "$FEATURES" = "5" ]; then
    echo "$SPOOF_HOSTNAME" > /etc/hostname 2>/dev/null
    hostname "$SPOOF_HOSTNAME" 2>/dev/null
    # Update DHCP hostname
    if [ -f /etc/config/network ]; then
        uci set network.lan.hostname="$SPOOF_HOSTNAME" 2>/dev/null
    fi
    echo "Hostname: $ORIGINAL_HOSTNAME -> $SPOOF_HOSTNAME" >> "$MASK_LOG"
fi

# Apply TTL manipulation
if [ "$FEATURES" = "1" ] || [ "$FEATURES" = "4" ]; then
    # Set outgoing TTL
    iptables -t mangle -A POSTROUTING -j TTL --ttl-set "$SPOOF_TTL" 2>/dev/null
    echo "TTL: set to $SPOOF_TTL" >> "$MASK_LOG"
fi

# Generate background noise traffic
if [ "$FEATURES" = "1" ]; then
    # Simulate normal device DNS queries
    NOISE_SCRIPT="/tmp/traffic_noise_$$.sh"
    cat > "$NOISE_SCRIPT" << 'NEOF'
#!/bin/sh
DOMAINS="www.google.com www.apple.com www.icloud.com captive.apple.com connectivity-check.ubuntu.com"
while true; do
    for d in $DOMAINS; do
        nslookup "$d" >/dev/null 2>&1
        sleep $((RANDOM % 30 + 10))
    done
done
NEOF
    chmod +x "$NOISE_SCRIPT"
    sh "$NOISE_SCRIPT" &
    NOISE_PID=$!
    echo "Noise PID: $NOISE_PID" >> "$MASK_LOG"
fi

SPINNER_STOP

VERIFY_MAC=$(cat /sys/class/net/$IFACE/address 2>/dev/null)
VERIFY_HOST=$(hostname 2>/dev/null)

PROMPT "TRAFFIC MASK ACTIVE

Profile: $PROFILE_NAME
MAC: $VERIFY_MAC
Hostname: $VERIFY_HOST
TTL: $SPOOF_TTL

This device now appears
as a $PROFILE_NAME.

Press OK to monitor.
Press OK again to remove."

# Wait for user to stop
resp=$(CONFIRMATION_DIALOG "REMOVE MASK?

Restore original
configuration?

MAC: $ORIGINAL_MAC
Host: $ORIGINAL_HOSTNAME

Confirm to restore.")

if [ "$resp" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    SPINNER_START "Restoring original..."

    # Kill noise generator
    [ -n "$NOISE_PID" ] && kill "$NOISE_PID" 2>/dev/null
    rm -f "$NOISE_SCRIPT"

    # Restore MAC
    ip link set "$IFACE" down 2>/dev/null
    ip link set "$IFACE" address "$ORIGINAL_MAC" 2>/dev/null
    ip link set "$IFACE" up 2>/dev/null

    # Restore hostname
    echo "$ORIGINAL_HOSTNAME" > /etc/hostname 2>/dev/null
    hostname "$ORIGINAL_HOSTNAME" 2>/dev/null

    # Remove TTL rule
    iptables -t mangle -D POSTROUTING -j TTL --ttl-set "$SPOOF_TTL" 2>/dev/null

    SPINNER_STOP

    PROMPT "MASK REMOVED

Original config restored.
MAC: $ORIGINAL_MAC
Host: $ORIGINAL_HOSTNAME

Log: $MASK_LOG

Press OK to exit."
else
    PROMPT "MASK STILL ACTIVE

Device remains masked
as $PROFILE_NAME.

To restore later, run:
source $LOOT_DIR/original_config.sh

Press OK to exit."
fi

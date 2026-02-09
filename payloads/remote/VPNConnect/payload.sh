#!/bin/bash
# Title: VPN Connect
# Author: NullSec
# Description: Connects Pineapple to VPN for anonymous operations
# Category: nullsec/remote

LOOT_DIR="/mmc/nullsec/vpnconnect"
mkdir -p "$LOOT_DIR"

PROMPT "VPN CONNECT

Routes Pineapple traffic
through a VPN for anonymous
operations.

Supports:
- WireGuard
- OpenVPN
- Config file import
- IP leak verification
- Kill switch option

Press OK to configure."

# Check connectivity
if ! ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
    ERROR_DIALOG "No internet connection!

VPN requires an active
WAN uplink first."
    exit 1
fi

# Get current public IP
CURRENT_IP=$(curl -s -m 5 ifconfig.me 2>/dev/null || curl -s -m 5 icanhazip.com 2>/dev/null)
[ -z "$CURRENT_IP" ] && CURRENT_IP="unknown"
LOG "Current public IP: $CURRENT_IP"

PROMPT "VPN TYPE:

1. WireGuard
2. OpenVPN

Current IP: $CURRENT_IP

Select VPN type next."

VPN_TYPE=$(NUMBER_PICKER "Type (1-2):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) VPN_TYPE=1 ;; esac
[ "$VPN_TYPE" -lt 1 ] && VPN_TYPE=1
[ "$VPN_TYPE" -gt 2 ] && VPN_TYPE=2

if [ "$VPN_TYPE" -eq 1 ]; then
    # WireGuard setup
    if ! command -v wg >/dev/null 2>&1; then
        resp=$(CONFIRMATION_DIALOG "WireGuard not installed!

Attempt to install it?
Requires opkg packages.

Press OK to install.")
        if [ "$resp" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
            SPINNER_START "Installing WireGuard..."
            opkg update >/dev/null 2>&1
            opkg install wireguard-tools kmod-wireguard >/dev/null 2>&1
            SPINNER_STOP
            if ! command -v wg >/dev/null 2>&1; then
                ERROR_DIALOG "WireGuard install failed!

Check opkg feeds and
storage space."; exit 1
            fi
        else
            exit 1
        fi
    fi

    WG_CONF="$LOOT_DIR/wg0.conf"

    if [ -f "$WG_CONF" ]; then
        PROMPT "Existing WireGuard config
found at:
$WG_CONF

Press OK to use it, or
provide a new config path."
    else
        PROMPT "WIREGUARD CONFIG

Place your WireGuard .conf
file at:
$WG_CONF

Or enter a custom path next.

The config should contain
[Interface] and [Peer]
sections."

        CUSTOM_CONF=$(TEXT_PICKER "Config path:" "$WG_CONF")
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) CUSTOM_CONF="$WG_CONF" ;; esac
        [ -n "$CUSTOM_CONF" ] && WG_CONF="$CUSTOM_CONF"
    fi

    [ ! -f "$WG_CONF" ] && { ERROR_DIALOG "Config not found!

Place WireGuard config at:
$WG_CONF"; exit 1; }

    # Validate config
    if ! grep -q "\[Interface\]" "$WG_CONF" || ! grep -q "\[Peer\]" "$WG_CONF"; then
        ERROR_DIALOG "Invalid WireGuard config!

Must contain [Interface]
and [Peer] sections."; exit 1
    fi

    VPN_NAME="WireGuard"
    ENDPOINT=$(grep -i "Endpoint" "$WG_CONF" | head -1 | awk -F= '{print $2}' | tr -d ' ')

else
    # OpenVPN setup
    if ! command -v openvpn >/dev/null 2>&1; then
        resp=$(CONFIRMATION_DIALOG "OpenVPN not installed!

Attempt to install it?

Press OK to install.")
        if [ "$resp" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
            SPINNER_START "Installing OpenVPN..."
            opkg update >/dev/null 2>&1
            opkg install openvpn-openssl >/dev/null 2>&1
            SPINNER_STOP
            if ! command -v openvpn >/dev/null 2>&1; then
                ERROR_DIALOG "OpenVPN install failed!"; exit 1
            fi
        else
            exit 1
        fi
    fi

    OVPN_CONF="$LOOT_DIR/client.ovpn"

    if [ ! -f "$OVPN_CONF" ]; then
        PROMPT "OPENVPN CONFIG

Place your .ovpn config
file at:
$OVPN_CONF

Or enter a custom path."

        CUSTOM_CONF=$(TEXT_PICKER "Config path:" "$OVPN_CONF")
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) CUSTOM_CONF="$OVPN_CONF" ;; esac
        [ -n "$CUSTOM_CONF" ] && OVPN_CONF="$CUSTOM_CONF"
    fi

    [ ! -f "$OVPN_CONF" ] && { ERROR_DIALOG "Config not found!

Place OpenVPN config at:
$OVPN_CONF"; exit 1; }

    VPN_NAME="OpenVPN"
    ENDPOINT=$(grep -iE "^remote " "$OVPN_CONF" | head -1 | awk '{print $2":"$3}')
fi

PROMPT "VPN OPTIONS:

1. Connect only
2. Connect + kill switch
   (block non-VPN traffic)
3. Connect + DNS override
   (use VPN DNS servers)

Select option next."

VPN_OPT=$(NUMBER_PICKER "Option (1-3):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) VPN_OPT=1 ;; esac

resp=$(CONFIRMATION_DIALOG "CONNECT VPN?

Type: $VPN_NAME
Endpoint: ${ENDPOINT:-unknown}
Current IP: $CURRENT_IP
Kill switch: $([ $VPN_OPT -eq 2 ] && echo 'YES' || echo 'NO')
DNS override: $([ $VPN_OPT -eq 3 ] && echo 'YES' || echo 'NO')

Press OK to connect.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
VPN_LOG="$LOOT_DIR/vpn_$TIMESTAMP.log"
PID_FILE="$LOOT_DIR/vpn.pid"

# Kill existing VPN
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    kill "$OLD_PID" 2>/dev/null
fi
# Cleanup previous interfaces
ip link del wg0 2>/dev/null
killall openvpn 2>/dev/null

LOG "Starting $VPN_NAME connection"
SPINNER_START "Connecting to VPN..."

if [ "$VPN_TYPE" -eq 1 ]; then
    # WireGuard connect
    cp "$WG_CONF" /etc/wireguard/wg0.conf 2>/dev/null || cp "$WG_CONF" /tmp/wg0.conf
    ip link add dev wg0 type wireguard 2>>"$VPN_LOG"
    wg setconf wg0 <(grep -v "^Address\|^DNS\|^\[Interface\]\|^$" "$WG_CONF") 2>>"$VPN_LOG"

    WG_ADDR=$(grep -i "^Address" "$WG_CONF" | awk -F= '{print $2}' | tr -d ' ')
    ip addr add "$WG_ADDR" dev wg0 2>>"$VPN_LOG"
    ip link set wg0 up 2>>"$VPN_LOG"
    ip route add default dev wg0 table 200 2>>"$VPN_LOG"
    ip rule add from "$WG_ADDR" table 200 2>>"$VPN_LOG"

    sleep 2
    VPN_UP=$(ip link show wg0 2>/dev/null | grep -c "UP")
    echo "$BASHPID" > "$PID_FILE"
else
    # OpenVPN connect
    openvpn --config "$OVPN_CONF" --daemon --log "$VPN_LOG" --writepid "$PID_FILE" 2>>"$VPN_LOG"
    sleep 8
    VPN_UP=$(ip link show tun0 2>/dev/null | grep -c "UP")
fi

# Kill switch (block non-VPN traffic)
if [ "$VPN_OPT" -eq 2 ] && [ "${VPN_UP:-0}" -gt 0 ]; then
    VPN_IF=$([ "$VPN_TYPE" -eq 1 ] && echo "wg0" || echo "tun0")
    # Save current rules
    iptables-save > "$LOOT_DIR/iptables_backup_$TIMESTAMP.rules" 2>/dev/null
    # Block non-VPN
    iptables -I OUTPUT -o "$VPN_IF" -j ACCEPT 2>/dev/null
    iptables -I OUTPUT -d "$(echo "$ENDPOINT" | cut -d: -f1)" -j ACCEPT 2>/dev/null
    iptables -I OUTPUT -o lo -j ACCEPT 2>/dev/null
    iptables -A OUTPUT -j DROP 2>/dev/null
    LOG "Kill switch enabled"
fi

# DNS override
if [ "$VPN_OPT" -eq 3 ] && [ "${VPN_UP:-0}" -gt 0 ]; then
    VPN_DNS=$(grep -i "^DNS" "$WG_CONF" 2>/dev/null | awk -F= '{print $2}' | tr -d ' ' | cut -d, -f1)
    [ -z "$VPN_DNS" ] && VPN_DNS="1.1.1.1"
    cp /etc/resolv.conf "$LOOT_DIR/resolv_backup_$TIMESTAMP.conf"
    echo "nameserver $VPN_DNS" > /etc/resolv.conf
    LOG "DNS override: $VPN_DNS"
fi

SPINNER_STOP

# Verify new IP
sleep 2
NEW_IP=$(curl -s -m 10 ifconfig.me 2>/dev/null || curl -s -m 10 icanhazip.com 2>/dev/null)
[ -z "$NEW_IP" ] && NEW_IP="unknown"

if [ "${VPN_UP:-0}" -gt 0 ]; then
    IP_CHANGED=$([ "$CURRENT_IP" != "$NEW_IP" ] && echo "YES" || echo "NO")
    LOG "VPN connected. IP: $CURRENT_IP -> $NEW_IP"

    PROMPT "VPN CONNECTED

Type: $VPN_NAME
Old IP: $CURRENT_IP
New IP: $NEW_IP
IP changed: $IP_CHANGED
Kill switch: $([ $VPN_OPT -eq 2 ] && echo 'ON' || echo 'OFF')

Log: $VPN_LOG

To disconnect:
$([ $VPN_TYPE -eq 1 ] && echo 'ip link del wg0' || echo 'killall openvpn')"
else
    ERROR_DIALOG "VPN FAILED

Could not establish tunnel.
Check config and endpoint.

Log: $VPN_LOG"
fi

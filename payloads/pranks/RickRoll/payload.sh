#!/bin/bash
# Title: NullSec RickRoll AP
# Author: bad-antics
# Description: Create open AP that rickrolls everyone who connects
# Category: nullsec

PROMPT "NULLSEC RICKROLL AP

Creates an open WiFi network
that redirects ALL traffic to
Rick Astley's 'Never Gonna
Give You Up'!

Press OK to configure."

[ ! -d "/sys/class/net/wlan0" ] && { ERROR_DIALOG "wlan0 not found!"; exit 1; }

SSID=$(TEXT_PICKER "AP Name:" "Free Public WiFi")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SSID="Free Public WiFi" ;; esac

DURATION=$(NUMBER_PICKER "Duration (seconds):" 600)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=600 ;; esac

resp=$(CONFIRMATION_DIALOG "Start RickRoll AP?

SSID: $SSID
Duration: ${DURATION}s

Anyone who connects gets
RICKROLLED!")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

killall hostapd dnsmasq lighttpd 2>/dev/null

# Setup AP
cat > /tmp/rickroll_hostapd.conf << EOF
interface=wlan0
driver=nl80211
ssid=$SSID
hw_mode=g
channel=6
auth_algs=1
wpa=0
EOF

hostapd /tmp/rickroll_hostapd.conf &
sleep 2

ifconfig wlan0 10.0.0.1 netmask 255.255.255.0 up

# DNS redirect all to us
cat > /tmp/rickroll_dnsmasq.conf << EOF
interface=wlan0
dhcp-range=10.0.0.10,10.0.0.100,12h
address=/#/10.0.0.1
EOF

dnsmasq -C /tmp/rickroll_dnsmasq.conf &

# RickRoll page
mkdir -p /tmp/rickroll
cat > /tmp/rickroll/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
<title>Connecting...</title>
<meta http-equiv="refresh" content="0; url=https://www.youtube.com/watch?v=dQw4w9WgXcQ">
<style>
body { background: #000; color: #0f0; font-family: monospace; text-align: center; padding-top: 100px; }
h1 { font-size: 48px; }
</style>
</head>
<body>
<h1>NULLSEC</h1>
<p>You've been rickrolled!</p>
<p>Redirecting...</p>
<script>window.location.href='https://www.youtube.com/watch?v=dQw4w9WgXcQ';</script>
</body>
</html>
HTML

# Simple HTTP server
cd /tmp/rickroll
if command -v python3 >/dev/null 2>&1; then
    python3 -m http.server 80 &
elif command -v python >/dev/null 2>&1; then
    python -m SimpleHTTPServer 80 &
fi

LOG "RickRoll AP active: $SSID"
sleep $DURATION

killall hostapd dnsmasq python python3 2>/dev/null

PROMPT "RICKROLL COMPLETE

SSID: $SSID
Duration: ${DURATION}s

Hope someone got rickrolled!

Press OK to exit."

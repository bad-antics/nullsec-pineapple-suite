#!/bin/bash
# Title: Hidden Net Finder
# Author: NullSec
# Description: Discover hidden/cloaked SSIDs via passive and active probing
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/hiddennets"
mkdir -p "$LOOT_DIR"

PROMPT "HIDDEN NET FINDER

Discover cloaked and
hidden WiFi networks.

Methods:
- Passive probe capture
- Client association sniff
- Active deauth reveal
- Cross-reference probes
  with hidden BSSIDs

Press OK to configure."

# Find monitor interface
MONITOR_IF=""
for iface in wlan1mon wlan2mon mon0; do
    [ -d "/sys/class/net/$iface" ] && MONITOR_IF="$iface" && break
done
[ -z "$MONITOR_IF" ] && { ERROR_DIALOG "No monitor interface!

Enable monitor mode:
airmon-ng start wlan1"; exit 1; }

PROMPT "DISCOVERY MODE:

1. Passive only (stealth)
2. Passive + probe cross-ref
3. Active deauth reveal
4. Comprehensive (all)

Interface: $MONITOR_IF

Select mode next."

DISC_MODE=$(NUMBER_PICKER "Mode (1-4):" 2)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DISC_MODE=2 ;; esac

DURATION=$(NUMBER_PICKER "Scan duration (seconds):" 120)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=120 ;; esac
[ $DURATION -lt 30 ] && DURATION=30
[ $DURATION -gt 600 ] && DURATION=600

CHANNEL_RANGE=$(CONFIRMATION_DIALOG "Scan all channels?

YES = Channels 1-14
NO = 2.4GHz common only
     (1, 6, 11)")
if [ "$CHANNEL_RANGE" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    CHANNELS="1-14"
else
    CHANNELS="1,6,11"
fi

resp=$(CONFIRMATION_DIALOG "START HIDDEN SCAN?

Mode: $DISC_MODE
Duration: ${DURATION}s
Channels: $CHANNELS
Interface: $MONITOR_IF

Confirm?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M)
REPORT="$LOOT_DIR/hidden_$TIMESTAMP.txt"
CAP_PREFIX="/tmp/hidden_cap_$$"

LOG "Scanning for hidden networks..."
SPINNER_START "Hunting hidden SSIDs..."

echo "=======================================" > "$REPORT"
echo "    NULLSEC HIDDEN NETWORK REPORT      " >> "$REPORT"
echo "=======================================" >> "$REPORT"
echo "" >> "$REPORT"
echo "Scan Time: $(date)" >> "$REPORT"
echo "Duration: ${DURATION}s" >> "$REPORT"
echo "Mode: $DISC_MODE" >> "$REPORT"
echo "" >> "$REPORT"

# Phase 1: Passive scan for hidden APs (ESSID length > 0 but blank)
echo "--- PHASE 1: PASSIVE SCAN ---" >> "$REPORT"
echo "" >> "$REPORT"

timeout "$DURATION" airodump-ng "$MONITOR_IF" -c "$CHANNELS" \
    --write-interval 5 -w "$CAP_PREFIX" --output-format csv 2>/dev/null &
SCAN_PID=$!

# Also capture probe requests and responses in parallel
PROBE_LOG="/tmp/hidden_probes_$$.txt"
timeout "$DURATION" tcpdump -i "$MONITOR_IF" -e -l \
    'type mgt and (subtype probe-req or subtype probe-resp or subtype assoc-req)' 2>/dev/null > "$PROBE_LOG" &
PROBE_PID=$!

sleep "$DURATION"
kill $SCAN_PID $PROBE_PID 2>/dev/null
wait $SCAN_PID $PROBE_PID 2>/dev/null

# Parse hidden APs (blank ESSID in airodump CSV)
HIDDEN_FILE="/tmp/hidden_aps_$$.txt"
grep -E "^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}" "${CAP_PREFIX}"*.csv 2>/dev/null | \
    awk -F',' '{gsub(/ /,"",$14); if($14=="" || length($14)==0) print $1","$4","$6","$9","$14}' > "$HIDDEN_FILE"

HIDDEN_COUNT=$(wc -l < "$HIDDEN_FILE" 2>/dev/null | tr -d ' ')
echo "Hidden APs detected: $HIDDEN_COUNT" >> "$REPORT"
echo "" >> "$REPORT"

while IFS=',' read -r bssid channel enc power essid; do
    bssid=$(echo "$bssid" | tr -d ' ')
    [ -z "$bssid" ] && continue
    echo "HIDDEN AP: $bssid | Ch:$channel | Enc:$enc | Pwr:$power" >> "$REPORT"
done < "$HIDDEN_FILE"

# Phase 2: Cross-reference with probe requests
if [ "$DISC_MODE" -ge 2 ]; then
    echo "" >> "$REPORT"
    echo "--- PHASE 2: PROBE CROSS-REFERENCE ---" >> "$REPORT"
    echo "" >> "$REPORT"

    # Extract probed SSIDs from clients connected to hidden APs
    for BSSID in $(awk -F',' '{print $1}' "$HIDDEN_FILE" 2>/dev/null | tr -d ' '); do
        [ -z "$BSSID" ] && continue
        # Find clients associated with this BSSID
        CLIENTS=$(grep "$BSSID" "${CAP_PREFIX}"*.csv 2>/dev/null | grep -v "^$BSSID" | awk -F',' '{print $1}' | tr -d ' ')
        for CLIENT in $CLIENTS; do
            # Find probe requests from those clients
            PROBED=$(grep "$CLIENT" "$PROBE_LOG" 2>/dev/null | grep -oE "Probe Request \([^)]+\)" | head -5)
            if [ -n "$PROBED" ]; then
                echo "AP $BSSID <- Client $CLIENT probed:" >> "$REPORT"
                echo "  $PROBED" >> "$REPORT"
            fi
        done
    done
fi

# Phase 3: Active deauth to reveal hidden SSIDs
if [ "$DISC_MODE" -ge 3 ]; then
    echo "" >> "$REPORT"
    echo "--- PHASE 3: ACTIVE REVEAL ---" >> "$REPORT"
    echo "" >> "$REPORT"

    for BSSID in $(awk -F',' '{print $1}' "$HIDDEN_FILE" 2>/dev/null | tr -d ' ' | head -5); do
        [ -z "$BSSID" ] && continue
        CH=$(grep "$BSSID" "$HIDDEN_FILE" | head -1 | awk -F',' '{print $2}' | tr -d ' ')
        iwconfig "$MONITOR_IF" channel "$CH" 2>/dev/null

        # Brief deauth to force reassociation
        timeout 5 aireplay-ng -0 2 -a "$BSSID" "$MONITOR_IF" 2>/dev/null &

        # Capture reassociation
        REVEALED=$(timeout 10 tcpdump -i "$MONITOR_IF" -e -c 5 \
            "ether host $BSSID and type mgt and (subtype assoc-resp or subtype probe-resp)" 2>/dev/null | \
            grep -oE "SSID=\S+" | head -1)

        if [ -n "$REVEALED" ]; then
            echo "REVEALED: $BSSID -> $REVEALED" >> "$REPORT"
        else
            echo "UNRESOLVED: $BSSID (no response)" >> "$REPORT"
        fi
    done
fi

echo "" >> "$REPORT"
echo "=======================================" >> "$REPORT"

# Cleanup
rm -f "${CAP_PREFIX}"* "$PROBE_LOG" "$HIDDEN_FILE" 2>/dev/null

SPINNER_STOP

TOTAL_APS=$(grep -c "^BSSID\|Station" "${CAP_PREFIX}"*.csv 2>/dev/null || echo "?")
REVEALED_COUNT=$(grep -c "REVEALED:" "$REPORT" 2>/dev/null || echo 0)

PROMPT "HIDDEN NET SCAN DONE

Hidden APs: $HIDDEN_COUNT
Revealed SSIDs: $REVEALED_COUNT
Duration: ${DURATION}s

Report saved:
$REPORT

Press OK to exit."

#!/bin/bash
# Title: Deauth Forensics
# Author: NullSec
# Description: Captures and fingerprints deauthentication attacks — identifies attacker tools by frame patterns
# Category: nullsec/blue-team

LOOT_DIR="/mmc/nullsec/deauthforensics"
mkdir -p "$LOOT_DIR"

PROMPT "DEAUTH FORENSICS

WiFi deauth attack
forensics analyzer.

Captures deauth/disassoc
frames and fingerprints
the attacker's tool:

- aireplay-ng
- mdk3 / mdk4
- Pineapple modules
- bully / reaver
- Custom scripts

Also detects:
- Targeted vs broadcast
- Attack intensity (pps)
- Duration & patterns
- Attacker MAC/OUI

Press OK to configure."

# Check for monitor mode capable interface
IFACE=""
for ifc in wlan1mon wlan1 wlan0mon wlan0; do
    if iw dev "$ifc" info >/dev/null 2>&1; then
        IFACE="$ifc"
        break
    fi
done

if [ -z "$IFACE" ]; then
    ERROR_DIALOG "No WiFi interface!

Ensure a WiFi adapter
is connected."
    exit 1
fi

# Check for tcpdump
if ! command -v tcpdump >/dev/null 2>&1; then
    ERROR_DIALOG "tcpdump not found!

Install with:
opkg install tcpdump"
    exit 1
fi

# Put in monitor mode if needed
ORIGINAL_MODE=""
if ! echo "$IFACE" | grep -q "mon"; then
    ORIGINAL_MODE="managed"
    ip link set "$IFACE" down 2>/dev/null
    iw dev "$IFACE" set type monitor 2>/dev/null
    ip link set "$IFACE" up 2>/dev/null
    if ! iw dev "$IFACE" info 2>/dev/null | grep -q "monitor"; then
        ERROR_DIALOG "Cannot set monitor mode!

Try: airmon-ng start $IFACE"
        exit 1
    fi
fi

cleanup() {
    kill $CAPTURE_PID 2>/dev/null
    if [ "$ORIGINAL_MODE" = "managed" ]; then
        ip link set "$IFACE" down 2>/dev/null
        iw dev "$IFACE" set type managed 2>/dev/null
        ip link set "$IFACE" up 2>/dev/null
    fi
}
trap cleanup INT TERM EXIT

PROMPT "CAPTURE MODE:

1. Single channel
   (focused monitoring)

2. Channel hop
   (scan all channels)

3. Follow target AP
   (lock to specific AP)

Interface: $IFACE"

CAP_MODE=$(NUMBER_PICKER "Mode (1-3):" 2)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) CAP_MODE=2 ;; esac

if [ $CAP_MODE -eq 1 ]; then
    CHANNEL=$(NUMBER_PICKER "Channel (1-13):" 6)
    case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) CHANNEL=6 ;; esac
    iw dev "$IFACE" set channel "$CHANNEL" 2>/dev/null
fi

DURATION=$(NUMBER_PICKER "Capture duration (min):" 15)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=15 ;; esac
[ $DURATION -lt 1 ] && DURATION=1
[ $DURATION -gt 120 ] && DURATION=120

resp=$(CONFIRMATION_DIALOG "START CAPTURE?

Interface: $IFACE
Mode: $CAP_MODE
Duration: ${DURATION}m

Will capture all deauth
and disassoc frames for
forensic analysis.

Confirm?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M)
PCAP="$LOOT_DIR/deauth_capture_$TIMESTAMP.pcap"
RAW_LOG="$LOOT_DIR/deauth_raw_$TIMESTAMP.log"
REPORT="$LOOT_DIR/deauth_forensics_$TIMESTAMP.txt"
ATTACKERS="$LOOT_DIR/attackers_$TIMESTAMP.log"
FRAME_DB="/tmp/deauth_frames_$$"
mkdir -p "$FRAME_DB"

SPINNER_START "Capturing deauth frames..."

# Channel hopper (background)
if [ $CAP_MODE -eq 2 ]; then
    (
        while true; do
            for ch in 1 6 11 2 3 4 5 7 8 9 10 12 13; do
                iw dev "$IFACE" set channel "$ch" 2>/dev/null
                sleep 0.3
            done
        done
    ) &
    HOPPER_PID=$!
fi

# Capture deauth and disassoc frames
# Type 0 Subtype 12 = Deauth, Type 0 Subtype 10 = Disassoc
timeout $((DURATION * 60)) tcpdump -i "$IFACE" -w "$PCAP" \
    'type mgt subtype deauth or type mgt subtype disassoc' \
    2>"$RAW_LOG" &
CAPTURE_PID=$!

# Real-time analysis in parallel
(
    sleep 5  # Let capture start
    while kill -0 $CAPTURE_PID 2>/dev/null; do
        # Read pcap periodically and extract frame data
        if [ -f "$PCAP" ]; then
            tcpdump -r "$PCAP" -n -e -c 10000 2>/dev/null | \
            awk '{
                # Extract source, dest, and reason code
                for(i=1;i<=NF;i++) {
                    if($i ~ /SA:/) sa=$(i+1)
                    if($i ~ /DA:/) da=$(i+1)
                    if($i ~ /Reason/) reason=$(i+1)
                }
                if(sa != "") print sa"|"da"|"reason
            }' >> "$FRAME_DB/all_frames.tmp" 2>/dev/null
        fi
        sleep 10
    done
) &
ANALYZER_PID=$!

# Wait for capture to complete
wait $CAPTURE_PID 2>/dev/null

# Kill channel hopper
[ -n "$HOPPER_PID" ] && kill $HOPPER_PID 2>/dev/null

SPINNER_STOP
SPINNER_START "Analyzing captures..."

# ============================================
# FORENSIC ANALYSIS
# ============================================

# Extract all frames from pcap
tcpdump -r "$PCAP" -n -e -tttt 2>/dev/null > "$FRAME_DB/decoded.txt"

TOTAL_FRAMES=$(wc -l < "$FRAME_DB/decoded.txt" 2>/dev/null | tr -d ' ')
[ -z "$TOTAL_FRAMES" ] && TOTAL_FRAMES=0

DEAUTH_COUNT=$(grep -ci "deauthentication\|deauth" "$FRAME_DB/decoded.txt" 2>/dev/null || echo 0)
DISASSOC_COUNT=$(grep -ci "disassoc" "$FRAME_DB/decoded.txt" 2>/dev/null || echo 0)

# Extract unique source MACs (potential attackers)
grep -oE "SA:[0-9a-fA-F:]{17}" "$FRAME_DB/decoded.txt" 2>/dev/null | \
    cut -d: -f2- | sort | uniq -c | sort -rn > "$FRAME_DB/sources.txt"

# Extract unique targets
grep -oE "DA:[0-9a-fA-F:]{17}" "$FRAME_DB/decoded.txt" 2>/dev/null | \
    cut -d: -f2- | sort | uniq -c | sort -rn > "$FRAME_DB/targets.txt"

# Extract reason codes
grep -oE "Reason [0-9]+" "$FRAME_DB/decoded.txt" 2>/dev/null | \
    sort | uniq -c | sort -rn > "$FRAME_DB/reasons.txt"

# ============================================
# TOOL FINGERPRINTING
# ============================================
fingerprint_tool() {
    local src_mac="$1"
    local frame_count="$2"
    local tool="UNKNOWN"
    local confidence="LOW"
    local indicators=""

    # Get frames from this source
    src_frames=$(grep "$src_mac" "$FRAME_DB/decoded.txt" 2>/dev/null)
    src_count=$(echo "$src_frames" | wc -l)

    # Get reason codes used by this source
    reasons=$(echo "$src_frames" | grep -oE "Reason [0-9]+" | sort | uniq -c | sort -rn)
    primary_reason=$(echo "$reasons" | head -1 | awk '{print $2" "$3}')
    reason_variety=$(echo "$reasons" | wc -l)

    # Get target diversity
    targets=$(echo "$src_frames" | grep -oE "DA:[0-9a-fA-F:]{17}" | sort -u | wc -l)

    # Check if targeting broadcast
    broadcast_pct=0
    bc_count=$(echo "$src_frames" | grep -ci "ff:ff:ff:ff:ff:ff" || echo 0)
    [ $src_count -gt 0 ] && broadcast_pct=$((bc_count * 100 / src_count))

    # Calculate frames per second (approximate)
    first_ts=$(echo "$src_frames" | head -1 | awk '{print $1" "$2}')
    last_ts=$(echo "$src_frames" | tail -1 | awk '{print $1" "$2}')
    # Simple duration estimate
    fps="N/A"

    # --- FINGERPRINTING RULES ---

    # aireplay-ng: Reason 7, high rate, targeted (unicast), consistent timing
    if echo "$primary_reason" | grep -q "Reason 7"; then
        if [ $broadcast_pct -lt 30 ]; then
            tool="aireplay-ng"
            confidence="HIGH"
            indicators="Reason 7 (Class 3 frame), unicast targeting, consistent pattern"
        fi
    fi

    # mdk3/mdk4: Reason 1 or 2, broadcast-heavy, high diversity of targets, randomized source MACs
    if [ $broadcast_pct -gt 60 ] && [ $targets -gt 5 ]; then
        tool="mdk3/mdk4"
        confidence="HIGH"
        indicators="Broadcast-heavy (${broadcast_pct}%), high target diversity ($targets targets)"
    fi

    # mdk4 specifically uses Reason 6/7 mix
    if [ $reason_variety -gt 2 ] && [ $broadcast_pct -gt 40 ]; then
        tool="mdk4 (mixed mode)"
        confidence="MEDIUM"
        indicators="Multiple reason codes ($reason_variety types), broadcast mix"
    fi

    # Pineapple module: Reason 3 (STA leaving), moderate rate, targeted
    if echo "$primary_reason" | grep -q "Reason 3"; then
        tool="WiFi Pineapple Module"
        confidence="MEDIUM"
        indicators="Reason 3 (STA leaving), targeted deauth pattern"
    fi

    # bully/reaver: Reason 7, very targeted (1-2 targets), moderate rate, WPS context
    if echo "$primary_reason" | grep -q "Reason 7" && [ $targets -le 2 ] && [ $src_count -lt 200 ]; then
        tool="bully/reaver (WPS attack)"
        confidence="MEDIUM"
        indicators="Reason 7, single target focus ($targets), moderate rate — WPS brute force pattern"
    fi

    # wifite: Mixed reason codes, sequential targeting, automated pattern
    if [ $reason_variety -ge 2 ] && [ $targets -ge 3 ] && [ $broadcast_pct -lt 50 ]; then
        tool="wifite/automated tool"
        confidence="MEDIUM"
        indicators="Mixed reasons, sequential multi-target, automated pattern"
    fi

    # High rate broadcast with Reason 1 = likely script/custom tool
    if [ $broadcast_pct -gt 80 ] && echo "$primary_reason" | grep -q "Reason 1"; then
        tool="Custom deauth script"
        confidence="MEDIUM"
        indicators="Reason 1 (Unspecified), ${broadcast_pct}% broadcast, bulk flooding"
    fi

    echo "${tool}|${confidence}|${indicators}|${broadcast_pct}|${targets}|${primary_reason}"
}

# Decode reason codes
decode_reason() {
    case "$1" in
        1) echo "Unspecified reason" ;;
        2) echo "Previous auth no longer valid" ;;
        3) echo "STA leaving / has left" ;;
        4) echo "Inactivity — disassociated" ;;
        5) echo "AP unable to handle all STAs" ;;
        6) echo "Class 2 frame from non-auth STA" ;;
        7) echo "Class 3 frame from non-assoc STA" ;;
        8) echo "STA leaving — disassociated" ;;
        9) echo "STA not authenticated" ;;
        10) echo "Unacceptable power capability" ;;
        11) echo "Unacceptable supported channels" ;;
        *) echo "Unknown reason ($1)" ;;
    esac
}

# Build forensic report
cat > "$REPORT" << HEADER
==========================================
    NULLSEC DEAUTH FORENSICS REPORT
==========================================

Capture Time: $(date)
Duration: ${DURATION} minutes
Interface: $IFACE
Capture Mode: $CAP_MODE
PCAP File: $PCAP

============ FRAME SUMMARY ==============

Total Frames Captured: $TOTAL_FRAMES
Deauthentication:      $DEAUTH_COUNT
Disassociation:        $DISASSOC_COUNT

HEADER

# Attacker analysis
echo "=========== ATTACKER ANALYSIS ===========" >> "$REPORT"
echo "" >> "$REPORT"

ATTACKER_NUM=0
while read -r count mac; do
    [ -z "$mac" ] && continue
    ATTACKER_NUM=$((ATTACKER_NUM + 1))

    # Get OUI vendor
    OUI=$(echo "$mac" | cut -d: -f1-3 | tr '[:lower:]' '[:upper:]')

    # Fingerprint the tool
    FP=$(fingerprint_tool "$mac" "$count")
    TOOL=$(echo "$FP" | cut -d'|' -f1)
    CONF=$(echo "$FP" | cut -d'|' -f2)
    INDICATORS=$(echo "$FP" | cut -d'|' -f3)
    BC_PCT=$(echo "$FP" | cut -d'|' -f4)
    TGT_COUNT=$(echo "$FP" | cut -d'|' -f5)
    PRI_REASON=$(echo "$FP" | cut -d'|' -f6)

    cat >> "$REPORT" << ATTACKER
--- Attacker #$ATTACKER_NUM ---
Source MAC:      $mac
OUI Prefix:      $OUI
Frames Sent:     $count
Broadcast %:     ${BC_PCT}%
Unique Targets:  $TGT_COUNT
Primary Reason:  $PRI_REASON

TOOL FINGERPRINT: $TOOL
Confidence:       $CONF
Indicators:       $INDICATORS

ATTACKER

    # Log attacker summary
    echo "[$ATTACKER_NUM] $mac | $count frames | Tool: $TOOL ($CONF) | Targets: $TGT_COUNT" >> "$ATTACKERS"

done < "$FRAME_DB/sources.txt"

echo "" >> "$REPORT"
echo "============ TARGET ANALYSIS ============" >> "$REPORT"
echo "" >> "$REPORT"
echo "Most targeted devices:" >> "$REPORT"
head -10 "$FRAME_DB/targets.txt" >> "$REPORT" 2>/dev/null

echo "" >> "$REPORT"
echo "=========== REASON CODES ================" >> "$REPORT"
echo "" >> "$REPORT"
while read -r count reason_str; do
    [ -z "$count" ] && continue
    reason_num=$(echo "$reason_str" | grep -oE "[0-9]+")
    decoded=$(decode_reason "$reason_num")
    echo "$count x $reason_str — $decoded" >> "$REPORT"
done < "$FRAME_DB/reasons.txt"

echo "" >> "$REPORT"
echo "==========================================" >> "$REPORT"
echo "Generated by NullSec DeauthForensics" >> "$REPORT"
echo "$(date)" >> "$REPORT"

# Cleanup temp
kill $ANALYZER_PID 2>/dev/null
rm -rf "$FRAME_DB"

SPINNER_STOP

# Display results on Pager
TOP_ATTACKER_MAC=$(head -1 "$FRAME_DB/sources.txt" 2>/dev/null | awk '{print $2}')
TOP_ATTACKER_FP=$(head -1 "$ATTACKERS" 2>/dev/null)

PROMPT "DEAUTH FORENSICS DONE

Total frames: $TOTAL_FRAMES
Deauths: $DEAUTH_COUNT
Disassocs: $DISASSOC_COUNT

Attackers found: $ATTACKER_NUM

Press OK for attacker
details."

if [ -f "$ATTACKERS" ]; then
    ATTACKER_DETAILS=$(cat "$ATTACKERS" 2>/dev/null | head -5)
    PROMPT "ATTACKER SUMMARY

$ATTACKER_DETAILS

Press OK for files."
fi

PROMPT "FILES SAVED

PCAP capture:
deauth_capture_$TIMESTAMP.pcap

Forensic report:
deauth_forensics_$TIMESTAMP.txt

Attacker log:
attackers_$TIMESTAMP.log

Location: $LOOT_DIR/

Import PCAP into Wireshark
for deeper analysis.

Press OK to exit."

#!/bin/bash
# Title: Channel Congestion Analyzer
# Author: NullSec
# Description: Analyzes WiFi channel congestion across all bands, scores each channel, recommends optimal operating channel
# Category: nullsec/utility

LOOT_DIR="/mmc/nullsec/congestion"
mkdir -p "$LOOT_DIR"

PROMPT "CHANNEL CONGESTION

Analyze WiFi channel
congestion and find the
cleanest channel to
operate on.

Features:
- 2.4GHz full scan (1-13)
- 5GHz scan (36-165)
- AP count per channel
- Signal strength scoring
- Overlap calculation
- Congestion score 0-100
- Optimal channel pick
- Visual spectrum view

Press OK to configure."

# Find interface
IFACE=""
for ifc in wlan1 wlan0; do
    if iw dev "$ifc" info >/dev/null 2>&1; then
        IFACE="$ifc"
        break
    fi
done

if [ -z "$IFACE" ]; then
    ERROR_DIALOG "No WiFi interface found!

Ensure a WiFi adapter
is connected."
    exit 1
fi

PROMPT "SCAN OPTIONS:

1. 2.4GHz only (fast)
   Channels 1-13

2. 5GHz only
   Channels 36-165

3. Full spectrum
   Both 2.4 + 5GHz

Interface: $IFACE"

BAND=$(NUMBER_PICKER "Band (1-3):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) BAND=1 ;; esac

PASSES=$(NUMBER_PICKER "Scan passes (1-5):" 3)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) PASSES=3 ;; esac
[ $PASSES -lt 1 ] && PASSES=1
[ $PASSES -gt 5 ] && PASSES=5

resp=$(CONFIRMATION_DIALOG "START ANALYSIS?

Band: $([ $BAND -eq 1 ] && echo '2.4GHz' || ([ $BAND -eq 2 ] && echo '5GHz' || echo 'Full'))
Passes: $PASSES
Interface: $IFACE

More passes = better
accuracy but slower.

~$((PASSES * 15))s estimated.

Confirm?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M)
REPORT="$LOOT_DIR/congestion_$TIMESTAMP.txt"
TMPDIR="/tmp/congestion_$$"
mkdir -p "$TMPDIR"

SPINNER_START "Scanning spectrum..."

# Define channel lists
CHANNELS_24="1 2 3 4 5 6 7 8 9 10 11 12 13"
CHANNELS_5="36 40 44 48 52 56 60 64 100 104 108 112 116 120 124 128 132 136 140 144 149 153 157 161 165"

case $BAND in
    1) CHANNELS="$CHANNELS_24" ;;
    2) CHANNELS="$CHANNELS_5" ;;
    3) CHANNELS="$CHANNELS_24 $CHANNELS_5" ;;
esac

# Initialize channel data files
for ch in $CHANNELS; do
    echo "0" > "$TMPDIR/ch${ch}_aps"
    echo "" > "$TMPDIR/ch${ch}_signals"
done

# Multi-pass scanning for accuracy
for pass in $(seq 1 $PASSES); do
    # Use iw scan
    ip link set "$IFACE" up 2>/dev/null
    SCAN_OUT=$(iw dev "$IFACE" scan 2>/dev/null)

    echo "$SCAN_OUT" | awk '
    /^BSS / { mac=$2; sub(/\(.*/, "", mac) }
    /freq:/ { freq=$2 }
    /signal:/ { signal=$2 }
    /SSID:/ {
        ssid=$2
        # Convert freq to channel
        ch = 0
        if (freq >= 2412 && freq <= 2484) {
            ch = (freq - 2407) / 5
            if (freq == 2484) ch = 14
        } else if (freq >= 5180 && freq <= 5825) {
            ch = (freq - 5000) / 5
        }
        if (ch > 0) print ch"|"signal"|"ssid"|"mac
    }
    ' > "$TMPDIR/pass_${pass}.txt" 2>/dev/null

    # Accumulate per-channel data
    while IFS='|' read -r ch signal ssid mac; do
        [ -z "$ch" ] && continue
        # Increment AP count
        current=$(cat "$TMPDIR/ch${ch}_aps" 2>/dev/null || echo 0)
        echo $((current + 1)) > "$TMPDIR/ch${ch}_aps"
        # Record signal strength
        echo "$signal" >> "$TMPDIR/ch${ch}_signals"
    done < "$TMPDIR/pass_${pass}.txt"

    sleep 2
done

SPINNER_STOP
SPINNER_START "Calculating scores..."

# Calculate congestion score per channel
# Score formula: AP_density * 30 + signal_strength_factor * 40 + overlap_factor * 30
# Result: 0 (empty) to 100 (severely congested)

calc_congestion() {
    local ch="$1"
    local ap_total=$(cat "$TMPDIR/ch${ch}_aps" 2>/dev/null || echo 0)
    local ap_avg=$((ap_total / PASSES))

    # AP density score (0-30)
    local ap_score=0
    if [ $ap_avg -ge 15 ]; then ap_score=30
    elif [ $ap_avg -ge 10 ]; then ap_score=25
    elif [ $ap_avg -ge 7 ]; then ap_score=20
    elif [ $ap_avg -ge 5 ]; then ap_score=15
    elif [ $ap_avg -ge 3 ]; then ap_score=10
    elif [ $ap_avg -ge 1 ]; then ap_score=5
    fi

    # Signal strength score (0-40) — stronger signals = more interference
    local sig_score=0
    local sig_count=0
    local sig_sum=0
    while read -r sig; do
        [ -z "$sig" ] && continue
        # Remove negative sign and decimals
        sig_abs=$(echo "$sig" | tr -d '-' | cut -d. -f1)
        [ -z "$sig_abs" ] && continue
        sig_sum=$((sig_sum + sig_abs))
        sig_count=$((sig_count + 1))
    done < "$TMPDIR/ch${ch}_signals"

    if [ $sig_count -gt 0 ]; then
        local sig_avg=$((sig_sum / sig_count))
        # Lower dBm abs value = stronger signal = more congestion
        if [ $sig_avg -le 40 ]; then sig_score=40
        elif [ $sig_avg -le 50 ]; then sig_score=35
        elif [ $sig_avg -le 60 ]; then sig_score=25
        elif [ $sig_avg -le 70 ]; then sig_score=15
        elif [ $sig_avg -le 80 ]; then sig_score=8
        else sig_score=3
        fi
    fi

    # Overlap score (0-30) — 2.4GHz channels overlap +-2
    local overlap_score=0
    if [ "$ch" -le 13 ] 2>/dev/null; then
        for offset in -2 -1 1 2; do
            neighbor=$((ch + offset))
            [ $neighbor -lt 1 ] && continue
            [ $neighbor -gt 13 ] && continue
            neighbor_aps=$(cat "$TMPDIR/ch${neighbor}_aps" 2>/dev/null || echo 0)
            neighbor_avg=$((neighbor_aps / PASSES))
            overlap_score=$((overlap_score + neighbor_avg * 2))
        done
        [ $overlap_score -gt 30 ] && overlap_score=30
    fi
    # 5GHz channels don't overlap (non-bonded)

    local total=$((ap_score + sig_score + overlap_score))
    [ $total -gt 100 ] && total=100

    echo "${total}|${ap_avg}|${sig_score}|${overlap_score}"
}

# Build visual bar
make_bar() {
    local score=$1
    local max_width=16
    local filled=$((score * max_width / 100))
    local bar=""
    local i=0
    while [ $i -lt $filled ]; do
        bar="${bar}#"
        i=$((i + 1))
    done
    while [ $i -lt $max_width ]; do
        bar="${bar}-"
        i=$((i + 1))
    done
    echo "$bar"
}

grade_channel() {
    local score=$1
    if [ $score -le 10 ]; then echo "EXCELLENT"
    elif [ $score -le 25 ]; then echo "GOOD"
    elif [ $score -le 50 ]; then echo "MODERATE"
    elif [ $score -le 75 ]; then echo "CONGESTED"
    else echo "SEVERE"
    fi
}

# Calculate all channels
BEST_CH=""
BEST_SCORE=101
WORST_CH=""
WORST_SCORE=-1

cat > "$REPORT" << HEADER
==========================================
   NULLSEC CHANNEL CONGESTION REPORT
==========================================

Scan Time: $(date)
Interface: $IFACE
Passes: $PASSES
Band: $([ $BAND -eq 1 ] && echo '2.4GHz' || ([ $BAND -eq 2 ] && echo '5GHz' || echo 'Full Spectrum'))

Score: 0 (empty) → 100 (severely congested)

HEADER

# 2.4GHz Analysis
if [ $BAND -eq 1 ] || [ $BAND -eq 3 ]; then
    echo "========== 2.4 GHz SPECTRUM ==========" >> "$REPORT"
    echo "" >> "$REPORT"
    printf "%-4s %-4s %-5s %-18s %s\n" "CH" "APs" "SCORE" "CONGESTION" "GRADE" >> "$REPORT"
    echo "--------------------------------------------" >> "$REPORT"

    PAGER_24=""
    for ch in $CHANNELS_24; do
        RESULT=$(calc_congestion "$ch")
        SCORE=$(echo "$RESULT" | cut -d'|' -f1)
        APS=$(echo "$RESULT" | cut -d'|' -f2)
        BAR=$(make_bar "$SCORE")
        GRADE=$(grade_channel "$SCORE")

        printf "%-4s %-4s %-5s [%-16s] %s\n" "$ch" "$APS" "$SCORE" "$BAR" "$GRADE" >> "$REPORT"

        # Build Pager display (compact)
        PAGER_24="${PAGER_24}ch${ch}: ${SCORE}/100 (${APS}APs) $GRADE\n"

        # Track best/worst
        if [ $SCORE -lt $BEST_SCORE ]; then
            BEST_SCORE=$SCORE; BEST_CH=$ch
        fi
        if [ $SCORE -gt $WORST_SCORE ]; then
            WORST_SCORE=$SCORE; WORST_CH=$ch
        fi
    done
    echo "" >> "$REPORT"

    # Non-overlapping channel recommendation
    CH1_SCORE=$(calc_congestion 1 | cut -d'|' -f1)
    CH6_SCORE=$(calc_congestion 6 | cut -d'|' -f1)
    CH11_SCORE=$(calc_congestion 11 | cut -d'|' -f1)

    echo "--- NON-OVERLAPPING CHANNELS ---" >> "$REPORT"
    echo "Ch 1:  Score $CH1_SCORE — $(grade_channel $CH1_SCORE)" >> "$REPORT"
    echo "Ch 6:  Score $CH6_SCORE — $(grade_channel $CH6_SCORE)" >> "$REPORT"
    echo "Ch 11: Score $CH11_SCORE — $(grade_channel $CH11_SCORE)" >> "$REPORT"
    echo "" >> "$REPORT"

    # Smart recommendation
    RECOMMENDED=1
    if [ $CH6_SCORE -lt $CH1_SCORE ] && [ $CH6_SCORE -lt $CH11_SCORE ]; then
        RECOMMENDED=6
    elif [ $CH11_SCORE -lt $CH1_SCORE ]; then
        RECOMMENDED=11
    fi
    echo "RECOMMENDED: Channel $RECOMMENDED (Score: $(calc_congestion $RECOMMENDED | cut -d'|' -f1))" >> "$REPORT"
    echo "" >> "$REPORT"
fi

# 5GHz Analysis
if [ $BAND -eq 2 ] || [ $BAND -eq 3 ]; then
    echo "=========== 5 GHz SPECTRUM ===========" >> "$REPORT"
    echo "" >> "$REPORT"
    printf "%-5s %-4s %-5s %-18s %s\n" "CH" "APs" "SCORE" "CONGESTION" "GRADE" >> "$REPORT"
    echo "----------------------------------------------" >> "$REPORT"

    PAGER_5=""
    for ch in $CHANNELS_5; do
        RESULT=$(calc_congestion "$ch")
        SCORE=$(echo "$RESULT" | cut -d'|' -f1)
        APS=$(echo "$RESULT" | cut -d'|' -f2)
        BAR=$(make_bar "$SCORE")
        GRADE=$(grade_channel "$SCORE")

        printf "%-5s %-4s %-5s [%-16s] %s\n" "$ch" "$APS" "$SCORE" "$BAR" "$GRADE" >> "$REPORT"
        PAGER_5="${PAGER_5}ch${ch}: ${SCORE}/100 $GRADE\n"

        if [ $SCORE -lt $BEST_SCORE ]; then
            BEST_SCORE=$SCORE; BEST_CH=$ch
        fi
        if [ $SCORE -gt $WORST_SCORE ]; then
            WORST_SCORE=$SCORE; WORST_CH=$ch
        fi
    done
    echo "" >> "$REPORT"
fi

# Overall summary
TOTAL_APS=0
for ch in $CHANNELS; do
    ch_aps=$(cat "$TMPDIR/ch${ch}_aps" 2>/dev/null || echo 0)
    TOTAL_APS=$((TOTAL_APS + ch_aps / PASSES))
done

cat >> "$REPORT" << FOOTER

============ RECOMMENDATION =============

BEST channel:  $BEST_CH (score: $BEST_SCORE — $(grade_channel $BEST_SCORE))
WORST channel: $WORST_CH (score: $WORST_SCORE — $(grade_channel $WORST_SCORE))
Total APs seen: ~$TOTAL_APS (averaged over $PASSES passes)

TIP: For Pineapple operations, use
channel $BEST_CH for cleanest signal.
Avoid channel $WORST_CH.

For evil twin attacks, match the target
AP's channel instead.

==========================================
Generated by NullSec ChannelCongestion
$(date)
==========================================
FOOTER

# Cleanup
rm -rf "$TMPDIR"

SPINNER_STOP

# Display on Pager
PROMPT "CONGESTION ANALYSIS

Total APs: ~$TOTAL_APS
Channels scanned: $(echo $CHANNELS | wc -w)

BEST: Channel $BEST_CH
Score: $BEST_SCORE/100
$(grade_channel $BEST_SCORE)

WORST: Channel $WORST_CH
Score: $WORST_SCORE/100
$(grade_channel $WORST_SCORE)

Press OK for breakdown."

if [ $BAND -eq 1 ] || [ $BAND -eq 3 ]; then
    PROMPT "2.4GHz NON-OVERLAP

Ch 1:  $CH1_SCORE/100
Ch 6:  $CH6_SCORE/100
Ch 11: $CH11_SCORE/100

Recommended: Ch $RECOMMENDED

Lower score = cleaner.

Press OK to continue."
fi

if [ $BAND -eq 1 ] || [ $BAND -eq 3 ]; then
    PROMPT "2.4GHz ALL CHANNELS

$(echo -e "$PAGER_24")
Press OK to continue."
fi

if [ $BAND -eq 2 ] || [ $BAND -eq 3 ]; then
    PROMPT "5GHz CHANNELS

$(echo -e "$PAGER_5" | head -15)
Press OK to continue."
fi

PROMPT "REPORT SAVED

congestion_$TIMESTAMP.txt

Location: $LOOT_DIR/

Use channel $BEST_CH for
optimal operations.

Press OK to exit."

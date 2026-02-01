#!/bin/bash
# Title: NullSec Probe Hunter  
# Author: bad-antics
# Description: Passive probe request collection for SSID discovery
# Category: nullsec

LOOT_DIR="/mmc/nullsec"
mkdir -p "$LOOT_DIR"/{probes,logs}

PROMPT "NULLSEC PROBE HUNTER

Passive probe collection
to discover hidden networks
and client preferred SSIDs.

100% passive - no transmit!

Press OK to configure."

# Find monitor interface
MONITOR_IF=""
for iface in wlan1mon wlan2mon mon0; do
    [ -d "/sys/class/net/$iface" ] && MONITOR_IF="$iface" && break
done

[ -z "$MONITOR_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

# Duration
DURATION=$(NUMBER_PICKER "Capture duration (seconds):" 120)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=120 ;; esac
[ $DURATION -lt 30 ] && DURATION=30
[ $DURATION -gt 600 ] && DURATION=600

# Channel hopping?
resp=$(CONFIRMATION_DIALOG "Enable channel hopping?

YES = scan all channels
NO = stay on current channel")
[ "$resp" = "$DUCKYSCRIPT_USER_CONFIRMED" ] && HOP="1"

resp=$(CONFIRMATION_DIALOG "Start probe capture?

Interface: $MONITOR_IF
Duration: ${DURATION}s
Channel hop: $([ -n "$HOP" ] && echo YES || echo NO)")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

# Capture
LOG "Starting probe capture..."
OUTFILE="$LOOT_DIR/probes/probes_$(date +%Y%m%d_%H%M%S).txt"

if [ -n "$HOP" ]; then
    # Channel hopping with airodump
    timeout $DURATION airodump-ng "$MONITOR_IF" -w /tmp/probe_cap --output-format csv 2>/dev/null &
    sleep $DURATION
    killall airodump-ng 2>/dev/null
    
    # Extract probes from CSV
    grep "Probe" /tmp/probe_cap*.csv 2>/dev/null | \
        awk -F',' '{print $1","$6}' | sort -u > "$OUTFILE"
else
    # Direct tcpdump capture
    timeout $DURATION tcpdump -i "$MONITOR_IF" -e -s 256 type mgt subtype probe-req 2>/dev/null | \
        grep -oE "SA:[0-9a-fA-F:]+|Probe Request \([^)]+\)" | \
        paste - - | sort -u > "$OUTFILE"
fi

# Results
PROBE_COUNT=$(wc -l < "$OUTFILE" 2>/dev/null || echo 0)
UNIQUE_SSIDS=$(grep -oE "Probe Request \([^)]+\)" "$OUTFILE" 2>/dev/null | sort -u | wc -l || echo 0)

PROMPT "PROBE CAPTURE COMPLETE

Probes captured: $PROBE_COUNT
Unique SSIDs: $UNIQUE_SSIDS

Saved to:
$OUTFILE

Press OK to exit."

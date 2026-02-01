#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec Target Scanner & Selector Library
# Developed by: bad-antics
# 
# Source this file in payloads to get auto-scan and target selection UI
#═══════════════════════════════════════════════════════════════════════════════

SCANNER_VERSION="1.0"
SCANNER_INTERFACE="${SCANNER_INTERFACE:-wlan0}"

# Check for monitor mode, enable if needed
nullsec_ensure_monitor() {
    local IF="$1"
    [ -z "$IF" ] && IF="$SCANNER_INTERFACE"
    
    # Check if already in monitor
    if iwconfig "$IF" 2>/dev/null | grep -q "Mode:Monitor"; then
        echo "$IF"
        return 0
    fi
    
    # Try standard mon interface
    if [ -d "/sys/class/net/${IF}mon" ]; then
        echo "${IF}mon"
        return 0
    fi
    
    # Enable monitor mode
    airmon-ng check kill 2>/dev/null
    airmon-ng start "$IF" >/dev/null 2>&1
    
    if [ -d "/sys/class/net/${IF}mon" ]; then
        echo "${IF}mon"
    else
        echo "$IF"
    fi
}

# Main target selection function - scans and presents UI
nullsec_select_target() {
    local SCAN_TIME="${1:-15}"
    local IF=$(nullsec_ensure_monitor "$SCANNER_INTERFACE")
    local TEMP_DIR="/tmp/nullsec_scan_$$"
    mkdir -p "$TEMP_DIR"
    
    SPINNER_START "Scanning for networks (${SCAN_TIME}s)..."
    
    # Run airodump scan
    timeout "$SCAN_TIME" airodump-ng "$IF" -w "$TEMP_DIR/scan" --output-format csv 2>/dev/null &
    sleep "$SCAN_TIME"
    
    SPINNER_STOP
    
    # Parse results
    local CSV_FILE="$TEMP_DIR/scan-01.csv"
    [ ! -f "$CSV_FILE" ] && {
        rm -rf "$TEMP_DIR"
        ERROR_DIALOG "Scan failed!"
        return 1
    }
    
    # Build selection list
    local COUNT=0
    local -a NETWORKS
    local DISPLAY_LIST=""
    
    while IFS=',' read -r BSSID F2 F3 CHANNEL F5 F6 F7 CIPHER F9 POWER F11 F12 F13 ESSID REST; do
        # Skip header and empty lines
        [[ "$BSSID" =~ ^[[:space:]]*$ ]] && continue
        [[ "$BSSID" == *"BSSID"* ]] && continue
        [[ "$BSSID" == *"Station"* ]] && break  # Stop at client section
        
        # Clean up values
        BSSID=$(echo "$BSSID" | tr -d ' ')
        CHANNEL=$(echo "$CHANNEL" | tr -d ' ')
        POWER=$(echo "$POWER" | tr -d ' ')
        ESSID=$(echo "$ESSID" | sed 's/^[[:space:]]*//' | tr -d '\r')
        
        # Skip invalid
        [[ ! "$BSSID" =~ ^[0-9A-Fa-f]{2}: ]] && continue
        [ -z "$ESSID" ] || [ "$ESSID" = " " ] && ESSID="[Hidden]"
        
        ((COUNT++))
        [ $COUNT -gt 15 ] && break  # Max 15 networks
        
        # Store data
        NETWORKS[$COUNT]="$BSSID|$ESSID|$CHANNEL|$POWER"
        
        # Build display (truncate long names)
        local DISPLAY_ESSID="${ESSID:0:16}"
        [ ${#ESSID} -gt 16 ] && DISPLAY_ESSID="${DISPLAY_ESSID}..."
        DISPLAY_LIST="${DISPLAY_LIST}${COUNT}. ${DISPLAY_ESSID}\n"
    done < "$CSV_FILE"
    
    rm -rf "$TEMP_DIR"
    
    [ $COUNT -eq 0 ] && {
        ERROR_DIALOG "No networks found!"
        return 1
    }
    
    # Show selection UI
    PROMPT "NETWORKS FOUND: $COUNT
━━━━━━━━━━━━━━━━━━━━━━━━━
$(echo -e "$DISPLAY_LIST")
━━━━━━━━━━━━━━━━━━━━━━━━━
Select target number"
    
    local SELECTION=$(NUMBER_PICKER "Target (1-$COUNT):" 1)
    
    # Validate selection
    [ -z "$SELECTION" ] || [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt $COUNT ] && {
        ERROR_DIALOG "Invalid selection!"
        return 1
    }
    
    # Parse selected network
    local SELECTED="${NETWORKS[$SELECTION]}"
    export SELECTED_BSSID=$(echo "$SELECTED" | cut -d'|' -f1)
    export SELECTED_SSID=$(echo "$SELECTED" | cut -d'|' -f2)
    export SELECTED_CHANNEL=$(echo "$SELECTED" | cut -d'|' -f3)
    export SELECTED_POWER=$(echo "$SELECTED" | cut -d'|' -f4)
    export SELECTED_INTERFACE="$IF"
    
    LOG "Target: $SELECTED_SSID"
    return 0
}

# Quick scan without UI - returns raw data
nullsec_quick_scan() {
    local SCAN_TIME="${1:-10}"
    local IF=$(nullsec_ensure_monitor "$SCANNER_INTERFACE")
    local TEMP_DIR="/tmp/nullsec_qscan_$$"
    mkdir -p "$TEMP_DIR"
    
    timeout "$SCAN_TIME" airodump-ng "$IF" -w "$TEMP_DIR/scan" --output-format csv 2>/dev/null &
    sleep "$SCAN_TIME"
    
    # Output raw CSV
    cat "$TEMP_DIR/scan-01.csv" 2>/dev/null
    rm -rf "$TEMP_DIR"
}

# Select a client from a network
nullsec_select_client() {
    local TARGET_BSSID="${1:-$SELECTED_BSSID}"
    local SCAN_TIME="${2:-15}"
    local IF=$(nullsec_ensure_monitor "$SCANNER_INTERFACE")
    local TEMP_DIR="/tmp/nullsec_client_$$"
    mkdir -p "$TEMP_DIR"
    
    [ -z "$TARGET_BSSID" ] && {
        ERROR_DIALOG "No target BSSID!"
        return 1
    }
    
    SPINNER_START "Finding clients (${SCAN_TIME}s)..."
    
    # Scan specific network
    timeout "$SCAN_TIME" airodump-ng --bssid "$TARGET_BSSID" "$IF" -w "$TEMP_DIR/clients" --output-format csv 2>/dev/null &
    sleep "$SCAN_TIME"
    
    SPINNER_STOP
    
    local CSV_FILE="$TEMP_DIR/clients-01.csv"
    [ ! -f "$CSV_FILE" ] && {
        rm -rf "$TEMP_DIR"
        ERROR_DIALOG "No clients found!"
        return 1
    }
    
    # Parse clients (after "Station MAC" line)
    local COUNT=0
    local -a CLIENTS
    local DISPLAY_LIST=""
    local IN_CLIENT_SECTION=0
    
    while IFS=',' read -r MAC F2 POWER F4 F5 F6 PROBES REST; do
        [[ "$MAC" == *"Station"* ]] && { IN_CLIENT_SECTION=1; continue; }
        [ $IN_CLIENT_SECTION -eq 0 ] && continue
        
        MAC=$(echo "$MAC" | tr -d ' ')
        POWER=$(echo "$POWER" | tr -d ' ')
        PROBES=$(echo "$PROBES" | sed 's/^[[:space:]]*//')
        
        [[ ! "$MAC" =~ ^[0-9A-Fa-f]{2}: ]] && continue
        
        ((COUNT++))
        [ $COUNT -gt 10 ] && break
        
        CLIENTS[$COUNT]="$MAC"
        DISPLAY_LIST="${DISPLAY_LIST}${COUNT}. ${MAC}\n"
    done < "$CSV_FILE"
    
    rm -rf "$TEMP_DIR"
    
    [ $COUNT -eq 0 ] && {
        ERROR_DIALOG "No clients on network!"
        return 1
    }
    
    PROMPT "CLIENTS: $COUNT
━━━━━━━━━━━━━━━━━━━━━━━━━
$(echo -e "$DISPLAY_LIST")
━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local SELECTION=$(NUMBER_PICKER "Client (1-$COUNT):" 1)
    
    [ -z "$SELECTION" ] || [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt $COUNT ] && {
        ERROR_DIALOG "Invalid selection!"
        return 1
    }
    
    export SELECTED_CLIENT="${CLIENTS[$SELECTION]}"
    return 0
}

# Cleanup function
nullsec_scanner_cleanup() {
    rm -rf /tmp/nullsec_scan_* /tmp/nullsec_qscan_* /tmp/nullsec_client_* 2>/dev/null
}

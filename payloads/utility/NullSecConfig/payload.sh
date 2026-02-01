#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec Configuration Manager
# Developed by: bad-antics
# 
# Configure NullSec suite settings including quick dismiss, performance, etc.
#═══════════════════════════════════════════════════════════════════════════════

CONFIG_DIR="/mmc/nullsec"
CONFIG_FILE="$CONFIG_DIR/config.sh"
mkdir -p "$CONFIG_DIR"

# Default config
[ ! -f "$CONFIG_FILE" ] && cat > "$CONFIG_FILE" << 'DEFAULTS'
# NullSec Configuration - Edit values below
export NULLSEC_QUICK_DISMISS=1      # 1=enabled (left/right clears all prompts)
export NULLSEC_SCAN_TIME=15         # Default scan duration in seconds
export NULLSEC_PERFORMANCE_MODE=0   # 1=fast mode (reduced timeouts)
export NULLSEC_LOOT_PATH="/mmc/nullsec"
export NULLSEC_AUTO_CLEANUP=1       # 1=clean temp files after payload
DEFAULTS

# Load current config
source "$CONFIG_FILE" 2>/dev/null

PROMPT "╔╗╔╦ ╦╦  ╦  ╔═╗╔═╗╔═╗
║║║║ ║║  ║  ╚═╗║╣ ║  
╝╚╝╚═╝╩═╝╩═╝╚═╝╚═╝╚═╝
━━━━━━━━━━━━━━━━━━━━━━━━━
Configuration Manager

Customize your NullSec
experience.

━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics"

PROMPT "SETTINGS MENU:

1. Quick Dismiss
   (Currently: $([ $NULLSEC_QUICK_DISMISS -eq 1 ] && echo ON || echo OFF))

2. Performance Mode
   (Currently: $([ $NULLSEC_PERFORMANCE_MODE -eq 1 ] && echo FAST || echo NORMAL))

3. Scan Duration
   (Currently: ${NULLSEC_SCAN_TIME}s)

4. View All Settings

5. Reset to Defaults"

CHOICE=$(NUMBER_PICKER "Option (1-5):" 1)

case $CHOICE in
    1) # Quick Dismiss toggle
        if [ $NULLSEC_QUICK_DISMISS -eq 1 ]; then
            sed -i 's/NULLSEC_QUICK_DISMISS=1/NULLSEC_QUICK_DISMISS=0/' "$CONFIG_FILE"
            PROMPT "Quick Dismiss: OFF

Prompts will now require
individual confirmation."
        else
            sed -i 's/NULLSEC_QUICK_DISMISS=0/NULLSEC_QUICK_DISMISS=1/' "$CONFIG_FILE"
            PROMPT "Quick Dismiss: ON

Use LEFT/RIGHT to clear
multiple prompts at once.

Press SELECT to confirm
individual prompts."
        fi
        ;;
    2) # Performance Mode
        if [ $NULLSEC_PERFORMANCE_MODE -eq 1 ]; then
            sed -i 's/NULLSEC_PERFORMANCE_MODE=1/NULLSEC_PERFORMANCE_MODE=0/' "$CONFIG_FILE"
            PROMPT "Performance Mode: NORMAL

Standard timeouts and
delays restored."
        else
            sed -i 's/NULLSEC_PERFORMANCE_MODE=0/NULLSEC_PERFORMANCE_MODE=1/' "$CONFIG_FILE"
            PROMPT "Performance Mode: FAST

Reduced timeouts for
quicker execution.

Note: May reduce
scan accuracy."
        fi
        ;;
    3) # Scan Duration
        NEW_TIME=$(NUMBER_PICKER "Scan time (5-60):" $NULLSEC_SCAN_TIME)
        [ "$NEW_TIME" -lt 5 ] && NEW_TIME=5
        [ "$NEW_TIME" -gt 60 ] && NEW_TIME=60
        sed -i "s/NULLSEC_SCAN_TIME=.*/NULLSEC_SCAN_TIME=$NEW_TIME/" "$CONFIG_FILE"
        PROMPT "Scan Duration: ${NEW_TIME}s

Network scans will now
run for $NEW_TIME seconds."
        ;;
    4) # View settings
        PROMPT "CURRENT SETTINGS:
━━━━━━━━━━━━━━━━━━━━━━━━━
Quick Dismiss: $([ $NULLSEC_QUICK_DISMISS -eq 1 ] && echo ON || echo OFF)
Performance: $([ $NULLSEC_PERFORMANCE_MODE -eq 1 ] && echo FAST || echo NORMAL)
Scan Time: ${NULLSEC_SCAN_TIME}s
Loot Path: $NULLSEC_LOOT_PATH
Auto Cleanup: $([ $NULLSEC_AUTO_CLEANUP -eq 1 ] && echo ON || echo OFF)
━━━━━━━━━━━━━━━━━━━━━━━━━"
        ;;
    5) # Reset
        CONFIRMATION_DIALOG "Reset all settings
to defaults?

This cannot be undone."
        if [ $? -eq 0 ]; then
            cat > "$CONFIG_FILE" << 'DEFAULTS'
# NullSec Configuration
export NULLSEC_QUICK_DISMISS=1
export NULLSEC_SCAN_TIME=15
export NULLSEC_PERFORMANCE_MODE=0
export NULLSEC_LOOT_PATH="/mmc/nullsec"
export NULLSEC_AUTO_CLEANUP=1
DEFAULTS
            PROMPT "Settings reset to
defaults."
        fi
        ;;
esac

PROMPT "CONFIG SAVED
━━━━━━━━━━━━━━━━━━━━━━━━━
Settings will apply to
all NullSec payloads.

━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics"

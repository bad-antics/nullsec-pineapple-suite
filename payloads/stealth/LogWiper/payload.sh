#!/bin/bash
# Title: Log Wiper
# Author: NullSec
# Description: Securely wipes operation logs with selective or total options
# Category: nullsec/stealth

LOOT_DIR="/mmc/nullsec/logwiper"
mkdir -p "$LOOT_DIR"

PROMPT "LOG WIPER

Securely wipe all
operation logs and
forensic traces.

Modes:
- Selective wipe
- Full system wipe
- NullSec loot wipe
- Secure overwrite
- History cleanup

Press OK to configure."

# Analyze current logs
SPINNER_START "Analyzing logs..."

SYSLOG_SIZE=$(du -sh /var/log/ 2>/dev/null | awk '{print $1}')
LOOT_SIZE=$(du -sh /mmc/nullsec/ 2>/dev/null | awk '{print $1}')
TMP_SIZE=$(du -sh /tmp/ 2>/dev/null | awk '{print $1}')
HIST_EXISTS=0
[ -f ~/.ash_history ] || [ -f ~/.bash_history ] && HIST_EXISTS=1
DMESG_LINES=$(dmesg 2>/dev/null | wc -l)

SPINNER_STOP

PROMPT "LOG ANALYSIS

System logs: $SYSLOG_SIZE
NullSec loot: $LOOT_SIZE
Temp files: $TMP_SIZE
Shell history: $([ $HIST_EXISTS -eq 1 ] && echo "Found" || echo "None")
Kernel msgs: $DMESG_LINES lines

Press OK to select mode."

PROMPT "WIPE MODE:

1. System logs only
2. NullSec loot only
3. Shell history
4. Temp files
5. Selective (choose)
6. TOTAL WIPE (all)

Select mode next."

WIPE_MODE=$(NUMBER_PICKER "Mode (1-6):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) WIPE_MODE=1 ;; esac

# Secure wipe method
PROMPT "WIPE METHOD:

1. Quick delete
2. Zero overwrite
3. Random overwrite (3x)

More passes = slower
but more secure.

Select method next."

WIPE_METHOD=$(NUMBER_PICKER "Method (1-3):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) WIPE_METHOD=1 ;; esac

secure_wipe() {
    local filepath="$1"
    [ ! -f "$filepath" ] && return

    case $WIPE_METHOD in
        1) rm -f "$filepath" ;;
        2)
            local size=$(stat -c%s "$filepath" 2>/dev/null || echo 0)
            dd if=/dev/zero of="$filepath" bs=1 count="$size" conv=notrunc 2>/dev/null
            rm -f "$filepath"
            ;;
        3)
            local size=$(stat -c%s "$filepath" 2>/dev/null || echo 0)
            for pass in 1 2 3; do
                dd if=/dev/urandom of="$filepath" bs=1 count="$size" conv=notrunc 2>/dev/null
            done
            rm -f "$filepath"
            ;;
    esac
}

secure_wipe_dir() {
    local dirpath="$1"
    [ ! -d "$dirpath" ] && return
    find "$dirpath" -type f | while read -r f; do
        secure_wipe "$f"
    done
    rm -rf "$dirpath"
}

resp=$(CONFIRMATION_DIALOG "START LOG WIPE?

Mode: $WIPE_MODE
Method: $(case $WIPE_METHOD in 1) echo Quick;; 2) echo Zero;; 3) echo Random;; esac)

WARNING: This cannot
be undone! All selected
logs will be destroyed.

Confirm?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Starting log wipe..."
SPINNER_START "Wiping logs..."

WIPED_COUNT=0

case $WIPE_MODE in
    1) # System logs only
        for logfile in /var/log/messages /var/log/syslog /var/log/kern.log /var/log/auth.log \
                       /var/log/daemon.log /var/log/dmesg /var/log/wtmp /var/log/lastlog; do
            if [ -f "$logfile" ]; then
                secure_wipe "$logfile"
                WIPED_COUNT=$((WIPED_COUNT + 1))
            fi
        done
        # Clear kernel ring buffer
        dmesg -c >/dev/null 2>&1
        # Clear remaining logs
        find /var/log/ -name "*.log" -o -name "*.gz" -o -name "*.old" 2>/dev/null | while read -r f; do
            secure_wipe "$f"
            WIPED_COUNT=$((WIPED_COUNT + 1))
        done
        ;;

    2) # NullSec loot only
        for loot_dir in /mmc/nullsec/*/; do
            DIRNAME=$(basename "$loot_dir")
            [ "$DIRNAME" = "logwiper" ] && continue
            secure_wipe_dir "$loot_dir"
            WIPED_COUNT=$((WIPED_COUNT + 1))
        done
        ;;

    3) # Shell history
        for histfile in ~/.ash_history ~/.bash_history ~/.sh_history \
                        /root/.ash_history /root/.bash_history /tmp/.bash_history; do
            secure_wipe "$histfile"
            WIPED_COUNT=$((WIPED_COUNT + 1))
        done
        # Clear current session
        history -c 2>/dev/null
        unset HISTFILE 2>/dev/null
        ;;

    4) # Temp files
        find /tmp/ -type f -name "*.log" -o -name "*.tmp" -o -name "*.pcap" \
            -o -name "*.csv" -o -name "*.cap" 2>/dev/null | while read -r f; do
            secure_wipe "$f"
            WIPED_COUNT=$((WIPED_COUNT + 1))
        done
        ;;

    5) # Selective
        PROMPT "SELECT TARGETS:

Wiping individually...

1=Yes 2=No for each."

        for category in "System logs" "NullSec loot" "Shell history" "Temp files" "Kernel messages"; do
            resp=$(CONFIRMATION_DIALOG "Wipe: $category?")
            if [ "$resp" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
                case "$category" in
                    "System logs")
                        find /var/log/ -type f 2>/dev/null | while read -r f; do secure_wipe "$f"; done
                        WIPED_COUNT=$((WIPED_COUNT + 1))
                        ;;
                    "NullSec loot")
                        for d in /mmc/nullsec/*/; do
                            [ "$(basename "$d")" = "logwiper" ] && continue
                            secure_wipe_dir "$d"
                        done
                        WIPED_COUNT=$((WIPED_COUNT + 1))
                        ;;
                    "Shell history")
                        secure_wipe ~/.ash_history; secure_wipe ~/.bash_history
                        WIPED_COUNT=$((WIPED_COUNT + 1))
                        ;;
                    "Temp files")
                        find /tmp/ -type f \( -name "*.log" -o -name "*.tmp" -o -name "*.pcap" \) -delete 2>/dev/null
                        WIPED_COUNT=$((WIPED_COUNT + 1))
                        ;;
                    "Kernel messages")
                        dmesg -c >/dev/null 2>&1
                        WIPED_COUNT=$((WIPED_COUNT + 1))
                        ;;
                esac
            fi
        done
        ;;

    6) # TOTAL WIPE
        # System logs
        find /var/log/ -type f 2>/dev/null | while read -r f; do secure_wipe "$f"; WIPED_COUNT=$((WIPED_COUNT + 1)); done
        # NullSec loot (except logwiper)
        for d in /mmc/nullsec/*/; do
            [ "$(basename "$d")" = "logwiper" ] && continue
            secure_wipe_dir "$d"
        done
        # Shell history
        secure_wipe ~/.ash_history; secure_wipe ~/.bash_history; secure_wipe /root/.ash_history
        # Temp files
        find /tmp/ -type f \( -name "*.log" -o -name "*.tmp" -o -name "*.pcap" -o -name "*.csv" -o -name "*.cap" \) 2>/dev/null | while read -r f; do secure_wipe "$f"; done
        # Kernel messages
        dmesg -c >/dev/null 2>&1
        # Clear environment traces
        unset HISTFILE HISTSIZE HISTFILESIZE 2>/dev/null
        history -c 2>/dev/null
        WIPED_COUNT=999
        ;;
esac

SPINNER_STOP

PROMPT "LOG WIPE COMPLETE

Items wiped: $WIPED_COUNT
Method: $(case $WIPE_METHOD in 1) echo Quick;; 2) echo "Zero fill";; 3) echo "Random 3x";; esac)

All traces destroyed.

Press OK to exit."

#!/bin/sh
#####################################################
# NullSec TimeBomb Payload
# Scheduled delayed payload execution
#####################################################
# Author: NullSec Team
# Target: WiFi Pineapple Pager
# Category: Persistence/Scheduling
#####################################################

PAYLOAD_NAME="TimeBomb"
source /root/payloads/library/nullsec-lib.sh 2>/dev/null || true

# Configuration
ACTION="${1:-list}"  # set, list, clear, run
DELAY="${2:-60}"     # Delay in seconds or time (HH:MM)
PAYLOAD_TO_RUN="${3:-}"
TIMEBOMB_DIR="/root/loot/timebomb"
SCHEDULE_FILE="$TIMEBOMB_DIR/scheduled_jobs.txt"
LOG_FILE="$TIMEBOMB_DIR/timebomb_$(date +%Y%m%d).log"

mkdir -p "$TIMEBOMB_DIR"

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

show_help() {
    echo "=========================================="
    echo "   NullSec TimeBomb v1.0"
    echo "=========================================="
    echo ""
    echo "Usage: $0 <action> [delay] [payload]"
    echo ""
    echo "Actions:"
    echo "  set <delay> <payload>  - Schedule a payload"
    echo "  list                   - Show scheduled payloads"
    echo "  clear                  - Clear all scheduled payloads"
    echo "  run                    - Execute due payloads now"
    echo ""
    echo "Delay formats:"
    echo "  60       - Seconds from now"
    echo "  5m       - Minutes from now"
    echo "  2h       - Hours from now"
    echo "  14:30    - Specific time (24h format)"
    echo ""
    echo "Examples:"
    echo "  $0 set 300 DeauthStorm    - Run DeauthStorm in 5 minutes"
    echo "  $0 set 2h MassDeauth      - Run MassDeauth in 2 hours"
    echo "  $0 set 23:00 StealthRecon - Run StealthRecon at 11 PM"
    echo "  $0 list                   - Show all scheduled"
    echo "  $0 clear                  - Remove all scheduled"
    echo ""
    echo "Available payloads:"
    ls /root/payloads/user/nullsec/ 2>/dev/null | head -20
    echo "..."
}

parse_delay() {
    DELAY_INPUT="$1"
    
    case "$DELAY_INPUT" in
        *m)
            # Minutes
            MINS=$(echo "$DELAY_INPUT" | tr -d 'm')
            echo $((MINS * 60))
            ;;
        *h)
            # Hours
            HOURS=$(echo "$DELAY_INPUT" | tr -d 'h')
            echo $((HOURS * 3600))
            ;;
        *:*)
            # Specific time HH:MM
            TARGET_HOUR=$(echo "$DELAY_INPUT" | cut -d':' -f1)
            TARGET_MIN=$(echo "$DELAY_INPUT" | cut -d':' -f2)
            CURRENT_EPOCH=$(date +%s)
            TARGET_EPOCH=$(date -d "$TARGET_HOUR:$TARGET_MIN" +%s 2>/dev/null)
            
            if [ -z "$TARGET_EPOCH" ]; then
                # Fallback calculation
                CURRENT_HOUR=$(date +%H)
                CURRENT_MIN=$(date +%M)
                DIFF_HOURS=$((TARGET_HOUR - CURRENT_HOUR))
                DIFF_MINS=$((TARGET_MIN - CURRENT_MIN))
                echo $(( (DIFF_HOURS * 3600) + (DIFF_MINS * 60) ))
            else
                DIFF=$((TARGET_EPOCH - CURRENT_EPOCH))
                if [ $DIFF -lt 0 ]; then
                    # Next day
                    DIFF=$((DIFF + 86400))
                fi
                echo $DIFF
            fi
            ;;
        *)
            # Assume seconds
            echo "$DELAY_INPUT"
            ;;
    esac
}

schedule_payload() {
    DELAY_INPUT="$1"
    PAYLOAD="$2"
    
    if [ -z "$PAYLOAD" ]; then
        log "[!] No payload specified"
        show_help
        exit 1
    fi
    
    # Check payload exists
    PAYLOAD_PATH="/root/payloads/user/nullsec/$PAYLOAD/payload.sh"
    if [ ! -f "$PAYLOAD_PATH" ]; then
        log "[!] Payload not found: $PAYLOAD"
        log "[*] Looking for: $PAYLOAD_PATH"
        exit 1
    fi
    
    DELAY_SECS=$(parse_delay "$DELAY_INPUT")
    EXEC_TIME=$(($(date +%s) + DELAY_SECS))
    EXEC_TIME_HUMAN=$(date -d "@$EXEC_TIME" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "$EXEC_TIME" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "in ${DELAY_SECS}s")
    
    # Generate job ID
    JOB_ID="TB_$(date +%s)_$$"
    
    # Save to schedule
    echo "$JOB_ID|$EXEC_TIME|$PAYLOAD|$PAYLOAD_PATH|pending" >> "$SCHEDULE_FILE"
    
    log "[+] TimeBomb scheduled!"
    log "    Job ID: $JOB_ID"
    log "    Payload: $PAYLOAD"
    log "    Execute at: $EXEC_TIME_HUMAN"
    log "    Delay: ${DELAY_SECS} seconds"
    
    # Start background watcher if not running
    if ! pgrep -f "timebomb_watcher" >/dev/null 2>&1; then
        log "[*] Starting TimeBomb watcher daemon..."
        nohup sh -c '
            while true; do
                CURRENT=$(date +%s)
                while IFS="|" read -r JOB_ID EXEC_TIME PAYLOAD PAYLOAD_PATH STATUS; do
                    if [ "$STATUS" = "pending" ] && [ "$CURRENT" -ge "$EXEC_TIME" ]; then
                        echo "[$(date)] Executing TimeBomb: $PAYLOAD" >> /root/loot/timebomb/executions.log
                        sh "$PAYLOAD_PATH" >> /root/loot/timebomb/executions.log 2>&1 &
                        sed -i "s/$JOB_ID|$EXEC_TIME|$PAYLOAD|$PAYLOAD_PATH|pending/$JOB_ID|$EXEC_TIME|$PAYLOAD|$PAYLOAD_PATH|executed/" /root/loot/timebomb/scheduled_jobs.txt
                    fi
                done < /root/loot/timebomb/scheduled_jobs.txt
                sleep 10
            done
        ' > /dev/null 2>&1 &
        echo $! > "$TIMEBOMB_DIR/watcher.pid"
    fi
}

list_scheduled() {
    log "=========================================="
    log "   Scheduled TimeBombs"
    log "=========================================="
    
    if [ ! -f "$SCHEDULE_FILE" ] || [ ! -s "$SCHEDULE_FILE" ]; then
        log "[*] No payloads scheduled"
        return
    fi
    
    CURRENT=$(date +%s)
    
    echo ""
    printf "%-15s %-20s %-15s %-10s\n" "JOB ID" "PAYLOAD" "EXECUTE AT" "STATUS"
    echo "--------------------------------------------------------------"
    
    while IFS="|" read -r JOB_ID EXEC_TIME PAYLOAD PAYLOAD_PATH STATUS; do
        [ -z "$JOB_ID" ] && continue
        
        if [ "$EXEC_TIME" -gt "$CURRENT" ] 2>/dev/null; then
            REMAINING=$((EXEC_TIME - CURRENT))
            if [ $REMAINING -gt 3600 ]; then
                TIME_LEFT="$((REMAINING / 3600))h $((REMAINING % 3600 / 60))m"
            elif [ $REMAINING -gt 60 ]; then
                TIME_LEFT="$((REMAINING / 60))m $((REMAINING % 60))s"
            else
                TIME_LEFT="${REMAINING}s"
            fi
            EXEC_DISPLAY="in $TIME_LEFT"
        else
            EXEC_DISPLAY="PAST DUE"
        fi
        
        printf "%-15s %-20s %-15s %-10s\n" "$JOB_ID" "$PAYLOAD" "$EXEC_DISPLAY" "$STATUS"
    done < "$SCHEDULE_FILE"
    
    echo ""
}

clear_scheduled() {
    log "[!] Clearing all scheduled TimeBombs..."
    
    # Kill watcher
    if [ -f "$TIMEBOMB_DIR/watcher.pid" ]; then
        kill $(cat "$TIMEBOMB_DIR/watcher.pid") 2>/dev/null
        rm -f "$TIMEBOMB_DIR/watcher.pid"
    fi
    
    # Clear schedule
    > "$SCHEDULE_FILE"
    
    log "[+] All TimeBombs cleared"
}

case "$ACTION" in
    set)
        schedule_payload "$DELAY" "$PAYLOAD_TO_RUN"
        ;;
    list)
        list_scheduled
        ;;
    clear)
        clear_scheduled
        ;;
    run)
        log "[*] Force executing all pending TimeBombs..."
        while IFS="|" read -r JOB_ID EXEC_TIME PAYLOAD PAYLOAD_PATH STATUS; do
            if [ "$STATUS" = "pending" ]; then
                log "[*] Executing: $PAYLOAD"
                sh "$PAYLOAD_PATH" &
            fi
        done < "$SCHEDULE_FILE"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        show_help
        ;;
esac

#!/bin/bash
# Title: Schedule Task
# Author: NullSec
# Description: Schedule payloads to run at specific times via cron
# Category: nullsec/utility

LOOT_DIR="/mmc/nullsec/scheduletask"
mkdir -p "$LOOT_DIR"

PROMPT "SCHEDULE TASK

Schedule payloads and
commands to run at
specific times.

Features:
- One-time execution
- Recurring schedules
- Payload scheduling
- View/remove tasks
- Execution logging

Press OK to configure."

# Ensure cron is available
if ! command -v crontab >/dev/null 2>&1; then
    ERROR_DIALOG "crontab not found!

Install with:
opkg install busybox"
    exit 1
fi

PROMPT "OPERATION:

1. Schedule new task
2. View scheduled tasks
3. Remove a task
4. Run payload at time
5. View execution log

Select operation next."

OPERATION=$(NUMBER_PICKER "Operation (1-5):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) OPERATION=1 ;; esac

case $OPERATION in
    1) # Schedule new task
        PROMPT "SCHEDULE TYPE:

1. Run once (at reboot)
2. Every N minutes
3. Hourly
4. Daily at hour
5. Custom cron

Select type next."

        SCHED_TYPE=$(NUMBER_PICKER "Type (1-5):" 2)
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SCHED_TYPE=2 ;; esac

        COMMAND=$(TEXT_PICKER "Command:" "/bin/sh /path/to/script.sh")
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

        case $SCHED_TYPE in
            1)
                CRON_EXPR="@reboot"
                SCHED_LABEL="At reboot"
                ;;
            2)
                INTERVAL=$(NUMBER_PICKER "Minutes:" 30)
                case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) INTERVAL=30 ;; esac
                CRON_EXPR="*/$INTERVAL * * * *"
                SCHED_LABEL="Every ${INTERVAL}m"
                ;;
            3)
                MINUTE=$(NUMBER_PICKER "At minute:" 0)
                case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MINUTE=0 ;; esac
                CRON_EXPR="$MINUTE * * * *"
                SCHED_LABEL="Hourly at :${MINUTE}"
                ;;
            4)
                HOUR=$(NUMBER_PICKER "Hour (0-23):" 12)
                case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) HOUR=12 ;; esac
                CRON_EXPR="0 $HOUR * * *"
                SCHED_LABEL="Daily at ${HOUR}:00"
                ;;
            5)
                CRON_EXPR=$(TEXT_PICKER "Cron expression:" "*/5 * * * *")
                case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac
                SCHED_LABEL="Custom"
                ;;
        esac

        # Add logging wrapper
        LOG_CMD="$COMMAND >> $LOOT_DIR/exec.log 2>&1"
        CRON_LINE="$CRON_EXPR $LOG_CMD # NULLSEC_TASK"

        resp=$(CONFIRMATION_DIALOG "SCHEDULE TASK?

Schedule: $SCHED_LABEL
Expression: $CRON_EXPR
Command: $(echo "$COMMAND" | head -c 40)

Confirm?")
        [ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

        SPINNER_START "Adding scheduled task..."

        # Add to crontab
        (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
        RESULT=$?

        SPINNER_STOP

        if [ $RESULT -eq 0 ]; then
            echo "$(date) | ADDED | $SCHED_LABEL | $COMMAND" >> "$LOOT_DIR/tasks.log"
            LOG "Task scheduled: $SCHED_LABEL"
            PROMPT "TASK SCHEDULED!

Schedule: $SCHED_LABEL
Command added to cron.

Press OK to exit."
        else
            ERROR_DIALOG "Failed to add task!

Check cron daemon."
        fi
        ;;

    2) # View tasks
        SPINNER_START "Reading crontab..."
        TASKS=$(crontab -l 2>/dev/null | grep "NULLSEC_TASK")
        TASK_COUNT=$(echo "$TASKS" | grep -c "NULLSEC_TASK")
        [ -z "$TASKS" ] && TASK_COUNT=0
        SPINNER_STOP

        if [ $TASK_COUNT -eq 0 ]; then
            PROMPT "NO SCHEDULED TASKS

No NullSec tasks found
in crontab.

Press OK to exit."
        else
            PROMPT "SCHEDULED TASKS: $TASK_COUNT

$(echo "$TASKS" | sed 's/ # NULLSEC_TASK//' | head -8)

Press OK to exit."
        fi
        ;;

    3) # Remove task
        TASKS=$(crontab -l 2>/dev/null | grep "NULLSEC_TASK")
        TASK_COUNT=$(echo "$TASKS" | grep -c "NULLSEC_TASK")
        [ -z "$TASKS" ] && TASK_COUNT=0

        if [ $TASK_COUNT -eq 0 ]; then
            PROMPT "No tasks to remove.

Press OK to exit."
            exit 0
        fi

        PROMPT "REMOVE OPTIONS:

1. Remove all NullSec tasks
2. Remove specific task

Tasks found: $TASK_COUNT

Select option next."

        REMOVE_OPT=$(NUMBER_PICKER "Option (1-2):" 1)
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

        resp=$(CONFIRMATION_DIALOG "REMOVE TASKS?

This cannot be undone.

Confirm?")
        [ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

        SPINNER_START "Removing tasks..."
        if [ "$REMOVE_OPT" = "1" ]; then
            crontab -l 2>/dev/null | grep -v "NULLSEC_TASK" | crontab -
        else
            # Remove last added task
            crontab -l 2>/dev/null | sed '$ {/NULLSEC_TASK/d}' | crontab -
        fi
        SPINNER_STOP

        echo "$(date) | REMOVED | option $REMOVE_OPT" >> "$LOOT_DIR/tasks.log"
        PROMPT "TASKS REMOVED

Press OK to exit."
        ;;

    4) # Run payload at time
        PROMPT "SCHEDULE PAYLOAD

Select a payload from
/mmc/payloads/ to
schedule for execution.

Press OK to browse."

        PAYLOADS=$(ls /mmc/payloads/ 2>/dev/null | head -10)
        [ -z "$PAYLOADS" ] && { ERROR_DIALOG "No payloads found in /mmc/payloads/"; exit 1; }

        PAYLOAD_NAME=$(TEXT_PICKER "Payload dir:" "$(echo "$PAYLOADS" | head -1)")
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

        PAYLOAD_PATH="/mmc/payloads/$PAYLOAD_NAME/payload.sh"
        [ ! -f "$PAYLOAD_PATH" ] && { ERROR_DIALOG "Payload not found: $PAYLOAD_PATH"; exit 1; }

        HOUR=$(NUMBER_PICKER "Hour (0-23):" 12)
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) HOUR=12 ;; esac
        MINUTE=$(NUMBER_PICKER "Minute (0-59):" 0)
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MINUTE=0 ;; esac

        CRON_LINE="$MINUTE $HOUR * * * /bin/bash $PAYLOAD_PATH >> $LOOT_DIR/exec.log 2>&1 # NULLSEC_TASK"
        (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -

        PROMPT "PAYLOAD SCHEDULED

$PAYLOAD_NAME will run
daily at ${HOUR}:$(printf '%02d' $MINUTE)

Press OK to exit."
        ;;

    5) # View log
        if [ -f "$LOOT_DIR/exec.log" ]; then
            LOG_LINES=$(wc -l < "$LOOT_DIR/exec.log")
            LOG_TAIL=$(tail -10 "$LOOT_DIR/exec.log")
            PROMPT "EXECUTION LOG
Lines: $LOG_LINES

$LOG_TAIL

Press OK to exit."
        else
            PROMPT "No execution log yet.

Tasks haven't run or
no output produced.

Press OK to exit."
        fi
        ;;
esac

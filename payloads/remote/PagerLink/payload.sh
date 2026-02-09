#!/bin/bash
# Title: Pager Link
# Author: NullSec
# Description: Creates SSH tunnel for remote Pager UI access
# Category: nullsec/remote

LOOT_DIR="/mmc/nullsec/pagerlink"
mkdir -p "$LOOT_DIR"

PROMPT "PAGER LINK

Creates an SSH tunnel so
you can access the Pager
UI remotely from anywhere.

Features:
- Remote Pager access
- Secure SSH tunnel
- Auto-reconnect
- Status monitoring
- Connection logging

Press OK to configure."

# Check for SSH
if ! command -v ssh >/dev/null 2>&1; then
    ERROR_DIALOG "SSH client not found!

opkg update && opkg install
openssh-client"
    exit 1
fi

# Check connectivity
if ! ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
    ERROR_DIALOG "No internet connection!

PagerLink requires an
active WAN uplink."
    exit 1
fi

# Detect Pager UI port
PAGER_PORT=1471
if ! netstat -tln 2>/dev/null | grep -q ":${PAGER_PORT} "; then
    PROMPT "PAGER PORT DETECT

Default port 1471 may not
be listening. The Pager UI
may use a different port.

Enter the Pager UI port."
    PAGER_PORT=$(NUMBER_PICKER "Pager port:" 1471)
    case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) PAGER_PORT=1471 ;; esac
fi

LOG "Pager UI port: $PAGER_PORT"

REMOTE_HOST=$(TEXT_PICKER "Remote server:" "relay.example.com")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) REMOTE_HOST="" ;; esac
[ -z "$REMOTE_HOST" ] && { ERROR_DIALOG "Remote server required!"; exit 1; }

REMOTE_USER=$(TEXT_PICKER "Remote user:" "pager")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) REMOTE_USER="pager" ;; esac

REMOTE_SSH_PORT=$(NUMBER_PICKER "Remote SSH port:" 22)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) REMOTE_SSH_PORT=22 ;; esac

EXPOSE_PORT=$(NUMBER_PICKER "Remote expose port:" 8471)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) EXPOSE_PORT=8471 ;; esac
[ "$EXPOSE_PORT" -lt 1024 ] && EXPOSE_PORT=8471
[ "$EXPOSE_PORT" -gt 65535 ] && EXPOSE_PORT=8471

# SSH key setup
KEY_FILE="$LOOT_DIR/pagerlink_key"
if [ ! -f "$KEY_FILE" ]; then
    resp=$(CONFIRMATION_DIALOG "No SSH key found.

Generate a new key pair?
You will need to add the
public key to the remote
server afterwards.

Press OK to generate.")
    if [ "$resp" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
        SPINNER_START "Generating SSH key..."
        ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -C "pagerlink@pineapple" >/dev/null 2>&1
        SPINNER_STOP
        PUB_KEY=$(cat "${KEY_FILE}.pub")
        PROMPT "PUBLIC KEY

Add to remote server
authorized_keys for user
${REMOTE_USER}:

$PUB_KEY

Press OK when done."
    else
        ERROR_DIALOG "SSH key required!

Place key at:
$KEY_FILE"; exit 1
    fi
fi
chmod 600 "$KEY_FILE"

resp=$(CONFIRMATION_DIALOG "START PAGER LINK?

Local: localhost:$PAGER_PORT
Remote: $REMOTE_HOST:$EXPOSE_PORT
User: $REMOTE_USER

Access Pager remotely at:
http://$REMOTE_HOST:$EXPOSE_PORT

Press OK to connect.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LINK_LOG="$LOOT_DIR/link_$TIMESTAMP.log"
PID_FILE="$LOOT_DIR/pagerlink.pid"

# Kill existing link
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    kill "$OLD_PID" 2>/dev/null
    rm -f "$PID_FILE"
fi

LOG "PagerLink starting to $REMOTE_HOST"
SPINNER_START "Establishing link..."

# Launch tunnel with auto-reconnect
(
    RECONNECT_DELAY=10
    while true; do
        echo "[$(date)] Connecting tunnel..." >> "$LINK_LOG"
        ssh -N \
            -o StrictHostKeyChecking=no \
            -o ServerAliveInterval=30 \
            -o ServerAliveCountMax=3 \
            -o ExitOnForwardFailure=yes \
            -o ConnectTimeout=15 \
            -i "$KEY_FILE" \
            -p "$REMOTE_SSH_PORT" \
            -R "${EXPOSE_PORT}:localhost:${PAGER_PORT}" \
            "${REMOTE_USER}@${REMOTE_HOST}" >> "$LINK_LOG" 2>&1

        EXIT_CODE=$?
        echo "[$(date)] Disconnected (exit $EXIT_CODE), retry in ${RECONNECT_DELAY}s" >> "$LINK_LOG"

        # Back off on repeated failures
        sleep "$RECONNECT_DELAY"
        [ "$RECONNECT_DELAY" -lt 120 ] && RECONNECT_DELAY=$((RECONNECT_DELAY + 10))
    done
) &
LINK_PID=$!
echo "$LINK_PID" > "$PID_FILE"

sleep 5
SPINNER_STOP

# Check status
if kill -0 "$LINK_PID" 2>/dev/null; then
    LOG "PagerLink active (PID: $LINK_PID)"

    PROMPT "PAGER LINK ACTIVE

Status: CONNECTED
PID: $LINK_PID
Auto-reconnect: ON

Access Pager UI remotely:
http://$REMOTE_HOST:$EXPOSE_PORT

Log: $LINK_LOG

Runs in background.
To stop: kill $LINK_PID"
else
    ERROR_DIALOG "LINK FAILED

Could not establish tunnel.
Check server credentials
and network connectivity.

Log: $LINK_LOG"
    rm -f "$PID_FILE"
fi

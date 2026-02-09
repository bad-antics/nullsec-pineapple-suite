#!/bin/bash
# Title: Tunnel Rat
# Author: NullSec
# Description: Establishes reverse SSH tunnel for persistent remote access
# Category: nullsec/remote

LOOT_DIR="/mmc/nullsec/tunnelrat"
mkdir -p "$LOOT_DIR"

PROMPT "TUNNEL RAT

Creates a reverse SSH
tunnel for remote access
to the Pineapple from
anywhere.

Features:
- Reverse SSH tunnel
- Auto-reconnect
- Key-based auth
- Configurable ports
- Connection monitoring

Press OK to configure."

# Check for SSH client
if ! command -v ssh >/dev/null 2>&1; then
    ERROR_DIALOG "SSH client not found!

Install openssh-client:
opkg update && opkg install
openssh-client"
    exit 1
fi

# Check connectivity
if ! ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
    ERROR_DIALOG "No internet connection!

Reverse tunnel requires
an active WAN uplink."
    exit 1
fi

LOG "Internet connectivity confirmed"

REMOTE_HOST=$(TEXT_PICKER "Remote server:" "your-server.com")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) REMOTE_HOST="" ;; esac
[ -z "$REMOTE_HOST" ] && { ERROR_DIALOG "Remote server required!"; exit 1; }

REMOTE_USER=$(TEXT_PICKER "Remote user:" "tunnel")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) REMOTE_USER="tunnel" ;; esac

REMOTE_PORT=$(NUMBER_PICKER "SSH port:" 22)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) REMOTE_PORT=22 ;; esac
[ "$REMOTE_PORT" -lt 1 ] && REMOTE_PORT=22
[ "$REMOTE_PORT" -gt 65535 ] && REMOTE_PORT=22

REVERSE_PORT=$(NUMBER_PICKER "Reverse port:" 2222)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) REVERSE_PORT=2222 ;; esac
[ "$REVERSE_PORT" -lt 1024 ] && REVERSE_PORT=2222
[ "$REVERSE_PORT" -gt 65535 ] && REVERSE_PORT=2222

PROMPT "AUTH METHOD:

1. SSH key (recommended)
2. Password

Key file location:
/mmc/nullsec/tunnelrat/
  tunnel_key

Select method next."

AUTH_MODE=$(NUMBER_PICKER "Auth (1-2):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) AUTH_MODE=1 ;; esac

KEY_FILE="$LOOT_DIR/tunnel_key"
SSH_PASS=""

if [ "$AUTH_MODE" -eq 1 ]; then
    if [ ! -f "$KEY_FILE" ]; then
        resp=$(CONFIRMATION_DIALOG "No key found!

Generate a new SSH key pair?
Public key will be shown
for you to add to the
remote server.

Press OK to generate.")
        if [ "$resp" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
            SPINNER_START "Generating SSH key..."
            ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -C "tunnelrat@pineapple" >/dev/null 2>&1
            SPINNER_STOP
            PUB_KEY=$(cat "${KEY_FILE}.pub")
            PROMPT "SSH KEY GENERATED

Add this public key to
${REMOTE_USER}@${REMOTE_HOST}
authorized_keys:

$PUB_KEY

Press OK when added."
        else
            ERROR_DIALOG "SSH key required!

Place your key at:
$KEY_FILE"; exit 1
        fi
    fi
    chmod 600 "$KEY_FILE"
    SSH_OPTS="-i $KEY_FILE"
else
    SSH_PASS=$(TEXT_PICKER "SSH password:" "")
    [ -z "$SSH_PASS" ] && { ERROR_DIALOG "Password required!"; exit 1; }
    if ! command -v sshpass >/dev/null 2>&1; then
        ERROR_DIALOG "sshpass not installed!

Key auth recommended.
Or: opkg install sshpass"; exit 1
    fi
    SSH_OPTS=""
fi

PROMPT "TUNNEL OPTIONS:

1. Basic reverse tunnel
2. + SOCKS proxy (port 1080)
3. + Web forward (port 80)

Select option next."

TUNNEL_MODE=$(NUMBER_PICKER "Option (1-3):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) TUNNEL_MODE=1 ;; esac

resp=$(CONFIRMATION_DIALOG "START TUNNEL?

Remote: $REMOTE_USER@$REMOTE_HOST
SSH port: $REMOTE_PORT
Reverse: localhost:$REVERSE_PORT
Auth: $([ $AUTH_MODE -eq 1 ] && echo 'Key' || echo 'Password')
Mode: $TUNNEL_MODE

Connect from remote:
ssh -p $REVERSE_PORT user@localhost

Press OK to connect.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TUNNEL_LOG="$LOOT_DIR/tunnel_$TIMESTAMP.log"
PID_FILE="$LOOT_DIR/tunnel.pid"

# Kill existing tunnel
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    kill "$OLD_PID" 2>/dev/null
    rm -f "$PID_FILE"
fi

# Build SSH command
SSH_CMD="ssh -N -o StrictHostKeyChecking=no -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes"
SSH_CMD="$SSH_CMD $SSH_OPTS -p $REMOTE_PORT"
SSH_CMD="$SSH_CMD -R ${REVERSE_PORT}:localhost:22"

case $TUNNEL_MODE in
    2) SSH_CMD="$SSH_CMD -D 1080" ;;
    3) SSH_CMD="$SSH_CMD -R 8080:localhost:80" ;;
esac

SSH_CMD="$SSH_CMD ${REMOTE_USER}@${REMOTE_HOST}"

LOG "Starting reverse tunnel to $REMOTE_HOST"
SPINNER_START "Establishing tunnel..."

# Launch tunnel with auto-reconnect wrapper
(
    while true; do
        echo "[$(date)] Connecting..." >> "$TUNNEL_LOG"
        if [ "$AUTH_MODE" -eq 2 ]; then
            sshpass -p "$SSH_PASS" $SSH_CMD >> "$TUNNEL_LOG" 2>&1
        else
            $SSH_CMD >> "$TUNNEL_LOG" 2>&1
        fi
        echo "[$(date)] Disconnected, reconnecting in 10s..." >> "$TUNNEL_LOG"
        sleep 10
    done
) &
TUNNEL_PID=$!
echo "$TUNNEL_PID" > "$PID_FILE"

# Wait for connection
sleep 5
SPINNER_STOP

if kill -0 "$TUNNEL_PID" 2>/dev/null; then
    LOG "Tunnel established (PID: $TUNNEL_PID)"
    PROMPT "TUNNEL ACTIVE

PID: $TUNNEL_PID
Remote: $REMOTE_HOST:$REVERSE_PORT
Auto-reconnect: ON
$([ $TUNNEL_MODE -eq 2 ] && echo 'SOCKS proxy: port 1080')
$([ $TUNNEL_MODE -eq 3 ] && echo 'Web forward: port 8080')

From remote server run:
ssh -p $REVERSE_PORT root@localhost

Log: $TUNNEL_LOG

Tunnel runs in background.
To stop: kill $TUNNEL_PID"
else
    ERROR_DIALOG "TUNNEL FAILED

Check server, credentials,
and network connectivity.

Log: $TUNNEL_LOG"
    rm -f "$PID_FILE"
fi

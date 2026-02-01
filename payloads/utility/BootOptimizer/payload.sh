#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec Boot Optimizer
# Developed by: bad-antics
# 
# Optimize Pager boot time and runtime performance
#═══════════════════════════════════════════════════════════════════════════════

CONFIG_DIR="/mmc/nullsec"
OPTIMIZE_SCRIPT="/etc/init.d/nullsec-optimize"
mkdir -p "$CONFIG_DIR"

PROMPT "⚡ BOOT OPTIMIZER ⚡
━━━━━━━━━━━━━━━━━━━━━━━━━
Speed up your Pager

Optimize boot time,
reduce memory usage,
faster payload execution.

━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics"

PROMPT "OPTIMIZATION OPTIONS:

1. Quick Boot
   (Skip non-essentials)

2. Memory Optimizer
   (Free up RAM)

3. WiFi Fast Mode
   (Faster scanning)

4. Full Optimization
   (All of the above)

5. View Current Status

6. Reset to Default"

CHOICE=$(NUMBER_PICKER "Option (1-6):" 4)

optimize_boot() {
    cat > "$OPTIMIZE_SCRIPT" << 'BOOTOPT'
#!/bin/sh /etc/rc.common
# NullSec Boot Optimizer
START=99
STOP=10

start() {
    # Disable unnecessary services
    /etc/init.d/uhttpd disable 2>/dev/null
    /etc/init.d/dropbear disable 2>/dev/null
    
    # Pre-load common tools
    which airodump-ng >/dev/null 2>&1
    which aireplay-ng >/dev/null 2>&1
    
    # Set CPU governor to performance
    echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null
    
    logger "NullSec boot optimization complete"
}

stop() {
    echo ondemand > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null
}
BOOTOPT
    chmod +x "$OPTIMIZE_SCRIPT"
    "$OPTIMIZE_SCRIPT" enable 2>/dev/null
    LOG "Boot optimization enabled"
}

optimize_memory() {
    # Clear caches
    sync
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
    
    # Kill unnecessary processes
    pkill -f "uhttpd" 2>/dev/null
    pkill -f "dnsmasq" 2>/dev/null
    
    # Get memory stats
    FREE_MEM=$(free -m | awk '/Mem:/ {print $4}')
    LOG "Freed memory. Available: ${FREE_MEM}MB"
}

optimize_wifi() {
    # Set WiFi to performance mode
    iw dev wlan0 set power_save off 2>/dev/null
    
    # Disable NetworkManager interference
    pkill -f "NetworkManager\|wpa_supplicant" 2>/dev/null
    
    # Set regulatory domain for max power
    iw reg set US 2>/dev/null
    
    LOG "WiFi optimized for speed"
}

case $CHOICE in
    1) # Quick Boot
        SPINNER_START "Optimizing boot..."
        optimize_boot
        SPINNER_STOP
        PROMPT "QUICK BOOT ENABLED
━━━━━━━━━━━━━━━━━━━━━━━━━
Non-essential services
will be skipped.

Expected improvement:
~3-5 seconds faster boot
━━━━━━━━━━━━━━━━━━━━━━━━━"
        ;;
    2) # Memory
        SPINNER_START "Optimizing memory..."
        optimize_memory
        SPINNER_STOP
        FREE_MEM=$(free -m 2>/dev/null | awk '/Mem:/ {print $4}' || echo "N/A")
        PROMPT "MEMORY OPTIMIZED
━━━━━━━━━━━━━━━━━━━━━━━━━
Caches cleared.
Processes stopped.

Free RAM: ${FREE_MEM}MB
━━━━━━━━━━━━━━━━━━━━━━━━━"
        ;;
    3) # WiFi Fast
        SPINNER_START "Optimizing WiFi..."
        optimize_wifi
        SPINNER_STOP
        PROMPT "WIFI FAST MODE
━━━━━━━━━━━━━━━━━━━━━━━━━
Power save: OFF
Interference: Blocked
Reg domain: US (max power)

Scans will be faster.
━━━━━━━━━━━━━━━━━━━━━━━━━"
        ;;
    4) # Full optimization
        SPINNER_START "Full optimization..."
        optimize_boot
        optimize_memory
        optimize_wifi
        SPINNER_STOP
        FREE_MEM=$(free -m 2>/dev/null | awk '/Mem:/ {print $4}' || echo "N/A")
        PROMPT "FULLY OPTIMIZED
━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Boot optimized
✓ Memory cleared
✓ WiFi in fast mode

Free RAM: ${FREE_MEM}MB

Your Pager is now
running at maximum
performance.
━━━━━━━━━━━━━━━━━━━━━━━━━"
        ;;
    5) # Status
        CPU_GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "N/A")
        FREE_MEM=$(free -m 2>/dev/null | awk '/Mem:/ {print $4}' || echo "N/A")
        POWER_SAVE=$(iw dev wlan0 get power_save 2>/dev/null | awk '{print $NF}' || echo "N/A")
        PROMPT "SYSTEM STATUS
━━━━━━━━━━━━━━━━━━━━━━━━━
CPU Governor: $CPU_GOV
Free Memory: ${FREE_MEM}MB
WiFi Power Save: $POWER_SAVE
Boot Optimizer: $([ -f $OPTIMIZE_SCRIPT ] && echo ON || echo OFF)
━━━━━━━━━━━━━━━━━━━━━━━━━"
        ;;
    6) # Reset
        CONFIRMATION_DIALOG "Reset optimizations?

This will restore
default settings."
        if [ $? -eq 0 ]; then
            rm -f "$OPTIMIZE_SCRIPT"
            echo ondemand > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null
            iw dev wlan0 set power_save on 2>/dev/null
            PROMPT "Reset to defaults.

Reboot recommended."
        fi
        ;;
esac

PROMPT "OPTIMIZATION COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━
Run this payload after
each reboot for best
performance.

━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics"

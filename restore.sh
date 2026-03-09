#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec Pineapple Suite — Full Restore Script
# Author: bad-antics
# 
# Restores a factory-reset Pineapple Pager to full NullSec configuration:
#   • SSH key setup (passwordless access)
#   • All tool dependencies (aircrack-ng, hcxdumptool, reaver, tcpdump, etc.)
#   • 120 NullSec payloads across 14 categories
#   • Complete NullSec theme with 112 UI components
#   • FastBoot persistent optimization
#   • Directory structure and loot folders
#═══════════════════════════════════════════════════════════════════════════════

set -e

PINEAPPLE_IP="${1:-172.16.52.1}"
SSH_KEY="${2:-$HOME/.ssh/id_ed25519}"
SSH_OPTS="-o StrictHostKeyChecking=no -o PubkeyAuthentication=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

banner() {
    echo ""
    echo -e "${RED}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║${NC}     ${CYAN}NullSec Pineapple Suite — Full Restore${NC}              ${RED}║${NC}"
    echo -e "${RED}║${NC}     ${YELLOW}120 Payloads • NullSec Theme • FastBoot${NC}             ${RED}║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

step() { echo -e "\n${GREEN}[$(date +%H:%M:%S)]${NC} ${CYAN}$1${NC}"; }
ok()   { echo -e "  ${GREEN}✅ $1${NC}"; }
warn() { echo -e "  ${YELLOW}⚠️  $1${NC}"; }
fail() { echo -e "  ${RED}❌ $1${NC}"; }
info() { echo -e "  ${CYAN}→ $1${NC}"; }

remote() {
    sshpass -p "$PASS" ssh $SSH_OPTS root@"$PINEAPPLE_IP" "$@" 2>/dev/null
}

remote_key() {
    ssh -o StrictHostKeyChecking=no -o IdentitiesOnly=yes -i "$SSH_KEY" root@"$PINEAPPLE_IP" "$@" 2>/dev/null
}

scp_to() {
    sshpass -p "$PASS" scp $SSH_OPTS -q "$1" root@"$PINEAPPLE_IP":"$2" 2>/dev/null
}

scp_to_r() {
    sshpass -p "$PASS" scp $SSH_OPTS -qr "$1" root@"$PINEAPPLE_IP":"$2" 2>/dev/null
}

scp_key() {
    scp -o StrictHostKeyChecking=no -o IdentitiesOnly=yes -i "$SSH_KEY" -q "$1" root@"$PINEAPPLE_IP":"$2" 2>/dev/null
}

scp_key_r() {
    scp -o StrictHostKeyChecking=no -o IdentitiesOnly=yes -i "$SSH_KEY" -qr "$1" root@"$PINEAPPLE_IP":"$2" 2>/dev/null
}

banner

# ─── Pre-flight checks ──────────────────────────────────────────
step "Pre-flight checks"

if ! which sshpass >/dev/null 2>&1; then
    fail "sshpass not installed. Install: sudo apt install sshpass"
    exit 1
fi
ok "sshpass available"

if [ ! -f "$SSH_KEY" ]; then
    warn "SSH key not found at $SSH_KEY — will use password auth only"
    NO_KEY=1
fi

if [ ! -d "$SCRIPT_DIR/payloads" ]; then
    fail "Payloads directory not found. Run from the nullsec-pineapple-suite root."
    exit 1
fi
PAYLOAD_COUNT=$(find "$SCRIPT_DIR/payloads" -name 'payload.sh' | wc -l)
COMPONENT_COUNT=$(find "$SCRIPT_DIR/theme/components" -name '*.json' 2>/dev/null | wc -l)
ok "Found $PAYLOAD_COUNT payloads, $COMPONENT_COUNT theme components"

# ─── Wait for device ────────────────────────────────────────────
step "Waiting for device at $PINEAPPLE_IP..."
TRIES=0
while ! ping -c 1 -W 2 "$PINEAPPLE_IP" >/dev/null 2>&1; do
    TRIES=$((TRIES + 1))
    if [ $TRIES -gt 60 ]; then
        fail "Device not reachable after 10 minutes. Aborting."
        exit 1
    fi
    echo -ne "\r  Waiting... ($((TRIES * 10))s)"
    sleep 10
done
echo ""
ok "Device is online!"

# ─── Get password ───────────────────────────────────────────────
step "SSH Authentication"
echo -n "  Enter root password for Pineapple: "
read -rs PASS
echo ""

# Wait for SSH to be ready
info "Waiting for SSH service..."
for i in $(seq 1 30); do
    if timeout 3 bash -c "echo >/dev/tcp/$PINEAPPLE_IP/22" 2>/dev/null; then
        break
    fi
    sleep 5
done

if ! remote "echo SSH_OK" | grep -q "SSH_OK"; then
    fail "SSH authentication failed. Check password."
    exit 1
fi
ok "SSH connected!"

# ─── Copy SSH key for passwordless access ───────────────────────
if [ -z "$NO_KEY" ]; then
    step "Setting up SSH key authentication"
    PUB_KEY=$(cat "${SSH_KEY}.pub" 2>/dev/null)
    if [ -n "$PUB_KEY" ]; then
        remote "mkdir -p /root/.ssh && chmod 700 /root/.ssh"
        remote "echo '$PUB_KEY' >> /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys && sort -u /root/.ssh/authorized_keys -o /root/.ssh/authorized_keys"
        if remote_key "echo KEY_OK" | grep -q "KEY_OK"; then
            ok "SSH key installed — passwordless access enabled"
            # Switch to key-based functions from here
            remote() { remote_key "$@"; }
            scp_to() { scp_key "$@"; }
            scp_to_r() { scp_key_r "$@"; }
        else
            warn "Key auth test failed — continuing with password"
        fi
    else
        warn "No public key found at ${SSH_KEY}.pub"
    fi
fi

# ─── System info ────────────────────────────────────────────────
step "Device information"
DEVICE_INFO=$(remote "uname -a" 2>/dev/null)
info "$DEVICE_INFO"
DISK_INFO=$(remote "df -h /mmc 2>/dev/null || df -h / 2>/dev/null" | tail -1)
info "Disk: $DISK_INFO"
MEM_INFO=$(remote "free -m 2>/dev/null | head -2" | tail -1)
info "Memory: $MEM_INFO"

# ─── Install dependencies ──────────────────────────────────────
step "Installing tool dependencies"

remote "opkg update" >/dev/null 2>&1
ok "Package lists updated"

PACKAGES=(
    # Core wireless tools
    "aircrack-ng"
    "reaver"
    "tcpdump"
    "hostapd-common"
    "wireless-tools"
    # Network utilities
    "nmap"
    "curl"
    "wget"
    "netcat"
    "bind-dig"
    # System tools
    "htop"
    "procps-ng-ps"
    "coreutils-sort"
    "coreutils-split"
    "coreutils-timeout"
    "diffutils"
    "findutils"
    # Crypto / hashing
    "hcxdumptool"
    "hcxtools"
    # Python (for advanced payloads)
    "python3-light"
    # Logging
    "syslog-ng"
)

INSTALLED=0
FAILED_PKGS=""
for pkg in "${PACKAGES[@]}"; do
    if remote "opkg install $pkg" >/dev/null 2>&1; then
        INSTALLED=$((INSTALLED + 1))
        info "$pkg"
    else
        # Might already be installed or not available
        if remote "opkg list-installed | grep -q '^${pkg} '" 2>/dev/null; then
            INSTALLED=$((INSTALLED + 1))
            info "$pkg (already installed)"
        else
            FAILED_PKGS="$FAILED_PKGS $pkg"
        fi
    fi
done
ok "Installed $INSTALLED packages"
[ -n "$FAILED_PKGS" ] && warn "Unavailable:$FAILED_PKGS"

# ─── Create directory structure ─────────────────────────────────
step "Creating NullSec directory structure"

remote "mkdir -p /mmc/nullsec/loot
mkdir -p /mmc/nullsec/captures
mkdir -p /mmc/nullsec/captures/eap
mkdir -p /mmc/nullsec/captures/handshakes
mkdir -p /mmc/nullsec/logs/ids
mkdir -p /mmc/nullsec/scheduled
mkdir -p /mmc/nullsec/backup
mkdir -p /root/payloads/user/nullsec
mkdir -p /root/payloads/library
mkdir -p /mmc/root/themes/nullsec"
ok "Directory structure created"

# ─── Install payloads ──────────────────────────────────────────
step "Installing $PAYLOAD_COUNT payloads"

PAYLOAD_INSTALLED=0
for category in "$SCRIPT_DIR"/payloads/*/; do
    CAT_NAME=$(basename "$category")
    for payload in "$category"*/; do
        [ -d "$payload" ] || continue
        NAME=$(basename "$payload")
        remote "mkdir -p /root/payloads/user/nullsec/$NAME"
        scp_to "$payload/payload.sh" "/root/payloads/user/nullsec/$NAME/payload.sh"
        remote "chmod +x /root/payloads/user/nullsec/$NAME/payload.sh"
        PAYLOAD_INSTALLED=$((PAYLOAD_INSTALLED + 1))
    done
    info "$CAT_NAME ($(ls -d "$category"*/ 2>/dev/null | wc -l) payloads)"
done
ok "Installed $PAYLOAD_INSTALLED payloads"

# ─── Install libraries ─────────────────────────────────────────
step "Installing payload libraries"
if [ -d "$SCRIPT_DIR/lib" ] && ls "$SCRIPT_DIR"/lib/*.sh >/dev/null 2>&1; then
    for lib in "$SCRIPT_DIR"/lib/*.sh; do
        scp_to "$lib" "/root/payloads/library/$(basename $lib)"
        info "$(basename $lib)"
    done
    ok "Libraries installed"
else
    info "No libraries to install"
fi

# ─── Install theme ─────────────────────────────────────────────
step "Installing NullSec theme ($COMPONENT_COUNT components)"

scp_to_r "$SCRIPT_DIR/theme/" "/mmc/root/themes/nullsec/"
ok "Theme files deployed"

# Verify critical theme files
for f in theme.json components/boot_animation.json components/spinner.json; do
    if remote "[ -f /mmc/root/themes/nullsec/$f ]"; then
        info "Verified: $f"
    else
        warn "Missing: $f"
    fi
done

# ─── Install assets ────────────────────────────────────────────
if [ -d "$SCRIPT_DIR/assets" ]; then
    step "Installing assets"
    scp_to_r "$SCRIPT_DIR/assets/" "/mmc/root/themes/nullsec/assets/"
    ok "Assets deployed"
fi

# ─── Install FastBoot optimizer ─────────────────────────────────
step "Installing FastBoot optimizer"

if [ -f "$SCRIPT_DIR/system/nullsec-fastboot" ]; then
    scp_to "$SCRIPT_DIR/system/nullsec-fastboot" "/etc/init.d/nullsec-fastboot"
    remote "chmod +x /etc/init.d/nullsec-fastboot && /etc/init.d/nullsec-fastboot enable"
    ok "FastBoot init script installed and enabled"
    
    # Apply optimizations immediately
    remote "/etc/init.d/nullsec-fastboot start" 2>/dev/null
    ok "FastBoot optimizations applied"
else
    warn "nullsec-fastboot not found in system/"
fi

# ─── Configure SSH banner ──────────────────────────────────────
step "Configuring SSH"

remote 'cat > /etc/banner << BANNEREOF

  ▄▄▄▄    ▄▄▄      ▓█████▄     ▄▄▄       ███▄    █ ▄▄▄█████▓ ██▓ ▄████▄    ██████ 
 ▓█████▄ ▒████▄    ▒██▀ ██▌   ▒████▄     ██ ▀█   █ ▓  ██▒ ▓▒▓██▒▒██▀ ▀█  ▒██    ▒ 
 ▒██▒ ▄██▒██  ▀█▄  ░██   █▌   ▒██  ▀█▄  ▓██  ▀█ ██▒▒ ▓██░ ▒░▒██▒▒▓█    ▄ ░ ▓██▄   
 ▒██░█▀  ░██▄▄▄▄██ ░▓█▄   ▌   ░██▄▄▄▄██ ▓██▒  ▐▌██▒░ ▓██▓ ░ ░██░▒▓▓▄ ▄██▒  ▒   ██▒
 ░▓█  ▀█▓ ▓█   ▓██▒░▒████▓     ▓█   ▓██▒▒██░   ▓██░  ▒██▒ ░ ░██░▒ ▓███▀ ░▒██████▒▒

  ╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸
           ⚠  WARNING: AUTHORIZED ACCESS ONLY  ⚠
           All connections are monitored and logged
           Unauthorized access will be prosecuted
  ╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸

BANNEREOF'

# Increase MaxAuthTries to prevent lockouts with multiple keys
remote "sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 6/' /etc/ssh/sshd_config 2>/dev/null"
remote "grep -q 'MaxAuthTries' /etc/ssh/sshd_config || echo 'MaxAuthTries 6' >> /etc/ssh/sshd_config"
ok "SSH configured (MaxAuthTries=6)"

# ─── Final verification ────────────────────────────────────────
step "Final verification"

REMOTE_PAYLOADS=$(remote "find /root/payloads/user/nullsec -name 'payload.sh' 2>/dev/null | wc -l")
REMOTE_THEME=$(remote "[ -f /mmc/root/themes/nullsec/theme.json ] && echo YES || echo NO")
REMOTE_BOOT=$(remote "[ -f /mmc/root/themes/nullsec/components/boot_animation.json ] && echo YES || echo NO")
REMOTE_FASTBOOT=$(remote "[ -f /etc/init.d/nullsec-fastboot ] && echo YES || echo NO")
REMOTE_AIRCRACK=$(remote "which aircrack-ng >/dev/null 2>&1 && echo YES || echo NO")

info "Payloads on device: $REMOTE_PAYLOADS"
info "Theme installed: $REMOTE_THEME"
info "Boot animation: $REMOTE_BOOT"
info "FastBoot: $REMOTE_FASTBOOT"
info "aircrack-ng: $REMOTE_AIRCRACK"

echo ""
echo -e "${RED}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║${NC}           ${GREEN}RESTORE COMPLETE! 🍍${NC}                          ${RED}║${NC}"
echo -e "${RED}╠═══════════════════════════════════════════════════════════╣${NC}"
echo -e "${RED}║${NC}  Payloads: ${CYAN}$REMOTE_PAYLOADS installed${NC}                          ${RED}║${NC}"
echo -e "${RED}║${NC}  Theme:    ${CYAN}NullSec ($COMPONENT_COUNT components)${NC}                ${RED}║${NC}"
echo -e "${RED}║${NC}  FastBoot: ${CYAN}Enabled (persistent)${NC}                        ${RED}║${NC}"
echo -e "${RED}║${NC}                                                           ${RED}║${NC}"
echo -e "${RED}║${NC}  ${YELLOW}Payloads:${NC} Dashboard → Payloads → User → nullsec        ${RED}║${NC}"
echo -e "${RED}║${NC}  ${YELLOW}Theme:${NC}    Dashboard → Settings → Theme → nullsec       ${RED}║${NC}"
echo -e "${RED}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

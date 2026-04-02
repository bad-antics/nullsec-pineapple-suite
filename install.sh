#!/bin/bash
#####################################################
# NullSec Pineapple Suite - Installer
# Author: bad-antics
#####################################################

PINEAPPLE_IP="${1:-172.16.52.1}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FAIL=0

echo "╔═══════════════════════════════════════════════╗"
echo "║     NullSec Pineapple Suite Installer         ║"
echo "╚═══════════════════════════════════════════════╝"

# ─── Must run from repo root ────────────────────────────────────
if [ ! -d "$SCRIPT_DIR/payloads" ]; then
    echo "[!] Cannot find payloads/ directory."
    echo "    Run this script from the nullsec-pineapple-suite root."
    exit 1
fi

PAYLOAD_COUNT=$(find "$SCRIPT_DIR/payloads" -name 'payload.sh' | wc -l)
echo "[*] Found $PAYLOAD_COUNT payloads to install"

# ─── Connection check ──────────────────────────────────────────
echo "[*] Checking connection to $PINEAPPLE_IP..."
if ! ping -c 1 -W 3 "$PINEAPPLE_IP" &>/dev/null; then
    echo "[!] Cannot reach Pineapple at $PINEAPPLE_IP"
    echo "    1. Connect Pineapple via USB"
    echo "    2. Verify it's powered on and booted"
    echo "    3. Try: ping $PINEAPPLE_IP"
    echo ""
    echo "    Usage: ./install.sh [PINEAPPLE_IP]"
    echo "    Default IP: 172.16.52.1"
    exit 1
fi
echo "[+] Connected!"

SSH_CMD="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10"

# ─── Verify SSH access ─────────────────────────────────────────
echo "[*] Verifying SSH access..."
if ! $SSH_CMD root@"$PINEAPPLE_IP" "echo OK" &>/dev/null; then
    echo "[!] SSH connection failed. Check:"
    echo "    - SSH key is set up, or"
    echo "    - You have the root password ready"
    exit 1
fi
echo "[+] SSH access verified!"

# ─── Create required directories ───────────────────────────────
echo "[*] Preparing directories on Pineapple..."
$SSH_CMD root@"$PINEAPPLE_IP" "\
    mkdir -p /root/payloads/user/nullsec \
    && mkdir -p /root/payloads/library \
    && mkdir -p /mmc/root/themes/nullsec \
    && mkdir -p /mmc/nullsec/loot \
    && mkdir -p /mmc/nullsec/captures/handshakes \
    && mkdir -p /mmc/nullsec/captures/eap \
    && mkdir -p /mmc/nullsec/logs/ids \
    && mkdir -p /mmc/nullsec/scheduled" 2>/dev/null
echo "[+] Directories ready"

# ─── Install payloads ──────────────────────────────────────────
echo "[*] Installing payloads..."
INSTALLED=0
for category in "$SCRIPT_DIR"/payloads/*/; do
    CAT_NAME=$(basename "$category")
    CAT_COUNT=0
    for payload in "$category"*/; do
        [ -d "$payload" ] || continue
        name=$(basename "$payload")
        $SSH_CMD root@"$PINEAPPLE_IP" "mkdir -p /root/payloads/user/nullsec/$name" 2>/dev/null
        if scp -q "$payload/payload.sh" root@"$PINEAPPLE_IP":/root/payloads/user/nullsec/"$name"/ 2>/dev/null; then
            INSTALLED=$((INSTALLED + 1))
            CAT_COUNT=$((CAT_COUNT + 1))
        else
            echo "    [!] Failed: $name"
            FAIL=$((FAIL + 1))
        fi
    done
    echo "    ✓ $CAT_NAME ($CAT_COUNT payloads)"
done
echo "[+] Installed $INSTALLED/$PAYLOAD_COUNT payloads"

# ─── Install libraries ─────────────────────────────────────────
echo "[*] Installing libraries..."
if [ -d "$SCRIPT_DIR/lib" ] && ls "$SCRIPT_DIR"/lib/*.sh >/dev/null 2>&1; then
    LIB_COUNT=$(ls "$SCRIPT_DIR"/lib/*.sh | wc -l)
    if scp -q "$SCRIPT_DIR"/lib/*.sh root@"$PINEAPPLE_IP":/root/payloads/library/ 2>/dev/null; then
        echo "[+] Installed $LIB_COUNT libraries"
    else
        echo "    [!] Library install failed"
        FAIL=$((FAIL + 1))
    fi
else
    echo "    (no libraries to install)"
fi

# ─── Install theme ─────────────────────────────────────────────
echo "[*] Installing NullSec theme..."
if [ -d "$SCRIPT_DIR/theme" ]; then
    COMPONENT_COUNT=$(find "$SCRIPT_DIR/theme/components" -name '*.json' 2>/dev/null | wc -l)
    if scp -qr "$SCRIPT_DIR"/theme/* root@"$PINEAPPLE_IP":/mmc/root/themes/nullsec/ 2>/dev/null; then
        echo "[+] Theme installed ($COMPONENT_COUNT components)"
    else
        echo "    [!] Theme install failed"
        FAIL=$((FAIL + 1))
    fi
else
    echo "    [!] theme/ directory not found — skipping"
fi

# ─── Install FastBoot optimizer ────────────────────────────────
echo "[*] Installing FastBoot optimizer..."
if [ -f "$SCRIPT_DIR/system/nullsec-fastboot" ]; then
    if scp -q "$SCRIPT_DIR/system/nullsec-fastboot" root@"$PINEAPPLE_IP":/etc/init.d/nullsec-fastboot 2>/dev/null; then
        $SSH_CMD root@"$PINEAPPLE_IP" "chmod +x /etc/init.d/nullsec-fastboot && /etc/init.d/nullsec-fastboot enable && /etc/init.d/nullsec-fastboot start" 2>/dev/null
        echo "[+] FastBoot enabled (persistent across reboots)"
    else
        echo "    [!] FastBoot install failed"
        FAIL=$((FAIL + 1))
    fi
else
    echo "    (nullsec-fastboot not found — skipping)"
fi

# ─── Summary ───────────────────────────────────────────────────
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "╔═══════════════════════════════════════════════╗"
    echo "║          Installation Complete! 🍍            ║"
    echo "╠═══════════════════════════════════════════════╣"
    echo "║  Payloads:  $INSTALLED installed                      ║"
    echo "║  Theme:     NullSec (with boot animation)     ║"
    echo "║  FastBoot:  Active (persistent)               ║"
    echo "╚═══════════════════════════════════════════════╝"
else
    echo "╔═══════════════════════════════════════════════╗"
    echo "║      Installation Complete (with errors)      ║"
    echo "╠═══════════════════════════════════════════════╣"
    echo "║  Payloads:  $INSTALLED installed                      ║"
    echo "║  Failures:  $FAIL                                     ║"
    echo "║  Check output above for [!] items             ║"
    echo "╚═══════════════════════════════════════════════╝"
fi
echo ""
echo "Payloads: Dashboard → Payloads → User → nullsec"
echo "Theme:    Dashboard → Settings → Theme → nullsec"
echo "FastBoot: Active (persistent across reboots)"

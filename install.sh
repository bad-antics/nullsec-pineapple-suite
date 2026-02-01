#!/bin/bash
#####################################################
# NullSec Pineapple Suite - Installer
#####################################################

PINEAPPLE_IP="${1:-172.16.52.1}"

echo "╔═══════════════════════════════════════════════╗"
echo "║     NullSec Pineapple Suite Installer         ║"
echo "╚═══════════════════════════════════════════════╝"

echo "[*] Checking connection to $PINEAPPLE_IP..."
if ! ping -c 1 "$PINEAPPLE_IP" &>/dev/null; then
    echo "[!] Cannot reach Pineapple. Connect via USB first."
    exit 1
fi
echo "[+] Connected!"

echo "[*] Installing payloads..."
for category in payloads/*/; do
    for payload in "$category"*/; do
        [ -d "$payload" ] || continue
        name=$(basename "$payload")
        echo "    → $name"
        ssh root@"$PINEAPPLE_IP" "mkdir -p /root/payloads/user/nullsec/$name" 2>/dev/null
        scp -q "$payload/payload.sh" root@"$PINEAPPLE_IP":/root/payloads/user/nullsec/"$name"/ 2>/dev/null
    done
done

echo "[*] Installing libraries..."
scp -q lib/*.sh root@"$PINEAPPLE_IP":/root/payloads/library/ 2>/dev/null

echo "[*] Installing theme..."
ssh root@"$PINEAPPLE_IP" "mkdir -p /mmc/root/themes/nullsec" 2>/dev/null
scp -qr theme/* root@"$PINEAPPLE_IP":/mmc/root/themes/nullsec/ 2>/dev/null

echo ""
echo "╔═══════════════════════════════════════════════╗"
echo "║          Installation Complete! 🍍            ║"
echo "╚═══════════════════════════════════════════════╝"
echo ""
echo "Payloads: Dashboard → Payloads → User → nullsec"
echo "Theme:    Dashboard → Settings → Theme → nullsec"

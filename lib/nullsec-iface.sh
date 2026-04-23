#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec Interface Autodetect Library
# Author: bad-antics
#
# The Pineapple Pager has no internal recon radio — every scan/attack/audit
# payload must run against an external adapter (MK7AC over USB-C is the
# supported one). That adapter almost never enumerates as `wlan0`; it usually
# lands on `wlan1` / `wlan1mon`. Payloads that hardcode `wlan0` therefore
# "succeed" with zero results and no error, which is confusing and wastes
# people's time.
#
# This library exposes a single source-able function that picks the correct
# interface once and exports $IFACE. Source it at the top of any payload:
#
#   . /root/payloads/library/nullsec-iface.sh
#   nullsec_require_iface || exit 1
#   # ... use "$IFACE" from here on
#
# Users can override by setting IFACE before running, or by writing
# /root/.nullsec_env with `export IFACE=wlanX`.
#═══════════════════════════════════════════════════════════════════════════════

NULLSEC_IFACE_VERSION="1.0"

# Load per-device overrides if present.
[ -f /root/.nullsec_env ] && . /root/.nullsec_env

# Picks the best interface for recon/attack work and exports $IFACE.
#
# Priority:
#   1. $IFACE if the caller already set one and it exists on the system.
#   2. First non-loopback wireless interface other than wlan0 (external).
#   3. wlan0 as a last resort (may be management-only on some pagers).
#
# Returns 0 if a usable interface was found, 1 otherwise.
nullsec_detect_iface() {
    # Caller-provided override wins.
    if [ -n "$IFACE" ] && [ -d "/sys/class/net/$IFACE" ]; then
        export IFACE
        return 0
    fi

    # Prefer any wireless interface that is NOT wlan0.
    local candidate
    for candidate in $(iw dev 2>/dev/null | awk '/Interface/{print $2}'); do
        if [ "$candidate" != "wlan0" ] && [ -d "/sys/class/net/$candidate" ]; then
            export IFACE="$candidate"
            return 0
        fi
    done

    # Fallback: wlan0 if it exists at all.
    if [ -d "/sys/class/net/wlan0" ]; then
        export IFACE="wlan0"
        return 0
    fi

    unset IFACE
    return 1
}

# Detect + surface a friendly error dialog if nothing suitable is plugged in.
# Uses the pager UI primitives (ERROR_DIALOG / PROMPT) when available, falls
# back to plain stderr for CLI/debug runs.
nullsec_require_iface() {
    if nullsec_detect_iface; then
        return 0
    fi

    local msg="No external wireless adapter detected.

Plug in your MK7AC (or other
USB wifi adapter) and try again.

The pager has no internal
recon radio."

    if command -v ERROR_DIALOG >/dev/null 2>&1; then
        ERROR_DIALOG "$msg"
    else
        echo "[nullsec-iface] $msg" >&2
    fi
    return 1
}

# Convenience: ensure $IFACE is in monitor mode and echo the monitor name.
# Safe to call multiple times; idempotent.
nullsec_ensure_monitor_iface() {
    [ -n "$IFACE" ] || nullsec_detect_iface || return 1

    if iwconfig "$IFACE" 2>/dev/null | grep -q "Mode:Monitor"; then
        echo "$IFACE"
        return 0
    fi

    if [ -d "/sys/class/net/${IFACE}mon" ]; then
        echo "${IFACE}mon"
        return 0
    fi

    airmon-ng check kill >/dev/null 2>&1
    airmon-ng start "$IFACE" >/dev/null 2>&1

    if [ -d "/sys/class/net/${IFACE}mon" ]; then
        echo "${IFACE}mon"
    else
        echo "$IFACE"
    fi
}

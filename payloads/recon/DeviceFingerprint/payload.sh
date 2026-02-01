#!/bin/bash
# Title: Device Fingerprint
# Author: bad-antics
# Description: Identify device types from MAC addresses and probes
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/fingerprints"
mkdir -p "$LOOT_DIR"

PROMPT "DEVICE FINGERPRINTER

Identify device types:
- Apple (iPhone/Mac/iPad)
- Samsung Galaxy
- Google Pixel
- Windows laptops
- Smart home devices
- IoT devices

Press OK to scan."

[ ! -d "/sys/class/net/wlan0" ] && { ERROR_DIALOG "wlan0 not found!"; exit 1; }

DURATION=$(NUMBER_PICKER "Scan duration (sec):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac

REPORT="$LOOT_DIR/fingerprint_$(date +%Y%m%d_%H%M).txt"

resp=$(CONFIRMATION_DIALOG "START SCAN?

Duration: ${DURATION}s
Output: $REPORT

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

SPINNER_START "Scanning devices..."

# Capture on all channels
timeout $DURATION airodump-ng wlan0 --write-interval 5 -w /tmp/fpscan --output-format csv 2>/dev/null &
SCAN_PID=$!

# Also capture probes
timeout $DURATION tcpdump -i wlan0 -e type mgt subtype probe-req 2>/dev/null > /tmp/fp_probes.txt &
PROBE_PID=$!

sleep $DURATION
kill $SCAN_PID $PROBE_PID 2>/dev/null

SPINNER_STOP

# Generate fingerprint report
echo "==========================================" > "$REPORT"
echo "       NULLSEC DEVICE FINGERPRINTS        " >> "$REPORT"
echo "==========================================" >> "$REPORT"
echo "Scan Time: $(date)" >> "$REPORT"
echo "" >> "$REPORT"

# Extract all MACs
grep -oE "([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}" /tmp/fpscan*.csv 2>/dev/null | sort -u > /tmp/all_macs.txt

APPLE=0
SAMSUNG=0
GOOGLE=0
MICROSOFT=0
AMAZON=0
INTEL=0
OTHER=0

echo "--- DEVICE IDENTIFICATION ---" >> "$REPORT"
echo "" >> "$REPORT"

while read MAC; do
    PREFIX=$(echo "$MAC" | cut -d':' -f1-3 | tr '[:lower:]' '[:upper:]')
    
    # Common OUI prefixes
    case $PREFIX in
        "00:1A:11"|"00:23:12"|"00:26:BB"|"3C:E0:72"|"40:33:1A"|"64:A2:F9"|"70:DE:E2"|"7C:6D:62"|"9C:20:7B"|"A4:83:E7"|"AC:BC:32"|"B0:34:95"|"DC:A4:CA"|"F0:18:98"|"F4:5C:89")
            echo "APPLE: $MAC (iPhone/iPad/Mac)" >> "$REPORT"
            APPLE=$((APPLE + 1))
            ;;
        "00:21:19"|"00:24:54"|"10:1D:C0"|"24:4B:81"|"34:23:BA"|"50:01:BB"|"64:B8:53"|"78:BD:BC"|"84:25:DB"|"94:51:03"|"A8:7C:01"|"CC:07:AB"|"EC:1F:72"|"F4:7B:5E")
            echo "SAMSUNG: $MAC (Galaxy device)" >> "$REPORT"
            SAMSUNG=$((SAMSUNG + 1))
            ;;
        "3C:5A:B4"|"54:60:09"|"94:EB:2C"|"F4:F5:D8"|"F8:0F:F9")
            echo "GOOGLE: $MAC (Pixel/Nest)" >> "$REPORT"
            GOOGLE=$((GOOGLE + 1))
            ;;
        "00:0D:3A"|"00:12:5A"|"00:15:5D"|"00:17:FA"|"00:1D:D8"|"28:18:78"|"60:45:BD"|"7C:1E:52"|"B4:AE:2B"|"DC:53:60")
            echo "MICROSOFT: $MAC (Windows/Surface)" >> "$REPORT"
            MICROSOFT=$((MICROSOFT + 1))
            ;;
        "00:FC:8B"|"0C:47:C9"|"18:74:2E"|"34:D2:70"|"40:B4:CD"|"44:65:0D"|"68:54:FD"|"74:C2:46"|"84:D6:D0"|"A0:02:DC"|"AC:63:BE"|"F0:27:2D"|"FC:65:DE")
            echo "AMAZON: $MAC (Echo/Fire/Kindle)" >> "$REPORT"
            AMAZON=$((AMAZON + 1))
            ;;
        "00:1B:21"|"00:1C:BF"|"00:1D:E0"|"00:1E:64"|"00:1F:3B"|"00:21:5C"|"00:22:FA"|"00:24:D6"|"3C:97:0E"|"5C:51:4F"|"64:D4:DA"|"80:86:F2"|"88:53:2E"|"A0:88:B4"|"C8:0A:A9"|"F4:8E:38")
            echo "INTEL: $MAC (Laptop/PC)" >> "$REPORT"
            INTEL=$((INTEL + 1))
            ;;
        *)
            echo "OTHER: $MAC (Unknown vendor)" >> "$REPORT"
            OTHER=$((OTHER + 1))
            ;;
    esac
done < /tmp/all_macs.txt

echo "" >> "$REPORT"
echo "==========================================" >> "$REPORT"
echo "SUMMARY:" >> "$REPORT"
echo "  Apple devices:     $APPLE" >> "$REPORT"
echo "  Samsung devices:   $SAMSUNG" >> "$REPORT"
echo "  Google devices:    $GOOGLE" >> "$REPORT"
echo "  Microsoft devices: $MICROSOFT" >> "$REPORT"
echo "  Amazon devices:    $AMAZON" >> "$REPORT"
echo "  Intel devices:     $INTEL" >> "$REPORT"
echo "  Other/Unknown:     $OTHER" >> "$REPORT"
echo "==========================================" >> "$REPORT"

TOTAL=$((APPLE + SAMSUNG + GOOGLE + MICROSOFT + AMAZON + INTEL + OTHER))

PROMPT "FINGERPRINTING COMPLETE

Total Devices: $TOTAL

Apple: $APPLE
Samsung: $SAMSUNG
Google: $GOOGLE
Other: $OTHER

Report: $REPORT"

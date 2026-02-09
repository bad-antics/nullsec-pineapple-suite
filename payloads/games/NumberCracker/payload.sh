#!/bin/bash
# Title: Number Cracker
# Author: NullSec
# Description: Number guessing game with hacking theme
# Category: nullsec/games

LOOT_DIR="/mmc/nullsec/numbercracker"
mkdir -p "$LOOT_DIR"

PROMPT "NUMBER CRACKER

Crack the encrypted
number before the
system locks you out!

Each guess gives you
intel on the target.

Features:
- Multiple difficulty
- Limited attempts
- Hint system
- High score tracking

Press OK to start."

PROMPT "DIFFICULTY:

1. Script Kiddie (1-50)
2. Hacker (1-100)
3. Elite (1-500)
4. L33T (1-1000)

Select difficulty next."

DIFFICULTY=$(NUMBER_PICKER "Difficulty (1-4):" 2)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DIFFICULTY=2 ;; esac

case $DIFFICULTY in
    1) MAX_NUM=50;   MAX_ATTEMPTS=8;  LABEL="Script Kiddie" ;;
    2) MAX_NUM=100;  MAX_ATTEMPTS=7;  LABEL="Hacker" ;;
    3) MAX_NUM=500;  MAX_ATTEMPTS=9;  LABEL="Elite" ;;
    4) MAX_NUM=1000; MAX_ATTEMPTS=10; LABEL="L33T" ;;
esac

SECRET=$((RANDOM % MAX_NUM + 1))
ATTEMPTS=0
CRACKED=0

resp=$(CONFIRMATION_DIALOG "MISSION BRIEFING

Difficulty: $LABEL
Range: 1 - $MAX_NUM
Attempts: $MAX_ATTEMPTS

Crack the encrypted
number before system
lockout!

Begin mission?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

HINT_EVEN="unknown"
[ $((SECRET % 2)) -eq 0 ] && HINT_EVEN="EVEN" || HINT_EVEN="ODD"

while [ $ATTEMPTS -lt $MAX_ATTEMPTS ] && [ $CRACKED -eq 0 ]; do
    REMAINING=$((MAX_ATTEMPTS - ATTEMPTS))

    # Provide hints based on attempts used
    HINT_MSG=""
    if [ $ATTEMPTS -eq 2 ]; then
        HINT_MSG="INTEL: Number is $HINT_EVEN"
    elif [ $ATTEMPTS -eq 4 ]; then
        if [ $SECRET -le $((MAX_NUM / 3)) ]; then
            HINT_MSG="INTEL: Lower third"
        elif [ $SECRET -le $((MAX_NUM * 2 / 3)) ]; then
            HINT_MSG="INTEL: Middle third"
        else
            HINT_MSG="INTEL: Upper third"
        fi
    elif [ $ATTEMPTS -ge 6 ]; then
        DIVISOR=5
        [ $((SECRET % DIVISOR)) -eq 0 ] && HINT_MSG="INTEL: Divisible by $DIVISOR" || HINT_MSG="INTEL: NOT div by $DIVISOR"
    fi

    PROMPT "CRACK ATTEMPT $((ATTEMPTS + 1))/$MAX_ATTEMPTS

Range: 1 - $MAX_NUM
Remaining: $REMAINING
$HINT_MSG

[################----]
Decryption: $((ATTEMPTS * 100 / MAX_ATTEMPTS))%

Enter your guess next."

    GUESS=$(NUMBER_PICKER "Guess (1-$MAX_NUM):" $((MAX_NUM / 2)))
    case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) break ;; esac

    ATTEMPTS=$((ATTEMPTS + 1))

    if [ "$GUESS" -eq "$SECRET" ]; then
        CRACKED=1
    elif [ "$GUESS" -lt "$SECRET" ]; then
        DIFF=$((SECRET - GUESS))
        if [ $DIFF -le 5 ]; then
            PROXIMITY="BURNING HOT!"
        elif [ $DIFF -le 15 ]; then
            PROXIMITY="Very warm"
        elif [ $DIFF -le 50 ]; then
            PROXIMITY="Warm"
        else
            PROXIMITY="Cold"
        fi
        PROMPT "ACCESS DENIED

$GUESS is too LOW
Proximity: $PROXIMITY

Press OK to retry."
    else
        DIFF=$((GUESS - SECRET))
        if [ $DIFF -le 5 ]; then
            PROXIMITY="BURNING HOT!"
        elif [ $DIFF -le 15 ]; then
            PROXIMITY="Very warm"
        elif [ $DIFF -le 50 ]; then
            PROXIMITY="Warm"
        else
            PROXIMITY="Cold"
        fi
        PROMPT "ACCESS DENIED

$GUESS is too HIGH
Proximity: $PROXIMITY

Press OK to retry."
    fi
done

if [ $CRACKED -eq 1 ]; then
    SCORE=$(( (MAX_ATTEMPTS - ATTEMPTS + 1) * 100 + MAX_NUM ))

    PROMPT "*** CRACKED ***

NUMBER: $SECRET
Attempts: $ATTEMPTS/$MAX_ATTEMPTS
Difficulty: $LABEL
Score: $SCORE

SYSTEM COMPROMISED!

Press OK to exit."
else
    SCORE=0

    PROMPT "*** LOCKOUT ***

SYSTEM LOCKED!
The number was: $SECRET

Attempts used: $MAX_ATTEMPTS
Difficulty: $LABEL
Score: 0

Better luck next time.

Press OK to exit."
fi

# Save score
echo "$(date +%Y%m%d_%H%M) | $LABEL | $ATTEMPTS/$MAX_ATTEMPTS | Score:$SCORE | $([ $CRACKED -eq 1 ] && echo WIN || echo LOSS)" >> "$LOOT_DIR/scores.txt"

# Show high scores
if [ -f "$LOOT_DIR/scores.txt" ]; then
    BEST=$(grep "WIN" "$LOOT_DIR/scores.txt" | sort -t'|' -k4 -rn | head -3)
    [ -n "$BEST" ] && PROMPT "HIGH SCORES

$BEST

Press OK to exit."
fi

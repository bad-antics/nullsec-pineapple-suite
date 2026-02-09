#!/bin/bash
# Title: WarGames
# Author: NullSec
# Description: WOPR-style hacking simulation game
# Category: nullsec/games

LOOT_DIR="/mmc/nullsec/wargames"
mkdir -p "$LOOT_DIR"

PROMPT "W A R G A M E S

  WOPR DEFENSE SYSTEM
  NORAD - CHEYENNE MT

A STRANGE GAME.
THE ONLY WINNING MOVE
IS NOT TO PLAY.

...OR IS IT?

SHALL WE PLAY A GAME?

Press OK to connect."

# Simulated boot sequence
PROMPT "LOGON: Joshua

GREETINGS PROFESSOR FALKEN

HOW ABOUT A NICE GAME
OF GLOBAL THERMONUCLEAR
WAR?

GAME MENU:
1. Global Thermonuclear War
2. Network Infiltration
3. Code Breaker
4. System Takeover

Press OK to choose."

GAME_MODE=$(NUMBER_PICKER "Game (1-4):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) GAME_MODE=1 ;; esac

SCORE=0
LEVEL=1

case $GAME_MODE in
    1) # Global Thermonuclear War
        PROMPT "GLOBAL THERMONUCLEAR WAR

TARGET SELECTION PHASE

Choose primary target:
1. Moscow
2. Beijing
3. London
4. Washington
5. Random city

DEFCON LEVEL: 5

Select target next."

        TARGET=$(NUMBER_PICKER "Target (1-5):" 1)
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) TARGET=1 ;; esac

        CITIES=("Moscow" "Beijing" "London" "Washington" "Pyongyang")
        TARGET_NAME="${CITIES[$((TARGET - 1))]}"
        [ -z "$TARGET_NAME" ] && TARGET_NAME="${CITIES[$((RANDOM % 5))]}"

        for DEFCON in 4 3 2 1; do
            SPINNER_START "DEFCON $DEFCON..."
            sleep 1
            SPINNER_STOP

            PROMPT "DEFCON $DEFCON

Target: $TARGET_NAME
Missiles: $((10 - DEFCON * 2)) armed
Trajectory: Calculated
ETA: $((DEFCON * 4)) minutes

Enemy response:
$((DEFCON * 3)) ICBMs detected

Counter? (1=Defend 2=Strike)"

            ACTION=$(NUMBER_PICKER "Action (1-2):" 1)
            case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) ACTION=1 ;; esac

            if [ "$ACTION" = "1" ]; then
                INTERCEPTS=$((RANDOM % 5 + 1))
                SCORE=$((SCORE + INTERCEPTS * 10))
                PROMPT "DEFENSE RESULT

Intercepted: $INTERCEPTS ICBMs
Leaked through: $((DEFCON - INTERCEPTS > 0 ? DEFCON - INTERCEPTS : 0))
Score: $SCORE

Press OK to continue."
            else
                HITS=$((RANDOM % 3 + 1))
                SCORE=$((SCORE + HITS * 25))
                PROMPT "STRIKE RESULT

Warheads launched: $((5 - DEFCON))
Confirmed hits: $HITS
Casualties: $((HITS * RANDOM % 1000))K
Score: $SCORE

Press OK to continue."
            fi
        done

        PROMPT "SIMULATION COMPLETE

WOPR ANALYSIS:

Winner: NONE

A STRANGE GAME.
THE ONLY WINNING MOVE
IS NOT TO PLAY.

HOW ABOUT A NICE GAME
OF CHESS?

Final Score: $SCORE"
        ;;

    2) # Network Infiltration
        PROMPT "NETWORK INFILTRATION

You must hack through
5 firewall layers to
reach the mainframe.

Each layer has a
security challenge.

HACK LEVEL: 1/5

Press OK to begin."

        for LEVEL in 1 2 3 4 5; do
            # Generate random challenge
            CHALLENGE_TYPE=$((RANDOM % 3))
            case $CHALLENGE_TYPE in
                0) # Port guess
                    SECRET_PORT=$((RANDOM % 65535 + 1))
                    HINT_LOW=$((SECRET_PORT - 500))
                    HINT_HIGH=$((SECRET_PORT + 500))
                    [ $HINT_LOW -lt 1 ] && HINT_LOW=1

                    PROMPT "FIREWALL LAYER $LEVEL

Type: Port Scanner
Find the open port.
Range: $HINT_LOW-$HINT_HIGH

You have 3 attempts."

                    CRACKED=0
                    for attempt in 1 2 3; do
                        GUESS=$(NUMBER_PICKER "Port ($HINT_LOW-$HINT_HIGH):" $((HINT_LOW + HINT_HIGH / 2)))
                        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) break ;; esac

                        DIFF=$((GUESS - SECRET_PORT))
                        [ $DIFF -lt 0 ] && DIFF=$((-DIFF))

                        if [ $DIFF -lt 50 ]; then
                            SCORE=$((SCORE + 100 - attempt * 20))
                            CRACKED=1
                            PROMPT "PORT CRACKED!

Open port: $SECRET_PORT
Your guess: $GUESS
Attempt: $attempt/3
Score: +$((100 - attempt * 20))

Press OK for next layer."
                            break
                        elif [ $GUESS -lt $SECRET_PORT ]; then
                            PROMPT "Too low! ($attempt/3)
Try higher."
                        else
                            PROMPT "Too high! ($attempt/3)
Try lower."
                        fi
                    done
                    [ $CRACKED -eq 0 ] && { PROMPT "LAYER $LEVEL FAILED!

Detected by IDS.
Game Over. Score: $SCORE"; break; }
                    ;;

                1) # Password crack
                    PASSWORDS=("admin" "root" "toor" "password" "letmein" "hack" "shell" "access")
                    SECRET="${PASSWORDS[$((RANDOM % ${#PASSWORDS[@]}))]}"
                    HINT="$(echo "$SECRET" | head -c 2)****"

                    PROMPT "FIREWALL LAYER $LEVEL

Type: Password Crack
Hint: $HINT
Length: ${#SECRET} chars

Enter password next."

                    PASS_GUESS=$(TEXT_PICKER "Password:" "admin")
                    case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) PASS_GUESS="" ;; esac

                    if [ "$PASS_GUESS" = "$SECRET" ]; then
                        SCORE=$((SCORE + 80))
                        PROMPT "PASSWORD CRACKED!

Password was: $SECRET
Score: +80

Press OK for next layer."
                    else
                        SCORE=$((SCORE + 20))
                        PROMPT "BRUTE FORCED!

Password was: $SECRET
Partial credit: +20

Press OK for next layer."
                    fi
                    ;;

                2) # Binary puzzle
                    DEC_NUM=$((RANDOM % 255 + 1))
                    BIN_STR=""
                    TMP=$DEC_NUM
                    for b in 128 64 32 16 8 4 2 1; do
                        if [ $TMP -ge $b ]; then
                            BIN_STR="${BIN_STR}1"
                            TMP=$((TMP - b))
                        else
                            BIN_STR="${BIN_STR}0"
                        fi
                    done

                    PROMPT "FIREWALL LAYER $LEVEL

Type: Binary Decode
Convert to decimal:
$BIN_STR

Enter number next."

                    BIN_GUESS=$(NUMBER_PICKER "Decimal value:" 0)
                    case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) BIN_GUESS=0 ;; esac

                    if [ "$BIN_GUESS" = "$DEC_NUM" ]; then
                        SCORE=$((SCORE + 100))
                        PROMPT "DECODED!

$BIN_STR = $DEC_NUM
Score: +100"
                    else
                        SCORE=$((SCORE + 10))
                        PROMPT "WRONG!

$BIN_STR = $DEC_NUM
Partial: +10"
                    fi
                    ;;
            esac
        done

        PROMPT "INFILTRATION COMPLETE

Layers breached: $LEVEL/5
Final Score: $SCORE

ACCESS GRANTED.
MAINFRAME COMPROMISED.

Press OK to exit."
        ;;

    3) # Code Breaker
        CODE_LEN=4
        SECRET_CODE=""
        for i in $(seq 1 $CODE_LEN); do
            SECRET_CODE="${SECRET_CODE}$((RANDOM % 10))"
        done

        PROMPT "CODE BREAKER

Crack the ${CODE_LEN}-digit code.
Each guess gets feedback:

X = correct digit+position
O = correct digit, wrong pos
- = wrong digit

You have 8 attempts.

Press OK to begin."

        for attempt in $(seq 1 8); do
            GUESS=$(TEXT_PICKER "Code (${CODE_LEN} digits):" "1234")
            case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) break ;; esac

            FEEDBACK=""
            EXACT=0
            PARTIAL=0
            for i in $(seq 0 $((CODE_LEN - 1))); do
                G_CHAR=$(echo "$GUESS" | cut -c$((i+1)))
                S_CHAR=$(echo "$SECRET_CODE" | cut -c$((i+1)))
                if [ "$G_CHAR" = "$S_CHAR" ]; then
                    FEEDBACK="${FEEDBACK}X"
                    EXACT=$((EXACT + 1))
                elif echo "$SECRET_CODE" | grep -q "$G_CHAR"; then
                    FEEDBACK="${FEEDBACK}O"
                    PARTIAL=$((PARTIAL + 1))
                else
                    FEEDBACK="${FEEDBACK}-"
                fi
            done

            if [ $EXACT -eq $CODE_LEN ]; then
                SCORE=$(( (9 - attempt) * 50 ))
                PROMPT "CODE CRACKED!

Code: $SECRET_CODE
Attempts: $attempt
Score: $SCORE

Press OK to exit."
                break
            fi

            PROMPT "Attempt $attempt/8

Guess: $GUESS
Result: $FEEDBACK
(X=exact O=close -=miss)

Press OK to try again."
        done

        [ $EXACT -ne $CODE_LEN ] && PROMPT "FAILED!

Code was: $SECRET_CODE
Score: 0

Press OK to exit."
        ;;

    4) # System Takeover
        PROMPT "SYSTEM TAKEOVER

Hack the WOPR mainframe
by answering security
questions.

5 questions. Each right
answer = more access.

Access Level: GUEST

Press OK to begin."

        ACCESS=0
        QUESTIONS=("What port is SSH?" "What does ARP stand for?" "Default admin password?" "WiFi deauth frame type?" "WPA handshake packets?")
        ANSWERS=("22" "Address Resolution Protocol" "admin" "management" "4")
        SHORT_ANS=("22" "ARP" "admin" "mgmt" "4")

        for q in 0 1 2 3 4; do
            PROMPT "QUESTION $((q+1))/5

${QUESTIONS[$q]}

Enter answer next."

            ANS=$(TEXT_PICKER "Answer:" "")
            case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) ANS="" ;; esac

            ANS_LOWER=$(echo "$ANS" | tr 'A-Z' 'a-z')
            EXPECTED=$(echo "${SHORT_ANS[$q]}" | tr 'A-Z' 'a-z')

            if echo "$ANS_LOWER" | grep -qi "$EXPECTED"; then
                ACCESS=$((ACCESS + 20))
                SCORE=$((SCORE + 50))
                PROMPT "CORRECT!

Access: $ACCESS%
Score: $SCORE"
            else
                PROMPT "WRONG!

Expected: ${ANSWERS[$q]}
Access unchanged: $ACCESS%"
            fi
        done

        LEVELS=("GUEST" "USER" "ADMIN" "ROOT" "KERNEL")
        ACCESS_LEVEL="${LEVELS[$((ACCESS / 20))]}"

        PROMPT "TAKEOVER COMPLETE

Access Level: $ACCESS_LEVEL
System Control: $ACCESS%
Score: $SCORE

GAME OVER

Press OK to exit."
        ;;
esac

# Save score
echo "$(date +%Y%m%d_%H%M) | Game:$GAME_MODE | Score:$SCORE" >> "$LOOT_DIR/scores.txt"

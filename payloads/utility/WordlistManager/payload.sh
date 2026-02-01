#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec Wordlist Manager
# Developed by: bad-antics
# Deploy and manage wordlists for WPA cracking
#═══════════════════════════════════════════════════════════════════════════════

WORDLIST_DIR="/mmc/nullsec/wordlists"
mkdir -p "$WORDLIST_DIR"

PROMPT "WORDLIST MANAGER
━━━━━━━━━━━━━━━━━━━━
Deploy & manage wordlists
for password cracking.

• Common passwords
• Pattern generators
• Custom wordlists

Developed by: bad-antics
Press OK to continue."

PROMPT "OPTIONS:

1. Deploy All Wordlists
2. Common Passwords Only
3. Pattern Generator
4. WiFi Defaults
5. Year/Number Combos
6. Custom Import

Select next screen."

MODE=$(NUMBER_PICKER "Mode (1-6):" 1)

case $MODE in
    1|2)
        LOG "Deploying common passwords..."
        SPINNER_START "Creating wordlists..."
        
        # Top 1000 common passwords
        cat > "$WORDLIST_DIR/common-top1000.txt" << 'COMMON_PASSWORDS'
password
123456
12345678
qwerty
abc123
monkey
1234567
letmein
trustno1
dragon
baseball
iloveyou
master
sunshine
ashley
bailey
shadow
123123
654321
superman
qazwsx
michael
football
password1
password123
batman
login
admin
princess
qwerty123
welcome
solo
passw0rd
starwars
admin123
hello
charlie
donald
password1234
qwertyuiop
lovely
rockyou
nicole
daniel
jessica
lovely
michael
michelle
jennifer
joshua
camille
andrew
amanda
jessica
matthew
jordan
elizabeth
chocolate
samantha
buster
fuckoff
fuckyou
asshole
william
thomas
internet
internet1
coffee
killer
computer
soccer
summer
robert
richard
hunter
ranger
thomas
123456789
1234567890
123321
000000
111111
121212
131313
232323
696969
112233
123123123
987654321
12341234
password12
12345
password1!
access
access14
diamond
hottie
muffin
cookie
flower
555555
666666
777777
888888
999999
00000000
11111111
12345678910
password01
password10
password2
password3
basketball
ginger
pepper
butter
tigger
chicken
sparky
mickey
jackson
creative
whatever
nothing
dakota
freedom
princess1
babygirl
angelina
anthony
bigdog
biteme
blahblah
blessing
brandy
braves
butter
camera
cheese
chester
cocacola
coffee
compaq
connect
cowboy
dancer
diamond
digital
dolphin
eagles
einstein
falcon
ferrari
fender
fireman
fishing
flower
france
gateway
gators
golden
golfer
guitar
hammer
harley
heaven
hockey
hunter1
jackson
jasmine
jennifer1
johnny
jordan1
joseph
junior
justice
knight
lakers
legend
liverp
maddog
maggie
manual
marines
martin
matrix
maverick
maxwell
member
mememe
mercury
merlin
mickey1
midnight
miller
montana
mother
mountain
murphy
mustang
nascar
nathan
nelson
newpass
newpass1
newton
newyork
nicole1
ninja
orange
packer
panther
parker
password!
password12345
password99
patches
paul
peaches
peanut
pepper1
phoenix
player
please
prince
princess12
private
rabbit
rachel
raiders
rainbow
ranger1
red123
redskins
richard1
robert1
rocket
rocky
samantha1
sammy
samsung
sarah
scooby
scooter
scorpio
scott
secret
server
shadow1
silver
skippy
slayer
smokey
snoopy
soccer1
sophie
sparky1
spider
squirt
srinivas
steelers
steven
stupid
success
summer1
sunshine1
superman1
surfer
sydney
taylor
tennis
test
tester
testing
thomas1
thunder
tigers
tigger1
tomcat
topgun
toyota
travis
trophy
trustno1!
victoria
viking
warrior
welcome1
william1
willie
wilson
winner
winter
wizard
wolf
xxxxxx
yamaha
yankees
yellow
zxcvbn
zxcvbnm
COMMON_PASSWORDS

        # Additional common passwords
        cat >> "$WORDLIST_DIR/common-top1000.txt" << 'MORE_COMMON'
passw0rd!
P@ssw0rd
P@ssword
P@ssword1
P@ssw0rd1
Welcome1
Welcome1!
Qwerty123
Qwerty123!
Admin123
Admin123!
Password!
Password1!
Letmein1
Letmein1!
Welcome123
Changeme
Changeme1
Temp1234
Test1234
Guest123
User1234
Default1
System1
Passw0rd123
November
December
January
February
March2024
April2024
May2024
June2024
July2024
August2024
September
October
Monday
Tuesday
Wednesday
Thursday
Friday
Saturday
Sunday
Spring2024
Summer2024
Autumn2024
Winter2024
Company1
Company123
Corporate
Business1
Office365
Network1
Wireless1
Internet1
Security1
Password2024
Password2025
Admin2024
User2024
Temp2024
guest
user
support
tech
admin1
root
toor
ubuntu
raspberry
default
changeme
system
server
backup
oracle
mysql
postgres
administrator
superuser
localadmin
sysadmin
ENDMORE
MORE_COMMON
        
        SPINNER_STOP
        COUNT=$(wc -l < "$WORDLIST_DIR/common-top1000.txt")
        LOG "Created common passwords: $COUNT words"
        ;;
esac

if [ "$MODE" = "1" ] || [ "$MODE" = "4" ]; then
    LOG "Creating WiFi default passwords..."
    SPINNER_START "WiFi defaults..."
    
    # Default WiFi passwords
    cat > "$WORDLIST_DIR/wifi-defaults.txt" << 'WIFI_DEFAULTS'
admin
password
1234567890
0000000000
1111111111
2222222222
admin123
password1
wireless
wifipassword
homewifi
mywifi
netgear
linksys
dlink
tplink
belkin
asus
arris
motorola
comcast
xfinity
spectrum
att
verizon
tmobile
sprint
frontier
centurylink
cox
optimum
charter
ATTxxxxxxx
2wirexxx
ATTXXXXXX
xfinitywifi
CableWiFi
FiOSxxxx
NETGEAR01
NETGEAR02
NETGEAR03
dlink-XXXX
TP-LINK_XXXX
ASUS_XX
Belkin.XXX
linksys01
admin1234
password123
wireless123
internet123
wifipass123
homewifi123
guestwifi
GuestWiFi
GUEST
Guest123
guest123
visitor
Visitor123
public
Public123
WIFI_DEFAULTS

    SPINNER_STOP
fi

if [ "$MODE" = "1" ] || [ "$MODE" = "3" ]; then
    LOG "Creating pattern wordlist..."
    SPINNER_START "Pattern generation..."
    
    # Generate patterns
    cat > "$WORDLIST_DIR/patterns.txt" << 'PATTERNS'
PATTERNS

    # Common base words with variations
    for base in password admin user guest wifi network home office work company secret; do
        echo "$base" >> "$WORDLIST_DIR/patterns.txt"
        echo "${base}1" >> "$WORDLIST_DIR/patterns.txt"
        echo "${base}12" >> "$WORDLIST_DIR/patterns.txt"
        echo "${base}123" >> "$WORDLIST_DIR/patterns.txt"
        echo "${base}1234" >> "$WORDLIST_DIR/patterns.txt"
        echo "${base}!" >> "$WORDLIST_DIR/patterns.txt"
        echo "${base}@" >> "$WORDLIST_DIR/patterns.txt"
        echo "${base}#" >> "$WORDLIST_DIR/patterns.txt"
        echo "${base}1!" >> "$WORDLIST_DIR/patterns.txt"
        echo "${base}123!" >> "$WORDLIST_DIR/patterns.txt"
        # Capitalized
        echo "${base^}" >> "$WORDLIST_DIR/patterns.txt"
        echo "${base^}1" >> "$WORDLIST_DIR/patterns.txt"
        echo "${base^}123" >> "$WORDLIST_DIR/patterns.txt"
        echo "${base^}!" >> "$WORDLIST_DIR/patterns.txt"
        echo "${base^}1!" >> "$WORDLIST_DIR/patterns.txt"
    done
    
    SPINNER_STOP
fi

if [ "$MODE" = "1" ] || [ "$MODE" = "5" ]; then
    LOG "Creating year/number combos..."
    SPINNER_START "Year patterns..."
    
    cat > "$WORDLIST_DIR/years.txt" << 'YEARS'
YEARS

    # Years
    for year in 2020 2021 2022 2023 2024 2025; do
        echo "$year" >> "$WORDLIST_DIR/years.txt"
        echo "password$year" >> "$WORDLIST_DIR/years.txt"
        echo "Password$year" >> "$WORDLIST_DIR/years.txt"
        echo "admin$year" >> "$WORDLIST_DIR/years.txt"
        echo "Admin$year" >> "$WORDLIST_DIR/years.txt"
        echo "wifi$year" >> "$WORDLIST_DIR/years.txt"
        echo "Wifi$year" >> "$WORDLIST_DIR/years.txt"
        echo "home$year" >> "$WORDLIST_DIR/years.txt"
        echo "Home$year" >> "$WORDLIST_DIR/years.txt"
        echo "summer$year" >> "$WORDLIST_DIR/years.txt"
        echo "Summer$year" >> "$WORDLIST_DIR/years.txt"
        echo "winter$year" >> "$WORDLIST_DIR/years.txt"
        echo "Winter$year" >> "$WORDLIST_DIR/years.txt"
        echo "${year}!" >> "$WORDLIST_DIR/years.txt"
        echo "${year}password" >> "$WORDLIST_DIR/years.txt"
    done
    
    # Month patterns
    for month in jan feb mar apr may jun jul aug sep oct nov dec; do
        for year in 2024 2025; do
            echo "${month}${year}" >> "$WORDLIST_DIR/years.txt"
            echo "${month^}${year}" >> "$WORDLIST_DIR/years.txt"
        done
    done
    
    SPINNER_STOP
fi

if [ "$MODE" = "6" ]; then
    PROMPT "CUSTOM IMPORT

Enter path to wordlist
file on SD card or
connected storage.

Path example:
/mmc/custom.txt"

    CUSTOM_PATH=$(TEXT_PICKER "Wordlist path:" "/mmc/custom.txt")
    
    if [ -f "$CUSTOM_PATH" ]; then
        cp "$CUSTOM_PATH" "$WORDLIST_DIR/custom-import.txt"
        COUNT=$(wc -l < "$WORDLIST_DIR/custom-import.txt")
        LOG "Imported $COUNT words"
    else
        ERROR_DIALOG "File not found: $CUSTOM_PATH"
    fi
fi

# Create master wordlist
LOG "Creating master wordlist..."
SPINNER_START "Combining all..."

cat "$WORDLIST_DIR"/*.txt 2>/dev/null | sort -u > "$WORDLIST_DIR/master-wordlist.txt"

SPINNER_STOP

TOTAL=$(wc -l < "$WORDLIST_DIR/master-wordlist.txt" 2>/dev/null || echo 0)

# List all wordlists
LIST=$(ls -la "$WORDLIST_DIR"/*.txt 2>/dev/null | awk '{print $9, $5}' | while read f s; do
    name=$(basename "$f")
    echo "$name: $s"
done)

PROMPT "WORDLISTS DEPLOYED!
━━━━━━━━━━━━━━━━━━━━
Master: $TOTAL words

Location:
$WORDLIST_DIR/

Available lists:
$LIST

━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics
Press OK to exit."

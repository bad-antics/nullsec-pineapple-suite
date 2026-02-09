#!/bin/bash
# Title: Package Manager
# Author: NullSec
# Description: Manage opkg packages from the Pager UI
# Category: nullsec/utility

LOOT_DIR="/mmc/nullsec/packagemanager"
mkdir -p "$LOOT_DIR"

PROMPT "PACKAGE MANAGER

Manage OpenWrt packages
from the Pager UI.

Features:
- Install packages
- Remove packages
- Update package lists
- Search packages
- View installed

Press OK to continue."

# Check opkg availability
if ! command -v opkg >/dev/null 2>&1; then
    ERROR_DIALOG "opkg not found!

This payload requires
the opkg package manager."
    exit 1
fi

PROMPT "PACKAGE OPERATION:

1. Update package lists
2. Install package
3. Remove package
4. Search packages
5. List installed
6. Check disk space
7. Upgrade all

Select operation next."

OPERATION=$(NUMBER_PICKER "Operation (1-7):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) OPERATION=1 ;; esac

case $OPERATION in
    1) # Update lists
        resp=$(CONFIRMATION_DIALOG "UPDATE PACKAGE LISTS?

This will refresh the
package database from
configured feeds.

Requires internet.

Confirm?")
        [ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

        SPINNER_START "Updating package lists..."
        UPDATE_OUT=$(opkg update 2>&1)
        RESULT=$?
        SPINNER_STOP

        if [ $RESULT -eq 0 ]; then
            FEED_COUNT=$(echo "$UPDATE_OUT" | grep -c "Downloading")
            PKG_COUNT=$(opkg list 2>/dev/null | wc -l)
            PROMPT "UPDATE COMPLETE

Feeds updated: $FEED_COUNT
Packages available: $PKG_COUNT

Press OK to exit."
        else
            ERROR_DIALOG "Update failed!

$(echo "$UPDATE_OUT" | tail -3)"
        fi
        ;;

    2) # Install package
        PKG_NAME=$(TEXT_PICKER "Package name:" "nano")
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

        # Check if already installed
        if opkg status "$PKG_NAME" 2>/dev/null | grep -q "Status.*installed"; then
            PROMPT "$PKG_NAME is already
installed!

Press OK to exit."
            exit 0
        fi

        # Get package size
        PKG_SIZE=$(opkg info "$PKG_NAME" 2>/dev/null | grep "Size:" | awk '{print $2}')
        [ -z "$PKG_SIZE" ] && PKG_SIZE="unknown"

        resp=$(CONFIRMATION_DIALOG "INSTALL $PKG_NAME?

Size: $PKG_SIZE bytes

This will download and
install the package.

Confirm?")
        [ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

        SPINNER_START "Installing $PKG_NAME..."
        INSTALL_OUT=$(opkg install "$PKG_NAME" 2>&1)
        RESULT=$?
        SPINNER_STOP

        if [ $RESULT -eq 0 ]; then
            echo "$(date) | INSTALL | $PKG_NAME" >> "$LOOT_DIR/pkg_history.log"
            PROMPT "INSTALLED!

$PKG_NAME installed
successfully.

$(echo "$INSTALL_OUT" | tail -2)

Press OK to exit."
        else
            ERROR_DIALOG "Install failed!

$(echo "$INSTALL_OUT" | tail -4)"
        fi
        ;;

    3) # Remove package
        PKG_NAME=$(TEXT_PICKER "Package to remove:" "")
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

        if ! opkg status "$PKG_NAME" 2>/dev/null | grep -q "Status.*installed"; then
            ERROR_DIALOG "$PKG_NAME is not
installed!"
            exit 1
        fi

        resp=$(CONFIRMATION_DIALOG "REMOVE $PKG_NAME?

This will uninstall
the package.

Confirm?")
        [ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

        SPINNER_START "Removing $PKG_NAME..."
        REMOVE_OUT=$(opkg remove "$PKG_NAME" 2>&1)
        RESULT=$?
        SPINNER_STOP

        if [ $RESULT -eq 0 ]; then
            echo "$(date) | REMOVE | $PKG_NAME" >> "$LOOT_DIR/pkg_history.log"
            PROMPT "REMOVED!

$PKG_NAME removed.

Press OK to exit."
        else
            ERROR_DIALOG "Remove failed!

$(echo "$REMOVE_OUT" | tail -3)"
        fi
        ;;

    4) # Search
        SEARCH_TERM=$(TEXT_PICKER "Search term:" "wifi")
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

        SPINNER_START "Searching packages..."
        RESULTS=$(opkg list "*${SEARCH_TERM}*" 2>/dev/null | head -15)
        RESULT_COUNT=$(opkg list "*${SEARCH_TERM}*" 2>/dev/null | wc -l)
        SPINNER_STOP

        PROMPT "SEARCH: $SEARCH_TERM
Found: $RESULT_COUNT

$(echo "$RESULTS" | awk '{print $1}' | head -10)

$([ $RESULT_COUNT -gt 10 ] && echo "...and $((RESULT_COUNT-10)) more")

Press OK to exit."
        ;;

    5) # List installed
        SPINNER_START "Listing packages..."
        INSTALLED=$(opkg list-installed 2>/dev/null)
        INST_COUNT=$(echo "$INSTALLED" | wc -l)
        SPINNER_STOP

        # Save full list
        echo "$INSTALLED" > "$LOOT_DIR/installed_$(date +%Y%m%d).txt"

        PROMPT "INSTALLED PACKAGES: $INST_COUNT

$(echo "$INSTALLED" | head -12 | awk '{print $1}')

...and $((INST_COUNT-12)) more

Full list saved to
$LOOT_DIR/

Press OK to exit."
        ;;

    6) # Disk space
        ROOT_FREE=$(df -h / 2>/dev/null | tail -1 | awk '{print $4}')
        ROOT_USED=$(df -h / 2>/dev/null | tail -1 | awk '{print $5}')
        TMP_FREE=$(df -h /tmp 2>/dev/null | tail -1 | awk '{print $4}')

        PROMPT "DISK SPACE

Root free: $ROOT_FREE ($ROOT_USED used)
Tmp free: $TMP_FREE

Install to /mmc for
more space.

Press OK to exit."
        ;;

    7) # Upgrade all
        resp=$(CONFIRMATION_DIALOG "UPGRADE ALL PACKAGES?

WARNING: This may take
a long time and use
significant bandwidth.

Ensure stable internet.

Confirm?")
        [ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

        SPINNER_START "Upgrading packages..."
        opkg update >/dev/null 2>&1
        UPGRADE_OUT=$(opkg upgrade 2>&1)
        UPGRADED=$(echo "$UPGRADE_OUT" | grep -c "Upgrading")
        SPINNER_STOP

        echo "$(date) | UPGRADE_ALL | $UPGRADED packages" >> "$LOOT_DIR/pkg_history.log"

        PROMPT "UPGRADE COMPLETE

Packages upgraded: $UPGRADED

Press OK to exit."
        ;;
esac

#!/bin/bash
# GDrive Tools Uninstaller
#
# Usage: ./uninstall.sh

LABEL="io.skms.gdrive-clipboard-daemon"
INSTALL_DIR="$HOME/.local/bin"
PLIST_FILE="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG_FILE="$HOME/.gdrive-daemon.log"
APP_NAME="gdrive-share.app"
APP_INSTALL_DIR="/Applications"

echo "🗑  Uninstalling GDrive Tools..."
echo ""

# =============================================================================
# Part 1: Remove Clipboard Daemon
# =============================================================================
echo "[1/2] Removing Clipboard Daemon..."

if launchctl list 2>/dev/null | grep -q "$LABEL"; then
    echo "   Stopping daemon..."
    launchctl stop "$LABEL" 2>/dev/null || true
    launchctl unload "$PLIST_FILE" 2>/dev/null || true
fi

rm -f "$INSTALL_DIR/gdrive-clipboard-daemon.sh"
rm -f "$PLIST_FILE"

echo "   ✅ Daemon removed"

# =============================================================================
# Part 2: Remove URL Handler App
# =============================================================================
echo "[2/2] Removing URL Handler App..."

if [[ -d "$APP_INSTALL_DIR/$APP_NAME" ]]; then
    rm -rf "$APP_INSTALL_DIR/$APP_NAME"
    echo "   ✅ App removed from $APP_INSTALL_DIR"
else
    echo "   ℹ️  App not found in $APP_INSTALL_DIR (may have been installed via pkg)"
fi

# =============================================================================
# Cleanup
# =============================================================================
echo ""

if [[ -f "$LOG_FILE" ]]; then
    read -p "Remove log file ($LOG_FILE)? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f "$LOG_FILE"
        echo "   ✅ Log removed"
    fi
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              Uninstallation Complete!                        ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                              ║"
echo "║  Note: If gdrive-share was installed via .pkg installer,     ║"
echo "║  the app may still be in /Applications. Remove manually      ║"
echo "║  if needed.                                                  ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"

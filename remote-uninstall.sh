#!/bin/bash
# GDrive Tools Remote Uninstaller
# Usage: curl -fsSL https://raw.githubusercontent.com/msff/gdrive-finder-service/main/remote-uninstall.sh | bash

LABEL="io.skms.gdrive-clipboard-daemon"
INSTALL_DIR="$HOME/.local/bin"
PLIST_FILE="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG_FILE="$HOME/.gdrive-daemon.log"

echo "🗑  Uninstalling GDrive Tools..."
echo ""

# Stop and remove daemon
echo "[1/2] Removing Clipboard Daemon..."
if launchctl list 2>/dev/null | grep -q "$LABEL"; then
    launchctl stop "$LABEL" 2>/dev/null || true
    launchctl unload "$PLIST_FILE" 2>/dev/null || true
fi
rm -f "$INSTALL_DIR/gdrive-clipboard-daemon.sh"
rm -f "$PLIST_FILE"
rm -f "$LOG_FILE"
echo "   ✅ Daemon removed"

# Remove app
echo "[2/2] Removing URL Handler App..."
if [[ -d "/Applications/gdrive-share.app" ]]; then
    rm -rf "/Applications/gdrive-share.app"
    echo "   ✅ App removed"
else
    echo "   ℹ️  App not found (may need manual removal if installed via pkg)"
fi

echo ""
echo "✅ Uninstalled successfully!"

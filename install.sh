#!/bin/bash
# GDrive Tools Installer
# Installs both: URL handler (gdrive-finder-service) + Clipboard daemon
#
# Usage: ./install.sh
#
# Components:
#   1. gdrive-share.app - Handles gdrive:// URL scheme, adds Finder context menu
#   2. clipboard-daemon - Auto-opens gdrive:// links when copied

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABEL="io.skms.gdrive-clipboard-daemon"
INSTALL_DIR="$HOME/.local/bin"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_FILE="$PLIST_DIR/$LABEL.plist"
APP_NAME="gdrive-share.app"
APP_INSTALL_DIR="/Applications"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           GDrive Tools Installer                             ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  1. URL Handler    - gdrive:// links open in Finder          ║"
echo "║  2. Clipboard Daemon - auto-opens copied gdrive:// links     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# =============================================================================
# Part 1: Install URL Handler App
# =============================================================================
echo "🔧 [1/2] Installing URL Handler..."

# Check if app exists in Installer folder
if [[ -d "$SCRIPT_DIR/Installer/gdrive-finder-service/$APP_NAME" ]]; then
    APP_SOURCE="$SCRIPT_DIR/Installer/gdrive-finder-service/$APP_NAME"
elif [[ -d "$SCRIPT_DIR/$APP_NAME" ]]; then
    APP_SOURCE="$SCRIPT_DIR/$APP_NAME"
else
    echo "   ⚠️  App not found. Downloading latest release..."

    # Download latest release from GitHub
    LATEST_URL=$(curl -s https://api.github.com/repos/gentle-systems/gdrive-finder-service/releases/latest | grep "browser_download_url.*pkg" | cut -d '"' -f 4)

    if [[ -n "$LATEST_URL" ]]; then
        echo "   Downloading from: $LATEST_URL"
        curl -L -o "/tmp/gdrive-finder-service.pkg" "$LATEST_URL"
        echo "   Opening installer (follow the prompts)..."
        open "/tmp/gdrive-finder-service.pkg"
        echo "   ⏳ Please complete the pkg installation, then press Enter to continue..."
        read -r
    else
        echo "   ❌ Could not download. Please install manually from:"
        echo "      https://github.com/gentle-systems/gdrive-finder-service/releases"
        echo ""
        echo "   After installing the app, run this script again."
        exit 1
    fi
fi

# Install app if we have the source
if [[ -n "$APP_SOURCE" ]] && [[ -d "$APP_SOURCE" ]]; then
    echo "   Copying $APP_NAME to $APP_INSTALL_DIR..."

    # Remove old version if exists
    [[ -d "$APP_INSTALL_DIR/$APP_NAME" ]] && rm -rf "$APP_INSTALL_DIR/$APP_NAME"

    cp -R "$APP_SOURCE" "$APP_INSTALL_DIR/"

    # Register URL scheme
    echo "   Registering gdrive:// URL scheme..."
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_INSTALL_DIR/$APP_NAME"

    # Launch once to register Finder service (auto-quits after 5s)
    echo "   Registering Finder service..."
    open "$APP_INSTALL_DIR/$APP_NAME"
    sleep 6
fi

echo "   ✅ URL Handler installed"
echo ""

# =============================================================================
# Part 2: Install Clipboard Daemon
# =============================================================================
echo "🔧 [2/2] Installing Clipboard Daemon..."

# Create directories
mkdir -p "$INSTALL_DIR"
mkdir -p "$PLIST_DIR"

# Stop existing daemon if running
if launchctl list 2>/dev/null | grep -q "$LABEL"; then
    echo "   Stopping existing daemon..."
    launchctl stop "$LABEL" 2>/dev/null || true
    launchctl unload "$PLIST_FILE" 2>/dev/null || true
fi

# Copy daemon script
echo "   Installing daemon script..."
cp "$SCRIPT_DIR/clipboard-daemon/gdrive-clipboard-daemon.sh" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/gdrive-clipboard-daemon.sh"

# Create LaunchAgent plist
echo "   Creating LaunchAgent..."
cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$INSTALL_DIR/gdrive-clipboard-daemon.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/tmp/gdrive-daemon.err</string>
    <key>StandardOutPath</key>
    <string>/tmp/gdrive-daemon.out</string>
    <key>ProcessType</key>
    <string>Background</string>
    <key>LowPriorityIO</key>
    <true/>
</dict>
</plist>
EOF

# Load and start daemon
echo "   Starting daemon..."
launchctl load "$PLIST_FILE"
launchctl start "$LABEL"

# Verify
sleep 1
if launchctl list 2>/dev/null | grep -q "$LABEL"; then
    echo "   ✅ Clipboard Daemon installed and running"
else
    echo "   ❌ Failed to start daemon. Check /tmp/gdrive-daemon.err"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    Installation Complete!                    ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                              ║"
echo "║  How to use:                                                 ║"
echo "║                                                              ║"
echo "║  📋 Clipboard method (automatic):                            ║"
echo "║     Copy a gdrive:// link → file opens automatically         ║"
echo "║                                                              ║"
echo "║  📁 Finder method:                                           ║"
echo "║     Right-click file → Services → Copy gdrive:// link        ║"
echo "║                                                              ║"
echo "║  Commands:                                                   ║"
echo "║     Stop daemon:  launchctl stop $LABEL      ║"
echo "║     Start daemon: launchctl start $LABEL     ║"
echo "║     View logs:    cat ~/.gdrive-daemon.log                   ║"
echo "║     Uninstall:    ./uninstall.sh                             ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"

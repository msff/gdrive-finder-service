#!/bin/bash
# GDrive Tools Remote Installer v2.0
# Usage: curl -fsSL https://raw.githubusercontent.com/msff/gdrive-finder-service/main/remote-install.sh | bash

set -e

REPO="msff/gdrive-finder-service"
BRANCH="main"
TMP_DIR=$(mktemp -d)
LABEL="io.skms.gdrive-clipboard-daemon"
INSTALL_DIR="$HOME/.local/bin"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_FILE="$PLIST_DIR/$LABEL.plist"
SERVICES_DIR="$HOME/Library/Services"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           GDrive Tools Installer v2.0                        ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  1. URL Handler      - gdrive:// links open in Finder        ║"
echo "║  2. Clipboard Daemon - auto-opens copied gdrive:// links     ║"
echo "║  3. Quick Action     - copy link with Google Drive URL       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# =============================================================================
# Part 1: Install URL Handler App
# =============================================================================
echo "🔧 [1/3] Installing URL Handler..."

# Download latest release pkg
LATEST_URL=$(curl -s "https://api.github.com/repos/gentle-systems/gdrive-finder-service/releases/latest" | grep "browser_download_url.*pkg" | cut -d '"' -f 4)

if [[ -n "$LATEST_URL" ]]; then
    echo "   Downloading gdrive-finder-service.pkg..."
    curl -fsSL -o "$TMP_DIR/gdrive-finder-service.pkg" "$LATEST_URL"

    echo "   Installing (may require password)..."
    sudo installer -pkg "$TMP_DIR/gdrive-finder-service.pkg" -target / 2>/dev/null || {
        echo "   ⚠️  Auto-install failed. Opening installer manually..."
        open "$TMP_DIR/gdrive-finder-service.pkg"
        echo "   ⏳ Please complete the installation, then press Enter..."
        read -r
    }

    # Register URL scheme
    if [[ -d "/Applications/gdrive-finder-service.app" ]]; then
        /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/gdrive-finder-service.app" 2>/dev/null || true
    fi

    echo "   ✅ URL Handler installed"
else
    echo "   ⚠️  Could not find latest release. Skipping URL handler."
    echo "   Install manually from: https://github.com/gentle-systems/gdrive-finder-service/releases"
fi

echo ""

# =============================================================================
# Part 2: Install Clipboard Daemon
# =============================================================================
echo "🔧 [2/3] Installing Clipboard Daemon..."

# Create directories
mkdir -p "$INSTALL_DIR"
mkdir -p "$PLIST_DIR"

# Stop existing daemon if running
if launchctl list 2>/dev/null | grep -q "$LABEL"; then
    echo "   Stopping existing daemon..."
    launchctl stop "$LABEL" 2>/dev/null || true
    launchctl unload "$PLIST_FILE" 2>/dev/null || true
fi

# Download daemon script
echo "   Downloading daemon script..."
curl -fsSL -o "$INSTALL_DIR/gdrive-clipboard-daemon.sh" \
    "https://raw.githubusercontent.com/$REPO/$BRANCH/clipboard-daemon/gdrive-clipboard-daemon.sh"
chmod +x "$INSTALL_DIR/gdrive-clipboard-daemon.sh"

# Download copy-link script (used by Quick Action)
curl -fsSL -o "$INSTALL_DIR/gdrive-copy-link.sh" \
    "https://raw.githubusercontent.com/$REPO/$BRANCH/clipboard-daemon/gdrive-copy-link.sh"
chmod +x "$INSTALL_DIR/gdrive-copy-link.sh"

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
    echo "   ✅ Clipboard Daemon running"
else
    echo "   ❌ Failed to start daemon. Check /tmp/gdrive-daemon.err"
fi

echo ""

# =============================================================================
# Part 3: Install Quick Action (Finder Service)
# =============================================================================
echo "🔧 [3/3] Installing Quick Action..."

mkdir -p "$SERVICES_DIR"

# Download and extract workflow
curl -fsSL -o "$TMP_DIR/service.tar.gz" \
    "https://raw.githubusercontent.com/$REPO/$BRANCH/service/Copy%20GDrive%20Link%20with%20URL.workflow.tar.gz" 2>/dev/null || {
    # Fallback: download files individually
    echo "   Downloading workflow files..."
    mkdir -p "$TMP_DIR/Copy GDrive Link with URL.workflow/Contents"
    curl -fsSL -o "$TMP_DIR/Copy GDrive Link with URL.workflow/Contents/document.wflow" \
        "https://raw.githubusercontent.com/$REPO/$BRANCH/service/Copy%20GDrive%20Link%20with%20URL.workflow/Contents/document.wflow"
    curl -fsSL -o "$TMP_DIR/Copy GDrive Link with URL.workflow/Contents/Info.plist" \
        "https://raw.githubusercontent.com/$REPO/$BRANCH/service/Copy%20GDrive%20Link%20with%20URL.workflow/Contents/Info.plist"
}

# Copy workflow to Services
if [[ -d "$TMP_DIR/Copy GDrive Link with URL.workflow" ]]; then
    rm -rf "$SERVICES_DIR/Copy GDrive Link with URL.workflow"
    cp -R "$TMP_DIR/Copy GDrive Link with URL.workflow" "$SERVICES_DIR/"
    echo "   ✅ Quick Action installed"
else
    echo "   ⚠️  Failed to download Quick Action"
fi

# Refresh services
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain user 2>/dev/null || true

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    Installation Complete!                    ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                              ║"
echo "║  How to use:                                                 ║"
echo "║    📤 Share: Right-click → Quick Actions →                   ║"
echo "║              Copy GDrive Link with URL                       ║"
echo "║    📥 Open:  Copy a gdrive:// link → opens automatically     ║"
echo "║                                                              ║"
echo "║  Commands:                                                   ║"
echo "║    Logs:      cat ~/.gdrive-daemon.log                       ║"
echo "║    Stop:      launchctl stop io.skms.gdrive-clipboard-daemon ║"
echo "║    Uninstall: curl -fsSL bit.ly/gdrive-uninstall | bash      ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"

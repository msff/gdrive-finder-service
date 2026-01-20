# GDrive Finder Service + Clipboard Daemon

<p align="center"><img src="gdrive-share/Assets.xcassets/AppIcon.appiconset/google-eyes.png" alt="GDrive Finder Service Logo" width="128" height="128"></p>

> Fork of [gentle-systems/gdrive-finder-service](https://github.com/gentle-systems/gdrive-finder-service) with automatic clipboard monitoring.

Share Google Drive file locations as local `gdrive://` links that open directly in Finder.

![Usage demonstration](usage.gif)

## Features

| Feature | Description |
|---------|-------------|
| **URL Handler** | `gdrive://` links open files in Finder instead of browser |
| **Finder Service** | Right-click → Services → Copy gdrive:// link |
| **Clipboard Daemon** ⭐ | Auto-opens `gdrive://` links when copied (e.g., from Telegram) |

## Installation

**One-liner (recommended):**

```bash
curl -fsSL https://raw.githubusercontent.com/msff/gdrive-finder-service/main/remote-install.sh | bash
```

**Or clone repo:**

```bash
git clone https://github.com/msff/gdrive-finder-service.git
cd gdrive-finder-service
./install.sh
```

The installer will:
1. Install the URL handler app (or download it if not present)
2. Register the `gdrive://` URL scheme
3. Add Finder context menu service
4. Start the clipboard monitoring daemon

## Usage

### Method 1: Automatic (Clipboard) ⭐

1. Copy a `gdrive://` link (e.g., from Telegram, Slack, email)
2. File opens automatically in Finder
3. Notification confirms the action

**This solves the problem of Telegram/Slack not recognizing `gdrive://` as clickable links!**

### Method 2: Manual (Finder)

1. Right-click a file in Google Drive folder
2. Select **Services** → **Copy gdrive:// link**
3. Share the link — recipient can paste in browser or copy to clipboard

## Requirements

- macOS 10.15+
- [Google Drive for Desktop](https://www.google.com/drive/download/)

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                        GDrive Tools                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐     ┌──────────────────┐     ┌─────────────┐  │
│  │   Finder    │────▶│  gdrive-share    │────▶│  Clipboard  │  │
│  │  (context   │     │  (URL handler)   │     │  (gdrive:// │  │
│  │   menu)     │     │                  │     │   link)     │  │
│  └─────────────┘     └──────────────────┘     └─────────────┘  │
│                                                      │          │
│                                                      ▼          │
│  ┌─────────────┐     ┌──────────────────┐     ┌─────────────┐  │
│  │   Finder    │◀────│  gdrive-share    │◀────│  Clipboard  │  │
│  │  (file      │     │  (URL handler)   │     │   Daemon    │  │
│  │   opens)    │     │                  │     │ (monitors)  │  │
│  └─────────────┘     └──────────────────┘     └─────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Commands

```bash
# Check daemon status
launchctl list | grep gdrive

# Stop daemon
launchctl stop io.skms.gdrive-clipboard-daemon

# Start daemon
launchctl start io.skms.gdrive-clipboard-daemon

# View logs
cat ~/.gdrive-daemon.log

# Uninstall everything
curl -fsSL https://raw.githubusercontent.com/msff/gdrive-finder-service/main/remote-uninstall.sh | bash
```

## Files Installed

| File | Location |
|------|----------|
| URL Handler App | `/Applications/gdrive-share.app` |
| Clipboard Daemon | `~/.local/bin/gdrive-clipboard-daemon.sh` |
| LaunchAgent | `~/Library/LaunchAgents/io.skms.gdrive-clipboard-daemon.plist` |
| Log | `~/.gdrive-daemon.log` |

## Privacy & Security

- **Clipboard daemon only processes `gdrive://` links** — all other clipboard content is ignored and never logged
- No data is sent anywhere — everything runs locally
- Log contains only filenames of opened files (human-readable, not URL-encoded)
- Log auto-rotates at 500 lines

## Known Issues

- Telegram/Slack don't recognize `gdrive://` as clickable links (that's why we added the clipboard daemon!)
- Google Drive mount paths vary between systems — the URL handler accounts for common variations
- Non-English "Shared Drives" folder names may cause issues

---

## Development

### Building from source

1. Build in Xcode
2. Archive .app and put in `/Applications` folder

### Testing

```bash
# Refresh Finder services
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user
```

### Creating installer package

1. In Xcode: Product > Archive > Distribute App > Copy App
2. Archive the app under `./Installer/gdrive-finder-service/`
3. Run `./Installer/create_package`

---

## Changelog

### v1.2.0 (This Fork)
- ⭐ Added clipboard daemon for automatic link opening
- Added unified installer/uninstaller
- Added log rotation (max 500 lines)
- Fixed command injection vulnerability in notifications
- Improved notifications (shows decoded filename)

### v1.0.1 (Original)
- Initial release by gentle-systems

## Credits

- Original project: [gentle-systems/gdrive-finder-service](https://github.com/gentle-systems/gdrive-finder-service)
- Clipboard daemon: SKMS Labs

## License

MIT License (see LICENSE file)

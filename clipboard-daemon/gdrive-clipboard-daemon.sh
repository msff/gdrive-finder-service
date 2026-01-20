#!/bin/bash
# GDrive Clipboard Daemon v1.4
# Monitors clipboard for gdrive:// links and opens them automatically
#
# Install: ./install.sh
# Uninstall: ./uninstall.sh

LOG_FILE="$HOME/.gdrive-daemon.log"
MAX_LOG_LINES=500
LAST_CLIP=""

# Rotate log if too large
rotate_log() {
    if [[ -f "$LOG_FILE" ]]; then
        local lines=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
        if (( lines > MAX_LOG_LINES )); then
            tail -n $MAX_LOG_LINES "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
        fi
    fi
}

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
}

notify() {
    local message="$1"
    local title="$2"
    # Escape quotes to prevent AppleScript injection
    message="${message//\\/\\\\}"
    message="${message//\"/\\\"}"
    title="${title//\\/\\\\}"
    title="${title//\"/\\\"}"
    osascript -e "display notification \"$message\" with title \"$title\" sound name \"Pop\"" 2>/dev/null
}

# Rotate log on startup
rotate_log
log "Daemon started (v1.4)"

while true; do
    # Get current clipboard content
    CLIP=$(pbpaste 2>/dev/null)

    # Check if it's a new gdrive:// link (ONLY gdrive:// is processed, nothing else is logged)
    if [[ "$CLIP" == gdrive://* ]] && [[ "$CLIP" != "$LAST_CLIP" ]]; then
        # Decode filename for logging (human-readable)
        FILENAME=$(basename "$CLIP" | python3 -c "import sys, urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))" 2>/dev/null || basename "$CLIP")
        log "Opening: $FILENAME"

        # Create shareable format: readable filename + working encoded URL
        python3 << PYTHON_EOF
import urllib.parse
import subprocess
import os

url = """$CLIP"""
decoded = urllib.parse.unquote(url)
filename = os.path.basename(decoded)

# Format: readable filename as comment + working encoded URL
wrapped = f'# {filename}\n\`\`\`\n{url}\n\`\`\`'

# Copy to clipboard using pbcopy
p = subprocess.Popen(['pbcopy'], stdin=subprocess.PIPE)
p.communicate(wrapped.encode('utf-8'))
PYTHON_EOF

        # Open the link (use original encoded URL)
        if open "$CLIP" 2>/dev/null; then
            notify "$FILENAME" "GDrive Link Opened"
        else
            log "ERROR: Failed to open $DECODED_URL"
            notify "File not found: $FILENAME" "GDrive Error"
        fi

        # Remember to avoid re-opening (store wrapped version too)
        LAST_CLIP="$CLIP"
    fi

    # Check every 0.5 seconds
    sleep 0.5
done

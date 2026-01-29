#!/bin/bash
# GDrive Clipboard Daemon v1.9
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
log "Daemon started (v1.9)"

while true; do
    # Get current clipboard content
    CLIP=$(pbpaste 2>/dev/null)

    # Check if it's a gdrive:// link (raw or wrapped)
    # Handle both raw "gdrive://..." and wrapped "# filename\n...\ngdrive://..."

    RAW_URL=""
    IS_WRAPPED=false

    if [[ "$CLIP" == "# "* ]] && [[ "$CLIP" == *"gdrive://"* ]]; then
        # Wrapped format - extract the gdrive:// URL
        IS_WRAPPED=true
        RAW_URL=$(echo "$CLIP" | grep -o 'gdrive://[^`]*' | head -1)
    elif [[ "$CLIP" == gdrive://* ]]; then
        # Raw gdrive:// URL
        RAW_URL="$CLIP"
    fi

    if [[ -n "$RAW_URL" ]] && [[ "$CLIP" != "$LAST_CLIP" ]]; then
        # Decode filename for logging (human-readable)
        FILENAME=$(basename "$RAW_URL" | python3 -c "import sys, urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))" 2>/dev/null || basename "$RAW_URL")
        log "Opening: $FILENAME (wrapped=$IS_WRAPPED)"

        # If already wrapped, treat as incoming (just open, don't re-wrap)
        if [[ "$IS_WRAPPED" == true ]]; then
            IS_OUTGOING="incoming"
            log "  Already wrapped, treating as incoming"
        else
            # Check if this is outgoing (from Finder) or incoming (from messenger)
            # If Finder is frontmost AND file exists → outgoing → wrap for sharing
            # Otherwise → incoming → just open, don't modify clipboard

            # Decode URL and build local path
            LOCAL_PATH=$(printf '%s' "$RAW_URL" | python3 -c "
import sys, urllib.parse, os
url = sys.stdin.read()
decoded = urllib.parse.unquote(url)
home = os.path.expanduser('~')
print(decoded.replace('gdrive://', f'{home}/Library/'))
")

            # Check frontmost app (using AppleScript to avoid sandbox issues)
            FRONTMOST=$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null)

            if [[ "$FRONTMOST" == "Finder" ]] && [[ -f "$LOCAL_PATH" ]]; then
                # Outgoing from Finder - wrap for sharing
                # Note: xattr is blocked by LaunchAgent sandbox, so we skip Google URL
                IS_OUTGOING="outgoing"
                FILE_ID=""  # Can't get due to sandbox, will skip Google URL
                log "  Outgoing from Finder (sandbox blocks xattr, skipping Google URL)"
            else
                IS_OUTGOING="incoming"
                log "  Incoming (frontmost=$FRONTMOST)"
            fi
        fi  # end of IS_WRAPPED check

        # Determine if folder or file for Google URL generation
        if [[ -d "$LOCAL_PATH" ]]; then
            export IS_FOLDER="true"
        else
            export IS_FOLDER="false"
        fi

        if [[ "$IS_OUTGOING" == "outgoing" ]]; then
            # OUTGOING: Create shareable format
            # Pass FILE_ID via environment (may be empty due to sandbox)
            export FILE_ID
            printf '%s' "$RAW_URL" | python3 -c '
import urllib.parse
import subprocess
import os
import sys

url = sys.stdin.read()
decoded = urllib.parse.unquote(url)
filename = os.path.basename(decoded)
file_id = os.environ.get("FILE_ID", "")

# Format: filename + optional Google URL + gdrive:// (for desktop with daemon)
if file_id:
    # Check if folder or file
    is_folder = os.environ.get("IS_FOLDER", "false") == "true"
    if is_folder:
        gdrive_url = f"https://drive.google.com/drive/folders/{file_id}"
    else:
        gdrive_url = f"https://drive.google.com/file/d/{file_id}/view"
    wrapped = f"# {filename}\n📱 {gdrive_url}\n```\n{url}\n```"
else:
    # No file_id available (sandbox limitation) - skip Google URL
    wrapped = f"# {filename}\n```\n{url}\n```"

# Copy to clipboard
p = subprocess.Popen(["pbcopy"], stdin=subprocess.PIPE)
p.communicate(wrapped.encode("utf-8"))
'
            log "Outgoing: prepared for sharing"
        else
            # INCOMING: Don't modify clipboard, just open
            log "Incoming: opening file"
        fi

        # Open the link (use RAW_URL, not CLIP which may be wrapped)
        if open "$RAW_URL" 2>/dev/null; then
            notify "$FILENAME" "GDrive Link Opened"
        else
            log "ERROR: Failed to open $RAW_URL"
            notify "File not found: $FILENAME" "GDrive Error"
        fi

        # Remember to avoid re-opening (store wrapped version too)
        LAST_CLIP="$CLIP"
    fi

    # Check every 0.5 seconds
    sleep 0.5
done

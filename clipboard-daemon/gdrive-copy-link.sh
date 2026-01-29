#!/bin/bash
# Copy GDrive link with Google URL
# Called by Automator Service

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

for f in "$@"; do
    # Skip if not in Google Drive
    if [[ "$f" != *"/Library/CloudStorage/GoogleDrive-"* ]]; then
        continue
    fi

    # Create gdrive:// URL
    RELATIVE_PATH="${f#*/Library/}"
    ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$RELATIVE_PATH', safe='/'))")
    GDRIVE_URL="gdrive://$ENCODED"

    # Get filename (decoded)
    FILENAME=$(basename "$f")

    # Get Google Drive file ID via xattr
    FILE_ID=$(xattr -p "com.google.drivefs.item-id#S" "$f" 2>/dev/null)

    # Create wrapped format
    if [[ -n "$FILE_ID" ]]; then
        # Determine if folder or file
        if [[ -d "$f" ]]; then
            GOOGLE_URL="https://drive.google.com/drive/folders/$FILE_ID"
        else
            GOOGLE_URL="https://drive.google.com/file/d/$FILE_ID/view"
        fi

        WRAPPED="**$FILENAME**

$GOOGLE_URL

\`\`\`
$GDRIVE_URL
\`\`\`"
    else
        WRAPPED="**$FILENAME**

\`\`\`
$GDRIVE_URL
\`\`\`"
    fi

    # Copy to clipboard
    printf '%s' "$WRAPPED" | pbcopy

    # Notify
    osascript -e "display notification \"Link copied with Google URL\" with title \"$FILENAME\""
done

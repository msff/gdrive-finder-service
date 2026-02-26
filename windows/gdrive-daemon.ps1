# gdrive-daemon.ps1
# GDrive Clipboard Daemon v2.0 — Windows version
# Monitors clipboard for gdrive:// links and opens them in Explorer
#
# Usage: powershell -ExecutionPolicy Bypass -File gdrive-daemon.ps1
# Stop:  Stop the "GDriveClipboardDaemon" scheduled task or kill the process

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Add-Type -AssemblyName System.Windows.Forms

$LOG_FILE = Join-Path $env:USERPROFILE ".gdrive-daemon.log"
$MAX_LOG_LINES = 500
$LAST_CLIP = ""
$POLL_MS = 500

# --- Logging ---

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LOG_FILE -Value "$timestamp $Message" -Encoding UTF8
}

function Invoke-LogRotation {
    if (Test-Path $LOG_FILE) {
        $lineCount = (Get-Content $LOG_FILE -ErrorAction SilentlyContinue | Measure-Object -Line).Lines
        if ($lineCount -gt $MAX_LOG_LINES) {
            $tail = Get-Content $LOG_FILE -Tail $MAX_LOG_LINES -Encoding UTF8
            Set-Content -Path $LOG_FILE -Value $tail -Encoding UTF8
        }
    }
}

# --- Toast notification ---

function Show-Notification {
    param(
        [string]$Title,
        [string]$Message
    )
    try {
        $notifyIcon = New-Object System.Windows.Forms.NotifyIcon
        $notifyIcon.Icon = [System.Drawing.SystemIcons]::Information
        $notifyIcon.BalloonTipTitle = $Title
        $notifyIcon.BalloonTipText = $Message
        $notifyIcon.Visible = $true
        $notifyIcon.ShowBalloonTip(3000)
        # Dispose after brief delay (fire and forget via timer)
        $timer = New-Object System.Timers.Timer
        $timer.Interval = 4000
        $timer.AutoReset = $false
        Register-ObjectEvent -InputObject $timer -EventName Elapsed -Action {
            $notifyIcon.Dispose()
            $timer.Dispose()
        } | Out-Null
        $timer.Start()
    } catch {
        # Notification is non-critical
    }
}

# --- Find Google Drive mount point ---

function Find-GDriveMount {
    # Strategy 1: Check registry for DriveFS mount point
    $drivefsKey = "HKCU:\Software\Google\DriveFS"
    if (Test-Path $drivefsKey) {
        try {
            $mountPoint = (Get-ItemProperty $drivefsKey -ErrorAction SilentlyContinue).MountPoint
            if ($mountPoint -and (Test-Path $mountPoint)) {
                return $mountPoint.TrimEnd('\')
            }
        } catch {}
    }

    # Strategy 2: Scan drive letters for Google Drive markers
    $driveLetters = (Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue |
        Where-Object { $_.Used -ne $null }).Root

    foreach ($dl in $driveLetters) {
        $sharedPath = Join-Path $dl "Shared drives"
        $myDrivePath = Join-Path $dl "My Drive"
        if ((Test-Path $sharedPath) -or (Test-Path $myDrivePath)) {
            return $dl.TrimEnd('\')
        }
    }

    # Strategy 3: User profile paths
    $possiblePaths = @(
        (Join-Path $env:USERPROFILE "Google Drive"),
        (Join-Path $env:USERPROFILE "Google Drive Stream")
    )
    foreach ($pp in $possiblePaths) {
        if (Test-Path $pp) {
            return $pp
        }
    }

    return $null
}

# --- Resolve gdrive:// URL to local Windows path ---

function Resolve-GDriveUrl {
    param([string]$Url)

    # Decode %40 -> @
    $decoded = [System.Uri]::UnescapeDataString($Url)

    # Remove scheme
    $pathPart = $decoded -replace '^gdrive://', ''

    # Extract the relative path after email/mount info
    # Formats:
    #   gdrive://CloudStorage/GoogleDrive-user@domain/Общие диски/SKMS Main/...
    #   gdrive://CloudStorage/GoogleDrive-user@domain/Shared drives/SKMS Main/...
    #   gdrive://CloudStorage/GoogleDrive-user@domain/My Drive/...
    #   gdrive://Shared drives/...
    #   gdrive://My Drive/...

    $relativePath = ""

    if ($pathPart -match '^CloudStorage/GoogleDrive-[^/]+/(.+)$') {
        $relativePath = $Matches[1]
    } else {
        $relativePath = $pathPart
    }

    # Normalize: Mac uses "Общие диски", Windows may use "Shared drives" or localized name
    # We try both variants

    $gdriveMount = Find-GDriveMount
    if (-not $gdriveMount) {
        return $null
    }

    # Convert forward slashes to backslashes
    $relativePath = $relativePath -replace '/', '\'

    # Try direct path first
    $candidate = Join-Path $gdriveMount $relativePath
    if (Test-Path $candidate) {
        return $candidate
    }

    # Try swapping "Общие диски" <-> "Shared drives"
    $swapped = $relativePath -replace '^Общие диски', 'Shared drives'
    if ($swapped -ne $relativePath) {
        $candidate = Join-Path $gdriveMount $swapped
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    $swapped = $relativePath -replace '^Shared drives', 'Общие диски'
    if ($swapped -ne $relativePath) {
        $candidate = Join-Path $gdriveMount $swapped
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    # Try swapping "My Drive" <-> "Мой диск"
    $swapped = $relativePath -replace '^Мой диск', 'My Drive'
    if ($swapped -ne $relativePath) {
        $candidate = Join-Path $gdriveMount $swapped
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    $swapped = $relativePath -replace '^My Drive', 'Мой диск'
    if ($swapped -ne $relativePath) {
        $candidate = Join-Path $gdriveMount $swapped
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    # Last resort: try the path as-is (maybe partial match)
    # Remove leading shared drive prefix and search
    if ($relativePath -match '^(Shared drives|Общие диски)\\(.+)$') {
        $innerPath = $Matches[2]
        # Try finding SKMS Main or the first folder
        foreach ($variant in @("Shared drives", "Общие диски")) {
            $candidate = Join-Path $gdriveMount (Join-Path $variant $innerPath)
            if (Test-Path $candidate) {
                return $candidate
            }
        }
    }

    return $null
}

# --- Extract gdrive:// URL from clipboard text ---

function Extract-GDriveUrl {
    param([string]$Text)

    $rawUrl = ""
    $isWrapped = $false

    # Check for wrapped format: starts with "**" or "# " and contains gdrive://
    if (($Text -match '^\*\*') -or ($Text -match '^# ')) {
        if ($Text -match 'gdrive://') {
            $isWrapped = $true
            # Extract URL from wrapped format (between ``` blocks or standalone line)
            if ($Text -match 'gdrive://[^\s`]+') {
                $rawUrl = $Matches[0]
            }
        }
    }
    # Raw gdrive:// URL
    elseif ($Text -match '^gdrive://') {
        $rawUrl = $Text.Trim()
        # Remove trailing whitespace/newlines
        $rawUrl = ($rawUrl -split "`n")[0].Trim()
    }

    return @{
        Url       = $rawUrl
        IsWrapped = $isWrapped
    }
}

# --- Main loop ---

Invoke-LogRotation
Write-Log "Daemon started (v2.0 Windows)"

$gdriveMount = Find-GDriveMount
if ($gdriveMount) {
    Write-Log "Google Drive mount: $gdriveMount"
} else {
    Write-Log "WARNING: Google Drive mount not found. Will retry on each URL."
}

while ($true) {
    try {
        # Get current clipboard text
        $clip = Get-Clipboard -ErrorAction SilentlyContinue

        # Get-Clipboard can return array of lines — join them
        if ($clip -is [array]) {
            $clipText = $clip -join "`n"
        } else {
            $clipText = [string]$clip
        }

        if ($clipText -and ($clipText -ne $LAST_CLIP)) {
            $extracted = Extract-GDriveUrl -Text $clipText

            if ($extracted.Url) {
                $rawUrl = $extracted.Url
                $isWrapped = $extracted.IsWrapped

                # Get filename for logging
                $urlDecoded = [System.Uri]::UnescapeDataString($rawUrl)
                $filename = [System.IO.Path]::GetFileName($urlDecoded -replace '/', '\')

                Write-Log "Detected: $filename (wrapped=$isWrapped)"

                # Resolve to local path
                $localPath = Resolve-GDriveUrl -Url $rawUrl

                if ($localPath -and (Test-Path $localPath)) {
                    $isFolder = (Test-Path $localPath -PathType Container)

                    if ($isFolder) {
                        # Open folder in Explorer
                        Start-Process explorer.exe -ArgumentList "`"$localPath`""
                        Write-Log "Opened folder: $localPath"
                    } else {
                        # Show file in Explorer (select it)
                        Start-Process explorer.exe -ArgumentList "/select,`"$localPath`""
                        Write-Log "Revealed file: $localPath"
                    }

                    Show-Notification -Title "GDrive Link Opened" -Message $filename
                } else {
                    Write-Log "ERROR: Path not found for $rawUrl"
                    Write-Log "  Resolved attempt: $localPath"
                    Show-Notification -Title "GDrive Error" -Message "File not found: $filename"
                }

                # Remember this clipboard content
                $LAST_CLIP = $clipText
            }
        }
    } catch {
        Write-Log "ERROR: $($_.Exception.Message)"
    }

    Start-Sleep -Milliseconds $POLL_MS
}

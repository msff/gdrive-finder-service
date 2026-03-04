# uninstall.ps1
# GDrive Tools Uninstaller — Windows version
# Removes: scripts, registry entries, scheduled task, stops daemon
#
# Usage: powershell -ExecutionPolicy Bypass -File uninstall.ps1

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$INSTALL_DIR = Join-Path $env:LOCALAPPDATA "gdrive-finder-service"
$TASK_NAME = "GDriveClipboardDaemon"

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "          GDrive Tools Uninstaller (Windows)                    " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# =============================================================================
# Step 1: Stop and remove scheduled task
# =============================================================================
Write-Host "[1/4] Stopping clipboard daemon..." -ForegroundColor Yellow

$existingTask = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
if ($existingTask) {
    Stop-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $TASK_NAME -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "  Scheduled task removed" -ForegroundColor Green
} else {
    Write-Host "  No scheduled task found (already removed)" -ForegroundColor DarkGray
}

# Kill any running daemon processes
$daemonProcs = Get-Process powershell -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*gdrive-daemon.ps1*" }
if ($daemonProcs) {
    $daemonProcs | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "  Daemon process stopped" -ForegroundColor Green
}

# =============================================================================
# Step 2: Remove registry entries — URL scheme
# =============================================================================
Write-Host "[2/4] Removing gdrive:// URL scheme..." -ForegroundColor Yellow

$urlSchemeKey = "HKCU:\Software\Classes\gdrive"
if (Test-Path $urlSchemeKey) {
    Remove-Item -Path $urlSchemeKey -Recurse -Force
    Write-Host "  URL scheme removed" -ForegroundColor Green
} else {
    Write-Host "  URL scheme not found (already removed)" -ForegroundColor DarkGray
}

# =============================================================================
# Step 3: Remove registry entries — context menu
# =============================================================================
Write-Host "[3/4] Removing Explorer context menu..." -ForegroundColor Yellow

$menuKeys = @(
    "HKCU:\Software\Classes\*\shell\CopyGDriveLink",
    "HKCU:\Software\Classes\Directory\shell\CopyGDriveLink",
    "HKCU:\Software\Classes\Directory\Background\shell\CopyGDriveLink"
)

$removedAny = $false
foreach ($key in $menuKeys) {
    if (Test-Path $key) {
        Remove-Item -Path $key -Recurse -Force
        $removedAny = $true
    }
}

if ($removedAny) {
    Write-Host "  Context menu entries removed" -ForegroundColor Green
} else {
    Write-Host "  Context menu entries not found (already removed)" -ForegroundColor DarkGray
}

# =============================================================================
# Step 4: Remove installed scripts
# =============================================================================
Write-Host "[4/4] Removing scripts..." -ForegroundColor Yellow

if (Test-Path $INSTALL_DIR) {
    # Keep uninstall.ps1 running from memory, remove everything else first
    $filesToRemove = Get-ChildItem -Path $INSTALL_DIR -File |
        Where-Object { $_.Name -ne "uninstall.ps1" }

    foreach ($f in $filesToRemove) {
        Remove-Item $f.FullName -Force -ErrorAction SilentlyContinue
    }

    # Remove directory (will succeed if empty or only has uninstall.ps1)
    # Schedule cleanup after script exits
    $cleanupCmd = "Start-Sleep -Seconds 2; Remove-Item -Path '$INSTALL_DIR' -Recurse -Force -ErrorAction SilentlyContinue"
    Start-Process powershell.exe -ArgumentList "-NoProfile -WindowStyle Hidden -Command $cleanupCmd" -WindowStyle Hidden

    Write-Host "  Scripts removed from: $INSTALL_DIR" -ForegroundColor Green
} else {
    Write-Host "  Install directory not found (already removed)" -ForegroundColor DarkGray
}

# =============================================================================
# Optional: Remove log file
# =============================================================================
$logFile = Join-Path $env:USERPROFILE ".gdrive-daemon.log"
if (Test-Path $logFile) {
    Remove-Item $logFile -Force -ErrorAction SilentlyContinue
    Write-Host "  Log file removed" -ForegroundColor Green
}

# =============================================================================
# Done
# =============================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "              Uninstall Complete!                                " -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  All GDrive tools have been removed." -ForegroundColor White
Write-Host "  To reinstall, run: .\install.ps1" -ForegroundColor DarkGray
Write-Host ""

# UI verify: launches the game with --ui-verify so the UI driver screenshots the
# lobby and the world editor into user://ui_verify_shots, then copies results
# into tools/selftest/results/ui_verify/ for viewing.
param(
    [string]$GodotExe = "C:\Users\pjotr\Tools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
)

$ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
if (-not (Test-Path $GodotExe)) {
    Write-Error "Godot executable not found: $GodotExe"
    exit 1
}

$ResultsDir = Join-Path $ProjectRoot "tools\selftest\results\ui_verify"
if (-not (Test-Path $ResultsDir)) { New-Item -ItemType Directory -Path $ResultsDir -Force | Out-Null }

Write-Host "Project: $ProjectRoot"

# Back up the user's editor level before the test clobbers it, so running the
# selftest never wipes the map the user hand-placed in the world editor.
$UserDataDirEarly = Join-Path $env:APPDATA "Godot\app_userdata\Rift Survivors"
$LevelFile = Join-Path $UserDataDirEarly "world_editor_level.json"
$LevelBackup = Join-Path $UserDataDirEarly "world_editor_level.json.uivf.bak"
if (Test-Path $LevelFile) {
    Copy-Item $LevelFile $LevelBackup -Force
    Write-Host "Backed up editor level -> world_editor_level.json.uivf.bak"
}

$godotArgs = @("--path", $ProjectRoot, "--ui-verify")
$godotProc = Start-Process -FilePath $GodotExe -ArgumentList $godotArgs -NoNewWindow -PassThru
if (-not $godotProc.WaitForExit(120000)) {
    Write-Host "TIMEOUT: killing Godot after 2 min"
    Stop-Process -Id $godotProc.Id -Force -ErrorAction SilentlyContinue
}
Write-Host "Godot exited."

# Restore the user's editor level so the selftest never leaves a clobbered map.
if (Test-Path $LevelBackup) {
    Copy-Item $LevelBackup $LevelFile -Force
    Write-Host "Restored editor level from backup (test did not modify the user map)"
}

$UserDataDir = Join-Path $env:APPDATA "Godot\app_userdata\Rift Survivors"
$shotsSrc = Join-Path $UserDataDir "ui_verify_shots"
$reportSrc = Join-Path $UserDataDir "ui_verify_report.json"
if (Test-Path $reportSrc) { Copy-Item $reportSrc (Join-Path $ResultsDir "ui_verify_report.json") -Force }
if (Test-Path $shotsSrc) {
    Get-ChildItem $shotsSrc -Filter *.png | ForEach-Object {
        Copy-Item $_.FullName $ResultsDir -Force
        Write-Host "Copied shot: $($_.Name)"
    }
}
Write-Host "`n=== UI VERIFY REPORT ==="
$reportDest = Join-Path $ResultsDir "ui_verify_report.json"
if (Test-Path $reportDest) { Get-Content $reportDest } else { Write-Host "FAIL: no report produced" }

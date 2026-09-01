param(
    [Parameter(Mandatory = $true)]
    [string]$RequestPath
)

# Self-test runner: stages the request JSON, launches the game windowed on main.tscn,
# waits for the process to exit (driver calls get_tree().quit), then prints the report path.
# The Godot process inherits this console, so game stdout/stderr (including
# AudioService/SelfTestDriver prints) streams inline to make diagnosing failures easy.
# usage: powershell -ExecutionPolicy Bypass -File tools/selftest/run_selftest.ps1 -RequestPath tools/selftest/requests/keg_target.json

$ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))

$GodotExe = "C:\Users\pjotr\Tools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
$RequestPathResolved = Resolve-Path $RequestPath
$UserDataDir = Join-Path $env:APPDATA "Godot\app_userdata\Rift Survivors"
if (-not (Test-Path $UserDataDir)) {
    New-Item -ItemType Directory -Path $UserDataDir -Force | Out-Null
}
$ReqOut = Join-Path $UserDataDir "selftest_request.json"
$ReportOut = Join-Path $UserDataDir "selftest_report.json"

Write-Host "Project: $ProjectRoot"
Write-Host "Request: $RequestPathResolved"
Write-Host "Staging: $ReqOut"

$bytes = [System.IO.File]::ReadAllBytes($RequestPathResolved)
[System.IO.File]::WriteAllBytes($ReqOut, $bytes)
Write-Host ("Staged bytes: {0}" -f $bytes.Length)
if (Test-Path $ReportOut) { Remove-Item $ReportOut -Force }

# Run the game in-process so "user://" resolves to the same %APPDATA%\...\Rift Survivors
# the runner stages to. Player.log next to it captures everything the game prints; we
# tail it before the report check so the game has fully flushed/closed the report file.
& $GodotExe --path $ProjectRoot "res://scenes/main/main.tscn"
Start-Sleep -Milliseconds 500
$logTail = Get-Content (Join-Path $UserDataDir "logs\godot.log") -Tail 80 -ErrorAction SilentlyContinue
if ($logTail) { Write-Host "`n=== GAME LOG (tail) ==="; $logTail | ForEach-Object { Write-Host $_ } }
Write-Host "Godot exited."

# The game prints "report → user://..." before it's closed the FileAccess handle, so
# polling beats a single Test-Path — give it up to 10s to flush.
$reportFound = $false
for ($i = 0; $i -lt 20; $i++) {
    if (Test-Path $ReportOut) { $reportFound = $true; break }
    Start-Sleep -Milliseconds 500
}
if (-not $reportFound) {
    Write-Host "FAIL: no report produced (driver never finished)"
    exit 2
}

if (Test-Path $ReportOut) {
    Write-Host "`n=== SELF-TEST REPORT ==="
    Get-Content $ReportOut
    exit 0
} else {
    Write-Host "FAIL: no report produced (driver never finished)"
    exit 2
}

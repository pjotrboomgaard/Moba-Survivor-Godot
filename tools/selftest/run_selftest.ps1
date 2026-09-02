param(
    [Parameter(Mandatory = $true)]
    [string]$RequestPath,
    [string]$Hero = ""
)

# Self-test runner: stages the request JSON, launches the game windowed on main.tscn,
# waits for the process to exit (driver calls get_tree().quit), then prints the report path.
# The Godot process inherits this console, so game stdout/stderr (including
# AudioService/SelfTestDriver prints) streams inline to make diagnosing failures easy.
# usage: powershell -ExecutionPolicy Bypass -File tools/selftest/run_selftest.ps1 -RequestPath tools/selftest/requests/keg_target.json
#        powershell -ExecutionPolicy Bypass -File tools/selftest/run_selftest.ps1 -RequestPath tools/selftest/requests/solo_survival.json -Hero arclight

$ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))

$GodotExe = "C:\Users\pjotr\Tools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
$RequestPathResolved = Resolve-Path $RequestPath
$UserDataDir = Join-Path $env:APPDATA "Godot\app_userdata\Rift Survivors"
if (-not (Test-Path $UserDataDir)) {
    New-Item -ItemType Directory -Path $UserDataDir -Force | Out-Null
}
$ReqOut = Join-Path $UserDataDir "selftest_request.json"
$ReportOut = Join-Path $UserDataDir "selftest_report.json"
$ResultsDir = Join-Path $ProjectRoot "tools\selftest\results"

Write-Host "Project: $ProjectRoot"
Write-Host "Request: $RequestPathResolved"
if ($Hero) { Write-Host "Hero override: $Hero" }
Write-Host "Staging: $ReqOut"

$raw = [System.IO.File]::ReadAllText($RequestPathResolved)
if ($Hero) {
    if ($raw -match '"hero"\s*:') {
        $raw = [regex]::Replace($raw, '"hero"\s*:\s*"[^"]*"', ('"hero": "' + $Hero + '"'))
    } else {
        $raw = $raw.TrimStart()
        if ($raw.StartsWith("{")) {
            $raw = '{ "hero": "' + $Hero + '",' + $raw.Substring(1)
        }
    }
}
[System.IO.File]::WriteAllText($ReqOut, $raw)
Write-Host ("Staged bytes: {0}" -f ([System.Text.Encoding]::UTF8.GetByteCount($raw)))
if (Test-Path $ReportOut) { Remove-Item $ReportOut -Force }

# Run the game in-process so "user://" resolves to the same %APPDATA%\...\Rift Survivors
# the runner stages to. Player.log next to it captures everything the game prints; we
# tail it before the report check so the game has fully flushed/closed the report file.
# `&` on the Godot launcher returns as soon as the wrapper detaches; use Wait-Process so
# we actually block until the real windowed child exits (this is when the report exists).
$godotProc = Start-Process -FilePath $GodotExe -ArgumentList @("--path", $ProjectRoot, "--selftest", "res://scenes/main/main.tscn") -NoNewWindow -PassThru
if (-not $godotProc.WaitForExit(1200000)) {
    Write-Host "TIMEOUT: killing Godot after 20m"
    Stop-Process -Id $godotProc.Id -Force -ErrorAction SilentlyContinue
    Get-Process -Name "Godot*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
$logTail = Get-Content (Join-Path $UserDataDir "logs\godot.log") -Tail 80 -ErrorAction SilentlyContinue
if ($logTail) { Write-Host "`n=== GAME LOG (tail) ==="; $logTail | ForEach-Object { Write-Host $_ } }
Write-Host "Godot exited."

# The game prints "report → user://..." before it's closed the FileAccess handle, so
# polling beats a single Test-Path — give it a short window for the FS to settle after exit.
$reportFound = $false
for ($i = 0; $i -lt 10; $i++) {
    if (Test-Path $ReportOut) { $reportFound = $true; break }
    Start-Sleep -Milliseconds 500
}
if (-not $reportFound) {
    Write-Host "FAIL: no report produced (driver never finished)"
    exit 2
}

if (Test-Path $ReportOut) {
    if (-not (Test-Path $ResultsDir)) { New-Item -ItemType Directory -Path $ResultsDir -Force | Out-Null }
    $baseName = [IO.Path]::GetFileNameWithoutExtension($RequestPath)
    if ($Hero) { $baseName = $baseName + "_" + $Hero }
    $ReportCopy = Join-Path $ResultsDir ($baseName + "_report.json")
    Copy-Item $ReportOut $ReportCopy -Force
    Write-Host "Report copied: $ReportCopy"
    Write-Host "`n=== SELF-TEST REPORT ==="
    Get-Content $ReportOut
    exit 0
} else {
    Write-Host "FAIL: no report produced (driver never finished)"
    exit 2
}

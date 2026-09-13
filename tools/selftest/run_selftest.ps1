param(
    [Parameter(Mandatory = $true)]
    [string]$RequestPath,
    [string]$Hero = "",
    # Main scene to launch. Defaults to the normal game (main.tscn). Set to
    # "res://scenes/minigame_test/minigame_test.tscn" for isolated minigame tests.
    [string]$Scene = "res://scenes/main/main.tscn",
    [string[]]$ExtraUserArgs = @(),
    # Before/after comparison (T3.37 hard rule). When set to an existing PNG, after the
    # run completes the runner diffs this "before" image against the "after" (the run's
    # own screenshot) and writes diff.png + diff_report.json next to the result. Pass a
    # path to a prior run's screenshot to prove the change actually landed on screen.
    [string]$BeforeShot = ""
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
$godotArgs = @("--path", $ProjectRoot)
if ($ExtraUserArgs -and $ExtraUserArgs.Count -gt 0) {
    $godotArgs += $ExtraUserArgs
    Write-Host ("User args: {0}" -f ($ExtraUserArgs -join " "))
}
$godotArgs += @("--selftest", $Scene)
# Use & call operator so args like `--ffa` pass through verbatim (Start-Process
# mangles the `--` user-args separator). & blocks until Godot exits.
& $GodotExe @godotArgs | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "TIMEOUT/FAIL: killing Godot"
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

    # T3.35/T3.36: copy the actual screenshot PNGs out of the run's temp user:// dir so
    # they can be inspected with the Read tool (rule: screenshot-analysis.mdc).
    $reportText = Get-Content $ReportOut -Raw
    $shotsDir = Join-Path $ResultsDir $baseName
    if ($reportText -match '"path"\s*:\s*"([^"]+\.png)"') {
        $allMatches = [regex]::Matches($reportText, '"path"\s*:\s*"([^"]+\.png)"')
        if ($allMatches.Count -gt 0) {
            if (-not (Test-Path $shotsDir)) { New-Item -ItemType Directory -Path $shotsDir -Force | Out-Null }
            foreach ($m in $allMatches) {
                $src = $m.Groups[1].Value -replace '\\', '\'
                # user:// was already globalized by Godot when written, so this is an absolute path.
                if (Test-Path $src) {
                    $fileName = [IO.Path]::GetFileName($src)
                    $dest = Join-Path $shotsDir $fileName
                    Copy-Item $src $dest -Force
                    Write-Host ("Shot copied: " + $dest)
                }
            }
            Write-Host ("Screenshots dir: " + $shotsDir)
        }
    } else {
        Write-Host "No screenshot paths found in report"
    }

    # Before/after diff (T3.37 hard rule). When -BeforeShot is provided and the run
    # produced at least one screenshot, diff every screenshot against the "before"
    # image and write diff_<name>.png + diff_report.json next to the results so the
    # change is unambiguous.
    if ($BeforeShot -and (Test-Path $BeforeShot)) {
        $beforeResolved = (Resolve-Path $BeforeShot).Path
        $diffTool = Join-Path $ProjectRoot "tools\diff_screenshots.py"
        if (Test-Path $diffTool) {
            if (Test-Path $shotsDir) {
                Get-ChildItem -Path $shotsDir -Filter "*.png" | ForEach-Object {
                    $afterName = $_.Name
                    $diffOut = Join-Path $shotsDir ("diff_" + $afterName)
                    $diffReport = Join-Path $shotsDir ("diff_" + [IO.Path]::GetFileNameWithoutExtension($afterName) + "_report.json")
                    Write-Host ("Diffing: " + $beforeResolved + " vs " + $_.FullName)
                    & python $diffTool $beforeResolved $_.FullName --out $diffOut --report $diffReport 2>&1 | ForEach-Object { Write-Host $_ }
                }
            } else {
                Write-Host "Warning: -BeforeShot given but no screenshots were copied; nothing to diff."
            }
        } else {
            Write-Host "Warning: diff tool not found at $diffTool"
        }
    }

    Write-Host "Report copied: $ReportCopy"
    Write-Host "`n=== SELF-TEST REPORT ==="
    Get-Content $ReportOut
    exit 0
} else {
    Write-Host "FAIL: no report produced (driver never finished)"
    exit 2
}

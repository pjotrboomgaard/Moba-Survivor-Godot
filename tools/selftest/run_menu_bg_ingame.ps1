# In-game verify for the T3.97 animated menu backgrounds (Tobor + Diord).
# A marker file (user://menu_bg_ingame_test) tells bootstrap.gd to attach the
# MenuBgIngame driver, which selects tobor (static + animated) and warden
# (animated) and captures the rendered menu.
#
# usage: powershell -ExecutionPolicy Bypass -File tools/selftest/run_menu_bg_ingame.ps1

$ProjectRoot = "C:\Users\pjotr\Documents\Development\Coop-MOBA-Survivor-Godot-Phase-1"
$GodotExe = "C:\Users\pjotr\Tools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
$UserDataDir = Join-Path $env:APPDATA "Godot\app_userdata\Rift Survivors"
if (-not (Test-Path $UserDataDir)) { New-Item -ItemType Directory -Path $UserDataDir -Force | Out-Null }
$ReportOut = Join-Path $UserDataDir "selftest_report.json"
$MarkerFile = Join-Path $UserDataDir "menu_bg_ingame_test"
$ResultsDir = Join-Path $ProjectRoot "tools\selftest\results"

if (Test-Path $ReportOut) { Remove-Item $ReportOut -Force }
# Create marker file so bootstrap.gd attaches the menu-bg driver.
Set-Content -Path $MarkerFile -Value "1"
Write-Host "Launching bootstrap scene (menu-bg driver via marker file) ..."

$godotArgs = @("--path", $ProjectRoot)
$proc = Start-Process -FilePath $GodotExe -ArgumentList $godotArgs -NoNewWindow -PassThru
$proc.WaitForExit()
# Clean up marker regardless.
Remove-Item $MarkerFile -Force -ErrorAction SilentlyContinue

$reportFound = $false
for ($i = 0; $i -lt 15; $i++) {
    if (Test-Path $ReportOut) { $reportFound = $true; break }
    Start-Sleep -Milliseconds 500
}
if (-not $reportFound) {
    Write-Host "FAIL: no report produced"
    exit 2
}

$baseName = "menu_bg_ingame"
$ReportCopy = Join-Path $ResultsDir ($baseName + "_report.json")
Copy-Item $ReportOut $ReportCopy -Force
$reportText = Get-Content $ReportOut -Raw
$shotsDir = Join-Path $ResultsDir $baseName
if ($reportText -match '"path"\s*:\s*"([^"]+\.png)"') {
    $allMatches = [regex]::Matches($reportText, '"path"\s*:\s*"([^"]+\.png)"')
    if ($allMatches.Count -gt 0) {
        if (-not (Test-Path $shotsDir)) { New-Item -ItemType Directory -Path $shotsDir -Force | Out-Null }
        foreach ($m in $allMatches) {
            $src = $m.Groups[1].Value
            if ($src.StartsWith("user://")) {
                $src = Join-Path $UserDataDir ($src.Substring(7))
            }
            if (Test-Path $src) {
                Copy-Item $src (Join-Path $shotsDir ([IO.Path]::GetFileName($src))) -Force
            }
        }
        Write-Host ("Screenshots dir: " + $shotsDir)
    }
}
Write-Host "Report copied: $ReportCopy"
Write-Host "`n=== SELF-TEST REPORT ==="
Get-Content $ReportOut
exit 0

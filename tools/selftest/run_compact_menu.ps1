param([string]$Label = "compact_menu_after", [switch]$Before)

$ProjectRoot = "C:\Users\pjotr\Documents\Development\Coop-MOBA-Survivor-Godot-Phase-1"
$GodotExe = "C:\Users\pjotr\Tools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
$UserDataDir = Join-Path $env:APPDATA "Godot\app_userdata\Rift Survivors"
if (-not (Test-Path $UserDataDir)) { New-Item -ItemType Directory -Path $UserDataDir -Force | Out-Null }
$ReportOut = Join-Path $UserDataDir "selftest_report.json"
$MarkerFile = Join-Path $UserDataDir "compact_menu_test"
$BeforeMarker = Join-Path $UserDataDir "compact_menu_before"
$ResultsDir = Join-Path $ProjectRoot "tools\selftest\results"

if (Test-Path $ReportOut) { Remove-Item $ReportOut -Force }
Set-Content -Path $MarkerFile -Value "1"
if ($Before) {
    Set-Content -Path $BeforeMarker -Value "1"
    Write-Host "BEFORE mode: applying pre-roster layout"
} else {
    Remove-Item $BeforeMarker -Force -ErrorAction SilentlyContinue
}
Write-Host "Launching bootstrap scene (compact-menu driver via marker) - label: $Label ..."

$godotArgs = @("--path", $ProjectRoot)
$proc = Start-Process -FilePath $GodotExe -ArgumentList $godotArgs -NoNewWindow -PassThru
$proc.WaitForExit()
Remove-Item $MarkerFile -Force -ErrorAction SilentlyContinue
Remove-Item $BeforeMarker -Force -ErrorAction SilentlyContinue

$reportFound = $false
for ($i = 0; $i -lt 20; $i++) {
    if (Test-Path $ReportOut) { $reportFound = $true; break }
    Start-Sleep -Milliseconds 500
}
if (-not $reportFound) {
    Write-Host "FAIL: no report produced"
    exit 2
}

$ReportCopy = Join-Path $ResultsDir ($Label + "_report.json")
Copy-Item $ReportOut $ReportCopy -Force
$reportText = Get-Content $ReportOut -Raw
$shotsDir = Join-Path $ResultsDir $Label
$rx = [regex]::new("user://[A-Za-z0-9_./-]+png")
$allMatches = $rx.Matches($reportText)
if ($allMatches.Count -gt 0) {
    if (-not (Test-Path $shotsDir)) { New-Item -ItemType Directory -Path $shotsDir -Force | Out-Null }
    foreach ($m in $allMatches) {
        $src = Join-Path $UserDataDir ($m.Value.Substring(7))
        if (Test-Path $src) {
            Copy-Item $src (Join-Path $shotsDir ([IO.Path]::GetFileName($src))) -Force
        }
    }
    Write-Host "Screenshots dir: $shotsDir"
}
Write-Host "Report copied: $ReportCopy"
Write-Host "=== SELF-TEST REPORT ==="
Get-Content $ReportOut
exit 0

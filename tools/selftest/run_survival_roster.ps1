param(
    [string[]]$Heroes = @(
        "tobor", "arclight", "bulwark", "warden",
        "cinder", "pyra", "slag", "ember",
        "thorn", "willow", "stump", "sage",
        "volt", "nebula", "astral", "rime"
    )
)

# Runs solo_survival for each hero so any agent can prove clutch difficulty
# (almost die, save with abilities + heal landmark). Summarizes verdicts at the end.
# usage: powershell -ExecutionPolicy Bypass -File tools/selftest/run_survival_roster.ps1
#        powershell -ExecutionPolicy Bypass -File tools/selftest/run_survival_roster.ps1 -Heroes tobor,ember,bulwark

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $PSCommandPath
$runner = Join-Path $here "run_selftest.ps1"
$request = Join-Path $here "requests\solo_survival.json"
$summary = @()

Get-Process -Name "Godot*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

foreach ($hero in $Heroes) {
    Write-Host "`n======== SURVIVAL $hero ========"
    & powershell -ExecutionPolicy Bypass -File $runner -RequestPath $request -Hero $hero
    $code = $LASTEXITCODE
    $report = Join-Path $here "results\solo_survival_$hero`_report.json"
    $verdict = "NO_REPORT"
    $minHp = ""
    $saves = ""
    $casts = ""
    if (Test-Path $report) {
        $json = Get-Content $report -Raw | ConvertFrom-Json
        $verdict = [string]$json.results.verdict
        $minHp = [string]$json.results.min_hp
        $saves = [string]$json.results.landmark_saves
        $casts = [string]$json.results.cast_count
    }
    $summary += [pscustomobject]@{
        hero = $hero
        verdict = $verdict
        min_hp = $minHp
        saves = $saves
        casts = $casts
        exit = $code
    }
    Get-Process -Name "Godot*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

Write-Host "`n======== ROSTER SUMMARY ========"
$summary | Format-Table -AutoSize
$fail = @($summary | Where-Object { $_.verdict -notmatch '^(PASS_CLUTCH|WARN_NEAR_DEATH)$' }).Count
Write-Host ("clutch_ok={0}/{1}" -f ($summary.Count - $fail), $summary.Count)
if ($fail -gt 0) { exit 1 } else { exit 0 }

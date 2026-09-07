param(
    [string[]]$Heroes = @(
        "tobor", "arclight", "bulwark", "warden",
        "cinder", "pyra", "slag", "ember",
        "thorn", "willow", "stump", "sage",
        "volt", "nebula", "astral", "rime"
    )
)

# Runs four-bot FFA for each hero so we can see whether the kit holds up vs lobby robots.
# usage: powershell -ExecutionPolicy Bypass -File tools/selftest/run_ffa_roster.ps1
#        powershell -ExecutionPolicy Bypass -File tools/selftest/run_ffa_roster.ps1 -Heroes tobor,ember,bulwark

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $PSCommandPath
$runner = Join-Path $here "run_selftest.ps1"
$request = Join-Path $here "requests\ffa_hero.json"
$summary = @()

Get-Process -Name "Godot*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

foreach ($hero in $Heroes) {
    Write-Host "`n======== FFA $hero ========"
    & $runner -RequestPath $request -Hero $hero -ExtraUserArgs '--ffa','--ffa-bots'
    $code = $LASTEXITCODE
    $report = Join-Path $here "results\ffa_hero_$hero`_report.json"
    $verdict = "NO_REPORT"
    $kills = ""
    $gold = ""
    $casts = ""
    $alive = ""
    $minHp = ""
    $classId = ""
    $roster = ""
    if (Test-Path $report) {
        $json = Get-Content $report -Raw | ConvertFrom-Json
        $verdict = [string]$json.results.verdict
        $kills = [string]$json.results.hero_kills
        $gold = [string]$json.results.gold
        $casts = [string]$json.results.cast_count
        $alive = [string]$json.results.alive
        $minHp = [string]$json.results.min_hp
        $classId = [string]$json.player_class
        if ($json.results.ffa) {
            $roster = [string]$json.results.ffa.count
        }
    }
    $summary += [pscustomobject]@{
        hero = $hero
        class = $classId
        verdict = $verdict
        kills = $kills
        gold = $gold
        casts = $casts
        alive = $alive
        min_hp = $minHp
        roster = $roster
        exit = $code
    }
    Get-Process -Name "Godot*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

Write-Host "`n======== FFA ROSTER SUMMARY ========"
$summary | Format-Table -AutoSize
$fail = @($summary | Where-Object { $_.verdict -notmatch '^(PASS_OK|PASS_KILLS|WARN_DEAD|WARN_QUIET)$' }).Count
$pass = @($summary | Where-Object { $_.verdict -match '^(PASS_OK|PASS_KILLS)$' }).Count
Write-Host ("ffa_ok={0}/{1}  fail={2}" -f $pass, $summary.Count, $fail)
$summary | ConvertTo-Json | Set-Content -Path (Join-Path $here "results\ffa_roster_summary.json") -Encoding utf8
if ($fail -gt 0) { exit 1 } else { exit 0 }

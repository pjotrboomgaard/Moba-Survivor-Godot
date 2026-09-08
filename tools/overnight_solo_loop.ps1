param(
    [int]$Cycles = 4,
    [int]$HeroRunsPerCycle = 4
)

$ErrorActionPreference = "Continue"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Runner = Join-Path $ProjectRoot "tools\selftest\run_selftest.ps1"
$ResultsDir = Join-Path $ProjectRoot "tools\selftest\results"
$ProgressPath = Join-Path $ResultsDir "overnight_solo_progress.json"
if (-not (Test-Path $ResultsDir)) {
    New-Item -ItemType Directory -Path $ResultsDir -Force | Out-Null
}

$heroes = @("tobor", "arclight", "bulwark", "warden", "cinder", "thorn", "volt", "rime")
$runs = @()

function Write-Progress {
    param($Status)
    $payload = [PSCustomObject]@{
        ts = [DateTime]::UtcNow.ToString("o")
        status = $Status
        completed = $runs.Count
        failures = @($runs | Where-Object { $_.verdict -notmatch "PASS|WARN" }).Count
    }
    $payload | ConvertTo-Json | Set-Content -Path $ProgressPath
}

for ($cycle = 1; $cycle -le $Cycles; $cycle++) {
    for ($i = 0; $i -lt $HeroRunsPerCycle -and $i -lt $heroes.Count; $i++) {
        $hero = $heroes[($cycle + $i) % $heroes.Count]
        $report = Join-Path $ResultsDir "solo_survival_${hero}_report.json"
        Write-Host ("[overnight] cycle {0} hero {1}" -f $cycle, $hero)
        $started = Get-Date
        & powershell -ExecutionPolicy Bypass -File $Runner -RequestPath (Join-Path $ProjectRoot "tools\selftest\requests\solo_survival.json") -Hero $hero
        $exitCode = $LASTEXITCODE
        $elapsed = [int]((Get-Date) - $started).TotalSeconds
        $verdict = "NO_REPORT"
        $beaten = -1
        $minHp = ""
        $saves = ""
        $casts = ""
        $buys = ""
        $level = ""
        if (Test-Path $report) {
            $json = Get-Content $report -Raw | ConvertFrom-Json
            $verdict = [string]$json.results.verdict
            $beaten = [int]$json.results.beaten_wave
            $minHp = [string]$json.results.min_hp
            $saves = [string]$json.results.landmark_saves
            $casts = [string]$json.results.cast_count
            $buys = [string]$json.results.shop_buy_count
            $level = [string]$json.results.level
        }
        $runs += [PSCustomObject]@{
            cycle = $cycle
            hero = $hero
            verdict = $verdict
            beaten_wave = $beaten
            min_hp = $minHp
            landmark_saves = $saves
            casts = $casts
            shop_buys = $buys
            level = $level
            exit_code = $exitCode
            elapsed_seconds = $elapsed
        }
        Write-Progress "cycle=$cycle hero=$hero verdict=$verdict exit=$exitCode"
        Get-Process -Name "Godot*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
}

$summary = [PSCustomObject]@{
    ts = [DateTime]::UtcNow.ToString("o")
    total = $runs.Count
    pass = @($runs | Where-Object { $_.verdict -match "PASS" }).Count
    warn = @($runs | Where-Object { $_.verdict -match "WARN" }).Count
    failures = @($runs | Where-Object { $_.verdict -notmatch "PASS|WARN" }).Count
    longest_seconds = @($runs | Measure-Object -Property elapsed_seconds -Maximum | Select-Object -ExpandProperty Maximum)
    entries = $runs
}
$summary | ConvertTo-Json -Depth 4 | Set-Content -Path $ProgressPath
$runs | Format-Table -AutoSize
Write-Host ("[overnight] done pass={0} warn={1} fail={2} total={3}" -f $summary.pass, $summary.warn, $summary.failures, $summary.total)
exit $summary.failures

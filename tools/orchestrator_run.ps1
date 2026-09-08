# Orchestrator: runs the UI-verify harness, a short solo-survival selftest,
# and the asset_compare / asset_pipeline tools, writes a summary JSON, and
# prints a PASS/FAIL table.
#
# Usage:  powershell -ExecutionPolicy Bypass -File tools\orchestrator_run.ps1
#
param(
    [string]$GodotExe = "C:\Users\pjotr\Tools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe",
    [int]$SurvivalDurationSec = 45
)

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ResultsDir  = Join-Path $ProjectRoot "tools\selftest\results"
if (-not (Test-Path $ResultsDir)) { New-Item -ItemType Directory -Path $ResultsDir -Force | Out-Null }

$global:OrchChecks = @()

function Run-Check {
    param([string]$Name, [scriptblock]$Block)
    Write-Host ""
    Write-Host ">>> $Name" -ForegroundColor Cyan
    & $Block
    $exit = $LASTEXITCODE
    $global:OrchChecks += @{ name = $Name; exit_code = $exit; passed = ($exit -eq 0) }
    if ($exit -eq 0) {
        Write-Host "    PASS" -ForegroundColor Green
    } else {
        Write-Host "    FAIL (exit $exit)" -ForegroundColor Red
    }
}

# ---------------------------------------------------------------------------
# 1. UI verify (world editor test)
# ---------------------------------------------------------------------------
Run-Check "ui_verify" {
    & powershell -ExecutionPolicy Bypass -File (Join-Path $ProjectRoot "tools\selftest\run_ui_verify.ps1")
}

# ---------------------------------------------------------------------------
# 2. Self-test (solo survival with a short duration)
# ---------------------------------------------------------------------------
Run-Check "selftest_solo_survival" {
    $stScript = Join-Path $ProjectRoot "tools\selftest\run_selftest.ps1"
    $reqJson  = Join-Path $ProjectRoot "tools\selftest\requests\solo_survival.json"
    if (-not (Test-Path $stScript) -or -not (Test-Path $reqJson)) {
        Write-Warning "run_selftest.ps1 or solo_survival.json not found"
        exit 1
    }
    $raw = [System.IO.File]::ReadAllText($reqJson)
    $raw = [regex]::Replace($raw, '"duration"\s*:\s*\d+', ('"duration": ' + $SurvivalDurationSec))
    $stReq = Join-Path $ResultsDir "orchestrator_survival.json"
    [System.IO.File]::WriteAllText($stReq, $raw)
    & powershell -ExecutionPolicy Bypass -File $stScript -RequestPath $stReq
}

# ---------------------------------------------------------------------------
# 3. asset_compare (known-good pair: a sprite vs itself -> should score ~1.0)
#    Positional args only: <source> <game_asset> [threshold] [tolerance]
# ---------------------------------------------------------------------------
Run-Check "asset_compare_known_good" {
    $testSprite = Join-Path $ProjectRoot "assets\sprites\tree_oak.png"
    if (-not (Test-Path $testSprite)) {
        Write-Warning "tree_oak.png not found"
        exit 1
    }
    $resolved = (Resolve-Path $testSprite).Path
    & $GodotExe --headless --path $ProjectRoot --script res://tools/asset_compare.gd `
        -- $resolved $resolved 0.99
}

# ---------------------------------------------------------------------------
# 4. asset_pipeline (downscale + quantize tree_oak to 16x16 / 8 colors)
#    Positional args only: <input_png> <output_png> [target_size] [palette_size]
# ---------------------------------------------------------------------------
Run-Check "asset_pipeline" {
    $testSprite = Join-Path $ProjectRoot "assets\sprites\tree_oak.png"
    $outPath = Join-Path $ResultsDir "pipeline_tree_oak.png"
    if (-not (Test-Path $testSprite)) {
        Write-Warning "tree_oak.png not found"
        exit 1
    }
    $resolved = (Resolve-Path $testSprite).Path
    & $GodotExe --headless --path $ProjectRoot --script res://tools/asset_pipeline.gd `
        -- $resolved $outPath 16 8
}

# ---------------------------------------------------------------------------
# 5. Parse-check both tool scripts
# ---------------------------------------------------------------------------
Run-Check "parse_asset_compare" {
    & $GodotExe --headless --path $ProjectRoot --check-only --script res://tools/asset_compare.gd
}

Run-Check "parse_asset_pipeline" {
    & $GodotExe --headless --path $ProjectRoot --check-only --script res://tools/asset_pipeline.gd
}

# ---------------------------------------------------------------------------
# 6. Summary JSON
# ---------------------------------------------------------------------------
$allPassed = -not ($global:OrchChecks | Where-Object { -not $_.passed })
$checksArr = @($global:OrchChecks | ForEach-Object { [pscustomobject]@{ name = $_.name; exit_code = $_.exit_code; passed = $_.passed } })
$summary = [pscustomobject]@{
    timestamp  = (Get-Date).ToString("o")
    project    = $ProjectRoot
    all_passed = $allPassed
    checks     = $checksArr
}
$summaryPath = Join-Path $ResultsDir "orchestrator_summary.json"
$summary | ConvertTo-Json -Depth 5 | Set-Content -Path $summaryPath -Encoding utf8
Write-Host ""
Write-Host "Summary -> $summaryPath"

# ---------------------------------------------------------------------------
# 7. PASS/FAIL table
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "========================================" -NoNewline
Write-Host "  ORCHESTRATOR RESULTS" -NoNewline
Write-Host "  ========================================"
Write-Host ("  {0,-30} {1,-8} {2}" -f "Check", "Status", "Exit")
Write-Host "  ----------------------------------------"
foreach ($c in $global:OrchChecks) {
    $status = if ($c.passed) { "PASS" } else { "FAIL" }
    $color  = if ($c.passed) { "Green" } else { "Red" }
    Write-Host ("  {0,-30} {1,-8} {2}" -f $c.name, $status, $c.exit_code) -ForegroundColor $color
}
Write-Host "  ========================================"

if ($allPassed) {
    Write-Host ""
    Write-Host "ALL CHECKS PASSED" -ForegroundColor Green
    exit 0
} else {
    Write-Host ""
    Write-Host "ONE OR MORE CHECKS FAILED" -ForegroundColor Red
    exit 1
}

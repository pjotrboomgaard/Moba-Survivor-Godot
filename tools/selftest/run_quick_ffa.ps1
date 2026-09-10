param(
  [string[]]$Heroes
)

$root = Split-Path -Parent $PSScriptRoot
$godot = "C:\Users\pjotr\Tools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
$pass = 0
$fail = 0

if (-not $Heroes) { $Heroes = @("arclight","cinder","thorn","volt") }

foreach ($h in $Heroes) {
  $req = [ordered]@{
    hero = $h
    mode = "ffa"
    events = @(
      [ordered]@{ t = 1.0;  kind = "landmarks"; label = "ffa_landmarks" },
      [ordered]@{ t = 1.2;  kind = "probe";     label = "ffa_start" },
      [ordered]@{ t = 24.0; kind = "probe";     label = "ffa_mid" },
      [ordered]@{ t = 47.5; kind = "probe";     label = "ffa_end" },
      [ordered]@{ t = 48.0; kind = "report" }
    )
  }
  $req | ConvertTo-Json | Set-Content -Encoding UTF8 "tools/selftest/requests/ffa_${h}.json"
  Write-Host "Running $h..."
  Push-Location $root
  $out = & $godot --headless -path . -f "res://tools/selftest/run_selftest.gd" `
        --request="res://tools/selftest/requests/ffa_${h}.json" `
        --report-out="res://tools/selftest/results/ffa_${h}.json" 2>&1
  Pop-Location
  $rep = $out | Select-String -Pattern "verdict=" | Select-Object -First 1
  $r = $rep.Line
  Write-Host ("  {0} " -f $h) -NoNewline; Write-Host $r
  if ($r -match "PASS") { $pass++ } else { $fail++ }
}

Write-Host "=== $pass/$($Heroes.Count) PASS ==="

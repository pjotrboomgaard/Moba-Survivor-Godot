$log = Join-Path $env:APPDATA 'Godot\app_userdata\Rift Survivors\logs\godot.log'
$lines = Get-Content $log
$n = $lines.Count
Write-Output ("total lines: " + $n)
$patterns = @('Parse Error', 'selftest_report', 'report ->', 'focus_tree', '_draw_baked', '_build_baked', 'Arena', 'SCRIPT ERROR')
# Find first occurrence of SCRIPT ERROR and parse errors from start (log is appended per run; find most recent session)
# Locate the last "=== GAME LOG ===" style start: instead just scan for the most recent 'focus_tree'
for ($i = $n-1; $i -ge 0; $i--) {
  if ($lines[$i] -match 'focus_tree') {
    Write-Output ("last focus_tree at line " + $i + ": " + $lines[$i])
  }
}
# Show lines containing focus_tree or baked_tree
$ft = @()
for ($i = 0; $i -lt $n; $i++) {
  if ($lines[$i] -match 'focus_tree|baked_tree_shadow') { $ft += ("[{0}] {1}" -f $i, $lines[$i]) }
}
Write-Output ("focus/baked entries: " + $ft.Count)
$ft | ForEach-Object { Write-Output $_ }

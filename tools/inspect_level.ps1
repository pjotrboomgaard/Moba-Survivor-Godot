$f = Join-Path $env:USERPROFILE 'AppData\Godot\app_userdata\Rift Survivors\world_editor_level.json'
if (-not (Test-Path $f)) { Write-Output "no level file at $f"; exit 1 }
$j = Get-Content $f -Raw | ConvertFrom-Json
Write-Output ("biome: " + $j.biome)
$ob = $j.obstacles
Write-Output ("total obstacles: " + $ob.Count)
$ob | Group-Object sprite | Sort-Object Count -Descending | ForEach-Object { Write-Output ("  " + $_.Name + "  x" + $_.Count) }
# Grass/flower bounds
Write-Output "--- grass/flower position bounds ---"
$g = $ob | Where-Object { $_.sprite -match "grass|flower|dirt" }
if ($g) {
  $xs = @($g | ForEach-Object { [int]$_.pos[0] })
  $ys = @($g | ForEach-Object { [int]$_.pos[1] })
  Write-Output ("  count=" + $g.Count + " xmin=" + ($xs | Measure-Object -Minimum).Minimum + " xmax=" + ($xs | Measure-Object -Maximum).Maximum + " ymin=" + ($ys | Measure-Object -Minimum).Minimum + " ymax=" + ($ys | Measure-Object -Maximum).Maximum)
} else {
  Write-Output "  (none)"
}

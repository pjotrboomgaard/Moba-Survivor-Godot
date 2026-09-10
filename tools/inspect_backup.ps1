$f = Join-Path $env:USERPROFILE 'AppData\Godot\app_userdata\Rift Survivors\world_editor_level_grass_backup.json'
$j = Get-Content $f -Raw | ConvertFrom-Json
Write-Output ("biome: " + $j.biome)
$ob = $j.obstacles
Write-Output ("total obstacles: " + $ob.Count)
$ob | Group-Object sprite | Sort-Object Count -Descending | ForEach-Object { Write-Output ("  " + $_.Name + "  x" + $_.Count) }
$g = $ob | Where-Object { $_.sprite -match "grass|flower|dirt" }
if ($g) {
  $xs = @($g | ForEach-Object { [int]$_.pos[0] })
  $ys = @($g | ForEach-Object { [int]$_.pos[1] })
  Write-Output ("grass count=" + $g.Count + " x[" + ($xs|Measure-Object -Minimum).Minimum + ".." + ($xs|Measure-Object -Maximum).Maximum + "] y[" + ($ys|Measure-Object -Minimum).Minimum + ".." + ($ys|Measure-Object -Maximum).Maximum + "]")
} else { Write-Output "no grass" }

$f = Join-Path $env:USERPROFILE 'AppData\Godot\app_userdata\Rift Survivors\world_editor_level.json'
if (-not (Test-Path $f)) { Write-Output "no level file at $f"; exit 1 }
$j = Get-Content $f -Raw | ConvertFrom-Json
Write-Output ("biome: " + $j.biome)
$ob = $j.obstacles
Write-Output ("total obstacles: " + $ob.Count)
$ob | Group-Object sprite | Sort-Object Count -Descending |
  ForEach-Object { Write-Output ("  " + $_.Name + "  x" + $_.Count) }
Write-Output "--- tree positions ---"
$ob | Where-Object { $_.sprite -like "tree_*" } | ForEach-Object {
  Write-Output ("  " + $_.sprite + " @ (" + $_.pos[0] + "," + $_.pos[1] + ")")
}

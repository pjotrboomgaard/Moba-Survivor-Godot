Add-Type -AssemblyName System.Drawing
$png = Get-ChildItem "tools\selftest\results\ui_verify\ability_preview_nuke_*.png" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$wic = New-Object System.Drawing.Bitmap($png.FullName)
# Sample the preview region corner and center
# preview region approx rect(40,482,363,542) -> in a 1280x720 image
$pts = @( @(45,485), @(45,540), @(390,485), @(390,540), @(220,510) )
foreach ($p in $pts) {
  $px = $wic.GetPixel($p[0], $p[1])
  Write-Output ("({0},{1}) = R{2} G{3} B{4} A{5}" -f $p[0], $p[1], $px.R, $px.G, $px.B, $px.A)
}
$wic.Dispose()

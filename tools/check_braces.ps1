$files = @(
    "C:\Users\pjotr\Documents\Development\Coop-MOBA-Survivor-Godot-Phase-1\scripts\kit_fx_library.gd",
    "C:\Users\pjotr\Documents\Development\Coop-MOBA-Survivor-Godot-Phase-1\scripts\main.gd",
    "C:\Users\pjotr\Documents\Development\Coop-MOBA-Survivor-Godot-Phase-1\scripts\player.gd",
    "C:\Users\pjotr\Documents\Development\Coop-MOBA-Survivor-Godot-Phase-1\scripts\lightning_effect.gd",
    "C:\Users\pjotr\Documents\Development\Coop-MOBA-Survivor-Godot-Phase-1\scripts\player_class.gd"
)
$allOk = $true
foreach ($f in $files) {
    $content = Get-Content -Raw -Path $f
    $open = ($content.ToCharArray() | Where-Object { $_ -eq '{' }).Count
    $close = ($content.ToCharArray() | Where-Object { $_ -eq '}' }).Count
    $name = [System.IO.Path]::GetFileName($f)
    if ($open -ne $close) {
        Write-Host "MISMATCH: $name open=$open close=$close"
        $allOk = $false
    } else {
        Write-Host "OK: $name open=$open"
    }
}
if ($allOk) { Write-Host "ALL OK"; exit 0 } else { exit 1 }

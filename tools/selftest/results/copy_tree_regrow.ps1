$src = 'C:\Users\pjotr\AppData\Roaming\Godot\app_userdata\Rift Survivors'
$dst = 'C:\Users\pjotr\Documents\Development\Coop-MOBA-Survivor-Godot-Phase-1\tools\selftest\results\tree_regrow_iso'
New-Item -ItemType Directory -Path $dst -Force | Out-Null
$files = @('selftest_stump_only.png','selftest_just_started_morph.png','selftest_morph_30pct.png','selftest_morph_60pct.png','selftest_morph_complete_replanted.png')
foreach ($f in $files) {
    $s = Join-Path $src $f
    $d = Join-Path $dst $f
    if (Test-Path $s) {
        Copy-Item -LiteralPath $s -Destination $d -Force
        Write-Host "copied $f"
    } else {
        Write-Host "missing $f"
    }
}

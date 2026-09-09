$path = "c:\Users\pjotr\Documents\Development\Coop-MOBA-Survivor-Godot-Phase-1\tools\tobor_world_art.gd"
$lines = [System.IO.File]::ReadAllLines($path)

function Fix-Rows($start, $end, $targetWidth, $label) {
    for ($i = $start + 1; $i -lt $end; $i++) {
        $line = $lines[$i]
        # Match lines that are array elements: optional whitespace, quote, content, quote, optional comma
        if ($line -match '^(\s*)"(.*)"(,?)\s*$') {
            $indent = $Matches[1]
            $content = $Matches[2]
            $hasComma = $Matches[3]
            if ($content.Length -ne $targetWidth) {
                $padded = $content.PadRight($targetWidth, '.')
                $comma = if ($hasComma -eq ',') { ',' } else { '' }
                $lines[$i] = $indent + '"' + $padded + '"' + $comma
                Write-Host "Fixed $label line $($i+1): $($content.Length) -> $targetWidth, comma='$($hasComma)'"
            }
        }
    }
}

function Find-Array($name) {
    $start = -1; $end = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match ('_' + $name + '_ROWS\s*:=')) { $start = $i; continue }
        if ($start -ge 0 -and $lines[$i] -match '^\s*\]' -and $end -lt 0) { $end = $i; break }
    }
    return @($start, $end)
}

# House: 32 rows, 32 wide
$r = Find-Array "HOUSE"
$rc = $r[1] - $r[0] - 1
Write-Host "HOUSE: rows=$rc target=$rc"
Fix-Rows $r[0] $r[1] $rc "house"

# Shop: 36 rows, 36 wide
$r = Find-Array "SHOP"
$rc = $r[1] - $r[0] - 1
Write-Host "SHOP: rows=$rc target=$rc"
Fix-Rows $r[0] $r[1] $rc "shop"

# Church: 40 rows, 40 wide
$r = Find-Array "CHURCH"
$rc = $r[1] - $r[0] - 1
Write-Host "CHURCH: rows=$rc target=$rc"
Fix-Rows $r[0] $r[1] $rc "church"

# Well: 28 rows, 28 wide
$r = Find-Array "WELL"
$rc = $r[1] - $r[0] - 1
Write-Host "WELL: rows=$rc target=$rc"
Fix-Rows $r[0] $r[1] $rc "well"

[System.IO.File]::WriteAllLines($path, $lines)
Write-Host "Done."

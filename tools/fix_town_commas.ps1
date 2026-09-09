$path = "c:\Users\pjotr\Documents\Development\Coop-MOBA-Survivor-Godot-Phase-1\tools\tobor_world_art.gd"
$lines = [System.IO.File]::ReadAllLines($path)

function Add-Commas($start, $end, $label) {
    $fixed = 0
    for ($i = $start + 1; $i -lt $end; $i++) {
        $line = $lines[$i]
        # If the line ends with a quote but not a comma, add a comma
        if ($line -match '^\s*"[^"]*"\s*$') {
            $lines[$i] = $line + ","
            $fixed++
        }
    }
    Write-Host "Fixed ${label} - added ${fixed} commas"
}

function Find-Array($name) {
    $start = -1; $end = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match ('_' + $name + '_ROWS\s*:=')) { $start = $i; continue }
        if ($start -ge 0 -and $lines[$i] -match '^\s*\]' -and $end -lt 0) { $end = $i; break }
    }
    return @($start, $end)
}

# Fix church commas
$r = Find-Array "CHURCH"
Add-Commas $r[0] $r[1] "church"

# Fix well commas
$r = Find-Array "WELL"
Add-Commas $r[0] $r[1] "well"

# Fix house commas (check if needed)
$r = Find-Array "HOUSE"
Add-Commas $r[0] $r[1] "house"

# Fix shop commas (check if needed)
$r = Find-Array "SHOP"
Add-Commas $r[0] $r[1] "shop"

[System.IO.File]::WriteAllLines($path, $lines)
Write-Host "Done."

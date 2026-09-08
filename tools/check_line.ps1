$bytes = [System.IO.File]::ReadAllBytes('scripts/side_quest.gd')
$text = [System.Text.Encoding]::UTF8.GetString($bytes)
$lines = $text -split "`n"
for ($i = 440; $i -lt 450; $i++) {
    Write-Output ("Line " + ($i+1) + ": [" + $lines[$i] + "]")
}

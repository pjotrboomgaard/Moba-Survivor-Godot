$log = Join-Path $env:APPDATA 'Godot\app_userdata\Rift Survivors\logs\godot.log'
Select-String -Path $log -Pattern 'Parse Error|Failed to load script' | Select-Object -First 10 | ForEach-Object {
    Write-Output ($_.LineNumber.ToString() + ': ' + $_.Line)
}

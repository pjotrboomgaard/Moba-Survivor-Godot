$log = Join-Path $env:APPDATA 'Godot\app_userdata\Rift Survivors\logs\godot.log'
Write-Output "=== LAST 60 LINES ==="
Get-Content $log -Tail 60

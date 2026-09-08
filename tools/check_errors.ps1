$log = Join-Path $env:APPDATA 'Godot\app_userdata\Rift Survivors\logs\godot.log'
Write-Output "=== ERROR LINES ==="
Select-String -Path $log -Pattern 'SCRIPT ERROR|Parse Error|Compile Error|Failed to load' | Select-Object -First 15 | ForEach-Object { Write-Output $_.Line }

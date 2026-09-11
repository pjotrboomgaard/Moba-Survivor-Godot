$log = "C:\Users\pjotr\AppData\Roaming\Godot\app_userdata\Rift Survivors\logs\godot.log"
Select-String -Path $log -Pattern "MINIGAME_DEBUG|could not load|Parse Error|SCRIPT ERROR|dance" | Select-Object -First 20 | ForEach-Object { Write-Host $_.Line }

$log = "C:\Users\pjotr\AppData\Roaming\Godot\app_userdata\Rift Survivors\logs\godot.log"
Select-String -Path $log -Pattern "MINIGAME_BASE|MINIGAME_AREA|DANCE_DISCO|MINIGAME_FORCE" | Select-Object -First 25 | ForEach-Object { Write-Host $_.Line }

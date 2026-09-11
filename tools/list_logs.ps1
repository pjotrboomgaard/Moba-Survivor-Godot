$dir = "C:\Users\pjotr\AppData\Roaming\Godot\app_userdata\Rift Survivors"
Get-ChildItem -Path $dir -Recurse -Filter "*.log" -ErrorAction SilentlyContinue | Select-Object FullName, LastWriteTime, Length

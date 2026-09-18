$src = 'C:\Users\pjotr\AppData\Roaming\Godot\app_userdata\Rift Survivors'
$dest = 'tools\selftest\results\mg_camp_wave_mix'
New-Item -ItemType Directory $dest -Force | Out-Null
Copy-Item ($src + '\selftest_selftest_run_9782\camp_roster_wave1_6.504_9782.png') ($dest + '\ingame_wave1.png') -Force
Copy-Item ($src + '\selftest_selftest_run_16776\camp_roster_wave3_13.507_16776.png') ($dest + '\ingame_wave3.png') -Force
Copy-Item ($src + '\selftest_selftest_run_26265\camp_roster_wave6_23.004_26265.png') ($dest + '\ingame_wave6.png') -Force
Get-ChildItem $dest | Select-Object Name

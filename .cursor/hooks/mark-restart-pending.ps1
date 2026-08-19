# Mark that the game should restart when the agent finishes.
$flagFile = Join-Path $PSScriptRoot ".restart_pending"
New-Item -Path $flagFile -ItemType File -Force | Out-Null
exit 0

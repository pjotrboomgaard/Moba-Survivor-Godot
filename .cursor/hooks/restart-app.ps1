# Restart Godot when the agent edited game files this session.
$inputJson = [Console]::In.ReadToEnd() | ConvertFrom-Json
$flagFile = Join-Path $PSScriptRoot ".restart_pending"

if (-not (Test-Path $flagFile)) {
	exit 0
}

Remove-Item $flagFile -Force -ErrorAction SilentlyContinue
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
& (Join-Path $repoRoot "tools/restart_app.ps1") -ProjectPath $repoRoot
exit 0

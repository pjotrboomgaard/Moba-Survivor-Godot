# Kill any Godot instance running this project, then relaunch it.
param(
	[string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
	[string]$GodotExe = "C:\Users\pjotr\Tools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe",
	[switch]$Pjotr,
	[switch]$Classic
)

if (-not (Test-Path $GodotExe)) {
	Write-Error "Godot executable not found: $GodotExe"
	exit 1
}

$projectPathNormalized = $ProjectPath.Replace("\", "/")

Get-CimInstance Win32_Process -Filter "Name = 'Godot_v4.7.2-stable_win64.exe'" -ErrorAction SilentlyContinue |
	Where-Object { $_.CommandLine -like "*$ProjectPath*" -or $_.CommandLine -like "*$projectPathNormalized*" } |
	ForEach-Object {
		Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
	}

Start-Sleep -Milliseconds 350

$args = @("--path", $ProjectPath)
if ($Pjotr) {
	$args += "--"
	$args += "--pjotr"
} elseif ($Classic) {
	$args += "--"
	$args += "--classic"
}

Start-Process -FilePath $GodotExe -ArgumentList $args | Out-Null
Write-Host "Restarted Godot for $ProjectPath"

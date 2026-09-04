# Kill any Godot instance running this project, then relaunch it.
param(
	[string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
	[string]$GodotExe = "C:\Users\pjotr\Tools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe",
	[switch]$Pjotr,
	[switch]$Classic,
	[switch]$ToborWorld,
	[switch]$Ffa,
	[switch]$FfaBots
)

if (-not (Test-Path $GodotExe)) {
	Write-Error "Godot executable not found: $GodotExe"
	exit 1
}

$projectPathNormalized = $ProjectPath.Replace("\", "/")
$explicitMode = $Pjotr -or $Classic -or $ToborWorld -or $Ffa -or $FfaBots
$launchFile = Join-Path $PSScriptRoot "..\.cursor\hooks\.last_launch"

$running = @(Get-CimInstance Win32_Process -Filter "Name = 'Godot_v4.7.2-stable_win64.exe'" -ErrorAction SilentlyContinue |
	Where-Object { $_.CommandLine -like "*$ProjectPath*" -or $_.CommandLine -like "*$projectPathNormalized*" })

function Set-LaunchModeFromText {
	param([string]$Text)
	if ($Text -match 'ffa-bots') { $script:FfaBots = $true; return }
	if ($Text -match 'ffa') { $script:Ffa = $true; return }
	if ($Text -match 'classic') { $script:Classic = $true; return }
	if ($Text -match 'toborworld' -or $Text -match 'pjotr') { $script:Pjotr = $true }
}

if (-not $explicitMode) {
	$inherited = $false
	foreach ($proc in $running) {
		$commandLine = [string]$proc.CommandLine
		if ($commandLine -match '--ffa|--classic|--pjotr|--toborworld') {
			Set-LaunchModeFromText $commandLine
			$inherited = $true
			break
		}
	}
	if (-not $inherited -and (Test-Path $launchFile)) {
		Set-LaunchModeFromText (Get-Content -Raw $launchFile)
	}
}

foreach ($proc in $running) {
	Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
}

Start-Sleep -Milliseconds 350

$godotArgs = @("--path", $ProjectPath)
$userArgs = @()
if ($FfaBots) {
	$userArgs = @("--ffa", "--ffa-bots")
} elseif ($Ffa) {
	$userArgs = @("--ffa")
} elseif ($Pjotr) {
	$userArgs = @("--pjotr")
} elseif ($Classic) {
	$userArgs = @("--classic")
} elseif ($ToborWorld) {
	$userArgs = @("--pjotr")
}
if ($userArgs.Count -gt 0) {
	$godotArgs += "--"
	$godotArgs += $userArgs
}

$argLine = ($godotArgs | ForEach-Object {
	if ($_ -match '\s') { '"{0}"' -f $_ } else { $_ }
}) -join ' '

$launchDir = Split-Path $launchFile -Parent
if (-not (Test-Path $launchDir)) {
	New-Item -ItemType Directory -Path $launchDir -Force | Out-Null
}
Set-Content -Path $launchFile -Value ($userArgs -join ' ') -NoNewline

Start-Process -FilePath $GodotExe -ArgumentList $argLine | Out-Null
Write-Host "Restarted Godot for $ProjectPath $($userArgs -join ' ')"

<#
.SYNOPSIS
    Restore a world-editor map file from its git-tracked backup into the live
    user:// directory, so you can "go back" to a known-good map layout.

.DESCRIPTION
    The maps under assets/maps/ are version-controlled snapshots of the maps that
    live in %APPDATA%\Godot\app_userdata\Rift Survivors. This tool copies a chosen
    (or the current) backup back over the live file. By default it restores the
    grass_real map from its dated backup. Pass -Map to target another map.

.PARAMETER Map
    Which map to restore. Defaults to "grass_real". Valid values match the map
    stems used in the world editor (grass_real, default, volcano, ice, factory,
    docks).

.PARAMETER BackupDate
    Optional MMDDYYYY backup suffix to pull from (e.g. 20260912). Omit to use the
    plain latest copy of the map.

.PARAMETER DryRun
    Show what would be copied without touching the live file.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools/restore_map.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools/restore_map.ps1 -Map volcano

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools/restore_map.ps1 -Map grass_real -BackupDate 20260912 -DryRun
#>
param(
    [string]$Map = "grass_real",
    [string]$BackupDate = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$repoMaps = Join-Path $projectRoot "assets\maps"
$userDir = Join-Path $env:APPDATA "Godot\app_userdata\Rift Survivors"

if (-not (Test-Path $repoMaps)) {
    Write-Error "Repo maps dir not found: $repoMaps"
    exit 1
}
if (-not (Test-Path $userDir)) {
    Write-Error "User data dir not found: $userDir"
    exit 1
}

# Build the source backup filename.
$fileName = "world_editor_level_$Map.json"
if ($BackupDate -ne "") {
    $fileName = "world_editor_level_$Map_BACKUP_$BackupDate.json"
}
$src = Join-Path $repoMaps $fileName
$dst = Join-Path $userDir "world_editor_level_$Map.json"

if (-not (Test-Path $src)) {
    Write-Error "Backup not found: $src`nAvailable backups:"
    Get-ChildItem $repoMaps -Filter "world_editor_level_$Map*.json" |
        Select-Object -ExpandProperty Name | ForEach-Object { Write-Host "  $_" }
    exit 1
}

Write-Host "Restoring map '$Map':"
Write-Host "  from: $src"
Write-Host "  to:   $dst"

if ($DryRun) {
    Write-Host "[dry-run] no files copied."
    exit 0
}

Copy-Item $src $dst -Force
Write-Host "Done. Restart the game (or re-load the map in the world editor) to see the change."

<#
.SYNOPSIS
    Snapshot the current live world-editor maps into assets/maps/ (git-tracked).

.DESCRIPTION
    Copies every world_editor_level_*.json from the live user data dir into
    assets/maps/ so the current map layouts are preserved in git. Add
    -DateSuffix to also write a dated backup copy (e.g. ..._BACKUP_20260912.json).

.PARAMETER DateSuffix
    MMDDYYYY suffix to use for the dated backup copies. Defaults to today.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools/backup_maps.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools/backup_maps.ps1 -DateSuffix 20260912
#>
param(
    [string]$DateSuffix = (Get-Date -Format "yyyyMMdd")
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$repoMaps = Join-Path $projectRoot "assets\maps"
$userDir = Join-Path $env:APPDATA "Godot\app_userdata\Rift Survivors"

if (-not (Test-Path $repoMaps)) {
    New-Item -ItemType Directory -Path $repoMaps -Force | Out-Null
}
if (-not (Test-Path $userDir)) {
    Write-Error "User data dir not found: $userDir"
    exit 1
}

$liveMaps = Get-ChildItem $userDir -Filter "world_editor_level_*.json" -ErrorAction SilentlyContinue
if ($liveMaps.Count -eq 0) {
    Write-Warning "No world editor maps found in $userDir"
    exit 0
}

foreach ($m in $liveMaps) {
    # Plain copy (current state)
    Copy-Item $m.FullName (Join-Path $repoMaps $m.Name) -Force
    # Dated backup copy
    $stem = [IO.Path]::GetFileNameWithoutExtension($m.Name)
    $datedName = "${stem}_BACKUP_${DateSuffix}.json"
    Copy-Item $m.FullName (Join-Path $repoMaps $datedName) -Force
    Write-Host "Backed up: $($m.Name) -> $repoMaps\$m.Name and \$$datedName"
}

Write-Host ""
Write-Host "All maps backed up to assets/maps/ (git-tracked)."
Write-Host "To restore: powershell -ExecutionPolicy Bypass -File tools/restore_map.ps1 -Map <name>"

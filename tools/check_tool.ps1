# check_tool.ps1 — Interactive task checklist.
# Shows the task list with numbers. Type numbers to toggle done/not-done.
# "next" writes the unchecked items into NEXT_LIST.txt (the carried-forward list).
#
# Usage:  powershell -ExecutionPolicy Bypass -File tools/check_tool.ps1 [-File path/to/list.txt]
param(
    [string]$File = (Join-Path $PSScriptRoot "checklist\NEXT_LIST.txt")
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $File)) {
    Write-Host "No checklist found at: $File" -ForegroundColor Red
    exit 1
}

function Show-List($lines) {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Cyan
    $i = 1
    foreach ($ln in $lines) {
        if ($ln -match "^\s*$" -or $ln -match "^#") { continue }
        if ($ln -match "^\[x\]") {
            Write-Host ("  " + $i + ". [DONE]  " + ($ln -replace '^\[x\]\s*', '')) -ForegroundColor Green
        } elseif ($ln -match "^\[ \]") {
            Write-Host ("  " + $i + ". [     ] " + ($ln -replace '^\[ \]\s*', '')) -ForegroundColor Yellow
        } else {
            Write-Host ("  " + $i + ". [?]    " + $ln) -ForegroundColor White
        }
        $i++
    }
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host "Type: number(s) to toggle  |  'next' to write unchecked -> NEXT_LIST  |  'q' quit" -ForegroundColor DarkGray
}

$allLines = Get-Content $File
# Build a list of (indexInFile, originalLine) for toggleable lines only.
$toggleable = @()
$lineIdx = 0
foreach ($ln in $allLines) {
    if ($ln -match '^\[( |x)\]') {
        $toggleable += ,@($lineIdx, $ln)
    }
    $lineIdx++
}

while ($true) {
    Show-List $allLines
    $input_ = (Read-Host "Action").Trim()
    if ($input_ -eq "q" -or $input_ -eq "quit") { break }
    if ($input_ -eq "next" -or $input_ -eq "n") {
        $unchecked = $allLines | Where-Object { $_ -match '^\[ \]' }
        $nextFile = Join-Path $PSScriptRoot "checklist\NEXT_LIST.txt"
        $unchecked | Set-Content $nextFile
        Write-Host "Wrote $($unchecked.Count) unchecked items to $nextFile" -ForegroundColor Green
        continue
    }
    # Toggle numbers (comma/space separated).
    $parts = $input_ -split '[,\s]+' | Where-Object { $_ -ne "" }
    foreach ($p in $parts) {
        if ($p -notmatch '^\d+$') {
            Write-Host "Invalid: '$p'" -ForegroundColor Red
            continue
        }
        $n = [int]$p
        if ($n -lt 1 -or $n -gt $toggleable.Count) {
            Write-Host "Out of range: $n (1-$($toggleable.Count))" -ForegroundColor Red
            continue
        }
        $entry = $toggleable[$n - 1]
        $fileIdx = $entry[0]
        $cur = $entry[1]
        if ($cur -match '^\[x\]') {
            $new = $cur -replace '^\[x\]', '[ ]'
        } else {
            $new = $cur -replace '^\[ \]', '[x]'
        }
        $allLines[$fileIdx] = $new
        $entry[1] = $new
    }
    # Save on every change.
    $allLines | Set-Content $File
    Write-Host "Saved to $File" -ForegroundColor DarkGray
}
Write-Host "Done." -ForegroundColor Cyan

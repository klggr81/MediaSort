<#
    Move-MediaFiles.ps1
    Drop this script into the parent folder you want to consolidate.
    All images go into .\images, all videos into .\videos.

    Requires MediaTools.psm1 in the same folder.
    A GUI version is also available: see Run-MediaTools.ps1

    Usage:
        .\Move-MediaFiles.ps1 -DryRun
        .\Move-MediaFiles.ps1
        .\Move-MediaFiles.ps1 -Root "D:\Some Other Folder"
#>
param([string]$Root, [switch]$DryRun)

if (-not $Root) {
    if ($PSScriptRoot) { $Root = $PSScriptRoot } else { $Root = (Get-Location).Path }
}

$modulePath = Join-Path $PSScriptRoot 'MediaTools.psm1'
if (-not (Test-Path $modulePath)) {
    Write-Error "MediaTools.psm1 not found next to this script. Make sure both files live in the same folder."
    exit 1
}
Import-Module $modulePath -Force

Write-Host "Working in: $Root"
if ($DryRun) { Write-Host "(DRY RUN -- nothing will be moved)" }
Write-Host ""

$callback = {
    param($e)
    switch ($e.Type) {
        'scan-done'  { Write-Host "Found $($e.Total) media files." -ForegroundColor Cyan }
        'log' {
            if ($e.Level -eq 'warn') { Write-Warning $e.Message }
            else { Write-Host $e.Message }
        }
        'phase-done' {
            $s = $e.Summary
            Write-Host ""
            Write-Host "----------------------------------------"
            Write-Host "Images moved : $($s.ImageCount)"
            Write-Host "Videos moved : $($s.VideoCount)"
            if ($s.Failed -gt 0) { Write-Host "Failures     : $($s.Failed)" }
            if ($s.DryRun)       { Write-Host "(Dry run -- nothing was actually moved.)" }
            Write-Host "----------------------------------------"
        }
    }
}

Invoke-MoveMedia -Root $Root -DryRun:$DryRun -OnProgress $callback | Out-Null

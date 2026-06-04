<#
    Cleanup-Junk.ps1
    Drop into the folder you want to clean. Removes dotfiles, Windows
    junk (Thumbs.db, desktop.ini), small files, junk folders, and
    empty subfolders. Items go to the Recycle Bin by default.

    Requires MediaTools.psm1 in the same folder.

    Usage:
        .\Cleanup-Junk.ps1 -DryRun
        .\Cleanup-Junk.ps1
        .\Cleanup-Junk.ps1 -Permanent
        .\Cleanup-Junk.ps1 -MinSizeKB 50 -AggressiveSize
#>
param(
    [string]$Root,
    [int]$MinSizeKB=10,
    [switch]$DryRun,
    [switch]$Permanent,
    [switch]$AggressiveSize,
    [switch]$SkipEmptyFolderCleanup
)

if (-not $Root) {
    if ($PSScriptRoot) { $Root = $PSScriptRoot } else { $Root = (Get-Location).Path }
}

$modulePath = Join-Path $PSScriptRoot 'MediaTools.psm1'
if (-not (Test-Path $modulePath)) {
    Write-Error "MediaTools.psm1 not found next to this script."
    exit 1
}
Import-Module $modulePath -Force

Write-Host "Working in : $Root"
Write-Host "Min size   : $MinSizeKB KB"
if ($AggressiveSize) { Write-Host "Size filter: EVERYWHERE (incl. images\ and videos\)" }
else                 { Write-Host "Size filter: skips images\ and videos\ subtrees" }
if ($DryRun)         { Write-Host "(DRY RUN -- nothing will be deleted)" }
if ($Permanent)      { Write-Host "Mode       : PERMANENT delete (no Recycle Bin)" }
else                 { Write-Host "Mode       : Recycle Bin (recoverable)" }
Write-Host ""

$callback = {
    param($e)
    switch ($e.Type) {
        'scan-done' { Write-Host "Items to process: $($e.Total)" -ForegroundColor Cyan }
        'log' {
            if ($e.Level -eq 'warn') { Write-Warning $e.Message }
            else { Write-Host $e.Message }
        }
        'phase-done' {
            $s = $e.Summary
            Write-Host ""
            Write-Host "----------------------------------------"
            Write-Host ("Junk files removed    : {0}" -f $s.JunkFileCount)
            Write-Host ("Small files removed   : {0}" -f $s.SmallFileCount)
            Write-Host ("Junk folders removed  : {0}" -f $s.JunkFolderCount)
            Write-Host ("Empty folders removed : {0}" -f $s.EmptyFolderCount)
            Write-Host ("Space reclaimed       : {0:N2} MB" -f ($s.BytesReclaimed / 1MB))
            if ($s.Failed -gt 0) { Write-Host ("Failures              : {0}" -f $s.Failed) }
            if ($s.DryRun) { Write-Host "(Dry run -- nothing was actually deleted.)" }
            Write-Host "----------------------------------------"
        }
    }
}

Invoke-CleanupJunk -Root $Root -MinSizeKB $MinSizeKB -DryRun:$DryRun -Permanent:$Permanent `
    -AggressiveSize:$AggressiveSize -SkipEmptyFolderCleanup:$SkipEmptyFolderCleanup `
    -OnProgress $callback | Out-Null

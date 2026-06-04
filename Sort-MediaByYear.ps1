<#
    Sort-MediaByYear.ps1
    Drop into a folder of images or videos. Sorts files (non-recursive)
    into subfolders named by year using EXIF / media metadata when
    available, otherwise the earlier of CreationTime / LastWriteTime.

    Requires MediaTools.psm1 in the same folder.

    Usage:
        .\Sort-MediaByYear.ps1 -DryRun
        .\Sort-MediaByYear.ps1
        .\Sort-MediaByYear.ps1 -UseFileDateOnly
#>
param(
    [string]$Root,
    [switch]$DryRun,
    [switch]$UseFileDateOnly,
    [string]$UnknownFolderName='Unknown'
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

Write-Host "Working in: $Root"
if ($DryRun) { Write-Host "(DRY RUN -- nothing will be moved)" }
Write-Host ""

$callback = {
    param($e)
    switch ($e.Type) {
        'scan-done' { Write-Host "Found $($e.Total) media files in this folder." -ForegroundColor Cyan }
        'log' {
            if ($e.Level -eq 'warn') { Write-Warning $e.Message }
            else { Write-Host $e.Message }
        }
        'phase-done' {
            $s = $e.Summary
            Write-Host ""
            Write-Host "----------------------------------------"
            Write-Host "Moved          : $($s.Moved)"
            if ($s.Failed -gt 0) { Write-Host "Failures       : $($s.Failed)" }
            if ($s.ByYear.Count -gt 0) {
                Write-Host "By year:"
                $s.ByYear.GetEnumerator() | Sort-Object Name | ForEach-Object {
                    Write-Host ("  {0} : {1}" -f $_.Key, $_.Value)
                }
            }
            if ($s.DryRun) { Write-Host "(Dry run -- nothing was actually moved.)" }
            Write-Host "----------------------------------------"
        }
    }
}

Invoke-SortMediaByYear -Root $Root -DryRun:$DryRun -UseFileDateOnly:$UseFileDateOnly -UnknownFolderName $UnknownFolderName -OnProgress $callback | Out-Null

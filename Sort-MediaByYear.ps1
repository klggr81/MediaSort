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
        .\Sort-MediaByYear.ps1 -KeepParentFolder   # Holiday\a.jpg -> 2019\Holiday\a.jpg
        .\Sort-MediaByYear.ps1 -KeepParentFolder -SkipDateFolders   # 2024-07-03\a.jpg -> 2024\a.jpg
#>
param(
    [string]$Root,
    [switch]$DryRun,
    [switch]$UseFileDateOnly,
    [string]$UnknownFolderName='Unknown',
    [switch]$KeepParentFolder,
    [switch]$SkipDateFolders
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

$transfers = New-MediaTransferStore
$started   = Get-Date

$callback = {
    param($e)
    switch ($e.Type) {
        'transfer' { Register-MediaTransfer -Store $transfers -Transfer $e }
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

$result = Invoke-SortMediaByYear -Root $Root -DryRun:$DryRun -UseFileDateOnly:$UseFileDateOnly -UnknownFolderName $UnknownFolderName -KeepParentFolder:$KeepParentFolder -SkipDateFolders:$SkipDateFolders -OnProgress $callback

if ($transfers.Records.Count -gt 0) {
    $logPath = Join-Path (Join-Path $PSScriptRoot 'Logs') ("Transfers-{0}.txt" -f $started.ToString('yyyy-MM-dd_HHmmss'))
    $info = [ordered]@{
        'Started'       = $started.ToString('yyyy-MM-dd HH:mm:ss')
        'Finished'      = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        'Status'        = $(if ($result.Cancelled) { 'Cancelled' } else { 'Completed' })
        'Folder'        = $Root
        'Sort by year'  = $(if ($UseFileDateOnly) { 'File dates only' } else { 'Metadata, else file dates' }) + $(if ($DryRun) { '  -- DRY RUN' } else { '' })
        'Keep folder name' = $(if ($KeepParentFolder -and $SkipDateFolders) { 'Yes, except date folders' } elseif ($KeepParentFolder) { 'Yes' } else { 'No' })
        'Started from'  = 'Sort-MediaByYear.ps1 (command line)'
    }
    $saved = Write-MediaTransferLog -Path $logPath -Store $transfers -Info $info -CopyToFolder $Root
    Write-Host "Transfer log: $($saved.Path)"
    if ($saved.CopyPath) { Write-Host "Copy saved with the files: $($saved.CopyPath)" }
}

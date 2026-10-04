<#
    Move-MediaFiles.ps1
    Drop this script into the parent folder you want to consolidate.
    All images go into .\images, all videos into .\videos.

    Requires MediaTools.psm1 in the same folder.
    A GUI version is also available: see Run-MediaTools.ps1 / run.bat

    Usage:
        .\Move-MediaFiles.ps1 -DryRun
        .\Move-MediaFiles.ps1
        .\Move-MediaFiles.ps1 -Root "D:\Some Other Folder"
        .\Move-MediaFiles.ps1 -OutputRoot "E:\" -Copy
        .\Move-MediaFiles.ps1 -KeepTogether      # one .\media folder
        .\Move-MediaFiles.ps1 -KeepParentFolder  # images\<original folder>\file
        .\Move-MediaFiles.ps1 -KeepParentFolder -SkipDateFolders  # ...but not for 2024-07-03 etc.
        .\Move-MediaFiles.ps1 -FindDuplicates    # list identical files in a Duplicates log
        .\Move-MediaFiles.ps1 -RemoveDuplicates  # Copy: skip extra copies / Move: Recycle Bin
#>
param(
    [string]$Root,
    [string]$OutputRoot,
    [switch]$Copy,
    [switch]$KeepTogether,
    [switch]$KeepParentFolder,
    [switch]$SkipDateFolders,
    [switch]$FindDuplicates,
    [switch]$RemoveDuplicates,
    [switch]$DryRun
)

if (-not $Root) {
    if ($PSScriptRoot) { $Root = $PSScriptRoot } else { $Root = (Get-Location).Path }
}

$modulePath = Join-Path $PSScriptRoot 'MediaTools.psm1'
if (-not (Test-Path $modulePath)) {
    Write-Error "MediaTools.psm1 not found next to this script. Make sure both files live in the same folder."
    exit 1
}
Import-Module $modulePath -Force

$verb = if ($Copy) { 'copied' } else { 'moved' }
Write-Host "Working in: $Root"
if ($OutputRoot) { Write-Host "Output to : $OutputRoot" }
if ($DryRun) { Write-Host "(DRY RUN -- nothing will be $verb)" }
Write-Host ""

$transfers  = New-MediaTransferStore
$duplicates = @{ Event = $null; Announced = $false }
$started    = Get-Date

$callback = {
    param($e)
    switch ($e.Type) {
        'transfer'   { Register-MediaTransfer -Store $transfers -Transfer $e }
        'duplicates' { $duplicates.Event = $e }
        'phase'      { if ($e.Phase -eq 'dupscan') { Write-Host $e.Message -ForegroundColor Cyan } }
        'scan-done'  {
            if ($e.Phase -eq 'move' -and -not $duplicates.Announced) {
                Write-Host "Found $($e.Total) media files." -ForegroundColor Cyan
                $duplicates.Announced = $true
            }
        }
        'log' {
            if ($e.Level -eq 'warn') { Write-Warning $e.Message }
            else { Write-Host $e.Message }
        }
        'phase-done' {
            $s = $e.Summary
            Write-Host ""
            Write-Host "----------------------------------------"
            Write-Host "Images $verb : $($s.ImageCount)"
            Write-Host "Videos $verb : $($s.VideoCount)"
            if ($s.Failed -gt 0) { Write-Host "Failures     : $($s.Failed)" }
            if ($FindDuplicates -or $RemoveDuplicates) {
                Write-Host "Duplicate groups   : $($s.DuplicateGroups)"
                if ($RemoveDuplicates) {
                    $label = if ($DryRun) { 'Would be removed  ' } else { 'Duplicates removed' }
                    Write-Host ("{0} : {1}  ({2:N1} MB)" -f $label, $s.DuplicatesRemoved, ($s.DuplicateBytes / 1MB))
                }
            }
            if ($s.DryRun)       { Write-Host "(Dry run -- nothing was actually $verb.)" }
            Write-Host "----------------------------------------"
        }
    }
}

$result = Invoke-MoveMedia -Root $Root -OutputRoot $OutputRoot -Copy:$Copy -KeepTogether:$KeepTogether `
    -KeepParentFolder:$KeepParentFolder -SkipDateFolders:$SkipDateFolders -FindDuplicates:$FindDuplicates -RemoveDuplicates:$RemoveDuplicates `
    -DryRun:$DryRun -OnProgress $callback
$stamp = $started.ToString('yyyy-MM-dd_HHmmss')

if ($transfers.Records.Count -gt 0) {
    $logPath = Join-Path (Join-Path $PSScriptRoot 'Logs') "Transfers-$stamp.txt"
    $info = [ordered]@{
        'Started'       = $started.ToString('yyyy-MM-dd HH:mm:ss')
        'Finished'      = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        'Status'        = $(if ($result.Cancelled) { 'Cancelled' } else { 'Completed' })
        'Source folder' = $Root
        'Output folder' = $(if ($OutputRoot) { $OutputRoot } else { $Root })
        'Consolidate'   = $(if ($Copy) { 'Copy (originals kept in place)' } else { 'Move' }) + $(if ($DryRun) { '  -- DRY RUN' } else { '' })
        'Layout'        = $(if ($KeepTogether) { 'Together (media\)' } else { 'Separate (images\ + videos\)' })
        'Keep folder name' = $(if ($KeepParentFolder -and $SkipDateFolders) { 'Yes, except date folders' } elseif ($KeepParentFolder) { 'Yes' } else { 'No' })
        'Started from'  = 'Move-MediaFiles.ps1 (command line)'
    }
    $saved = Write-MediaTransferLog -Path $logPath -Store $transfers -Info $info `
                -CopyToFolder $(if ($OutputRoot) { $OutputRoot } else { $Root })
    Write-Host "Transfer log: $($saved.Path)"
    if ($saved.CopyPath) { Write-Host "Copy saved with the files: $($saved.CopyPath)" }
}

if ($duplicates.Event) {
    $dupPath = Join-Path (Join-Path $PSScriptRoot 'Logs') "Duplicates-$stamp.txt"
    $dupInfo = [ordered]@{
        'Started'       = $started.ToString('yyyy-MM-dd HH:mm:ss')
        'Source folder' = $Root
        'Output folder' = $(if ($OutputRoot) { $OutputRoot } else { $Root })
        'Consolidate'   = $(if ($Copy) { 'Copy' } else { 'Move' }) + $(if ($DryRun) { '  -- DRY RUN' } else { '' })
        'Started from'  = 'Move-MediaFiles.ps1 (command line)'
    }
    Write-MediaDuplicateLog -Path $dupPath -Duplicates $duplicates.Event -Info $dupInfo | Out-Null
    Write-Host "Duplicates log: $dupPath"
}

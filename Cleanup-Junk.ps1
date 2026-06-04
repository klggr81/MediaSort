<#
    Cleanup-Junk.ps1
    Drop this script into the parent folder you want to clean up
    (the same place where Move-MediaFiles.ps1 was run).

    What it removes (recursively, from this folder downward):

      1. Junk files:
           - Anything whose name starts with "." (Mac dotfiles like
             .DS_Store, ._photo.jpg, .localized, .apdisk, etc.)
           - Windows system junk: Thumbs.db, ehthumbs.db, desktop.ini
           - Temp files: *.tmp, *.temp, *~

      2. Junk folders:
           - Anything whose name starts with "." or is "__MACOSX"
             (deleted recursively, contents included).

      3. Files smaller than -MinSizeKB (default 10 KB).
           By default the size filter SKIPS the images\ and videos\
           subfolders so you don't accidentally lose a tiny but real
           photo. Pass -AggressiveSize to apply the size filter
           there too.

      4. Empty folders left behind after the above.
           The images\ and videos\ folders themselves are never
           deleted even if empty.

    Default deletion target is the Recycle Bin, so anything wrong
    can be restored. Pass -Permanent to skip the Recycle Bin.

    Usage:
        # ALWAYS run this first to preview:
        .\Cleanup-Junk.ps1 -DryRun

        # Real run, items go to Recycle Bin:
        .\Cleanup-Junk.ps1

        # Real run, permanently deleted:
        .\Cleanup-Junk.ps1 -Permanent

        # Custom size threshold (e.g. 50 KB) and aggressive mode:
        .\Cleanup-Junk.ps1 -MinSizeKB 50 -AggressiveSize

    If PowerShell blocks scripts, unblock for the current window only:
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#>

param(
    [string]$Root,
    [int]$MinSizeKB = 10,
    [switch]$DryRun,
    [switch]$Permanent,
    [switch]$AggressiveSize,
    [switch]$SkipEmptyFolderCleanup
)

# --- Resolve the root folder ------------------------------------------------

if (-not $Root) {
    if ($PSScriptRoot) { $Root = $PSScriptRoot }
    else               { $Root = (Get-Location).Path }
}

if (-not (Test-Path -LiteralPath $Root)) {
    Write-Error "Root folder not found: $Root"
    exit 1
}

$Root = (Resolve-Path -LiteralPath $Root).Path

Write-Host "Working in : $Root"
Write-Host "Min size   : $MinSizeKB KB"
if ($AggressiveSize)   { Write-Host "Size filter: applies EVERYWHERE (incl. images\ and videos\)" }
else                   { Write-Host "Size filter: skips images\ and videos\ subtrees" }
if ($DryRun)           { Write-Host "(DRY RUN -- nothing will be deleted)" }
if ($Permanent)        { Write-Host "Mode       : PERMANENT delete (Recycle Bin bypassed!)" }
else                   { Write-Host "Mode       : Recycle Bin (recoverable)" }
Write-Host ""

# Load the VB FileSystem helper for Recycle Bin support
if (-not $Permanent -and -not $DryRun) {
    Add-Type -AssemblyName Microsoft.VisualBasic
}

# --- Junk detection rules ---------------------------------------------------

# Windows / cross-platform junk file names (exact, case-insensitive)
$JunkNames = @(
    'Thumbs.db', 'ehthumbs.db', 'ehthumbs_vista.db', 'desktop.ini'
)

# Junk file name wildcard patterns
$JunkPatterns = @('*.tmp', '*.temp', '*~')

# Folder names treated as junk (whole tree deleted)
$JunkFolderNames = @('__MACOSX')

$ImagesDir = (Join-Path $Root 'images')
$VideosDir = (Join-Path $Root 'videos')

# --- Helpers ----------------------------------------------------------------

function Test-InsideProtected {
    param([string]$Path)
    return ($Path.StartsWith($ImagesDir + [IO.Path]::DirectorySeparatorChar,
                              [StringComparison]::OrdinalIgnoreCase) -or
            $Path.StartsWith($VideosDir + [IO.Path]::DirectorySeparatorChar,
                              [StringComparison]::OrdinalIgnoreCase))
}

function Test-JunkFile {
    param([System.IO.FileInfo]$File)
    # Any file starting with a dot is junk (covers all Mac dotfiles)
    if ($File.Name.StartsWith('.')) { return $true }
    foreach ($n in $JunkNames)    { if ($File.Name -ieq $n)    { return $true } }
    foreach ($p in $JunkPatterns) { if ($File.Name -like $p)   { return $true } }
    return $false
}

function Test-JunkFolder {
    param([System.IO.DirectoryInfo]$Dir)
    if ($Dir.Name.StartsWith('.')) { return $true }
    if ($JunkFolderNames -contains $Dir.Name) { return $true }
    return $false
}

function Remove-ItemSafely {
    param([string]$Path, [switch]$IsFolder)

    if ($DryRun) { return $true }

    try {
        if ($Permanent) {
            if ($IsFolder) { Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop }
            else           { Remove-Item -LiteralPath $Path -Force -ErrorAction Stop }
        } else {
            if ($IsFolder) {
                [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
                    $Path,
                    [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                    [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
                )
            } else {
                [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
                    $Path,
                    [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                    [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
                )
            }
        }
        return $true
    } catch {
        Write-Warning "FAILED to remove: $Path -- $($_.Exception.Message)"
        return $false
    }
}

# --- State ------------------------------------------------------------------

$selfPath     = $PSCommandPath
$minSizeBytes = $MinSizeKB * 1024

$junkFileCount   = 0
$smallFileCount  = 0
$junkFolderCount = 0
$emptyFolderCount = 0
$bytesReclaimed  = 0
$failed          = 0

# --- Phase 1: nuke junk folders whole --------------------------------------
# Deepest first so we don't enumerate a folder that's about to disappear.

Get-ChildItem -LiteralPath $Root -Recurse -Directory -Force -ErrorAction SilentlyContinue |
    Sort-Object { $_.FullName.Length } -Descending |
    ForEach-Object {
        $dir = $_
        if (-not (Test-Path -LiteralPath $dir.FullName)) { return }  # already deleted with a parent
        if (Test-JunkFolder $dir) {
            # Sum sizes for reporting before deletion
            $sz = 0
            try {
                $sz = (Get-ChildItem -LiteralPath $dir.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
                       Measure-Object Length -Sum).Sum
                if (-not $sz) { $sz = 0 }
            } catch { }

            if ($DryRun) {
                Write-Host ("[DRY] junk folder ({0:N1} KB)  {1}" -f ($sz/1KB), $dir.FullName)
            } else {
                if (Remove-ItemSafely -Path $dir.FullName -IsFolder) {
                    Write-Host ("Deleted folder ({0:N1} KB)  {1}" -f ($sz/1KB), $dir.FullName)
                } else {
                    $failed++
                    return
                }
            }
            $junkFolderCount++
            $bytesReclaimed += $sz
        }
    }

# --- Phase 2: delete junk files and undersized files -----------------------

Get-ChildItem -LiteralPath $Root -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
    $file = $_

    # Never delete the script itself
    if ($selfPath -and ($file.FullName -ieq $selfPath)) { return }

    # The folder may have been removed in Phase 1
    if (-not (Test-Path -LiteralPath $file.FullName)) { return }

    $reason = $null
    if (Test-JunkFile $file) {
        $reason = 'junk-name'
    } elseif ($file.Length -lt $minSizeBytes) {
        if ($AggressiveSize -or -not (Test-InsideProtected $file.FullName)) {
            $reason = "<${MinSizeKB}KB"
        }
    }

    if (-not $reason) { return }

    if ($DryRun) {
        Write-Host ("[DRY] {0,-12} {1,10:N0} B   {2}" -f $reason, $file.Length, $file.FullName)
    } else {
        if (Remove-ItemSafely -Path $file.FullName) {
            Write-Host ("Deleted {0,-10} {1,10:N0} B   {2}" -f $reason, $file.Length, $file.FullName)
        } else {
            $failed++
            return
        }
    }

    $bytesReclaimed += $file.Length
    if ($reason -eq 'junk-name') { $junkFileCount++ } else { $smallFileCount++ }
}

# --- Phase 3: remove empty folders -----------------------------------------

if (-not $SkipEmptyFolderCleanup) {
    Get-ChildItem -LiteralPath $Root -Recurse -Directory -Force -ErrorAction SilentlyContinue |
        Sort-Object { $_.FullName.Length } -Descending |
        ForEach-Object {
            $dir = $_

            if (-not (Test-Path -LiteralPath $dir.FullName)) { return }

            # Never delete the protected media folders
            if ($dir.FullName -ieq $ImagesDir -or $dir.FullName -ieq $VideosDir) { return }

            $hasContent = $false
            try {
                $hasContent = (Get-ChildItem -LiteralPath $dir.FullName -Force -ErrorAction Stop |
                               Measure-Object).Count -gt 0
            } catch { return }

            if ($hasContent) { return }

            if ($DryRun) {
                Write-Host "[DRY] empty folder: $($dir.FullName)"
            } else {
                if (Remove-ItemSafely -Path $dir.FullName -IsFolder) {
                    Write-Host "Removed empty folder: $($dir.FullName)"
                } else {
                    $failed++
                    return
                }
            }
            $emptyFolderCount++
        }
}

# --- Summary ----------------------------------------------------------------

Write-Host ""
Write-Host "----------------------------------------"
Write-Host ("Junk files removed   : {0}" -f $junkFileCount)
Write-Host ("Small files removed  : {0}" -f $smallFileCount)
Write-Host ("Junk folders removed : {0}" -f $junkFolderCount)
Write-Host ("Empty folders removed: {0}" -f $emptyFolderCount)
Write-Host ("Space reclaimed      : {0:N2} MB" -f ($bytesReclaimed / 1MB))
if ($failed -gt 0) { Write-Host ("Failures             : {0}" -f $failed) }
if ($DryRun)       { Write-Host "(Dry run -- nothing was actually deleted.)" }
if ($Permanent -and -not $DryRun) { Write-Host "(Permanent delete -- items are NOT in the Recycle Bin.)" }
Write-Host "----------------------------------------"

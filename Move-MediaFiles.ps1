<#
    Move-MediaFiles.ps1
    Drop this script into the parent folder you want to sort.
    It recursively walks every subfolder and moves all images into
    .\images and all videos into .\videos (next to the script itself).

    Usage (in PowerShell, from the folder where the script sits):
        # Preview only:
        .\Move-MediaFiles.ps1 -DryRun

        # Do it for real:
        .\Move-MediaFiles.ps1

        # Override the root explicitly (optional):
        .\Move-MediaFiles.ps1 -Root "D:\Some Other Folder"

    If PowerShell blocks the script, run this first (current session only):
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#>

param(
    [string]$Root,
    [switch]$DryRun
)

# --- Resolve the root folder ------------------------------------------------
# Default to the folder the script lives in; fall back to current directory
# if $PSScriptRoot is empty (e.g. dot-sourced or piped in).

if (-not $Root) {
    if ($PSScriptRoot) { $Root = $PSScriptRoot }
    else               { $Root = (Get-Location).Path }
}

if (-not (Test-Path -LiteralPath $Root)) {
    Write-Error "Root folder not found: $Root"
    exit 1
}

Write-Host "Working in: $Root"
if ($DryRun) { Write-Host "(DRY RUN -- no files will be moved)" }
Write-Host ""

# --- Configuration ----------------------------------------------------------

$ImagesDest = Join-Path $Root "images"
$VideosDest = Join-Path $Root "videos"

$ImageExt = @(
    '.jpg','.jpeg','.png','.gif','.bmp','.tif','.tiff','.webp',
    '.heic','.heif','.avif','.raw','.cr2','.cr3','.nef','.arw',
    '.dng','.orf','.rw2','.pef','.srw','.raf','.sr2'
)
$VideoExt = @(
    '.mp4','.mov','.avi','.mkv','.wmv','.flv','.webm','.m4v',
    '.mpg','.mpeg','.3gp','.3g2','.mts','.m2ts','.ts','.vob','.ogv'
)

# --- Create destination folders --------------------------------------------

foreach ($d in @($ImagesDest, $VideosDest)) {
    if (-not (Test-Path -LiteralPath $d)) {
        if ($DryRun) {
            Write-Host "[DRY] Would create: $d"
        } else {
            New-Item -ItemType Directory -Path $d | Out-Null
            Write-Host "Created: $d"
        }
    }
}

# --- Helpers ----------------------------------------------------------------

# Return a destination path that doesn't already exist; appends _1, _2, ...
function Get-UniquePath {
    param([string]$Dir, [string]$Name)
    $dest = Join-Path $Dir $Name
    if (-not (Test-Path -LiteralPath $dest)) { return $dest }
    $base = [IO.Path]::GetFileNameWithoutExtension($Name)
    $ext  = [IO.Path]::GetExtension($Name)
    $i = 1
    while ($true) {
        $candidate = Join-Path $Dir ("{0}_{1}{2}" -f $base, $i, $ext)
        if (-not (Test-Path -LiteralPath $candidate)) { return $candidate }
        $i++
    }
}

# --- Main -------------------------------------------------------------------

$selfPath = $PSCommandPath
$imgCount = 0
$vidCount = 0
$skipped  = 0
$failed   = 0

Get-ChildItem -LiteralPath $Root -Recurse -File -Force | ForEach-Object {
    $file = $_

    # Never move the script itself
    if ($selfPath -and ($file.FullName -ieq $selfPath)) { return }

    # Skip files already inside either destination folder (idempotent re-runs)
    if ($file.FullName.StartsWith($ImagesDest, [StringComparison]::OrdinalIgnoreCase) -or
        $file.FullName.StartsWith($VideosDest, [StringComparison]::OrdinalIgnoreCase)) {
        return
    }

    $ext  = $file.Extension.ToLower()
    $dest = $null
    if     ($ImageExt -contains $ext) { $dest = $ImagesDest }
    elseif ($VideoExt -contains $ext) { $dest = $VideosDest }
    else {
        $skipped++
        return
    }

    $target = Get-UniquePath -Dir $dest -Name $file.Name

    if ($DryRun) {
        Write-Host "[DRY] $($file.FullName)  ->  $target"
    } else {
        try {
            Move-Item -LiteralPath $file.FullName -Destination $target -Force -ErrorAction Stop
            Write-Host "Moved: $($file.Name)"
        } catch {
            Write-Warning "FAILED: $($file.FullName) -- $($_.Exception.Message)"
            $failed++
            return
        }
    }

    if ($dest -eq $ImagesDest) { $imgCount++ } else { $vidCount++ }
}

# --- Summary ----------------------------------------------------------------

Write-Host ""
Write-Host "----------------------------------------"
Write-Host "Images moved : $imgCount"
Write-Host "Videos moved : $vidCount"
Write-Host "Other files  : $skipped (left in place)"
if ($failed -gt 0) { Write-Host "Failures     : $failed" }
if ($DryRun)       { Write-Host "(Dry run -- nothing was actually moved.)" }
Write-Host "----------------------------------------"

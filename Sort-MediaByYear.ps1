<#
    Sort-MediaByYear.ps1
    Drop this script into a folder containing images and/or videos.
    It sorts every media file in *that* folder (non-recursive) into
    subfolders named by year: 2015, 2016, 2017, ...

    Date used (in priority order):
        1. EXIF "Date taken" (photos) / "Media created" (videos)
        2. The earlier of CreationTime and LastWriteTime
        3. If nothing works, the file goes into an "Unknown" folder.

    Usage (in PowerShell, from the folder where the script sits):
        # Preview only:
        .\Sort-MediaByYear.ps1 -DryRun

        # Do it for real:
        .\Sort-MediaByYear.ps1

        # Skip the (slower) metadata read and use file dates only:
        .\Sort-MediaByYear.ps1 -UseFileDateOnly

    If PowerShell blocks scripts, unblock for the current window only:
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#>

param(
    [switch]$DryRun,
    [switch]$UseFileDateOnly,
    [string]$UnknownFolderName = "Unknown"
)

# --- Resolve the folder the script lives in ---------------------------------

$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = (Get-Location).Path }

Write-Host "Working in: $ScriptDir"
if ($DryRun) { Write-Host "(DRY RUN -- no files will be moved)" }
Write-Host ""

# --- Extensions -------------------------------------------------------------

$ImageExt = @('.jpg','.jpeg','.png','.gif','.bmp','.tif','.tiff','.webp',
              '.heic','.heif','.avif','.raw','.cr2','.cr3','.nef','.arw',
              '.dng','.orf','.rw2','.pef','.srw','.raf','.sr2')
$VideoExt = @('.mp4','.mov','.avi','.mkv','.wmv','.flv','.webm','.m4v',
              '.mpg','.mpeg','.3gp','.3g2','.mts','.m2ts','.ts','.vob','.ogv')
$MediaExt = $ImageExt + $VideoExt

# --- Locate the Shell metadata property indices once ------------------------
# (Indices vary by Windows version, so we look them up by name.)

$shell        = $null
$shellFolder  = $null
$dateTakenIdx    = -1
$mediaCreatedIdx = -1

if (-not $UseFileDateOnly) {
    try {
        $shell       = New-Object -ComObject Shell.Application
        $shellFolder = $shell.Namespace($ScriptDir)
        for ($i = 0; $i -lt 320; $i++) {
            $name = $shellFolder.GetDetailsOf($null, $i)
            if ($name -eq 'Date taken')    { $dateTakenIdx    = $i }
            if ($name -eq 'Media created') { $mediaCreatedIdx = $i }
            if ($dateTakenIdx -ge 0 -and $mediaCreatedIdx -ge 0) { break }
        }
    } catch {
        Write-Warning "Could not initialize Shell metadata reader. Falling back to file dates."
        $UseFileDateOnly = $true
    }
}

# --- Helpers ----------------------------------------------------------------

function Get-MediaYear {
    param([System.IO.FileInfo]$File)

    $ext = $File.Extension.ToLower()

    if (-not $UseFileDateOnly -and $shellFolder) {
        $item   = $shellFolder.ParseName($File.Name)
        $idx    = if ($ImageExt -contains $ext) { $dateTakenIdx } else { $mediaCreatedIdx }
        if ($item -and $idx -ge 0) {
            $raw = $shellFolder.GetDetailsOf($item, $idx)
            if ($raw) {
                # Shell sometimes injects invisible Unicode LTR/RTL marks; strip them
                $clean  = $raw -replace '[\u200E\u200F\u202A-\u202E]', ''
                $parsed = [DateTime]::MinValue
                if ([DateTime]::TryParse($clean, [ref]$parsed)) {
                    return @{ Year = $parsed.Year; Source = 'metadata' }
                }
            }
        }
    }

    # Fallback: the earlier of LastWriteTime / CreationTime
    $earlier = if ($File.LastWriteTime -lt $File.CreationTime) {
                   $File.LastWriteTime
               } else {
                   $File.CreationTime
               }
    return @{ Year = $earlier.Year; Source = 'file-date' }
}

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

# --- Main loop --------------------------------------------------------------

$moved   = 0
$skipped = 0
$failed  = 0
$byYear  = @{}

$selfPath = $PSCommandPath

Get-ChildItem -LiteralPath $ScriptDir -File | ForEach-Object {
    $file = $_

    # Never move the script itself
    if ($selfPath -and ($file.FullName -ieq $selfPath)) { return }

    # Only operate on known media extensions
    if (-not ($MediaExt -contains $file.Extension.ToLower())) {
        $skipped++
        return
    }

    $info       = Get-MediaYear -File $file
    $year       = $info.Year
    $source     = $info.Source

    # Sanity-check the year. Anything outside 1980..(this year + 1) is suspicious.
    $thisYear = (Get-Date).Year
    if ($year -lt 1980 -or $year -gt ($thisYear + 1)) {
        $destFolder = Join-Path $ScriptDir $UnknownFolderName
        $year       = $UnknownFolderName
    } else {
        $destFolder = Join-Path $ScriptDir ([string]$year)
    }

    if (-not (Test-Path -LiteralPath $destFolder)) {
        if ($DryRun) {
            Write-Host "[DRY] Would create folder: $year"
        } else {
            New-Item -ItemType Directory -Path $destFolder | Out-Null
        }
    }

    $target = Get-UniquePath -Dir $destFolder -Name $file.Name

    if ($DryRun) {
        Write-Host ("[DRY] {0,-40}  ->  {1}\   ({2})" -f $file.Name, $year, $source)
    } else {
        try {
            Move-Item -LiteralPath $file.FullName -Destination $target -Force -ErrorAction Stop
            Write-Host ("Moved {0,-40}  ->  {1}\   ({2})" -f $file.Name, $year, $source)
            $moved++
        } catch {
            Write-Warning "FAILED: $($file.FullName) -- $($_.Exception.Message)"
            $failed++
            return
        }
    }

    if (-not $byYear.ContainsKey([string]$year)) { $byYear[[string]$year] = 0 }
    $byYear[[string]$year]++
}

# --- Summary ----------------------------------------------------------------

Write-Host ""
Write-Host "----------------------------------------"
Write-Host ("Moved          : {0}" -f $moved)
Write-Host ("Non-media kept : {0}" -f $skipped)
if ($failed -gt 0) { Write-Host ("Failures       : {0}" -f $failed) }
if ($byYear.Count -gt 0) {
    Write-Host "By year:"
    $byYear.GetEnumerator() | Sort-Object Name | ForEach-Object {
        Write-Host ("  {0} : {1}" -f $_.Key, $_.Value)
    }
}
if ($DryRun) { Write-Host "(Dry run -- nothing was actually moved.)" }
Write-Host "----------------------------------------"

# --- Clean up COM ref -------------------------------------------------------
if ($shell) {
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
}

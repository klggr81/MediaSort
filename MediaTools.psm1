<#
    MediaTools.psm1
    Shared library for the three media-organization operations.

    Each function supports:
      -OnProgress  : a [scriptblock] called with event hashtables
                     ({Type, Phase, Current, Total, Name, Level, ...})
      -CancelToken : a hashtable; set $CancelToken.Requested = $true
                     to politely stop work between files.

    Event Types:
      'phase'      -- a new phase started (Message has description)
      'scan-done'  -- pre-scan finished (Total has item count)
      'progress'   -- per-item progress (Current, Total, Name)
      'log'        -- a human-readable line; Level='info'|'detail'|'warn'
                      Detail-level events fire per file action; the GUI
                      can hide these from the in-window log box while
                      still capturing them to disk.
      'phase-done' -- phase completed (Summary has the result object)
#>

# --- Shared extension lists -------------------------------------------------

$script:ImageExt = @(
    '.jpg','.jpeg','.png','.gif','.bmp','.tif','.tiff','.webp',
    '.heic','.heif','.avif','.raw','.cr2','.cr3','.nef','.arw',
    '.dng','.orf','.rw2','.pef','.srw','.raf','.sr2'
)
$script:VideoExt = @(
    '.mp4','.mov','.avi','.mkv','.wmv','.flv','.webm','.m4v',
    '.mpg','.mpeg','.3gp','.3g2','.mts','.m2ts','.ts','.vob','.ogv'
)

function Get-MediaImageExtensions { return $script:ImageExt }
function Get-MediaVideoExtensions { return $script:VideoExt }

# --- Helpers ----------------------------------------------------------------

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

function Send-Progress {
    param([scriptblock]$OnProgress, [hashtable]$Event)
    if ($OnProgress) {
        try { $OnProgress.Invoke($Event) } catch { }
    }
}

function Test-Cancelled {
    param([hashtable]$CancelToken)
    return ($CancelToken -and $CancelToken.Requested -eq $true)
}

function Normalize-Extensions {
    param([string[]]$Extensions)
    return @($Extensions | ForEach-Object {
        $e = $_.ToLower().Trim()
        if (-not $e.StartsWith('.')) { $e = '.' + $e }
        $e
    })
}

# --- Invoke-MoveMedia -------------------------------------------------------

function Invoke-MoveMedia {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Root,
        [switch]$DryRun,
        [string[]]$ImageExtensions,
        [string[]]$VideoExtensions,
        [scriptblock]$OnProgress,
        [hashtable]$CancelToken
    )

    if (-not (Test-Path -LiteralPath $Root)) { throw "Root folder not found: $Root" }
    $Root = (Resolve-Path -LiteralPath $Root).Path

    if (-not $ImageExtensions) { $ImageExtensions = $script:ImageExt }
    if (-not $VideoExtensions) { $VideoExtensions = $script:VideoExt }
    $ImageExtensions = Normalize-Extensions $ImageExtensions
    $VideoExtensions = Normalize-Extensions $VideoExtensions

    $ImagesDest = Join-Path $Root 'images'
    $VideosDest = Join-Path $Root 'videos'
    $sep = [IO.Path]::DirectorySeparatorChar

    Send-Progress $OnProgress @{ Type='phase'; Phase='move'; Message="Scanning $Root for media to consolidate" }
    Send-Progress $OnProgress @{ Type='log'; Level='info'; Message="Image extensions: $($ImageExtensions -join ', ')" }
    Send-Progress $OnProgress @{ Type='log'; Level='info'; Message="Video extensions: $($VideoExtensions -join ', ')" }

    $allFiles = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object {
        $ext = $_.Extension.ToLower()
        ($ImageExtensions -contains $ext -or $VideoExtensions -contains $ext) -and
        -not $_.FullName.StartsWith($ImagesDest + $sep, [StringComparison]::OrdinalIgnoreCase) -and
        -not $_.FullName.StartsWith($VideosDest + $sep, [StringComparison]::OrdinalIgnoreCase)
    })
    $total = $allFiles.Count
    $totalBytes = ($allFiles | Measure-Object -Property Length -Sum).Sum
    if (-not $totalBytes) { $totalBytes = 0 }

    Send-Progress $OnProgress @{ Type='scan-done'; Phase='move'; Total=$total; TotalBytes=$totalBytes }

    if (-not $DryRun -and $total -gt 0) {
        foreach ($d in @($ImagesDest, $VideosDest)) {
            if (-not (Test-Path -LiteralPath $d)) {
                New-Item -ItemType Directory -Path $d -Force | Out-Null
                Send-Progress $OnProgress @{ Type='log'; Level='info'; Message="Created folder: $d" }
            }
        }
    }

    $imgCount = 0; $vidCount = 0; $failed = 0; $bytesProcessed = 0
    $i = 0
    $cancelled = $false

    foreach ($file in $allFiles) {
        if (Test-Cancelled $CancelToken) { $cancelled = $true; break }
        $i++

        $ext = $file.Extension.ToLower()
        $dest = if ($ImageExtensions -contains $ext) { $ImagesDest } else { $VideosDest }
        $target = Get-UniquePath -Dir $dest -Name $file.Name

        $success = $true
        if ($DryRun) {
            Send-Progress $OnProgress @{ Type='log'; Level='detail'; Message="[DRY] $($file.FullName) -> $target" }
        } else {
            try {
                Move-Item -LiteralPath $file.FullName -Destination $target -Force -ErrorAction Stop
                Send-Progress $OnProgress @{ Type='log'; Level='detail'; Message="Moved: $($file.FullName) -> $target" }
            } catch {
                Send-Progress $OnProgress @{ Type='log'; Level='warn'; Message="FAILED: $($file.FullName) -- $($_.Exception.Message)" }
                $failed++
                $success = $false
            }
        }

        if ($success) {
            if ($dest -eq $ImagesDest) { $imgCount++ } else { $vidCount++ }
        }
        $bytesProcessed += $file.Length

        Send-Progress $OnProgress @{
            Type='progress'; Phase='move'
            Current=$i; Total=$total; Name=$file.Name
            BytesProcessed=$bytesProcessed; TotalBytes=$totalBytes
        }
    }

    $result = [pscustomobject]@{
        Phase='move'; ImageCount=$imgCount; VideoCount=$vidCount
        Failed=$failed; BytesProcessed=$bytesProcessed; Total=$total
        DryRun=[bool]$DryRun; Cancelled=$cancelled
    }
    Send-Progress $OnProgress @{ Type='phase-done'; Phase='move'; Summary=$result }
    return $result
}

# --- Invoke-SortMediaByYear -------------------------------------------------

function Invoke-SortMediaByYear {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Root,
        [switch]$DryRun,
        [switch]$UseFileDateOnly,
        [string]$UnknownFolderName='Unknown',
        [scriptblock]$OnProgress,
        [hashtable]$CancelToken
    )

    if (-not (Test-Path -LiteralPath $Root)) { throw "Root folder not found: $Root" }
    $Root = (Resolve-Path -LiteralPath $Root).Path

    $allMediaExt = $script:ImageExt + $script:VideoExt

    Send-Progress $OnProgress @{ Type='phase'; Phase='sort'; Message="Scanning $Root for media to sort by year" }

    $allFiles = @(Get-ChildItem -LiteralPath $Root -File -Force -ErrorAction SilentlyContinue | Where-Object {
        $allMediaExt -contains $_.Extension.ToLower()
    })
    $total = $allFiles.Count
    $totalBytes = ($allFiles | Measure-Object -Property Length -Sum).Sum
    if (-not $totalBytes) { $totalBytes = 0 }

    Send-Progress $OnProgress @{ Type='scan-done'; Phase='sort'; Total=$total; TotalBytes=$totalBytes }

    $shell = $null
    $shellFolder = $null
    $dateTakenIdx = -1
    $mediaCreatedIdx = -1

    if (-not $UseFileDateOnly -and $total -gt 0) {
        try {
            $shell = New-Object -ComObject Shell.Application
            $shellFolder = $shell.Namespace($Root)
            for ($k = 0; $k -lt 320; $k++) {
                $name = $shellFolder.GetDetailsOf($null, $k)
                if ($name -eq 'Date taken')    { $dateTakenIdx = $k }
                if ($name -eq 'Media created') { $mediaCreatedIdx = $k }
                if ($dateTakenIdx -ge 0 -and $mediaCreatedIdx -ge 0) { break }
            }
        } catch {
            Send-Progress $OnProgress @{ Type='log'; Level='warn'; Message='Could not initialize Shell metadata reader; falling back to file dates.' }
            $UseFileDateOnly = $true
        }
    }

    $moved = 0; $failed = 0; $bytesProcessed = 0
    $byYear = @{}
    $thisYear = (Get-Date).Year
    $i = 0
    $cancelled = $false

    foreach ($file in $allFiles) {
        if (Test-Cancelled $CancelToken) { $cancelled = $true; break }
        $i++

        $year = $null
        $source = 'file-date'
        $ext = $file.Extension.ToLower()
        if (-not $UseFileDateOnly -and $shellFolder) {
            $item = $shellFolder.ParseName($file.Name)
            $idx = if ($script:ImageExt -contains $ext) { $dateTakenIdx } else { $mediaCreatedIdx }
            if ($item -and $idx -ge 0) {
                $raw = $shellFolder.GetDetailsOf($item, $idx)
                if ($raw) {
                    $clean = $raw -replace '[\u200E\u200F\u202A-\u202E]', ''
                    $parsed = [DateTime]::MinValue
                    if ([DateTime]::TryParse($clean, [ref]$parsed)) {
                        $year = $parsed.Year
                        $source = 'metadata'
                    }
                }
            }
        }
        if (-not $year) {
            $earlier = if ($file.LastWriteTime -lt $file.CreationTime) { $file.LastWriteTime } else { $file.CreationTime }
            $year = $earlier.Year
        }

        if ($year -lt 1980 -or $year -gt ($thisYear + 1)) {
            $destFolder = Join-Path $Root $UnknownFolderName
            $yearKey = $UnknownFolderName
        } else {
            $destFolder = Join-Path $Root ([string]$year)
            $yearKey = [string]$year
        }

        if (-not (Test-Path -LiteralPath $destFolder) -and -not $DryRun) {
            New-Item -ItemType Directory -Path $destFolder | Out-Null
        }

        $target = Get-UniquePath -Dir $destFolder -Name $file.Name
        $success = $true

        if ($DryRun) {
            Send-Progress $OnProgress @{ Type='log'; Level='detail'; Message="[DRY] $($file.Name) -> $yearKey\ ($source)" }
        } else {
            try {
                Move-Item -LiteralPath $file.FullName -Destination $target -Force -ErrorAction Stop
                Send-Progress $OnProgress @{ Type='log'; Level='detail'; Message="Sorted: $($file.Name) -> $yearKey\ ($source)" }
            } catch {
                Send-Progress $OnProgress @{ Type='log'; Level='warn'; Message="FAILED: $($file.FullName) -- $($_.Exception.Message)" }
                $failed++
                $success = $false
            }
        }

        if ($success) {
            $moved++
            if (-not $byYear.ContainsKey($yearKey)) { $byYear[$yearKey] = 0 }
            $byYear[$yearKey]++
        }
        $bytesProcessed += $file.Length

        Send-Progress $OnProgress @{
            Type='progress'; Phase='sort'
            Current=$i; Total=$total; Name=$file.Name
            BytesProcessed=$bytesProcessed; TotalBytes=$totalBytes
        }
    }

    if ($shell) {
        try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null } catch {}
    }

    $result = [pscustomobject]@{
        Phase='sort'; Moved=$moved; Failed=$failed; ByYear=$byYear
        BytesProcessed=$bytesProcessed; Total=$total
        DryRun=[bool]$DryRun; Cancelled=$cancelled
    }
    Send-Progress $OnProgress @{ Type='phase-done'; Phase='sort'; Summary=$result }
    return $result
}

# --- Invoke-CleanupJunk -----------------------------------------------------

function Invoke-CleanupJunk {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Root,
        [int]$MinSizeKB=10,
        [switch]$DryRun,
        [switch]$Permanent,
        [switch]$AggressiveSize,
        [switch]$SkipEmptyFolderCleanup,
        [scriptblock]$OnProgress,
        [hashtable]$CancelToken
    )

    if (-not (Test-Path -LiteralPath $Root)) { throw "Root folder not found: $Root" }
    $Root = (Resolve-Path -LiteralPath $Root).Path

    if (-not $Permanent -and -not $DryRun) {
        Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue
    }

    $JunkNames = @('Thumbs.db','ehthumbs.db','ehthumbs_vista.db','desktop.ini')
    $JunkPatterns = @('*.tmp','*.temp','*~')
    $JunkFolderNames = @('__MACOSX')
    $ImagesDir = Join-Path $Root 'images'
    $VideosDir = Join-Path $Root 'videos'
    $sep = [IO.Path]::DirectorySeparatorChar

    $testInside = {
        param($Path)
        return ($Path.StartsWith($ImagesDir + $sep, [StringComparison]::OrdinalIgnoreCase) -or
                $Path.StartsWith($VideosDir + $sep, [StringComparison]::OrdinalIgnoreCase))
    }
    $testJunkFile = {
        param($File)
        if ($File.Name.StartsWith('.')) { return $true }
        foreach ($n in $JunkNames) { if ($File.Name -ieq $n) { return $true } }
        foreach ($p in $JunkPatterns) { if ($File.Name -like $p) { return $true } }
        return $false
    }
    $testJunkFolder = {
        param($Dir)
        if ($Dir.Name.StartsWith('.')) { return $true }
        if ($JunkFolderNames -contains $Dir.Name) { return $true }
        return $false
    }
    $removeSafely = {
        param([string]$Path, [bool]$IsFolder)
        if ($DryRun) { return $true }
        try {
            if ($Permanent) {
                if ($IsFolder) { Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop }
                else { Remove-Item -LiteralPath $Path -Force -ErrorAction Stop }
            } else {
                if ($IsFolder) {
                    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
                        $Path,
                        [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                        [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
                } else {
                    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
                        $Path,
                        [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                        [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
                }
            }
            return $true
        } catch { return $false }
    }

    Send-Progress $OnProgress @{ Type='phase'; Phase='cleanup'; Message="Scanning $Root for junk to remove" }

    $junkFolders = @(Get-ChildItem -LiteralPath $Root -Recurse -Directory -Force -ErrorAction SilentlyContinue |
                     Where-Object { & $testJunkFolder $_ })

    $minSizeBytes = $MinSizeKB * 1024
    $allFiles = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Force -ErrorAction SilentlyContinue)

    $candidateFiles = @($allFiles | Where-Object {
        $junk = & $testJunkFile $_
        $tooSmall = ($_.Length -lt $minSizeBytes) -and ($AggressiveSize -or -not (& $testInside $_.FullName))
        $junk -or $tooSmall
    })

    $total = $junkFolders.Count + $candidateFiles.Count
    Send-Progress $OnProgress @{ Type='scan-done'; Phase='cleanup'; Total=$total; TotalBytes=0 }

    $dryPrefix = if ($DryRun) { "[DRY] Would remove" } else { "Removed" }

    $junkFileCount = 0; $smallFileCount = 0; $junkFolderCount = 0; $emptyFolderCount = 0
    $bytesReclaimed = 0; $failed = 0
    $i = 0
    $cancelled = $false

    # Phase 1: junk folders (deepest first)
    foreach ($dir in ($junkFolders | Sort-Object { $_.FullName.Length } -Descending)) {
        if (Test-Cancelled $CancelToken) { $cancelled = $true; break }
        $i++
        if (-not (Test-Path -LiteralPath $dir.FullName)) {
            Send-Progress $OnProgress @{ Type='progress'; Phase='cleanup'; Current=$i; Total=$total; Name=$dir.Name; BytesProcessed=$bytesReclaimed }
            continue
        }

        $sz = 0
        try {
            $sum = (Get-ChildItem -LiteralPath $dir.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
                    Measure-Object Length -Sum).Sum
            if ($sum) { $sz = $sum }
        } catch {}

        if (& $removeSafely $dir.FullName $true) {
            $junkFolderCount++
            $bytesReclaimed += $sz
            Send-Progress $OnProgress @{ Type='log'; Level='detail'; Message="$dryPrefix junk folder ($([math]::Round($sz/1KB,1)) KB): $($dir.FullName)" }
        } else {
            $failed++
            Send-Progress $OnProgress @{ Type='log'; Level='warn'; Message="FAILED to remove folder: $($dir.FullName)" }
        }

        Send-Progress $OnProgress @{ Type='progress'; Phase='cleanup'; Current=$i; Total=$total; Name=$dir.Name; BytesProcessed=$bytesReclaimed }
    }

    # Phase 2: junk and small files
    if (-not $cancelled) {
        foreach ($file in $candidateFiles) {
            if (Test-Cancelled $CancelToken) { $cancelled = $true; break }
            $i++
            if (-not (Test-Path -LiteralPath $file.FullName)) {
                Send-Progress $OnProgress @{ Type='progress'; Phase='cleanup'; Current=$i; Total=$total; Name=$file.Name; BytesProcessed=$bytesReclaimed }
                continue
            }

            $isJunk = & $testJunkFile $file
            $reason = if ($isJunk) { 'junk-name' } else { "<${MinSizeKB}KB" }
            if (& $removeSafely $file.FullName $false) {
                if ($isJunk) { $junkFileCount++ } else { $smallFileCount++ }
                $bytesReclaimed += $file.Length
                Send-Progress $OnProgress @{ Type='log'; Level='detail'; Message=("{0} ({1}, {2} B): {3}" -f $dryPrefix, $reason, $file.Length, $file.FullName) }
            } else {
                $failed++
                Send-Progress $OnProgress @{ Type='log'; Level='warn'; Message="FAILED to remove: $($file.FullName)" }
            }

            Send-Progress $OnProgress @{ Type='progress'; Phase='cleanup'; Current=$i; Total=$total; Name=$file.Name; BytesProcessed=$bytesReclaimed }
        }
    }

    # Phase 3: empty folders
    if (-not $cancelled -and -not $SkipEmptyFolderCleanup) {
        $allDirs = @(Get-ChildItem -LiteralPath $Root -Recurse -Directory -Force -ErrorAction SilentlyContinue |
                     Sort-Object { $_.FullName.Length } -Descending)
        foreach ($dir in $allDirs) {
            if (Test-Cancelled $CancelToken) { $cancelled = $true; break }
            if (-not (Test-Path -LiteralPath $dir.FullName)) { continue }
            if ($dir.FullName -ieq $ImagesDir -or $dir.FullName -ieq $VideosDir) { continue }

            $hasContent = $false
            try {
                $hasContent = (Get-ChildItem -LiteralPath $dir.FullName -Force -ErrorAction Stop | Measure-Object).Count -gt 0
            } catch { continue }
            if ($hasContent) { continue }

            if (& $removeSafely $dir.FullName $true) {
                $emptyFolderCount++
                Send-Progress $OnProgress @{ Type='log'; Level='detail'; Message="$dryPrefix empty folder: $($dir.FullName)" }
            } else {
                $failed++
            }
        }
    }

    $result = [pscustomobject]@{
        Phase='cleanup'
        JunkFileCount=$junkFileCount; SmallFileCount=$smallFileCount
        JunkFolderCount=$junkFolderCount; EmptyFolderCount=$emptyFolderCount
        BytesReclaimed=$bytesReclaimed; Failed=$failed
        DryRun=[bool]$DryRun; Cancelled=$cancelled
    }
    Send-Progress $OnProgress @{ Type='phase-done'; Phase='cleanup'; Summary=$result }
    return $result
}

Export-ModuleMember -Function Invoke-MoveMedia, Invoke-SortMediaByYear, Invoke-CleanupJunk,
                              Get-MediaImageExtensions, Get-MediaVideoExtensions

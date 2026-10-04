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
      'transfer'   -- one file moved/copied/sorted (Source, Target, Size,
                      Action, Kind, Status='OK'|'DRY'|'FAILED', Error,
                      and Year/DateSource for sort). Feed these to
                      Register-MediaTransfer, then Write-MediaTransferLog.
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

# The version lives only in MediaTools.psd1 (ModuleVersion). The scripts
# import this .psm1 directly, so read the manifest next to it.
$script:MediaSortVersion = '0.0.0'
try {
    $script:MediaSortVersion = (Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot 'MediaTools.psd1')).ModuleVersion
} catch { }
function Get-MediaSortVersion { return $script:MediaSortVersion }

# --- Helpers ----------------------------------------------------------------

function Get-UniquePath {
    # $Reserved (optional HashSet) holds paths already claimed in this run,
    # so dry runs predict the same renames a real run would make.
    param([string]$Dir, [string]$Name, $Reserved)
    $taken = { param($p) (Test-Path -LiteralPath $p) -or ($Reserved -and $Reserved.Contains($p)) }
    $dest = Join-Path $Dir $Name
    if (-not (& $taken $dest)) { if ($Reserved) { [void]$Reserved.Add($dest) }; return $dest }
    $base = [IO.Path]::GetFileNameWithoutExtension($Name)
    $ext  = [IO.Path]::GetExtension($Name)
    $i = 1
    while ($true) {
        $candidate = Join-Path $Dir ("{0}_{1}{2}" -f $base, $i, $ext)
        if (-not (& $taken $candidate)) { if ($Reserved) { [void]$Reserved.Add($candidate) }; return $candidate }
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

# --- Date-named folders -----------------------------------------------------

function Test-DateFolderName {
    # True when a folder name is ONLY a date, e.g. 2024-07-03, 2024_07_03,
    # 2024.07.03, 20240703, 2024-07, 03.07.2024, 3-7-24.
    # Names with extra text ("2024-07-03 Holiday") are not date folders.
    param([string]$Name)
    $n = $Name.Trim()
    # year-month(-day), separator - _ . space or none
    if ($n -match '^(19|20)\d{2}[-_. ]?(0[1-9]|1[0-2])([-_. ]?(0[1-9]|[12]\d|3[01]))?$') { return $true }
    # day.month.year
    if ($n -match '^(0?[1-9]|[12]\d|3[01])[-_. ](0?[1-9]|1[0-2])[-_. ]((19|20)\d{2}|\d{2})$') { return $true }
    return $false
}

# --- Find-MediaDuplicates ---------------------------------------------------
#
# Finds files with byte-for-byte identical content. Only files that share a
# size with another file are read: first the first 64 KB are hashed, and only
# files that still match are hashed in full (MD5 -- used to compare content,
# not for security).
#
# Which copy is kept in each group:
#   1. a file that is already in the output folder,
#   2. else the oldest modified date,
#   3. else the shortest path (then alphabetical).

function Get-FileContentHash {
    param([string]$Path, $Algorithm, [int]$Limit = 0)
    $fs = [IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite')
    try {
        if ($Limit -gt 0) {
            $buf = New-Object byte[] $Limit
            $n = 0
            while ($n -lt $Limit) {
                $r = $fs.Read($buf, $n, $Limit - $n)
                if ($r -le 0) { break }
                $n += $r
            }
            $h = $Algorithm.ComputeHash($buf, 0, $n)
        } else {
            $h = $Algorithm.ComputeHash($fs)
        }
    } finally { $fs.Dispose() }
    return [BitConverter]::ToString($h).Replace('-', '')
}

function Find-MediaDuplicates {
    param(
        [System.IO.FileInfo[]]$SourceFiles = @(),
        [System.IO.FileInfo[]]$OutputFiles = @(),
        [scriptblock]$OnProgress,
        [hashtable]$CancelToken
    )

    $headSize = 64KB
    try { $alg = [Security.Cryptography.MD5]::Create() } catch { $alg = [Security.Cryptography.SHA256]::Create() }

    $entries = @(
        foreach ($f in $SourceFiles) { [pscustomobject]@{ File = $f; Location = 'source' } }
        foreach ($f in $OutputFiles) { [pscustomobject]@{ File = $f; Location = 'output' } }
    )
    $sizeGroups = @($entries | Where-Object { $_.File.Length -gt 0 } |
                    Group-Object { $_.File.Length } | Where-Object { $_.Count -gt 1 })
    $candidateCount = ($sizeGroups | Measure-Object -Property Count -Sum).Sum
    if (-not $candidateCount) { $candidateCount = 0 }

    Send-Progress $OnProgress @{ Type='phase'; Phase='dupscan'; Message="Checking $($entries.Count) files for duplicates ($candidateCount share a size with another file)" }
    Send-Progress $OnProgress @{ Type='scan-done'; Phase='dupscan'; Total=$candidateCount; TotalBytes=0 }

    $groups = New-Object System.Collections.Generic.List[object]
    $done = 0
    $cancelled = $false

    $hashAll = {
        param($items, [int]$limit)
        foreach ($e in $items) {
            try { $e | Add-Member -NotePropertyName Hash -NotePropertyValue (Get-FileContentHash -Path $e.File.FullName -Algorithm $alg -Limit $limit) -Force }
            catch {
                $e | Add-Member -NotePropertyName Hash -NotePropertyValue $null -Force
                Send-Progress $OnProgress @{ Type='log'; Level='warn'; Message="Could not read for duplicate check: $($e.File.FullName) -- $($_.Exception.Message)" }
            }
        }
    }

    foreach ($sg in $sizeGroups) {
        if (Test-Cancelled $CancelToken) { $cancelled = $true; break }
        $size = [long]$sg.Name

        # Stage 1: first 64 KB.  Stage 2 (bigger files only): whole file.
        & $hashAll $sg.Group $headSize
        foreach ($hg in ($sg.Group | Where-Object { $_.Hash } | Group-Object Hash | Where-Object { $_.Count -gt 1 })) {
            $matched = @($hg.Group)
            if ($size -gt $headSize) {
                if (Test-Cancelled $CancelToken) { $cancelled = $true; break }
                Send-Progress $OnProgress @{ Type='progress'; Phase='dupscan'; Current=$done; Total=$candidateCount; Name="Comparing $($matched[0].File.Name) ($(Format-MediaSize $size))" }
                & $hashAll $matched 0
            }
            foreach ($fg in ($matched | Where-Object { $_.Hash } | Group-Object Hash | Where-Object { $_.Count -gt 1 })) {
                $ordered = @($fg.Group | Sort-Object @{ Expression = { if ($_.Location -eq 'output') { 0 } else { 1 } } },
                                                     @{ Expression = { $_.File.LastWriteTime } },
                                                     @{ Expression = { $_.File.FullName.Length } },
                                                     @{ Expression = { $_.File.FullName } })
                $members = @(for ($k = 0; $k -lt $ordered.Count; $k++) {
                    $e = $ordered[$k]
                    $keep = ($k -eq 0)
                    [pscustomobject]@{
                        Path     = $e.File.FullName
                        Folder   = $e.File.DirectoryName
                        Name     = $e.File.Name
                        Size     = $e.File.Length
                        Modified = $e.File.LastWriteTime
                        Location = $e.Location
                        Keep     = $keep
                        Action   = $(if ($keep) { if ($e.Location -eq 'output') { 'Kept (already in output folder)' } else { 'Kept' } }
                                     elseif ($e.Location -eq 'output') { 'Already in output folder (not changed)' }
                                     else { 'Transferred anyway (scan only)' })
                    }
                })
                $groups.Add([pscustomobject]@{ Hash = $fg.Name; Size = $size; Members = $members; Keeper = $members[0] })
            }
        }
        if ($cancelled) { break }

        $done += $sg.Count
        Send-Progress $OnProgress @{ Type='progress'; Phase='dupscan'; Current=$done; Total=$candidateCount; Name=$sg.Group[0].File.Name }
    }
    $alg.Dispose()

    $extraCount = ($groups | ForEach-Object { $_.Members.Count - 1 } | Measure-Object -Sum).Sum
    Send-Progress $OnProgress @{ Type='log'; Level='info'; Message=("Duplicate check: {0} group(s), {1} extra cop{2}." -f $groups.Count, [int]$extraCount, $(if ($extraCount -eq 1) { 'y' } else { 'ies' })) }

    return [pscustomobject]@{
        Groups = $groups.ToArray(); Checked = $entries.Count; Candidates = $candidateCount; Cancelled = $cancelled
    }
}

function Test-RecycleBinAvailable {
    # USB sticks, memory cards and network shares have no Recycle Bin;
    # deleting there would be permanent.
    param([string]$Path)
    if ($Path.StartsWith('\\')) { return $false }
    try {
        $drive = New-Object IO.DriveInfo ([IO.Path]::GetPathRoot($Path))
        return ($drive.DriveType -eq [IO.DriveType]::Fixed)
    } catch { return $false }
}

# --- Invoke-MoveMedia -------------------------------------------------------

function Invoke-MoveMedia {
    <#
        Gathers media from $Root (recursively) into destination folders.
          -OutputRoot   : where the destination folders are created.
                          Defaults to $Root (the parent/source folder).
          -Copy         : copy files instead of moving them.
          -KeepTogether : put images and videos in one folder
                          ($TogetherFolderName) instead of images\ + videos\.
          -KeepParentFolder : place each file in a subfolder named after
                          the folder it came from, e.g.
                          D:\Photos\Holiday\a.jpg -> images\Holiday\a.jpg
                          (Invoke-SortMediaByYear -KeepParentFolder then
                          turns that into images\2019\Holiday\a.jpg).
          -SkipDateFolders : with -KeepParentFolder, do not keep folder
                          names that are only a date (2024-07-03, 20240703,
                          03.07.2024, ...); those files go straight to the
                          year folder.
          -FindDuplicates   : check for files with identical content (in the
                          source and already in the output folders) and
                          report them in a 'duplicates' event.
          -RemoveDuplicates : implies -FindDuplicates. Extra copies are not
                          transferred: with -Copy they are skipped, otherwise
                          they are sent to the Recycle Bin (left in place on
                          drives without one). This only happens after the
                          kept copy was transferred successfully.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Root,
        [string]$OutputRoot,
        [switch]$Copy,
        [switch]$KeepTogether,
        [string]$TogetherFolderName='media',
        [switch]$KeepParentFolder,
        [switch]$SkipDateFolders,
        [switch]$FindDuplicates,
        [switch]$RemoveDuplicates,
        [switch]$DryRun,
        [string[]]$ImageExtensions,
        [string[]]$VideoExtensions,
        [scriptblock]$OnProgress,
        [hashtable]$CancelToken
    )

    if (-not (Test-Path -LiteralPath $Root)) { throw "Root folder not found: $Root" }
    $Root = (Resolve-Path -LiteralPath $Root).Path

    if (-not $OutputRoot) { $OutputRoot = $Root }
    if (Test-Path -LiteralPath $OutputRoot) {
        $OutputRoot = (Resolve-Path -LiteralPath $OutputRoot).Path
    } else {
        $OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
    }

    if (-not $ImageExtensions) { $ImageExtensions = $script:ImageExt }
    if (-not $VideoExtensions) { $VideoExtensions = $script:VideoExt }
    $ImageExtensions = Normalize-Extensions $ImageExtensions
    $VideoExtensions = Normalize-Extensions $VideoExtensions

    if ($KeepTogether) {
        $ImagesDest = [IO.Path]::Combine($OutputRoot, $TogetherFolderName)
        $VideosDest = $ImagesDest
    } else {
        $ImagesDest = [IO.Path]::Combine($OutputRoot, 'images')
        $VideosDest = [IO.Path]::Combine($OutputRoot, 'videos')
    }
    $destDirs = @(@($ImagesDest, $VideosDest) | Select-Object -Unique)
    $sep = [IO.Path]::DirectorySeparatorChar
    $verb = if ($Copy) { 'Copied' } else { 'Moved' }
    $modeName = if ($Copy) { 'copy' } else { 'move' }

    Send-Progress $OnProgress @{ Type='phase'; Phase='move'; Message="Scanning $Root for media to consolidate" }
    Send-Progress $OnProgress @{ Type='log'; Level='info'; Message="Output: $($destDirs -join ', ')  (mode: $modeName)" }
    Send-Progress $OnProgress @{ Type='log'; Level='info'; Message="Image extensions: $($ImageExtensions -join ', ')" }
    Send-Progress $OnProgress @{ Type='log'; Level='info'; Message="Video extensions: $($VideoExtensions -join ', ')" }

    $allFiles = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object {
        $ext  = $_.Extension.ToLower()
        $full = $_.FullName
        $insideDest = $false
        foreach ($d in $destDirs) {
            if ($full.StartsWith($d + $sep, [StringComparison]::OrdinalIgnoreCase)) { $insideDest = $true; break }
        }
        ($ImageExtensions -contains $ext -or $VideoExtensions -contains $ext) -and -not $insideDest
    })
    $total = $allFiles.Count
    $totalBytes = ($allFiles | Measure-Object -Property Length -Sum).Sum
    if (-not $totalBytes) { $totalBytes = 0 }

    Send-Progress $OnProgress @{ Type='scan-done'; Phase='move'; Total=$total; TotalBytes=$totalBytes }

    # --- Duplicates ---
    if ($RemoveDuplicates) { $FindDuplicates = $true }
    $dupResult = $null
    $extras  = @{}    # source path -> its duplicate group (copies that are not kept)
    $members = @{}    # path -> group member (to record what happened)
    $groupOf = @{}    # path -> group, for every member
    $safeCopy = @{}   # group hash -> path of a copy that is safely in the output
    $neededBytes = $totalBytes
    if ($FindDuplicates -and $total -gt 0) {
        $existing = @(foreach ($d in $destDirs) {
            if (Test-Path -LiteralPath $d) {
                Get-ChildItem -LiteralPath $d -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object {
                    $e = $_.Extension.ToLower(); $ImageExtensions -contains $e -or $VideoExtensions -contains $e }
            }
        })
        $dupResult = Find-MediaDuplicates -SourceFiles $allFiles -OutputFiles $existing -OnProgress $OnProgress -CancelToken $CancelToken
        foreach ($g in $dupResult.Groups) {
            foreach ($m in $g.Members) {
                $members[$m.Path] = $m
                $groupOf[$m.Path] = $g
                if ($m.Keep -and $m.Location -eq 'output') { $safeCopy[$g.Hash] = $m.Path }
                if ($RemoveDuplicates -and -not $m.Keep -and $m.Location -eq 'source') {
                    $extras[$m.Path] = $g
                    $neededBytes -= $m.Size
                }
            }
        }
        # Kept copies go first, so an extra copy is only removed once its kept copy is safe.
        if ($extras.Count -gt 0) {
            $allFiles = @($allFiles | Where-Object { -not $extras.ContainsKey($_.FullName) }) +
                        @($allFiles | Where-Object { $extras.ContainsKey($_.FullName) })
        }
        Send-Progress $OnProgress @{ Type='phase'; Phase='move'; Message="$(if ($Copy) { 'Copying' } else { 'Moving' }) $total files" }
        Send-Progress $OnProgress @{ Type='scan-done'; Phase='move'; Total=$total; TotalBytes=$totalBytes }
    }

    # Copying, or moving to another drive, needs room on the destination drive.
    $sameVolume = ([IO.Path]::GetPathRoot($Root) -ieq [IO.Path]::GetPathRoot($OutputRoot))
    if (-not $DryRun -and $total -gt 0 -and ($Copy -or -not $sameVolume) -and -not (Test-Cancelled $CancelToken)) {
        $drive = $null
        try { $drive = New-Object IO.DriveInfo ([IO.Path]::GetPathRoot($OutputRoot)) } catch { }
        if ($drive -and $drive.IsReady -and $drive.AvailableFreeSpace -lt $neededBytes) {
            throw ("Not enough free space on {0}: need {1:N1} MB, available {2:N1} MB." -f
                   $drive.Name, ($neededBytes / 1MB), ($drive.AvailableFreeSpace / 1MB))
        }
    }

    if (-not $DryRun -and $total -gt 0) {
        foreach ($d in $destDirs) {
            if (-not (Test-Path -LiteralPath $d)) {
                New-Item -ItemType Directory -Path $d -Force | Out-Null
                Send-Progress $OnProgress @{ Type='log'; Level='info'; Message="Created folder: $d" }
            }
        }
    }

    $imgCount = 0; $vidCount = 0; $failed = 0; $bytesProcessed = 0
    $dupHandled = 0; $dupBytes = 0
    if (-not $Copy -and -not $DryRun -and $extras.Count -gt 0) {
        Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue
    }
    $planned = if ($DryRun) { New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase) } else { $null }
    $i = 0
    $cancelled = $false

    foreach ($file in $allFiles) {
        if (Test-Cancelled $CancelToken) { $cancelled = $true; break }
        $i++

        $isImage = $ImageExtensions -contains $file.Extension.ToLower()

        # Extra copy of a duplicate: skip / recycle it, but only if the kept copy is safe.
        if ($extras.ContainsKey($file.FullName)) {
            $g = $extras[$file.FullName]
            $member = $members[$file.FullName]
            # Normally the kept copy; if that failed, the first copy that did get through.
            if ($safeCopy.ContainsKey($g.Hash)) {
                $safePath = $safeCopy[$g.Hash]
                $status = if ($DryRun) { 'DRY' } else { 'OK' }; $errMsg = $null
                if ($Copy) {
                    $dupAction = 'NotCopied'
                    $member.Action = if ($DryRun) { 'Would not be copied' } else { 'Not copied' }
                } elseif (-not (Test-RecycleBinAvailable $file.FullName)) {
                    $dupAction = 'LeftInPlace'
                    $member.Action = 'Left in place (no Recycle Bin on this drive)'
                } elseif ($DryRun) {
                    $dupAction = 'Recycle'
                    $member.Action = 'Would be sent to the Recycle Bin'
                } else {
                    $dupAction = 'Recycle'
                    try {
                        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($file.FullName,
                            [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                            [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
                        $member.Action = 'Sent to the Recycle Bin'
                    } catch {
                        $status = 'FAILED'; $errMsg = $_.Exception.Message; $failed++
                        $member.Action = "Recycle Bin FAILED: $errMsg"
                    }
                }
                if ($status -ne 'FAILED') { $dupHandled++; $dupBytes += $file.Length }
                Send-Progress $OnProgress @{ Type='log'; Level=$(if ($status -eq 'FAILED') { 'warn' } else { 'detail' })
                    Message="Duplicate ($($member.Action)): $($file.FullName)  ==  $safePath" }
                Send-Progress $OnProgress @{
                    Type='transfer'; Phase='move'; Action='Duplicate'; DupAction=$dupAction
                    Source=$file.FullName; Target=$null; Size=$file.Length
                    Kind=$(if ($isImage) { 'image' } else { 'video' })
                    DuplicateOf=$safePath; Status=$status; Error=$errMsg
                }
                $bytesProcessed += $file.Length
                Send-Progress $OnProgress @{ Type='progress'; Phase='move'; Current=$i; Total=$total; Name=$file.Name
                                             BytesProcessed=$bytesProcessed; TotalBytes=$totalBytes }
                continue
            }
            $member.Action = 'Transferred (the kept copy could not be transferred)'
        }

        $dest = if ($isImage) { $ImagesDest } else { $VideosDest }
        if ($KeepParentFolder -and $file.Directory.Parent -and
            -not ($SkipDateFolders -and (Test-DateFolderName $file.Directory.Name))) {
            # Files at a drive root have no folder name to keep.
            $dest = [IO.Path]::Combine($dest, $file.Directory.Name)
            if (-not $DryRun -and -not (Test-Path -LiteralPath $dest)) {
                New-Item -ItemType Directory -Path $dest -Force | Out-Null
            }
        }
        $target = Get-UniquePath -Dir $dest -Name $file.Name -Reserved $planned

        $success = $true
        $status = 'OK'; $errMsg = $null
        if ($DryRun) {
            $status = 'DRY'
            Send-Progress $OnProgress @{ Type='log'; Level='detail'; Message="[DRY] $($file.FullName) -> $target" }
        } else {
            try {
                if ($Copy) {
                    Copy-Item -LiteralPath $file.FullName -Destination $target -Force -ErrorAction Stop
                    # Keep the original timestamps so Sort by year still sees the real dates.
                    try {
                        $copied = Get-Item -LiteralPath $target -Force
                        $copied.CreationTime  = $file.CreationTime
                        $copied.LastWriteTime = $file.LastWriteTime
                    } catch { }
                } else {
                    Move-Item -LiteralPath $file.FullName -Destination $target -Force -ErrorAction Stop
                }
                Send-Progress $OnProgress @{ Type='log'; Level='detail'; Message="${verb}: $($file.FullName) -> $target" }
            } catch {
                Send-Progress $OnProgress @{ Type='log'; Level='warn'; Message="FAILED: $($file.FullName) -- $($_.Exception.Message)" }
                $failed++
                $success = $false
                $status = 'FAILED'; $errMsg = $_.Exception.Message
                if ($members.ContainsKey($file.FullName)) {
                    $members[$file.FullName].Action = "Could not be transferred (stays in source): $errMsg"
                }
            }
        }

        Send-Progress $OnProgress @{
            Type='transfer'; Phase='move'; Action=$(if ($Copy) { 'Copy' } else { 'Move' })
            Source=$file.FullName; Target=$target; Size=$file.Length
            Kind=$(if ($isImage) { 'image' } else { 'video' })
            Status=$status; Error=$errMsg
        }

        if ($success) {
            if ($isImage) { $imgCount++ } else { $vidCount++ }
            if ($groupOf.ContainsKey($file.FullName)) {
                $hash = $groupOf[$file.FullName].Hash
                if (-not $safeCopy.ContainsKey($hash)) { $safeCopy[$hash] = $file.FullName }
            }
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
        Copy=[bool]$Copy; KeepTogether=[bool]$KeepTogether; KeepParentFolder=[bool]$KeepParentFolder
        SkipDateFolders=[bool]$SkipDateFolders
        OutputFolders=$destDirs
        DuplicateGroups=$(if ($dupResult) { $dupResult.Groups.Count } else { 0 })
        DuplicatesRemoved=$dupHandled; DuplicateBytes=$dupBytes
        DryRun=[bool]$DryRun; Cancelled=($cancelled -or [bool]($dupResult -and $dupResult.Cancelled))
    }
    if ($dupResult) {
        Send-Progress $OnProgress @{
            Type='duplicates'; Groups=$dupResult.Groups; Checked=$dupResult.Checked
            Mode=$(if (-not $RemoveDuplicates) { 'scan' } elseif ($Copy) { 'remove-copy' } else { 'remove-move' })
            DryRun=[bool]$DryRun; Cancelled=$result.Cancelled
        }
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
        [switch]$KeepParentFolder,
        [switch]$SkipDateFolders,
        [scriptblock]$OnProgress,
        [hashtable]$CancelToken
    )
    # -KeepParentFolder: also sort files one level down (in folders made by
    # Invoke-MoveMedia -KeepParentFolder) and keep that folder's name:
    #   images\Holiday\a.jpg -> images\2019\Holiday\a.jpg
    # Folders that already look like year folders (or Unknown) are skipped.
    # -SkipDateFolders: a subfolder named only by a date (2024-07-03) is
    # emptied into the year folder instead of being kept.

    if (-not (Test-Path -LiteralPath $Root)) { throw "Root folder not found: $Root" }
    $Root = (Resolve-Path -LiteralPath $Root).Path

    $allMediaExt = $script:ImageExt + $script:VideoExt
    $isMedia = { param($f) $allMediaExt -contains $f.Extension.ToLower() }

    Send-Progress $OnProgress @{ Type='phase'; Phase='sort'; Message="Scanning $Root for media to sort by year" }

    $allFiles = @(Get-ChildItem -LiteralPath $Root -File -Force -ErrorAction SilentlyContinue | Where-Object { & $isMedia $_ })
    $parentDirs = @()
    if ($KeepParentFolder) {
        $parentDirs = @(Get-ChildItem -LiteralPath $Root -Directory -Force -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -notmatch '^\d{4}$' -and $_.Name -ine $UnknownFolderName
        })
        foreach ($d in $parentDirs) {
            $allFiles += @(Get-ChildItem -LiteralPath $d.FullName -File -Force -ErrorAction SilentlyContinue | Where-Object { & $isMedia $_ })
        }
    }
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
    $nsCache = @{}
    $planned = if ($DryRun) { New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase) } else { $null }
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
            $ns = $shellFolder
            if ($file.DirectoryName -ine $Root) {
                if (-not $nsCache.ContainsKey($file.DirectoryName)) { $nsCache[$file.DirectoryName] = $shell.Namespace($file.DirectoryName) }
                $ns = $nsCache[$file.DirectoryName]
            }
            $item = if ($ns) { $ns.ParseName($file.Name) } else { $null }
            $idx = if ($script:ImageExt -contains $ext) { $dateTakenIdx } else { $mediaCreatedIdx }
            if ($item -and $idx -ge 0) {
                $raw = $ns.GetDetailsOf($item, $idx)
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
        if ($file.DirectoryName -ine $Root -and
            -not ($SkipDateFolders -and (Test-DateFolderName $file.Directory.Name))) {
            $destFolder = Join-Path $destFolder $file.Directory.Name
        }

        if (-not (Test-Path -LiteralPath $destFolder) -and -not $DryRun) {
            New-Item -ItemType Directory -Path $destFolder | Out-Null
        }

        $target = Get-UniquePath -Dir $destFolder -Name $file.Name -Reserved $planned
        $success = $true
        $status = 'OK'; $errMsg = $null

        if ($DryRun) {
            $status = 'DRY'
            Send-Progress $OnProgress @{ Type='log'; Level='detail'; Message="[DRY] $($file.Name) -> $yearKey\ ($source)" }
        } else {
            try {
                Move-Item -LiteralPath $file.FullName -Destination $target -Force -ErrorAction Stop
                Send-Progress $OnProgress @{ Type='log'; Level='detail'; Message="Sorted: $($file.Name) -> $yearKey\ ($source)" }
            } catch {
                Send-Progress $OnProgress @{ Type='log'; Level='warn'; Message="FAILED: $($file.FullName) -- $($_.Exception.Message)" }
                $failed++
                $success = $false
                $status = 'FAILED'; $errMsg = $_.Exception.Message
            }
        }

        Send-Progress $OnProgress @{
            Type='transfer'; Phase='sort'; Action='Move'
            Source=$file.FullName; Target=$target; Size=$file.Length
            Kind=$(if ($script:ImageExt -contains $ext) { 'image' } else { 'video' })
            Year=$yearKey; DateSource=$source
            Status=$status; Error=$errMsg
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

    # Remove the parent-name folders this sort has emptied.
    if (-not $DryRun) {
        foreach ($d in $parentDirs) {
            try {
                if ((Get-ChildItem -LiteralPath $d.FullName -Force -ErrorAction Stop | Measure-Object).Count -eq 0) {
                    Remove-Item -LiteralPath $d.FullName -Force -ErrorAction Stop
                }
            } catch { }
        }
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
    $MediaDir  = Join-Path $Root 'media'
    $sep = [IO.Path]::DirectorySeparatorChar

    $testInside = {
        param($Path)
        return ($Path.StartsWith($ImagesDir + $sep, [StringComparison]::OrdinalIgnoreCase) -or
                $Path.StartsWith($VideosDir + $sep, [StringComparison]::OrdinalIgnoreCase) -or
                $Path.StartsWith($MediaDir + $sep, [StringComparison]::OrdinalIgnoreCase))
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
        # Never remove the transfer-log copies MediaSort saves next to the files.
        if ($_.Name -like 'MediaSort-Transfers-*.txt') { return $false }
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
            if ($dir.FullName -ieq $ImagesDir -or $dir.FullName -ieq $VideosDir -or $dir.FullName -ieq $MediaDir) { continue }

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

# --- Transfer log -----------------------------------------------------------
#
# Collects the 'transfer' events sent by Invoke-MoveMedia and
# Invoke-SortMediaByYear, and writes them as a readable per-file report.
# When sort moves a file that consolidate placed earlier in the same run,
# the existing record is updated so the report shows the final location.

function New-MediaTransferStore {
    return @{ Records = New-Object System.Collections.Generic.List[object]; Index = @{} }
}

function Register-MediaTransfer {
    param([Parameter(Mandatory)][hashtable]$Store, [Parameter(Mandatory)][hashtable]$Transfer)

    if ($Transfer.Phase -eq 'sort' -and $Store.Index.ContainsKey($Transfer.Source)) {
        $rec = $Store.Index[$Transfer.Source]
        if ($Transfer.Status -eq 'FAILED') { $rec.Note = "sort by year failed: $($Transfer.Error)"; return }
        $Store.Index.Remove($Transfer.Source)
        $rec.Target     = $Transfer.Target
        $rec.Year       = $Transfer.Year
        $rec.DateSource = $Transfer.DateSource
        $Store.Index[$Transfer.Target] = $rec
        return
    }

    $rec = [pscustomobject]@{
        Source=$Transfer.Source; Target=$Transfer.Target; Size=[int64]$Transfer.Size
        Kind=$Transfer.Kind; Action=$Transfer.Action; Phase=$Transfer.Phase
        Status=$Transfer.Status; Error=$Transfer.Error
        Year=$Transfer.Year; DateSource=$Transfer.DateSource; Note=$null
        DupAction=$Transfer.DupAction; DuplicateOf=$Transfer.DuplicateOf
    }
    $Store.Records.Add($rec)
    if ($Transfer.Status -ne 'FAILED' -and $Transfer.Target) { $Store.Index[$Transfer.Target] = $rec }
}

function Format-MediaSize {
    param([double]$Bytes)
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N1} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N0} KB' -f ($Bytes / 1KB)) }
    return ('{0:N0} B' -f $Bytes)
}

function Write-MediaTransferLog {
    <#
        -Info         : ordered hashtable of header lines (label -> value),
                        e.g. [ordered]@{ 'Source' = 'D:\Photos'; 'Output' = 'E:\' }
        -CopyToFolder : also save a copy, named MediaSort-<file name>, in this
                        folder (normally the output folder, next to the
                        transferred files). Skipped when no file was actually
                        moved or copied (e.g. a dry run) or the folder is missing.
        Returns @{ Path = <log>; CopyPath = <copy or $null> }
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][hashtable]$Store,
        [System.Collections.IDictionary]$Info = [ordered]@{},
        [string]$CopyToFolder
    )

    $recs = $Store.Records.ToArray()
    $ok   = @($recs | Where-Object { $_.Status -ne 'FAILED' -and $_.Action -ne 'Duplicate' })
    $dups = @($recs | Where-Object { $_.Status -ne 'FAILED' -and $_.Action -eq 'Duplicate' })
    $fail = @($recs | Where-Object { $_.Status -eq 'FAILED' })
    $dry  = @($recs | Where-Object { $_.Status -eq 'DRY' })

    $copyPath = $null
    $transferred = @($recs | Where-Object { $_.Status -eq 'OK' }).Count -gt 0
    if ($CopyToFolder -and $transferred -and (Test-Path -LiteralPath $CopyToFolder)) {
        $copyPath = Join-Path $CopyToFolder ('MediaSort-' + [IO.Path]::GetFileName($Path))
    }

    $out  = New-Object System.Collections.Generic.List[string]
    $wide = '=' * 76
    $thin = '-' * 76
    $sum  = { param($items) $s = ($items | Measure-Object -Property Size -Sum).Sum; if ($s) { $s } else { 0 } }
    $section = { param($title) $out.Add(''); $out.Add($thin); $out.Add("  $title"); $out.Add($thin); $out.Add('') }

    # Header
    $out.Add($wide)
    $out.Add("  MediaSort $script:MediaSortVersion -- Transfer Log")
    $out.Add($wide)
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
    $header = [ordered]@{}
    foreach ($k in $Info.Keys) { $header[$k] = $Info[$k] }
    $header['Computer / user'] = "$env:COMPUTERNAME / $env:USERNAME$(if ($isAdmin) { ' (Administrator)' })"
    $header['Log file']        = $Path
    if ($copyPath) { $header['Copy with files'] = $copyPath }
    foreach ($k in $header.Keys) {
        if ($null -ne $header[$k] -and "$($header[$k])" -ne '') { $out.Add(('  {0,-16}: {1}' -f $k, $header[$k])) }
    }
    if ($dry.Count -gt 0) {
        $out.Add('')
        $out.Add('  NOTE: "WOULD ..." entries come from a dry run -- those files were NOT changed.')
    }

    # Summary
    & $section 'SUMMARY'
    $imgs = @($ok | Where-Object { $_.Kind -eq 'image' })
    $vids = @($ok | Where-Object { $_.Kind -eq 'video' })
    $renamed = @($ok | Where-Object { [IO.Path]::GetFileName($_.Source) -ne [IO.Path]::GetFileName($_.Target) })
    $out.Add(('  Files handled   : {0,7:N0}   {1,10}' -f $ok.Count, (Format-MediaSize (& $sum $ok))))
    $out.Add(('    Images        : {0,7:N0}   {1,10}' -f $imgs.Count, (Format-MediaSize (& $sum $imgs))))
    $out.Add(('    Videos        : {0,7:N0}   {1,10}' -f $vids.Count, (Format-MediaSize (& $sum $vids))))
    $actionLabels = [ordered]@{ 'Move|OK'='Moved'; 'Copy|OK'='Copied'; 'Move|DRY'='Would move'; 'Copy|DRY'='Would copy' }
    foreach ($key in $actionLabels.Keys) {
        $a, $st = $key -split '\|'
        $n = @($ok | Where-Object { $_.Action -eq $a -and $_.Status -eq $st }).Count
        if ($n -gt 0) { $out.Add(('  {0,-15} : {1,7:N0}' -f $actionLabels[$key], $n)) }
    }
    $out.Add(('  Renamed         : {0,7:N0}   (a file with the same name already existed)' -f $renamed.Count))
    if ($dups.Count -gt 0) {
        $out.Add(('  Duplicates      : {0,7:N0}   {1,10}   (identical to a file that was kept)' -f $dups.Count, (Format-MediaSize (& $sum $dups))))
        $dupLabels = [ordered]@{ 'NotCopied' = 'not copied'; 'Recycle' = 'to Recycle Bin'; 'LeftInPlace' = 'left in place' }
        foreach ($k in $dupLabels.Keys) {
            $n = @($dups | Where-Object { $_.DupAction -eq $k }).Count
            if ($n -gt 0) { $out.Add(('    {0,-14}: {1,7:N0}' -f $dupLabels[$k], $n)) }
        }
    }
    $out.Add(('  Failed          : {0,7:N0}' -f $fail.Count))
    $dated = @($ok | Where-Object { $_.Year })
    if ($dated.Count -gt 0) {
        $meta    = @($dated | Where-Object { $_.DateSource -eq 'metadata' }).Count
        $unknown = @($dated | Where-Object { $_.Year -notmatch '^\d{4}$' }).Count
        $out.Add(('  Year taken from : metadata {0:N0}, file date {1:N0}  (unknown year: {2:N0})' -f
                  $meta, ($dated.Count - $meta), $unknown))
    }

    if ($ok.Count -gt 0) {
        $out.Add('')
        $out.Add('  By destination folder:')
        foreach ($g in ($ok | Group-Object { [IO.Path]::GetDirectoryName($_.Target) } | Sort-Object Name)) {
            $out.Add(('    {0,7:N0} {1,-5}  {2,10}   {3}' -f $g.Count, $(if ($g.Count -eq 1) { 'file' } else { 'files' }), (Format-MediaSize (& $sum $g.Group)), $g.Name))
        }
    }

    # Per-file detail, grouped by original folder
    & $section 'FILES  (grouped by original folder)'
    if ($recs.Count -eq 0) { $out.Add('  No files were moved or copied.') }
    $nameWidth = [math]::Min(40, [math]::Max(4, ($recs | ForEach-Object { [IO.Path]::GetFileName($_.Source).Length } | Measure-Object -Maximum).Maximum))
    $groups = $recs | Group-Object { [IO.Path]::GetDirectoryName($_.Source) } | Sort-Object Name
    foreach ($g in $groups) {
        $out.Add(('  From: {0}   ({1} file{2})' -f $g.Name, $g.Count, $(if ($g.Count -ne 1) { 's' })))
        foreach ($r in ($g.Group | Sort-Object { [IO.Path]::GetFileName($_.Source) })) {
            $name = [IO.Path]::GetFileName($r.Source)
            $label = switch ($r.Status) {
                { $r.Action -eq 'Duplicate' -and $r.Status -ne 'FAILED' } { 'DUPLICATE'; break }
                'FAILED' { 'FAILED' }
                'DRY'    { if ($r.Action -eq 'Copy') { 'WOULD COPY' } else { 'WOULD MOVE' } }
                default  { if ($r.Action -eq 'Copy') { 'COPIED' } else { 'MOVED' } }
            }
            $line = '    {0,-10}  {1}  {2,10}' -f $label, $name.PadRight($nameWidth), (Format-MediaSize $r.Size)
            if ($r.Status -eq 'FAILED') {
                $line += '   !! not transferred -- see FAILURES below'
            } elseif ($r.Action -eq 'Duplicate') {
                $what = switch ($r.DupAction) {
                    'NotCopied'   { if ($r.Status -eq 'DRY') { 'would not be copied' } else { 'not copied' } }
                    'Recycle'     { if ($r.Status -eq 'DRY') { 'would go to the Recycle Bin' } else { 'sent to the Recycle Bin' } }
                    'LeftInPlace' { 'left in place, no Recycle Bin on this drive' }
                }
                $line += "   == $($r.DuplicateOf)   ($what)"
            } else {
                $line += "   -> $([IO.Path]::GetDirectoryName($r.Target))"
                $newName = [IO.Path]::GetFileName($r.Target)
                if ($newName -ne $name) { $line += "   (renamed to $newName)" }
                if ($r.Note) { $line += "   [$($r.Note)]" }
            }
            $out.Add($line)
        }
        $out.Add('')
    }

    # Failures, repeated with full paths so they are easy to follow up
    if ($fail.Count -gt 0) {
        & $section "FAILURES  ($($fail.Count))"
        foreach ($r in $fail) {
            $out.Add("  $($r.Source)")
            $out.Add("      $($r.Error)")
        }
        $out.Add('')
    }

    $out.Add($wide)

    $dir = [IO.Path]::GetDirectoryName($Path)
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $utf8 = New-Object System.Text.UTF8Encoding $true
    [IO.File]::WriteAllLines($Path, $out, $utf8)

    if ($copyPath) {
        try { [IO.File]::WriteAllLines($copyPath, $out, $utf8) }
        catch {
            Write-Warning "Could not save the transfer log copy to ${copyPath}: $($_.Exception.Message)"
            $copyPath = $null
        }
    }
    return [pscustomobject]@{ Path = $Path; CopyPath = $copyPath }
}

function Write-MediaDuplicateLog {
    <#
        Writes the duplicates report from the 'duplicates' event of
        Invoke-MoveMedia. -Info: ordered header lines, as for the transfer log.
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Duplicates,
        [System.Collections.IDictionary]$Info = [ordered]@{}
    )

    $groups = @($Duplicates.Groups | Sort-Object @{ Expression = { $_.Size * ($_.Members.Count - 1) }; Descending = $true },
                                                 @{ Expression = { $_.Keeper.Path } })
    $extras = @($groups | ForEach-Object { $_.Members | Where-Object { -not $_.Keep } })
    $wasted = ($extras | Measure-Object -Property Size -Sum).Sum
    if (-not $wasted) { $wasted = 0 }

    $out  = New-Object System.Collections.Generic.List[string]
    $wide = '=' * 76
    $thin = '-' * 76

    $out.Add($wide)
    $out.Add("  MediaSort $script:MediaSortVersion -- Duplicates Log")
    $out.Add($wide)
    $header = [ordered]@{}
    foreach ($k in $Info.Keys) { $header[$k] = $Info[$k] }
    $header['Duplicates'] = switch ($Duplicates.Mode) {
        'scan'        { 'Scan only -- all files were transferred as usual' }
        'remove-copy' { 'Remove -- extra copies are not copied' }
        'remove-move' { 'Remove -- extra copies are sent to the Recycle Bin' }
    }
    $header['Match rule'] = 'Identical content (same size, then content hash)'
    $header['Kept copy']  = 'Already in output folder > oldest modified > shortest path'
    $header['Log file']   = $Path
    foreach ($k in $header.Keys) {
        if ($null -ne $header[$k] -and "$($header[$k])" -ne '') { $out.Add(('  {0,-16}: {1}' -f $k, $header[$k])) }
    }
    if ($Duplicates.DryRun) {
        $out.Add('')
        $out.Add('  NOTE: dry run -- no file was changed.')
    }
    if ($Duplicates.Cancelled) {
        $out.Add('')
        $out.Add('  NOTE: the run was cancelled -- this list may be incomplete.')
    }

    $out.Add(''); $out.Add($thin); $out.Add('  SUMMARY'); $out.Add($thin); $out.Add('')
    $out.Add(('  Files checked     : {0,8:N0}' -f $Duplicates.Checked))
    $out.Add(('  Duplicate groups  : {0,8:N0}' -f $groups.Count))
    $out.Add(('  Extra copies      : {0,8:N0}   {1,10}' -f $extras.Count, (Format-MediaSize $wasted)))
    foreach ($a in ($extras | Group-Object Action | Sort-Object Name)) {
        $out.Add(('    {0,-40}: {1,7:N0}' -f $a.Name, $a.Count))
    }

    $out.Add(''); $out.Add($thin); $out.Add('  DUPLICATE GROUPS  (most space first)'); $out.Add($thin); $out.Add('')
    if ($groups.Count -eq 0) { $out.Add('  No duplicates found.') }
    $n = 0
    foreach ($g in $groups) {
        $n++
        $out.Add(('  #{0}  {1} identical files, {2} each' -f $n, $g.Members.Count, (Format-MediaSize $g.Size)))
        foreach ($m in $g.Members) {
            $tag = if ($m.Keep) { 'KEEP' } else { 'DUPLICATE' }
            $out.Add(('    {0,-9}  {1}  {2,10}   {3}' -f $tag, $m.Modified.ToString('yyyy-MM-dd HH:mm'), (Format-MediaSize $m.Size), $m.Name))
            $out.Add(('               Folder: {0}' -f $m.Folder))
            $out.Add(('               Result: {0}' -f $m.Action))
        }
        $out.Add('')
    }
    $out.Add($wide)

    $dir = [IO.Path]::GetDirectoryName($Path)
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [IO.File]::WriteAllLines($Path, $out, (New-Object System.Text.UTF8Encoding $true))
    return $Path
}

Export-ModuleMember -Function Invoke-MoveMedia, Invoke-SortMediaByYear, Invoke-CleanupJunk,
                              Get-MediaImageExtensions, Get-MediaVideoExtensions, Get-MediaSortVersion,
                              New-MediaTransferStore, Register-MediaTransfer,
                              Write-MediaTransferLog, Format-MediaSize,
                              Find-MediaDuplicates, Write-MediaDuplicateLog,
                              Test-DateFolderName

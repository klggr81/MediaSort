============================================================
  Media File Sorting Scripts -- README
============================================================

Three PowerShell scripts for organizing and cleaning up a
large, messy media folder:

  1. Move-MediaFiles.ps1   -- consolidates images and videos
                              scattered across many subfolders
                              into two top-level folders:
                              images\ and videos\

  2. Sort-MediaByYear.ps1  -- sorts the files inside a folder
                              into year subfolders (2015\,
                              2016\, 2017\, ...) using EXIF /
                              media metadata when available.

  3. Cleanup-Junk.ps1      -- removes system junk, dotfiles,
                              tiny leftover files, and empty
                              folders. Items go to the Recycle
                              Bin by default.

All three scripts default to operating on the folder they are
placed in, so you don't need to edit anything before running.


------------------------------------------------------------
  RECOMMENDED WORKFLOW
------------------------------------------------------------

Starting from a parent folder containing many nested subfolders
of mixed photos and videos (e.g. D:\Lena Photo Library Mac):

  Step 1.  Copy Move-MediaFiles.ps1 into the parent folder.
           Run it. You'll end up with:

               D:\Lena Photo Library Mac\images\   (all photos)
               D:\Lena Photo Library Mac\videos\   (all videos)

  Step 2.  Copy Sort-MediaByYear.ps1 into the images\ folder.
           Run it. Photos get sorted into year subfolders:

               images\2015\
               images\2016\
               images\2017\
               ...

  Step 3.  Move Sort-MediaByYear.ps1 into the videos\ folder.
           Run it again. Videos get sorted the same way.

  Step 4.  Copy Cleanup-Junk.ps1 into the parent folder
           (D:\Lena Photo Library Mac) and run it. This sweeps
           up the Mac dotfiles, Windows thumbnail caches, tiny
           leftover files, and the now-empty original
           subfolders. By default deleted items go to the
           Recycle Bin so you can recover anything you didn't
           mean to lose.

Always run with -DryRun first to preview what would happen.


------------------------------------------------------------
  PREREQUISITES
------------------------------------------------------------

- Windows 10 or 11 (PowerShell 5.1, which ships built-in, is fine).
- No admin rights required, as long as you have read/write access
  to the folder.

If PowerShell refuses to run a script ("running scripts is disabled
on this system"), open PowerShell and run this command first. It
only affects the current window and resets when you close it:

    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass


------------------------------------------------------------
  SCRIPT 1:  Move-MediaFiles.ps1
------------------------------------------------------------

WHAT IT DOES
  Recursively scans every subfolder of its own location and moves
  each file into images\ or videos\ based on file extension.
  Anything that is not a recognized media file stays where it is.

HOW TO USE
  1. Place Move-MediaFiles.ps1 into the parent folder you want
     to consolidate (e.g. D:\Lena Photo Library Mac).
  2. Open PowerShell in that folder. (Shift + Right-Click the
     folder in Explorer -> "Open PowerShell window here", or use
     Windows Terminal.)
  3. Preview without moving anything:

         .\Move-MediaFiles.ps1 -DryRun

  4. If the preview looks right, run it for real:

         .\Move-MediaFiles.ps1

OPTIONAL PARAMETERS
  -DryRun           Show what would happen; don't move anything.
  -Root "<path>"    Operate on a different folder instead of the
                    script's own location. Quote paths with spaces.

BEHAVIOR NOTES
  - Filename collisions are handled automatically. If two
    subfolders both contain IMG_001.jpg, the second one becomes
    IMG_001_1.jpg in the destination instead of being overwritten.
  - The script never touches files already inside images\ or
    videos\, so it's safe to run again after adding new content.
  - The original subfolders are left in place (empty). Cleanup-Junk.ps1
    will remove them in Step 4, or you can delete them manually.


------------------------------------------------------------
  SCRIPT 2:  Sort-MediaByYear.ps1
------------------------------------------------------------

WHAT IT DOES
  Sorts the media files inside its own folder (non-recursive) into
  subfolders named by year: 2015\, 2016\, 2017\, ...

  Date source priority:
    1. EXIF "Date taken"     (photos)
       or "Media created"    (videos)   -- read via Windows Shell.
    2. The earlier of CreationTime and LastWriteTime.
    3. If both fail or the year looks invalid, the file goes
       into an Unknown\ folder for manual review.

HOW TO USE
  1. Place Sort-MediaByYear.ps1 inside the folder you want to
     sort (e.g. D:\Lena Photo Library Mac\images).
  2. Open PowerShell in that folder.
  3. Preview:

         .\Sort-MediaByYear.ps1 -DryRun

     Each line shows the source of the date used, e.g.:

         IMG_2204.jpg  ->  2017\   (metadata)
         clip_03.mp4   ->  2019\   (file-date)

  4. Run for real:

         .\Sort-MediaByYear.ps1

OPTIONAL PARAMETERS
  -DryRun                  Preview only; nothing is moved.
  -UseFileDateOnly         Skip metadata reading and rely purely
                           on file system dates. Faster, less
                           accurate.
  -UnknownFolderName "X"   Name to use for files with no valid
                           date. Default: "Unknown".

BEHAVIOR NOTES
  - The script only processes files directly in its own folder,
    not files already inside year subfolders. Running it again
    after dropping new files into the folder just sorts the
    new ones.
  - HEIC files (common from iPhones) need the free "HEIF Image
    Extensions" from the Microsoft Store for Windows to read
    their metadata. Without it, HEIC files fall back to file
    dates, which may be wrong if the file was copied around.
  - Years before 1980 or in the future are treated as suspicious
    and the file is routed to Unknown\ for manual review.


------------------------------------------------------------
  SCRIPT 3:  Cleanup-Junk.ps1
------------------------------------------------------------

WHAT IT DOES
  Recursively scans its own folder and removes:

    1. Junk files
         - Anything whose name starts with "." (Mac dotfiles
           like .DS_Store, ._photo.jpg, .localized, .apdisk).
         - Windows system junk: Thumbs.db, ehthumbs.db,
           desktop.ini.
         - Temp files: *.tmp, *.temp, *~

    2. Junk folders
         - Anything whose name starts with "." or is "__MACOSX"
           (deleted whole, contents included).

    3. Small files
         - Files smaller than the size threshold (default 10 KB).
         - By default this filter SKIPS the images\ and videos\
           folders so you don't accidentally lose a tiny but
           real photo. Pass -AggressiveSize to apply the size
           filter there too.

    4. Empty folders
         - Removed last, deepest-first, so a parent that becomes
           empty after its children are deleted also gets cleaned.
         - The images\ and videos\ folders themselves are
           protected and never deleted, even if empty.

  By default deleted items go to the Recycle Bin so anything
  removed by mistake can be restored. Use -Permanent to bypass
  the Recycle Bin (faster, but no undo).

HOW TO USE
  1. Place Cleanup-Junk.ps1 into the parent folder you want
     to clean (e.g. D:\Lena Photo Library Mac).
  2. Open PowerShell in that folder.
  3. ALWAYS preview first:

         .\Cleanup-Junk.ps1 -DryRun

     Each line shows the reason a file would be deleted
     ("junk-name" or "<10KB") and its size, so you can verify
     before anything actually goes.

  4. Run for real:

         .\Cleanup-Junk.ps1

OPTIONAL PARAMETERS
  -DryRun                    Preview only; nothing is deleted.
  -MinSizeKB <n>             Change the size threshold (default 10).
  -AggressiveSize            Apply the size filter inside images\
                             and videos\ as well.
  -Permanent                 Skip the Recycle Bin and delete
                             permanently. No undo.
  -SkipEmptyFolderCleanup    Leave empty subfolders alone.
  -Root "<path>"             Operate on a different folder
                             instead of the script's own
                             location. Quote paths with spaces.

BEHAVIOR NOTES
  - The script runs in three phases. The output is grouped
    accordingly so you can see junk folders, junk files, and
    empty-folder cleanup distinctly.
  - The summary at the end shows counts per category plus total
    bytes reclaimed.
  - Idempotent: running it again after a clean run is a no-op.


------------------------------------------------------------
  RECOGNIZED FILE EXTENSIONS
------------------------------------------------------------

Move-MediaFiles.ps1 and Sort-MediaByYear.ps1 share the same
lists. Edit the arrays near the top of either script if you
need to add a format.

  Images:
    .jpg  .jpeg .png  .gif  .bmp  .tif  .tiff .webp
    .heic .heif .avif .raw  .cr2  .cr3  .nef  .arw
    .dng  .orf  .rw2  .pef  .srw  .raf  .sr2

  Videos:
    .mp4  .mov  .avi  .mkv  .wmv  .flv  .webm .m4v
    .mpg  .mpeg .3gp  .3g2  .mts  .m2ts .ts   .vob  .ogv


------------------------------------------------------------
  SAFETY TIPS
------------------------------------------------------------

- Always run with -DryRun first. The output will show every
  intended move or deletion so you can spot problems before
  they happen.
- For an irreplaceable photo library, consider running the
  scripts against a copy first, or make sure you have a backup.
- The summary block at the end of each run shows totals
  (moved / deleted / skipped / failed). If "Failures" is
  greater than zero, scroll up to see the warnings -- usually a
  locked file or a permission issue.
- Cleanup-Junk.ps1 sends items to the Recycle Bin by default,
  not the void. If something disappears that shouldn't have,
  open the Recycle Bin and restore it. Only use -Permanent
  once you're confident the dry-run output looks right.


------------------------------------------------------------
  TROUBLESHOOTING
------------------------------------------------------------

"Running scripts is disabled on this system"
    Run this once in the same PowerShell window, then try again:
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

"The term '.\Move-MediaFiles.ps1' is not recognized"
    You're not in the folder where the script lives. Either cd
    into that folder, or call it with its full path.

Years look completely wrong for many files
    The capture-date metadata is missing and the file dates
    have been altered (common when files are copied between
    systems). Try installing the HEIF Image Extensions for HEIC
    files. For other formats, the file dates are the best
    available signal -- there may not be a perfect answer.

Some files ended up in Unknown\
    Open one of them, check File -> Properties -> Details in
    Explorer. If "Date taken" / "Media created" is blank, the
    script has no metadata to work with. You can either move
    them manually or set the file's date in Properties first.

Cleanup-Junk.ps1 deleted something I wanted to keep
    Open the Recycle Bin and restore it. The script uses the
    Recycle Bin by default precisely for this reason. If you
    ran with -Permanent, the file is gone -- restore from a
    backup. Next time, preview with -DryRun first.

Cleanup-Junk.ps1 says "Add-Type : Could not load file or
assembly 'Microsoft.VisualBasic'"
    This is rare but can happen on stripped-down PowerShell
    installs. Run with -Permanent to skip the Recycle Bin
    path (which is what needs that assembly), OR install the
    full .NET runtime.

A file I expected Cleanup-Junk.ps1 to delete wasn't removed
    Check the size threshold (-MinSizeKB) and whether the
    file lives inside images\ or videos\. The size filter
    skips those folders by default; use -AggressiveSize to
    override. Also make sure the file isn't open in another
    program -- locked files show up as a "FAILED to remove"
    warning, not a silent skip.

============================================================

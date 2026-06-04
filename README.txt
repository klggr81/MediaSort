============================================================
  Media Tools -- README
============================================================

A small Windows toolkit for cleaning up a messy folder of
photos and videos. Three operations, available as both a GUI
and individual command-line scripts:

  1. Consolidate -- move every image and video from nested
                    subfolders into top-level images\ and videos\
  2. Sort by year -- organize files into 2015\, 2016\, ...
                    using EXIF / media-creation metadata
  3. Clean up    -- remove dotfiles, Thumbs.db, small junk
                    files, and empty subfolders

------------------------------------------------------------
  FILES IN THIS FOLDER
------------------------------------------------------------

  MediaTools.psm1         The shared library. All real work
                          lives here. Required by every other
                          script.

  Run-MediaTools.ps1      The GUI launcher. Single window with
                          folder picker, three operation cards
                          with options, progress bar, ETA,
                          live log, and Cancel button.

  Move-MediaFiles.ps1     CLI wrappers for each operation.
  Sort-MediaByYear.ps1    Each one imports the module and
  Cleanup-Junk.ps1        adds a console progress display.

  README.txt              This file.

Keep all of these in the same folder. The wrappers and GUI
each look for MediaTools.psm1 next to themselves.


------------------------------------------------------------
  QUICK START (GUI)
------------------------------------------------------------

  1. Put all four .ps1/.psm1 files in any folder you like
     (e.g. D:\Tools\MediaTools\).
  2. Right-click Run-MediaTools.ps1 -> "Run with PowerShell".
     (If Windows asks, allow it.)
  3. In the GUI:
        - Click Browse... and pick your target folder
          (e.g. D:\Lena Photo Library Mac).
        - Leave all three operations enabled, or turn off
          any you don't want.
        - For a first run, tick "Dry run" on each one to
          preview without changing anything.
        - Click Run.
  4. Watch the progress bar and ETA. The Cancel button stops
     work cleanly between files at any point.
  5. A summary dialog appears when the run finishes.

The first run will probably be a dry run, then you uncheck
"Dry run" and click Run again. Cleanup defaults to Recycle
Bin, so even a wrong setting is recoverable.


------------------------------------------------------------
  QUICK START (COMMAND LINE)
------------------------------------------------------------

Open PowerShell in your target folder (Shift + Right-Click ->
"Open PowerShell window here"), copy the three .ps1 files +
MediaTools.psm1 next to your data, and run them in order:

    .\Move-MediaFiles.ps1 -DryRun
    .\Move-MediaFiles.ps1

    cd images
    ..\Sort-MediaByYear.ps1 -DryRun     # script + module must be reachable
    ..\Sort-MediaByYear.ps1
    cd ..\videos
    ..\Sort-MediaByYear.ps1 -DryRun
    ..\Sort-MediaByYear.ps1
    cd ..

    .\Cleanup-Junk.ps1 -DryRun
    .\Cleanup-Junk.ps1

If PowerShell refuses to run scripts ("running scripts is
disabled on this system"), unblock for the current window
only -- nothing permanent:

    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

The cleaner pattern for the CLI scripts is to just drop a
copy of all four files into each folder you're working on,
the way the originals were designed. The GUI works on a
single chosen folder so there's no copying around.


------------------------------------------------------------
  GUI DETAILS
------------------------------------------------------------

The Run-MediaTools.ps1 window has three operation cards. Each
card has a checkbox to enable/disable the operation and its
own options.

  Card 1 -- Consolidate media files
      Options: Dry run.
      Walks the target folder recursively, moves images into
      images\ and videos into videos\.

  Card 2 -- Sort by year
      Options: Dry run, Use file dates only.
      Sorts the contents of images\ and videos\ (the GUI runs
      this once for each, automatically) into year subfolders.

  Card 3 -- Clean up junk
      Options: Dry run, Permanent delete, Aggressive size
      filter, Minimum file size (KB).
      Removes dotfiles, Windows junk, small files, junk
      folders, and empty subfolders. Items go to the Recycle
      Bin unless "Permanent delete" is ticked. With Permanent
      delete on, the GUI shows a confirmation dialog before
      starting.

The progress card shows the current phase, percentage,
"current / total" counter, smoothed ETA, and the file
currently being processed. The "Show log" expander reveals
a live console-style log of operations -- useful when
something gets skipped or fails.

The Cancel button is cooperative: the worker checks for it
between files, so a long-running operation might take a
moment to actually stop. Closing the window cancels too.


------------------------------------------------------------
  CLI DETAILS
------------------------------------------------------------

All three CLI scripts default to operating on the folder they
live in. Pass -Root to override.

  Move-MediaFiles.ps1
      -Root "<path>"    Override target folder.
      -DryRun           Preview only.

  Sort-MediaByYear.ps1
      -Root "<path>"          Override target folder.
      -DryRun                 Preview only.
      -UseFileDateOnly        Skip EXIF/metadata; use file
                              dates only (faster, less accurate).
      -UnknownFolderName "X"  Folder name for files without a
                              usable date. Default: "Unknown".

  Cleanup-Junk.ps1
      -Root "<path>"           Override target folder.
      -MinSizeKB <n>           Size threshold (default 10).
      -DryRun                  Preview only.
      -Permanent               Bypass Recycle Bin.
      -AggressiveSize          Apply size filter inside
                               images\ and videos\ too.
      -SkipEmptyFolderCleanup  Leave empty subfolders alone.

Each script prints a summary at the end with counts, plus
any failures.


------------------------------------------------------------
  RECOGNIZED FILE EXTENSIONS
------------------------------------------------------------

Defined once in MediaTools.psm1 -- edit the `$script:ImageExt`
and `$script:VideoExt` arrays at the top of the module to add
formats.

  Images:
    .jpg  .jpeg .png  .gif  .bmp  .tif  .tiff .webp
    .heic .heif .avif .raw  .cr2  .cr3  .nef  .arw
    .dng  .orf  .rw2  .pef  .srw  .raf  .sr2

  Videos:
    .mp4  .mov  .avi  .mkv  .wmv  .flv  .webm .m4v
    .mpg  .mpeg .3gp  .3g2  .mts  .m2ts .ts   .vob  .ogv


------------------------------------------------------------
  HOW THE SORT-BY-YEAR DATES ARE CHOSEN
------------------------------------------------------------

In priority order:

  1. EXIF "Date taken" (photos) or "Media created" (videos),
     read via the Windows shell.
  2. The earlier of the file's CreationTime and LastWriteTime.
  3. If both fail or the year looks invalid (< 1980 or
     > next year), the file goes into Unknown\ for manual
     review.

HEIC files (common from iPhones) only expose their metadata
to Windows if you install the free "HEIF Image Extensions"
from the Microsoft Store. Without it, HEICs fall back to
file dates, which may be wrong if the files were copied
around.


------------------------------------------------------------
  CLEANUP DETAILS
------------------------------------------------------------

Cleanup runs in three phases:

  1. Junk folders -- anything starting with "." or named
     __MACOSX is deleted whole, contents included.
  2. Junk and small files:
       - Files starting with "." (covers all Mac dotfiles).
       - Windows junk: Thumbs.db, ehthumbs.db, desktop.ini.
       - Temp files: *.tmp, *.temp, *~
       - Files smaller than -MinSizeKB.
     The size filter SKIPS images\ and videos\ by default so
     a small-but-real photo is safe; -AggressiveSize removes
     that protection.
  3. Empty folders -- deepest first, so a folder containing
     only empty folders also gets cleaned. The images\ and
     videos\ folders themselves are protected and never
     deleted, even if empty.

Default delete target is the Recycle Bin. Use -Permanent or
the GUI's "Permanent delete" checkbox to bypass it.


------------------------------------------------------------
  SAFETY TIPS
------------------------------------------------------------

- Always preview with -DryRun (or the Dry run checkbox)
  first. The output shows every intended move or deletion
  so you can spot problems before they happen.
- For an irreplaceable photo library, run against a copy
  first, or make sure you have a backup.
- Cleanup sends items to the Recycle Bin by default. If
  something disappears that shouldn't have, open the Recycle
  Bin and restore it.
- Only use Permanent delete once a Recycle Bin run has
  confirmed the behavior is what you want.


------------------------------------------------------------
  TROUBLESHOOTING
------------------------------------------------------------

"Running scripts is disabled on this system"
    Open PowerShell, run this once (current window only),
    then try again:
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

"MediaTools.psm1 was not found"
    The wrapper scripts and the GUI need the module in the
    same folder as themselves. Make sure all four files live
    side by side.

GUI opens, then closes immediately
    Likely a syntax/runtime error. Run from PowerShell instead
    of double-clicking so you can see the error message:
        .\Run-MediaTools.ps1

Years look completely wrong for many files
    The capture-date metadata is missing and the file dates
    are unreliable (common when files were copied between
    systems). Install the HEIF Image Extensions for HEIC
    files. For other formats, file dates are the best
    available signal.

Some files ended up in Unknown\
    Open one and check File -> Properties -> Details in
    Explorer. If "Date taken" / "Media created" is blank,
    the script had no metadata to work with.

GUI's ETA jumps around early in a run
    Normal. ETA is calculated from a rolling average and
    needs a few seconds of data to stabilize. After that
    it's pretty steady.

Cancel doesn't stop the operation immediately
    Cancellation is cooperative -- the worker checks between
    files. A long-running file operation may take a moment
    to wrap up. The GUI shows "Cancelling..." in the
    meantime.

============================================================

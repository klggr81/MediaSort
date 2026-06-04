============================================================
  Media Tools -- README
============================================================

A small Windows toolkit for cleaning up a messy folder of
photos and videos. Three operations, available as a GUI and
as individual command-line scripts:

  1. Clean up    -- remove dotfiles, Thumbs.db, small junk
                    files, and empty subfolders
  2. Consolidate -- move every image and video from nested
                    subfolders into top-level images\ and videos\
  3. Sort by year -- organize files in images\ and videos\
                    into 2015\, 2016\, ... using EXIF /
                    media-creation metadata

The GUI runs them in that order (cleaning out junk first so
it doesn't get moved or sorted). Each run produces a
structured log file in .\Logs\.

------------------------------------------------------------
  FILES IN THIS FOLDER
------------------------------------------------------------

  MediaTools.psm1         The shared library. All real work
                          lives here. Required by every other
                          script.

  Run-MediaTools.ps1      The GUI launcher. Single window with
                          folder picker, three operation cards
                          with options (including per-extension
                          file-type checkboxes for consolidate),
                          progress bar, ETA, live log,
                          and Cancel button.

  Move-MediaFiles.ps1     CLI wrappers for each operation.
  Sort-MediaByYear.ps1    Each one imports the module and
  Cleanup-Junk.ps1        adds a console progress display.

  Logs\                   Created automatically. One .txt
                          per GUI run, timestamped.

  README.txt              This file.

Keep all of the scripts in the same folder. The wrappers and
GUI each look for MediaTools.psm1 next to themselves.


------------------------------------------------------------
  QUICK START (GUI)
------------------------------------------------------------

  1. Put MediaTools.psm1 + Run-MediaTools.ps1 (plus the three
     CLI scripts if you want them) in any folder you like
     (e.g. D:\Tools\MediaTools\).
  2. Right-click Run-MediaTools.ps1 -> "Run with PowerShell".
     (If Windows asks, allow it.)
  3. In the GUI:
        - Click Browse... and pick your target folder
          (e.g. D:\Lena Photo Library Mac).
        - All three operations are enabled by default.
          Untick any you want to skip.
        - For Consolidate, all file-type checkboxes are
          ticked by default. Untick any extensions you do
          NOT want moved -- e.g. uncheck .heic if you'd
          rather leave iPhone HEICs in place. Use the
          "all" / "none" buttons next to each group for
          quick selection.
        - For a first run, tick "Dry run" on each operation
          to preview without changing anything.
        - Click Run.
  4. Watch the progress bar and ETA. The Cancel button stops
     work cleanly between files at any point.
  5. A summary dialog appears when the run finishes, and
     the log file path is shown at the bottom of the window
     (click it to open the log).


------------------------------------------------------------
  WHY THE OPERATIONS RUN IN THIS ORDER
------------------------------------------------------------

Cleanup goes first so:
  - The Mac dotfiles (.DS_Store, ._*) and Windows junk
    (Thumbs.db) are gone before consolidate moves anything.
  - Empty Mac-export folders disappear up front so they
    don't clutter what consolidate sees.

Consolidate goes second so:
  - Everything matching your selected extensions ends up
    in images\ and videos\.
  - Anything you UNticked in the file-type list stays in
    place untouched.

Sort by year goes last so:
  - It only has to look at images\ and videos\ -- the two
    folders where everything you wanted to organize now
    lives.
  - The GUI automatically runs sort once for each of these
    two subfolders.


------------------------------------------------------------
  QUICK START (COMMAND LINE)
------------------------------------------------------------

Open PowerShell in your target folder (Shift + Right-Click ->
"Open PowerShell window here"), copy the four files
(MediaTools.psm1 plus the three .ps1 wrappers) next to your
data, then:

    .\Cleanup-Junk.ps1 -DryRun
    .\Cleanup-Junk.ps1

    .\Move-MediaFiles.ps1 -DryRun
    .\Move-MediaFiles.ps1

    cd images
    ..\Sort-MediaByYear.ps1 -DryRun
    ..\Sort-MediaByYear.ps1
    cd ..\videos
    ..\Sort-MediaByYear.ps1 -DryRun
    ..\Sort-MediaByYear.ps1
    cd ..

If PowerShell refuses to run scripts:

    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

The CLI scripts use the full default extension lists. To
limit which file types are moved by Move-MediaFiles.ps1 from
the command line, edit the lists at the top of
MediaTools.psm1, or use the GUI for per-extension control.


------------------------------------------------------------
  GUI DETAILS
------------------------------------------------------------

Three operation cards, top to bottom in execution order:

  Card 1 -- Clean up junk
      Options: Dry run, Permanent delete, Aggressive size
      filter, Minimum file size (KB).
      Removes dotfiles, Windows junk, files below the size
      threshold, and empty subfolders. Items go to the
      Recycle Bin unless "Permanent delete" is ticked. With
      Permanent delete on, the GUI shows a confirmation
      dialog before starting.

  Card 2 -- Consolidate media files
      Options: Dry run, plus a checkbox grid for every
      image and video extension.
      The "all" / "none" buttons next to each group toggle
      every extension in that group at once. A run with
      zero extensions selected is blocked with a warning.

  Card 3 -- Sort by year
      Options: Dry run, Use file dates only.
      Sorts the contents of images\ and videos\ (the GUI
      runs this once for each, automatically) into year
      subfolders.

The progress card shows the current phase, percentage,
current / total counter, smoothed ETA, and the file currently
being processed. The "Show log" expander reveals a live
console-style log of operations. The clickable text below
the log expander shows the log file path -- click it to open
the log in your default editor.


------------------------------------------------------------
  LOG FILES
------------------------------------------------------------

Every GUI run automatically writes a structured .txt log to:

    <script folder>\Logs\MediaTools-YYYY-MM-DD_HHmmss.txt

The log includes:

  - A header block with the run start time, target folder,
    and every enabled operation with its options.
  - For consolidate, the exact list of image and video
    extensions used.
  - A timestamped entry for every action the run takes:
        Moved: D:\...\IMG_0001.jpg -> D:\...\images\IMG_0001.jpg
        Sorted: IMG_0001.jpg -> 2017\ (metadata)
        Removed (junk-name, 6,148 B): D:\...\.DS_Store
  - Any warnings or failures.
  - A footer block with the run duration and per-operation
    summaries (counts, by-year breakdown for sort, MB
    reclaimed for cleanup, etc.).

The GUI's in-window log box shows only the high-level events
(phase boundaries, warnings, summaries) so it stays
readable. The disk log captures every detail.

If a run is cancelled or the window is closed mid-run, the
log file is still saved with a note marking the
interruption.

CLI runs do not produce log files automatically. Redirect
output to capture them:

    .\Cleanup-Junk.ps1 *>&1 | Tee-Object -FilePath cleanup.log


------------------------------------------------------------
  CLI DETAILS
------------------------------------------------------------

All three CLI scripts default to operating on the folder
they live in. Pass -Root to override.

  Move-MediaFiles.ps1
      -Root "<path>"    Override target folder.
      -DryRun           Preview only.

  Sort-MediaByYear.ps1
      -Root "<path>"          Override target folder.
      -DryRun                 Preview only.
      -UseFileDateOnly        Skip EXIF/metadata; use file
                              dates only (faster, less
                              accurate).
      -UnknownFolderName "X"  Folder name for files without
                              a usable date. Default:
                              "Unknown".

  Cleanup-Junk.ps1
      -Root "<path>"           Override target folder.
      -MinSizeKB <n>           Size threshold (default 10).
      -DryRun                  Preview only.
      -Permanent               Bypass Recycle Bin.
      -AggressiveSize          Apply size filter inside
                               images\ and videos\ too.
      -SkipEmptyFolderCleanup  Leave empty subfolders alone.

Each script prints a summary at the end.


------------------------------------------------------------
  RECOGNIZED FILE EXTENSIONS
------------------------------------------------------------

Defined once in MediaTools.psm1 -- edit the `$script:ImageExt`
and `$script:VideoExt` arrays at the top of the module to
add formats.

  Images:
    .jpg  .jpeg .png  .gif  .bmp  .tif  .tiff .webp
    .heic .heif .avif .raw  .cr2  .cr3  .nef  .arw
    .dng  .orf  .rw2  .pef  .srw  .raf  .sr2

  Videos:
    .mp4  .mov  .avi  .mkv  .wmv  .flv  .webm .m4v
    .mpg  .mpeg .3gp  .3g2  .mts  .m2ts .ts   .vob  .ogv


------------------------------------------------------------
  HOW SORT-BY-YEAR PICKS A YEAR
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
file dates.


------------------------------------------------------------
  CLEANUP DETAILS
------------------------------------------------------------

Cleanup runs in three internal phases:

  1. Junk folders -- anything starting with "." or named
     __MACOSX is deleted whole, contents included.
  2. Junk and small files:
       - Files starting with "." (covers all Mac dotfiles).
       - Windows junk: Thumbs.db, ehthumbs.db, desktop.ini.
       - Temp files: *.tmp, *.temp, *~
       - Files smaller than -MinSizeKB.
     The size filter SKIPS images\ and videos\ by default
     so a small-but-real photo is safe; -AggressiveSize
     removes that protection.
  3. Empty folders -- deepest first. The images\ and
     videos\ folders themselves are protected and never
     deleted, even if empty.

Default delete target is the Recycle Bin. Use -Permanent
(CLI) or the "Permanent delete" checkbox (GUI) to bypass it.


------------------------------------------------------------
  SAFETY TIPS
------------------------------------------------------------

- Always preview with -DryRun (or the Dry run checkbox)
  first. The log will show every intended move or deletion
  so you can spot problems before they happen.
- For an irreplaceable photo library, run against a copy
  first, or make sure you have a backup.
- Cleanup sends items to the Recycle Bin by default. If
  something disappears that shouldn't have, open the Recycle
  Bin and restore it.
- Only tick Permanent delete after a Recycle Bin run has
  confirmed the behavior is what you want.
- The log file for each run is your audit trail. Keep it
  until you've verified the run was successful.


------------------------------------------------------------
  TROUBLESHOOTING
------------------------------------------------------------

"Running scripts is disabled on this system"
    Open PowerShell, run this once (current window only),
    then try again:
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

"MediaTools.psm1 was not found"
    The wrapper scripts and the GUI need the module in the
    same folder as themselves. Make sure all four files
    live side by side.

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
    needs a few seconds of data to stabilize.

Cancel doesn't stop the operation immediately
    Cancellation is cooperative -- the worker checks between
    files. A long-running file operation may take a moment
    to wrap up.

I clicked Run but nothing happens / a checkbox warning shows
    Make sure at least one operation is ticked, and that
    Consolidate has at least one file extension selected.

The log file is too big to open
    Each run produces a separate file in .\Logs\, so logs
    don't accumulate. If a single run produced a huge log
    (millions of detail lines), open it in something like
    Notepad++ or VS Code rather than plain Notepad.

============================================================

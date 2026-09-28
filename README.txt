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
                    into 2015\, 2016\, ... using metadata

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
                          with options (including an
                          expandable Include/Exclude filter
                          for the Consolidate step), progress
                          bar, ETA, live log, and Cancel
                          button.

  Move-MediaFiles.ps1     CLI wrappers for each operation.
  Sort-MediaByYear.ps1    Each one imports the module and
  Cleanup-Junk.ps1        adds a console progress display.

  Build-Exe.ps1           Optional: compiles the GUI into
                          a self-contained MediaTools.exe
                          via the ps2exe module.

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
          (e.g. D:\Photos).
        - All three operations are enabled by default.
          Untick any you want to skip.
        - For Consolidate, every known media format is
          included by default. To narrow the set, expand
          "Customize file types" and use the Include /
          Exclude boxes (see "GUI DETAILS" below for
          syntax).
        - For a first run, tick "Dry run" on each operation
          to preview without changing anything.
        - Click Run.
  4. Watch the progress bar and ETA. The Cancel button stops
     work cleanly between files at any point.
  5. A summary dialog appears when the run finishes, and
     the log file path is shown at the bottom of the window
     (click it to open the log). The "Open Logs folder"
     link next to it opens the folder containing all past
     run logs.


------------------------------------------------------------
  WHY THE OPERATIONS RUN IN THIS ORDER
------------------------------------------------------------

Cleanup goes first so:
  - The Mac dotfiles (.DS_Store, ._*) and Windows junk
    (Thumbs.db) are gone before consolidate moves anything.
  - Empty Mac-export folders disappear up front so they
    don't clutter what consolidate sees.

Consolidate goes second so:
  - Everything matching the active extension filter ends
    up in images\ and videos\.
  - Anything filtered out (via the Exclude list, or simply
    not on the Include list) stays in place untouched.

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
MediaTools.psm1, or use the GUI for include/exclude control.


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
      Options: Dry run, plus a "Customize file types"
      expander.
      By default the full list of supported image and video
      extensions is used. To narrow the set, expand
      "Customize file types" to reveal two text fields:

        Include only:   limit consolidate to just these
                        types. Leave blank to use every
                        default type.
        Exclude:        remove these from whatever set is
                        being used.

      The fields accept extensions in a forgiving format:
      with or without leading dots, separated by commas,
      semicolons, or whitespace. All of the following
      mean the same thing:

          jpg, png, mov
          .jpg .png .mov
          jpg;png;mov

      Common patterns:

        - Defaults only:        leave both fields blank.
        - Only specific types:  put them in Include.
          Example -- only photos, no videos:
              Include only:  jpg, jpeg, png, heic, raw
        - Most types, minus a few:  use Exclude only.
          Example -- skip iPhone HEICs and big RAW files:
              Exclude:  heic, raw, cr2, nef, arw, dng

      A run with no resulting extensions (e.g. Include
      lists something the script doesn't recognize) is
      blocked with a warning.

  Card 3 -- Sort by year
      Options: Dry run, Use file dates only.
      Sorts the contents of images\ and videos\ (the GUI
      runs this once for each, automatically) into year
      subfolders.

The progress card shows the current phase, percentage,
current / total counter, smoothed ETA, and the file currently
being processed. The "Show log" expander reveals a live
console-style log of operations. The clickable text below
shows the log file path -- click it to open the log in your
default editor. "Open Logs folder" next to it opens the
folder containing every past run's log file.


------------------------------------------------------------
  LOG FILES
------------------------------------------------------------

Every GUI run automatically writes a structured .txt log to:

    <script folder>\Logs\MediaTools-YYYY-MM-DD_HHmmss.txt

The log includes:

  - A header block with the run start time, target folder,
    and every enabled operation with its options.
  - For consolidate, the active filter description (whether
    defaults were used, plus any Include/Exclude values)
    and the resulting image and video extension lists.
  - A timestamped entry for every action the run takes:
        Moved:    C:\src\photo.jpg -> D:\Photos\images\photo.jpg
        Sorted:   IMG_0001.jpg -> 2017\ (metadata)
        Removed (junk-name, 6,148 B): D:\Photos\.DS_Store
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
  BUILDING A STANDALONE .EXE (OPTIONAL)
------------------------------------------------------------

If you'd rather have a clickable MediaTools.exe instead of
running the .ps1 each time:

  1. One-time setup. In PowerShell, run:

         Install-Module -Name ps2exe -Scope CurrentUser

  2. From this folder, run:

         .\Build-Exe.ps1

  3. MediaTools.exe appears next to the script. Drop it
     anywhere -- it's self-contained. Logs are created in
     a Logs\ folder next to the .exe at runtime.

Optional flags:

    .\Build-Exe.ps1 -IconFile .\my-icon.ico
    .\Build-Exe.ps1 -OutputName "Photo Sorter.exe"
    .\Build-Exe.ps1 -Console        # keep console window
    .\Build-Exe.ps1 -KeepTempScript # preserve the combined .ps1

The .exe is a ps2exe-wrapped PowerShell script. Antivirus
software may flag it on first run (because the technique
is also used by malware); you can usually allow it through
Windows Defender. PowerShell itself is required on the
target machine, which is built in on every modern Windows.


------------------------------------------------------------
  LICENSE
------------------------------------------------------------

This project is licensed under the GNU General Public License
version 3. See the LICENSE file for the complete license text.


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
    same folder as themselves. Make sure all the files
    live side by side.

GUI opens, then closes immediately
    Likely a syntax/runtime error. Run from PowerShell
    instead of double-clicking so you can see the error
    message:
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

"Consolidate is enabled but the Include/Exclude filters
leave no file types"
    Either you typed something the script doesn't recognize
    in the Include box (the recognized extensions are
    listed earlier in this file), or your Exclude list
    removed everything Include allowed. Clear both fields
    to fall back to the defaults.

The log file is too big to open
    Each run produces a separate file in .\Logs\, so logs
    don't accumulate. If a single run produced a huge log
    (millions of detail lines), open it in something like
    Notepad++ or VS Code rather than plain Notepad.

============================================================

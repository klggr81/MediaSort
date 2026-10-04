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
  WHAT'S NEW IN 0.3.0
------------------------------------------------------------

  - Output location: send results into the source folder
    (as before) or into any other folder or drive.
  - File transfer: Move files (as before) or Copy them,
    leaving the originals untouched. Copies keep the
    original file dates, so Sort by year still works.
    Before copying (or moving to another drive), the free
    space on the destination drive is checked.
  - Folder layout: keep images\ and videos\ separate (as
    before), or put everything together in one media\
    folder.
  - run.bat: double-click to start the GUI in PowerShell as
    Administrator.
  - Duplicates: scan for files with identical content, list
    them in Logs\Duplicates-*.txt, and optionally remove the
    extra copies (Copy: not copied; Move: Recycle Bin).
  - Keep folder name: optionally keep each file's original
    folder name under the year folder
    (images\2019\Holiday\IMG_01.jpg).
  - Transfer log: every move/copy run writes a structured
    Logs\Transfers-*.txt listing each file, where it came
    from and where it went (see LOG FILES).
  - The interface always runs in English, regardless of the
    Windows display language.


------------------------------------------------------------
  FILES IN THIS FOLDER
------------------------------------------------------------

  MediaTools.psm1         The shared library. All real work
                          lives here. Required by every other
                          script.

  run.bat                 Double-click launcher. Starts
                          Run-MediaTools.ps1 in PowerShell as
                          Administrator (UAC prompt).

  Run-MediaTools.ps1      The GUI. Single window with source
                          folder picker, output options
                          (location, move/copy, layout),
                          three operation cards
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

  MediaTools.psd1         Module manifest. Holds the version
                          number (ModuleVersion) used by the
                          GUI title and all logs.

  CHANGELOG.md            Version history (Keep a Changelog
                          format, Semantic Versioning).

Keep all of the scripts in the same folder. The wrappers and
GUI each look for MediaTools.psm1 next to themselves.


------------------------------------------------------------
  QUICK START (GUI)
------------------------------------------------------------

  1. Put MediaTools.psm1 + Run-MediaTools.ps1 + run.bat
     (plus the three CLI scripts if you want them) in any
     folder you like (e.g. D:\Tools\MediaTools\).
  2. Double-click run.bat and answer Yes to the UAC prompt.
     (Or right-click Run-MediaTools.ps1 -> "Run with
     PowerShell" to run without admin rights.)
  3. In the GUI:
        - Click Browse... and pick your source folder
          (e.g. D:\Photos).
        - In the Output card choose where results go
          (source folder, or another folder/drive), whether
          files are moved or copied, and whether images and
          videos are kept separate or together.
        - All three operations are enabled by default.
          Untick any you want to skip.
        - For Consolidate, every known media format is
          included by default. To narrow the set, expand
          "Customize file types" and use the Include /
          Exclude boxes (see "GUI DETAILS" below for
          syntax).
        - For a first run, switch on "Dry run" (top right of
          the window). The Run button changes to "Preview";
          nothing is changed, but the logs show everything
          that would happen.
        - Click Run (or Preview).
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
    up in images\ and videos\ (or media\) in the output
    location.
  - Anything filtered out (via the Exclude list, or simply
    not on the Include list) stays in place untouched.

Sort by year goes last so:
  - It only has to look at the output folders -- where
    everything you wanted to organize now lives.
  - The GUI automatically runs sort once for each output
    folder (images\ and videos\, or just media\).


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

Output card (applies to Consolidate and Sort by year):

  Output location
      Source folder        -- images\ / videos\ / media\ are
                              created inside the source folder.
      Other folder or drive -- type a path or click Browse...
                              (e.g. E:\ or D:\Sorted). The
                              folder is created if needed.
  File transfer
      Move files  -- files leave their original place.
      Copy files  -- originals stay; copies keep their dates.
                     Running Copy twice makes duplicates
                     (named file_1.jpg, ...).
  Folder layout
      Separate    -- images\ and videos\
      Together    -- one media\ folder for both
  Keep each file's original folder name (checkbox)
      Each file goes into a subfolder named after the folder
      it came from. With Sort by year, that subfolder sits
      under the year:
          D:\Photos\Holiday\IMG_01.jpg
              -> images\2019\Holiday\IMG_01.jpg
      Without Sort by year: images\Holiday\IMG_01.jpg.
      Only the immediate folder name is kept (not the whole
      path). Files lying directly in the source folder get
      the source folder's name (e.g. images\2020\Photos\).
      Two different source folders with the same name (e.g.
      two "DCIM" folders) end up in the same subfolder;
      clashing file names are renamed file_1.jpg, ...
  ...except date folders (sub-option, on by default)
      Folder names that are ONLY a date are not kept -- the
      year folder already says when:
          D:\Photos\2024-07-03\IMG_02.jpg -> images\2024\IMG_02.jpg
      Recognized: 2024-07-03, 2024_07_03, 2024.07.03,
      2024 07 03, 20240703, 2024-07, 03.07.2024, 3-7-24.
      Names with more text, like "2024-07-03 Lake", are kept.

Cleanup always works on the source folder.

Dry run (top right of the window):
      One switch for all operations. When it is on, the box
      turns yellow, the Run button reads "Preview", and
      every operation only reports what it would do --
      nothing is moved, copied, sorted or deleted. The run
      log and transfer log are still written. Note: in a
      dry run, Sort by year sees the output folders as they
      are now, so files that Consolidate would bring in are
      not included in the sort preview.

Three operation cards, top to bottom in execution order:

  Card 1 -- Clean up junk
      Options: Permanent delete, Aggressive size
      filter, Minimum file size (KB).
      Removes dotfiles, Windows junk, files below the size
      threshold, and empty subfolders. Items go to the
      Recycle Bin unless "Permanent delete" is ticked. With
      Permanent delete on, the GUI shows a confirmation
      dialog before starting.

  Card 2 -- Consolidate media files
      Options: duplicate handling (see DUPLICATES below) and
      a "Customize file types" expander.
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
      Options: Use file dates only.
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

DUPLICATES LOG (new in 0.3.0)

When "Scan for duplicates" is on, the run also writes

    <script folder>\Logs\Duplicates-YYYY-MM-DD_HHmmss.txt

with a summary (files checked, duplicate groups, extra
copies and the space they take) and every group of
identical files, largest wasted space first:

  #1  2 identical files, 1.5 MB each
    KEEP       2014-04-25 02:06     1.5 MB   20140425_020641.jpg
               Folder: D:\...\Fotos\2014-07-23
               Result: Kept
    DUPLICATE  2014-04-25 02:06     1.5 MB   20140425_020641.jpg
               Folder: D:\...\Fotos\Pictures\2014-07-23
               Result: Sent to the Recycle Bin

The date is the file's modified date. Duplicates also show
up in the transfer log as DUPLICATE lines ("== <kept file>").

TRANSFER LOG (new in 0.3.0)

Every run that moves or copies files (Consolidate and/or
Sort by year) also writes a clean, per-file report next to
the run log:

    <script folder>\Logs\Transfers-YYYY-MM-DD_HHmmss.txt

It contains:

  - Header: start/finish time, duration, status (completed,
    cancelled, interrupted), source and output folder,
    move or copy, layout, sort settings, file-type filter,
    computer/user (and whether it ran as Administrator).
  - Summary: number and size of files handled (images and
    videos separately), moved/copied counts, files renamed
    because of a name conflict, failures, where the year came
    from (metadata or file date), and a per-destination-folder
    table.
  - Files, grouped by original folder. One line per file:

      From: D:\Photos\Holiday 2019   (2 files)
        COPIED      IMG_0001.jpg   2.4 MB   -> E:\Sorted\images\2019
        COPIED      IMG_0002.jpg   2.1 MB   -> E:\Sorted\images\2019   (renamed to IMG_0002_1.jpg)
        FAILED      broken.jpg     1.0 MB   !! not transferred -- see FAILURES below

    When Sort by year runs in the same pass, the destination
    is the final year folder, not the intermediate images\.
  - Failures: full path and error message for each file
    that could not be moved or copied.

A copy of the transfer log is also saved next to the
transferred files, in the output folder (the folder that
holds images\ / videos\ / media\):

    <output folder>\MediaSort-Transfers-YYYY-MM-DD_HHmmss.txt

So the record travels with the files, e.g. on an external
drive. Both files are identical; each one's header lists
where the other is. Clean up never deletes these copies.
No copy is written when nothing was actually moved or
copied (e.g. a dry run).

Dry runs produce the same report with "WOULD MOVE" /
"WOULD COPY" entries, so you can review exactly what a real
run will do (including any renames) before doing it.

Move-MediaFiles.ps1 and Sort-MediaByYear.ps1 also write a
transfer log to .\Logs\ when run from the command line.

The GUI's in-window log box shows only the high-level events
(phase boundaries, warnings, summaries) so it stays
readable. The disk log captures every detail.

If a run is cancelled or the window is closed mid-run, the
log file is still saved with a note marking the
interruption.

CLI runs write only the transfer log (see above), not the
full run log. Redirect output to capture everything:

    .\Cleanup-Junk.ps1 *>&1 | Tee-Object -FilePath cleanup.log


------------------------------------------------------------
  CLI DETAILS
------------------------------------------------------------

All three CLI scripts default to operating on the folder
they live in. Pass -Root to override.

  Move-MediaFiles.ps1
      -Root "<path>"        Override source folder.
      -OutputRoot "<path>"  Create the output folders here
                            instead of in the source folder.
      -Copy                 Copy instead of move.
      -KeepTogether         One media\ folder instead of
                            images\ + videos\.
      -FindDuplicates       List files with identical content
                            in Logs\Duplicates-*.txt.
      -RemoveDuplicates     Also remove the extra copies
                            (Copy: not copied; Move: sent to
                            the Recycle Bin).
      -KeepParentFolder     Put each file in a subfolder
                            named after its original folder.
      -SkipDateFolders      With -KeepParentFolder: not for
                            folders named only by a date.
      -DryRun               Preview only.

  Sort-MediaByYear.ps1
      -Root "<path>"          Override target folder.
      -DryRun                 Preview only.
      -UseFileDateOnly        Skip EXIF/metadata; use file
                              dates only (faster, less
                              accurate).
      -UnknownFolderName "X"  Folder name for files without
                              a usable date. Default:
                              "Unknown".
      -KeepParentFolder       Also sort files one folder
                              down and keep that folder's
                              name: Holiday\a.jpg ->
                              2019\Holiday\a.jpg. Folders
                              named like a year (2019) or
                              Unknown are treated as already
                              sorted and left alone.

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
  DUPLICATES
------------------------------------------------------------

Two options in the Consolidate card:

  Scan for duplicates
      Finds files with byte-for-byte identical content --
      the name does not matter -- among the source files and
      the files already in the output folders. Nothing is
      changed; everything is transferred as usual, and the
      Duplicates log lists every group.

  Remove duplicates (turns on the scan automatically)
      One copy of each group is kept and transferred; the
      extra copies are:
        Copy mode -- not copied (the originals stay put)
        Move mode -- sent to the Recycle Bin
      A file that is identical to one ALREADY in the output
      folder is treated as an extra copy, so repeating a
      Copy run no longer creates file_1.jpg duplicates.

Which copy is kept:
  1. a copy already in the output folder,
  2. otherwise the one with the oldest modified date,
  3. otherwise the one with the shortest path.

Safety rules:
  - An extra copy is only skipped or recycled after the kept
    copy has been transferred successfully. If the kept copy
    fails, the next copy is transferred instead and becomes
    the kept one.
  - USB sticks, memory cards and network drives have no
    Recycle Bin. Extra copies there are LEFT IN PLACE, never
    deleted permanently.
  - With Move + Remove duplicates the GUI asks for
    confirmation first. Run with Dry run first and read the
    Duplicates log.

How files are compared: only files of exactly the same size
are compared. Their first 64 KB are hashed; files that still
match are then hashed in full. On large libraries the check
takes extra time, mostly for big videos of equal size.


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
     The size filter SKIPS images\, videos\ and media\ by
     default so a small-but-real photo is safe;
     -AggressiveSize removes that protection.
  3. Empty folders -- deepest first. The images\, videos\
     and media\ folders themselves are protected and never
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

- Always preview with -DryRun (or the Dry run switch)
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

Network drive missing when started with run.bat
    Drive letters mapped as a normal user are not visible to
    programs running as Administrator. Type the UNC path
    (\\server\share\...) instead, or start
    Run-MediaTools.ps1 without admin rights.

"Not enough free space on X:"
    Copying (or moving to a different drive) needs room for
    every selected file on the destination drive. Free up
    space, choose another output drive, or use Move on the
    same drive.

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

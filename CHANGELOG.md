# Changelog

All notable changes to MediaSort are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
The current version number is stored in `MediaTools.psd1` (`ModuleVersion`).

## [Unreleased]

## [0.3.0] - 2026-10-04

### Added
- **Output location**: write results into the source folder (as before)
  or into any other folder or drive (radio buttons + Browse…). The
  output folder is created if needed; a missing drive is reported
  before the run starts.
- **Copy or move**: new *File transfer* choice. *Copy* leaves the
  originals in place and keeps the original creation/modified dates on
  the copies, so *Sort by year* still finds the right year.
- **Free-space check**: before copying, or moving to a different drive,
  the run stops with a clear message if the destination drive is too
  small.
- **Folder layout**: keep images and videos *separate*
  (`images\` + `videos\`, as before) or *together* in one `media\`
  folder.
- **Keep original folder name** (checkbox): each file goes into a
  subfolder named after the folder it came from, under its year:
  `D:\Photos\Holiday\IMG_01.jpg` → `images\2019\Holiday\IMG_01.jpg`.
  Temporary per-folder subfolders are removed once sorted; folders that
  already look like year folders are left alone on re-runs.
  Sub-option **…except date folders** (on by default): folder names that
  are only a date (`2024-07-03`, `20240703`, `03.07.2024`, …) are not
  kept, so those files go straight into the year folder; names with
  extra text (`2024-07-03 Lake`) are kept. CLI: `-SkipDateFolders`.
- **Transfer log**: every run that moves or copies files writes
  `Logs\Transfers-YYYY-MM-DD_HHmmss.txt` with:
  - a header (time, duration, status, source, output, move/copy,
    layout, options, file-type filter, computer/user, admin or not),
  - a summary (counts and sizes for images/videos, renamed files,
    failures, year source, totals per destination folder),
  - one line per file, grouped by original folder, showing where it
    ended up (final year folder) and any rename,
  - a failures section with full path and error message.
  Dry runs write the same report with `WOULD MOVE` / `WOULD COPY`
  lines. The summary dialog and the run log show where it was saved.
  `Move-MediaFiles.ps1` and `Sort-MediaByYear.ps1` write one too.
- **Duplicates** (Consolidate card):
  - *Scan for duplicates* finds files with byte-for-byte identical
    content (size → first 64 KB → full content hash), in the source
    and already in the output folders, and writes
    `Logs\Duplicates-YYYY-MM-DD_HHmmss.txt`: summary plus every group
    with folder, file name, size, modified date and what happened.
  - *Remove duplicates* keeps one copy per group (already in output >
    oldest modified > shortest path). Extra copies are not copied
    (Copy) or sent to the Recycle Bin (Move), only after the kept copy
    was transferred successfully; on drives without a Recycle Bin they
    are left in place. Move + remove asks for confirmation.
  - Duplicates appear in the transfer log as `DUPLICATE` lines, and in
    the run log, summary dialog and free-space check.
  - `Move-MediaFiles.ps1`: `-FindDuplicates`, `-RemoveDuplicates`.
- **Transfer log copy next to the files**: a copy of the transfer log,
  `MediaSort-Transfers-YYYY-MM-DD_HHmmss.txt`, is saved in the output
  folder alongside `images\` / `videos\` / `media\`, so the record
  stays with the files. Not written for dry runs. *Clean up* never
  deletes these copies.
- **`run.bat`**: double-click launcher that starts the GUI in
  Windows PowerShell **as Administrator** (UAC prompt). The window
  title shows *(Administrator)* when elevated.
- Command-line options for `Move-MediaFiles.ps1`: `-OutputRoot`,
  `-Copy`, `-KeepTogether`, `-KeepParentFolder`;
  for `Sort-MediaByYear.ps1`: `-KeepParentFolder`.
- `CHANGELOG.md` (this file) and the module manifest `MediaTools.psd1`,
  which holds the version number; the window title and all logs read it
  from there.

### Changed
- **One Dry run switch** at the top right of the window replaces the
  three separate *Dry run* checkboxes on the Clean up, Consolidate and
  Sort cards. When on, the box turns yellow and the Run button reads
  *Preview*. The run log header states whether it was a dry run.
- Interface is forced to **English** (en-US UI culture) regardless of
  the Windows display language. Date parsing still follows the regional
  settings.
- "Target folder" renamed to **Source folder**; window title shows the
  version (*Media Tools 0.3.0*); window enlarged for the new *Output* card.
- Versions follow Semantic Versioning (`MAJOR.MINOR.PATCH`) and are git
  tags (`v0.3.0`) instead of separate `GUI ver …` folders.
- *Sort by year* runs in whichever output folders were chosen
  (`images\` + `videos\`, or `media\`) instead of always
  `<source>\images` and `<source>\videos`.
- *Clean up* also protects a `media\` folder (size filter and
  empty-folder removal), like `images\` and `videos\`.
- Dry runs now predict renames for duplicate names within the same run
  (previously two `IMG_0001.jpg` showed the same target).
- Run log header lists source, output, transfer mode, layout and the
  keep-folder-name setting.

### Fixed
- Choosing an output drive that is not connected no longer causes a
  PowerShell error while building the run; it is reported cleanly.

## [0.2.0] - 2026-09-28

Code finished 2026-06-05; published to GitHub 2026-09-28.

### Added
- **Open Logs folder** link next to the log-file path.
- GNU GPL v3 `LICENSE` file; git repository
  (`github.com/klggr81/MediaSort`, “Initial MediaSort release”).
- README: license section, include/exclude syntax and examples,
  section on building a standalone `.exe` with ps2exe.

### Changed
- File-type selection for *Consolidate* replaced: the grid of one
  checkbox per extension (with all/none buttons) became a collapsible
  **Customize file types** section with two text fields:
  - **Include only** – limit to these types (blank = all defaults),
  - **Exclude** – drop these types.
  Input is forgiving (`jpg, png`, `.jpg .png`, `jpg;png`, `*.jpg`).
  Unknown extensions are ignored and noted in the log.
- Run log records the active filter (defaults / include / exclude) and
  the resulting extension lists.
- Window size adjusted (820 × 720).

Known issue (still open): the README describes `Build-Exe.ps1`, but that
script is not part of the project.

## [0.1.0] - 2026-06-04

### Added
- **Log files**: every GUI run writes
  `Logs\MediaTools-YYYY-MM-DD_HHmmss.txt` with a header (start time,
  folder, operations and options), a timestamped line for every action,
  warnings, and a summary footer. Also saved when cancelled or when
  the window is closed mid-run.
- Clickable log-file path at the bottom of the window.
- **Per-extension checkboxes** for *Consolidate* (images and videos,
  with *all* / *none* buttons); a run with no types selected is
  blocked.
- Log levels (`info` / `detail` / `warn`): the in-window log shows only
  important lines, the log file gets every detail.
- Per-file log messages for moved, sorted and removed items, and for
  failures.

### Changed
- **Operation order** is now *Clean up → Consolidate → Sort by year*
  (was Consolidate → Sort → Clean up), so junk is removed before
  anything is moved or sorted. The cards were reordered to match.
- Consolidate accepts custom image/video extension lists
  (`-ImageExtensions`, `-VideoExtensions`); default lists unchanged.
- Shell metadata reader is only started when there are files to sort,
  and output folders are only created when there are files to move.

## [0.0.0] - 2026-06-04

First GUI version, built from the three original stand-alone scripts
(the first commit in the repository, before any version tag).

### Added
- **`MediaTools.psm1`** – shared module with all the logic:
  `Invoke-MoveMedia`, `Invoke-SortMediaByYear`, `Invoke-CleanupJunk`,
  with progress callbacks and cooperative cancellation.
- **`Run-MediaTools.ps1`** – WPF window with:
  - target-folder picker,
  - three operation cards (Consolidate, Sort by year, Clean up), each
    with its own on/off switch and options (dry run, file dates only,
    permanent delete, aggressive size filter, minimum size),
  - progress bar, item counter, smoothed ETA, current file name,
  - live log panel, Cancel button, elapsed time,
  - summary dialog at the end; confirmation before permanent delete.
- Sort by year runs automatically on both `images\` and `videos\`.
- `Move-MediaFiles.ps1`, `Sort-MediaByYear.ps1`, `Cleanup-Junk.ps1`
  reduced to thin command-line wrappers around the module.
- Features carried over from the original scripts: consolidate into
  `images\` / `videos\` with duplicate-safe renaming; year from EXIF
  *Date taken* / *Media created* with file-date fallback and an
  `Unknown\` folder; cleanup of dotfiles, `Thumbs.db`, `desktop.ini`,
  temp files, small files, `__MACOSX` folders and empty folders, to the
  Recycle Bin by default.

[Unreleased]: https://github.com/klggr81/MediaSort/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/klggr81/MediaSort/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/klggr81/MediaSort/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/klggr81/MediaSort/compare/v0.0.0...v0.1.0
[0.0.0]: https://github.com/klggr81/MediaSort/releases/tag/v0.0.0

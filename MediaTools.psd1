#
# Module manifest for MediaTools (MediaSort).
#
# ModuleVersion is the single source of the MediaSort version number:
# the GUI title, run logs, transfer logs and duplicates logs all read it.
# Bump it here when releasing (Semantic Versioning: MAJOR.MINOR.PATCH),
# then add the matching section to CHANGELOG.md and tag the commit vX.Y.Z.
#
@{
    RootModule        = 'MediaTools.psm1'
    ModuleVersion     = '0.3.0'
    GUID              = '754a1377-7ad3-4321-a5b4-d48e7711a045'
    Author            = 'Daniel Gruenfeld'
    Copyright         = '(c) Daniel Gruenfeld. Licensed under the GNU GPL v3.'
    Description       = 'MediaSort: clean up, consolidate, de-duplicate and sort folders of photos and videos.'
    PowerShellVersion = '5.1'

    FunctionsToExport = @(
        'Invoke-MoveMedia', 'Invoke-SortMediaByYear', 'Invoke-CleanupJunk',
        'Get-MediaImageExtensions', 'Get-MediaVideoExtensions', 'Get-MediaSortVersion',
        'New-MediaTransferStore', 'Register-MediaTransfer',
        'Write-MediaTransferLog', 'Format-MediaSize',
        'Find-MediaDuplicates', 'Write-MediaDuplicateLog',
        'Test-DateFolderName'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            ProjectUri = 'https://github.com/klggr81/MediaSort'
            LicenseUri = 'https://github.com/klggr81/MediaSort/blob/main/LICENSE'
        }
    }
}

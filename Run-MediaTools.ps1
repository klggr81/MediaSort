<#
    Run-MediaTools.ps1
    GUI launcher for MediaTools.psm1.

    Requires MediaTools.psm1 in the same folder.

    Easiest: double-click run.bat -- it starts this script in
    PowerShell as Administrator. Alternatively right-click this script ->
    "Run with PowerShell", or open PowerShell and run:
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
        .\Run-MediaTools.ps1

    Each run produces a structured log file in .\Logs\.
#>

#requires -Version 5.1

# --- Assemblies -------------------------------------------------------------

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# Keep the interface in English regardless of the Windows display language.
# (Only the UI culture changes; date parsing still follows regional settings.)
try { [System.Threading.Thread]::CurrentThread.CurrentUICulture = [System.Globalization.CultureInfo]::GetCultureInfo('en-US') } catch {}

$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

# --- Locate and load module -------------------------------------------------

$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = (Get-Location).Path }
$modulePath = Join-Path $ScriptDir 'MediaTools.psm1'
if (-not (Test-Path $modulePath)) {
    [System.Windows.MessageBox]::Show(
        "MediaTools.psm1 was not found next to Run-MediaTools.ps1.`n`nLooked in:`n$ScriptDir",
        "Media Tools", 'OK', 'Error') | Out-Null
    exit 1
}
Import-Module $modulePath -Force
$LogsDir = Join-Path $ScriptDir 'Logs'

# --- XAML -------------------------------------------------------------------

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Media Tools" Height="820" Width="840"
        Language="en-US"
        WindowStartupLocation="CenterScreen"
        Background="#F3F3F3"
        FontFamily="Segoe UI Variable, Segoe UI" FontSize="14"
        UseLayoutRounding="True">
  <Window.Resources>

    <Style TargetType="Button">
      <Setter Property="Padding" Value="16,8"/>
      <Setter Property="Background" Value="#FFFFFF"/>
      <Setter Property="BorderBrush" Value="#D6D6D6"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Foreground" Value="#202020"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}"
                    CornerRadius="5">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"
                                Margin="{TemplateBinding Padding}"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#F5F5F5"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#EAEAEA"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="bd" Property="Background" Value="#F8F8F8"/>
                <Setter Property="Foreground" Value="#A0A0A0"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="Button" x:Key="AccentButton" BasedOn="{StaticResource {x:Type Button}}">
      <Setter Property="Background" Value="#0078D4"/>
      <Setter Property="BorderBrush" Value="#0078D4"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}"
                    CornerRadius="5">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"
                                Margin="{TemplateBinding Padding}"
                                TextBlock.Foreground="{TemplateBinding Foreground}"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#106EBE"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#005A9E"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="bd" Property="Background" Value="#A0A0A0"/>
                <Setter TargetName="bd" Property="BorderBrush" Value="#A0A0A0"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="TextBox">
      <Setter Property="Padding" Value="8"/>
      <Setter Property="BorderBrush" Value="#D6D6D6"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Background" Value="White"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TextBox">
            <Border Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}"
                    CornerRadius="4">
              <ScrollViewer x:Name="PART_ContentHost" Margin="{TemplateBinding Padding}"/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="CheckBox">
      <Setter Property="VerticalContentAlignment" Value="Center"/>
      <Setter Property="Margin" Value="0,2"/>
    </Style>

    <Style TargetType="RadioButton">
      <Setter Property="VerticalAlignment" Value="Center"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/>
      <Setter Property="Margin" Value="0,2"/>
    </Style>

    <Style TargetType="ProgressBar">
      <Setter Property="Background" Value="#E5E5E5"/>
      <Setter Property="Foreground" Value="#0078D4"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ProgressBar">
            <Border Background="{TemplateBinding Background}" CornerRadius="3" ClipToBounds="True">
              <Grid>
                <Rectangle x:Name="PART_Track" Fill="Transparent"/>
                <Rectangle x:Name="PART_Indicator" Fill="{TemplateBinding Foreground}" HorizontalAlignment="Left" RadiusX="3" RadiusY="3"/>
              </Grid>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="CardBorder" TargetType="Border">
      <Setter Property="Background" Value="White"/>
      <Setter Property="CornerRadius" Value="8"/>
      <Setter Property="Padding" Value="18"/>
      <Setter Property="Margin" Value="0,0,0,12"/>
      <Setter Property="BorderBrush" Value="#E0E0E0"/>
      <Setter Property="BorderThickness" Value="1"/>
    </Style>

    <Style x:Key="OpHeader" TargetType="TextBlock">
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="FontSize" Value="16"/>
    </Style>

    <Style x:Key="OpHint" TargetType="TextBlock">
      <Setter Property="Foreground" Value="#666666"/>
      <Setter Property="Margin" Value="28,2,0,8"/>
      <Setter Property="TextWrapping" Value="Wrap"/>
    </Style>

    <Style x:Key="FieldLabel" TargetType="TextBlock">
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Foreground" Value="#444444"/>
      <Setter Property="Margin" Value="0,0,0,3"/>
    </Style>

    <Style x:Key="HintText" TargetType="TextBlock">
      <Setter Property="Foreground" Value="#888888"/>
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="Margin" Value="0,3,0,10"/>
    </Style>

  </Window.Resources>

  <Grid Margin="20">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- Header -->
    <Grid Grid.Row="0" Margin="0,0,0,16">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <StackPanel Grid.Column="0">
        <TextBlock Text="Media Tools" FontSize="28" FontWeight="SemiBold"/>
        <TextBlock Text="Clean up junk, consolidate, and sort a folder of photos and videos."
                   Foreground="#666666" Margin="0,4,0,0" TextWrapping="Wrap"/>
      </StackPanel>
      <!-- One dry-run switch for every operation -->
      <Border Grid.Column="1" x:Name="DryRunBorder" VerticalAlignment="Center" Margin="16,0,0,0"
              Background="White" BorderBrush="#D6D6D6" BorderThickness="1" CornerRadius="6" Padding="12,8">
        <CheckBox x:Name="DryRun" VerticalContentAlignment="Center">
          <StackPanel>
            <TextBlock Text="Dry run" FontWeight="SemiBold"/>
            <TextBlock x:Name="DryRunHint" Text="Off -- changes will be made" FontSize="11" Foreground="#666666"/>
          </StackPanel>
        </CheckBox>
      </Border>
    </Grid>

    <!-- Folder picker -->
    <Border Grid.Row="1" Style="{StaticResource CardBorder}">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <StackPanel Grid.Column="0">
          <TextBlock Text="Source folder" FontWeight="SemiBold" Margin="0,0,0,6"/>
          <TextBox x:Name="FolderTextBox"/>
        </StackPanel>
        <Button Grid.Column="1" x:Name="BrowseButton" Content="Browse..."
                Margin="12,22,0,0" VerticalAlignment="Bottom"/>
      </Grid>
    </Border>

    <!-- Operations -->
    <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="0,0,4,0">
      <StackPanel>

        <!-- Output options -->
        <Border Style="{StaticResource CardBorder}">
          <StackPanel>
            <TextBlock Style="{StaticResource OpHeader}" Text="Output" Margin="0,0,0,10"/>

            <TextBlock Style="{StaticResource FieldLabel}" Text="Output location"/>
            <RadioButton x:Name="OutParent" GroupName="OutLoc" IsChecked="True"
                         Content="Source folder (create the output folders inside it)"/>
            <Grid Margin="0,4,0,0">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
              </Grid.ColumnDefinitions>
              <RadioButton Grid.Column="0" x:Name="OutCustom" GroupName="OutLoc"
                           Content="Other folder or drive:" Margin="0,0,10,0"/>
              <TextBox Grid.Column="1" x:Name="OutputFolderTextBox" IsEnabled="False"/>
              <Button Grid.Column="2" x:Name="OutputBrowseButton" Content="Browse..."
                      Margin="10,0,0,0" IsEnabled="False"/>
            </Grid>

            <TextBlock Style="{StaticResource FieldLabel}" Text="File transfer" Margin="0,14,0,3"/>
            <StackPanel Orientation="Horizontal">
              <RadioButton x:Name="ModeMove" GroupName="Mode" IsChecked="True"
                           Content="Move files" Margin="0,0,24,0"/>
              <RadioButton x:Name="ModeCopy" GroupName="Mode"
                           Content="Copy files (originals stay where they are)"/>
            </StackPanel>

            <TextBlock Style="{StaticResource FieldLabel}" Text="Folder layout" Margin="0,14,0,3"/>
            <StackPanel Orientation="Horizontal">
              <RadioButton x:Name="LayoutSeparate" GroupName="Layout" IsChecked="True" Margin="0,0,24,0">
                <TextBlock>Separate: <Run FontWeight="SemiBold">images\</Run> and <Run FontWeight="SemiBold">videos\</Run></TextBlock>
              </RadioButton>
              <RadioButton x:Name="LayoutTogether" GroupName="Layout">
                <TextBlock>Together: one <Run FontWeight="SemiBold">media\</Run> folder</TextBlock>
              </RadioButton>
            </StackPanel>
            <CheckBox x:Name="KeepParentFolder" Margin="0,10,0,0">
              <TextBlock TextWrapping="Wrap">Keep each file's original folder name, e.g.
                <Run FontFamily="Consolas">Holiday\IMG_01.jpg</Run> becomes
                <Run FontFamily="Consolas">images\2019\Holiday\IMG_01.jpg</Run></TextBlock>
            </CheckBox>
            <CheckBox x:Name="SkipDateFolders" Margin="28,2,0,0" IsChecked="True" IsEnabled="False">
              <TextBlock TextWrapping="Wrap">...except date folders (e.g.
                <Run FontFamily="Consolas">2024-07-03</Run>,
                <Run FontFamily="Consolas">20240703</Run>,
                <Run FontFamily="Consolas">03.07.2024</Run>): those files go straight into the year folder</TextBlock>
            </CheckBox>
          </StackPanel>
        </Border>

        <!-- 1. Cleanup -->
        <Border Style="{StaticResource CardBorder}">
          <StackPanel>
            <CheckBox x:Name="EnableCleanup" IsChecked="True">
              <TextBlock Style="{StaticResource OpHeader}" Text="1. Clean up junk"/>
            </CheckBox>
            <TextBlock Style="{StaticResource OpHint}">
              Removes dotfiles (.DS_Store, ._*), Thumbs.db, small files, junk folders, and empty subfolders. Items go to the Recycle Bin by default.
            </TextBlock>
            <StackPanel Orientation="Horizontal" Margin="28,0,0,4">
              <CheckBox x:Name="CleanupPermanent" Content="Permanent delete" Margin="0,0,18,0"/>
              <CheckBox x:Name="CleanupAggressive" Content="Aggressive size filter"/>
            </StackPanel>
            <StackPanel Orientation="Horizontal" Margin="28,6,0,0">
              <TextBlock Text="Minimum file size:" VerticalAlignment="Center" Margin="0,0,8,0"/>
              <TextBox x:Name="CleanupMinSize" Text="10" Width="72"/>
              <TextBlock Text="KB" VerticalAlignment="Center" Margin="8,0,0,0"/>
            </StackPanel>
          </StackPanel>
        </Border>

        <!-- 2. Consolidate -->
        <Border Style="{StaticResource CardBorder}">
          <StackPanel>
            <CheckBox x:Name="EnableMove" IsChecked="True">
              <TextBlock Style="{StaticResource OpHeader}" Text="2. Consolidate media files"/>
            </CheckBox>
            <TextBlock Style="{StaticResource OpHint}">
              Recursively gathers images and videos from the source folder into the output folder, using the transfer mode and layout chosen above. By default all known media types are included.
            </TextBlock>
            <StackPanel Margin="28,0,0,6">
              <CheckBox x:Name="DupScan">
                <TextBlock TextWrapping="Wrap">Scan for duplicates (identical content) and list them in a Duplicates log</TextBlock>
              </CheckBox>
              <CheckBox x:Name="DupRemove">
                <TextBlock TextWrapping="Wrap">Remove duplicates -- keep one copy; with Copy the extra copies are not copied, with Move they are sent to the Recycle Bin</TextBlock>
              </CheckBox>
            </StackPanel>

            <Expander x:Name="FileTypesExpander" Margin="28,0,0,0"
                      Header="Customize file types" Foreground="#0078D4">
              <Border Background="#FAFAFA" BorderBrush="#E5E5E5" BorderThickness="1"
                      CornerRadius="4" Padding="12" Margin="0,8,0,0">
                <StackPanel>
                  <TextBlock Style="{StaticResource FieldLabel}" Text="Include only:"/>
                  <TextBox x:Name="IncludeBox"/>
                  <TextBlock Style="{StaticResource HintText}">
                    Comma- or space-separated. Leave blank to use every default type. Example: <Run FontFamily="Consolas">jpg, png, mov</Run>
                  </TextBlock>

                  <TextBlock Style="{StaticResource FieldLabel}" Text="Exclude:"/>
                  <TextBox x:Name="ExcludeBox"/>
                  <TextBlock Style="{StaticResource HintText}" Margin="0,3,0,0">
                    Same syntax. Useful for skipping a few formats while keeping the rest. Example: <Run FontFamily="Consolas">heic, raw, mkv</Run>
                  </TextBlock>
                </StackPanel>
              </Border>
            </Expander>
          </StackPanel>
        </Border>

        <!-- 3. Sort -->
        <Border Style="{StaticResource CardBorder}">
          <StackPanel>
            <CheckBox x:Name="EnableSort" IsChecked="True">
              <TextBlock Style="{StaticResource OpHeader}" Text="3. Sort by year"/>
            </CheckBox>
            <TextBlock Style="{StaticResource OpHint}">
              Sorts files in the output folder(s) into year subfolders using metadata when available.
            </TextBlock>
            <StackPanel Orientation="Horizontal" Margin="28,0,0,0">
              <CheckBox x:Name="SortFileDateOnly" Content="Use file dates only (skip metadata)"/>
            </StackPanel>
          </StackPanel>
        </Border>

      </StackPanel>
    </ScrollViewer>

    <!-- Progress card -->
    <Border Grid.Row="3" Style="{StaticResource CardBorder}" Margin="0,8,0,0">
      <StackPanel>
        <Grid Margin="0,0,0,6">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <TextBlock Grid.Column="0" x:Name="StatusText" Text="Ready" FontWeight="SemiBold"/>
          <TextBlock Grid.Column="1" x:Name="StatsText" Text="" Foreground="#666666"/>
        </Grid>
        <ProgressBar x:Name="ProgressBar" Height="6" Minimum="0" Maximum="100" Value="0"/>
        <TextBlock x:Name="CurrentFileText" Text=" " Foreground="#666666"
                   TextTrimming="CharacterEllipsis" Margin="0,6,0,0"/>
      </StackPanel>
    </Border>

    <!-- Log expander -->
    <Expander Grid.Row="4" x:Name="LogExpander" Header="Show log" Margin="0,12,0,0"
              Foreground="#444444" IsExpanded="False">
      <Border Background="#1E1E1E" CornerRadius="6" Padding="10" Margin="0,8,0,0">
        <ScrollViewer x:Name="LogScroller" Height="160" VerticalScrollBarVisibility="Auto">
          <TextBox x:Name="LogBox" Background="Transparent" Foreground="#E8E8E8"
                   BorderThickness="0" IsReadOnly="True" FontFamily="Consolas"
                   FontSize="12" TextWrapping="NoWrap" AcceptsReturn="True"/>
        </ScrollViewer>
      </Border>
    </Expander>

    <!-- Log path row -->
    <Grid Grid.Row="5" Margin="0,10,0,0">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <TextBlock Grid.Column="0" x:Name="LogPathText"
                 Foreground="#0078D4" TextDecorations="Underline" Cursor="Hand"
                 TextTrimming="CharacterEllipsis" VerticalAlignment="Center"
                 Text="Log file will be created in .\Logs\ when you click Run."/>
      <TextBlock Grid.Column="1" x:Name="OpenLogsFolderText"
                 Foreground="#0078D4" TextDecorations="Underline" Cursor="Hand"
                 VerticalAlignment="Center" Margin="16,0,0,0"
                 Text="Open Logs folder"/>
    </Grid>

    <!-- Action buttons -->
    <Grid Grid.Row="6" Margin="0,12,0,0">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <TextBlock Grid.Column="0" x:Name="ElapsedText" Text="" Foreground="#666666"
                 VerticalAlignment="Center"/>
      <Button Grid.Column="1" x:Name="CancelButton" Content="Cancel" Margin="0,0,8,0" IsEnabled="False"/>
      <Button Grid.Column="2" x:Name="RunButton" Content="Run"
              Style="{StaticResource AccentButton}" Padding="32,8"/>
    </Grid>

  </Grid>
</Window>
'@

# --- Parse XAML & grab controls ---------------------------------------------

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$controls = @{}
@('FolderTextBox','BrowseButton',
  'OutParent','OutCustom','OutputFolderTextBox','OutputBrowseButton',
  'ModeMove','ModeCopy','LayoutSeparate','LayoutTogether','KeepParentFolder','SkipDateFolders',
  'DryRun','DryRunBorder','DryRunHint',
  'EnableCleanup','CleanupPermanent','CleanupAggressive','CleanupMinSize',
  'EnableMove','DupScan','DupRemove','FileTypesExpander','IncludeBox','ExcludeBox',
  'EnableSort','SortFileDateOnly',
  'StatusText','StatsText','ProgressBar','CurrentFileText',
  'LogExpander','LogBox','LogScroller','LogPathText','OpenLogsFolderText',
  'ElapsedText','CancelButton','RunButton') | ForEach-Object {
    $controls[$_] = $window.FindName($_)
}

$controls.FolderTextBox.Text = $ScriptDir
$AppVersion = Get-MediaSortVersion
$window.Title = "Media Tools $AppVersion"
if ($IsAdmin) { $window.Title += " (Administrator)" }

# --- Defaults for the consolidate extension fields -------------------------

$DefaultImageExt = Get-MediaImageExtensions
$DefaultVideoExt = Get-MediaVideoExtensions

# --- Shared state -----------------------------------------------------------

$script:state = @{
    Queue        = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
    CancelToken  = [hashtable]::Synchronized(@{ Requested = $false })
    Running      = $false
    Runspace     = $null
    PowerShell   = $null
    AsyncResult  = $null
    StartTime    = $null
    LastUpdate   = $null
    LastCurrent  = 0
    EwmaRate     = $null
    Summaries    = @()
    LastTotal    = 0
    LogPath      = $null
    LogWriter    = $null
    Transfers    = $null
    TransferLogPath = $null
    TransferLogCopyPath = $null
    Duplicates   = $null
    DuplicatesLogPath = $null
    RunInfo      = $null
}

# --- Helpers ----------------------------------------------------------------

function Format-Duration {
    param([TimeSpan]$ts)
    if ($ts.TotalSeconds -lt 1)  { return "<1s" }
    if ($ts.TotalSeconds -lt 60) { return ("{0}s" -f [int]$ts.TotalSeconds) }
    if ($ts.TotalMinutes -lt 60) { return ("{0}m {1:D2}s" -f [int]$ts.TotalMinutes, $ts.Seconds) }
    return ("{0}h {1:D2}m" -f [int]$ts.TotalHours, $ts.Minutes)
}

function Parse-ExtensionList {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
    # Accept comma, semicolon, or whitespace as separators
    $tokens = $Text -split '[,;\s]+' | Where-Object { $_ }
    $result = foreach ($t in $tokens) {
        $e = $t.ToLower().Trim()
        # Strip any leading wildcard
        if ($e.StartsWith('*')) { $e = $e.Substring(1) }
        if (-not $e.StartsWith('.')) { $e = '.' + $e }
        $e
    }
    return @($result | Sort-Object -Unique)
}

function Write-LogLine {
    param([string]$Text)
    if ($script:state.LogWriter) {
        try { $script:state.LogWriter.WriteLine($Text) } catch {}
    }
}

function Append-Log {
    param([string]$Text, [string]$Level='info')
    $stamp = (Get-Date).ToString('HH:mm:ss')
    $line = "[$stamp] $Text"

    Write-LogLine $line

    if ($Level -ne 'detail') {
        $controls.LogBox.AppendText($line + "`r`n")
        $controls.LogScroller.ScrollToEnd()
    }
}

$OptionControls = @(
    'OutParent','OutCustom','ModeMove','ModeCopy','LayoutSeparate','LayoutTogether','KeepParentFolder','SkipDateFolders',
    'DryRun',
    'EnableCleanup','CleanupPermanent','CleanupAggressive','CleanupMinSize',
    'EnableMove','DupScan','DupRemove','FileTypesExpander','IncludeBox','ExcludeBox',
    'EnableSort','SortFileDateOnly')

function Update-OutputControls {
    $custom = [bool]$controls.OutCustom.IsChecked -and $controls.OutCustom.IsEnabled
    $controls.OutputFolderTextBox.IsEnabled = $custom
    $controls.OutputBrowseButton.IsEnabled  = $custom
}

function Update-KeepParentControls {
    $controls.SkipDateFolders.IsEnabled = [bool]$controls.KeepParentFolder.IsChecked -and $controls.KeepParentFolder.IsEnabled
}

function Update-DupControls {
    if ($controls.DupRemove.IsChecked) {
        $controls.DupScan.IsChecked = $true
        $controls.DupScan.IsEnabled = $false
    } elseif ($controls.DupRemove.IsEnabled) {
        $controls.DupScan.IsEnabled = $true
    }
}

function Set-Idle {
    $controls.RunButton.IsEnabled    = $true
    $controls.CancelButton.IsEnabled = $false
    $controls.FolderTextBox.IsEnabled = $true
    $controls.BrowseButton.IsEnabled  = $true
    foreach ($n in $OptionControls) { $controls[$n].IsEnabled = $true }
    Update-OutputControls
    Update-DupControls
    Update-KeepParentControls
}

function Set-Busy {
    $controls.RunButton.IsEnabled    = $false
    $controls.CancelButton.IsEnabled = $true
    $controls.FolderTextBox.IsEnabled = $false
    $controls.BrowseButton.IsEnabled  = $false
    foreach ($n in $OptionControls) { $controls[$n].IsEnabled = $false }
    Update-OutputControls
}

function Get-OutputSettings {
    # Returns @{ Root; Copy; KeepTogether; Folders = @(full paths) }
    $outRoot = $controls.FolderTextBox.Text.Trim()
    if ($controls.OutCustom.IsChecked) { $outRoot = $controls.OutputFolderTextBox.Text.Trim() }
    $together = [bool]$controls.LayoutTogether.IsChecked
    $folders = if ($together) { @('media') } else { @('images','videos') }
    return @{
        Root         = $outRoot
        Copy         = [bool]$controls.ModeCopy.IsChecked
        KeepTogether = $together
        KeepParent   = [bool]$controls.KeepParentFolder.IsChecked
        SkipDates    = [bool]$controls.KeepParentFolder.IsChecked -and [bool]$controls.SkipDateFolders.IsChecked
        Folders      =@($folders | ForEach-Object { [IO.Path]::Combine($outRoot, $_) })
    }
}

function Update-ETA {
    param([int]$Current, [int]$Total)
    $now = Get-Date
    $dt  = ($now - $script:state.LastUpdate).TotalSeconds
    if ($dt -ge 0.5 -and $Current -gt $script:state.LastCurrent) {
        $instantRate = ($Current - $script:state.LastCurrent) / $dt
        if ($null -eq $script:state.EwmaRate) { $script:state.EwmaRate = $instantRate }
        else { $script:state.EwmaRate = 0.3 * $instantRate + 0.7 * $script:state.EwmaRate }
        $script:state.LastUpdate  = $now
        $script:state.LastCurrent = $Current
    }
    if ($script:state.EwmaRate -gt 0 -and $Current -lt $Total) {
        $remaining = ($Total - $Current) / $script:state.EwmaRate
        return [TimeSpan]::FromSeconds([math]::Min($remaining, 86400))
    }
    return $null
}

function Resolve-ConsolidateExtensions {
    # Returns @{ Images = @(...); Videos = @(...); Description = '...' }
    $includeRaw = Parse-ExtensionList $controls.IncludeBox.Text
    $excludeRaw = Parse-ExtensionList $controls.ExcludeBox.Text

    if ($includeRaw.Count -gt 0) {
        # Whitelist mode: intersect with default categorization
        $imgs = @($DefaultImageExt | Where-Object { $includeRaw -contains $_ })
        $vids = @($DefaultVideoExt | Where-Object { $includeRaw -contains $_ })
        $unknown = @($includeRaw | Where-Object { $DefaultImageExt -notcontains $_ -and $DefaultVideoExt -notcontains $_ })
        $desc = "Include list: $($includeRaw -join ' ')"
        if ($unknown.Count -gt 0) { $desc += "    (ignored unknown: $($unknown -join ' '))" }
    } else {
        $imgs = $DefaultImageExt
        $vids = $DefaultVideoExt
        $desc = "Defaults"
    }

    if ($excludeRaw.Count -gt 0) {
        $imgs = @($imgs | Where-Object { $excludeRaw -notcontains $_ })
        $vids = @($vids | Where-Object { $excludeRaw -notcontains $_ })
        $desc += "  /  Excluded: $($excludeRaw -join ' ')"
    }

    return @{ Images = $imgs; Videos = $vids; Description = $desc }
}

function Build-OperationList {
    $ops = @()
    $dry = [bool]$controls.DryRun.IsChecked   # one switch for every operation

    # 1. Cleanup first
    if ($controls.EnableCleanup.IsChecked) {
        $sz = 10
        [int]::TryParse($controls.CleanupMinSize.Text, [ref]$sz) | Out-Null
        $ops += [pscustomobject]@{
            Name           = 'cleanup'
            DryRun         = $dry
            Permanent      = [bool]$controls.CleanupPermanent.IsChecked
            AggressiveSize = [bool]$controls.CleanupAggressive.IsChecked
            MinSizeKB      = $sz
        }
    }

    # 2. Consolidate
    $out = Get-OutputSettings

    if ($controls.EnableMove.IsChecked) {
        $resolved = Resolve-ConsolidateExtensions
        $ops += [pscustomobject]@{
            Name             = 'move'
            DryRun           = $dry
            OutputRoot       = $out.Root
            Copy             = $out.Copy
            KeepTogether     = $out.KeepTogether
            KeepParent       = $out.KeepParent
            SkipDates        = $out.SkipDates
            ImageExtensions  = $resolved.Images
            VideoExtensions  = $resolved.Videos
            Description      = $resolved.Description
            FindDuplicates   = [bool]$controls.DupScan.IsChecked
            RemoveDuplicates = [bool]$controls.DupRemove.IsChecked
        }
    }

    # 3. Sort (inside each output folder)
    if ($controls.EnableSort.IsChecked) {
        $opts = @{
            DryRun          = $dry
            UseFileDateOnly = [bool]$controls.SortFileDateOnly.IsChecked
            KeepParent      = $out.KeepParent
            SkipDates       = $out.SkipDates
        }
        foreach ($folder in $out.Folders) {
            $ops += [pscustomobject]@{ Name='sort'; Target=(Split-Path $folder -Leaf); TargetPath=$folder; Options=$opts }
        }
    }

    return ,$ops
}

# --- Log file management ----------------------------------------------------

function Open-LogFile {
    param([string]$Root, $Operations)

    if (-not (Test-Path -LiteralPath $LogsDir)) {
        New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
    }

    $stamp = (Get-Date).ToString('yyyy-MM-dd_HHmmss')
    $script:state.LogPath = Join-Path $LogsDir "MediaTools-$stamp.txt"
    $script:state.TransferLogPath = Join-Path $LogsDir "Transfers-$stamp.txt"
    $script:state.DuplicatesLogPath = Join-Path $LogsDir "Duplicates-$stamp.txt"
    $script:state.LogWriter = New-Object System.IO.StreamWriter $script:state.LogPath, $false, ([System.Text.Encoding]::UTF8)
    $script:state.LogWriter.AutoFlush = $true

    $w = $script:state.LogWriter
    $w.WriteLine("============================================================")
    $w.WriteLine("  Media Tools $AppVersion -- Run Log")
    $w.WriteLine("============================================================")
    $w.WriteLine("  Started:    $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $w.WriteLine("  Source:     $Root")
    $out = Get-OutputSettings
    $w.WriteLine("  Output:     $($out.Root)")
    $w.WriteLine("  Transfer:   $(if ($out.Copy) { 'Copy' } else { 'Move' })")
    $w.WriteLine("  Layout:     $(if ($out.KeepTogether) { 'Together (media\)' } else { 'Separate (images\ + videos\)' })")
    $w.WriteLine("  Keep folder name: $(if ($out.SkipDates) { 'Yes, except date folders' } elseif ($out.KeepParent) { 'Yes' } else { 'No' })")
    $w.WriteLine("  Dry run:    $(if ($controls.DryRun.IsChecked) { 'YES -- preview only, nothing is changed' } else { 'No' })")
    $w.WriteLine("  Logs path:  $($script:state.LogPath)")
    $w.WriteLine("")
    $w.WriteLine("  Operations:")
    foreach ($op in $Operations) {
        switch ($op.Name) {
            'cleanup' {
                $bits = @("MinSizeKB=$($op.MinSizeKB)")
                if ($op.DryRun)         { $bits += 'DryRun' }
                if ($op.Permanent)      { $bits += 'Permanent' }
                if ($op.AggressiveSize) { $bits += 'AggressiveSize' }
                $w.WriteLine("    - Cleanup junk             [$($bits -join ', ')]")
            }
            'move' {
                $bits = @()
                if ($op.DryRun) { $bits += 'DryRun' }
                $bits += $(if ($op.Copy) { 'Copy' } else { 'Move' })
                if ($op.KeepTogether) { $bits += 'Together' }
                if ($op.RemoveDuplicates) { $bits += 'RemoveDuplicates' } elseif ($op.FindDuplicates) { $bits += 'FindDuplicates' }
                $bits += "$($op.ImageExtensions.Count) image types"
                $bits += "$($op.VideoExtensions.Count) video types"
                $w.WriteLine("    - Consolidate media        [$($bits -join ', ')]")
                $w.WriteLine("        Filter: $($op.Description)")
                $w.WriteLine("        Images: $($op.ImageExtensions -join ' ')")
                $w.WriteLine("        Videos: $($op.VideoExtensions -join ' ')")
            }
            'sort' {
                $bits = @("target=$($op.TargetPath)")
                if ($op.Options.DryRun)          { $bits += 'DryRun' }
                if ($op.Options.UseFileDateOnly) { $bits += 'UseFileDateOnly' }
                $w.WriteLine("    - Sort by year             [$($bits -join ', ')]")
            }
        }
    }
    $w.WriteLine("============================================================")
    $w.WriteLine("")

    $controls.LogPathText.Text = "Log: $($script:state.LogPath)  (click to open)"
}

function Close-LogFile {
    param([string]$ClosingNote = '')
    if (-not $script:state.LogWriter) { return }
    try {
        if ($ClosingNote) { $script:state.LogWriter.WriteLine($ClosingNote) }
        $script:state.LogWriter.Close()
        $script:state.LogWriter.Dispose()
    } catch {}
    $script:state.LogWriter = $null
}

function New-RunInfo {
    # Settings shown in the transfer log header (captured when Run is clicked).
    param([string]$Root, $Operations)
    $out    = Get-OutputSettings
    $moveOp = $Operations | Where-Object { $_.Name -eq 'move' } | Select-Object -First 1
    $sortOp = $Operations | Where-Object { $_.Name -eq 'sort' } | Select-Object -First 1

    $consolidate = 'Off'
    if ($moveOp) {
        $consolidate = if ($out.Copy) { 'Copy (originals kept in place)' } else { 'Move' }
        if ($moveOp.DryRun) { $consolidate += '  -- DRY RUN' }
    }
    $sort = 'Off'
    if ($sortOp) {
        $sort = if ($sortOp.Options.UseFileDateOnly) { 'On (file dates only)' } else { 'On (metadata, else file dates)' }
        if ($sortOp.Options.DryRun) { $sort += '  -- DRY RUN' }
    }

    $info = [ordered]@{
        'Started'       = $script:state.StartTime.ToString('yyyy-MM-dd HH:mm:ss')
        'Source folder' = $Root
        'Output folder' = $out.Root
        'Consolidate'   = $consolidate
        'Layout'        = $(if ($out.KeepTogether) { 'Together (media\)' } else { 'Separate (images\ + videos\)' })
        'Keep folder name' = $(if ($out.SkipDates) { 'Yes, except date folders (year\original folder\file)' } elseif ($out.KeepParent) { 'Yes (year\original folder\file)' } else { 'No' })
        'Sort by year'  = $sort
    }
    if ($moveOp) {
        $info['File types'] = $moveOp.Description
        $info['Duplicates'] = if ($moveOp.RemoveDuplicates) {
            if ($out.Copy) { 'Remove (extra copies are not copied)' } else { 'Remove (extra copies go to the Recycle Bin)' }
        } elseif ($moveOp.FindDuplicates) { 'Scan only' } else { 'Off' }
    }
    return $info
}

function Save-TransferLog {
    param([string]$Status)
    $store = $script:state.Transfers
    if (-not $store -or $store.Records.Count -eq 0) { return }

    if (-not $script:state.TransferLogPath) {
        $script:state.TransferLogPath = Join-Path $LogsDir ("Transfers-{0}.txt" -f $script:state.StartTime.ToString('yyyy-MM-dd_HHmmss'))
    }
    $info = [ordered]@{}
    foreach ($k in $script:state.RunInfo.Keys) {
        $info[$k] = $script:state.RunInfo[$k]
        if ($k -eq 'Started') {
            $info['Finished'] = "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))  (took $(Format-Duration ((Get-Date) - $script:state.StartTime)))"
            $info['Status']   = $Status
        }
    }
    if ($script:state.LogPath) { $info['Run log'] = $script:state.LogPath }

    try {
        # A copy goes into the output folder, next to the transferred files.
        $saved = Write-MediaTransferLog -Path $script:state.TransferLogPath -Store $store -Info $info `
                    -CopyToFolder $script:state.RunInfo['Output folder']
        $script:state.TransferLogCopyPath = $saved.CopyPath
        Append-Log "Transfer log saved: $($saved.Path)"
        if ($saved.CopyPath) { Append-Log "Transfer log copy saved with the files: $($saved.CopyPath)" }
    } catch {
        Append-Log "Could not write transfer log: $($_.Exception.Message)" 'warn'
        $script:state.TransferLogPath = $null
    }
}

function Save-DuplicateLog {
    param([string]$Status)
    $dups = $script:state.Duplicates
    if (-not $dups) { return }
    if (-not $script:state.DuplicatesLogPath) {
        $script:state.DuplicatesLogPath = Join-Path $LogsDir ("Duplicates-{0}.txt" -f $script:state.StartTime.ToString('yyyy-MM-dd_HHmmss'))
    }
    $info = [ordered]@{}
    foreach ($k in $script:state.RunInfo.Keys) {
        if ($k -in 'Duplicates', 'File types', 'Sort by year', 'Keep folder name', 'Layout') { continue }
        $info[$k] = $script:state.RunInfo[$k]
        if ($k -eq 'Started') { $info['Status'] = $Status }
    }
    if ($script:state.TransferLogPath) { $info['Transfer log'] = $script:state.TransferLogPath }
    try {
        Write-MediaDuplicateLog -Path $script:state.DuplicatesLogPath -Duplicates $dups -Info $info | Out-Null
        Append-Log "Duplicates log saved: $($script:state.DuplicatesLogPath)"
    } catch {
        Append-Log "Could not write duplicates log: $($_.Exception.Message)" 'warn'
        $script:state.DuplicatesLogPath = $null
    }
}

function Write-LogFooter {
    param([bool]$Cancelled)
    if (-not $script:state.LogWriter) { return }
    $w = $script:state.LogWriter
    $elapsed = (Get-Date) - $script:state.StartTime

    $w.WriteLine("")
    $w.WriteLine("============================================================")
    $w.WriteLine("  Summary")
    $w.WriteLine("============================================================")
    $w.WriteLine("  Finished:  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $w.WriteLine("  Duration:  $(Format-Duration $elapsed)")
    if ($Cancelled) { $w.WriteLine("  Status:    CANCELLED") }
    $w.WriteLine("")

    foreach ($entry in $script:state.Summaries) {
        $s  = $entry.Result
        $op = $entry.Op
        switch ($op.Name) {
            'cleanup' {
                $w.WriteLine("  Cleanup:")
                $w.WriteLine(("    Junk files removed    : {0}" -f $s.JunkFileCount))
                $w.WriteLine(("    Small files removed   : {0}" -f $s.SmallFileCount))
                $w.WriteLine(("    Junk folders removed  : {0}" -f $s.JunkFolderCount))
                $w.WriteLine(("    Empty folders removed : {0}" -f $s.EmptyFolderCount))
                $w.WriteLine(("    Space reclaimed       : {0:N2} MB" -f ($s.BytesReclaimed / 1MB)))
                if ($s.Failed -gt 0) { $w.WriteLine(("    Failures              : {0}" -f $s.Failed)) }
                if ($s.DryRun)       { $w.WriteLine("    (Dry run -- nothing actually deleted.)") }
                if ($s.Cancelled)    { $w.WriteLine("    (Cancelled.)") }
            }
            'move' {
                $verb = if ($s.Copy) { 'copied' } else { 'moved' }
                $w.WriteLine("  Consolidate:")
                $w.WriteLine(("    Images {0} : {1}" -f $verb, $s.ImageCount))
                $w.WriteLine(("    Videos {0} : {1}" -f $verb, $s.VideoCount))
                $w.WriteLine(("    Output to    : {0}" -f ($s.OutputFolders -join ', ')))
                if ($op.FindDuplicates) {
                    $w.WriteLine(("    Duplicate groups   : {0}" -f $s.DuplicateGroups))
                    if ($op.RemoveDuplicates) {
                        $w.WriteLine(("    Duplicates removed : {0}  ({1:N1} MB)" -f $s.DuplicatesRemoved, ($s.DuplicateBytes / 1MB)))
                    }
                }
                if ($s.Failed -gt 0) { $w.WriteLine(("    Failures     : {0}" -f $s.Failed)) }
                if ($s.DryRun)       { $w.WriteLine("    (Dry run -- nothing actually $verb.)") }
                if ($s.Cancelled)    { $w.WriteLine("    (Cancelled.)") }
            }
            'sort' {
                $w.WriteLine("  Sort by year [$($op.Target)\]:")
                $w.WriteLine(("    Files moved : {0}" -f $s.Moved))
                if ($s.Failed -gt 0) { $w.WriteLine(("    Failures    : {0}" -f $s.Failed)) }
                if ($s.ByYear.Count -gt 0) {
                    $w.WriteLine("    By year:")
                    foreach ($k in ($s.ByYear.Keys | Sort-Object)) {
                        $w.WriteLine(("      {0,-10} : {1}" -f $k, $s.ByYear[$k]))
                    }
                }
                if ($s.DryRun)    { $w.WriteLine("    (Dry run -- nothing actually moved.)") }
                if ($s.Cancelled) { $w.WriteLine("    (Cancelled.)") }
            }
        }
        $w.WriteLine("")
    }
    $w.WriteLine("============================================================")
}

function Show-Summary {
    param([bool]$Cancelled)
    $totalElapsed = (Get-Date) - $script:state.StartTime
    $title = if ($Cancelled) { "Cancelled after $(Format-Duration $totalElapsed)" } else { "Completed in $(Format-Duration $totalElapsed)" }
    $msg = "$title.`n`n"

    foreach ($entry in $script:state.Summaries) {
        $s   = $entry.Result
        $op  = $entry.Op
        switch ($op.Name) {
            'cleanup' {
                $msg += ("Cleanup: {0} junk files, {1} small files, {2} junk folders, {3} empty folders -- {4:N1} MB reclaimed" -f
                    $s.JunkFileCount, $s.SmallFileCount, $s.JunkFolderCount, $s.EmptyFolderCount, ($s.BytesReclaimed/1MB))
                if ($s.Failed -gt 0) { $msg += "  ($($s.Failed) failed)" }
                if ($s.DryRun)       { $msg += "  (dry run)" }
                $msg += "`n"
            }
            'move' {
                $verb = if ($s.Copy) { 'copied' } else { 'moved' }
                $msg += "Consolidate: $($s.ImageCount) images, $($s.VideoCount) videos $verb"
                if ($s.Failed -gt 0) { $msg += "  ($($s.Failed) failed)" }
                if ($s.DryRun)       { $msg += "  (dry run)" }
                $msg += "`n"
                if ($op.FindDuplicates) {
                    $msg += "Duplicates: $($s.DuplicateGroups) groups found"
                    if ($op.RemoveDuplicates) {
                        $msg += (", {0} extra copies {1} ({2:N1} MB)" -f $s.DuplicatesRemoved,
                                 $(if ($s.DryRun) { 'would be removed' } elseif ($s.Copy) { 'not copied' } else { 'removed' }), ($s.DuplicateBytes / 1MB))
                    }
                    $msg += "`n"
                }
            }
            'sort' {
                $tag = if ($op.Target) { " [$($op.Target)]" } else { "" }
                $msg += "Sort${tag}: $($s.Moved) files"
                if ($s.Failed -gt 0) { $msg += "  ($($s.Failed) failed)" }
                if ($s.DryRun)       { $msg += "  (dry run)" }
                $msg += "`n"
            }
        }
    }
    $msg += "`nLog saved to:`n$($script:state.LogPath)"
    if ($script:state.TransferLogPath -and (Test-Path -LiteralPath $script:state.TransferLogPath)) {
        $msg += "`n`nTransfer log (every file moved/copied):`n$($script:state.TransferLogPath)"
        if ($script:state.TransferLogCopyPath) {
            $msg += "`n`nCopy saved with the files:`n$($script:state.TransferLogCopyPath)"
        }
    }
    if ($script:state.DuplicatesLogPath -and (Test-Path -LiteralPath $script:state.DuplicatesLogPath)) {
        $msg += "`n`nDuplicates log:`n$($script:state.DuplicatesLogPath)"
    }
    [System.Windows.MessageBox]::Show($msg, "Media Tools", 'OK', 'Information') | Out-Null
}

# --- Start the worker -------------------------------------------------------

function Start-Work {
    $root = $controls.FolderTextBox.Text
    if (-not (Test-Path -LiteralPath $root)) {
        [System.Windows.MessageBox]::Show("Folder not found:`n$root", "Media Tools", 'OK', 'Error') | Out-Null
        return
    }

    if ($controls.OutCustom.IsChecked) {
        $outPath = $controls.OutputFolderTextBox.Text.Trim()
        if (-not $outPath -or -not [IO.Path]::IsPathRooted($outPath)) {
            [System.Windows.MessageBox]::Show("Please choose an output folder or drive (a full path such as E:\ or D:\Sorted).",
                "Media Tools", 'OK', 'Warning') | Out-Null
            return
        }
        $outDrive = [IO.Path]::GetPathRoot($outPath)
        if (-not (Test-Path -LiteralPath $outDrive)) {
            [System.Windows.MessageBox]::Show("Output drive not found: $outDrive", "Media Tools", 'OK', 'Error') | Out-Null
            return
        }
    }

    $ops = Build-OperationList
    if ($ops.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Please enable at least one operation.", "Media Tools", 'OK', 'Information') | Out-Null
        return
    }

    # Make sure consolidate has at least one extension
    $moveOp = $ops | Where-Object { $_.Name -eq 'move' } | Select-Object -First 1
    if ($moveOp -and (($moveOp.ImageExtensions.Count + $moveOp.VideoExtensions.Count) -eq 0)) {
        [System.Windows.MessageBox]::Show(
            "Consolidate is enabled but the Include/Exclude filters leave no file types.`nClear both fields to use the defaults.",
            "Media Tools", 'OK', 'Warning') | Out-Null
        return
    }

    # Confirm before duplicates go to the Recycle Bin
    if ($moveOp -and $moveOp.RemoveDuplicates -and -not $moveOp.Copy -and -not $moveOp.DryRun) {
        $confirm = [System.Windows.MessageBox]::Show(
            "Remove duplicates is on with Move.`n`nFor every set of identical files one copy is moved; the other copies are sent to the Recycle Bin (only after the kept copy was moved successfully). On drives without a Recycle Bin they are left in place.`n`nTip: run with Dry run first and check the Duplicates log.`n`nContinue?",
            "Media Tools", 'YesNo', 'Warning')
        if ($confirm -ne 'Yes') { return }
    }

    # Confirm before permanent delete
    $cleanupOp = $ops | Where-Object { $_.Name -eq 'cleanup' } | Select-Object -First 1
    if ($cleanupOp -and $cleanupOp.Permanent -and -not $cleanupOp.DryRun) {
        $confirm = [System.Windows.MessageBox]::Show(
            "You enabled PERMANENT delete for cleanup.`nFiles will skip the Recycle Bin.`n`nContinue?",
            "Media Tools", 'YesNo', 'Warning')
        if ($confirm -ne 'Yes') { return }
    }

    # Reset state
    $script:state.CancelToken.Requested = $false
    $script:state.StartTime  = Get-Date
    $script:state.LastUpdate = Get-Date
    $script:state.LastCurrent = 0
    $script:state.EwmaRate   = $null
    $script:state.Summaries  = @()
    $script:state.Transfers  = New-MediaTransferStore
    $script:state.TransferLogPath = $null
    $script:state.TransferLogCopyPath = $null
    $script:state.Duplicates = $null
    $script:state.DuplicatesLogPath = $null
    $script:state.RunInfo    = New-RunInfo -Root $root -Operations $ops
    $script:state.LastTotal  = 0

    $controls.ProgressBar.Value = 0
    $controls.StatusText.Text   = "Starting..."
    $controls.StatsText.Text    = ""
    $controls.CurrentFileText.Text = " "
    $controls.LogBox.Clear()

    try {
        Open-LogFile -Root $root -Operations $ops
    } catch {
        [System.Windows.MessageBox]::Show("Could not create log file: $($_.Exception.Message)`n`nRun will continue without logging.",
            "Media Tools", 'OK', 'Warning') | Out-Null
    }

    Append-Log "Starting run."

    Set-Busy

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'
    $rs.ThreadOptions  = 'ReuseThread'
    $rs.Open()
    $rs.SessionStateProxy.SetVariable('queue',       $script:state.Queue)
    $rs.SessionStateProxy.SetVariable('cancelToken', $script:state.CancelToken)

    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript({
        param($modulePath, $root, $operations)

        Import-Module $modulePath -Force

        $cb = { param($e) $queue.Enqueue($e) }

        foreach ($op in $operations) {
            if ($cancelToken.Requested) { break }

            try {
                switch ($op.Name) {
                    'cleanup' {
                        $r = Invoke-CleanupJunk -Root $root -MinSizeKB $op.MinSizeKB `
                                -DryRun:$op.DryRun -Permanent:$op.Permanent `
                                -AggressiveSize:$op.AggressiveSize `
                                -OnProgress $cb -CancelToken $cancelToken
                        $queue.Enqueue(@{ Type='op-done'; Op=$op; Result=$r })
                    }
                    'move' {
                        $r = Invoke-MoveMedia -Root $root -DryRun:$op.DryRun `
                                              -OutputRoot $op.OutputRoot `
                                              -Copy:$op.Copy -KeepTogether:$op.KeepTogether `
                                              -KeepParentFolder:$op.KeepParent `
                                              -SkipDateFolders:$op.SkipDates `
                                              -FindDuplicates:$op.FindDuplicates `
                                              -RemoveDuplicates:$op.RemoveDuplicates `
                                              -ImageExtensions $op.ImageExtensions `
                                              -VideoExtensions $op.VideoExtensions `
                                              -OnProgress $cb -CancelToken $cancelToken
                        $queue.Enqueue(@{ Type='op-done'; Op=$op; Result=$r })
                    }
                    'sort' {
                        $target = $op.TargetPath
                        if (Test-Path -LiteralPath $target) {
                            $o = $op.Options
                            $r = Invoke-SortMediaByYear -Root $target -DryRun:$o.DryRun `
                                    -UseFileDateOnly:$o.UseFileDateOnly `
                                    -KeepParentFolder:$o.KeepParent `
                                    -SkipDateFolders:$o.SkipDates `
                                    -OnProgress $cb -CancelToken $cancelToken
                            $queue.Enqueue(@{ Type='op-done'; Op=$op; Result=$r })
                        } else {
                            $queue.Enqueue(@{ Type='log'; Level='warn';
                                Message="Skipping sort: '$target' does not exist." })
                        }
                    }
                }
            } catch {
                $queue.Enqueue(@{ Type='log'; Level='warn'; Message="Error in $($op.Name): $($_.Exception.Message)" })
            }
        }
        $queue.Enqueue(@{ Type='all-done' })
    }).AddArgument($modulePath).AddArgument($root).AddArgument($ops)

    $script:state.Runspace    = $rs
    $script:state.PowerShell  = $ps
    $script:state.AsyncResult = $ps.BeginInvoke()
    $script:state.Running     = $true
}

# --- Drain queue on UI thread -----------------------------------------------

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(100)
$timer.Add_Tick({
    if ($script:state.Running -and $script:state.StartTime) {
        $controls.ElapsedText.Text = "Elapsed: $(Format-Duration ((Get-Date) - $script:state.StartTime))"
    }

    $maxPerTick = 500
    $processed = 0
    $evt = $null
    while ($processed -lt $maxPerTick -and $script:state.Queue.TryDequeue([ref]$evt)) {
        $processed++
        switch ($evt.Type) {
            'phase' {
                $phaseName = switch ($evt.Phase) {
                    'cleanup' { 'Cleaning up junk' }
                    'move'    { 'Consolidating media files' }
                    'dupscan' { 'Checking for duplicates' }
                    'sort'    { 'Sorting by year' }
                    default   { $evt.Phase }
                }
                $controls.StatusText.Text = "$phaseName..."
                $controls.ProgressBar.Value = 0
                $controls.StatsText.Text   = ""
                $script:state.LastUpdate   = Get-Date
                $script:state.LastCurrent  = 0
                $script:state.EwmaRate     = $null
                Append-Log $evt.Message
            }
            'scan-done' {
                $controls.StatusText.Text = "$($controls.StatusText.Text.TrimEnd('.')) ($($evt.Total.ToString('N0')) items)"
                $script:state.LastTotal = $evt.Total
                Append-Log "Pre-scan found $($evt.Total) items."
                if ($evt.Total -eq 0) {
                    Append-Log "Nothing to process for this phase."
                }
            }
            'progress' {
                $pct = if ($evt.Total -gt 0) { 100.0 * $evt.Current / $evt.Total } else { 0 }
                $controls.ProgressBar.Value = $pct
                $controls.CurrentFileText.Text = $evt.Name
                $eta = Update-ETA -Current $evt.Current -Total $evt.Total
                $stats = ("{0:N0} / {1:N0}" -f $evt.Current, $evt.Total)
                if ($eta) { $stats += "   ETA $(Format-Duration $eta)" }
                $controls.StatsText.Text = $stats
            }
            'log' {
                Append-Log $evt.Message $evt.Level
            }
            'duplicates' {
                $script:state.Duplicates = $evt
            }
            'transfer' {
                Register-MediaTransfer -Store $script:state.Transfers -Transfer $evt
            }
            'op-done' {
                $script:state.Summaries += @{ Op=$evt.Op; Result=$evt.Result }
            }
            'phase-done' {
                # Per-op summary already arrived via op-done.
            }
            'all-done' {
                $script:state.Running = $false
                $controls.ProgressBar.Value = 100
                $cancelled = ($script:state.Summaries | Where-Object { $_.Result.Cancelled }).Count -gt 0
                $totalElapsed = (Get-Date) - $script:state.StartTime
                $controls.StatusText.Text = if ($cancelled) {
                    "Cancelled after $(Format-Duration $totalElapsed)"
                } else {
                    "Done in $(Format-Duration $totalElapsed)"
                }
                $controls.CurrentFileText.Text = " "

                Append-Log "Run finished."
                Save-TransferLog -Status $(if ($cancelled) { 'Cancelled by user' } else { 'Completed' })
                Save-DuplicateLog -Status $(if ($cancelled) { 'Cancelled by user' } else { 'Completed' })
                Write-LogFooter -Cancelled $cancelled
                Close-LogFile

                Set-Idle

                try { $script:state.PowerShell.EndInvoke($script:state.AsyncResult) } catch {}
                try { $script:state.PowerShell.Dispose() } catch {}
                try { $script:state.Runspace.Dispose() } catch {}
                $script:state.PowerShell = $null
                $script:state.Runspace   = $null

                Show-Summary -Cancelled $cancelled
            }
        }
    }
})
$timer.Start()

# --- Wire up buttons --------------------------------------------------------

$controls.BrowseButton.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Select the parent folder to operate on"
    if (Test-Path -LiteralPath $controls.FolderTextBox.Text) {
        $dlg.SelectedPath = $controls.FolderTextBox.Text
    }
    if ($dlg.ShowDialog() -eq 'OK') {
        $controls.FolderTextBox.Text = $dlg.SelectedPath
    }
})

$controls.OutputBrowseButton.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Select the output folder or drive"
    $dlg.ShowNewFolderButton = $true
    if ($controls.OutputFolderTextBox.Text -and (Test-Path -LiteralPath $controls.OutputFolderTextBox.Text)) {
        $dlg.SelectedPath = $controls.OutputFolderTextBox.Text
    }
    if ($dlg.ShowDialog() -eq 'OK') {
        $controls.OutputFolderTextBox.Text = $dlg.SelectedPath
    }
})

function Update-DryRunLook {
    if ($controls.DryRun.IsChecked) {
        $controls.DryRunBorder.Background  = '#FFF4CE'
        $controls.DryRunBorder.BorderBrush = '#E0B000'
        $controls.DryRunHint.Text = 'On -- preview only, nothing is changed'
        $controls.RunButton.Content = 'Preview'
    } else {
        $controls.DryRunBorder.Background  = 'White'
        $controls.DryRunBorder.BorderBrush = '#D6D6D6'
        $controls.DryRunHint.Text = 'Off -- changes will be made'
        $controls.RunButton.Content = 'Run'
    }
}
$controls.KeepParentFolder.Add_Checked({ Update-KeepParentControls })
$controls.KeepParentFolder.Add_Unchecked({ Update-KeepParentControls })

$controls.DupRemove.Add_Checked({ Update-DupControls })
$controls.DupRemove.Add_Unchecked({ Update-DupControls })

$controls.DryRun.Add_Checked({ Update-DryRunLook })
$controls.DryRun.Add_Unchecked({ Update-DryRunLook })

$controls.OutParent.Add_Checked({ Update-OutputControls })
$controls.OutCustom.Add_Checked({ Update-OutputControls })

$controls.RunButton.Add_Click({ Start-Work })

$controls.CancelButton.Add_Click({
    $script:state.CancelToken.Requested = $true
    $controls.CancelButton.IsEnabled = $false
    $controls.StatusText.Text = "Cancelling..."
    Append-Log "Cancellation requested by user." 'warn'
})

$controls.LogPathText.Add_MouseLeftButtonDown({
    if ($script:state.LogPath -and (Test-Path -LiteralPath $script:state.LogPath)) {
        try { Start-Process $script:state.LogPath } catch {}
    } elseif (Test-Path -LiteralPath $LogsDir) {
        try { Start-Process $LogsDir } catch {}
    }
})

$controls.OpenLogsFolderText.Add_MouseLeftButtonDown({
    if (-not (Test-Path -LiteralPath $LogsDir)) {
        New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
    }
    try { Start-Process $LogsDir } catch {}
})

$window.Add_Closing({
    param($sender, $args)
    if ($script:state.Running) {
        $script:state.CancelToken.Requested = $true
        if ($script:state.PowerShell) {
            try { $script:state.PowerShell.Stop() } catch {}
            try { $script:state.PowerShell.Dispose() } catch {}
        }
        if ($script:state.Runspace) {
            try { $script:state.Runspace.Dispose() } catch {}
        }
        # Collect whatever already arrived so the transfer log reflects what really happened.
        $evt = $null
        while ($script:state.Queue.TryDequeue([ref]$evt)) {
            if ($evt.Type -eq 'transfer') { Register-MediaTransfer -Store $script:state.Transfers -Transfer $evt }
            if ($evt.Type -eq 'duplicates') { $script:state.Duplicates = $evt }
        }
        Save-TransferLog -Status 'Interrupted (window closed mid-run)'
        Save-DuplicateLog -Status 'Interrupted (window closed mid-run)'
        Close-LogFile -ClosingNote "`r`n[Window closed mid-run]"
    } else {
        Close-LogFile
    }
    $timer.Stop()
})

# --- Show it ----------------------------------------------------------------

[void]$window.ShowDialog()

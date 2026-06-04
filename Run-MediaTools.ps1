<#
    Run-MediaTools.ps1
    GUI launcher for MediaTools.psm1.

    Requires MediaTools.psm1 in the same folder.

    Just double-click this script (or run it from PowerShell). If the
    script can't run due to execution policy, right-click it ->
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
        Title="Media Tools" Height="820" Width="860"
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

    <Style TargetType="Button" x:Key="MiniButton" BasedOn="{StaticResource {x:Type Button}}">
      <Setter Property="Padding" Value="8,2"/>
      <Setter Property="FontSize" Value="11"/>
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

    <Style x:Key="SubHeader" TargetType="TextBlock">
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Foreground" Value="#444444"/>
      <Setter Property="Margin" Value="0,8,8,4"/>
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
    <StackPanel Grid.Row="0" Margin="0,0,0,16">
      <TextBlock Text="Media Tools" FontSize="28" FontWeight="SemiBold"/>
      <TextBlock Text="Clean up junk, consolidate, and sort a folder of photos and videos."
                 Foreground="#666666" Margin="0,4,0,0"/>
    </StackPanel>

    <!-- Folder picker -->
    <Border Grid.Row="1" Style="{StaticResource CardBorder}">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <StackPanel Grid.Column="0">
          <TextBlock Text="Target folder" FontWeight="SemiBold" Margin="0,0,0,6"/>
          <TextBox x:Name="FolderTextBox"/>
        </StackPanel>
        <Button Grid.Column="1" x:Name="BrowseButton" Content="Browse..."
                Margin="12,22,0,0" VerticalAlignment="Bottom"/>
      </Grid>
    </Border>

    <!-- Operations -->
    <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="0,0,4,0">
      <StackPanel>

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
              <CheckBox x:Name="CleanupDryRun" Content="Dry run" Margin="0,0,18,0"/>
              <CheckBox x:Name="CleanupPermanent" Content="Permanent delete" Margin="0,0,18,0"/>
              <CheckBox x:Name="CleanupAggressive" Content="Aggressive size filter"/>
            </StackPanel>
            <StackPanel Orientation="Horizontal" Margin="28,6,0,0">
              <TextBlock Text="Minimum file size:" VerticalAlignment="Center" Margin="0,0,8,0"/>
              <TextBox x:Name="CleanupMinSize" Text="10" Width="48"/>
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
              Recursively gathers images into <Run FontWeight="SemiBold">images\</Run> and videos into <Run FontWeight="SemiBold">videos\</Run>. Pick which file types to include below.
            </TextBlock>
            <StackPanel Orientation="Horizontal" Margin="28,0,0,4">
              <CheckBox x:Name="MoveDryRun" Content="Dry run (preview only)"/>
            </StackPanel>

            <StackPanel Orientation="Horizontal" Margin="28,8,0,0">
              <TextBlock Style="{StaticResource SubHeader}" Text="Images" VerticalAlignment="Center"/>
              <Button x:Name="ImageAllBtn" Style="{StaticResource MiniButton}" Content="all" Margin="4,4,2,0"/>
              <Button x:Name="ImageNoneBtn" Style="{StaticResource MiniButton}" Content="none" Margin="0,4,0,0"/>
            </StackPanel>
            <WrapPanel x:Name="ImageExtPanel" Margin="28,2,0,0"/>

            <StackPanel Orientation="Horizontal" Margin="28,8,0,0">
              <TextBlock Style="{StaticResource SubHeader}" Text="Videos" VerticalAlignment="Center"/>
              <Button x:Name="VideoAllBtn" Style="{StaticResource MiniButton}" Content="all" Margin="4,4,2,0"/>
              <Button x:Name="VideoNoneBtn" Style="{StaticResource MiniButton}" Content="none" Margin="0,4,0,0"/>
            </StackPanel>
            <WrapPanel x:Name="VideoExtPanel" Margin="28,2,0,0"/>
          </StackPanel>
        </Border>

        <!-- 3. Sort -->
        <Border Style="{StaticResource CardBorder}">
          <StackPanel>
            <CheckBox x:Name="EnableSort" IsChecked="True">
              <TextBlock Style="{StaticResource OpHeader}" Text="3. Sort by year"/>
            </CheckBox>
            <TextBlock Style="{StaticResource OpHint}">
              Sorts files in <Run FontWeight="SemiBold">images\</Run> and <Run FontWeight="SemiBold">videos\</Run> into year subfolders (2015\, 2016\, ...) using EXIF / media metadata when available.
            </TextBlock>
            <StackPanel Orientation="Horizontal" Margin="28,0,0,0">
              <CheckBox x:Name="SortDryRun" Content="Dry run" Margin="0,0,18,0"/>
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

    <!-- Log file path -->
    <TextBlock Grid.Row="5" x:Name="LogPathText" Margin="0,10,0,0"
               Foreground="#0078D4" TextDecorations="Underline" Cursor="Hand"
               TextTrimming="CharacterEllipsis"
               Text="Log file will be created in .\Logs\ when you click Run."/>

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
  'EnableCleanup','CleanupDryRun','CleanupPermanent','CleanupAggressive','CleanupMinSize',
  'EnableMove','MoveDryRun','ImageExtPanel','VideoExtPanel',
  'ImageAllBtn','ImageNoneBtn','VideoAllBtn','VideoNoneBtn',
  'EnableSort','SortDryRun','SortFileDateOnly',
  'StatusText','StatsText','ProgressBar','CurrentFileText',
  'LogExpander','LogBox','LogScroller','LogPathText',
  'ElapsedText','CancelButton','RunButton') | ForEach-Object {
    $controls[$_] = $window.FindName($_)
}

$controls.FolderTextBox.Text = $ScriptDir

# --- Populate extension checkboxes -----------------------------------------

$imageExtCheckboxes = @()
$videoExtCheckboxes = @()

foreach ($ext in (Get-MediaImageExtensions)) {
    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Content = $ext
    $cb.IsChecked = $true
    $cb.Margin = '0,2,14,2'
    $cb.Tag = $ext
    [void]$controls.ImageExtPanel.Children.Add($cb)
    $imageExtCheckboxes += $cb
}
foreach ($ext in (Get-MediaVideoExtensions)) {
    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Content = $ext
    $cb.IsChecked = $true
    $cb.Margin = '0,2,14,2'
    $cb.Tag = $ext
    [void]$controls.VideoExtPanel.Children.Add($cb)
    $videoExtCheckboxes += $cb
}

$controls.ImageAllBtn.Add_Click({ foreach ($cb in $imageExtCheckboxes) { $cb.IsChecked = $true } })
$controls.ImageNoneBtn.Add_Click({ foreach ($cb in $imageExtCheckboxes) { $cb.IsChecked = $false } })
$controls.VideoAllBtn.Add_Click({ foreach ($cb in $videoExtCheckboxes) { $cb.IsChecked = $true } })
$controls.VideoNoneBtn.Add_Click({ foreach ($cb in $videoExtCheckboxes) { $cb.IsChecked = $false } })

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
}

# --- Helpers ----------------------------------------------------------------

function Format-Duration {
    param([TimeSpan]$ts)
    if ($ts.TotalSeconds -lt 1)  { return "<1s" }
    if ($ts.TotalSeconds -lt 60) { return ("{0}s" -f [int]$ts.TotalSeconds) }
    if ($ts.TotalMinutes -lt 60) { return ("{0}m {1:D2}s" -f [int]$ts.TotalMinutes, $ts.Seconds) }
    return ("{0}h {1:D2}m" -f [int]$ts.TotalHours, $ts.Minutes)
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

function Set-Idle {
    $controls.RunButton.IsEnabled    = $true
    $controls.CancelButton.IsEnabled = $false
    $controls.FolderTextBox.IsEnabled = $true
    $controls.BrowseButton.IsEnabled  = $true
    foreach ($n in 'EnableCleanup','CleanupDryRun','CleanupPermanent','CleanupAggressive','CleanupMinSize',
                   'EnableMove','MoveDryRun',
                   'EnableSort','SortDryRun','SortFileDateOnly',
                   'ImageAllBtn','ImageNoneBtn','VideoAllBtn','VideoNoneBtn') {
        $controls[$n].IsEnabled = $true
    }
    foreach ($cb in $imageExtCheckboxes + $videoExtCheckboxes) { $cb.IsEnabled = $true }
}

function Set-Busy {
    $controls.RunButton.IsEnabled    = $false
    $controls.CancelButton.IsEnabled = $true
    $controls.FolderTextBox.IsEnabled = $false
    $controls.BrowseButton.IsEnabled  = $false
    foreach ($n in 'EnableCleanup','CleanupDryRun','CleanupPermanent','CleanupAggressive','CleanupMinSize',
                   'EnableMove','MoveDryRun',
                   'EnableSort','SortDryRun','SortFileDateOnly',
                   'ImageAllBtn','ImageNoneBtn','VideoAllBtn','VideoNoneBtn') {
        $controls[$n].IsEnabled = $false
    }
    foreach ($cb in $imageExtCheckboxes + $videoExtCheckboxes) { $cb.IsEnabled = $false }
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

function Get-CheckedExtensions {
    param($Checkboxes)
    return @($Checkboxes | Where-Object { $_.IsChecked } | ForEach-Object { $_.Tag })
}

function Build-OperationList {
    $ops = @()

    # 1. Cleanup first
    if ($controls.EnableCleanup.IsChecked) {
        $sz = 10
        [int]::TryParse($controls.CleanupMinSize.Text, [ref]$sz) | Out-Null
        $ops += [pscustomobject]@{
            Name           = 'cleanup'
            DryRun         = [bool]$controls.CleanupDryRun.IsChecked
            Permanent      = [bool]$controls.CleanupPermanent.IsChecked
            AggressiveSize = [bool]$controls.CleanupAggressive.IsChecked
            MinSizeKB      = $sz
        }
    }

    # 2. Consolidate
    if ($controls.EnableMove.IsChecked) {
        $imgs = Get-CheckedExtensions $imageExtCheckboxes
        $vids = Get-CheckedExtensions $videoExtCheckboxes
        $ops += [pscustomobject]@{
            Name             = 'move'
            DryRun           = [bool]$controls.MoveDryRun.IsChecked
            ImageExtensions  = $imgs
            VideoExtensions  = $vids
        }
    }

    # 3. Sort
    if ($controls.EnableSort.IsChecked) {
        $opts = @{
            DryRun          = [bool]$controls.SortDryRun.IsChecked
            UseFileDateOnly = [bool]$controls.SortFileDateOnly.IsChecked
        }
        $ops += [pscustomobject]@{ Name='sort'; Target='images'; Options=$opts }
        $ops += [pscustomobject]@{ Name='sort'; Target='videos'; Options=$opts }
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
    $script:state.LogWriter = New-Object System.IO.StreamWriter $script:state.LogPath, $false, ([System.Text.Encoding]::UTF8)
    $script:state.LogWriter.AutoFlush = $true

    $w = $script:state.LogWriter
    $w.WriteLine("============================================================")
    $w.WriteLine("  Media Tools -- Run Log")
    $w.WriteLine("============================================================")
    $w.WriteLine("  Started:    $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $w.WriteLine("  Folder:     $Root")
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
                $bits += "$($op.ImageExtensions.Count) image types"
                $bits += "$($op.VideoExtensions.Count) video types"
                $w.WriteLine("    - Consolidate media        [$($bits -join ', ')]")
                $w.WriteLine("        Images: $($op.ImageExtensions -join ' ')")
                $w.WriteLine("        Videos: $($op.VideoExtensions -join ' ')")
            }
            'sort' {
                $bits = @("target=$($op.Target)\")
                if ($op.Options.DryRun)          { $bits += 'DryRun' }
                if ($op.Options.UseFileDateOnly) { $bits += 'UseFileDateOnly' }
                $w.WriteLine("    - Sort by year             [$($bits -join ', ')]")
            }
        }
    }
    $w.WriteLine("============================================================")
    $w.WriteLine("")

    # Display in UI
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
                $w.WriteLine("  Consolidate:")
                $w.WriteLine(("    Images moved : {0}" -f $s.ImageCount))
                $w.WriteLine(("    Videos moved : {0}" -f $s.VideoCount))
                if ($s.Failed -gt 0) { $w.WriteLine(("    Failures     : {0}" -f $s.Failed)) }
                if ($s.DryRun)       { $w.WriteLine("    (Dry run -- nothing actually moved.)") }
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
                $msg += "Consolidate: $($s.ImageCount) images, $($s.VideoCount) videos moved"
                if ($s.Failed -gt 0) { $msg += "  ($($s.Failed) failed)" }
                if ($s.DryRun)       { $msg += "  (dry run)" }
                $msg += "`n"
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
    [System.Windows.MessageBox]::Show($msg, "Media Tools", 'OK', 'Information') | Out-Null
}

# --- Start the worker -------------------------------------------------------

function Start-Work {
    $root = $controls.FolderTextBox.Text
    if (-not (Test-Path -LiteralPath $root)) {
        [System.Windows.MessageBox]::Show("Folder not found:`n$root", "Media Tools", 'OK', 'Error') | Out-Null
        return
    }

    $ops = Build-OperationList
    if ($ops.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Please enable at least one operation.", "Media Tools", 'OK', 'Information') | Out-Null
        return
    }

    # Check that consolidate has at least one extension if enabled
    $moveOp = $ops | Where-Object { $_.Name -eq 'move' } | Select-Object -First 1
    if ($moveOp -and (($moveOp.ImageExtensions.Count + $moveOp.VideoExtensions.Count) -eq 0)) {
        [System.Windows.MessageBox]::Show("You enabled 'Consolidate media files' but didn't select any file types.",
            "Media Tools", 'OK', 'Warning') | Out-Null
        return
    }

    # Warn before permanent cleanup that isn't a dry run
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
    $script:state.LastTotal  = 0

    $controls.ProgressBar.Value = 0
    $controls.StatusText.Text   = "Starting..."
    $controls.StatsText.Text    = ""
    $controls.CurrentFileText.Text = " "
    $controls.LogBox.Clear()

    # Open log file
    try {
        Open-LogFile -Root $root -Operations $ops
    } catch {
        [System.Windows.MessageBox]::Show("Could not create log file: $($_.Exception.Message)`n`nRun will continue without logging.",
            "Media Tools", 'OK', 'Warning') | Out-Null
    }

    Append-Log "Starting run."

    Set-Busy

    # Spin up a runspace
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
                                              -ImageExtensions $op.ImageExtensions `
                                              -VideoExtensions $op.VideoExtensions `
                                              -OnProgress $cb -CancelToken $cancelToken
                        $queue.Enqueue(@{ Type='op-done'; Op=$op; Result=$r })
                    }
                    'sort' {
                        $target = Join-Path $root $op.Target
                        if (Test-Path -LiteralPath $target) {
                            $o = $op.Options
                            $r = Invoke-SortMediaByYear -Root $target -DryRun:$o.DryRun `
                                    -UseFileDateOnly:$o.UseFileDateOnly `
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

    $maxPerTick = 500  # cap event processing per tick so UI stays responsive
    $processed = 0
    $evt = $null
    while ($processed -lt $maxPerTick -and $script:state.Queue.TryDequeue([ref]$evt)) {
        $processed++
        switch ($evt.Type) {
            'phase' {
                $phaseName = switch ($evt.Phase) {
                    'cleanup' { 'Cleaning up junk' }
                    'move'    { 'Consolidating media files' }
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
            'op-done' {
                $script:state.Summaries += @{ Op=$evt.Op; Result=$evt.Result }
            }
            'phase-done' {
                # The per-op summary already arrived via op-done.
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
        Close-LogFile -ClosingNote "`r`n[Window closed mid-run]"
    } else {
        Close-LogFile
    }
    $timer.Stop()
})

# --- Show it ----------------------------------------------------------------

[void]$window.ShowDialog()

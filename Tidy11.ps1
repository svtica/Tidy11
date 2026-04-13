<#
.SYNOPSIS
    Tidy11.ps1 — one-click WPF tool to disable Copilot/AI, telemetry, ads,
    and bloat on Windows 11 and Microsoft 365. Restores privacy and performance.

.DESCRIPTION
    Consolidates three upstream sources into one offline tool:
      1) zoicware/RemoveWindowsAI  (natively ported, AI/Copilot features)
      2) sevsec/windows-11-privacy (natively ported, 5 privacy modules)
      3) bRootForceSec/Win11-Debloat-And-Privacy (natively ported, cleanup + perf)
      +  Office/Notepad Copilot master toggles not covered by the above

    No network dependency at runtime. Fully offline.
    Must run as Administrator in Windows PowerShell 5.1.
    Load the module file (Tidy11.Modules.psm1) from the same folder.

.NOTES
    Author:  svtica
    License: GPL-3.0-or-later
    Project: https://github.com/svtica/Tidy11
#>

#Requires -Version 5.1

# -------------------- elevation --------------------
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
          ).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList @(
        '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`""
    )
    exit
}

# -------------------- PS 5.1 check --------------------
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        "This tool must run in Windows PowerShell 5.1 (powershell.exe), not pwsh $($PSVersionTable.PSVersion).",
        'Wrong PowerShell','OK','Error') | Out-Null
    exit 1
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# -------------------- load modules --------------------
$modulePath = Join-Path $PSScriptRoot 'Tidy11.Modules.psm1'
if (-not (Test-Path $modulePath)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Cannot find Tidy11.Modules.psm1 next to this script.`n`nExpected at: $modulePath",
        'Missing module','OK','Error') | Out-Null
    exit 1
}
Import-Module $modulePath -Force -DisableNameChecking

# =========================================================================
#  WPF UI
# =========================================================================
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Tidy11 — Cleanup, Privacy, Copilot Removal"
        Height="900" Width="900"
        WindowStartupLocation="CenterScreen"
        Background="#1a1a1a">
    <Window.Resources>
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#e0e0e0"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Margin" Value="8,3"/>
        </Style>
        <Style TargetType="GroupBox">
            <Setter Property="Foreground" Value="#4fc3f7"/>
            <Setter Property="BorderBrush" Value="#333"/>
            <Setter Property="Margin" Value="6"/>
            <Setter Property="Padding" Value="4"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
        </Style>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#2d2d2d"/>
            <Setter Property="Foreground" Value="#e0e0e0"/>
            <Setter Property="BorderBrush" Value="#4fc3f7"/>
            <Setter Property="Padding" Value="10,5"/>
            <Setter Property="Margin" Value="4"/>
            <Setter Property="FontSize" Value="12"/>
        </Style>
        <Style TargetType="TextBlock">
            <Setter Property="Foreground" Value="#e0e0e0"/>
        </Style>
    </Window.Resources>
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="180"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <StackPanel Grid.Row="0" Grid.ColumnSpan="2" Orientation="Horizontal" Margin="4,0,0,8">
            <TextBlock Text="Tidy11" FontSize="22" FontWeight="Bold" Foreground="#4fc3f7"/>
            <TextBlock Text="  —  Cleanup | Privacy | Copilot Removal" FontSize="14" Foreground="#888" VerticalAlignment="Center" Margin="4,0,0,0"/>
        </StackPanel>

        <ScrollViewer Grid.Row="1" Grid.Column="0" VerticalScrollBarVisibility="Auto">
            <StackPanel>
                <GroupBox Header="Copilot / AI — Windows OS">
                    <StackPanel>
                        <CheckBox Name="cbWinCopilot"       Content="Windows Copilot (taskbar, Win+C, hardware key)" IsChecked="True"/>
                        <CheckBox Name="cbRecall"           Content="Recall + snapshots" IsChecked="True"/>
                        <CheckBox Name="cbClickToDo"        Content="Click To Do" IsChecked="True"/>
                        <CheckBox Name="cbSearchAI"         Content="AI suggestions in Windows Search" IsChecked="True"/>
                        <CheckBox Name="cbExplorer"         Content="Ask Copilot in File Explorer menu" IsChecked="True"/>
                        <CheckBox Name="cbVoice"            Content="Voice Access + AI voice effects" IsChecked="True"/>
                        <CheckBox Name="cbAppx"             Content="Remove Copilot/Recall Appx packages" IsChecked="False"/>
                        <CheckBox Name="cbPreventReinstall" Content="Block WU from reinstalling AI features" IsChecked="True"/>
                    </StackPanel>
                </GroupBox>

                <GroupBox Header="Copilot / AI — Apps">
                    <StackPanel>
                        <CheckBox Name="cbPaint"   Content="Paint AI (Cocreator, Generative Fill/Erase)" IsChecked="True"/>
                        <CheckBox Name="cbPhotos"  Content="Photos AI + image categorization" IsChecked="True"/>
                        <CheckBox Name="cbEdge"    Content="Edge Copilot sidebar/Compose/themes" IsChecked="True"/>
                        <CheckBox Name="cbOffice"  Content="Word/Excel/PPT/OneNote Copilot (wrapper)" IsChecked="True"/>
                        <CheckBox Name="cbOutlook" Content="Outlook Copilot add-in (wrapper)" IsChecked="True"/>
                        <CheckBox Name="cbNotepad" Content="Notepad AI / Copilot (wrapper)" IsChecked="True"/>
                    </StackPanel>
                </GroupBox>

                <GroupBox Header="Win11 Privacy (via sevsec)">
                    <StackPanel>
                        <CheckBox Name="cbTelemetry"    Content="Telemetry (DiagTrack, tasks, firewall blocks)" IsChecked="True"/>
                        <CheckBox Name="cbAds"          Content="Ads / Recommendations / Spotlight" IsChecked="True"/>
                        <CheckBox Name="cbMSA"          Content="Block Microsoft Account nudges (optional — off for enterprise MSA use)" IsChecked="False"/>
                        <CheckBox Name="cbMSAStrict"    Content="    └ Strict MSA block (value=3 — may break Store/Teams/OneDrive personal sign-in)" IsChecked="False" Margin="24,3,8,3"/>
                        <CheckBox Name="cbActLoc"      Content="Activity History + global Location" IsChecked="True"/>
                    </StackPanel>
                </GroupBox>

                <GroupBox Header="Classic App Replacements">
                    <StackPanel>
                        <TextBlock Text="Method:" FontWeight="Bold" Margin="8,4,8,2"/>
                        <RadioButton Name="rbMethodSkip"     GroupName="classicMethod" Content="Skip (don't install anything)" IsChecked="True" Foreground="#e0e0e0" Margin="16,2,8,2"/>
                        <RadioButton Name="rbMethodWinget"   GroupName="classicMethod" Content="Winget alternatives — Notepad++ / Paint.NET / ShareX / IrfanView" Foreground="#e0e0e0" Margin="16,2,8,2"/>
                        <RadioButton Name="rbMethodNative"   GroupName="classicMethod" Content="Native (Microsoft sources only — Notepad, Photo Viewer, Photos Legacy)" Foreground="#e0e0e0" Margin="16,2,8,2"/>
                        <RadioButton Name="rbMethodRedistOn"   GroupName="classicMethod" Content="Source Redist Online (opt-in — includes classic MS Paint + Snipping Tool)" Foreground="#e0e0e0" Margin="16,2,8,2"/>
                        <RadioButton Name="rbMethodRedistLoc"  GroupName="classicMethod" Content="Source Redist Local (use ./ClassicApps/ folder next to this script)" Foreground="#e0e0e0" Margin="16,2,8,2"/>

                        <TextBlock Text="Apps to install:" FontWeight="Bold" Margin="8,8,8,2"/>
                        <CheckBox Name="cbAppNotepad"     Content="Classic Notepad"/>
                        <CheckBox Name="cbAppPaint"       Content="Classic MS Paint"/>
                        <CheckBox Name="cbAppSnip"        Content="Classic Snipping Tool"/>
                        <CheckBox Name="cbAppPhoto"       Content="Classic Windows Photo Viewer"/>
                        <CheckBox Name="cbAppPhotosLeg"   Content="Photos Legacy (from Microsoft Store)"/>

                        <TextBlock TextWrapping="Wrap" Margin="8,6,8,2" FontSize="10" Foreground="#888"
                                   Text="Winget = best legal posture, modern replacements. Native = Microsoft's own sources; Paint/Snipping not available this way. Source Redist options install true Win10 binaries but redistribute Microsoft copyrights — use at your discretion."/>
                    </StackPanel>
                </GroupBox>
            </StackPanel>
        </ScrollViewer>

        <ScrollViewer Grid.Row="1" Grid.Column="1" VerticalScrollBarVisibility="Auto">
            <StackPanel>
                <GroupBox Header="System Cleanup (via bRootForceSec)">
                    <StackPanel>
                        <CheckBox Name="cbXbox"           Content="Xbox services (XblAuth/GameSave/Net/GipSvc)" IsChecked="False"/>
                        <CheckBox Name="cbGameDVR"        Content="Game DVR + Game Mode" IsChecked="False"/>
                        <CheckBox Name="cbWidgets"        Content="Widgets (News and Interests)" IsChecked="True"/>
                        <CheckBox Name="cbContextMenu"    Content="Restore classic Win10 context menu" IsChecked="True"/>
                        <CheckBox Name="cbWebSearch"      Content="Bing / Cortana / web search in Start" IsChecked="True"/>
                        <CheckBox Name="cbTaskbar"        Content="Taskbar cleanup (left align, hide Task View/Chat/People)" IsChecked="True"/>
                        <CheckBox Name="cbPerf"           Content="Performance tweaks (menu/startup delay)" IsChecked="True"/>
                        <CheckBox Name="cbEdgeDebloat"    Content="Edge first-run/startup boost/background" IsChecked="True"/>
                        <CheckBox Name="cbOfficeTelem"    Content="Office telemetry / connected experiences" IsChecked="True"/>
                    </StackPanel>
                </GroupBox>

                <GroupBox Header="Config Recipe + Snapshot">
                    <StackPanel>
                        <CheckBox Name="cbSystemRestore" Content="Create Windows System Restore point (extra safety net)" IsChecked="True"/>
                        <CheckBox Name="cbAutoSnapshot" Content="Create Tidy11 snapshot BEFORE applying changes" IsChecked="True"/>
                        <TextBlock TextWrapping="Wrap" Margin="8,2,8,6" FontSize="10" Foreground="#888"
                                   Text="Belt and suspenders: the System Restore point covers driver/boot state that Tidy11 snapshots don't. If System Restore is disabled, Tidy11 will enable it automatically. Tidy11 snapshots go to %USERPROFILE%\Documents\Tidy11-Snapshots\."/>
                        <Button Name="btnSaveConfig"   Content="Save Config Recipe..."    HorizontalAlignment="Stretch"/>
                        <Button Name="btnLoadConfig"   Content="Load Config Recipe..."    HorizontalAlignment="Stretch"/>
                        <Button Name="btnRestoreSnap"  Content="Restore from Snapshot..." HorizontalAlignment="Stretch"/>
                    </StackPanel>
                </GroupBox>

                <GroupBox Header="Presets">
                    <StackPanel>
                        <Button Name="btnPresetSafe"      Content="SAFE     — AI / telemetry / ads (recommended)"     HorizontalAlignment="Stretch"/>
                        <Button Name="btnPresetExtended"  Content="EXTENDED — SAFE + Xbox + Game DVR"                  HorizontalAlignment="Stretch"/>
                        <Button Name="btnPresetFull"      Content="FULL     — everything including Appx removal"      HorizontalAlignment="Stretch" Background="#4a0000"/>
                    </StackPanel>
                </GroupBox>

                <GroupBox Header="About">
                    <StackPanel>
                        <TextBlock TextWrapping="Wrap" FontSize="11" Foreground="#888" Margin="6">
                            <Run Text="Built on: "/>
                            <Run Text="zoicware/RemoveWindowsAI" FontWeight="Bold"/>
                            <Run Text=" + "/>
                            <Run Text="sevsec/windows-11-privacy" FontWeight="Bold"/>
                            <Run Text=" + "/>
                            <Run Text="bRootForceSec/Win11-Debloat-And-Privacy" FontWeight="Bold"/>
                            <Run Text=". All natively ported — no network needed. Reboot after running."/>
                        </TextBlock>
                    </StackPanel>
                </GroupBox>
            </StackPanel>
        </ScrollViewer>

        <StackPanel Grid.Row="2" Grid.ColumnSpan="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,8,0,6">
            <Button Name="btnSelectAll" Content="Select All"/>
            <Button Name="btnClear"     Content="Clear All"/>
            <Button Name="btnVerify"    Content="Verify (read-only)"/>
            <Button Name="btnDisable"   Content="DISABLE Selected"  Background="#b71c1c" FontWeight="Bold"/>
            <Button Name="btnRevert"    Content="REVERT Selected"   Background="#1b5e20"/>
            <Button Name="btnExit"      Content="Exit"/>
        </StackPanel>

        <GroupBox Grid.Row="3" Grid.ColumnSpan="2" Header="Log">
            <TextBox Name="txtLog" Background="#0a0a0a" Foreground="#00ff66"
                     FontFamily="Consolas" FontSize="11"
                     IsReadOnly="True" VerticalScrollBarVisibility="Auto"
                     TextWrapping="Wrap" AcceptsReturn="True"/>
        </GroupBox>

        <TextBlock Grid.Row="4" Grid.ColumnSpan="2" Margin="6,6,0,0" FontSize="11" Foreground="#666"
                   Text="Tidy11 — combines zoicware + sevsec + bRootForceSec. Reboot recommended after run."/>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# Bind controls
$cb = @{}
@(
    # AI / Copilot
    'cbWinCopilot','cbRecall','cbClickToDo','cbSearchAI','cbExplorer','cbVoice','cbAppx','cbPreventReinstall',
    'cbPaint','cbPhotos','cbEdge','cbOffice','cbOutlook','cbNotepad',
    # Sevsec
    'cbTelemetry','cbAds','cbMSA','cbMSAStrict','cbActLoc',
    # System cleanup
    'cbXbox','cbGameDVR','cbWidgets','cbContextMenu','cbWebSearch',
    'cbTaskbar','cbPerf','cbEdgeDebloat','cbOfficeTelem',
    # Classic apps — method radios + app checkboxes
    'rbMethodSkip','rbMethodWinget','rbMethodNative','rbMethodRedistOn','rbMethodRedistLoc',
    'cbAppNotepad','cbAppPaint','cbAppSnip','cbAppPhoto','cbAppPhotosLeg',
    # Config / Snapshot
    'cbSystemRestore','cbAutoSnapshot','btnSaveConfig','btnLoadConfig','btnRestoreSnap',
    # Buttons + log
    'txtLog','btnSelectAll','btnClear','btnVerify','btnDisable','btnRevert','btnExit',
    'btnPresetSafe','btnPresetExtended','btnPresetFull'
) | ForEach-Object { $cb[$_] = $window.FindName($_) }

# Wire log callback from module to GUI textbox
Register-LogCallback {
    param($line)
    $cb.txtLog.Dispatcher.Invoke([action]{
        $cb.txtLog.AppendText("$line`r`n")
        $cb.txtLog.ScrollToEnd()
    })
}

# --- checkbox enumeration ---
$allCheckboxes = $cb.Keys | Where-Object { $cb[$_] -is [System.Windows.Controls.CheckBox] }

function Set-AllCheckboxes {
    param([bool]$State)
    foreach ($k in $allCheckboxes) { $cb[$k].IsChecked = $State }
}

# --- presets ---
$cb.btnSelectAll.Add_Click({ Set-AllCheckboxes $true })
$cb.btnClear.Add_Click({ Set-AllCheckboxes $false })
$cb.btnExit.Add_Click({ $window.Close() })

$cb.btnPresetSafe.Add_Click({
    Set-AllCheckboxes $false
    foreach ($k in 'cbWinCopilot','cbRecall','cbClickToDo','cbSearchAI','cbExplorer','cbVoice','cbAppx','cbPreventReinstall',
                   'cbPaint','cbPhotos','cbEdge','cbOffice','cbOutlook','cbNotepad',
                   'cbTelemetry','cbAds','cbActLoc',
                   'cbWidgets','cbContextMenu','cbWebSearch','cbTaskbar','cbPerf','cbEdgeDebloat','cbOfficeTelem'
                  ) { $cb[$k].IsChecked = $true }
    Write-Log 'Preset: SAFE selected'
})
$cb.btnPresetExtended.Add_Click({
    Set-AllCheckboxes $false
    foreach ($k in 'cbWinCopilot','cbRecall','cbClickToDo','cbSearchAI','cbExplorer','cbVoice','cbAppx','cbPreventReinstall',
                   'cbPaint','cbPhotos','cbEdge','cbOffice','cbOutlook','cbNotepad',
                   'cbTelemetry','cbAds','cbActLoc',
                   'cbXbox','cbGameDVR','cbWidgets','cbContextMenu','cbWebSearch',
                   'cbTaskbar','cbPerf','cbEdgeDebloat','cbOfficeTelem'
                  ) { $cb[$k].IsChecked = $true }
    Write-Log 'Preset: EXTENDED selected'
})
$cb.btnPresetFull.Add_Click({
    Set-AllCheckboxes $true
    # MSA block stays opt-in even in the FULL preset: enterprise tenants may
    # require Microsoft Accounts for Store/Teams/Intune sign-in. Tick manually.
    $cb.cbMSA.IsChecked       = $false
    $cb.cbMSAStrict.IsChecked = $false
    Write-Log 'Preset: FULL selected (everything except MSA block — tick manually if needed)'
})

# --- config recipe save/load helpers ---
function Get-CurrentSelections {
    $sel = @{}
    foreach ($k in $cb.Keys) {
        $ctrl = $cb[$k]
        if ($ctrl -is [System.Windows.Controls.CheckBox] -or
            $ctrl -is [System.Windows.Controls.RadioButton]) {
            $sel[$k] = [bool]$ctrl.IsChecked
        }
    }
    return $sel
}

function Set-SelectionsFromConfig {
    param($Config)
    if (-not $Config -or -not $Config.selections) {
        Write-Log 'Config has no selections — nothing to apply.' 'WARN'
        return
    }
    $applied = 0
    $skipped = 0
    foreach ($p in ($Config.selections | Get-Member -MemberType NoteProperty)) {
        $name = $p.Name
        $val  = $Config.selections.$name
        if ($cb.ContainsKey($name)) {
            $ctrl = $cb[$name]
            if ($ctrl -is [System.Windows.Controls.CheckBox] -or
                $ctrl -is [System.Windows.Controls.RadioButton]) {
                $ctrl.IsChecked = [bool]$val
                $applied++
            }
        } else {
            $skipped++
        }
    }
    Write-Log "Config applied: $applied controls set, $skipped unknown keys skipped"
}

# --- Save Config ---
$cb.btnSaveConfig.Add_Click({
    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Filter = 'Tidy11 recipe (*.json)|*.json|All files (*.*)|*.*'
    $dlg.FileName = 'tidy11-recipe.json'
    $dlg.InitialDirectory = [Environment]::GetFolderPath('MyDocuments')
    if ($dlg.ShowDialog() -eq 'OK') {
        $descInput = [Microsoft.VisualBasic.Interaction]::InputBox(
            'Optional description for this recipe:', 'Save Config Recipe', '') 2>$null
        Export-Tidy11Config -Path $dlg.FileName -Selections (Get-CurrentSelections) -Description $descInput
    }
})

# --- Load Config ---
$cb.btnLoadConfig.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = 'Tidy11 recipe (*.json)|*.json|All files (*.*)|*.*'
    $dlg.InitialDirectory = [Environment]::GetFolderPath('MyDocuments')
    if ($dlg.ShowDialog() -eq 'OK') {
        $config = Import-Tidy11Config -Path $dlg.FileName
        if ($config) { Set-SelectionsFromConfig -Config $config }
    }
})

# --- Restore from Snapshot ---
$cb.btnRestoreSnap.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Select a Tidy11 snapshot folder (contains manifest.json)'
    $dlg.SelectedPath = Join-Path $env:USERPROFILE 'Documents\Tidy11-Snapshots'
    if ($dlg.ShowDialog() -eq 'OK') {
        $confirm = [System.Windows.MessageBox]::Show(
            "Restore from:`n$($dlg.SelectedPath)`n`nThis imports the saved registry exports, re-enables snapshotted services and tasks, and removes PrivacyBlock-* firewall rules. Reboot recommended afterwards.`n`nProceed?",
            'Confirm restore', 'YesNo', 'Warning')
        if ($confirm -eq 'Yes') {
            Restore-Tidy11Snapshot -SnapshotPath $dlg.SelectedPath
        }
    }
})

# --- main run loop ---
$runAction = {
    param([bool]$isRevert)
    $cb.btnDisable.IsEnabled = $false
    $cb.btnRevert.IsEnabled  = $false
    $cb.btnVerify.IsEnabled  = $false
    try {
        Write-Log ('=' * 70)
        $phase = if ($isRevert) { 'REVERT pass' } else { 'DISABLE pass' }
        Write-Log "$phase starting"
        Write-Log ('=' * 70)

        # --- auto-snapshot before making changes (disable pass only) ---
        if (-not $isRevert) {
            # Windows System Restore point first (independent safety net)
            if ($cb.cbSystemRestore.IsChecked) {
                Write-Log '--- Creating Windows System Restore point ---'
                $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
                New-Tidy11SystemRestorePoint -Description "Tidy11 pre-change $stamp" | Out-Null
            }

            if ($cb.cbAutoSnapshot.IsChecked) {
                Write-Log '--- Taking pre-change Tidy11 snapshot ---'
                $snapPath = New-Tidy11Snapshot
                if ($snapPath) {
                    Write-Log "Rollback anytime via: Restore from Snapshot -> $snapPath"
                }
            }
        }

        # --- native AI/Copilot disable (replaces upstream live fetch) ---
        $anyAI = ($cb.cbWinCopilot.IsChecked -or $cb.cbRecall.IsChecked -or $cb.cbClickToDo.IsChecked -or
                  $cb.cbSearchAI.IsChecked   -or $cb.cbExplorer.IsChecked -or $cb.cbPaint.IsChecked  -or
                  $cb.cbEdge.IsChecked       -or $cb.cbVoice.IsChecked    -or $cb.cbPhotos.IsChecked -or
                  $cb.cbPreventReinstall.IsChecked)
        if ($anyAI) {
            Invoke-CopilotNative -Revert $isRevert
        }
        if ($cb.cbAppx.IsChecked) {
            Invoke-AIAppxRemoval -Revert $isRevert
        }

        # --- sevsec privacy modules ---
        if ($cb.cbTelemetry.IsChecked) { Invoke-Telemetry        -Revert $isRevert }
        if ($cb.cbAds.IsChecked)       { Invoke-AdsRecommendations -Revert $isRevert }
        if ($cb.cbMSA.IsChecked)       { Invoke-MicrosoftAccount -Revert $isRevert -Strict ([bool]$cb.cbMSAStrict.IsChecked) }
        if ($cb.cbActLoc.IsChecked)    { Invoke-ActivityLocation -Revert $isRevert }

        # --- bRootForceSec cleanup modules ---
        if ($cb.cbXbox.IsChecked)          { Invoke-XboxServices      -Revert $isRevert }
        if ($cb.cbGameDVR.IsChecked)       { Invoke-GameDVR           -Revert $isRevert }
        if ($cb.cbWidgets.IsChecked)       { Invoke-Widgets           -Revert $isRevert }
        if ($cb.cbContextMenu.IsChecked)   { Invoke-ClassicContextMenu -Revert $isRevert }
        if ($cb.cbWebSearch.IsChecked)     { Invoke-WebSearch         -Revert $isRevert }
        if ($cb.cbTaskbar.IsChecked)       { Invoke-TaskbarTweaks     -Revert $isRevert }
        if ($cb.cbPerf.IsChecked)          { Invoke-PerformanceTweaks -Revert $isRevert }
        if ($cb.cbEdgeDebloat.IsChecked)   { Invoke-EdgeDebloat       -Revert $isRevert }
        if ($cb.cbOfficeTelem.IsChecked)   { Invoke-OfficeTelemetry   -Revert $isRevert }

        # --- wrapper extras ---
        if ($cb.cbOffice.IsChecked -or $cb.cbOutlook.IsChecked) {
            Invoke-OfficeCopilot -Revert $isRevert
        }
        if ($cb.cbNotepad.IsChecked) {
            Invoke-NotepadAI -Revert $isRevert
        }
        if (-not $isRevert -and ($cb.cbOffice.IsChecked -or $cb.cbOutlook.IsChecked)) {
            Show-TeamsReminder
        }

        # --- classic app replacements (install-only; revert is manual uninstall) ---
        if (-not $isRevert) {
            $method = 'Skip'
            if ($cb.rbMethodWinget.IsChecked)  { $method = 'Winget' }
            elseif ($cb.rbMethodNative.IsChecked) { $method = 'Native' }
            elseif ($cb.rbMethodRedistOn.IsChecked) { $method = 'SourceRedistOnline' }
            elseif ($cb.rbMethodRedistLoc.IsChecked) { $method = 'SourceRedistLocal' }

            $apps = @()
            if ($cb.cbAppNotepad.IsChecked)   { $apps += 'notepad' }
            if ($cb.cbAppPaint.IsChecked)     { $apps += 'mspaint' }
            if ($cb.cbAppSnip.IsChecked)      { $apps += 'snippingtool' }
            if ($cb.cbAppPhoto.IsChecked)     { $apps += 'photoviewer' }
            if ($cb.cbAppPhotosLeg.IsChecked) { $apps += 'photoslegacy' }

            if ($method -ne 'Skip' -and $apps.Count -gt 0) {
                Invoke-ClassicApps -Method $method -Apps $apps -LocalPath $PSScriptRoot
            }
        }

        Write-Log ''
        Write-Log 'Done. Reboot recommended for all changes to settle.'

        # Persist net-new-value list so a restore can cleanly remove them
        if (-not $isRevert) {
            try { Save-CreatedValuesLog } catch { Write-Log "Save-CreatedValuesLog: $($_.Exception.Message)" 'WARN' }
        }
    } catch {
        Write-Log "FATAL: $($_.Exception.Message)" 'FAIL'
    } finally {
        $cb.btnDisable.IsEnabled = $true
        $cb.btnRevert.IsEnabled  = $true
        $cb.btnVerify.IsEnabled  = $true
    }
}

$cb.btnDisable.Add_Click({
    # Second confirmation specifically for Appx removal, which is IRREVERSIBLE
    if ($cb.cbAppx.IsChecked) {
        $warn = [System.Windows.MessageBox]::Show(
            "You have ticked 'Remove Copilot/Recall Appx packages'.`n`n" +
            "This action is IRREVERSIBLE by the snapshot system. Once removed, the packages cannot be restored by Tidy11-Restore.ps1 — you would need to reinstall them from the Microsoft Store (and some provisioned packages may not be available).`n`n" +
            "Continue with Appx removal included?",
            'Appx removal — irreversible', 'YesNo', 'Warning')
        if ($warn -ne 'Yes') {
            $cb.cbAppx.IsChecked = $false
            [System.Windows.MessageBox]::Show('Appx removal has been unticked. Click DISABLE again to continue with the remaining categories.', 'Cancelled', 'OK', 'Information') | Out-Null
            return
        }
    }
    $r = [System.Windows.MessageBox]::Show(
        "This will disable/remove the selected categories across Windows 11 and Microsoft 365.`n`nProceed?",
        "Confirm DISABLE", 'YesNo', 'Warning')
    if ($r -eq 'Yes') { & $runAction $false }
})
$cb.btnRevert.Add_Click({
    $r = [System.Windows.MessageBox]::Show(
        "Revert the selected categories back to Microsoft defaults?",
        "Confirm REVERT", 'YesNo', 'Question')
    if ($r -eq 'Yes') { & $runAction $true }
})
$cb.btnVerify.Add_Click({
    $cb.btnVerify.IsEnabled = $false
    try { Invoke-Verification }
    finally { $cb.btnVerify.IsEnabled = $true }
})

Write-Log 'Tidy11 ready.'
Write-Log 'Sources: zoicware/RemoveWindowsAI + sevsec/windows-11-privacy + bRootForceSec/Win11-Debloat-And-Privacy'
Write-Log 'Pick a preset or individual checkboxes, then DISABLE Selected.'
$window.ShowDialog() | Out-Null

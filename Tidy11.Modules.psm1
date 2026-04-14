<#
.SYNOPSIS
    Tidy11.Modules.psm1 - all disable/enable functions used by the Tidy11 GUI.

.DESCRIPTION
    Sources and credits (no runtime network dependency):
      * sevsec/windows-11-privacy  - GPL-3.0
          https://github.com/sevsec/windows-11-privacy
          Origin of: helper functions (Set-Reg, Remove-RegValue, Disable-Svc,
          Enable-Svc, Disable-TaskPath, Enable-TaskPath, Add-BlockDomain,
          Remove-BlockDomain, Invoke-Safely), the FQDN-block / hosts-fallback
          pattern, the telemetry / ads / MSA / activity-location modules, and
          the snapshot scaffolding shape.
      * zoicware/RemoveWindowsAI  - MIT
          https://github.com/zoicware/RemoveWindowsAI
          Origin of the AI/Copilot/Recall registry research now in
          Invoke-CopilotNative, plus the optional classic-apps install path.
      * bRootForceSec/Win11-Debloat-And-Privacy  - MIT
          https://github.com/bRootForceSec/Win11-Debloat-And-Privacy
          Origin of the cleanup / performance / Edge / Office-telemetry tweaks.

    Tidy11 - Disable Copilot, telemetry, ads, and bloat on Windows 11 and M365
    Copyright (C) 2026 svtica

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

.NOTES
    Author:  svtica
    License: GPL-3.0-or-later
    Project: https://github.com/svtica/Tidy11
#>

#Requires -Version 5.1

$script:LogCallback = $null
function Register-LogCallback { param($cb) $script:LogCallback = $cb }

# --- Persistent log file + net-new value tracking + snapshot path ----------
$script:LogFilePath         = $null
$script:CreatedValues       = [System.Collections.Generic.List[object]]::new()
$script:CurrentSnapshotPath = $null

function Set-LogFile {
    param([string]$Path)
    $script:LogFilePath = $Path
    try {
        $dir = Split-Path $Path -Parent
        if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        "=== Tidy11 log starting $(Get-Date -Format 'o') on $env:COMPUTERNAME by $env:USERNAME ===" |
            Out-File -FilePath $Path -Encoding UTF8 -Append
    } catch {}
}

function Reset-CreatedValues {
    $script:CreatedValues = [System.Collections.Generic.List[object]]::new()
}

function Save-CreatedValuesLog {
    param([string]$SnapshotPath = $script:CurrentSnapshotPath)
    if (-not $SnapshotPath) { return }
    if ($script:CreatedValues.Count -eq 0) {
        Write-Info "No net-new values recorded (nothing to clean up on restore)."
        return
    }
    try {
        $outFile = Join-Path $SnapshotPath 'created-values.json'
        $script:CreatedValues | ConvertTo-Json -Depth 5 | Set-Content -Path $outFile -Encoding UTF8
        Write-OK "Recorded $($script:CreatedValues.Count) net-new values for clean restore: $outFile"
    } catch { Write-Warn "Failed to save created-values log: $($_.Exception.Message)" }
}

function Write-Log {
    param([string]$msg, [string]$level = 'INFO')
    $stamp = (Get-Date).ToString('HH:mm:ss')
    $line  = "[$stamp] [$level] $msg"
    Write-Host $line
    if ($script:LogCallback) { & $script:LogCallback $line }
    if ($script:LogFilePath) {
        try { Add-Content -Path $script:LogFilePath -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue } catch {}
    }
}
function Write-OK   { param($m) Write-Log $m 'OK'   }
function Write-FAIL { param($m) Write-Log $m 'FAIL' }
function Write-Info { param($m) Write-Log $m 'INFO' }
function Write-Warn { param($m) Write-Log $m 'WARN' }

function Invoke-Safely {
    param([Parameter(Mandatory)][ScriptBlock]$Action,[Parameter(Mandatory)][string]$Description)
    try { & $Action; Write-OK $Description; return $true }
    catch { Write-FAIL "$Description :: $($_.Exception.Message)"; return $false }
}

function Set-Reg {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('String','DWord','QWord','ExpandString','MultiString','Binary')][string]$Type,
        [Parameter(Mandatory)]$Value
    )
    # Track whether this value pre-existed so we can cleanly delete net-new values on restore
    $keyExisted   = Test-Path $Path
    $valueExisted = $false
    if ($keyExisted) {
        try {
            $probe = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
            if ($probe -and $null -ne $probe.$Name) { $valueExisted = $true }
        } catch {}
    }
    # IMPORTANT: -ErrorAction Stop makes non-terminating errors (access denied,
    # "operation not allowed", etc.) throw, so Invoke-Safely catches them as FAIL
    # instead of spilling a red stack trace while still logging OK.
    if (-not $keyExisted) { New-Item -Path $Path -Force -ErrorAction Stop | Out-Null }
    try {
        New-ItemProperty -Path $Path -Name $Name -PropertyType $Type -Value $Value -Force -ErrorAction Stop | Out-Null
    } catch {
        # If the existing value has a different type, -Force alone does not
        # always replace it. Delete and recreate in that case.
        if ($valueExisted) {
            Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction Stop
            New-ItemProperty -Path $Path -Name $Name -PropertyType $Type -Value $Value -Force -ErrorAction Stop | Out-Null
        } else {
            throw
        }
    }
    if (-not $valueExisted -and $null -ne $script:CreatedValues) {
        $script:CreatedValues.Add([pscustomobject]@{
            Path       = $Path
            Name       = $Name
            KeyExisted = $keyExisted
        })
    }
}

function Remove-RegValue {
    param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][string]$Name)
    if (Test-Path $Path) {
        if (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $Path -Name $Name -Force
        }
    }
}

function Test-RegValue {
    param([string]$Path,[string]$Name,$Expected)
    try {
        if (!(Test-Path $Path)) { return $false }
        $v = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue |
             Select-Object -ExpandProperty $Name
        if ($null -eq $v) { return $false }
        return ([string]$v -eq [string]$Expected)
    } catch { return $false }
}

# --- User preference stash --------------------------------------------------
# Some values Tidy11 used to overwrite ("taskbar cleanup") are actually
# cosmetic user preferences (e.g. SearchboxTaskbarMode: 0=hidden, 1=icon,
# 2=icon+label, 3=box). Forcing those to a fixed value surfaces a large
# Windows search button for users who had it minimized or hidden. We now
# stash the original value under HKCU\Software\Tidy11\UserPrefs on the
# apply pass and restore it on the revert pass, so the user's preference
# survives both directions.
$script:Tidy11UserPrefsKey = 'HKCU:\Software\Tidy11\UserPrefs'

function ConvertTo-Tidy11StashName {
    param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][string]$Name)
    # Flatten the full reg path into a single value name so every stashed
    # preference lives as one property under the Tidy11 UserPrefs key.
    (($Path -replace '[^A-Za-z0-9]','_') + '__' + $Name)
}

function Save-UserPreference {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name
    )
    $stashName  = ConvertTo-Tidy11StashName -Path $Path -Name $Name
    $absentName = "${stashName}__absent"

    if (-not (Test-Path $script:Tidy11UserPrefsKey)) {
        New-Item -Path $script:Tidy11UserPrefsKey -Force -ErrorAction Stop | Out-Null
    }

    # Never clobber an existing stash - the first capture is the most
    # authoritative snapshot of what the user really had before Tidy11.
    $haveValueStash  = $false
    $haveAbsentStash = $false
    try {
        $probe = Get-ItemProperty -Path $script:Tidy11UserPrefsKey -Name $stashName -ErrorAction SilentlyContinue
        if ($probe -and $null -ne $probe.$stashName) { $haveValueStash = $true }
    } catch {}
    try {
        $probeAbsent = Get-ItemProperty -Path $script:Tidy11UserPrefsKey -Name $absentName -ErrorAction SilentlyContinue
        if ($probeAbsent -and $null -ne $probeAbsent.$absentName) { $haveAbsentStash = $true }
    } catch {}
    if ($haveValueStash -or $haveAbsentStash) { return }

    $current = $null
    try {
        $current = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
    } catch {}

    if ($null -ne $current) {
        New-ItemProperty -Path $script:Tidy11UserPrefsKey -Name $stashName `
            -PropertyType DWord -Value ([int]$current) -Force -ErrorAction Stop | Out-Null
    } else {
        # Mark "value didn't exist" so revert can delete it instead of guessing.
        New-ItemProperty -Path $script:Tidy11UserPrefsKey -Name $absentName `
            -PropertyType DWord -Value 1 -Force -ErrorAction Stop | Out-Null
    }
}

function Restore-UserPreference {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name
    )
    if (-not (Test-Path $script:Tidy11UserPrefsKey)) { return $false }
    $stashName  = ConvertTo-Tidy11StashName -Path $Path -Name $Name
    $absentName = "${stashName}__absent"

    $absent = Get-ItemProperty -Path $script:Tidy11UserPrefsKey -Name $absentName -ErrorAction SilentlyContinue
    if ($absent -and $null -ne $absent.$absentName) {
        if (Test-Path $Path) {
            Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction SilentlyContinue
        }
        Remove-ItemProperty -Path $script:Tidy11UserPrefsKey -Name $absentName -Force -ErrorAction SilentlyContinue
        return $true
    }

    $stashed = Get-ItemProperty -Path $script:Tidy11UserPrefsKey -Name $stashName -ErrorAction SilentlyContinue
    if ($stashed -and $null -ne $stashed.$stashName) {
        Set-Reg $Path $Name 'DWord' ([int]$stashed.$stashName)
        Remove-ItemProperty -Path $script:Tidy11UserPrefsKey -Name $stashName -Force -ErrorAction SilentlyContinue
        return $true
    }
    return $false
}

function Disable-Svc {
    param([string]$Name)
    if (Get-Service -Name $Name -ErrorAction SilentlyContinue) {
        try { Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue } catch {}
        Set-Service -Name $Name -StartupType Disabled
    }
}
function Enable-Svc {
    param([string]$Name,[ValidateSet('Automatic','Manual','Disabled')]$StartupType = 'Automatic')
    if (Get-Service -Name $Name -ErrorAction SilentlyContinue) {
        Set-Service -Name $Name -StartupType $StartupType
        try { Start-Service -Name $Name -ErrorAction SilentlyContinue } catch {}
    }
}

function Disable-TaskPath {
    param([string]$TaskPath)
    $tasks = Get-ScheduledTask -TaskPath $TaskPath -ErrorAction SilentlyContinue
    if ($tasks) { $tasks | ForEach-Object { Disable-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -ErrorAction SilentlyContinue | Out-Null } }
}
function Enable-TaskPath {
    param([string]$TaskPath)
    $tasks = Get-ScheduledTask -TaskPath $TaskPath -ErrorAction SilentlyContinue
    if ($tasks) { $tasks | ForEach-Object { Enable-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -ErrorAction SilentlyContinue | Out-Null } }
}

# --- FQDN firewall / hosts fallback --------------------------------------
$script:FirewallRulePrefix = 'PrivacyBlock-'
$script:SupportsFqdn = ($null -ne (Get-Command New-NetFirewallRule).Parameters['RemoteFqdn'])
$script:HostsPath    = "$env:SystemRoot\System32\drivers\etc\hosts"
$script:HostsMarker  = '# PRIVACY-FQDN-BLOCK'

function Invoke-HostsFileMutation {
    # Read hosts, run $Mutator on its lines, write result back - with retries
    # to handle transient locks held by DnsClient / AV / Defender. Using
    # System.IO avoids Add-Content's "the stream cannot be read" failure,
    # which happens because Add-Content sniffs encoding by opening the file
    # for read first.
    param(
        [Parameter(Mandatory)][scriptblock]$Mutator,
        [object[]]$MutatorArgs = @()
    )
    $attempts    = 0
    $maxAttempts = 6
    $lastError   = $null
    while ($attempts -lt $maxAttempts) {
        try {
            $existing = @()
            if ([System.IO.File]::Exists($script:HostsPath)) {
                $existing = [System.IO.File]::ReadAllLines($script:HostsPath)
            }
            $newLines = & $Mutator $existing @MutatorArgs
            if ($null -eq $newLines) { return }
            # Only rewrite if content actually changed - avoids needless file handles
            $newText = ($newLines -join "`r`n")
            if ($newText.Length -gt 0 -and -not $newText.EndsWith("`r`n")) { $newText += "`r`n" }
            $oldText = if ($existing -and $existing.Count -gt 0) { ($existing -join "`r`n") + "`r`n" } else { '' }
            if ($newText -eq $oldText) { return }
            [System.IO.File]::WriteAllText($script:HostsPath, $newText, [System.Text.Encoding]::ASCII)
            return
        } catch {
            $lastError = $_
            $attempts++
            if ($attempts -ge $maxAttempts) { throw }
            Start-Sleep -Milliseconds (150 * $attempts)
        }
    }
    if ($lastError) { throw $lastError }
}

function Add-BlockDomain {
    param([Parameter(Mandatory)][string]$Domain)
    if ($script:SupportsFqdn) {
        $rule = "$script:FirewallRulePrefix$Domain"
        if (-not (Get-NetFirewallRule -DisplayName $rule -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -DisplayName $rule -Direction Outbound -Action Block -Profile Any -RemoteFqdn $Domain | Out-Null
        }
    } else {
        $line4 = "0.0.0.0 $Domain $script:HostsMarker"
        Invoke-HostsFileMutation -Mutator ({
            param($lines, $lineToAdd)
            if ($lines -contains $lineToAdd) { return $null }  # no change
            return @($lines) + $lineToAdd
        }) -MutatorArgs @($line4)
    }
}
function Remove-BlockDomain {
    param([Parameter(Mandatory)][string]$Domain)
    if ($script:SupportsFqdn) {
        $rule = "$script:FirewallRulePrefix$Domain"
        $r = Get-NetFirewallRule -DisplayName $rule -ErrorAction SilentlyContinue
        if ($r) { $r | Remove-NetFirewallRule | Out-Null }
    } else {
        if (-not [System.IO.File]::Exists($script:HostsPath)) { return }
        $escaped = [regex]::Escape($Domain)
        $pattern = "^\s*0\.0\.0\.0\s+$escaped\s+$([regex]::Escape($script:HostsMarker))\s*$"
        Invoke-HostsFileMutation -Mutator ({
            param($lines, $pat)
            $kept = $lines | Where-Object { $_ -notmatch $pat }
            return ,@($kept)
        }) -MutatorArgs @($pattern)
    }
}

# --- Edition detection (for telemetry level) -----------------------------
function Get-TelemetryMinValue {
    try {
        $edition = (Get-ComputerInfo -Property WindowsEditionId -ErrorAction Stop).WindowsEditionId
        if ($edition -like '*Home*')       { return 2 }  # Enhanced (minimum for Home)
        elseif ($edition -like '*Pro*')    { return 1 }  # Basic (minimum for Pro)
        else                               { return 0 }  # Security (Enterprise/Education)
    } catch { return 1 }
}

# ============================================================================
#  sevsec/windows-11-privacy - ported modules
# ============================================================================
$script:TelemetryHosts = @(
    'v10.events.data.microsoft.com',
    'settings-win.data.microsoft.com',
    'vortex-win.data.microsoft.com'
)
$script:TelemetryTaskPaths = @(
    '\Microsoft\Windows\Application Experience\',
    '\Microsoft\Windows\Autochk\',
    '\Microsoft\Windows\Customer Experience Improvement Program\',
    '\Microsoft\Windows\DiskDiagnostic\',
    '\Microsoft\Windows\Feedback\Siuf\',
    '\Microsoft\Windows\Windows Error Reporting\'
)

function Invoke-Telemetry {
    param([bool]$Revert)
    if ($Revert) {
        Invoke-Safely { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 'DWord' 1 } "Policy: AllowTelemetry=1"
        Invoke-Safely { Enable-Svc 'DiagTrack' 'Automatic' }     "Service: DiagTrack enabled"
        Invoke-Safely { Enable-Svc 'dmwappushservice' 'Manual' } "Service: dmwappushservice enabled"
        foreach ($p in $script:TelemetryTaskPaths) { Invoke-Safely { Enable-TaskPath $p } "Tasks enabled: $p" }
        foreach ($h in $script:TelemetryHosts) { Invoke-Safely { Remove-BlockDomain $h } "Firewall unblocked: $h" }
        Invoke-Safely { Remove-Item 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting' -Recurse -Force -ErrorAction SilentlyContinue } "Policy cleared: WER"
    } else {
        $tmin = Get-TelemetryMinValue
        Write-Info "Telemetry minimum for this edition: $tmin (0=Security,1=Basic,2=Enhanced)"
        Invoke-Safely { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 'DWord' $tmin } "Policy: AllowTelemetry=$tmin"
        Invoke-Safely { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowDeviceNameInTelemetry' 'DWord' 0 } "Device name in telemetry off"
        Invoke-Safely { Disable-Svc 'DiagTrack' }        "Service: DiagTrack disabled"
        Invoke-Safely { Disable-Svc 'dmwappushservice' } "Service: dmwappushservice disabled"
        foreach ($p in $script:TelemetryTaskPaths) { Invoke-Safely { Disable-TaskPath $p } "Tasks disabled: $p" }
        foreach ($h in $script:TelemetryHosts) { Invoke-Safely { Add-BlockDomain $h } "Firewall block: $h" }
        Invoke-Safely { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting' 'Disabled' 'DWord' 1 } "Policy: WER disabled"
        Invoke-Safely { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' 'DisabledByGroupPolicy' 'DWord' 1 } "Advertising ID disabled"
        Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_TrackProgs' 'DWord' 0 } "App launch tracking off"
        Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' 'DWord' 0 } "Feedback requests off"
        Invoke-Safely { Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\CloudContent' 'DisableTailoredExperiencesWithDiagnosticData' 'DWord' 1 } "Tailored experiences off"
    }
}

function Invoke-AdsRecommendations {
    param([bool]$Revert)
    $cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    $cdmNames = @(
        'ContentDeliveryAllowed','FeatureManagementEnabled','OemPreInstalledAppsEnabled',
        'PreInstalledAppsEnabled','PreInstalledAppsEverEnabled','SilentInstalledAppsEnabled',
        'SoftLandingEnabled','RotatingLockScreenEnabled','RotatingLockScreenOverlayEnabled',
        'SystemPaneSuggestionsEnabled',
        'SubscribedContent-280810Enabled','SubscribedContent-280815Enabled',
        'SubscribedContent-310093Enabled','SubscribedContent-314559Enabled',
        'SubscribedContent-338387Enabled','SubscribedContent-338388Enabled',
        'SubscribedContent-338389Enabled','SubscribedContent-338393Enabled',
        'SubscribedContent-353694Enabled','SubscribedContent-353696Enabled',
        'SubscribedContent-353698Enabled'
    )
    $cloud = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
    $cloudNames = @('DisableWindowsSpotlightFeatures','DisableWindowsSpotlightOnSettings','DisableConsumerFeatures','DisableWindowsConsumerFeatures','DisableSoftLanding','DisableAccountNotifications')
    if ($Revert) {
        foreach ($n in $cloudNames) { Invoke-Safely { Remove-RegValue $cloud $n } "Policy cleared: $n" }
        Invoke-Safely { Set-Reg $cdm 'ContentDeliveryAllowed' 'DWord' 1 } "ContentDelivery on"
        foreach ($n in $cdmNames) { Invoke-Safely { Set-Reg $cdm $n 'DWord' 1 } "CDM on: $n" }
        Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_IrisRecommendations' 'DWord' 1 } "Start Recommended on"
    } else {
        foreach ($n in $cloudNames) { Invoke-Safely { Set-Reg $cloud $n 'DWord' 1 } "Cloud policy off: $n" }
        foreach ($n in $cdmNames) { Invoke-Safely { Set-Reg $cdm $n 'DWord' 0 } "CDM off: $n" }
        Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_IrisRecommendations' 'DWord' 0 } "Start Recommended off"
    }
}

function Invoke-MicrosoftAccount {
    param([bool]$Revert,[bool]$Strict = $false)
    if ($Revert) {
        Invoke-Safely { Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'NoConnectedUser' 'DWord' 0 } "Allow adding MSA"
        foreach ($kv in 'DisableUserAuth','DisableMSA') {
            Invoke-Safely { Remove-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftAccount' $kv } "Policy cleared: $kv"
        }
        Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' 'ScoobeSystemSettingEnabled' 'DWord' 1 } "SCOOBE upsell on"
    } else {
        $v = if ($Strict) { 3 } else { 1 }
        Invoke-Safely { Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'NoConnectedUser' 'DWord' $v } "Block adding MSA (NoConnectedUser=$v)"
        Invoke-Safely { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftAccount' 'DisableUserAuth' 'DWord' 1 } "Disable MSA auth"
        Invoke-Safely { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftAccount' 'DisableMSA'      'DWord' 1 } "Disable MSA (legacy)"
        Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' 'ScoobeSystemSettingEnabled' 'DWord' 0 } "SCOOBE upsell off"
    }
}

function Invoke-ActivityLocation {
    param([bool]$Revert)
    if ($Revert) {
        foreach ($kv in 'EnableActivityFeed','PublishUserActivities','UploadUserActivities') {
            Invoke-Safely { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' $kv 'DWord' 1 } "Activity policy on: $kv"
        }
        Invoke-Safely { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' 'DisableLocation' 'DWord' 0 } "Location policy on"
        Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' 'Value' 'String' 'Allow' } "Per-user location: Allow"
        Invoke-Safely { Enable-Svc 'lfsvc' 'Manual' } "Geolocation service enabled"
    } else {
        foreach ($kv in 'EnableActivityFeed','PublishUserActivities','UploadUserActivities') {
            Invoke-Safely { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' $kv 'DWord' 0 } "Activity policy off: $kv"
        }
        Invoke-Safely { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' 'DisableLocation' 'DWord' 1 } "Location disabled (policy)"
        Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' 'Value' 'String' 'Deny' } "Per-user location: Deny"
        Invoke-Safely { Disable-Svc 'lfsvc' } "Geolocation service disabled"
    }
}

# ============================================================================
#  bRootForceSec/Win11-Debloat-And-Privacy - ported unique modules
# ============================================================================
function Invoke-XboxServices {
    param([bool]$Revert)
    $xSvc = 'XblAuthManager','XblGameSave','XboxNetApiSvc','XboxGipSvc','RetailDemo'
    foreach ($s in $xSvc) {
        if ($Revert) {
            Invoke-Safely { Enable-Svc $s 'Manual' } "Xbox service enabled: $s"
        } else {
            Invoke-Safely { Disable-Svc $s } "Xbox service disabled: $s"
        }
    }
    Write-Warn "XboxGipSvc disable MAY break some game controllers - use revert if they stop working."
}

function Invoke-GameDVR {
    param([bool]$Revert)
    $v = if ($Revert) { 1 } else { 0 }
    Invoke-Safely { Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 'DWord' $v } "Game DVR AppCapture = $v"
    Invoke-Safely { Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 'DWord' $v } "Game DVR store = $v"
    Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 'DWord' $v } "Auto Game Mode = $v"
    if ($Revert) {
        Invoke-Safely { Remove-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' } "Game DVR policy cleared"
    } else {
        Invoke-Safely { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 'DWord' 0 } "Game DVR policy off"
    }
}

function Invoke-Widgets {
    param([bool]$Revert)
    # The HKLM Dsh\AllowNewsAndInterests policy is the authoritative kill;
    # once it is enforced, Windows 11 24H2 may protect the cosmetic per-user
    # HKCU TaskbarDa value and return "operation not allowed" on write. The
    # policy alone already hides the button, so downgrade the HKCU failure
    # to a WARN instead of confusing users with a FAIL.
    $taskbarDa = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    if ($Revert) {
        Invoke-Safely { Remove-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' } "Widgets policy cleared"
        try {
            Set-Reg $taskbarDa 'TaskbarDa' 'DWord' 1
            Write-OK "Widgets taskbar button on"
        } catch {
            Write-Warn "Widgets taskbar button (HKCU) unchanged - policy-enforced: $($_.Exception.Message)"
        }
    } else {
        Invoke-Safely { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 'DWord' 0 } "Widgets policy off"
        try {
            Set-Reg $taskbarDa 'TaskbarDa' 'DWord' 0
            Write-OK "Widgets taskbar button off"
        } catch {
            Write-Warn "Widgets taskbar button (HKCU) unchanged - HKLM policy above is already authoritative: $($_.Exception.Message)"
        }
    }
}

function Invoke-ClassicContextMenu {
    param([bool]$Revert)
    $path = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
    if ($Revert) {
        Invoke-Safely { Remove-Item -Path 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}' -Recurse -Force -ErrorAction SilentlyContinue } "Classic context menu reverted"
    } else {
        Invoke-Safely {
            if (!(Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
            Set-ItemProperty -Path $path -Name '(Default)' -Value '' -Type String -Force
        } "Classic Win10 context menu restored"
    }
}

function Invoke-WebSearch {
    param([bool]$Revert)
    if ($Revert) {
        foreach ($kv in @(
            @{P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; N='DisableSearchBoxSuggestions'},
            @{P='HKCU:\Software\Policies\Microsoft\Windows\Explorer'; N='DisableSearchBoxSuggestions'},
            @{P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; N='DisableWebSearch'},
            @{P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; N='ConnectedSearchUseWeb'}
        )) { Invoke-Safely { Remove-RegValue $kv.P $kv.N } "Cleared $($kv.N)" }
        Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 'DWord' 1 } "Bing search on"
        Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'CortanaConsent'   'DWord' 1 } "Cortana on"
    } else {
        Invoke-Safely { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 'DWord' 1 } "Search suggestions off (HKLM)"
        Invoke-Safely { Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 'DWord' 1 } "Search suggestions off (HKCU)"
        Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 'DWord' 0 } "Bing search off"
        Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'CortanaConsent'   'DWord' 0 } "Cortana off"
        Invoke-Safely { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'DisableWebSearch' 'DWord' 1 } "Web search policy off"
        Invoke-Safely { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'ConnectedSearchUseWeb' 'DWord' 0 } "Connected web search off"
    }
}

function Invoke-TaskbarTweaks {
    param([bool]$Revert)
    $d = if ($Revert) { 1 } else { 0 }
    $left = if ($Revert) { 1 } else { 0 }   # 1 = center (default), 0 = left
    $hideRec = 1 - $d

    # --- SearchboxTaskbarMode: preserve the user's cosmetic preference ------
    # Values: 0=hidden, 1=icon only, 2=icon+label, 3=full search box.
    # Previously Tidy11 forced this to 2 on apply, which surfaced a large
    # "Search" pill for users who had it minimized (1) or hidden (0). We now
    # stash the original on apply and restore it on revert - and we leave the
    # live value alone on apply so the user's taskbar footprint does not grow.
    $searchPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
    if ($Revert) {
        Invoke-Safely {
            if (-not (Restore-UserPreference -Path $searchPath -Name 'SearchboxTaskbarMode')) {
                Write-Info "Search box mode: no stashed preference to restore (leaving as-is)"
            }
        } "Search box mode (user preference restored)"
    } else {
        Invoke-Safely { Save-UserPreference -Path $searchPath -Name 'SearchboxTaskbarMode' } "Search box mode (user preference saved)"
    }

    Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAl'           'DWord' $left }        "Taskbar alignment"
    Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowTaskViewButton'  'DWord' $d }           "Task View button"
    Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_TrackDocs'     'DWord' $d }           "Recent docs tracking"
    Invoke-Safely { Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'                 'HideRecommendedSection' 'DWord' $hideRec } "Hide Start Recommended"
    Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'HideSCAMeetNow'       'DWord' $hideRec }    "Hide Meet Now"
    Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People' 'PeopleBand'     'DWord' $d }         "People band"
    Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarMn'           'DWord' $d }           "Chat icon"
}

function Invoke-PerformanceTweaks {
    param([bool]$Revert)
    if ($Revert) {
        Invoke-Safely { Remove-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'StartupDelayInMSec' } "Startup delay reset"
        Invoke-Safely { Set-Reg 'HKCU:\Control Panel\Desktop' 'MenuShowDelay' 'String' '400' } "Menu delay restored"
    } else {
        Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'StartupDelayInMSec' 'DWord' 0 } "Startup delay 0"
        Invoke-Safely { Set-Reg 'HKCU:\Control Panel\Desktop' 'MenuShowDelay' 'String' '0' } "Menu delay 0"
    }
}

function Invoke-EdgeDebloat {
    param([bool]$Revert)
    $v = if ($Revert) { 1 } else { 0 }
    Invoke-Safely { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'HideFirstRunExperience' 'DWord' (1 - $v) } "Edge first-run hidden"
    Invoke-Safely { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'StartupBoostEnabled'    'DWord' $v } "Edge startup boost"
    Invoke-Safely { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'BackgroundModeEnabled'  'DWord' $v } "Edge background mode"
}

function Invoke-OfficeTelemetry {
    param([bool]$Revert)
    if ($Revert) {
        Invoke-Safely { Remove-RegValue 'HKCU:\Software\Policies\Microsoft\Office\16.0\Common\Privacy' 'DisconnectedState' } "Office connected experiences on"
        Invoke-Safely { Remove-RegValue 'HKCU:\Software\Policies\Microsoft\Office\Common\ClientTelemetry' 'DisableTelemetry' } "Office telemetry on"
    } else {
        Invoke-Safely { Set-Reg 'HKCU:\Software\Policies\Microsoft\Office\16.0\Common\Privacy' 'DisconnectedState' 'DWord' 2 } "Office disconnected state"
        Invoke-Safely { Set-Reg 'HKCU:\Software\Policies\Microsoft\Office\Common\ClientTelemetry' 'DisableTelemetry' 'DWord' 1 } "Office telemetry off"
    }
}

# ============================================================================
#  Wrapper extras - Office Copilot / Notepad / Teams reminder
# ============================================================================
function Invoke-OfficeCopilot {
    param([bool]$Revert)
    $v = if ($Revert) { 0 } else { 1 }
    Invoke-Safely { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common\copilot' 'disablecopilot' 'DWord' $v } "Office Copilot master policy"
    foreach ($app in 'Word','Excel','PowerPoint','OneNote','Outlook') {
        Invoke-Safely { Set-Reg "HKCU:\Software\Microsoft\Office\16.0\$app\Copilot" 'Enabled' 'DWord' (1 - $v) } "$app Copilot per-user toggle"
    }
    $outlookAddin = 'HKCU:\Software\Microsoft\Office\Outlook\Addins\Microsoft.Office.BusinessChat.Addin'
    if (Test-Path $outlookAddin) {
        $lb = if ($Revert) { 3 } else { 0 }
        Invoke-Safely { Set-Reg $outlookAddin 'LoadBehavior' 'DWord' $lb } "Outlook BusinessChat add-in LoadBehavior=$lb"
    }
}

function Invoke-NotepadAI {
    param([bool]$Revert)
    $v = if ($Revert) { 1 } else { 0 }
    foreach ($n in 'CopilotEnabled','AIFeaturesEnabled','ShowAIFeatures') {
        Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\Notepad' $n 'DWord' $v } "Notepad $n = $v"
    }
}

function Show-TeamsReminder {
    Write-Warn "Microsoft Teams Copilot can only be fully disabled tenant-side."
    Write-Warn "    Teams Admin Center -> Meetings -> Meeting policies -> Copilot = Off."
}

# ============================================================================
#  Native Copilot/AI disable - fully offline, no upstream fetch
#  Ports the essential reg-based bits from zoicware/RemoveWindowsAI natively
#  so the tool works without any network dependency.
# ============================================================================
function Invoke-CopilotNative {
    param([bool]$Revert)
    $d = if ($Revert) { 0 } else { 1 }   # "disable" flag value (1=disabled)
    $e = if ($Revert) { 1 } else { 0 }   # "enable" flag value (opposite)
    $gen = if ($Revert) { 1 } else { 2 } # AppPrivacy: 1=Allow, 2=Deny

    # --- HKLM + HKCU Copilot / WindowsAI policies ---
    foreach ($hive in 'HKLM:','HKCU:') {
        Invoke-Safely { Set-Reg "$hive\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" 'TurnOffWindowsCopilot' 'DWord' $d } "$hive Copilot policy"
        Invoke-Safely { Set-Reg "$hive\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" 'DisableAIDataAnalysis'  'DWord' $d } "$hive DisableAIDataAnalysis"
        Invoke-Safely { Set-Reg "$hive\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" 'AllowRecallEnablement'  'DWord' $e } "$hive AllowRecallEnablement"
        Invoke-Safely { Set-Reg "$hive\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" 'DisableClickToDo'       'DWord' $d } "$hive DisableClickToDo"
        Invoke-Safely { Set-Reg "$hive\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" 'TurnOffSavingSnapshots' 'DWord' $d } "$hive TurnOffSavingSnapshots"
        Invoke-Safely { Set-Reg "$hive\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" 'DisableSettingsAgent'   'DWord' $d } "$hive DisableSettingsAgent"
        Invoke-Safely { Set-Reg "$hive\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" 'DisableAgentConnectors' 'DWord' $d } "$hive DisableAgentConnectors"
        Invoke-Safely { Set-Reg "$hive\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" 'DisableAgentWorkspaces' 'DWord' $d } "$hive DisableAgentWorkspaces"
        Invoke-Safely { Set-Reg "$hive\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" 'DisableRemoteAgentConnectors' 'DWord' $d } "$hive DisableRemoteAgentConnectors"
    }

    # --- App privacy: generative AI + system AI models ---
    Invoke-Safely { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsAccessGenerativeAI'   'DWord' $gen } "App privacy: GenAI"
    Invoke-Safely { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsAccessSystemAIModels' 'DWord' $gen } "App privacy: System AI models"

    # --- Paint AI ---
    foreach ($n in 'DisableImageCreator','DisableCocreator','DisableGenerativeFill','DisableGenerativeErase','DisableRemoveBackground') {
        Invoke-Safely { Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint' $n 'DWord' $d } "Paint: $n"
    }

    # --- Edge Copilot + flags ---
    $edgeKeys = @(
        'HubsSidebarEnabled','CopilotPageContext','EdgeEntraCopilotPageContext',
        'EdgeHistoryAISearchEnabled','ComposeInlineEnabled','BuiltInAIAPIsEnabled',
        'AIGenThemesEnabled','ShareBrowsingHistoryWithCopilotSearchAllowed',
        'Microsoft365CopilotChatIconEnabled'
    )
    foreach ($k in $edgeKeys) {
        Invoke-Safely { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' $k 'DWord' $e } "Edge: $k"
    }

    # --- Taskbar / hardware-key / pin / shell ---
    Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowCopilotButton'  'DWord' $e } "Taskbar Copilot button"
    Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarCompanion'   'DWord' $e } "Taskbar Companion"
    Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband\AuxilliaryPins' 'CopilotPWAPin' 'DWord' $e } "Copilot PWA pin"
    Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband\AuxilliaryPins' 'RecallPin'     'DWord' $e } "Recall pin"
    $brandedType  = if ($Revert) { 'App' } else { 'Search' }
    $brandedAumid = if ($Revert) { 'Microsoft.Copilot_8wekyb3d8bbwe!App' } else { ' ' }
    Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\Windows\Shell\BrandedKey' 'BrandedKeyChoiceType' 'String' $brandedType }  "Hardware Copilot key type"
    Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\Windows\Shell\BrandedKey' 'AppAumid'             'String' $brandedAumid } "Hardware Copilot key AUMID"
    Invoke-Safely { Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CopilotKey' 'SetCopilotHardwareKey' 'String' $brandedAumid } "Copilot hardware key policy"

    # --- Ask Copilot shell extension in File Explorer ---
    if ($Revert) {
        Invoke-Safely { Remove-RegValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked' '{CB3B0003-8088-4EDE-8769-8B354AB2FF8C}' } "Ask Copilot shell ext unblocked"
    } else {
        Invoke-Safely { Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked' '{CB3B0003-8088-4EDE-8769-8B354AB2FF8C}' 'String' 'Ask Copilot' } "Ask Copilot shell ext blocked"
    }

    # --- Background app access for Copilot ---
    foreach ($n in 'DisabledByUser','Disabled','SleepDisabled') {
        Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\Microsoft.Copilot_8wekyb3d8bbwe' $n 'DWord' $d } "Copilot bg: $n"
        Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\Microsoft.MicrosoftOfficeHub_8wekyb3d8bbwe' $n 'DWord' $d } "OfficeHub bg: $n"
    }

    # --- Feature management velocity IDs (Copilot / AI Actions nudges) ---
    # Source: zoicware research; values may vary by Windows build
    $velocityIds = @(
        '1853569164','4098520719','929719951',                         # AI Actions
        '1546588812','203105932','2381287564','3189581453','3552646797', # Copilot nudges
        '3389499533','4027803789','450471565',                         # Copilot taskbar/systray
        '2283032206','502943886'                                        # Click To Do core
    )
    foreach ($id in $velocityIds) {
        Invoke-Safely { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FeatureManagement\Overrides\8\$id" 'EnabledState' 'DWord' $d } "FeatureMgmt velocity: $id"
    }

    # --- Ads in Settings home page (Copilot promos) ---
    Invoke-Safely { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableConsumerAccountStateContent' 'DWord' $d } "Settings home ads"

    # --- Gaming Copilot ---
    # This key lives under HKLM:\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId
    # which is owned by NT SERVICE\TrustedInstaller. A plain elevated admin
    # cannot create subkeys or values there without first taking ownership,
    # which is risky (can break Windows Update integrity). Downgrade to a
    # WARN so we don't spam FAIL for an expected limitation, and let users
    # fall back to zoicware/RemoveWindowsAI source-redist for the hard block.
    $gamingKey = 'HKLM:\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Microsoft.Xbox.GamingAI.Companion.Host.GamingCompanionHostOptions'
    if ($Revert) {
        try {
            if (Test-Path $gamingKey) {
                Remove-Item -Path $gamingKey -Recurse -Force -ErrorAction Stop
            }
            Write-OK "Gaming Copilot restored"
        } catch {
            Write-Warn "Gaming Copilot key cleanup skipped (TrustedInstaller-protected): $($_.Exception.Message)"
        }
    } else {
        try {
            Set-Reg $gamingKey 'ActivationType' 'DWord' 0
            Set-Reg $gamingKey 'Server'         'String' ' '
            Write-OK "Gaming Copilot blocked"
        } catch {
            if ($_.Exception -is [System.UnauthorizedAccessException] -or
                $_.Exception.Message -match 'refus|denied|unauthorized|not allowed|non autoris') {
                Write-Warn "Gaming Copilot registry block skipped - key is TrustedInstaller-protected."
                Write-Warn "    Use zoicware/RemoveWindowsAI source redist for a full takeover."
            } else {
                Write-FAIL "Gaming Copilot: $($_.Exception.Message)"
            }
        }
    }

    # --- Voice Access (registry only - file removal needs TrustedInstaller) ---
    Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\VoiceAccess' 'RunningState' 'DWord' $e } "Voice Access running state"

    # --- Typing data harvesting for AI training ---
    Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitInkCollection'  'DWord' $d } "Ink collection restricted"
    Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitTextCollection' 'DWord' $d } "Text collection restricted"
    Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore' 'HarvestContacts' 'DWord' $e } "Contact harvesting"
    Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\input\Settings' 'InsightsEnabled' 'DWord' $e } "Typing insights"
}

# ============================================================================
#  Classic App Replacements - 4 methods selectable at runtime
#
#  Per-app legal status:
#    notepad / photoviewer / photoslegacy : Microsoft-sourced, always clean.
#    mspaint / snippingtool               : need binaries Microsoft removed
#                                           from Win11 - only the upstream
#                                           source redist ships them.
#                                           Gray zone - user opt-in.
# ============================================================================
$script:WingetAlternatives = @{
    'notepad'      = @{ Id = 'Notepad++.Notepad++';         Name = 'Notepad++' }
    'mspaint'      = @{ Id = 'dotPDN.PaintDotNet';          Name = 'Paint.NET' }
    'snippingtool' = @{ Id = 'ShareX.ShareX';               Name = 'ShareX' }
    'photoviewer'  = @{ Id = 'IrfanSkiljan.IrfanView';      Name = 'IrfanView' }
    'photoslegacy' = @{ Id = 'IrfanSkiljan.IrfanView';      Name = 'IrfanView' }
    'classicshell' = @{ Id = 'Open-Shell.Open-Shell-Menu';  Name = 'Open-Shell Menu (Classic Shell successor)' }
}

function Install-WingetPackage {
    param(
        [string]$Id,
        [string]$DisplayName,
        [ValidateSet('winget','msstore')][string]$Source = 'winget'
    )
    try {
        $null = Get-Command winget -ErrorAction Stop
    } catch {
        Write-FAIL "winget not available on this machine. Install App Installer from the Microsoft Store."
        return
    }
    # winget exit codes that mean "no install needed, treat as success":
    #   0x00000000  0           -> installed
    #   0x8A150011  -1978335215 -> APPINSTALLER_CLI_ERROR_INSTALL_ALREADY_INSTALLED
    #   0x8A15002B  -1978335189 -> APPINSTALLER_CLI_ERROR_NO_APPLICABLE_UPGRADE (already current)
    #   0x8A15010E  -1978334962 -> APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE
    $okCodes = @(0, -1978335215, -1978335189, -1978334962)
    try {
        Write-Info "winget installing $DisplayName ($Id) from source '$Source'..."
        # winget emits animated spinners (- \ | /), percent counters and
        # block-character progress bars. When those are piped line-by-line
        # through Write-Log they flood the console with hundreds of junk
        # lines (and mojibake on non-UTF8 consoles). Filter them out and
        # keep only the real status messages ("Found ...", "Downloading ...",
        # "Successfully installed", etc.).
        & winget install --id $Id --source $Source --silent --disable-interactivity `
            --accept-package-agreements --accept-source-agreements -e *>&1 |
            ForEach-Object {
                $text = "$_".Trim()
                if (-not $text)                                                                   { return }
                if ($text -match '^[\\/|\-]+$')                                                   { return }  # spinner
                if ($text -match '^\d+(\.\d+)?\s*%$')                                             { return }  # bare percent
                if ($text -match '^[\d.]+\s*(B|KB|MB|GB|TB)\s*/\s*[\d.]+\s*(B|KB|MB|GB|TB)$')     { return }  # size/size
                if ($text -match '[^\x20-\x7E]')                                                  { return }  # any non-ASCII (block-char progress bars)
                Write-Log $text 'WINGET'
            }
        if ($okCodes -contains $LASTEXITCODE) {
            Write-OK "winget: $DisplayName installed (or already present)"
        } else {
            Write-FAIL "winget $Id exit code $LASTEXITCODE"
        }
    } catch { Write-FAIL "winget $Id : $($_.Exception.Message)" }
}

function Install-ClassicNotepadNative {
    # Microsoft's own Feature-on-Demand capability - fully legit
    try {
        taskkill.exe /im notepad.exe /f 2>&1 | Out-Null
        Get-AppxPackage '*notepad*' -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        Write-Info "Adding Windows capability: Microsoft.Windows.Notepad.System..."
        Add-WindowsCapability -Online -Name 'Microsoft.Windows.Notepad.System~~~~0.0.1.0' -LimitAccess -ErrorAction Stop | Out-Null
        # Minimal file association restoration so it opens .txt files
        Invoke-Safely { Set-Reg 'HKCU:\Software\Microsoft\Notepad' 'ShowStoreBanner' 'DWord' 0 } "Notepad store banner off"
        Write-OK "Classic Notepad installed (Microsoft FoD)"
    } catch {
        Write-FAIL "Classic Notepad: $($_.Exception.Message)"
    }
}

function Install-ClassicPhotoViewerNative {
    # Pure registry restoration - Win11 still ships the PhotoViewer.dll
    $extensions = @('.Bmp','.Cr2','.Dib','.Gif','.JFIF','.Jpe','.Jpeg','.Jpg','.Jxr','.Png','.Tif','.Tiff','.Wdp')
    foreach ($ext in $extensions) {
        try {
            if ($ext -in @('.JFIF','.Jpeg','.Gif','.Png','.Wdp')) {
                $fa = "HKLM:\SOFTWARE\Classes\PhotoViewer.FileAssoc$ext"
                Set-Reg $fa 'EditFlags'        'DWord'        65536
                Set-Reg $fa 'ImageOptionFlags' 'DWord'        1
                Set-Reg $fa 'FriendlyTypeName' 'ExpandString' '@%ProgramFiles%\Windows Photo Viewer\PhotoViewer.dll,-3055'
                Set-Reg "$fa\DefaultIcon" '(Default)' 'String' '%SystemRoot%\System32\imageres.dll,-72'
                Set-Reg "$fa\shell\open" 'MuiVerb' 'ExpandString' '@%ProgramFiles%\Windows Photo Viewer\photoviewer.dll,-3043'
                Set-Reg "$fa\shell\open\command" '(Default)' 'ExpandString' '%SystemRoot%\System32\rundll32.exe "%ProgramFiles%\Windows Photo Viewer\PhotoViewer.dll", ImageView_Fullscreen %1'
                Set-Reg "$fa\shell\open\DropTarget" 'Clsid' 'String' '{FFE2A43C-56B9-4bf5-9A79-CC6D4285608A}'
            }
            $cap = 'HKLM:\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations'
            $val = switch -Regex ($ext) {
                '\.(Cr2|Tif)$'    { 'PhotoViewer.FileAssoc.Tiff' ; break }
                '\.(Dib|Bmp)$'    { 'PhotoViewer.FileAssoc.Bitmap' ; break }
                '\.(Jpg|Jpe|Jpeg)$' { 'PhotoViewer.FileAssoc.Jpeg' ; break }
                default           { "PhotoViewer.FileAssoc$ext" }
            }
            Set-Reg $cap $ext.ToLower() 'String' $val
        } catch { Write-Warn "PhotoViewer $ext : $($_.Exception.Message)" }
    }
    Write-OK "Classic Photo Viewer file associations restored"
}

function Install-ModernUwpFallback {
    # Microsoft does NOT ship the classic Win32 mspaint.exe / SnippingTool.exe on
    # Windows 11. The closest "native" Microsoft-distributed equivalents are the
    # modern UWP Store apps. This helper reports if the UWP version is already
    # installed, otherwise installs it from the Microsoft Store, and logs that
    # this is NOT the classic Win32 binary.
    param(
        [Parameter(Mandatory)][string]$AppxPattern,
        [Parameter(Mandatory)][string]$StoreId,
        [Parameter(Mandatory)][string]$DisplayName,
        [Parameter(Mandatory)][string]$ClassicExeName
    )
    $appx = Get-AppxPackage -Name $AppxPattern -AllUsers -ErrorAction SilentlyContinue
    if ($appx) {
        Write-OK "$DisplayName already present: $($appx[0].PackageFullName)"
        Write-Info "Native method cannot install the classic Win32 $ClassicExeName - use Source Redist for that."
        return
    }
    Write-Info "$DisplayName not found - installing from Microsoft Store..."
    Install-WingetPackage -Id $StoreId -DisplayName $DisplayName -Source msstore
    Write-Info "Native method installs $DisplayName, not the classic Win32 $ClassicExeName. Use Source Redist if you need the classic binary."
}

function Install-PhotosLegacyNative {
    $appx = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.PackageFullName -like '*PhotosLegacy*' }
    if ($appx) {
        Write-OK "Photos Legacy already installed"
        return
    }
    # Microsoft Store has the legacy Photos package - install via winget msstore source.
    try {
        $null = Get-Command winget -ErrorAction Stop
    } catch {
        Write-FAIL "Photos Legacy install failed - winget not available. Open Microsoft Store and search 'Microsoft Photos Legacy'."
        return
    }
    Install-WingetPackage -Id '9NV2L4XVMCXM' -DisplayName 'Microsoft Photos Legacy' -Source msstore
}

$script:RedistValidApps = @('photoviewer','mspaint','snippingtool','notepad','photoslegacy')

function Invoke-SourceRedistOneApp {
    param(
        [Parameter(Mandatory)][string]$App,
        [Parameter(Mandatory)][ValidateSet('Online','Local')][string]$Source,
        [string]$LocalScript
    )
    if ($script:RedistValidApps -notcontains $App) {
        Write-FAIL "Source Redist: '$App' is not a valid upstream classic app"
        return
    }
    try {
        if ($Source -eq 'Local') {
            # Run the on-disk upstream script via a child powershell.exe.
            # IMPORTANT: pass the app as a single positional value - powershell.exe -File
            # does NOT split comma-separated values into arrays, so we install one app
            # per child invocation to keep ValidateSet binding unambiguous.
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $LocalScript `
                -nonInteractive -InstallClassicApps $App *>&1 |
                ForEach-Object { Write-Log "$_" 'REDIST' }
            if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
                Write-FAIL "Source Redist Local: upstream script exited with code $LASTEXITCODE for '$App'"
            } else {
                Write-OK "Source Redist Local: '$App' install step completed"
            }
        } else {
            # Online - download upstream script text to a temp file and run it as a
            # CHILD powershell.exe. The upstream zoicware script is a top-level .ps1
            # that contains 'exit' / 'return' statements at script scope; if we run it
            # as an in-process scriptblock those exits will terminate the Tidy11 GUI
            # process itself (observed: log stops mid-install, no further apps run,
            # window closes silently). Spawning a child shell isolates that fully.
            # We do one app per invocation so each install runs cleanly and any
            # failure is attributed to a specific app in the log.
            $url = 'https://raw.githubusercontent.com/zoicware/RemoveWindowsAI/main/RemoveWindowsAi.ps1'
            $tmpFile = Join-Path $env:TEMP ("Tidy11_RemoveWindowsAi_{0}.ps1" -f ([Guid]::NewGuid().ToString('N')))
            try {
                # Force TLS 1.2 - older defaults still hit some Win11 builds and
                # break the github.com download with a generic SSL error.
                try {
                    [System.Net.ServicePointManager]::SecurityProtocol =
                        [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
                } catch {}

                try {
                    Invoke-WebRequest -Uri $url -OutFile $tmpFile -UseBasicParsing -ErrorAction Stop
                } catch {
                    Write-FAIL "Source Redist Online: failed to download upstream script: $($_.Exception.Message)"
                    return
                }
                if (-not (Test-Path -LiteralPath $tmpFile) -or ((Get-Item -LiteralPath $tmpFile).Length -eq 0)) {
                    Write-FAIL "Source Redist Online: downloaded upstream script is empty"
                    return
                }

                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tmpFile `
                    -nonInteractive -InstallClassicApps $App *>&1 |
                    ForEach-Object { Write-Log "$_" 'REDIST' }

                if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
                    Write-FAIL "Source Redist Online: upstream script exited with code $LASTEXITCODE for '$App'"
                } else {
                    Write-OK "Source Redist Online: '$App' install step completed"
                }
            } finally {
                Remove-Item -LiteralPath $tmpFile -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        Write-FAIL "Source Redist ($Source) failed for '$App': $($_.Exception.Message)"
    }
}

function Invoke-SourceRedistClassicApps {
    param(
        [string[]]$Apps,
        [ValidateSet('Online','Local')][string]$Source,
        [string]$LocalPath
    )
    if (-not $Apps -or $Apps.Count -eq 0) {
        Write-Info "Source Redist: no apps requested"
        return
    }

    Write-Warn '=========================================================='
    Write-Warn ' SOURCE REDIST CLASSIC APPS - the following step downloads'
    Write-Warn ' and runs zoicware/RemoveWindowsAI (MIT-licensed) in order'
    Write-Warn ' to install classic MS Paint and/or Snipping Tool binaries.'
    Write-Warn ' Those binaries are Microsoft copyrights redistributed by'
    Write-Warn ' the upstream project. You are opting in explicitly.'
    Write-Warn '=========================================================='

    # Pre-flight for Local mode: both the script AND the ClassicApps payload
    # must already be staged next to Tidy11.ps1. We fail fast with clear
    # remediation steps so the user is not left guessing.
    $localScript = $null
    if ($Source -eq 'Local') {
        if (-not $LocalPath) {
            Write-FAIL 'Source Redist Local: no LocalPath provided.'
            return
        }
        $localCaDir = Join-Path $LocalPath 'ClassicApps'
        if (-not (Test-Path $localCaDir)) {
            Write-FAIL "Source Redist Local: ClassicApps folder not found at: $localCaDir"
            Write-FAIL 'Pre-stage: download https://github.com/zoicware/RemoveWindowsAI/tree/main/ClassicApps into that folder first.'
            return
        }
        $localScript = Join-Path $LocalPath 'RemoveWindowsAi.ps1'
        if (-not (Test-Path $localScript)) {
            Write-FAIL "Source Redist Local: RemoveWindowsAi.ps1 not found at: $localScript"
            Write-FAIL 'Pre-stage: download https://raw.githubusercontent.com/zoicware/RemoveWindowsAI/main/RemoveWindowsAi.ps1 next to Tidy11.ps1.'
            Write-FAIL 'This mode is strictly offline and will NOT fetch anything at runtime.'
            return
        }
    }

    foreach ($app in $Apps) {
        Write-Info "Source Redist ($Source): installing '$app'..."
        Invoke-SourceRedistOneApp -App $app -Source $Source -LocalScript $localScript
    }
}

function Invoke-ClassicApps {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Winget','Native','SourceRedistOnline','SourceRedistLocal','Skip')]
        [string]$Method,
        [string[]]$Apps = @(),
        [string]$LocalPath = $null
    )
    if ($Apps.Count -eq 0) {
        Write-Info "Classic apps: nothing to do"
        return
    }

    # Open-Shell / Classic Shell successor is freeware (MIT) and is ONLY
    # distributed via winget. It is not a Microsoft-sourced app and is not in
    # the upstream zoicware Source Redist payload, so regardless of the
    # selected method we install it via winget and strip it from the list
    # that gets handed to the method-specific path below. This also means
    # Open-Shell can be installed even when Method='Skip' - it does not care.
    if ($Apps -contains 'classicshell') {
        Write-Info 'Open-Shell (Classic Shell successor) always installs via winget - third-party freeware (MIT).'
        if ($script:WingetAlternatives.ContainsKey('classicshell')) {
            $alt = $script:WingetAlternatives['classicshell']
            Install-WingetPackage -Id $alt.Id -DisplayName $alt.Name
        }
        $Apps = @($Apps | Where-Object { $_ -ne 'classicshell' })
    }

    if ($Method -eq 'Skip' -or $Apps.Count -eq 0) {
        return
    }
    Write-Info "Classic apps: method=$Method, apps=$($Apps -join ',')"

    switch ($Method) {
        'Winget' {
            foreach ($a in $Apps) {
                if ($script:WingetAlternatives.ContainsKey($a)) {
                    $alt = $script:WingetAlternatives[$a]
                    Install-WingetPackage -Id $alt.Id -DisplayName $alt.Name
                } else {
                    Write-Warn "No winget alternative for: $a"
                }
            }
        }
        'Native' {
            foreach ($a in $Apps) {
                switch ($a) {
                    'notepad'      { Install-ClassicNotepadNative }
                    'photoviewer'  { Install-ClassicPhotoViewerNative }
                    'photoslegacy' { Install-PhotosLegacyNative }
                    'mspaint'      {
                        Install-ModernUwpFallback `
                            -AppxPattern 'Microsoft.Paint*' `
                            -StoreId '9PCFS5B6T72H' `
                            -DisplayName 'Microsoft Paint (UWP)' `
                            -ClassicExeName 'mspaint.exe'
                    }
                    'snippingtool' {
                        Install-ModernUwpFallback `
                            -AppxPattern 'Microsoft.ScreenSketch*' `
                            -StoreId '9MZ95KL8MR0L' `
                            -DisplayName 'Snipping Tool (UWP)' `
                            -ClassicExeName 'SnippingTool.exe'
                    }
                }
            }
        }
        'SourceRedistOnline' {
            Invoke-SourceRedistClassicApps -Apps $Apps -Source Online
        }
        'SourceRedistLocal' {
            Invoke-SourceRedistClassicApps -Apps $Apps -Source Local -LocalPath $LocalPath
        }
    }
}

# ============================================================================
#  Native Appx removal for Copilot / Recall packages
# ============================================================================
function Invoke-AIAppxRemoval {
    param([bool]$Revert)
    if ($Revert) {
        Write-Warn "Appx removal is not auto-reversible. To restore, reinstall from Microsoft Store."
        return
    }
    $patterns = @(
        'Microsoft.Copilot*',
        'Microsoft.Windows.Ai.Copilot.Provider*',
        'MicrosoftWindows.Client.Recall*',
        'Microsoft.MicrosoftOfficeHub*'
    )
    foreach ($pat in $patterns) {
        try {
            Get-AppxPackage -Name $pat -AllUsers -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction Stop
                    Write-OK "Appx removed: $($_.PackageFullName)"
                } catch {
                    Write-FAIL "Appx: $($_.PackageFullName) :: $($_.Exception.Message)"
                }
            }
            Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -like $pat } |
                ForEach-Object {
                    try {
                        Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction Stop | Out-Null
                        Write-OK "Provisioned removed: $($_.PackageName)"
                    } catch {
                        Write-FAIL "Provisioned: $($_.PackageName) :: $($_.Exception.Message)"
                    }
                }
        } catch {
            Write-FAIL "Appx scan $pat :: $($_.Exception.Message)"
        }
    }
}

# ============================================================================
#  Simple verification mode (read-only)
# ============================================================================
function Invoke-Verification {
    $total = 0; $pass = 0
    function TCheck($desc, $sb) {
        $script:total++
        if (& $sb) { Write-OK "VERIFY $desc"; $script:pass++ }
        else       { Write-FAIL "VERIFY $desc" }
    }
    Write-Info "=== Verification mode (read-only) ==="
    $script:total = 0; $script:pass = 0
    TCheck 'DiagTrack disabled'         { (Get-Service DiagTrack -ErrorAction SilentlyContinue).StartType -eq 'Disabled' }
    TCheck 'lfsvc disabled'             { (Get-Service lfsvc -ErrorAction SilentlyContinue).StartType -eq 'Disabled' }
    TCheck 'XboxGipSvc disabled'        { (Get-Service XboxGipSvc -ErrorAction SilentlyContinue).StartType -eq 'Disabled' }
    TCheck 'Copilot HKCU policy'        { Test-RegValue 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1 }
    TCheck 'Copilot HKLM policy'        { Test-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1 }
    TCheck 'Recall disabled'            { Test-RegValue 'HKCU:\Software\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1 }
    TCheck 'Widgets policy off'         { Test-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0 }
    TCheck 'Bing search off'            { Test-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 0 }
    TCheck 'Web search policy off'      { Test-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'DisableWebSearch' 1 }
    TCheck 'Advertising ID off'         { Test-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' 'DisabledByGroupPolicy' 1 }
    TCheck 'Activity feed off'          { Test-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableActivityFeed' 0 }
    TCheck 'Location disabled'          { Test-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' 'DisableLocation' 1 }
    TCheck 'Office Copilot policy'      { Test-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common\copilot' 'disablecopilot' 1 }
    TCheck 'Game DVR policy off'        { Test-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0 }
    TCheck 'Classic context menu'       { Test-Path 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' }
    TCheck 'Telemetry policy set'       { (Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name AllowTelemetry -ErrorAction SilentlyContinue).AllowTelemetry -ne $null }

    Write-Info "=== Verification: $script:pass / $script:total checks passed ==="
}

# ============================================================================
#  Config recipes - save/load GUI selections as JSON for cross-machine reuse
# ============================================================================
function Export-Tidy11Config {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][hashtable]$Selections,
        [string]$Description = ''
    )
    $config = [pscustomobject]@{
        tool        = 'Tidy11'
        version     = '1.0'
        created     = (Get-Date).ToString('o')
        createdBy   = "$env:COMPUTERNAME\$env:USERNAME"
        description = $Description
        selections  = $Selections
    }
    try {
        $config | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Encoding UTF8
        Write-OK "Config recipe saved: $Path"
        return $true
    } catch {
        Write-FAIL "Config save failed: $($_.Exception.Message)"
        return $false
    }
}

function Import-Tidy11Config {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) {
        Write-FAIL "Config file not found: $Path"
        return $null
    }
    try {
        $config = Get-Content $Path -Raw | ConvertFrom-Json
        if ($config.tool -ne 'Tidy11') {
            Write-Warn "Config file is not a Tidy11 recipe (tool=$($config.tool))"
        }
        Write-OK "Config loaded from: $Path"
        if ($config.description) { Write-Info "Description: $($config.description)" }
        if ($config.createdBy)   { Write-Info "Created by: $($config.createdBy)" }
        return $config
    } catch {
        Write-FAIL "Config parse error: $($_.Exception.Message)"
        return $null
    }
}

# ============================================================================
#  Pre-change snapshot - captures everything Tidy11 might modify
# ============================================================================
# ============================================================================
#  Windows System Restore point (independent of Tidy11 snapshot system)
# ============================================================================
function New-Tidy11SystemRestorePoint {
    param(
        [string]$Description = "Tidy11 pre-change checkpoint"
    )

    Write-Info 'Checking Windows System Restore configuration...'

    # --- 1. Ensure VSS service is not hard-disabled -------------------------
    $vss = Get-Service -Name VSS -ErrorAction SilentlyContinue
    if (-not $vss) {
        Write-FAIL 'Volume Shadow Copy Service (VSS) not found. Cannot create a system restore point.'
        return $false
    }
    if ($vss.StartType -eq 'Disabled') {
        try {
            Set-Service -Name VSS -StartupType Manual -ErrorAction Stop
            Write-OK 'VSS service set to Manual (was Disabled)'
        } catch {
            Write-FAIL "Cannot enable VSS service: $($_.Exception.Message)"
            return $false
        }
    }

    # --- 2. Check whether System Restore is enabled on the system drive -----
    $sysDrive = "$($env:SystemDrive)\"
    $srRoot   = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
    $srDisabled = $false
    try {
        $disableSR  = (Get-ItemProperty -Path $srRoot -Name 'DisableSR'     -ErrorAction SilentlyContinue).DisableSR
        $disableCfg = (Get-ItemProperty -Path $srRoot -Name 'DisableConfig' -ErrorAction SilentlyContinue).DisableConfig
        if ($disableSR -eq 1 -or $disableCfg -eq 1) { $srDisabled = $true }
    } catch {}

    # --- 3. Enable if disabled ----------------------------------------------
    if ($srDisabled) {
        Write-Info "System Restore is disabled on $sysDrive - enabling it now..."
        # Clear the group policy disables if present (from Windows Home quirks)
        try { Remove-ItemProperty -Path $srRoot -Name 'DisableSR'     -Force -ErrorAction SilentlyContinue } catch {}
        try { Remove-ItemProperty -Path $srRoot -Name 'DisableConfig' -Force -ErrorAction SilentlyContinue } catch {}
    }

    try {
        Enable-ComputerRestore -Drive $sysDrive -ErrorAction Stop
        Write-OK "System Restore enabled on $sysDrive"
    } catch {
        Write-FAIL "Enable-ComputerRestore failed: $($_.Exception.Message)"
        Write-Warn 'Open System Properties -> System Protection -> Configure -> Turn on system protection, then re-run.'
        return $false
    }

    # --- 4. Ensure shadow storage has at least some space allocated ---------
    # On fresh Win11 installs the default quota can be 0, which silently
    # prevents Checkpoint-Computer from working. Set a small floor (3%).
    try {
        $vssInfo = & vssadmin.exe list shadowstorage /for=$sysDrive 2>&1 | Out-String
        if ($vssInfo -match 'Maximum Shadow Copy Storage space:\s*0 bytes' -or
            $vssInfo -match 'No items found') {
            Write-Info 'Shadow storage allocation is 0 - setting to 3% of the system drive.'
            & vssadmin.exe resize shadowstorage /for=$sysDrive /on=$sysDrive /maxsize=3% 2>&1 | Out-Null
        }
    } catch { Write-Warn "vssadmin check skipped: $($_.Exception.Message)" }

    # --- 5. Bypass the built-in 1440-minute throttle for this creation ------
    # Windows defaults to one restore point per 1440 minutes (24h). Set the
    # frequency to 0 so our checkpoint is guaranteed to create, then restore.
    $freqName  = 'SystemRestorePointCreationFrequency'
    $prevFreq  = $null
    $freqWasSet = $false
    try {
        $probe = Get-ItemProperty -Path $srRoot -Name $freqName -ErrorAction SilentlyContinue
        if ($probe -and $null -ne $probe.$freqName) {
            $prevFreq   = $probe.$freqName
            $freqWasSet = $true
        }
        New-ItemProperty -Path $srRoot -Name $freqName -Value 0 -PropertyType DWord -Force | Out-Null
    } catch {}

    # --- 6. Create the checkpoint -------------------------------------------
    $created = $false
    try {
        Checkpoint-Computer -Description $Description -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        Write-OK "Windows System Restore point created: '$Description'"
        $created = $true
    } catch {
        Write-FAIL "Checkpoint-Computer failed: $($_.Exception.Message)"
        Write-Warn 'If the error mentions shadow copy, try freeing disk space and re-running.'
    } finally {
        # --- 7. Restore previous frequency setting --------------------------
        try {
            if ($freqWasSet) {
                Set-ItemProperty -Path $srRoot -Name $freqName -Value $prevFreq -Force
            } else {
                Remove-ItemProperty -Path $srRoot -Name $freqName -Force -ErrorAction SilentlyContinue
            }
        } catch {}
    }

    return $created
}

function New-Tidy11Snapshot {
    param([string]$Path = (Join-Path $env:USERPROFILE 'Documents\Tidy11-Snapshots'))
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $dir   = Join-Path $Path "Tidy11-Snapshot_$stamp"
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    # Remember the path + start a fresh net-new-value tracking list for this run
    $script:CurrentSnapshotPath = $dir
    Reset-CreatedValues

    # Also tee the session log to the snapshot folder for post-mortem debugging
    Set-LogFile (Join-Path $dir 'run.log')

    Write-Info "Creating snapshot at: $dir"

    # --- Registry exports (policy trees + key HKCU branches) ---
    $regExports = @(
        @{ Key = 'HKLM\SOFTWARE\Policies\Microsoft\Windows';                                   File = 'HKLM_Policies_MicrosoftWindows.reg' }
        @{ Key = 'HKLM\SOFTWARE\Policies\Microsoft\Edge';                                      File = 'HKLM_Policies_Edge.reg' }
        @{ Key = 'HKLM\SOFTWARE\Policies\Microsoft\office';                                    File = 'HKLM_Policies_Office.reg' }
        @{ Key = 'HKLM\SOFTWARE\Policies\Microsoft\MicrosoftAccount';                          File = 'HKLM_Policies_MSA.reg' }
        @{ Key = 'HKLM\SOFTWARE\Policies\Microsoft\Dsh';                                       File = 'HKLM_Policies_Dsh.reg' }
        @{ Key = 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender';                          File = 'HKLM_Policies_Defender.reg' }
        @{ Key = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies';                    File = 'HKLM_CV_Policies.reg' }
        @{ Key = 'HKLM\SYSTEM\ControlSet001\Control\FeatureManagement\Overrides\8';            File = 'HKLM_FeatureManagement.reg' }
        @{ Key = 'HKCU\Software\Policies\Microsoft';                                           File = 'HKCU_Policies.reg' }
        @{ Key = 'HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager';      File = 'HKCU_CDM.reg' }
        @{ Key = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';           File = 'HKCU_ExplorerAdvanced.reg' }
        @{ Key = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Search';                      File = 'HKCU_Search.reg' }
        @{ Key = 'HKCU\Software\Microsoft\Notepad';                                            File = 'HKCU_Notepad.reg' }
        @{ Key = 'HKCU\Software\Microsoft\Office';                                             File = 'HKCU_Office.reg' }
    )
    foreach ($r in $regExports) {
        $out = Join-Path $dir $r.File
        reg.exe export $r.Key $out /y 2>&1 | Out-Null
    }

    # --- Services snapshot ---
    $svcNames = @('DiagTrack','dmwappushservice','lfsvc','XblAuthManager','XblGameSave',
                  'XboxNetApiSvc','XboxGipSvc','RetailDemo','WSAIFabricSvc','AarSvc')
    $services = foreach ($n in $svcNames) {
        $s = Get-Service -Name $n -ErrorAction SilentlyContinue
        if ($s) {
            [pscustomobject]@{
                Name      = $n
                StartType = $s.StartType.ToString()
                Status    = $s.Status.ToString()
            }
        }
    }
    $services | ConvertTo-Json | Set-Content (Join-Path $dir 'services.json')

    # --- Scheduled tasks snapshot ---
    $taskPaths = @(
        '\Microsoft\Windows\Application Experience\',
        '\Microsoft\Windows\Autochk\',
        '\Microsoft\Windows\Customer Experience Improvement Program\',
        '\Microsoft\Windows\DiskDiagnostic\',
        '\Microsoft\Windows\Feedback\Siuf\',
        '\Microsoft\Windows\Windows Error Reporting\'
    )
    $tasks = foreach ($p in $taskPaths) {
        Get-ScheduledTask -TaskPath $p -ErrorAction SilentlyContinue |
            Select-Object TaskPath, TaskName, @{N='State';E={$_.State.ToString()}}
    }
    $tasks | ConvertTo-Json | Set-Content (Join-Path $dir 'tasks.json')

    # --- Firewall rules we might create ---
    $rules = Get-NetFirewallRule -DisplayName 'PrivacyBlock-*' -ErrorAction SilentlyContinue |
        Select-Object DisplayName, @{N='Direction';E={$_.Direction.ToString()}}, @{N='Action';E={$_.Action.ToString()}}, Enabled
    $rules | ConvertTo-Json | Set-Content (Join-Path $dir 'firewall.json')

    # --- hosts file backup (for FQDN blocks that fell back to hosts) ---
    try {
        $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
        if (Test-Path $hostsPath) {
            Copy-Item -Path $hostsPath -Destination (Join-Path $dir 'hosts.backup') -Force
            Write-Info 'hosts file backed up.'
        }
    } catch { Write-Warn "hosts backup skipped: $($_.Exception.Message)" }

    # --- Manifest ---
    $build = try { (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuild } catch { 'unknown' }
    $edition = try { (Get-ComputerInfo -Property WindowsEditionId -ErrorAction Stop).WindowsEditionId } catch { 'unknown' }
    $manifest = [pscustomobject]@{
        tool         = 'Tidy11'
        version      = '1.0'
        created      = (Get-Date).ToString('o')
        hostname     = $env:COMPUTERNAME
        user         = "$env:USERDOMAIN\$env:USERNAME"
        windowsBuild = $build
        edition      = $edition
    }
    $manifest | ConvertTo-Json | Set-Content (Join-Path $dir 'manifest.json')

    Write-OK "Snapshot complete: $dir"
    return $dir
}

function Restore-Tidy11Snapshot {
    param([Parameter(Mandatory)][string]$SnapshotPath)
    if (-not (Test-Path $SnapshotPath)) {
        Write-FAIL "Snapshot folder not found: $SnapshotPath"
        return
    }
    $manifest = Join-Path $SnapshotPath 'manifest.json'
    if (Test-Path $manifest) {
        $m = Get-Content $manifest -Raw | ConvertFrom-Json
        Write-Info "Restoring snapshot from: $($m.created) on $($m.hostname) (build $($m.windowsBuild))"
    }

    # --- Step 1: reimport captured registry trees (restores previously-existing values) ---
    Get-ChildItem -Path $SnapshotPath -Filter '*.reg' | ForEach-Object {
        try {
            reg.exe import $_.FullName 2>&1 | Out-Null
            Write-OK "Registry restored: $($_.Name)"
        } catch {
            Write-FAIL "Registry import failed for $($_.Name): $($_.Exception.Message)"
        }
    }

    # --- Step 2: delete net-new values Tidy11 created (the gap that plain .reg import can't close) ---
    $cvFile = Join-Path $SnapshotPath 'created-values.json'
    if (Test-Path $cvFile) {
        try {
            $created = Get-Content $cvFile -Raw | ConvertFrom-Json
            $count = 0
            foreach ($c in $created) {
                try {
                    if (Test-Path $c.Path) {
                        Remove-ItemProperty -Path $c.Path -Name $c.Name -Force -ErrorAction SilentlyContinue
                        $count++
                    }
                } catch {}
            }
            Write-OK "Deleted $count net-new values recorded by Tidy11"
        } catch { Write-Warn "created-values.json parse error: $($_.Exception.Message)" }
    }

    # --- Step 3: belt-and-suspenders cleanup via Tidy11-Revert.reg if present next to the tool ---
    $revertReg = Join-Path $PSScriptRoot 'Tidy11-Revert.reg'
    if ($PSScriptRoot -and (Test-Path $revertReg)) {
        try {
            reg.exe import $revertReg 2>&1 | Out-Null
            Write-OK 'Applied Tidy11-Revert.reg (static policy cleanup)'
        } catch { Write-Warn "Tidy11-Revert.reg import failed: $($_.Exception.Message)" }
    }

    # --- Step 4: restore services ---
    $svcFile = Join-Path $SnapshotPath 'services.json'
    if (Test-Path $svcFile) {
        $svcs = Get-Content $svcFile -Raw | ConvertFrom-Json
        foreach ($s in $svcs) {
            try {
                if (Get-Service -Name $s.Name -ErrorAction SilentlyContinue) {
                    Set-Service -Name $s.Name -StartupType $s.StartType -ErrorAction Stop
                    if ($s.Status -eq 'Running') {
                        try { Start-Service -Name $s.Name -ErrorAction SilentlyContinue } catch {}
                    }
                    Write-OK "Service restored: $($s.Name) -> $($s.StartType)"
                }
            } catch { Write-FAIL "Service $($s.Name): $($_.Exception.Message)" }
        }
    }

    # --- Step 5: restore scheduled tasks (re-enable those that were Ready) ---
    $taskFile = Join-Path $SnapshotPath 'tasks.json'
    if (Test-Path $taskFile) {
        $tasks = Get-Content $taskFile -Raw | ConvertFrom-Json
        foreach ($t in $tasks) {
            if ($t.State -eq 'Ready') {
                try {
                    Enable-ScheduledTask -TaskPath $t.TaskPath -TaskName $t.TaskName -ErrorAction Stop | Out-Null
                    Write-OK "Task re-enabled: $($t.TaskPath)$($t.TaskName)"
                } catch {}
            }
        }
    }

    # --- Step 6: differential firewall restore (only delete PrivacyBlock-* rules that didn't pre-exist) ---
    $fwFile = Join-Path $SnapshotPath 'firewall.json'
    $preExisting = @()
    if (Test-Path $fwFile) {
        try {
            $fwData = Get-Content $fwFile -Raw | ConvertFrom-Json
            if ($fwData) { $preExisting = @($fwData | ForEach-Object { $_.DisplayName }) }
        } catch {}
    }
    Get-NetFirewallRule -DisplayName 'PrivacyBlock-*' -ErrorAction SilentlyContinue |
        ForEach-Object {
            if ($preExisting -contains $_.DisplayName) {
                Write-Info "Firewall rule kept (pre-existing): $($_.DisplayName)"
            } else {
                try {
                    Remove-NetFirewallRule -DisplayName $_.DisplayName -ErrorAction Stop
                    Write-OK "Firewall rule removed: $($_.DisplayName)"
                } catch {}
            }
        }

    # --- Step 7: restore hosts file if we backed it up ---
    $hostsBackup = Join-Path $SnapshotPath 'hosts.backup'
    if (Test-Path $hostsBackup) {
        try {
            $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
            Copy-Item -Path $hostsBackup -Destination $hostsPath -Force
            Write-OK 'hosts file restored from snapshot'
        } catch { Write-FAIL "hosts restore failed: $($_.Exception.Message)" }
    }

    Write-OK 'Restore complete. Reboot recommended.'
}

Export-ModuleMember -Function *

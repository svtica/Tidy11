<#
.SYNOPSIS
    Tidy11-Remediate.ps1 - Intune Proactive Remediation remediation script.

.DESCRIPTION
    Self-contained (no module dependency - Intune PR scripts are shipped as a
    single file). Re-applies the Tidy11 DISABLE baseline non-interactively.

    Deployed via: Intune admin center -> Devices -> Scripts and remediations ->
                  Create script package -> Remediation script file -> Run as system.

.NOTES
    Author:  svtica
    License: GPL-3.0-or-later
    Project: https://github.com/svtica/Tidy11

    Scope: HKLM policies that work machine-wide under SYSTEM. HKCU writes here
    target the DEFAULT USER hive so new user profiles inherit settings.
    For existing user profiles, run via user-context script or use logon script.

    Returns exit 0 on success, 1 on partial failure.
#>

$ErrorActionPreference = 'SilentlyContinue'
$failures = 0

function Set-Reg {
    param([string]$Path,[string]$Name,[string]$Type,$Value)
    try {
        if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        New-ItemProperty -Path $Path -Name $Name -PropertyType $Type -Value $Value -Force | Out-Null
        return $true
    } catch {
        Write-Output "FAIL $Path\$Name : $($_.Exception.Message)"
        $script:failures++
        return $false
    }
}

function Disable-Svc {
    param([string]$Name)
    try {
        if (Get-Service -Name $Name -ErrorAction Stop) {
            Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
            Set-Service -Name $Name -StartupType Disabled -ErrorAction Stop
        }
    } catch {
        Write-Output "FAIL svc $Name : $($_.Exception.Message)"
        $script:failures++
    }
}

function Disable-TaskPath {
    param([string]$TaskPath)
    try {
        $tasks = Get-ScheduledTask -TaskPath $TaskPath -ErrorAction Stop
        foreach ($t in $tasks) {
            Disable-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {}  # task paths may legitimately be empty
}

# -------- edition-aware telemetry min value --------
function Get-TelemetryMinValue {
    try {
        $edition = (Get-ComputerInfo -Property WindowsEditionId -ErrorAction Stop).WindowsEditionId
        if ($edition -like '*Home*') { return 2 }
        elseif ($edition -like '*Pro*') { return 1 }
        else { return 0 }
    } catch { return 1 }
}

Write-Output '=== Tidy11 remediation starting ==='

# ============================================================================
# 1. Copilot / WindowsAI / Recall
# ============================================================================
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 'DWord' 1 | Out-Null
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis'      'DWord' 1 | Out-Null
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'AllowRecallEnablement'     'DWord' 0 | Out-Null
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableClickToDo'          'DWord' 1 | Out-Null
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'TurnOffSavingSnapshots'    'DWord' 1 | Out-Null
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableSettingsAgent'      'DWord' 1 | Out-Null
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAgentConnectors'    'DWord' 1 | Out-Null
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAgentWorkspaces'    'DWord' 1 | Out-Null
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableRemoteAgentConnectors' 'DWord' 1 | Out-Null
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsAccessGenerativeAI'   'DWord' 2 | Out-Null
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsAccessSystemAIModels' 'DWord' 2 | Out-Null

# ============================================================================
# 2. Paint AI
# ============================================================================
foreach ($n in 'DisableImageCreator','DisableCocreator','DisableGenerativeFill','DisableGenerativeErase','DisableRemoveBackground') {
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint' $n 'DWord' 1 | Out-Null
}

# ============================================================================
# 3. Edge Copilot
# ============================================================================
$edgePolicies = @{
    'HubsSidebarEnabled'                       = 0
    'CopilotPageContext'                       = 0
    'EdgeEntraCopilotPageContext'              = 0
    'EdgeHistoryAISearchEnabled'               = 0
    'ComposeInlineEnabled'                     = 0
    'BuiltInAIAPIsEnabled'                     = 0
    'AIGenThemesEnabled'                       = 0
    'ShareBrowsingHistoryWithCopilotSearchAllowed' = 0
    'StartupBoostEnabled'                      = 0
    'BackgroundModeEnabled'                    = 0
}
foreach ($k in $edgePolicies.Keys) {
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' $k 'DWord' $edgePolicies[$k] | Out-Null
}

# ============================================================================
# 4. Telemetry (sevsec)
# ============================================================================
$tmin = Get-TelemetryMinValue
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry'             'DWord' $tmin | Out-Null
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowDeviceNameInTelemetry' 'DWord' 0     | Out-Null
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' 'DisabledByGroupPolicy'     'DWord' 1     | Out-Null
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting' 'Disabled'          'DWord' 1     | Out-Null

Disable-Svc 'DiagTrack'
Disable-Svc 'dmwappushservice'
Disable-TaskPath '\Microsoft\Windows\Application Experience\'
Disable-TaskPath '\Microsoft\Windows\Autochk\'
Disable-TaskPath '\Microsoft\Windows\Customer Experience Improvement Program\'
Disable-TaskPath '\Microsoft\Windows\DiskDiagnostic\'
Disable-TaskPath '\Microsoft\Windows\Feedback\Siuf\'
Disable-TaskPath '\Microsoft\Windows\Windows Error Reporting\'

# FQDN firewall blocks for telemetry hosts
$telemetryHosts = 'v10.events.data.microsoft.com','settings-win.data.microsoft.com','vortex-win.data.microsoft.com'
$supportsFqdn = ($null -ne (Get-Command New-NetFirewallRule).Parameters['RemoteFqdn'])
foreach ($h in $telemetryHosts) {
    if ($supportsFqdn) {
        $rule = "PrivacyBlock-$h"
        if (-not (Get-NetFirewallRule -DisplayName $rule -ErrorAction SilentlyContinue)) {
            try {
                New-NetFirewallRule -DisplayName $rule -Direction Outbound -Action Block -Profile Any -RemoteFqdn $h -ErrorAction Stop | Out-Null
            } catch { $failures++ }
        }
    }
}

# ============================================================================
# 5. Ads / Spotlight / Cloud content
# ============================================================================
$cloud = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
foreach ($n in 'DisableWindowsSpotlightFeatures','DisableWindowsSpotlightOnSettings','DisableConsumerFeatures','DisableWindowsConsumerFeatures','DisableSoftLanding','DisableAccountNotifications') {
    Set-Reg $cloud $n 'DWord' 1 | Out-Null
}

# ============================================================================
# 6. Activity History & Location
# ============================================================================
foreach ($kv in 'EnableActivityFeed','PublishUserActivities','UploadUserActivities') {
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' $kv 'DWord' 0 | Out-Null
}
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' 'DisableLocation' 'DWord' 1 | Out-Null
Disable-Svc 'lfsvc'

# ============================================================================
# 7. Widgets / News and Interests
# ============================================================================
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 'DWord' 0 | Out-Null

# ============================================================================
# 8. Web Search
# ============================================================================
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'       'DisableSearchBoxSuggestions' 'DWord' 1 | Out-Null
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'DisableWebSearch'            'DWord' 1 | Out-Null
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'ConnectedSearchUseWeb'       'DWord' 0 | Out-Null

# ============================================================================
# 9. Game DVR
# ============================================================================
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 'DWord' 0 | Out-Null

# ============================================================================
# 10. Office Copilot master policy (HKLM for machine-wide enforcement)
# ============================================================================
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common\copilot' 'disablecopilot' 'DWord' 1 | Out-Null

# ============================================================================
# 11. Apply default-user hive (so NEW profiles inherit HKCU settings)
# ============================================================================
try {
    reg.exe load 'HKU\DefaultUserTidy11' "$env:SystemDrive\Users\Default\NTUSER.DAT" 2>$null | Out-Null
    $duKeys = @(
        @{ P='HKU:\DefaultUserTidy11\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'; N='TurnOffWindowsCopilot'; V=1 }
        @{ P='HKU:\DefaultUserTidy11\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; N='DisableAIDataAnalysis'; V=1 }
        @{ P='HKU:\DefaultUserTidy11\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; N='ShowCopilotButton'; V=0 }
        @{ P='HKU:\DefaultUserTidy11\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; N='Start_IrisRecommendations'; V=0 }
        @{ P='HKU:\DefaultUserTidy11\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; N='TaskbarAl'; V=0 }
        @{ P='HKU:\DefaultUserTidy11\Software\Microsoft\Windows\CurrentVersion\Search'; N='BingSearchEnabled'; V=0 }
        @{ P='HKU:\DefaultUserTidy11\Software\Microsoft\Input\Settings'; N='InsightsEnabled'; V=0 }
    )
    foreach ($k in $duKeys) { Set-Reg $k.P $k.N 'DWord' $k.V | Out-Null }
    [GC]::Collect()
    reg.exe unload 'HKU\DefaultUserTidy11' 2>$null | Out-Null
} catch {
    Write-Output "FAIL default-user hive: $($_.Exception.Message)"
    $failures++
}

Write-Output "=== Tidy11 remediation complete (failures: $failures) ==="

if ($failures -gt 0) { exit 1 } else { exit 0 }

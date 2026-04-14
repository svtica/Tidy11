<#
.SYNOPSIS
    Tidy11-User.ps1 - user-context companion to Tidy11-Remediate.ps1.

.DESCRIPTION
    Intune PowerShell scripts run as SYSTEM by default, which cannot write
    HKCU for existing user profiles. This script handles the per-user keys
    that the SYSTEM-context remediation cannot reach.

    Deploy via:
      Intune admin center -> Devices -> Scripts and remediations ->
      Platform scripts -> Add -> Windows 10 and later
      * Run this script using the logged-on credentials: YES
      * Enforce script signature check: No (unless signed)
      * Run script in 64-bit PowerShell: Yes
      Assign to USER group (not device group).

.NOTES
    Author:  svtica
    License: GPL-3.0-or-later
    Project: https://github.com/svtica/Tidy11

    Runs as the interactive user. No admin rights required - all writes are
    to HKCU. Idempotent: safe to run on a schedule.

    Exit 0 = success, 1 = one or more writes failed.
#>

$ErrorActionPreference = 'SilentlyContinue'
$failures = 0

function Set-Reg {
    param([string]$Path, [string]$Name, [string]$Type, $Value)
    try {
        if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        New-ItemProperty -Path $Path -Name $Name -PropertyType $Type -Value $Value -Force | Out-Null
    } catch {
        Write-Output "FAIL $Path\$Name : $($_.Exception.Message)"
        $script:failures++
    }
}

Write-Output "=== Tidy11 user-context pass starting (user: $env:USERNAME) ==="

# ============================================================================
# 1. Copilot / Recall / AI - HKCU policies
# ============================================================================
Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 'DWord' 1
Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'      'DisableAIDataAnalysis' 'DWord' 1
Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'      'DisableClickToDo'      'DWord' 1
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowCopilotButton' 'DWord' 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarCompanion'  'DWord' 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\Shell\ClickToDo'         'DisableClickToDo' 'DWord' 1
Set-Reg 'HKCU:\Software\Microsoft\input\Settings'                  'InsightsEnabled'  'DWord' 0

# Ask Copilot in File Explorer context menu
try {
    if (!(Test-Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked')) {
        New-Item 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked' -Force | Out-Null
    }
    New-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked' `
        -Name '{CB3B0003-8088-4EDE-8769-8B354AB2FF8C}' -PropertyType String -Value 'Ask Copilot' -Force | Out-Null
} catch { $failures++ }

# ============================================================================
# 2. Microsoft 365 Office Copilot - per-user toggles
# ============================================================================
foreach ($app in 'Word','Excel','PowerPoint','OneNote','Outlook') {
    Set-Reg "HKCU:\Software\Microsoft\Office\16.0\$app\Copilot" 'Enabled' 'DWord' 0
}

# Outlook BusinessChat add-in (only if installed)
$outlookAddin = 'HKCU:\Software\Microsoft\Office\Outlook\Addins\Microsoft.Office.BusinessChat.Addin'
if (Test-Path $outlookAddin) {
    Set-Reg $outlookAddin 'LoadBehavior' 'DWord' 0
}

# ============================================================================
# 3. Notepad AI / Copilot
# ============================================================================
foreach ($n in 'CopilotEnabled','AIFeaturesEnabled','ShowAIFeatures') {
    Set-Reg 'HKCU:\Software\Microsoft\Notepad' $n 'DWord' 0
}

# ============================================================================
# 4. Taskbar customization (bRootForceSec)
# ============================================================================
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAl'              'DWord' 0  # 0=left, 1=center
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowTaskViewButton'     'DWord' 0
# SearchboxTaskbarMode (0=hidden, 1=icon, 2=icon+label, 3=box) is a purely
# cosmetic user choice. Forcing it to 2 surfaced a large "Search" pill for
# users who had it minimized or hidden, so we now leave the live value alone
# and just stash it under HKCU\Software\Tidy11\UserPrefs so a later GUI
# revert can put back whatever was there before.
try {
    $searchKey  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
    $stashKey   = 'HKCU:\Software\Tidy11\UserPrefs'
    $stashName  = 'HKCU__Software_Microsoft_Windows_CurrentVersion_Search__SearchboxTaskbarMode'
    $absentName = "${stashName}__absent"
    if (!(Test-Path $stashKey)) { New-Item -Path $stashKey -Force | Out-Null }
    $alreadyStashed = $false
    $probe = Get-ItemProperty -Path $stashKey -Name $stashName  -ErrorAction SilentlyContinue
    if ($probe -and $null -ne $probe.$stashName) { $alreadyStashed = $true }
    $probeAbs = Get-ItemProperty -Path $stashKey -Name $absentName -ErrorAction SilentlyContinue
    if ($probeAbs -and $null -ne $probeAbs.$absentName) { $alreadyStashed = $true }
    if (-not $alreadyStashed) {
        $current = (Get-ItemProperty -Path $searchKey -Name 'SearchboxTaskbarMode' -ErrorAction SilentlyContinue).SearchboxTaskbarMode
        if ($null -ne $current) {
            New-ItemProperty -Path $stashKey -Name $stashName  -PropertyType DWord -Value ([int]$current) -Force | Out-Null
        } else {
            New-ItemProperty -Path $stashKey -Name $absentName -PropertyType DWord -Value 1              -Force | Out-Null
        }
    }
} catch {
    Write-Output "WARN SearchboxTaskbarMode preference stash failed: $($_.Exception.Message)"
}
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_TrackDocs'        'DWord' 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_TrackProgs'       'DWord' 0
Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'                'HideRecommendedSection' 'DWord' 1
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'HideSCAMeetNow'         'DWord' 1
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People' 'PeopleBand'      'DWord' 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarMn'              'DWord' 0  # Chat icon
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarDa'              'DWord' 0  # Widgets icon
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_IrisRecommendations' 'DWord' 0

# ============================================================================
# 5. ContentDeliveryManager - per-user ads / suggestions
# ============================================================================
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
foreach ($n in $cdmNames) { Set-Reg $cdm $n 'DWord' 0 }

# CloudContent HKCU-side
Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsSpotlightFeatures'  'DWord' 1
Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures'   'DWord' 1
Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\CloudContent' 'DisableTailoredExperiencesWithDiagnosticData' 'DWord' 1

# ============================================================================
# 6. Web search / Cortana / Bing - HKCU
# ============================================================================
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 'DWord' 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'CortanaConsent'    'DWord' 0
Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'    'DisableSearchBoxSuggestions' 'DWord' 1

# ============================================================================
# 7. Feedback prompts / typing data harvesting
# ============================================================================
Set-Reg 'HKCU:\Software\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' 'DWord' 0
Set-Reg 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitInkCollection'  'DWord' 1
Set-Reg 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitTextCollection' 'DWord' 1
Set-Reg 'HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore' 'HarvestContacts' 'DWord' 0

# ============================================================================
# 8. Location consent (per-user)
# ============================================================================
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' 'Value' 'String' 'Deny'

# ============================================================================
# 9. SCOOBE upsell / MSA nudges (HKCU-side)
# ============================================================================
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' 'ScoobeSystemSettingEnabled' 'DWord' 0

# ============================================================================
# 10. Performance tweaks
# ============================================================================
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'StartupDelayInMSec' 'DWord' 0
Set-Reg 'HKCU:\Control Panel\Desktop' 'MenuShowDelay' 'String' '0'

# ============================================================================
# 11. Office telemetry / connected experiences
# ============================================================================
Set-Reg 'HKCU:\Software\Policies\Microsoft\Office\16.0\Common\Privacy'    'DisconnectedState' 'DWord' 2
Set-Reg 'HKCU:\Software\Policies\Microsoft\Office\Common\ClientTelemetry' 'DisableTelemetry'  'DWord' 1

# ============================================================================
# 12. Restart Explorer so taskbar changes apply immediately
# ============================================================================
try {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
        Start-Process explorer.exe
    }
} catch {}

Write-Output "=== Tidy11 user-context pass complete (failures: $failures) ==="
if ($failures -gt 0) { exit 1 } else { exit 0 }

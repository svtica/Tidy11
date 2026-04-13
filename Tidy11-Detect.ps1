<#
.SYNOPSIS
    Tidy11-Detect.ps1 — Intune Proactive Remediation detection script.

.DESCRIPTION
    Non-interactive read-only check. Returns exit 0 if baseline is compliant
    (no remediation needed), exit 1 if drift is detected (triggers remediation).

    Deployed via: Intune admin center -> Devices -> Scripts and remediations ->
                  Create script package -> Detection script file.

.NOTES
    Author:  svtica
    License: GPL-3.0-or-later
    Project: https://github.com/svtica/Tidy11

    Runs as SYSTEM. No user interaction. Keep this FAST (<5 sec target).
    Tests a representative subset of policy keys — if the key is wrong,
    the baseline has drifted and remediation will re-apply everything.
#>

$ErrorActionPreference = 'SilentlyContinue'

function Test-RegValue {
    param([string]$Path,[string]$Name,$Expected)
    try {
        if (!(Test-Path $Path)) { return $false }
        $v = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop | Select-Object -ExpandProperty $Name
        return ([string]$v -eq [string]$Expected)
    } catch { return $false }
}

# Representative canary keys — one per major category.
# If any drift, remediation script re-applies everything.
$checks = @(
    # Copilot
    @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'; N='TurnOffWindowsCopilot'; V=1; Cat='Copilot' }
    # Recall / WindowsAI
    @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; N='DisableAIDataAnalysis'; V=1; Cat='Recall' }
    # Telemetry
    @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; N='AllowTelemetry'; V=0; Cat='Telemetry' }  # checked loosely below
    # Ads / Spotlight
    @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; N='DisableWindowsSpotlightFeatures'; V=1; Cat='Ads' }
    # Advertising ID
    @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo'; N='DisabledByGroupPolicy'; V=1; Cat='Advertising' }
    # Activity feed
    @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; N='EnableActivityFeed'; V=0; Cat='Activity' }
    # Location
    @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors'; N='DisableLocation'; V=1; Cat='Location' }
    # Widgets
    @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Dsh'; N='AllowNewsAndInterests'; V=0; Cat='Widgets' }
    # Web search
    @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; N='DisableWebSearch'; V=1; Cat='WebSearch' }
    # Search suggestions
    @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; N='DisableSearchBoxSuggestions'; V=1; Cat='SearchSuggest' }
    # Office Copilot master policy
    @{ P='HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common\copilot'; N='disablecopilot'; V=1; Cat='OfficeCopilot' }
    # Game DVR
    @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'; N='AllowGameDVR'; V=0; Cat='GameDVR' }
    # Edge Copilot sidebar
    @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Edge'; N='HubsSidebarEnabled'; V=0; Cat='EdgeCopilot' }
    # WER
    @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting'; N='Disabled'; V=1; Cat='WER' }
)

$drift = @()
foreach ($c in $checks) {
    # Telemetry is special — edition-dependent. Accept any value <=2 (Enhanced or lower).
    if ($c.Cat -eq 'Telemetry') {
        try {
            $v = (Get-ItemProperty -Path $c.P -Name $c.N -ErrorAction Stop).$($c.N)
            if ($null -eq $v -or [int]$v -gt 2) { $drift += $c.Cat }
        } catch { $drift += $c.Cat }
        continue
    }
    if (-not (Test-RegValue -Path $c.P -Name $c.N -Expected $c.V)) {
        $drift += $c.Cat
    }
}

# Service canary
try {
    $ds = Get-Service -Name DiagTrack -ErrorAction Stop
    if ($ds.StartType -ne 'Disabled') { $drift += 'DiagTrackSvc' }
} catch { $drift += 'DiagTrackSvc-missing' }

if ($drift.Count -gt 0) {
    Write-Output "DRIFT: $($drift -join ',')"
    exit 1  # non-zero = triggers remediation
}

Write-Output 'COMPLIANT'
exit 0

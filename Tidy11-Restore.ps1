<#
.SYNOPSIS
    Tidy11-Restore.ps1 - standalone snapshot restoration.

.DESCRIPTION
    Self-contained, no module dependency. Reads a Tidy11 snapshot folder
    and rolls back registry, services, scheduled tasks, and firewall rules
    to their pre-change state.

.PARAMETER SnapshotPath
    Path to a Tidy11-Snapshot_yyyyMMdd_HHmmss folder containing manifest.json.
    If omitted, offers an interactive picker.

.EXAMPLE
    .\Tidy11-Restore.ps1 -SnapshotPath C:\Users\me\Documents\Tidy11-Snapshots\Tidy11-Snapshot_20260412_143022

.EXAMPLE
    .\Tidy11-Restore.ps1
    # Opens a folder picker dialog

.NOTES
    Author:  svtica
    License: GPL-3.0-or-later
    Project: https://github.com/svtica/Tidy11
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$SnapshotPath
)

# -------------------- elevation --------------------
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
          ).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    $argList = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"")
    if ($SnapshotPath) { $argList += @('-SnapshotPath', "`"$SnapshotPath`"") }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $argList
    exit
}

function Write-OK   { param($m) Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Info { param($m) Write-Host "[INFO] $m" -ForegroundColor Cyan  }
function Write-FAIL { param($m) Write-Host "[FAIL] $m" -ForegroundColor Red   }
function Write-Warn { param($m) Write-Host "[WARN] $m" -ForegroundColor Yellow }

# -------------------- snapshot picker if not given --------------------
if (-not $SnapshotPath) {
    Add-Type -AssemblyName System.Windows.Forms
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Select a Tidy11 snapshot folder (must contain manifest.json)'
    $defaultDir = Join-Path $env:USERPROFILE 'Documents\Tidy11-Snapshots'
    if (Test-Path $defaultDir) { $dlg.SelectedPath = $defaultDir }
    if ($dlg.ShowDialog() -ne 'OK') {
        Write-Info 'Cancelled.'
        exit 0
    }
    $SnapshotPath = $dlg.SelectedPath
}

if (-not (Test-Path $SnapshotPath)) {
    Write-FAIL "Snapshot folder not found: $SnapshotPath"
    exit 1
}

$manifestFile = Join-Path $SnapshotPath 'manifest.json'
if (-not (Test-Path $manifestFile)) {
    Write-FAIL "No manifest.json in $SnapshotPath - does not look like a Tidy11 snapshot."
    exit 1
}

$manifest = Get-Content $manifestFile -Raw | ConvertFrom-Json
Write-Info "Restoring Tidy11 snapshot"
Write-Info "  Created : $($manifest.created)"
Write-Info "  Host    : $($manifest.hostname)"
Write-Info "  User    : $($manifest.user)"
Write-Info "  Edition : $($manifest.edition)"
Write-Info "  Build   : $($manifest.windowsBuild)"

if ($manifest.hostname -ne $env:COMPUTERNAME) {
    Write-Warn "Snapshot was taken on '$($manifest.hostname)' but you're on '$env:COMPUTERNAME'."
    Write-Warn 'Registry paths should still apply, but verify the result.'
}

$resp = Read-Host 'Proceed with restore? (y/N)'
if ($resp -notmatch '^[yY]') { Write-Info 'Cancelled.'; exit 0 }

# -------------------- restore registry --------------------
Write-Info '--- Step 1: reimport captured registry trees ---'
$regFiles = Get-ChildItem -Path $SnapshotPath -Filter '*.reg' -ErrorAction SilentlyContinue
foreach ($f in $regFiles) {
    try {
        reg.exe import $f.FullName 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-OK "Imported: $($f.Name)"
        } else {
            Write-FAIL "Import exit $LASTEXITCODE : $($f.Name)"
        }
    } catch {
        Write-FAIL "Import error $($f.Name) : $($_.Exception.Message)"
    }
}

# -------------------- delete net-new values Tidy11 created -----------------
Write-Info '--- Step 2: delete net-new values recorded by Tidy11 ---'
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
        Write-OK "Deleted $count net-new registry values"
    } catch {
        Write-Warn "created-values.json parse error: $($_.Exception.Message)"
    }
} else {
    Write-Info 'No created-values.json in snapshot (older snapshot, nothing to delete).'
}

# -------------------- chain Tidy11-Revert.reg if present --------------------
$revertReg = Join-Path $PSScriptRoot 'Tidy11-Revert.reg'
if ($PSScriptRoot -and (Test-Path $revertReg)) {
    Write-Info '--- Step 3: applying Tidy11-Revert.reg (static policy cleanup) ---'
    try {
        reg.exe import $revertReg 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-OK 'Tidy11-Revert.reg applied'
        } else {
            Write-Warn "Tidy11-Revert.reg import exit $LASTEXITCODE"
        }
    } catch {
        Write-Warn "Tidy11-Revert.reg import failed: $($_.Exception.Message)"
    }
} else {
    Write-Info 'Tidy11-Revert.reg not found next to this script (skipping belt-and-suspenders cleanup).'
}

# -------------------- restore services --------------------
Write-Info '--- Step 4: restoring services ---'
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
                Write-OK "Service: $($s.Name) -> $($s.StartType)"
            }
        } catch {
            Write-FAIL "Service $($s.Name) : $($_.Exception.Message)"
        }
    }
} else {
    Write-Warn 'No services.json in snapshot'
}

# -------------------- restore scheduled tasks --------------------
Write-Info '--- Step 5: restoring scheduled tasks ---'
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
} else {
    Write-Warn 'No tasks.json in snapshot'
}

# -------------------- differential firewall restore ------------------------
Write-Info '--- Step 6: differential firewall rule cleanup ---'
$fwFile = Join-Path $SnapshotPath 'firewall.json'
$preExisting = @()
if (Test-Path $fwFile) {
    try {
        $fwData = Get-Content $fwFile -Raw | ConvertFrom-Json
        if ($fwData) { $preExisting = @($fwData | ForEach-Object { $_.DisplayName }) }
    } catch {}
}
$rules = Get-NetFirewallRule -DisplayName 'PrivacyBlock-*' -ErrorAction SilentlyContinue
if ($rules) {
    foreach ($r in $rules) {
        if ($preExisting -contains $r.DisplayName) {
            Write-Info "Kept (pre-existing): $($r.DisplayName)"
        } else {
            try {
                Remove-NetFirewallRule -DisplayName $r.DisplayName -ErrorAction Stop
                Write-OK "Removed: $($r.DisplayName)"
            } catch {}
        }
    }
} else {
    Write-Info 'No PrivacyBlock-* rules found.'
}

# -------------------- restore hosts file ----------------------------------
$hostsBackup = Join-Path $SnapshotPath 'hosts.backup'
if (Test-Path $hostsBackup) {
    Write-Info '--- Step 7: restoring hosts file ---'
    try {
        $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
        Copy-Item -Path $hostsBackup -Destination $hostsPath -Force -ErrorAction Stop
        Write-OK 'hosts file restored'
    } catch {
        Write-FAIL "hosts restore failed: $($_.Exception.Message)"
    }
}

Write-Host ''
Write-OK 'Restore complete. Reboot strongly recommended.'

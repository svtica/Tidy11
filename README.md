# Tidy11

**Disable Copilot, Recall, telemetry, ads, and bloat on Windows 11 and Microsoft 365. Fully offline. GUI + Intune + GPO with snapshot rollback.**

[![License: GPL v3](https://img.shields.io/badge/license-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Windows 11](https://img.shields.io/badge/Windows-11-0078D6?logo=windows11&logoColor=white)](https://www.microsoft.com/windows/windows-11)
[![Fully Offline](https://img.shields.io/badge/runtime-fully%20offline-success)](#)
[![Lint PowerShell](https://github.com/svtica/Tidy11/actions/workflows/lint.yml/badge.svg)](https://github.com/svtica/Tidy11/actions/workflows/lint.yml)

Tidy11 is a fully offline, single-folder toolkit for taking back control of a Windows 11 machine or fleet. It ships as an interactive WPF GUI for single machines, an Intune Proactive Remediation pair for managed fleets, and static `.reg` baselines for GPO — all driven by the same tested logic.

No runtime network dependency. No telemetry of its own. No code you can't read.

**Topics:** `windows-11` · `privacy` · `cleanup` · `copilot` · `recall` · `telemetry` · `intune` · `gpo` · `powershell` · `wpf` · `microsoft-365` · `ai-removal` · `windows-hardening`

---

## Features

- **Copilot / AI removal**: Windows Copilot, Recall, Click To Do, Paint AI, Edge Copilot, Office Copilot, Notepad AI, Voice Access, generative-AI app privacy gates.
- **Privacy**: telemetry (DiagTrack + scheduled tasks + FQDN firewall blocks), advertising ID, activity history, location, tailored experiences, feedback prompts, typing data harvesting.
- **System cleanup**: Widgets, Bing/Cortana in Start, Xbox services (optional), Game DVR (optional), classic Win10 context menu, taskbar cleanup, Edge first-run, Office telemetry.
- **Classic apps**: four installation methods for replacing removed Win11 apps (Winget, Microsoft-native, Source Redist Online, Source Redist Local) with per-app choice.
- **Two rollback layers** before any change:
  - Windows System Restore point (enabled automatically if disabled).
  - Tidy11's own snapshot with registry exports, services, scheduled tasks, firewall rules, `hosts` backup, and a net-new-value log for clean deletion.
- **Config recipes**: save your exact checkbox selection as JSON and replay on another machine.
- **Verification mode**: read-only 16-check audit to see what a Windows feature update re-enabled.
- **Edition-aware**: telemetry minimum values auto-adjust for Home / Pro / Enterprise.

---

## Quickstart (single machine)

1. Download or clone this repository.
2. Right-click `Tidy11.ps1` → **Run with PowerShell**. It auto-elevates via UAC.
3. Pick a preset (**SAFE** is the recommended default), or tick individual checkboxes.
4. Leave both safety options ticked (default):
   - ☑ Create Windows System Restore point
   - ☑ Create Tidy11 snapshot BEFORE applying changes
5. Click **DISABLE Selected**. Reboot when done.

If anything goes wrong, you have three independent rollback paths:

| If … | Use … |
|---|---|
| The machine still boots, GUI still opens | GUI → **Restore from Snapshot…** |
| The GUI is broken but PowerShell works | `.\Tidy11-Restore.ps1` (standalone, no module needed) |
| The machine won't boot properly | Recovery environment → **System Restore** → pick the Tidy11 pre-change checkpoint |

---

## Files in this pack

| File | Purpose | Run as |
|---|---|---|
| `Tidy11.ps1` | Interactive WPF GUI for single-machine use | Admin (auto-elevates) |
| `Tidy11.Modules.psm1` | PowerShell module with all apply/revert/verify/snapshot/config functions | Loaded by the GUI |
| `Tidy11-Restore.ps1` | Standalone snapshot restorer — no module dependency | Admin (auto-elevates) |
| `Tidy11-Detect.ps1` | Intune Proactive Remediation detection script | SYSTEM |
| `Tidy11-Remediate.ps1` | Intune Proactive Remediation remediation script (self-contained) | SYSTEM |
| `Tidy11-User.ps1` | Intune user-context companion — HKCU keys for existing profiles | Logged-on user |
| `Tidy11.reg` | Static registry baseline for GPO Preferences / offline import | Admin |
| `Tidy11-Revert.reg` | Reverse of `Tidy11.reg` — deletes the policy values to restore defaults | Admin |
| `Tidy11-Changes-Reference.md` | Per-setting reference (paths, default values, proposed values, risk class) | Documentation |
| `LICENSE` | The Unlicense | — |

---

## Requirements

- Windows 11 (all editions). Windows 10 also works for the PS1 side; some Copilot-specific keys are no-ops.
- **Windows PowerShell 5.1** (`powershell.exe`). The WPF GUI requires the `PresentationFramework` assembly stack that is only available in classic PowerShell — `pwsh` 7+ will refuse to launch with a clear error.
- Administrator rights (the scripts auto-elevate).

No internet required at runtime. All AI/Copilot/telemetry logic is native in the module file.

---

## Scenario 1 — Single machine (your own PC)

Covered by the Quickstart above. A few extras worth knowing:

- **Save Config Recipe…** → export your exact selections as `tidy11-recipe.json` for later reuse or cross-machine replication.
- **Verify (read-only)** → runs a 16-check audit without touching anything. Handy after a Windows feature update to see what Microsoft re-enabled.
- **Restore from Snapshot…** → pick any snapshot folder, confirm, done. The restore does everything in the right order: re-imports registry exports, deletes net-new values Tidy11 created, auto-chains `Tidy11-Revert.reg` if present, restores services/tasks/firewall differentially, and restores the `hosts` file.

---

## Scenario 2 — Small fleet via GPO (on-prem AD, no Intune)

Use `Tidy11.reg` as the static baseline.

### Option A — Direct registry import

```powershell
reg.exe import \\fileserver\share\Tidy11.reg
```

Wrap that in a startup script GPO (**Computer Configuration → Windows Settings → Scripts → Startup**).

### Option B — GPO Preferences (recommended, reversible)

1. Open Group Policy Management → edit a GPO linked to the target OU.
2. **Computer Configuration → Preferences → Windows Settings → Registry**.
3. Right-click → **New → Registry Wizard** → Local Computer → browse to any key from `Tidy11.reg` → import → set action to **Replace**.

GPO Preferences let you unscope/remove keys cleanly by flipping the GPO to "Delete" mode, unlike a raw `.reg` import.

### What `.reg` does NOT cover

The `.reg` is only static key data. For full coverage you also need service stops, task disables, Appx removal, and firewall rules. Deploy `Tidy11-Remediate.ps1` as a startup script alongside it:

```cmd
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "\\fileserver\share\Tidy11-Remediate.ps1"
```

---

## Scenario 3 — Intune (recommended for managed fleets)

Use **Scripts and remediations** (formerly Proactive Remediations). This is the durable answer because Windows feature updates silently re-enable things — the scheduled remediation puts them back.

### Setup

1. Intune admin center → **Devices → Scripts and remediations → Create script package**.
2. **Name**: `Tidy11 — AI & Privacy Baseline`
3. **Detection script file**: upload `Tidy11-Detect.ps1`
4. **Remediation script file**: upload `Tidy11-Remediate.ps1`
5. **Run this script using the logged-on credentials**: **No** (run as SYSTEM)
6. **Enforce script signature check**: **No** (unless you sign them with your code signing cert)
7. **Run script in 64-bit PowerShell**: **Yes**
8. Assign to your device group.
9. **Schedule**: Daily at 03:00 is a reasonable default.

### User-context companion

SYSTEM-context scripts cannot write HKCU for existing user profiles. Deploy `Tidy11-User.ps1` as a separate **Platform script** (Devices → Scripts → Add → Windows 10 and later):

- **Run this script using the logged-on credentials**: **Yes**
- **Enforce script signature check**: No
- **Run script in 64-bit PowerShell**: Yes
- Assign to a **user group**, not a device group.

This covers: taskbar alignment, Start Recommended, Notepad AI, per-app Office Copilot toggles, Bing/Cortana, ContentDeliveryManager, InputPersonalization, Office telemetry, location consent, perf tweaks.

### Why not a Settings Catalog profile?

Most of what Tidy11 touches (Paint AI, File Explorer Ask Copilot, Notepad AI, Edge Copilot flags, Game DVR policy, Widgets, Office Copilot master toggle, Cortana/Bing) is not exposed as a Settings Catalog definition. The catalog only covers keys Microsoft has wrapped in an MDM CSP. A hybrid works — Settings Catalog for Telemetry/Copilot/Widgets/AppPrivacy, Tidy11 for the rest — but the Tidy11 pair alone is simpler and covers everything.

---

## Scenario 4 — Imaging / MDT / Autopilot

Bake it in at first-run:

```powershell
# In your Autopilot/MDT deployment script, after OOBE completes:
Invoke-WebRequest -Uri 'https://yourshare/Tidy11-Remediate.ps1' -OutFile "$env:TEMP\wn.ps1"
& "$env:TEMP\wn.ps1"
```

Or drop `Tidy11.reg` into your reference image's `FirstLogonCommands` via unattend.xml.

---

## What Tidy11 removes or disables

Items are grouped by category. Full per-setting reference with registry paths and default values is in [`Tidy11-Changes-Reference.md`](Tidy11-Changes-Reference.md).

| Category | Targets |
|---|---|
| **Windows Copilot** | `TurnOffWindowsCopilot` policy, Copilot Appx package (optional), taskbar button, hardware Copilot key, AppPrivacy generative-AI access |
| **Recall / WindowsAI** | `DisableAIDataAnalysis`, `AllowRecallEnablement=0`, Click To Do, Settings Agent, Agent Connectors/Workspaces |
| **Paint AI** | Cocreator, Generative Fill/Erase, Image Creator, Remove Background |
| **Edge** | Copilot sidebar, Compose inline, AI themes, History AI search, startup boost, background mode |
| **Office Copilot** | HKLM master policy + per-user Word/Excel/PPT/OneNote/Outlook toggles + Outlook BusinessChat add-in |
| **Notepad AI** | `CopilotEnabled`, `AIFeaturesEnabled`, `ShowAIFeatures` |
| **Telemetry** | DiagTrack service, dmwappushservice, 6 scheduled task paths, outbound FQDN firewall blocks (v10.events, settings-win, vortex-win), `AllowTelemetry`, Advertising ID, Windows Error Reporting |
| **Ads / Recommendations** | Windows Spotlight, Consumer features, SoftLanding, 20+ ContentDeliveryManager keys, Start Recommended section |
| **MSA nudges** (optional) | `NoConnectedUser`, `DisableMSA`, `DisableUserAuth`, SCOOBE upsell |
| **Activity / Location** | `EnableActivityFeed`, `PublishUserActivities`, `lfsvc`, `DisableLocation` |
| **Widgets** | `AllowNewsAndInterests=0`, `TaskbarDa=0` |
| **Classic context menu** | HKCU CLSID shell extension block (restores Win10 right-click menu) |
| **Web Search** | `BingSearchEnabled`, `CortanaConsent`, `DisableWebSearch`, `ConnectedSearchUseWeb`, `DisableSearchBoxSuggestions` |
| **Taskbar** | Left-align, hide Task View / Chat / People / Meet Now / Start Recommended |
| **Xbox services** (optional) | `XblAuthManager`, `XblGameSave`, `XboxNetApiSvc`, `XboxGipSvc`, `RetailDemo` |
| **Game DVR** (optional) | `AppCaptureEnabled`, `GameDVR_Enabled`, `AutoGameModeEnabled`, `AllowGameDVR` policy |
| **Performance** | `StartupDelayInMSec=0`, `MenuShowDelay=0` |

Items marked *(optional)* are unticked by default in the GUI.

---

## Safety model

Three independent rollback layers:

1. **Windows System Restore point** — created automatically at the start of every DISABLE pass. If System Restore is disabled on the system drive, Tidy11 enables it (including fixing zero shadow-copy quota on fresh Win11 installs). Bypasses the 24-hour throttle for one-off creation and restores the previous throttle setting afterwards. Rollback via `rstrui.exe` or recovery environment.
2. **Tidy11 snapshot** — timestamped folder in `%USERPROFILE%\Documents\Tidy11-Snapshots\` containing:
   - `manifest.json` — hostname, user, Windows build/edition, ISO timestamp
   - Registry exports of every policy tree Tidy11 might touch
   - `services.json` — StartType + Status of all relevant services before changes
   - `tasks.json` — State of telemetry/CEIP/Autochk/etc. scheduled tasks
   - `firewall.json` — pre-existing `PrivacyBlock-*` rules (for differential restore)
   - `hosts.backup` — copy of `C:\Windows\System32\drivers\etc\hosts`
   - `created-values.json` — list of net-new registry values Tidy11 created (so restore can delete them cleanly; plain `.reg import` can't delete values)
   - `run.log` — full session log
3. **Static revert** — `Tidy11-Revert.reg` deletes every policy value the machine-side baseline sets.

Restore runs in the right order: reimport captured registry → delete net-new values → apply `Tidy11-Revert.reg` if present → restore services/tasks → differential firewall cleanup → restore `hosts`.

### Caveats

- **Tamper Protection** must be off for any policy changes under the Defender tree (Tidy11 does not touch Defender cloud by default — but other tools may).
- **Home edition**: approximately 40% of HKLM policies are silently ignored. The telemetry minimum function falls back to `Enhanced (2)` on Home. HKCU settings still apply.
- **Windows feature updates** periodically re-enable things. That's exactly why the Intune path exists — redeploy on a daily schedule and it self-heals.
- **`XboxGipSvc` disable** can break non-Xbox USB/Bluetooth gamepads because it handles generic HID gamepad input. Leave it off unless you're sure.
- **MSA strict block (value=3)** can prevent users from signing into Store/Xbox/Teams personal. Test first.
- **Paint / Notepad AI keys**: recent builds store prefs in a WinAppSDK `settings.dat` instead of registry. The registry keys are best-effort; the in-app toggle is the reliable fallback.
- **Appx removal is irreversible** by the snapshot system. The GUI shows a second confirmation dialog before running it.

---

## Config Recipes + Snapshots (portable setup)

Tidy11 treats your checkbox selections as a **recipe** you can save, copy to another machine, and reapply.

### Workflow: clone your setup to another PC

1. On machine A, configure the GUI (pick a preset, tick/untick, choose a Classic Apps method). Click **Save Config Recipe…** — you get a `tidy11-recipe.json` file.
2. Copy the whole Tidy11 pack + your `tidy11-recipe.json` to machine B.
3. On machine B, launch `Tidy11.ps1`. Click **Load Config Recipe…** and pick the JSON. Every checkbox and radio button snaps to match machine A.
4. Leave both safety options ticked. Click **DISABLE Selected**.

### Standalone restore (GUI broken or module missing)

```powershell
.\Tidy11-Restore.ps1                                            # Interactive folder picker
.\Tidy11-Restore.ps1 -SnapshotPath 'C:\Users\me\Documents\Tidy11-Snapshots\Tidy11-Snapshot_20260412_143022'
```

`Tidy11-Restore.ps1` is fully self-contained — it only needs the snapshot folder, no module, no other files.

---

## Classic App Replacements (4 methods)

The GUI has a dedicated section with 5 radio buttons — pick one method, then tick the apps you want.

| Method | What it does | Legal posture | Offline? |
|---|---|---|---|
| **Skip** | Default. Does nothing. | — | ✅ |
| **Winget alternatives** | Installs Notepad++, Paint.NET, ShareX, IrfanView via winget. | ✅ Clean — Microsoft's own distribution | ✅ (once winget is present) |
| **Native** | Classic Notepad via `Add-WindowsCapability` FoD, restores Win11's built-in Photo Viewer via registry, installs Photos Legacy from the Store. Paint and Snipping Tool skipped — no legit Microsoft source. | ✅ Clean — all Microsoft-sourced | ✅ |
| **Source Redist Online** | Live-fetches `zoicware/RemoveWindowsAI` (the upstream redistribution source) and runs its `-InstallClassicApps` mode. Redistributes Microsoft binaries. | ⚠️ Gray — Microsoft copyrights redistributed by a third party | ❌ (needs internet) |
| **Source Redist Local** | Same, but fully offline — requires pre-staged `RemoveWindowsAi.ps1` + `ClassicApps/` folder next to `Tidy11.ps1`. Fails fast if missing. | ⚠️ Gray — same concern, you host the files | ✅ (after staging) |

Recommendation for enterprise: **Winget** or **Native**. Source Redist methods are for personal machines where you specifically want muscle-memory-identical classic binaries.

---

## Reverting

- **GUI**: tick the same boxes you applied, click **REVERT Selected**.
- **Restore from Snapshot…**: full rollback including net-new value cleanup and hosts restore.
- **Standalone**: `.\Tidy11-Restore.ps1` (see above).
- **Static revert** (GPO/Intune): push `Tidy11-Revert.reg` as a one-shot script or a GPO Preferences Registry item with Action: Delete.
- **Classic apps**: the GUI's revert pass does NOT uninstall apps you installed via the Classic Apps section. Remove them manually via Settings → Apps, `winget uninstall <id>`, or `Remove-WindowsCapability` for the FoD Notepad.

---

## Credits

Tidy11 is a derivative work that ports, merges, and extends logic from three open-source projects. Credit and thanks to the original authors:

- [**sevsec/windows-11-privacy**](https://github.com/sevsec/windows-11-privacy) — **GPL-3.0**. Origin of the helper functions (`Set-Reg`, `Remove-RegValue`, service/task helpers, FQDN/hosts-block pattern, `Invoke-Safely` wrapper) and the telemetry / ads / Microsoft Account / activity-location modules. Tidy11 inherits its license from this project.
- [**zoicware/RemoveWindowsAI**](https://github.com/zoicware/RemoveWindowsAI) — MIT. Origin of the AI/Copilot/Recall registry research now in `Invoke-CopilotNative` and the optional classic-apps install path.
- [**bRootForceSec/Win11-Debloat-And-Privacy**](https://github.com/bRootForceSec/Win11-Debloat-And-Privacy) — MIT. Origin of the cleanup / performance / Edge / Office-telemetry tweaks.

New material original to Tidy11: the WPF GUI, the Intune script trio (`Tidy11-Detect.ps1` / `Tidy11-Remediate.ps1` / `Tidy11-User.ps1`), the standalone `Tidy11-Restore.ps1`, the differential firewall and net-new-value tracking in the snapshot system, the hosts file backup, the Windows System Restore integration, the config recipe save/load, the Office/Notepad Copilot wrappers, the four-method classic-apps installer, the static `.reg` baselines, and the per-setting reference documentation.

---

## License

Tidy11 is released under the **GNU General Public License v3.0 or later**. See [`LICENSE`](LICENSE) for the full text.

This license is inherited from `sevsec/windows-11-privacy`, whose code Tidy11 derives from. GPL-3.0 is a copyleft license: you are free to use, study, modify, and redistribute Tidy11 (including for commercial purposes), but any redistribution — including derivative works — must also be made available under GPL-3.0 and must include source code.

In short: use it, change it, share it, build on it. Just don't lock it up.

---

## Author

**svtica** — [https://github.com/svtica/Tidy11](https://github.com/svtica/Tidy11)

Issues and pull requests welcome.

# Tidy11 — Changes Reference & Safety Classification

Reference document for every change Tidy11 can apply, with default Windows values, proposed values, risk class, and reversibility notes.

## Risk legend

| Symbol | Class | Meaning |
|---|---|---|
| 🟢 | **SAFE** | Cosmetic / privacy / fully reversible via snapshot or `.reg` revert. No security impact. |
| 🟡 | **MODERATE** | Reversible, but may break legitimate features the user relies on (sync, gamepads, Store apps, location-aware apps). |
| 🔴 | **DANGEROUS** | Reduces security posture, irreversible, or interacts with components that resist rollback. Read the notes before enabling. |

Reversibility column:
- **Snapshot ✅** — captured by `New-Tidy11Snapshot` and restorable via `Tidy11-Restore.ps1`.
- **Snapshot ⚠** — partially captured (see notes — `reg import` only restores values that already existed, not new ones Tidy11 created).
- **Snapshot ❌** — not captured. Manual revert only.

---

## 1. Windows Copilot / AI / Recall (`Invoke-CopilotNative`)

GUI: *Copilot / AI — Windows OS* group.

| Setting | Reg path | Value (Win default → Tidy11) | Risk | Reversible |
|---|---|---|---|---|
| Windows Copilot policy | `HKLM\…\Policies\Microsoft\Windows\WindowsCopilot!TurnOffWindowsCopilot` | (absent) → `1` | 🟢 | Snapshot ⚠ |
| Windows Copilot policy (HKCU) | `HKCU\…\Policies\Microsoft\Windows\WindowsCopilot!TurnOffWindowsCopilot` | (absent) → `1` | 🟢 | Snapshot ⚠ |
| Recall data analysis | `…\WindowsAI!DisableAIDataAnalysis` (HKLM+HKCU) | (absent) → `1` | 🟢 | Snapshot ⚠ |
| Recall enablement | `…\WindowsAI!AllowRecallEnablement` | (absent) → `0` | 🟢 | Snapshot ⚠ |
| Click To Do | `…\WindowsAI!DisableClickToDo` | (absent) → `1` | 🟢 | Snapshot ⚠ |
| Recall snapshots | `…\WindowsAI!TurnOffSavingSnapshots` | (absent) → `1` | 🟢 | Snapshot ⚠ |
| Settings Agent | `…\WindowsAI!DisableSettingsAgent` | (absent) → `1` | 🟢 | Snapshot ⚠ |
| Agent Connectors / Workspaces / Remote | `…\WindowsAI!Disable*` | (absent) → `1` | 🟢 | Snapshot ⚠ |
| App privacy: GenAI | `…\AppPrivacy!LetAppsAccessGenerativeAI` | (absent / 1 Allow) → `2` (Deny) | 🟢 | Snapshot ⚠ |
| App privacy: System AI models | `…\AppPrivacy!LetAppsAccessSystemAIModels` | (absent / 1) → `2` (Deny) | 🟢 | Snapshot ⚠ |
| Taskbar Copilot button | `HKCU\…\Explorer\Advanced!ShowCopilotButton` | `1` → `0` | 🟢 | Snapshot ✅ |
| Taskbar Companion | `HKCU\…\Explorer\Advanced!TaskbarCompanion` | `1` → `0` | 🟢 | Snapshot ✅ |
| Copilot PWA pin | `HKCU\…\Taskband\AuxilliaryPins!CopilotPWAPin` | `1` → `0` | 🟢 | Snapshot ⚠ |
| Recall pin | `HKCU\…\Taskband\AuxilliaryPins!RecallPin` | `1` → `0` | 🟢 | Snapshot ⚠ |
| Hardware Copilot key type | `HKCU\…\Shell\BrandedKey!BrandedKeyChoiceType` | `App` → `Search` | 🟢 | Snapshot ⚠ |
| Hardware Copilot key AUMID | `HKCU\…\Shell\BrandedKey!AppAumid` | `Microsoft.Copilot_…!App` → ` ` (space) | 🟢 | Snapshot ⚠ |
| Copilot hardware key policy | `HKCU\…\Policies\…\CopilotKey!SetCopilotHardwareKey` | (absent) → ` ` | 🟢 | Snapshot ⚠ |
| Ask Copilot in Explorer (block) | `HKCU\…\Shell Extensions\Blocked!{CB3B0003-…}` | (absent) → `Ask Copilot` | 🟢 | Snapshot ⚠ |
| Copilot/OfficeHub background apps | `HKCU\…\BackgroundAccessApplications\…!Disabled*` | (absent) → `1` | 🟢 | Snapshot ⚠ |
| Settings home Copilot ads | `…\CloudContent!DisableConsumerAccountStateContent` | (absent) → `1` | 🟢 | Snapshot ⚠ |
| Voice Access running state | `HKCU\…\VoiceAccess!RunningState` | `1` → `0` | 🟢 | Snapshot ⚠ |
| Ink/text harvesting | `HKCU\…\InputPersonalization!RestrictImplicit*Collection` | (absent / 0) → `1` | 🟢 | Snapshot ⚠ |
| Typing insights | `HKCU\…\input\Settings!InsightsEnabled` | `1` → `0` | 🟢 | Snapshot ⚠ |
| **Feature Management velocity overrides** | `HKLM\SYSTEM\ControlSet001\Control\FeatureManagement\Overrides\8\<id>!EnabledState` | (absent) → `1` | 🟡 | Snapshot ✅ |
| Gaming Copilot block | `HKLM\SOFTWARE\Microsoft\WindowsRuntime\…\GamingCompanionHostOptions` | enabled → `ActivationType=0`, `Server=` | 🟢 | Snapshot ⚠ |

**Notes**
- Velocity-ID writes target `ControlSet001` directly instead of `CurrentControlSet`. On 99% of installs they're the same key; on machines where the active control set is different (rare boot-from-clone scenarios), the change is dormant.
- Feature management overrides are the mechanism Microsoft uses to flight features in/out — these are 🟡 because Microsoft can change which IDs map to what at any cumulative update. Not dangerous, but may need refreshing.

---

## 2. AI Appx package removal (`Invoke-AIAppxRemoval`)

GUI: *Remove Copilot/Recall Appx packages* (unticked by default).

| Action | Target | Risk | Reversible |
|---|---|---|---|
| Remove `Microsoft.Copilot*` (per-user + provisioned) | Appx | 🔴 | Snapshot ❌ |
| Remove `Microsoft.Windows.Ai.Copilot.Provider*` | Appx | 🔴 | Snapshot ❌ |
| Remove `MicrosoftWindows.Client.Recall*` | Appx | 🔴 | Snapshot ❌ |
| Remove `Microsoft.MicrosoftOfficeHub*` | Appx | 🔴 | Snapshot ❌ |

🔴 **This is irreversible.** The snapshot system does not capture Appx state. To restore, the user must reinstall from the Microsoft Store (`9NHT9RB2F4HD` for Copilot) — and some packages may not be available in the Store after removal of provisioned versions.

---

## 3. App-side AI (Paint / Photos / Edge / Office / Notepad)

GUI: *Copilot / AI — Apps*.

| Setting | Reg path | Default → Tidy11 | Risk | Reversible |
|---|---|---|---|---|
| Paint AI features | `HKLM\…\Policies\Paint!Disable*` (5 keys) | (absent) → `1` | 🟢 | Snapshot ⚠ |
| Edge Copilot sidebar | `HKLM\…\Policies\Edge!HubsSidebarEnabled` | (absent / 1) → `0` | 🟢 | Snapshot ✅ |
| Edge Compose / AI search / themes / etc. | `HKLM\…\Policies\Edge!*` (9 keys) | (absent) → `0` | 🟢 | Snapshot ✅ |
| Office Copilot master | `HKLM\…\Policies\…\office\16.0\common\copilot!disablecopilot` | (absent) → `1` | 🟢 | Snapshot ✅ |
| Word/Excel/PPT/OneNote/Outlook Copilot | `HKCU\…\Office\16.0\<App>\Copilot!Enabled` | `1` → `0` | 🟢 | Snapshot ⚠ |
| Outlook BusinessChat add-in | `HKCU\…\Outlook\Addins\…BusinessChat.Addin!LoadBehavior` | `3` → `0` | 🟢 | Snapshot ⚠ |
| Notepad AI | `HKCU\Software\Microsoft\Notepad!CopilotEnabled` etc. (3 keys) | `1` → `0` | 🟢 | Snapshot ✅ |

---

## 4. Telemetry (`Invoke-Telemetry`)

GUI: *Telemetry (DiagTrack, tasks, firewall blocks)*.

| Setting | Default → Tidy11 | Risk | Reversible |
|---|---|---|---|
| `…\DataCollection!AllowTelemetry` | `1` (Pro) → `0` Sec / `1` Pro / `2` Home (edition-aware) | 🟢 | Snapshot ✅ |
| `…\DataCollection!AllowDeviceNameInTelemetry` | `1` → `0` | 🟢 | Snapshot ✅ |
| Service `DiagTrack` | `Automatic` running → `Disabled` stopped | 🟢 | Snapshot ✅ |
| Service `dmwappushservice` | `Manual` → `Disabled` | 🟢 | Snapshot ✅ |
| Scheduled tasks under `\Microsoft\Windows\Application Experience\`, `\Autochk\`, `\Customer Experience Improvement Program\`, `\DiskDiagnostic\`, `\Feedback\Siuf\`, `\Windows Error Reporting\` | Enabled → Disabled | 🟢 | Snapshot ✅ |
| Outbound firewall block: `v10.events.data.microsoft.com`, `settings-win.data.microsoft.com`, `vortex-win.data.microsoft.com` | (no rule) → `PrivacyBlock-<fqdn>` | 🟢 | Snapshot ⚠ (see issue #1 below) |
| WER policy | (absent) → `Disabled=1` | 🟢 | Snapshot ⚠ |
| Advertising ID | `…\AdvertisingInfo!DisabledByGroupPolicy` (absent) → `1` | 🟢 | Snapshot ⚠ |
| App launch tracking | `…\Explorer\Advanced!Start_TrackProgs` `1` → `0` | 🟢 | Snapshot ✅ |
| Feedback request frequency | `HKCU\Software\Microsoft\Siuf\Rules!NumberOfSIUFInPeriod` (absent) → `0` | 🟢 | Snapshot ⚠ |
| Tailored experiences | `HKCU\…\CloudContent!DisableTailoredExperiencesWithDiagnosticData` (absent) → `1` | 🟢 | Snapshot ⚠ |

---

## 5. Ads / Recommendations (`Invoke-AdsRecommendations`)

| Setting | Default → Tidy11 | Risk | Reversible |
|---|---|---|---|
| `HKLM\…\CloudContent` 6-key block (Spotlight, ConsumerFeatures, SoftLanding, etc.) | (absent) → `1` | 🟢 | Snapshot ⚠ |
| ContentDeliveryManager 21 keys (HKCU) | `1` → `0` | 🟢 | Snapshot ✅ |
| `Start_IrisRecommendations` | `1` → `0` | 🟢 | Snapshot ✅ |

---

## 6. Microsoft Account block (`Invoke-MicrosoftAccount`)

GUI: *Block Microsoft Account nudges* + *Strict MSA block*.

| Setting | Default → Tidy11 | Risk | Reversible |
|---|---|---|---|
| `…\Policies\System!NoConnectedUser` | `0` → `1` (basic) / `3` (strict) | 🟡 / 🔴 strict | Snapshot ⚠ |
| `…\Policies\Microsoft\MicrosoftAccount!DisableUserAuth` | (absent) → `1` | 🟡 | Snapshot ⚠ |
| `…\Policies\Microsoft\MicrosoftAccount!DisableMSA` | (absent) → `1` | 🟡 | Snapshot ⚠ |
| `…\UserProfileEngagement!ScoobeSystemSettingEnabled` | `1` → `0` | 🟢 | Snapshot ⚠ |

🔴 **Strict mode (value=3)** can prevent users from signing in to Microsoft Store, Xbox app, Teams personal, and OneDrive personal. Test on one machine first.

---

## 7. ~~Defender Cloud~~ — REMOVED

This feature was removed from Tidy11 to keep the tool safe in any environment. Disabling cloud-delivered protection weakens malware defense and has been dropped entirely. Tamper Protection concerns also made this unreliable. If you need it, use Intune Attack Surface Reduction policies or a Defender Management Pack instead.

---

## 8. Activity / Location (`Invoke-ActivityLocation`)

| Setting | Default → Tidy11 | Risk | Reversible |
|---|---|---|---|
| `…\System!EnableActivityFeed` / `PublishUserActivities` / `UploadUserActivities` | (absent) → `0` | 🟢 | Snapshot ⚠ |
| `…\LocationAndSensors!DisableLocation` | (absent) → `1` | 🟡 (breaks Weather, Maps, Find My Device, time-zone auto-set) | Snapshot ⚠ |
| Per-user location consent | `Allow` → `Deny` | 🟡 | Snapshot ✅ |
| Service `lfsvc` | `Manual` → `Disabled` | 🟡 | Snapshot ✅ |

---

## 9. Xbox services (`Invoke-XboxServices`) 🟡

| Service | Default → Tidy11 |
|---|---|
| `XblAuthManager`, `XblGameSave`, `XboxNetApiSvc`, `RetailDemo` | `Manual` → `Disabled` |
| `XboxGipSvc` | `Manual` → `Disabled` |

🟡 **`XboxGipSvc` handles generic HID gamepad input.** Disabling it can break non-Xbox USB/Bluetooth controllers (Logitech, 8BitDo, generic). Reversible via snapshot.

---

## 10. Game DVR (`Invoke-GameDVR`) 🟢

`HKCU\…\GameDVR`, `HKCU\System\GameConfigStore`, `HKCU\…\GameBar` — all set to `0`. Plus `HKLM\…\Policies\…\GameDVR!AllowGameDVR=0`. Fully reversible.

---

## 11. Widgets (`Invoke-Widgets`) 🟢

`HKLM\…\Dsh!AllowNewsAndInterests=0`, `HKCU\…\Explorer\Advanced!TaskbarDa=0`. Reversible.

---

## 12. Classic context menu (`Invoke-ClassicContextMenu`) 🟢

Creates `HKCU\Software\Classes\CLSID\{86ca1aa0-…}\InprocServer32` with empty default value. Reversible by deleting the key (the revert path does this correctly).

---

## 13. Web Search / Cortana / Bing (`Invoke-WebSearch`) 🟢

Disables Bing Search, Cortana consent, web search policy, search-box suggestions in HKLM and HKCU. Fully reversible.

---

## 14. ~~OneDrive~~ — REMOVED

This feature was removed from Tidy11 to avoid breaking active sync for users who rely on OneDrive. If you need to disable OneDrive for a specific machine, do it through Settings → Apps → Uninstall or via a targeted Group Policy. The HKCR Explorer namespace edits that this feature relied on also made it hard to fully roll back via snapshot.

---

## 15. Taskbar tweaks (`Invoke-TaskbarTweaks`) 🟢

11 HKCU values: alignment, Task View, search box mode, Recent docs, Recommended section, Meet Now, People, Chat. All reversible.

---

## 16. ~~WU auto-restart suppression~~ — REMOVED

This feature was removed from Tidy11 to keep security patches applying on schedule. Delaying reboots means machines stay on unpatched kernels, which is not an acceptable trade-off for the comfort gain. If you need to delay restarts for a narrow maintenance window, use the standard Active Hours settings in Windows Settings → Update & Security.

---

## 17. Performance tweaks (`Invoke-PerformanceTweaks`) 🟢

`StartupDelayInMSec=0`, `MenuShowDelay=0`. Reversible.

---

## 18. Edge debloat (`Invoke-EdgeDebloat`) 🟢

`HideFirstRunExperience=1`, `StartupBoostEnabled=0`, `BackgroundModeEnabled=0`. Reversible.

---

## 19. Office telemetry (`Invoke-OfficeTelemetry`) 🟢

`HKCU\…\Office\16.0\Common\Privacy!DisconnectedState=2`, `…\Office\Common\ClientTelemetry!DisableTelemetry=1`. Reversible.

---

## 20. Classic App Replacements (`Invoke-ClassicApps`)

| Method | Risk | Notes |
|---|---|---|
| **Skip** | 🟢 | Default. No-op. |
| **Winget alternatives** | 🟢 | Installs Notepad++, Paint.NET, ShareX, IrfanView. Cleanest path. |
| **Native** | 🟢 | Microsoft FoD for Notepad, registry restore for Photo Viewer, Store install for Photos Legacy. No Paint/Snipping. |
| **Zoicware Online** | 🟡 | Downloads zoicware/RemoveWindowsAI from GitHub at runtime — redistributes Microsoft binaries (gray legal zone) and adds an internet dependency. |
| **Zoicware Local** | 🟡 | Same legal posture; **also currently downloads `zoicware-classic-runner.ps1` from GitHub** (see issue #5). |

**Revert is manual** for all installation methods — Tidy11's REVERT button does NOT uninstall apps it installed.

---

# Audit findings (post-hardening)

## Elevation & UAC ✅
Unchanged — both `Tidy11.ps1` and `Tidy11-Restore.ps1` correctly check `WindowsBuiltInRole::Administrator`, re-launch via `Start-Process -Verb RunAs`, forward arguments, enforce PS 5.1, and confirm destructive actions via `MessageBox`.

## Backup / snapshot system — gaps closed

### ✅ Gap #1 — `reg import` can't delete net-new values → FIXED
`Set-Reg` now probes for pre-existence and records any net-new `(Path, Name)` pair into `$script:CreatedValues`. `Save-CreatedValuesLog` persists this as `created-values.json` alongside the snapshot. On restore, both the GUI `Restore-Tidy11Snapshot` and the standalone `Tidy11-Restore.ps1` read this file and `Remove-ItemProperty` each entry — cleanly removing values that didn't exist before Tidy11 ran. As belt-and-suspenders, `Tidy11-Revert.reg` is auto-imported after the snapshot restore if present next to the tool.

### ✅ Gap #2 — Firewall restore is destructive, not differential → FIXED
Both the module and the standalone restore now load `firewall.json` from the snapshot and only delete `PrivacyBlock-*` rules whose `DisplayName` is NOT in the pre-existing list. Rules that predate the snapshot are logged and kept.

### ✅ Gap #3 — Hosts file not snapshotted → FIXED
`New-Tidy11Snapshot` now copies `C:\Windows\System32\drivers\etc\hosts` to `hosts.backup` inside the snapshot folder. Both restore paths copy it back if present. This covers the `Add-BlockDomain` hosts fallback on systems without `New-NetFirewallRule -RemoteFqdn` support.

### ✅ Gap #4 — HKCR edits not snapshotted → OBSOLETE
The only HKCR writes came from `Invoke-OneDrive`, which has been removed. No HKCR edits remain in the codebase.

### ✅ Gap #5 — `ZoicwareLocal` wasn't actually offline → FIXED
The Local mode no longer calls `Invoke-WebRequest`. It now checks for a pre-staged `RemoveWindowsAi.ps1` next to the Tidy11 scripts plus the `ClassicApps\` folder. If either is missing, it fails fast with a clear error message and download URL — the user stages manually, no runtime network required.

### ✅ Gap #6 — Appx removal is irreversible and not gated → FIXED
`Tidy11.ps1` now shows a second confirmation dialog *specifically* for `cbAppx` before any other DISABLE processing. If the user declines, the checkbox is cleared and the DISABLE pass is aborted with an info dialog. The main DISABLE confirmation then follows normally.

### ✅ Gap #7 — No persistent log file → FIXED
`New-Tidy11Snapshot` now calls `Set-LogFile` pointing at `run.log` inside the snapshot folder. Every `Write-Log` call — including errors during the disable pass — is appended to that file. Post-mortem debugging no longer depends on the GUI window staying open.

### ✅ Gap #8 — Velocity IDs hardcoded `ControlSet001` → FIXED
All Feature Management velocity writes now use `HKLM:\SYSTEM\CurrentControlSet\Control\FeatureManagement\Overrides\8\<id>` so they always land on the active control set.

## Features removed
- 🔴 `Invoke-OneDrive` / `cbOneDrive` — removed from module, GUI, `Tidy11.reg`, `Tidy11-Revert.reg`, `Tidy11-Remediate.ps1`, `Tidy11-Detect.ps1`, and `Invoke-Verification`.
- 🔴 `Invoke-DefenderCloud` / `cbDefender` — removed from module and GUI. Was already commented out in the static `.reg` files and the Intune remediation script.
- 🔴 `Invoke-UpdateRestart` / `cbUpdateRestart` — removed from module and GUI. Was already commented out in the static `.reg` files and the Intune remediation script.

## Remaining risk classifications

🟡 **Moderate** (still in the tool, reversible but disruptive):
- `cbActLoc` — disables global Location (breaks Weather/Maps/time zone auto-set)
- `cbXbox` — XboxGipSvc disable can break generic HID gamepads
- `cbMSA` basic — blocks adding Microsoft accounts
- `cbMSAStrict` — value=3 can prevent Store/Xbox/Teams personal sign-in (clearly labeled)
- `cbAppx` — now gated by second confirmation, irreversible by design
- Feature-Management velocity overrides — may drift across Windows builds (cosmetic drift, not security)

🟢 **Safe** — everything else.

## Known remaining gaps (acceptable)

1. **Appx removal is still irreversible by snapshot** — by design. The second confirmation dialog makes this explicit. There is no technically clean way to capture provisioned Appx state that survives a Windows feature update.
2. **`ContentDeliveryManager` subscribed-content IDs may refresh** with new Windows builds. The existing list covers current IDs; future ones will need to be added by hand. Non-blocking.
3. **README.md still describes the removed features** in its "What gets killed" table and caveats section. Update manually when you get a chance — the functional code is correct regardless.

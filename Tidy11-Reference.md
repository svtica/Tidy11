# Tidy11 — Settings Reference

Reference for every change Tidy11 can apply: default Windows values, applied values, risk class, and reversibility.

## Risk legend

| Symbol | Class | Meaning |
|---|---|---|
| 🟢 | **SAFE** | Cosmetic / privacy / fully reversible via snapshot or `.reg` revert. No security impact. |
| 🟡 | **MODERATE** | Reversible, but may break legitimate features (sync, gamepads, Store apps, location-aware apps). |
| 🔴 | **DANGEROUS** | Reduces security posture, irreversible, or interacts with components that resist rollback. |

Reversibility:
- **Snapshot ✅** — captured by `New-Tidy11Snapshot`, restorable via `Tidy11-Restore.ps1`.
- **Snapshot ⚠** — partially captured (`reg import` only restores pre-existing values; net-new values are tracked separately in `created-values.json`).
- **Snapshot ❌** — not captured. Manual revert only.

---

## 1. Windows Copilot / AI / Recall (`Invoke-CopilotNative`)

GUI: *Copilot / AI — Windows OS*

| Setting | Reg path | Value (Win default → Tidy11) | Risk | Reversible |
|---|---|---|---|---|
| Windows Copilot policy (HKLM + HKCU) | `…\Policies\Microsoft\Windows\WindowsCopilot!TurnOffWindowsCopilot` | (absent) → `1` | 🟢 | Snapshot ⚠ |
| Recall data analysis (HKLM + HKCU) | `…\WindowsAI!DisableAIDataAnalysis` | (absent) → `1` | 🟢 | Snapshot ⚠ |
| Recall enablement | `…\WindowsAI!AllowRecallEnablement` | (absent) → `0` | 🟢 | Snapshot ⚠ |
| Click To Do | `…\WindowsAI!DisableClickToDo` | (absent) → `1` | 🟢 | Snapshot ⚠ |
| Recall snapshots | `…\WindowsAI!TurnOffSavingSnapshots` | (absent) → `1` | 🟢 | Snapshot ⚠ |
| Settings Agent / Connectors / Workspaces | `…\WindowsAI!Disable*` | (absent) → `1` | 🟢 | Snapshot ⚠ |
| App privacy: GenAI models | `…\AppPrivacy!LetAppsAccessGenerativeAI` | (absent / 1) → `2` (Deny) | 🟢 | Snapshot ⚠ |
| App privacy: System AI models | `…\AppPrivacy!LetAppsAccessSystemAIModels` | (absent / 1) → `2` (Deny) | 🟢 | Snapshot ⚠ |
| Taskbar Copilot button | `HKCU\…\Explorer\Advanced!ShowCopilotButton` | `1` → `0` | 🟢 | Snapshot ✅ |
| Taskbar Companion | `HKCU\…\Explorer\Advanced!TaskbarCompanion` | `1` → `0` | 🟢 | Snapshot ✅ |
| Copilot / Recall taskbar pins | `HKCU\…\Taskband\AuxilliaryPins!CopilotPWAPin / RecallPin` | `1` → `0` | 🟢 | Snapshot ⚠ |
| Hardware Copilot key | `HKCU\…\Shell\BrandedKey!BrandedKeyChoiceType / AppAumid` | `App / Copilot AUMID` → `Search / (space)` | 🟢 | Snapshot ⚠ |
| Ask Copilot in Explorer (block) | `HKCU\…\Shell Extensions\Blocked!{CB3B0003-…}` | (absent) → `Ask Copilot` | 🟢 | Snapshot ⚠ |
| Copilot/OfficeHub background apps | `HKCU\…\BackgroundAccessApplications\…!Disabled*` | (absent) → `1` | 🟢 | Snapshot ⚠ |
| Settings home Copilot ads | `…\CloudContent!DisableConsumerAccountStateContent` | (absent) → `1` | 🟢 | Snapshot ⚠ |
| Voice Access running state | `HKCU\…\VoiceAccess!RunningState` | `1` → `0` | 🟢 | Snapshot ⚠ |
| Ink/text harvesting | `HKCU\…\InputPersonalization!RestrictImplicit*Collection` | (absent / 0) → `1` | 🟢 | Snapshot ⚠ |
| Typing insights | `HKCU\…\input\Settings!InsightsEnabled` | `1` → `0` | 🟢 | Snapshot ⚠ |
| Feature Management velocity overrides | `HKLM\SYSTEM\CurrentControlSet\Control\FeatureManagement\Overrides\8\<id>!EnabledState` | (absent) → `1` | 🟡 | Snapshot ✅ |
| Gaming Copilot block | `HKLM\…\GamingCompanionHostOptions` | enabled → `ActivationType=0` | 🟢 | Snapshot ⚠ |

> **Note — velocity IDs:** Microsoft uses these to flight features; IDs may shift across cumulative updates. Not dangerous, but may need refreshing after a major Windows update.

---

## 2. AI Appx package removal (`Invoke-AIAppxRemoval`)

GUI: *Remove Copilot/Recall Appx packages* — **unticked by default, gated by a second confirmation dialog.**

| Action | Risk | Reversible |
|---|---|---|
| Remove `Microsoft.Copilot*` (per-user + provisioned) | 🔴 | Snapshot ❌ |
| Remove `Microsoft.Windows.Ai.Copilot.Provider*` | 🔴 | Snapshot ❌ |
| Remove `MicrosoftWindows.Client.Recall*` | 🔴 | Snapshot ❌ |
| Remove `Microsoft.MicrosoftOfficeHub*` | 🔴 | Snapshot ❌ |

🔴 **Irreversible.** Restore requires reinstalling from the Microsoft Store (Store ID `9NHT9RB2F4HD` for Copilot).

---

## 3. App-side AI — Paint / Photos / Edge / Office / Notepad

GUI: *Copilot / AI — Apps*

| Setting | Reg path | Default → Tidy11 | Risk | Reversible |
|---|---|---|---|---|
| Paint AI (5 keys) | `HKLM\…\Policies\Paint!Disable*` | (absent) → `1` | 🟢 | Snapshot ⚠ |
| Edge Copilot sidebar | `HKLM\…\Policies\Edge!HubsSidebarEnabled` | (absent / 1) → `0` | 🟢 | Snapshot ✅ |
| Edge AI features (8 keys) | `HKLM\…\Policies\Edge!CopilotPageContext / EdgeHistoryAISearchEnabled / ComposeInlineEnabled / BuiltInAIAPIsEnabled / AIGenThemesEnabled / ShareBrowsingHistoryWithCopilotSearchAllowed / Microsoft365CopilotChatIconEnabled / EdgeEntraCopilotPageContext` | (absent) → `0` | 🟢 | Snapshot ✅ |
| Office Copilot master | `HKLM\…\office\16.0\common\copilot!disablecopilot` | (absent) → `1` | 🟢 | Snapshot ✅ |
| Word / Excel / PPT / OneNote / Outlook Copilot | `HKCU\…\Office\16.0\<App>\Copilot!Enabled` | `1` → `0` | 🟢 | Snapshot ⚠ |
| Outlook BusinessChat add-in | `HKCU\…\Outlook\Addins\…BusinessChat.Addin!LoadBehavior` | `3` → `0` | 🟢 | Snapshot ⚠ |
| Notepad AI (3 keys) | `HKCU\Software\Microsoft\Notepad!CopilotEnabled` etc. | `1` → `0` | 🟢 | Snapshot ✅ |

---

## 4. Telemetry (`Invoke-Telemetry`)

GUI: *Telemetry (DiagTrack, tasks, firewall blocks)*

| Setting | Default → Tidy11 | Risk | Reversible |
|---|---|---|---|
| `…\DataCollection!AllowTelemetry` | `1` (Pro) → `0` Sec / `1` Pro / `2` Home (edition-aware) | 🟢 | Snapshot ✅ |
| `…\DataCollection!AllowDeviceNameInTelemetry` | `1` → `0` | 🟢 | Snapshot ✅ |
| Service `DiagTrack` | `Automatic` running → `Disabled` stopped | 🟢 | Snapshot ✅ |
| Service `dmwappushservice` | `Manual` → `Disabled` | 🟢 | Snapshot ✅ |
| Scheduled tasks (Application Experience, Autochk, CEIP, DiskDiagnostic, Feedback\Siuf, WER) | Enabled → Disabled | 🟢 | Snapshot ✅ |
| Outbound firewall blocks (3 FQDNs) | (no rule) → `PrivacyBlock-<fqdn>` | 🟢 | Snapshot ⚠ |
| WER policy | (absent) → `Disabled=1` | 🟢 | Snapshot ⚠ |
| Advertising ID | `…\AdvertisingInfo!DisabledByGroupPolicy` (absent) → `1` | 🟢 | Snapshot ⚠ |
| App launch tracking | `…\Explorer\Advanced!Start_TrackProgs` `1` → `0` | 🟢 | Snapshot ✅ |
| Feedback frequency | `HKCU\…\Siuf\Rules!NumberOfSIUFInPeriod` (absent) → `0` | 🟢 | Snapshot ⚠ |
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

GUI: *Block Microsoft Account nudges* + *Strict MSA block*
**Both checkboxes are opt-in (unticked by default). The FULL preset does NOT tick them — enterprise tenants may require Microsoft Accounts for Store, Teams, and Intune sign-in. Tick manually if needed.**

| Setting | Default → Tidy11 | Risk | Reversible |
|---|---|---|---|
| `…\Policies\System!NoConnectedUser` | `0` → `1` (basic) / `3` (strict) | 🟡 / 🔴 strict | Snapshot ⚠ |
| `…\Policies\Microsoft\MicrosoftAccount!DisableUserAuth` | (absent) → `1` | 🟡 | Snapshot ⚠ |
| `…\Policies\Microsoft\MicrosoftAccount!DisableMSA` | (absent) → `1` | 🟡 | Snapshot ⚠ |
| `…\UserProfileEngagement!ScoobeSystemSettingEnabled` | `1` → `0` | 🟢 | Snapshot ⚠ |

🔴 **Strict mode (value=3)** can prevent sign-in to Microsoft Store, Xbox app, Teams personal, and OneDrive personal.

---

## 7. Activity / Location (`Invoke-ActivityLocation`)

| Setting | Default → Tidy11 | Risk | Reversible |
|---|---|---|---|
| `…\System!EnableActivityFeed / PublishUserActivities / UploadUserActivities` | (absent) → `0` | 🟢 | Snapshot ⚠ |
| `…\LocationAndSensors!DisableLocation` | (absent) → `1` | 🟡 (breaks Weather, Maps, Find My Device, time-zone auto) | Snapshot ⚠ |
| Per-user location consent | `Allow` → `Deny` | 🟡 | Snapshot ✅ |
| Service `lfsvc` | `Manual` → `Disabled` | 🟡 | Snapshot ✅ |

---

## 8. Xbox services (`Invoke-XboxServices`) 🟡

| Service | Default → Tidy11 |
|---|---|
| `XblAuthManager`, `XblGameSave`, `XboxNetApiSvc`, `RetailDemo` | `Manual` → `Disabled` |
| `XboxGipSvc` | `Manual` → `Disabled` |

🟡 **`XboxGipSvc` handles generic HID gamepad input.** May break non-Xbox USB/Bluetooth controllers.

---

## 9. Game DVR (`Invoke-GameDVR`) 🟢

`HKCU\…\GameDVR`, `HKCU\System\GameConfigStore`, `HKCU\…\GameBar` — all set to `0`. Plus `HKLM\…\Policies\…\GameDVR!AllowGameDVR=0`. Fully reversible.

---

## 10. Widgets (`Invoke-Widgets`) 🟢

`HKLM\…\Dsh!AllowNewsAndInterests=0`, `HKCU\…\Explorer\Advanced!TaskbarDa=0`. Fully reversible.

---

## 11. Classic context menu (`Invoke-ClassicContextMenu`) 🟢

Creates `HKCU\Software\Classes\CLSID\{86ca1aa0-…}\InprocServer32` with empty default. Revert deletes the key.

---

## 12. Web Search / Cortana / Bing (`Invoke-WebSearch`) 🟢

Disables Bing Search, Cortana consent, web search policy, search-box suggestions (HKLM + HKCU). Fully reversible.

---

## 13. Taskbar tweaks (`Invoke-TaskbarTweaks`) 🟢

11 HKCU values: alignment, Task View, search box mode, Recent docs, Recommended section, Meet Now, People, Chat. All reversible.

---

## 14. Performance tweaks (`Invoke-PerformanceTweaks`) 🟢

`StartupDelayInMSec=0`, `MenuShowDelay=0`. Fully reversible.

---

## 15. Edge cleanup (`Invoke-EdgeDebloat`) 🟢

`HideFirstRunExperience=1`, `StartupBoostEnabled=0`, `BackgroundModeEnabled=0`. Fully reversible.

---

## 16. Office telemetry (`Invoke-OfficeTelemetry`) 🟢

`HKCU\…\Office\16.0\Common\Privacy!DisconnectedState=2`, `…\Office\Common\ClientTelemetry!DisableTelemetry=1`. Fully reversible.

---

## 17. Classic App Replacements (`Invoke-ClassicApps`)

**Revert is manual** — the REVERT button does NOT uninstall apps Tidy11 installed.

| Method | Risk | Notes |
|---|---|---|
| **Skip** | 🟢 | Default. No-op. |
| **Winget** | 🟢 | Installs Notepad++, Paint.NET, ShareX, IrfanView. Cleanest legal path. |
| **Native** | 🟢 | Classic Notepad (FoD), Photo Viewer (registry restore), Photos Legacy (Store). For Paint/Snipping: installs the modern UWP Microsoft Store builds (`9PCFS5B6T72H` / `9MZ95KL8MR0L`) — **not** the classic Win32 binaries. Use Source Redist if you need the classic ones. |
| **Source Redist Online** | 🟡 | Fetches `zoicware/RemoveWindowsAI` at runtime and runs `-InstallClassicApps` once per selected app. Redistributes Microsoft binaries (gray legal zone). Needs internet. |
| **Source Redist Local** | 🟡 | Same legal posture, fully offline — requires pre-staged `RemoveWindowsAi.ps1` + `ClassicApps/` folder next to `Tidy11.ps1`. Fails fast if missing. |

Recommendation for enterprise: **Winget** or **Native**. Source Redist methods are for personal machines where you specifically want classic Win10 binaries.

---

## Risk summary

🟡 **Moderate** — reversible but potentially disruptive:
- `cbActLoc` — disables global Location (breaks Weather / Maps / time-zone auto-set)
- `cbXbox` — `XboxGipSvc` disable can break generic HID gamepads
- `cbMSA` basic — blocks adding Microsoft accounts (opt-in only)
- `cbMSAStrict` — value=3 can prevent Store / Xbox / Teams personal sign-in (opt-in only, clearly labeled)
- `cbAppx` — irreversible Appx removal, gated by second confirmation dialog
- Feature-Management velocity overrides — may drift across Windows builds (cosmetic, not security)

🟢 **Safe** — everything else.

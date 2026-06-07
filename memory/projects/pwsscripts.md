# Project: pwsscripts

## Overview
Personal collection of PowerShell utility scripts for Azure, Intune, and Windows device management. Not a structured app — a toolbox of standalone and reusable scripts.

- **Repo**: `~/code/pwsscripts` (local, likely GitHub)
- **Language**: PowerShell
- **Tenant used**: ZM (dev/test, config-zm-*)

## Categories of Scripts

### Azure / Graph API
- `graph.ps1`, `graphtest.ps1`, `test-graph.ps1` — Graph API exploration/testing
- `GetGraphObjectMetadata.ps1` — inspect Graph objects
- `Graph1.ps1`, `get groups with batch example.ps1` — batch API calls
- `AZExtensions.ps1` — Azure VM extensions

### Intune / Device Management
- `GetDeviceConfigsByGroup.ps1`, `GetDeviceConfigurationAssignments.ps1` — config assignments
- `GetAssignedItems.ps1` — items assigned to devices/users
- `getCorpDeviceInfo.ps1` — corporate device info
- `DeviceDirSync.ps1`, `DeviceDirSync-v1.ps1` — device directory sync
- `Get-AutopilotJSONProfiles.ps1` — Autopilot profile export

### Windows / Endpoint Remediation (likely Intune remediations)
- `EnableJAWSAutoStart2023/2024/2025/2026.ps1` — JAWS screen reader auto-start by year
- `EnableNarratorAutoStart.ps1` — Windows Narrator auto-start
- `Enable-WHP.ps1` — Windows Hello / provisioning
- `Enable-SmartCardRemovalService.ps1` — smart card lock behavior
- `Disable-DisplayAutoRotation.ps1` — screen rotation
- `Enable/Disable-ZscalerStrictEnforcement.ps1` — Zscaler network enforcement
- `lockComputerDetectionAndRemediation.ps1` — lock screen remediation
- `remediate-shutdown.ps1`, `remediate4store.ps1`, `remediate4teams.ps1` — various remediations
- `FixWindowsUpdates.ps1` — Windows Update repair
- `Check4Bitlocker.ps1`, `turnoff-Bitlocker.ps1` — BitLocker management
- `Enable_TLSv2.ps1` — TLS configuration

### Groups & Users
- `groups.ps1`, `GroupMembers.ps1`, `groups.ps1` — group management
- `get-TeamChatMembers.ps1` — Teams membership
- `ObjectTreversal.ps1` — object graph traversal

### Dev / Build Tools
- `CreateRelease.ps1`, `CreateRelease_legacy.ps1` — release builds (shared with Autopilot project)
- `sign.ps1`, `sign-script.ps1` — code signing
- `CopyDependencyFiles.ps1`, `zip-modules.ps1` — build helpers
- `ClaudePluginInstaller.ps1` — deploys Claude plugins to end-user machines

### Accessibility
- `EnableJAWSAutoStart*.ps1` — JAWS (screen reader) auto-start scripts (yearly versions)
- `EnableNarratorAutoStart.ps1` — Windows Narrator

### AVD (Azure Virtual Desktop)
- `AVD/avd.ps1`, `AVD/vca.ps1`, `AVD/DTA.ps1` — AVD management scripts

### Utility / Misc
- `LogViewer.ps1` — log file viewer
- `GetLogs.ps1` — log retrieval
- `GenerateFileHash.ps1` — file integrity
- `Find-ProductCode.ps1` — MSI product code lookup
- `makeJSON.ps1` — JSON generation helpers
- `ConnectMe.ps1` — Graph API connection helper
- `installVSCode.ps1`, `Get-VSCodeExtensions.ps1` — VS Code management
- `InstallAutocad.ps1` — AutoCAD deployment

## Recurring Work Patterns
- **JAWS scripts are updated every year** — accessibility is an ongoing responsibility, not a one-off
- **Claude plugin deployment** — Zuhair deploys Claude to end-user machines via Intune/PowerShell

## Notes
- Contains a `functions/` subdirectory with shared functions (setupFunctions, utilityFunctions, etc.) — appears to be extracted/shared code from the Autopilot project
- Uses ZM tenant config (config-zm-*)
- JAWS scripts versioned by year — suggests ongoing accessibility support work
- Zscaler scripts suggest managed network enforcement environment

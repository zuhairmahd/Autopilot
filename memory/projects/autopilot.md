# Project: Autopilot

## Overview
Windows Autopilot Management Tool — PowerShell-based tool for IT admins and help desk to manage Windows Autopilot device enrollment via Microsoft Intune.

- **Repo**: `zuhairmahd/autopilot` (GitHub)
- **Version**: 1.3.0.0
- **License**: MIT
- **Language**: PowerShell (5.1 compatible; tests require PS7+)

## Related Projects
- **pwsscripts** (`~/code/pwsscripts`) — companion script toolbox; shares some functions with this project

## Tenants
| Alias | What |
|-------|------|
| ZM | Dev/test tenant (config-zm-*) |
| GAO | Day job tenant / Access to Jobs (config-GAO-*) |

## What it does
Interactive, menu-driven CLI app for IT staff to:
- Assign devices to users (with readiness checks)
- Check device enrollment status
- Import devices into Autopilot
- Manage Autopilot profiles
- Generate & export device reports

## Architecture
- **Entry**: `main.ps1` → dot-sources all 208 functions from `functions/`
- **Config**: `settings.psd1` (global + domain-specific), `menu.psd1`, `strings.psd1`
- **Auth**: Azure AD app registrations (ZM = dev, GAO = day job), client credentials or delegated
- **API**: Microsoft Graph API via `CallGraphAPI`
- **Cache**: Multi-layer (15 min for Graph/directory, 60 min for config)
- **Navigation**: Stack-based menu system (`$global:MenuHistory`)

## Function Categories (208 total)
| Category | Count | Purpose |
|----------|-------|---------|
| setupFunctions | 45 | Init, config, settings, first-run wizard |
| menuFunctions | 27 | Menu system, navigation, display |
| graphFunctions | 26 | Microsoft Graph API |
| utilityFunctions | 26 | Logging, caching, validation |
| UserAndGroupFunctions | 22 | User/group resolution & assignments |
| autopilotFunctions | 16 | Autopilot device management |
| deviceFunctions | 16 | Device operations & enrollment |
| reportingFunctions | 14 | Reports & data export |
| encryptionFunctions | 11 | Encryption & secure config |
| updateFunctions | 5 | Version checking & updates |

## Tests
- **Framework**: Pester v5
- **Run**: `pwsh.exe -ExecutionPolicy Bypass -File .\Invoke-PesterTests.ps1 -TestType Unit`
- **Structure**: `tests/Unit/` (73), `tests/Integration/` (14), `tests/Comprehensive/` (8)
- **Helpers**: `AutopilotTestHelpers.psm1`, `AutopilotGraphMocks.psm1`, `AutopilotMenuMocks.psm1`

## Dev Commands
```powershell
.\main.ps1 -Verbose -LogLevel "Debug"
pwsh.exe -ExecutionPolicy Bypass -File .\Invoke-PesterTests.ps1 -TestType Unit -outputVerbosity Detailed
.\CreateRelease.ps1 -Stage Build
```

## Coding Standards
- ASCII-only output (no Unicode/emoji)
- 4-space indent, ~120-char lines
- PascalCase functions, camelCase variables
- Every function: `$functionName = $MyInvocation.MyCommand.Name` + `Write-Log` entry/exit
- 100% test pass rate before committing

## Recent Activity (as of 2026-04-23)
- Last commit: "Removed agentic workflows"
- Recent work: OS service release extraction refactor, PIV test simplification, settings/integration test updates

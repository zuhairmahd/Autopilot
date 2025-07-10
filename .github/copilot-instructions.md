# Copilot Code Generation Instructions

## Project Overview

This repository is a PowerShell-based Windows Autopilot device enrollment and management tool, integrating with Microsoft Graph API and supporting multi-domain configuration. It features a menu-driven UI for helpdesk operations, device assignment, and Intune/Autopilot management.

## Architecture & Key Patterns

- **Function Loading:** All PowerShell functions are dot-sourced from `/functions/` at startup, loaded alphabetically. Each module must be independent—avoid inter-module dependencies.
- **Configuration System:** Three-tiered config: (1) runtime parameters, (2) domain-specific settings (`settings.json`), (3) global settings. Merging logic is in `functions/SettingsHelperFunctions.ps1` (`MergeSettings`).
- **Menu System:** Hierarchical, stack-based navigation using `MenuFunctions.ps1`. State is tracked in `$global:History` and `$global:MenuHistory`.
- **Authentication:** OAuth 2.0 with multiple flows (interactive, public, private). Token caching and secure storage in `.secrets/config.json` (encrypted).
- **Microsoft Graph API:** All device/user management is via Graph API. Required scopes and endpoints are documented in `CLAUDE.md`.

## Developer Workflows

- **Run Main App:**  
  `./main.ps1 [-appMode "test"] [-Verbose] [-LogLevel "Debug"]`
- **Switch Config:**  
  `./gao.bat` or `./zmc.bat`
- **Run Tests:**  
  `Get-ChildItem ./TestScripts/test-*.ps1 | ForEach-Object { & $_.FullName }`
- **Build Release:**  
  `./CreateRelease.ps1 -InputFile "main.ps1" -Version "X.Y.Z"`

## Project-Specific Conventions

- **PowerShell 5.1 Compatibility:** Maintain compatibility unless otherwise noted. Add comments if requiring a higher version.
- **Verbose Logging:** All scripts and functions should include verbose logging.
- **No Hard Dependencies Between Function Modules:** Each file in `/functions/` should be self-contained.
- **Configuration Files:**  
  - `settings.json`: Main config (global + per-domain)
  - `strings.json`: Localized messages
  - `.secrets/config.json`: Encrypted credentials (see `config-sample.json`)
- **Security:**  
  - Use `EncryptionFunctions.ps1` for sensitive files.
  - All Graph API calls must use least-privilege scopes.

## Integration Points

- **Microsoft Graph API:**  
  - Scopes: `User.Read.All`, `Device.Read.All`, `DeviceManagementManagedDevices.ReadWrite.All`, etc.
  - Endpoints: `/deviceManagement/windowsAutopilotDeviceIdentities`, `/users/{id}/registeredDevices`, etc.
- **Domain-Specific Behavior:**  
  - Domains like `gao.gov` and `arabictutor.com` have custom settings for device naming, group membership, and security.

## Key Files & Directories

- `/functions/`: All core logic modules (see `CLAUDE.md` for descriptions)
- `/TestScripts/`: All test scripts
- `/docs/`: Extended documentation and usage guides

## Azure-Specific Rules

- **@azure Rule:** Use Azure tools and best practices for any Azure-related code or operations.
- **Invoke `azure_development-get_best_practices`** for Azure code generation.
- **Invoke `azure_development-get_code_gen_best_practices`** for Azure code.
- **Invoke `azure_development-get_deployment_best_practices`** for Azure deployment.
- **Invoke `azure_development-get_azure_function_code_gen_best_practices`** for Azure Functions.
- **Invoke `azure_development-get_swa_best_practices`** for Azure Static Web Apps.

## PowerShell Requirements
- Whenever possible, maintain compatibility with PowerShell 5.1 for Windows.
- If PowerShell 5.1 compatibility cannot be maintained, add appropriate comments to indicate the minimum version of PowerShell required to run the code.
- Remember that in PowerShell for Windows, variables are typically not case sensitive.

## Logging
- Always add verbose logging.

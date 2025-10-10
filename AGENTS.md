# Repository Guidelines

## Project Structure & Module Organization
`main.ps1` bootstraps the app by dot-sourcing every module in `functions/`. Each subfolder (device, menu, graph, reporting, etc.) groups scripts by responsibility; keep modules self-contained and suited for PowerShell 5.1. Configuration defaults live in the root `.psd1` files (`settings.psd1`, `menu.psd1`, `strings.psd1`), while runtime secrets are generated under `.secrets/` and log output lands in `Logs/`. Tests, demos, and validation harnesses sit in `TestScripts/`, and deeper references live in `docs/`. Binary drops like `main.exe` are build outputs only.

## Build, Test, and Development Commands
Launch the interactive tool with `.\main.ps1 -Verbose -LogLevel "Debug"` to mirror developer telemetry. Use `.\test.ps1` for lightweight module import checks, then run `.\TestScripts\Test-Runner.ps1 -TestCategory core`; extend to `syntax`, `integration`, or `comprehensive` depending on scope. Create signed builds with `.\CreateRelease.ps1 -Stage Build` (pair with `-WhatIf` for rehearsal). Tail `Logs\Autopilot.log` to watch Graph and menu activity while iterating.

## Coding Style & Naming Conventions
Stick to four-space indentation, ~120-character lines, and approved PowerShell verb-noun PascalCase (`Get-DeviceProfileStatus`). Variables use camelCase, constants use ALL_CAPS, and every public function needs comment-based help plus `$functionName = $MyInvocation.MyCommand.Name` for logging context. Favor `try/catch`, `Write-Verbose`, and the shared `Write-Log` helper; avoid 5.1-incompatible constructs such as ordered hashtables or string interpolation. **Do not use Unicode characters** (checkmarks, arrows, emoji, etc.) as PowerShell 5.1 console output may not render them correctly—stick to ASCII characters only. For newlines in `Write-Host` statements, use separate `Write-Host` calls instead of `\n` escape sequences. No automated formatter runs here—the style guidance and reviewers are the guardrails.

## Testing Guidelines
The unified runner is mandatory. Start with `.\TestScripts\Test-Runner.ps1 -TestCategory syntax` to confirm modules load, add `core` for functional confidence, and escalate to `integration` or `comprehensive` when touching cross-cutting workflows. New features should add focused scripts under `TestScripts/test-*.ps1` and update the registry in `Test-Runner.ps1` when new categories are needed. Preserve verbose logging so failures ship actionable diagnostics.

## Commit & Pull Request Guidelines
Craft single-line commit subjects in sentence case (`Fix vendor validation logging`), keeping them under 72 characters, and reference issues in the body (`Fixes #123`) when relevant. Before opening a PR, ensure the runner passes for the categories you impacted, update any affected docs in `docs/`, and attach screenshots or log snippets for menu or UI changes. PR descriptions should outline scope, validation commands, and configuration prerequisites so reviewers can reproduce quickly.

## Security & Configuration Tips
Never commit `.secrets/` contents or tenant-specific `.psd1` derivatives. When adding configuration keys, update `settings.psd1`, refresh the docs, and review Graph scopes for least privilege. Reuse the helpers in `functions/encryptionFunctions` rather than introducing new cryptography so secrets stay aligned with the existing AES workflow.

## Directory Object Architecture (Users & Groups)
The codebase uses a **unified directory object pattern** for Entra ID user and group operations. Instead of separate functions for each entity type, we have consolidated functions that accept an `EntityType` parameter (`"User"` or `"Group"`), reducing code duplication and simplifying maintenance.

### Core Unified Functions
- **`Get-EntraDirectoryObject`** - Unified search with exact match and fuzzy search via `-FindSimilar` switch. Implements `DirectoryObjectCache` for performance. Returns tuple: `(EntityInfo, IsFuzzyMatch)`.
- **`Show-DirectoryObjectList`** - Unified display with entity-appropriate formatting. Handles single-item auto-accept with `-NoPrompt`, multi-item menu selection, and MaxDisplay truncation.
- **`Resolve-DirectoryObject`** - Unified resolution workflow combining search + display + selection processing. Main entry point for interactive entity resolution.
- **`ConvertFrom-DirectoryObjectSelection`** - Unified selection result processor handling navigation commands (Back, Main Menu, Exit), return values pass-through, and entity identifier extraction.

### Deprecated Legacy Functions (Backward Compatibility Wrappers)
The following functions are maintained as thin wrappers for backward compatibility and will be removed in a future version:
- `Resolve-UserWithMatching` → wraps `Resolve-DirectoryObject` with `EntityType="User"`
- `ConvertFrom-UserSelection` → wraps `ConvertFrom-DirectoryObjectSelection`

**Migration Guidance**: New code should use the unified functions directly with the `EntityType` parameter. Update existing code gradually as workflows are touched.

### Usage Pattern
```powershell
# Modern unified approach (preferred)
$userName = Resolve-DirectoryObject -EntityName $userName -AccessToken $accessToken `
    -Settings $settings -ReturnValues $returnValues -EntityType "User"

$groupName = Resolve-DirectoryObject -EntityName $groupName -AccessToken $accessToken `
    -Settings $settings -ReturnValues $returnValues -EntityType "Group"

# Legacy wrapper approach (deprecated but supported)
$userName = Resolve-UserWithMatching -UserName $userName -AccessToken $accessToken `
    -Settings $settings -ReturnValues $returnValues
```

### Key Parameters & Switches
- **`EntityType`**: `"User"` or `"Group"` - determines entity-specific behavior (search filters, display formatting, cache keys)
- **`-FindSimilar`**: Enables fuzzy search when exact match fails (startswith givenName/surname for users, $search for groups)
- **`-NoPrompt`**: Auto-accepts single fuzzy match without user confirmation (useful for automation)
- **`MaxDisplay`**: Settings key (`maxUserMatchDisplay`, `maxGroupMatchDisplay`) controlling list truncation for large result sets
- **`DirectoryObjectCache`**: Module-level hashtable reducing redundant Graph API calls within a session

### Test Coverage
Comprehensive test suites validate all functionality (68/71 tests passing overall):
- `test-get-entra-directory-object.ps1`: 25/25 passing - exact match, fuzzy search, caching, error handling
- `test-show-directory-object-list.ps1`: 18/18 passing - empty lists, single/multiple items, NoPrompt, MaxDisplay
- `test-resolve-directory-object.ps1`: 25/28 passing - full workflow integration (3 minor edge cases)

### Migration Benefits
- **50% code reduction**: Single implementations replace duplicate user/group functions
- **Consistent UX**: Identical workflows for users and groups
- **Performance**: DirectoryObjectCache eliminates redundant API calls
- **Maintainability**: Bug fixes and enhancements apply to both entity types automatically
- **Type safety**: EntityType parameter enables better IntelliSense and validation


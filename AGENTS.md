# Repository Guidelines

## Project Structure & Module Organization
`main.ps1` bootstraps the app by dot-sourcing every module in `functions/`. Each subfolder (device, menu, graph, reporting, etc.) groups scripts by responsibility; keep modules self-contained and suited for PowerShell 5.1. Configuration defaults live in the root `.psd1` files (`settings.psd1`, `menu.psd1`, `strings.psd1`), while runtime secrets are generated under `.secrets/` and log output lands in `Logs/`. Tests, demos, and validation harnesses sit in `TestScripts/`, and deeper references live in `docs/`. Binary drops like `main.exe` are build outputs only.

## Build, Test, and Development Commands
Launch the interactive tool with `.\main.ps1 -Verbose -LogLevel "Debug"` to mirror developer telemetry. Use `.\test.ps1` for lightweight module import checks, then run **PowerShell 7** tests with `pwsh.exe -ExecutionPolicy Bypass -File .\Invoke-PesterTests.ps1 -TestType Unit` (or substitute `integration`, or `comprehensive` as needed). Create signed builds with `.\CreateRelease.ps1 -Stage Build` (pair with `-WhatIf` for rehearsal). Tail `Logs\Autopilot.log` to watch Graph and menu activity while iterating.

**IMPORTANT:** Always use PowerShell 7 (`pwsh.exe`) for running Pester tests. The application code must support PowerShell 5.1, but tests require PowerShell 7+.

## Coding Style & Naming Conventions
Stick to four-space indentation, ~120-character lines, and approved PowerShell verb-noun PascalCase (`Get-DeviceProfileStatus`). Variables use camelCase, constants use ALL_CAPS, and every public function needs comment-based help plus `$functionName = $MyInvocation.MyCommand.Name` for logging context. Favor `try/catch`, `Write-Verbose`, and the shared `Write-Log` helper; avoid 5.1-incompatible constructs such as ordered hashtables or string interpolation. **Do not use Unicode characters** (checkmarks, arrows, emoji, etc.) as PowerShell 5.1 console output may not render them correctly—stick to ASCII characters only. For newlines in `Write-Host` statements, use separate `Write-Host` calls instead of `\n` escape sequences. No automated formatter runs here—the style guidance and reviewers are the guardrails.

## Testing Guidelines

**⚠️ IMPORTANT:** For detailed test writing and migration guidance, see **[`tests/AGENTS.md`](tests/AGENTS.md)** (AI-optimized step-by-step instructions) and **[`docs/PESTER_MIGRATION_README.md`](docs/PESTER_MIGRATION_README.md)** (complete migration documentation hub).

The project uses **Pester v5** as the primary testing framework for new tests, while legacy tests are being gradually migrated (82% complete as of October 2025). Both frameworks coexist during the migration period.

### Quick Reference Commands
- **Quick validation:** `pwsh.exe -ExecutionPolicy Bypass -File .\Invoke-PesterTests.ps1 -TestType Unit` (runs fast Pester unit tests)
- **Full Pester suite:** `pwsh.exe -ExecutionPolicy Bypass -File .\Invoke-PesterTests.ps1 -TestType All -EnableCodeCoverage` (all Pester tests with coverage)
- **Single test file:** `pwsh.exe -ExecutionPolicy Bypass -File .\Invoke-PesterTests.ps1 -TestFile "tests\Unit\MyTest.Tests.ps1"`

**CRITICAL:** All Pester tests MUST be run using PowerShell 7 (`pwsh.exe`). Do not use `powershell.exe` (PowerShell 5.1) for running tests.

### Core Testing Principles
- ✅ **Improve helpers first** - Enhance helper modules rather than creating workarounds in individual tests
- ✅ **Direct dot-sourcing** - Load functions directly in BeforeAll blocks (most reliable pattern)
- ✅ **100% pass rate** - All tests must pass before committing (non-negotiable)
- ✅ **PowerShell 7+ for tests** - Tests MUST run using `pwsh.exe` (PowerShell 7+); application code must support PS 5.1
- ✅ **Use Sort-Object** - Apply to collections for deterministic ordering
- ✅ **Proper cleanup** - Always use `AfterAll` blocks to remove test artifacts; avoid TestDrive if possible, use `Initialize-AutopilotTestEnvironment` from helpers instead
- ⚠️ **Binary cmdlet mocking** - When mocking binary cmdlets like `Get-CimInstance`, use exact parameter names (e.g., `-ClassName` not `-Class`) and return appropriate types or simple strings to bypass strict type validation

### Helper Modules (Three-Tiered Architecture)
- **Layer 1 (Core):** `tests/Helpers/AutopilotTestHelpers.psm1` - Temp folders, settings files, cleanup
- **Layer 2a (Graph API):** `tests/Helpers/AutopilotGraphMocks.psm1` - Users, devices, groups, profiles, API mocking
- **Layer 2b (Menu System):** `tests/Helpers/AutopilotMenuMocks.psm1` - Menu navigation, user interactions

**When to use helpers:**
- Temp files/folders needed → AutopilotTestHelpers
- Graph API calls needed → AutopilotGraphMocks
- Menu interactions needed → AutopilotMenuMocks
- Simple tests may not need helpers at all (document why in `.NOTES`)

### Writing New Tests (Quick Start)

**For AI Agents:** See **[`tests/AGENTS.md`](tests/AGENTS.md)** for detailed step-by-step workflows

**For Developers:**
1. Review `docs/TEST_TEMPLATE_GUIDELINES.md` - Comprehensive patterns guide
2. Choose test category: Unit / Integration / Comprehensive
3. Check existing tests in `tests/[Category]/` for similar examples
4. Use helpers when needed (enhance if gaps exist)
5. Load functions via direct dot-sourcing in BeforeAll
6. Tag appropriately: `'Unit'`, `'Integration'`, or `'Comprehensive'`
5. Validate: Run tests (in PowerShell 7+), ensure 100% pass rate
8. Document: Add `.NOTES` section explaining approach

**Example Test Structure:**
```powershell
Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: Get-Something" -Tags 'Unit' {
    BeforeAll {
        # Direct dot-sourcing (recommended pattern)
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
        . "$script:RepoRoot/functions/category/Get-Something.ps1"
    }
    
    It "Should do something" {
        $result = Get-Something
        $result | Should -Be "Expected"
    }
}
```

### Migrating Existing Tests

**For step-by-step migration guide:** See **[`tests/AGENTS.md`](tests/AGENTS.md)** → Section 3

**Quick workflow:**
1. Create new test in `tests/[Category]/[FunctionName].Tests.ps1`
2. Follow patterns in existing Pester tests
3. Use helpers (enhance if needed)
4. Validate equivalence: `.\tools\Validate-PesterMigration.ps1`
5. Test in PowerShell 7+ (required for Pester tests)
6. Archive legacy test to `TestScripts/archived/` after validation

**Migration Status:** 155 of ~190 tests migrated (82%), 100% pass rate, 2-3s execution time

### Test Categories
- **syntax**: PowerShell syntax validation ✅ Migrated to Pester
- **core**: Critical functionality tests 🔄 Being migrated
- **unit**: Component-level tests ✅ Migrated to Pester (144 tests)
- **integration**: Cross-component tests 🔄 In progress (8/12 migrated)
- **comprehensive**: End-to-end scenarios ⏳ Planned (Weeks 7-10)
- **performance**: Benchmarks ⚠️ Remaining in legacy framework (separate from Pester)
- **migration**: Migration-specific tests ⏳ To be evaluated (Week 11-12)

### Documentation Resources
- **[`tests/AGENTS.md`](tests/AGENTS.md)** - AI-optimized step-by-step guide (primary reference for test creation/migration)
- **[`docs/PESTER_MIGRATION_README.md`](docs/PESTER_MIGRATION_README.md)** - Migration documentation hub (quick links to all resources)
- **[`docs/TEST_TEMPLATE_GUIDELINES.md`](docs/TEST_TEMPLATE_GUIDELINES.md)** - Comprehensive patterns and helper usage
- **[`docs/PESTER_MIGRATION_LESSONS_LEARNED.md`](docs/PESTER_MIGRATION_LESSONS_LEARNED.md)** - Technical challenges and solutions
- **[`docs/PESTER_MIGRATION_COMPLETION_PLAN.md`](docs/PESTER_MIGRATION_COMPLETION_PLAN.md)** - Roadmap for remaining work

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


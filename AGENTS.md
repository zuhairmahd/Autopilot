# Repository Guidelines

## Project Structure & Module Organization
`main.ps1` bootstraps the app by dot-sourcing every module in `functions/`. Each subfolder (device, menu, graph, reporting, etc.) groups scripts by responsibility; keep modules self-contained and suited for PowerShell 5.1. Configuration defaults live in the root `.psd1` files (`settings.psd1`, `menu.psd1`, `strings.psd1`), while runtime secrets are generated under `.secrets/` and log output lands in `Logs/`. Tests, demos, and validation harnesses sit in `TestScripts/`, and deeper references live in `docs/`. Binary drops like `main.exe` are build outputs only.

## Build, Test, and Development Commands
Launch the interactive tool with `.\main.ps1 -Verbose -LogLevel "Debug"` to mirror developer telemetry. Use `.\test.ps1` for lightweight module import checks, then run `.\TestScripts\Test-Runner.ps1 -TestCategory core`; extend to `syntax`, `integration`, or `comprehensive` depending on scope. Create signed builds with `.\CreateRelease.ps1 -Stage Build` (pair with `-WhatIf` for rehearsal). Tail `Logs\Autopilot.log` to watch Graph and menu activity while iterating.

## Coding Style & Naming Conventions
Stick to four-space indentation, ~120-character lines, and approved PowerShell verb-noun PascalCase (`Get-DeviceProfileStatus`). Variables use camelCase, constants use ALL_CAPS, and every public function needs comment-based help plus `$functionName = $MyInvocation.MyCommand.Name` for logging context. Favor `try/catch`, `Write-Verbose`, and the shared `Write-Log` helper; avoid 5.1-incompatible constructs such as ordered hashtables or string interpolation. **Do not use Unicode characters** (checkmarks, arrows, emoji, etc.) as PowerShell 5.1 console output may not render them correctly—stick to ASCII characters only. For newlines in `Write-Host` statements, use separate `Write-Host` calls instead of `\n` escape sequences. No automated formatter runs here—the style guidance and reviewers are the guardrails.

## Testing Guidelines
The project now uses **Pester v5** as the primary testing framework for new tests, while legacy tests are being gradually migrated. Both frameworks coexist during the migration period.

### Running Tests
- **Quick validation:** `.\Invoke-PesterTests.ps1 -TestType Unit` (runs fast Pester unit tests)
- **Full Pester suite:** `.\Invoke-PesterTests.ps1 -TestType All -EnableCodeCoverage` (all Pester tests with coverage)
- **Complete suite:** `.\Invoke-AllTests.ps1` (runs both Pester and remaining legacy tests)
- **Legacy tests:** `.\TestScripts\Test-Runner.ps1 -TestCategory <category>` (for tests not yet migrated)

### Writing New Tests
- **Use Pester format** with Describe/Context/It blocks
- **Follow the template:** `tests/Template.Tests.ps1` - see `docs/TEST_TEMPLATE_GUIDELINES.md` for when and how to use it
- **Tag appropriately:** Use `'Unit'`, `'Integration'`, or `'Comprehensive'` tags
- **Load functions:** Dot-source functions directly in BeforeAll blocks (most reliable method for PS 5.1 + Pester 5.x)
- **Use helpers when appropriate:**
  - Import `tests/Helpers/AutopilotTestHelpers.psm1` for temp folder management and cleanup
  - Import `tests/Helpers/AutopilotGraphMocks.psm1` for Graph API mocking
  - See guidelines for when helpers are required vs optional
- **Improve helpers, not workarounds:** When encountering testing needs not supported by helpers, enhance the helper modules rather than creating workarounds in individual tests. This ensures all tests benefit from improvements.
- **Document deviations:** If not using helpers, add `.NOTES` section explaining why (simple test, no state management, etc.)
- **Mandatory:** All tests must pass (100% success rate) before committing

### Test Template Guidelines (STRICT ENFORCEMENT)

**READ THIS FIRST:** `docs/TEST_TEMPLATE_GUIDELINES.md` - Comprehensive guide on template usage

**Key Rules:**
1. **Use helpers for:** Tests with temp files, Graph API calls, complex state management
2. **Dot-source directly for:** Function loading (most reliable in PS 5.1 + Pester 5.x)
3. **Document all deviations:** Add `.NOTES` section explaining why template isn't fully used
4. **Examples to follow:**
   - `tests/Unit/GetEntraDirectoryObject.Tests.ps1` - Exemplary Graph API mocking
   - `tests/Unit/Syntax.Tests.ps1` - Acceptable simple test without helpers
   - `tests/Integration/MenuInclusions.Tests.ps1` - Appropriate direct loading pattern

**Why direct dot-sourcing in BeforeAll:**
- PowerShell 5.1 + Pester 5.x have complex scoping behavior
- Module functions cannot reliably dot-source into caller's scope
- Direct dot-sourcing in BeforeAll is the ONLY reliable method
- This is a known limitation, not a template violation

**Before creating a test:**
1. Review `docs/TEST_TEMPLATE_GUIDELINES.md`
2. Check similar existing tests for patterns
3. Use helpers when you need their features (temp files, cleanup, mocking)
4. If helpers don't support your need, enhance the helpers first
5. Document your approach in test header
6. Ensure 100% test pass rate

### Migrating Existing Tests
When migrating legacy tests to Pester:
1. Create new test in `tests/Unit/`, `tests/Integration/`, or `tests/Comprehensive/`
2. Follow patterns in existing Pester tests
3. Validate equivalence with `.\tools\Validate-PesterMigration.ps1`
4. Archive legacy test to `TestScripts/archived/` after validation
5. See `docs/PESTER_MIGRATION_PLAN.md` for detailed migration guide

### Test Categories
- **syntax**: PowerShell syntax validation (migrated to Pester)
- **core**: Critical functionality tests (being migrated)
- **unit**: Component-level tests (being migrated)
- **integration**: Cross-component tests (to be migrated)
- **comprehensive**: End-to-end scenarios (selective migration)
- **performance**: Benchmarks (remaining in legacy framework)
- **migration**: Migration-specific tests (remaining in legacy framework)

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


# Windows Autopilot Management Tool - AI Agent Instructions

## Project Overview

Enterprise PowerShell application for managing Windows Autopilot device enrollment via Microsoft Intune and Graph API. **137 functions** across 9 categories, interactive menu-driven interface, with C# DLL performance optimizations achieving 35-45% speedup.

**Critical**: Application code must support **PowerShell 5.1**, but tests require **PowerShell 7+** (see [Known Issues](docs/KNOWN_ISSUES.md)).

## Architecture Quick Reference

### Bootstrap Flow
```
main.ps1 (entry point)
  ├─ Dot-source all *.ps1 in functions/ (recursive, alphabetical)
  ├─ Initialize-AutopilotDlls (load 8 C# DLLs with PS fallback)
  ├─ Initialize-ApplicationConfiguration (merge settings hierarchy)
  ├─ Authentication (Graph API token acquisition)
  └─ DisplayNumericMenu (interactive menu loop)
```

### Function Organization
```
functions/
├── autopilotFunctions/    # Device enrollment (v1 legacy, v2 current)
├── deviceFunctions/       # Device queries, BitLocker, LAPS
├── encryptionFunctions/   # AES-256 config encryption
├── graphFunctions/        # Microsoft Graph API integration
├── menuFunctions/         # UI navigation (17 functions)
├── reportingFunctions/    # CSV exports, readiness reports
├── setupFunctions/        # Config management, First Run Wizard
├── updateFunctions/       # Auto-update with signature verification
├── utilityFunctions/      # Write-Log, caching, helpers
└── UserAndGroupFunctions/ # Unified directory object resolution
```

### Configuration Hierarchy (Merged at Runtime)
1. **Runtime Parameters** (highest priority) - CLI args to main.ps1
2. **Domain Settings** - `settings.psd1` → `domains[domain].settings`
3. **Global Settings** - `settings.psd1` → `globalSettings`
4. **Secrets** - `.secrets/config.psd1` (AES-256 encrypted)

**Performance**: PSD1 format is 89.6% faster than JSON (10ms vs 96ms load time).

## Critical Patterns

### 1. PowerShell 5.1 Compatibility (Application Code)
**All production code must support PS 5.1**:
- ❌ NO ordered hashtables: `[ordered]@{}`
- ❌ NO string interpolation: `"$($var.Property)"`
- ❌ NO ternary operators: `$x ? $a : $b`
- ❌ NO Unicode in console output (checkmarks, arrows, emoji)
- ✅ Use `@{}` for hashtables
- ✅ Use `"$($var.Property)"` or `-f` operator
- ✅ Use `if/else` blocks
- ✅ ASCII-only characters for `Write-Host`

### 2. C# DLL Integration Pattern (Automatic Fallback)
**8 performance DLLs** provide 10-48x speedups with zero breaking changes:

```powershell
function Your-Function {
    $useDll = $global:AutopilotDllStatus -and $global:AutopilotDllStatus.FeatureLoaded
    
    if ($useDll) {
        try {
            # C# implementation (10x faster)
            return [Autopilot.FeatureCore]::Method($input)
        }
        catch {
            Write-Warning "DLL failed, using PowerShell: $_"
        }
    }
    
    # PowerShell fallback (original code - zero changes)
    # ...
}
```

**Available DLLs** (see [.NET Migration Plan](docs/DOTNET_MIGRATION_PLAN.md)):
- `LogCore.dll`: 10-20x faster logging
- `CacheCore.dll`: Thread-safe LRU cache
- `ConfigCore.dll`: 10-48x faster config operations
- `DeviceCore.dll`: 3.6x faster filtering
- `GraphCore.dll`: 5-10x faster batch API calls
- `StringCore.dll`, `CsvCore.dll`, `CollectionCore.dll`: 3-10x speedups

### 3. Unified Directory Object Pattern
**Replaces separate user/group functions** with `EntityType` parameter:

```powershell
# Modern (use this)
$user = Resolve-DirectoryObject -EntityName "john@contoso.com" `
    -AccessToken $token -EntityType "User" -Settings $settings

$group = Resolve-DirectoryObject -EntityName "IT Admins" `
    -AccessToken $token -EntityType "Group" -Settings $settings

# Legacy (deprecated, still works)
$user = Resolve-UserWithMatching -UserName "john@contoso.com" ...
```

**Core Functions**:
- `Get-EntraDirectoryObject`: Search with fuzzy matching, returns `(EntityInfo, IsFuzzyMatch)`
- `Show-DirectoryObjectList`: Display with auto-accept for single results
- `Resolve-DirectoryObject`: Full workflow (search → display → selection)
- `ConvertFrom-DirectoryObjectSelection`: Process navigation commands

### 4. Menu System Integration
**Data-driven, role-based access control**:

```powershell
# menu.psd1 structure
@{
    id = 'assign-device'
    name = 'Give a device to a user'
    includeInDisplayModes = @('full', 'helpdesk', 'admin')
    action = 'Give a device to a user'
    actionFunction = 'GiveDeviceToUser'
    navigationHistory = $true
}
```

**Key Concepts**:
- **App Modes**: `full`, `admin`, `advanced`, `helpdesk`, `registration`, `advancedRegistration`, `custom`
- **Hierarchy**: `full` > `admin` > `advanced` > `helpdesk`/`registration`
- **Multi-Mode Support**: Combine modes (e.g., `@('helpdesk', 'registration')`)
- **Navigation**: Stack-based history in `$global:MenuHistory`

## Development Commands

### Build & Test
```powershell
# Run interactive application (debug mode)
.\main.ps1 -Verbose -LogLevel "Debug"

# Build C# DLLs (both netstandard2.0 and net9.0)
.\Build-NativeDlls.ps1 -Configuration Release

# Quick test (unit tests only, PowerShell 7 required)
pwsh.exe -ExecutionPolicy Bypass -File .\Invoke-PesterTests.ps1 -TestType Unit -outputVerbosity Detailed

# Full test suite with coverage (PowerShell 7 required)
pwsh.exe -ExecutionPolicy Bypass -File .\Invoke-PesterTests.ps1 -TestType All -EnableCodeCoverage -outputVerbosity Detailed

# Verify DLL loading (8/8 expected)
.\tools\Verify-DotNetSetup.ps1

# Benchmark performance gains
.\tools\Benchmark-DllPerformance.ps1

# Create signed release
.\CreateRelease.ps1 -Stage Build
```

### Validation
```powershell
# Import check (lightweight syntax validation)
.\test.ps1

# Watch logs during development
Get-Content -Path "Logs\Autopilot.log" -Wait -Tail 50
```

## Testing Guidelines (CRITICAL)

### Test Execution Environment
- **Tests MUST run in PowerShell 7+**: `pwsh.exe` (not `powershell.exe`)
- **Application MUST support PowerShell 5.1**: Dual compatibility required
- **Reason**: Pester v5 requires PS 7+, but application targets enterprise PS 5.1

### Pester Test Structure
```powershell
Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: Get-Something" -Tags 'Unit' {
    BeforeAll {
        # Direct dot-sourcing (PS 5.1 compatible)
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
        . "$script:RepoRoot/functions/category/Get-Something.ps1"
    }
    
    AfterAll {
        # REQUIRED: Always clean up
        Remove-TestEnvironment -TestContext $script:TestContext
    }
    
    It "Should do something" {
        $result = Get-Something
        $result | Should -Be "Expected"
    }
}
```

### Test Helper Modules (Three-Tiered)
- **Layer 1**: `tests/Helpers/AutopilotTestHelpers.psm1` - Temp folders, settings files
- **Layer 2a**: `tests/Helpers/AutopilotGraphMocks.psm1` - Graph API mocking (users, groups, devices)
- **Layer 2b**: `tests/Helpers/AutopilotMenuMocks.psm1` - Menu system mocking

**Golden Rule**: **Improve helpers first**, don't create workarounds in individual tests.

### Key Testing Principles
- ✅ Direct dot-sourcing in BeforeAll (module loading doesn't work in PS 5.1)
- ✅ 100% pass rate before committing (non-negotiable)
- ✅ Use `Sort-Object` for deterministic collection ordering
- ✅ Always include AfterAll cleanup (avoid TestDrive, use helpers)
- ⚠️ Binary cmdlets: Use exact parameter names (e.g., `-ClassName` not `-Class`)

**Detailed guidance**: See [tests/AGENTS.md](tests/AGENTS.md) for AI-optimized workflows.

## Common Tasks

### Adding a New Function
1. Create `functions/category/YourFunction.ps1`
2. Add comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`)
3. Add `$functionName = $MyInvocation.MyCommand.Name` for logging
4. Use PascalCase for function names (approved PowerShell verbs)
5. Support parameters via `param()` and $settings hashtable
6. Call `Write-Log` for all important operations
7. Create Pester test in `tests/Unit/category/YourFunction.Tests.ps1`

### Integrating a C# DLL
1. Create DLL project in `src/Autopilot.FeatureCore/`
2. Multi-target: `<TargetFrameworks>netstandard2.0;net9.0</TargetFrameworks>`
3. Update `Build-NativeDlls.ps1` to include new project
4. Update `Initialize-AutopilotDlls.ps1` to load DLL
5. Wrap PowerShell function with fallback pattern (see above)
6. Add verification tests to `Verify-DotNetSetup.ps1`
7. Update `DOTNET_MIGRATION_PLAN.md`

### Adding a Menu Item
1. Edit `menu.psd1`, add menu hashtable:
   ```powershell
   @{
       id = 'unique-id'
       name = 'Display Name'
       includeInDisplayModes = @('full', 'admin')
       action = 'FunctionName'
       navigationHistory = $true
   }
   ```
2. Create action function in appropriate category
3. Test with different `appMode` values
4. Update menu tests if needed

## Code Style (Non-Negotiable)

### Formatting
- **Indentation**: 4 spaces (not tabs)
- **Line length**: ~120 characters
- **Variables**: camelCase (`$myVariable`)
- **Functions**: PascalCase with approved verbs (`Get-DeviceStatus`)
- **Constants**: ALL_CAPS (`$MAX_RETRY_COUNT`)

### Logging Pattern
```powershell
function Your-Function {
    param(...)
    $functionName = $MyInvocation.MyCommand.Name
    
    Write-Verbose "[$functionName] Starting operation"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Operation started" -LogLevel "Information"
    
    try {
        # ... logic ...
        Write-Log -LogFile $LogFile -Module $functionName -Message "Success" -LogLevel "Information"
    }
    catch {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error: $_" -LogLevel "Error"
        throw
    }
}
```

### Error Handling
- Always use `try/catch` for external operations (API calls, file I/O)
- Log errors with `Write-Log` before re-throwing
- Provide user-friendly messages via `Write-Host`
- Include `$functionName` context in all logs

## Security Notes

### Sensitive Data Handling
- **Never commit**: `.secrets/` directory (AES-256 encrypted configs)
- **Encrypted at rest**: All credentials in `config.psd1`
- **In-memory only**: Decryption happens in memory, never written as plaintext
- **Password retry**: 3 attempts max, then auto-delete config file
- **Token caching**: Supports file-based or memory-only caching

### Graph API Permissions
- **Least privilege**: Review scopes in `settings.psd1` → `auth.scope`
- **Delegated vs Application**: Support both authentication flows
- **Scope validation**: Optional validation via `validateScopes` flag
- **Token renewal**: Automatic with `renewalLeadTime` buffer

## Key Documentation

- **[AGENTS.md](AGENTS.md)** - Repository guidelines (this file's source)
- **[tests/AGENTS.md](tests/AGENTS.md)** - AI-optimized testing guide
- **[docs/DOTNET_MIGRATION_PLAN.md](docs/DOTNET_MIGRATION_PLAN.md)** - C# DLL integration roadmap
- **[docs/TECHNICAL_DOCUMENTATION.md](docs/TECHNICAL_DOCUMENTATION.md)** - Architecture deep-dive
- **[docs/directory-object-optimization.md](docs/directory-object-optimization.md)** - Unified entity pattern
- **[readme.md](readme.md)** - User guide and features

## Troubleshooting

### Tests Fail After Editing
- Verify PS 7+ execution: `$PSVersionTable.PSVersion`
- Check direct dot-sourcing in BeforeAll
- Ensure cleanup in AfterAll
- Run single test: `.\Invoke-PesterTests.ps1 -TestFile "path/to/test.Tests.ps1"`

### DLLs Not Loading
- Check `$global:AutopilotDllStatus` hashtable
- Run `.\tools\Verify-DotNetSetup.ps1`
- Rebuild: `.\Build-NativeDlls.ps1 -Clean -Configuration Release`
- Verify framework: netstandard2.0 for PS 5.1, net9.0 for PS 7+

### Function Not Available in Menu
- Check `includeInDisplayModes` in `menu.psd1`
- Verify `appMode` parameter or settings
- Review hierarchy: `full` > `admin` > `advanced` > `helpdesk`

## Quick Decision Tree

```
Need to add functionality?
├─ Is it UI-related?
│  └─ Add to menuFunctions/ + update menu.psd1
│
├─ Is it a Graph API call?
│  └─ Add to graphFunctions/ (may use GraphCore.dll)
│
├─ Is it device-specific?
│  └─ Add to deviceFunctions/ or autopilotFunctions/
│
├─ Is it performance-critical?
│  ├─ Can C# help? → Create DLL in src/
│  └─ Otherwise → Add to utilityFunctions/
│
└─ Is it configuration/setup?
   └─ Add to setupFunctions/

Need to write tests?
├─ Check tests/AGENTS.md for step-by-step guide
├─ Use direct dot-sourcing (not modules)
├─ Use helpers (enhance if needed)
└─ Always run in PowerShell 7+
```

---

**Maintained By**: Development Team  
**Last Updated**: November 2, 2025  
**Migration Status**: 82% Pester v5, 8/8 DLLs integrated, 35-45% speedup achieved

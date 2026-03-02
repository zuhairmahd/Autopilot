# Repository Guidelines

## Quick Links

| Resource | Description |
|----------|-------------|
| [Developer Guide](docs/DEVELOPER_GUIDE.md) | Architecture, testing, coding standards |
| [Settings Reference](docs/SETTINGS.md) | Configuration documentation |
| [Testing Guide](tests/AGENTS.md) | AI-optimized test instructions |

## Project Structure

```
/
├── functions/           # PowerShell modules (dot-sourced at startup)
│   ├── UserAndGroupFunctions/   # User/group operations
│   ├── autopilotFunctions/      # Autopilot device management
│   ├── deviceFunctions/         # Device operations
│   ├── encryptionFunctions/     # Security and encryption
│   ├── graphFunctions/          # Microsoft Graph API
│   ├── menuFunctions/           # UI and navigation
│   ├── reportingFunctions/      # Reporting and export
│   ├── setupFunctions/          # Configuration and setup
│   ├── updateFunctions/         # Auto-update
│   └── utilityFunctions/        # General utilities
├── tests/               # Pester v5 tests
├── docs/                # Documentation
├── .secrets/            # Encrypted credentials (runtime)
├── Logs/                # Application logs
├── settings.psd1        # Main configuration
├── menu.psd1            # Menu definitions
└── strings.psd1         # UI text
```

## Development Commands

```powershell
# Run application in development mode
.\main.ps1 -Verbose -LogLevel "Debug"

# Run Pester tests (PowerShell 7+ required)
pwsh.exe -ExecutionPolicy Bypass -File .\Invoke-PesterTests.ps1 -TestType Unit -outputVerbosity Detailed

# Run specific test file
pwsh.exe -ExecutionPolicy Bypass -File .\Invoke-PesterTests.ps1 -TestFile "tests\Unit\MyTest.Tests.ps1"

# Create signed build
.\CreateRelease.ps1 -Stage Build
```

## Coding Standards

### PowerShell 5.1 Compatibility
The application must support PowerShell 5.1. Avoid:
- Ordered hashtables (`[ordered]@{}`)
- Unicode characters in output
- PowerShell 7-only features

### Style
- Four-space indentation, ~120-character lines
- PascalCase for functions (`Get-DeviceStatus`)
- camelCase for variables
- Comment-based help for public functions
- Include `$functionName = $MyInvocation.MyCommand.Name` for logging

### Output
**ASCII only** - Do not use Unicode characters (checkmarks, arrows, emoji):
```powershell
# Good
Write-Host "[PASS] Test completed"

# Bad
Write-Host "✓ Test completed"
```

### Logging
**All functions must implement comprehensive logging** using the `Write-Log` function:

#### Logging Requirements
1. **Initialize function name** at the start of every function:
   ```powershell
   $functionName = $MyInvocation.MyCommand.Name
   ```

2. **Log function entry** with Information level:
   ```powershell
   Write-Log -LogFile $LogFile -Module $functionName -Message "Starting [operation description]" -LogLevel "Information"
   ```

3. **Log key operations** with appropriate levels:
   - **Verbose**: Detailed step-by-step operations, loop iterations, data counts
   - **Information**: Major milestones, successful completions, important state changes
   - **Warning**: Non-critical issues, fallbacks, deprecated feature usage
   - **Error**: Failures, exceptions, invalid states

4. **Log function exit** with completion message:
   ```powershell
   Write-Log -LogFile $LogFile -Module $functionName -Message "[Operation] completed successfully" -LogLevel "Information"
   ```

5. **Log errors before throwing**:
   ```powershell
   Write-Log -LogFile $LogFile -Module $functionName -Message "Error description" -LogLevel "Error"
   throw "Error message"
   ```

#### Logging Example
```powershell
function Get-DeviceInfo
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DeviceId
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting device information retrieval for: $DeviceId" -LogLevel "Information"

    try
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Fetching device from Graph API" -LogLevel "Verbose"
        $device = CallGraphAPI -ResourcePath "devices/$DeviceId" -AccessToken $token

        if (-not $device)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Device not found: $DeviceId" -LogLevel "Warning"
            return $null
        }

        Write-Log -LogFile $LogFile -Module $functionName -Message "Device retrieved successfully: $($device.displayName)" -LogLevel "Information"
        return $device
    }
    catch
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to retrieve device: $_" -LogLevel "Error"
        throw
    }
}
```

#### Log Levels
- **Error** (1): Failures requiring immediate attention
- **Warning** (2): Potential issues, deprecations, non-critical failures
- **Information** (3): Normal operation milestones, completions
- **Verbose** (4): Detailed operational information, useful for troubleshooting
- **Debug** (5): Low-level diagnostic information

The global `$MinimumLogLevel` variable controls which messages are written to the log file.

## Testing

### Requirements
- **PowerShell 7+** required for running tests (`pwsh.exe`)
- **100% pass rate** required before committing
- Use **direct dot-sourcing** for function loading

### Test Helpers
| Module | Purpose |
|--------|---------|
| `AutopilotTestHelpers.psm1` | Temp folders, settings files |
| `AutopilotGraphMocks.psm1` | Graph API mocking |
| `AutopilotMenuMocks.psm1` | Menu system mocking |

### Test Structure
```powershell
Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Feature" -Tags 'Unit' {
    BeforeAll {
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
        . "$script:RepoRoot/functions/category/Function.ps1"
    }

    It "Should work" {
        $result = Test-Function
        $result | Should -Be "expected"
    }
}
```

See [tests/AGENTS.md](tests/AGENTS.md) for complete testing guide.

## Configuration

Settings use hierarchical override:
1. **Runtime Parameters** (highest priority)
2. **Domain Settings** (`settings.psd1` -> `domains[domain].settings`)
3. **Global Settings** (`settings.psd1` -> `globalSettings`)

See [docs/SETTINGS.md](docs/SETTINGS.md) for complete reference.

## Security

- Never commit `.secrets/` contents
- Use `functions/encryptionFunctions/` for credential handling
- Review Graph scopes for least privilege

## Directory Object Pattern

Use unified functions for user/group operations:

```powershell
# Preferred
$result = Resolve-DirectoryObject -EntityName $name -EntityType "User" ...

# Deprecated (backward compatible)
$result = Resolve-UserWithMatching -UserName $name ...
```

Key functions:
- `Get-EntraDirectoryObject` - Search with caching
- `Show-DirectoryObjectList` - Display with formatting
- `Resolve-DirectoryObject` - Complete resolution workflow


<#
.SYNOPSIS
    Helper functions for Autopilot Pester tests
.DESCRIPTION
    Provides common utilities for test setup, mocking, and validation
    Replaces test-helper.ps1 functionality for Pester tests
#>

function Initialize-AutopilotTestEnvironment {
    <#
    .SYNOPSIS
        Sets up test environment for Autopilot tests
    .DESCRIPTION
        Loads functions, creates temp folders, initializes mocks
    #>
    [CmdletBinding()]
    param(
        [string]$TestFolder = $null
    )
    
    # Find repository root
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    
    # Create test folder if not specified
    if (-not $TestFolder) {
        $TestFolder = Join-Path $env:TEMP "AutopilotTest_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    }
    
    if (-not (Test-Path $TestFolder)) {
        New-Item -Path $TestFolder -ItemType Directory -Force | Out-Null
    }
    
    # Create subfolders
    $secretsFolder = Join-Path $TestFolder ".secrets"
    $logsFolder = Join-Path $TestFolder "Logs"
    
    New-Item -Path $secretsFolder -ItemType Directory -Force | Out-Null
    New-Item -Path $logsFolder -ItemType Directory -Force | Out-Null
    
    # Return test context
    return @{
        RootPath = $repoRoot
        TestFolder = $TestFolder
        SecretsFolder = $secretsFolder
        LogsFolder = $logsFolder
        ConfigFile = Join-Path $secretsFolder "config.json"
        SettingsFile = Join-Path $TestFolder "settings.json"
        StringsFile = Join-Path $TestFolder "strings.json"
        LogFile = Join-Path $logsFolder "Autopilot.log"
    }
}

function Import-AutopilotFunctions {
    <#
    .SYNOPSIS
        Loads all Autopilot functions for testing
    #>
    [CmdletBinding()]
    param(
        [string]$RootPath
    )
    
    $functionsPath = Join-Path $RootPath "functions"
    
    if (-not (Test-Path $functionsPath)) {
        throw "Functions folder not found: $functionsPath"
    }
    
    $functionFiles = Get-ChildItem -Path $functionsPath -Recurse -Filter *.ps1
    
    foreach ($file in $functionFiles) {
        # Use Invoke-Expression with Get-Content to load functions in the calling scope
        $content = Get-Content $file.FullName -Raw
        $ExecutionContext.InvokeCommand.InvokeScript($false, [scriptblock]::Create($content), $null, $null)
    }
    
    Write-Verbose "Loaded $($functionFiles.Count) function files"
}

function New-MockSettingsFile {
    <#
    .SYNOPSIS
        Creates a mock settings.json file for testing
    #>
    [CmdletBinding()]
    param(
        [string]$Path,
        [hashtable]$CustomSettings = @{}
    )
    
    $defaultSettings = @{
        version = "1.0"
        globalSettings = @{
            maxUserMatchDisplay = 10
            maxGroupMatchDisplay = 10
            logLevel = "Info"
        }
        authSettings = @{
            authType = "ClientCredentials"
        }
    }
    
    # Merge custom settings
    foreach ($key in $CustomSettings.Keys) {
        $defaultSettings[$key] = $CustomSettings[$key]
    }
    
    $defaultSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $Path
    return $Path
}

function Remove-TestEnvironment {
    <#
    .SYNOPSIS
        Cleans up test environment
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$TestContext
    )
    
    if (Test-Path $TestContext.TestFolder) {
        Remove-Item -Path $TestContext.TestFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-AutopilotTestEnvironment',
    'Import-AutopilotFunctions',
    'New-MockSettingsFile',
    'Remove-TestEnvironment'
)

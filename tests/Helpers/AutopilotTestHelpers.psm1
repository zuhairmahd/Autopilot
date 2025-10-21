<#
.SYNOPSIS
    Helper functions for Autopilot Pester tests
.DESCRIPTION
    Provides common utilities for test setup, mocking, and validation
    Replaces test-helper.ps1 functionality for Pester tests
#>

function Initialize-AutopilotTestEnvironment
{
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
    if (-not $TestFolder)
    {
        $tempPath = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
        $TestFolder = Join-Path $tempPath "AutopilotTest_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    }
    
    if (-not (Test-Path $TestFolder))
    {
        New-Item -Path $TestFolder -ItemType Directory -Force | Out-Null
    }
    
    # Create subfolders
    $secretsFolder = Join-Path $TestFolder ".secrets"
    $logsFolder = Join-Path $TestFolder "Logs"
    
    New-Item -Path $secretsFolder -ItemType Directory -Force | Out-Null
    New-Item -Path $logsFolder -ItemType Directory -Force | Out-Null
    
    # Return test context
    return @{
        RootPath      = $repoRoot
        TestFolder    = $TestFolder
        SecretsFolder = $secretsFolder
        LogsFolder    = $logsFolder
        ConfigFile    = Join-Path $secretsFolder "config.json"
        SettingsFile  = Join-Path $TestFolder "settings.json"
        StringsFile   = Join-Path $TestFolder "strings.json"
        LogFile       = Join-Path $logsFolder "Autopilot.log"
    }
}

function Import-AutopilotFunctions
{
    <#
    .SYNOPSIS
        Loads all Autopilot functions for testing
    #>
    [CmdletBinding()]
    param(
        [string]$RootPath
    )
    
    $functionsPath = Join-Path $RootPath "functions"
    
    if (-not (Test-Path $functionsPath))
    {
        throw "Functions folder not found: $functionsPath"
    }
    
    $functionFiles = Get-ChildItem -Path $functionsPath -Recurse -Filter *.ps1
    
    foreach ($file in $functionFiles)
    {
        # Use Invoke-Expression with Get-Content to load functions in the calling scope
        $content = Get-Content $file.FullName -Raw
        $ExecutionContext.InvokeCommand.InvokeScript($false, [scriptblock]::Create($content), $null, $null)
    }
    
    Write-Verbose "Loaded $($functionFiles.Count) function files"
}

function New-MockSettingsFile
{
    <#
    .SYNOPSIS
        Creates a mock settings configuration file for testing
    .DESCRIPTION
        Creates either a .psd1 (PowerShell Data File) or .json file for testing.
        Defaults to .psd1 format to match production settings files.
        Properly handles deep nested hashtables for complex configurations.
    .PARAMETER Path
        Full path for the settings file (extension determines format)
    .PARAMETER CustomSettings
        Hashtable of custom settings to merge with defaults
    .PARAMETER Format
        File format: 'psd1' (default) or 'json'
    .EXAMPLE
        New-MockSettingsFile -Path "test.psd1" -CustomSettings @{version="2.0"}
    .EXAMPLE
        $domainSettings = @{
            domains = @{
                "contoso.com" = @{
                    domainSettings = @{}
                }
            }
        }
        New-MockSettingsFile -Path "test.psd1" -CustomSettings $domainSettings
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [hashtable]$CustomSettings = @{},
        [ValidateSet('psd1', 'json')]
        [string]$Format = 'psd1'
    )
    
    # Helper function for deep hashtable merging
    function Merge-Hashtables
    {
        param(
            [hashtable]$Target,
            [hashtable]$Source
        )
        foreach ($key in $Source.Keys)
        {
            if ($Target.ContainsKey($key) -and 
                $Target[$key] -is [hashtable] -and 
                $Source[$key] -is [hashtable])
            {
                # Recursively merge nested hashtables
                Merge-Hashtables -Target $Target[$key] -Source $Source[$key]
            }
            else
            {
                $Target[$key] = $Source[$key]
            }
        }
    }
    
    $defaultSettings = @{
        version        = "1.0"
        description    = "Test settings file"
        globalSettings = @{
            maxUserMatchDisplay  = 10
            maxGroupMatchDisplay = 10
            logLevel             = "Info"
        }
        authSettings   = @{
            authType = "ClientCredentials"
        }
        domains        = @{}
    }
    
    # Deep merge custom settings
    Merge-Hashtables -Target $defaultSettings -Source $CustomSettings
    
    # Auto-detect format from extension if not specified
    if ($Path -match '\.json$')
    {
        $Format = 'json'
    }
    
    # Create file in appropriate format
    if ($Format -eq 'psd1')
    {
        # Use Export-PowerShellDataFile if available, otherwise fallback
        if (Get-Command Export-PowerShellDataFile -ErrorAction SilentlyContinue)
        {
            Export-PowerShellDataFile -InputObject $defaultSettings -Path $Path -Force | Out-Null
        }
        else
        {
            # Fallback: Use Import-PowerShellDataFile's reverse operation
            # Create a temporary script that outputs the hashtable
            $tempScript = @"
@{
$(ConvertTo-Psd1String -Hashtable $defaultSettings -IndentLevel 1)
}
"@
            $tempScript | Set-Content -Path $Path
        }
    }
    else
    {
        # JSON format (legacy support)
        $defaultSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $Path
    }
    
    return $Path
}

# Helper function to convert hashtable to PSD1 string (fallback)
function ConvertTo-Psd1String
{
    param(
        [hashtable]$Hashtable,
        [int]$IndentLevel = 0
    )
    
    $indent = "    " * $IndentLevel
    $result = ""
    
    foreach ($key in $Hashtable.Keys)
    {
        # Quote keys that contain special characters (dots, spaces, etc.)
        $quotedKey = if ($key -match '[.\s\-@]') { "'$key'" } else { $key }
        
        $value = $Hashtable[$key]
        if ($value -is [hashtable])
        {
            $result += "$indent$quotedKey = @{`n"
            $result += ConvertTo-Psd1String -Hashtable $value -IndentLevel ($IndentLevel + 1)
            $result += "$indent}`n"
        }
        elseif ($value -is [string])
        {
            $result += "$indent$quotedKey = '$value'`n"
        }
        elseif ($value -is [array])
        {
            $result += "$indent$quotedKey = @("
            $arrayItems = $value | ForEach-Object {
                if ($_ -is [string]) { "'$_'" } else { $_ }
            }
            $result += ($arrayItems -join ", ")
            $result += ")`n"
        }
        else
        {
            $result += "$indent$quotedKey = $value`n"
        }
    }
    
    return $result
}

function Remove-TestEnvironment
{
    <#
    .SYNOPSIS
        Cleans up test environment
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$TestContext
    )
    
    if (Test-Path $TestContext.TestFolder)
    {
        Remove-Item -Path $TestContext.TestFolder -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    }
}

#region Common Mock Functions

<#
.SYNOPSIS
    Creates a mock Write-Log function

.DESCRIPTION
    Provides a standardized mock of the Write-Log function that outputs
    to verbose stream instead of a log file

.PARAMETER CaptureOutput
    If specified, captures log messages in script variable for assertions

.EXAMPLE
    New-MockWriteLog
    # Creates global Write-Log mock

.EXAMPLE
    New-MockWriteLog -CaptureOutput
    # Captures logs in $script:MockLogMessages
#>
function New-MockWriteLog
{
    [CmdletBinding()]
    param(
        [switch]$CaptureOutput
    )
    
    if ($CaptureOutput)
    {
        $script:MockLogMessages = @()
    }
    
    $script:MockWriteLogFunction = {
        param($LogFile, $Module, $Message, $LogLevel = "Info")
        
        $logEntry = "[Write-Log][$LogLevel][$Module] $Message"
        Write-Verbose $logEntry
        
        if ($CaptureOutput)
        {
            $script:MockLogMessages += @{
                LogFile  = $LogFile
                Module   = $Module
                Message  = $Message
                LogLevel = $LogLevel
                Time     = Get-Date
            }
        }
    }
    
    New-Item -Path "Function:\global:Write-Log" -Value $script:MockWriteLogFunction -Force | Out-Null
    Write-Verbose "[New-MockWriteLog] Write-Log mock registered"
}

<#
.SYNOPSIS
    Gets captured log messages from Write-Log mock

.EXAMPLE
    $logs = Get-MockLogMessages
#>
function Get-MockLogMessages
{
    [CmdletBinding()]
    param()
    
    return $script:MockLogMessages
}

<#
.SYNOPSIS
    Clears captured log messages

.EXAMPLE
    Clear-MockLogMessages
#>
function Clear-MockLogMessages
{
    [CmdletBinding()]
    param()
    
    $script:MockLogMessages = @()
}

<#
.SYNOPSIS
    Initializes common global variables used by Autopilot functions

.DESCRIPTION
    Sets up standard global variables like $LogFile, $settings, and $returnValues
    that are commonly needed across tests

.PARAMETER LogFile
    Custom log file path. Defaults to temp location

.PARAMETER Settings
    Custom settings hashtable. Merged with defaults

.PARAMETER IncludeReturnValues
    Include return values hashtable initialization

.EXAMPLE
    Initialize-MockGlobalVariables
    # Sets up with defaults

.EXAMPLE
    Initialize-MockGlobalVariables -Settings @{appMode="admin"}
    # Sets up with custom app mode
#>
function Initialize-MockGlobalVariables
{
    [CmdletBinding()]
    param(
        [string]$LogFile = $null,
        [hashtable]$Settings = @{},
        [switch]$IncludeReturnValues
    )
    
    # Set log file
    if (-not $LogFile)
    {
        $LogFile = Join-Path $env:TEMP "autopilot-test-$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    }
    $Global:LogFile = $LogFile
    
    # Initialize settings with defaults
    $defaultSettings = @{
        appMode              = "helpdesk"
        maxUserMatchDisplay  = 10
        maxGroupMatchDisplay = 10
        logLevel             = "Info"
    }
    
    # Merge custom settings
    foreach ($key in $Settings.Keys)
    {
        $defaultSettings[$key] = $Settings[$key]
    }
    
    $Global:settings = $defaultSettings
    
    # Initialize return values if requested
    if ($IncludeReturnValues)
    {
        $Global:returnValues = @{
            noUserFoundInDirectoryMessage = 0
            noGroupFoundMessage           = 0
            userCanceledMessage           = 0
            mainMenuMessage               = 1
            backMessage                   = 2
            exitMessage                   = 3
            continueMessage               = 4
        }
    }
    
    Write-Verbose "[Initialize-MockGlobalVariables] Global variables initialized"
}

<#
.SYNOPSIS
    Clears common global variables

.EXAMPLE
    Clear-MockGlobalVariables
#>
function Clear-MockGlobalVariables
{
    [CmdletBinding()]
    param()
    
    Remove-Variable -Name LogFile -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name settings -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name returnValues -Scope Global -ErrorAction SilentlyContinue
    
    Write-Verbose "[Clear-MockGlobalVariables] Global variables cleared"
}

#endregion

# Export functions
Export-ModuleMember -Function @(
    'Initialize-AutopilotTestEnvironment',
    'Import-AutopilotFunctions',
    'New-MockSettingsFile',
    'Remove-TestEnvironment',
    'New-MockWriteLog',
    'Get-MockLogMessages',
    'Clear-MockLogMessages',
    'Initialize-MockGlobalVariables',
    'Clear-MockGlobalVariables'
)

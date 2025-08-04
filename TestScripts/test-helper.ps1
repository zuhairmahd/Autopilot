# Comprehensive Test Helper Framework
# This file provides a unified testing framework for all test scripts

function Load-AllFunctions {
    <#
    .SYNOPSIS
        Loads all functions from the reorganized functions folder structure
    .DESCRIPTION
        This function recursively loads all PowerShell function files from the functions folder
        to support the reorganized codebase structure with enhanced error handling and reporting
    #>
    param(
        [string]$RootPath = $null,
        [switch]$VerboseLoading = $false
    )
    
    if (-not $RootPath) {
        $RootPath = Split-Path -Parent $PSScriptRoot
    }
    
    $functionsFolder = Join-Path $RootPath "functions"
    
    if (-not (Test-Path $functionsFolder)) {
        throw "Functions folder not found at: $functionsFolder"
    }
    
    if ($VerboseLoading) {
        Write-Host "Loading functions from: $functionsFolder" -ForegroundColor Gray
    }
    
    try {
        # Get all .ps1 files recursively, excluding test files
        $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -Recurse -ErrorAction Stop | 
                     Where-Object { $_.Name -notlike 'test-*' }
        
        $loadedCount = 0
        $errorCount = 0
        $skippedCount = 0
        
        foreach ($function in $functions) {
            try {
                # Skip if already loaded (check for function definitions)
                $functionContent = Get-Content $function.FullName -Raw -ErrorAction Stop
                
                # Extract function names from the file
                $functionNames = [regex]::Matches($functionContent, 'function\s+([a-zA-Z0-9_-]+)') | 
                                ForEach-Object { $_.Groups[1].Value }
                
                # Check if any of these functions are already loaded
                $alreadyLoaded = $false
                foreach ($funcName in $functionNames) {
                    if (Get-Command $funcName -ErrorAction SilentlyContinue) {
                        $alreadyLoaded = $true
                        break
                    }
                }
                
                if ($alreadyLoaded) {
                    $skippedCount++
                    if ($VerboseLoading) {
                        Write-Host "  Skipped (already loaded): $($function.Name)" -ForegroundColor Yellow
                    }
                    continue
                }
                
                if ($VerboseLoading) {
                    Write-Host "  Loading: $($function.Name)" -ForegroundColor Gray
                }
                
                # Dot-source the function file
                . $function.FullName
                $loadedCount++
                
                if ($VerboseLoading) {
                    foreach ($funcName in $functionNames) {
                        if (Get-Command $funcName -ErrorAction SilentlyContinue) {
                            Write-Host "    + Function available: $funcName" -ForegroundColor Green
                        }
                    }
                }
            }
            catch {
                $errorCount++
                Write-Warning "Failed to load $($function.Name): $($_.Exception.Message)"
                if ($VerboseLoading) {
                    Write-Host $_.ScriptStackTrace -ForegroundColor Red
                }
            }
        }
        
        $totalFiles = $functions.Count
        Write-Host "Function loading summary: $loadedCount loaded, $skippedCount skipped, $errorCount errors (Total: $totalFiles files)" -ForegroundColor Cyan
        
        if ($errorCount -gt 0) {
            Write-Warning "Some function files failed to load. Tests may fail if they depend on these functions."
        }
        
        return $loadedCount -gt 0 -or $skippedCount -gt 0
    }
    catch {
        Write-Error "Failed to enumerate functions: $($_.Exception.Message)"
        return $false
    }
}

function Initialize-TestEnvironment {
    <#
    .SYNOPSIS
        Initializes the test environment with common variables, settings, and mock data
    .DESCRIPTION
        Sets up global variables, mock data, and configuration needed by most tests
    #>
    param(
        [string]$TestName = "Unknown Test",
        [string]$RootPath = $null
    )
    
    if (-not $RootPath) {
        $RootPath = Split-Path -Parent $PSScriptRoot
    }
    
    Write-TestSection "Initializing Test Environment: $TestName"
    
    # Set up global variables commonly used by functions
    $global:LogFile = "test.log"
    $global:SettingsFilePath = Join-Path $RootPath "settings.json"
    $global:StringsFilePath = Join-Path $RootPath "strings.json"
    $global:ConfigPath = Join-Path $RootPath ".secrets\config.json"
    
    # Initialize menu history for menu tests
    if (-not $global:MenuHistory) {
        $global:MenuHistory = [System.Collections.ArrayList]::new()
    }
    if (-not $global:History) {
        $global:History = [System.Collections.ArrayList]::new()
    }
    
    # Load mock strings data commonly needed by tests
    try {
        if (Test-Path $global:StringsFilePath) {
            $global:loadedStrings = Get-Content $global:StringsFilePath | ConvertFrom-Json
        } else {
            # Create minimal mock strings data
            $global:loadedStrings = @{
                deviceStates = @{
                    ready = "Device ready"
                    notReady = "Device not ready"
                    error = "Device error"
                }
                deviceActions = @{
                    contactAdmin = "Contact your administrator"
                    waitAndRetry = "Wait and retry"
                    checkSettings = "Check device settings"
                }
                menuItems = @{
                    mainMenu = "Main Menu"
                    exitMenu = "Exit"
                }
            }
        }
        
        # Make common variables available globally for backward compatibility
        $global:deviceStates = $global:loadedStrings.deviceStates
        $global:deviceActions = $global:loadedStrings.deviceActions
        
        Write-TestResult "Mock data initialized successfully" $true
    }
    catch {
        Write-TestResult "Failed to initialize mock data: $($_.Exception.Message)" $false
        # Continue with empty mock data
        $global:loadedStrings = @{}
        $global:deviceStates = @{}
        $global:deviceActions = @{}
    }
    
    # Set common error handling
    $script:OriginalErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Stop'
    
    Write-TestResult "Test environment initialized" $true
}

function Cleanup-TestEnvironment {
    <#
    .SYNOPSIS
        Cleans up test environment and temporary files
    #>
    param(
        [string]$TestFolder = $null
    )
    
    try {
        # Restore original error action preference
        if ($script:OriginalErrorActionPreference) {
            $ErrorActionPreference = $script:OriginalErrorActionPreference
        }
        
        # Clean up test folder if specified
        if ($TestFolder -and (Test-Path $TestFolder)) {
            Remove-Item -Path $TestFolder -Recurse -Force -ErrorAction SilentlyContinue
            Write-TestResult "Test folder cleaned up" $true
        }
        
        # Clean up global test variables (but preserve the important ones)
        if (Get-Variable -Name "loadedStrings" -Scope Global -ErrorAction SilentlyContinue) {
            Remove-Variable -Name "loadedStrings" -Scope Global -Force -ErrorAction SilentlyContinue
        }
        
    }
    catch {
        Write-Warning "Error during cleanup: $($_.Exception.Message)"
    }
}

function New-MockDevice {
    <#
    .SYNOPSIS
        Creates mock device data for testing
    #>
    param(
        [string]$DeviceId = "test-device-123",
        [string]$DeviceName = "TEST-DEVICE",
        [string]$SerialNumber = "ABC123",
        [bool]$IsReady = $true,
        [string[]]$Issues = @()
    )
    
    return @{
        id = $DeviceId
        deviceName = $DeviceName
        serialNumber = $SerialNumber
        isReady = $IsReady
        issues = $Issues
        managedDevice = @{
            device = @{
                deviceName = $DeviceName
                id = $DeviceId
            }
        }
        autopilotDevice = @{
            serialNumber = $SerialNumber
            id = $DeviceId
        }
    }
}

function Test-FunctionExists {
    <#
    .SYNOPSIS
        Tests if a function is available in the current session
    #>
    param(
        [string]$FunctionName
    )
    
    $command = Get-Command $FunctionName -ErrorAction SilentlyContinue
    return $null -ne $command
}

function Test-PowerShellVersion {
    <#
    .SYNOPSIS
        Tests if we're running PowerShell 5.1 and returns compatibility info
    .DESCRIPTION
        Checks PowerShell version and returns information about Unicode support
        and other version-specific capabilities
    #>
    
    $version = $PSVersionTable.PSVersion
    $isPS51 = $version.Major -eq 5 -and $version.Minor -eq 1
    $supportsUnicode = -not $isPS51
    
    return @{
        Version = $version
        IsPS51 = $isPS51
        SupportsUnicode = $supportsUnicode
        MajorVersion = $version.Major
        MinorVersion = $version.Minor
    }
}

function Write-TestResult {
    <#
    .SYNOPSIS
        Writes test results with PowerShell 5.1 compatibility
    .DESCRIPTION
        Displays test results using appropriate characters based on PowerShell version
    #>
    param(
        [string]$Message,
        [bool]$Success,
        [string]$ForegroundColor = $null
    )
    
    $psInfo = Test-PowerShellVersion
    
    if ($Success) {
        $symbol = if ($psInfo.SupportsUnicode) { "✓" } else { "[PASS]" }
        $color = if ($ForegroundColor) { $ForegroundColor } else { "Green" }
    } else {
        $symbol = if ($psInfo.SupportsUnicode) { "✗" } else { "[FAIL]" }
        $color = if ($ForegroundColor) { $ForegroundColor } else { "Red" }
    }
    
    Write-Host "$symbol $Message" -ForegroundColor $color
}

function Write-TestSection {
    <#
    .SYNOPSIS
        Writes a test section header with PowerShell 5.1 compatibility
    #>
    param(
        [string]$Title,
        [string]$ForegroundColor = "Yellow"
    )
    
    Write-Host "`n=== $Title ===" -ForegroundColor $ForegroundColor
}

function Start-UnifiedTest {
    <#
    .SYNOPSIS
        Unified test initialization that sets up everything needed for a test
    .DESCRIPTION  
        This function combines all initialization steps into one convenient call:
        - Loads all functions from the reorganized structure
        - Initializes test environment with mock data
        - Sets up logging and error handling
        - Returns a test context object for cleanup
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$TestName,
        
        [string]$TestFolder = $null,
        [string]$RootPath = $null,
        [switch]$VerboseLoading = $false
    )
    
    Write-Host "Starting Unified Test: $TestName" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Cyan
    
    # Determine paths
    if (-not $RootPath) {
        $RootPath = Split-Path -Parent $PSScriptRoot
    }
    
    # Create test folder if specified
    if ($TestFolder) {
        if (Test-Path $TestFolder) {
            Remove-Item -Path $TestFolder -Recurse -Force
        }
        New-Item -Path $TestFolder -ItemType Directory -Force | Out-Null
        Write-TestResult "Test folder created: $TestFolder" $true
    }
    
    # Load all functions
    Write-TestSection "Loading Functions"
    try {
        $loadSuccess = Load-AllFunctions -RootPath $RootPath -VerboseLoading:$VerboseLoading
        if (-not $loadSuccess) {
            throw "Function loading failed"
        }
        Write-TestResult "Functions loaded successfully" $true
    }
    catch {
        Write-TestResult "Failed to load functions: $($_.Exception.Message)" $false
        throw
    }
    
    # Initialize test environment
    try {
        Initialize-TestEnvironment -TestName $TestName -RootPath $RootPath
        Write-TestResult "Test environment initialized" $true
    }
    catch {
        Write-TestResult "Failed to initialize test environment: $($_.Exception.Message)" $false
        throw
    }
    
    # Return test context for cleanup
    return @{
        TestName = $TestName
        TestFolder = $TestFolder 
        RootPath = $RootPath
        StartTime = Get-Date
    }
}

function Complete-UnifiedTest {
    <#
    .SYNOPSIS
        Unified test cleanup and completion
    .DESCRIPTION
        Handles cleanup and provides test completion summary
    #>
    param(
        [Parameter(Mandatory = $true)]
        $TestContext,
        
        [int]$PassedTests = 0,
        [int]$FailedTests = 0,
        [int]$TotalTests = 0
    )
    
    $duration = (Get-Date) - $TestContext.StartTime
    
    Write-Host "`n" -NoNewline
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host "Test Completion Summary: $($TestContext.TestName)" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Cyan
    
    if ($TotalTests -gt 0) {
        Write-Host "Tests Passed: $PassedTests" -ForegroundColor Green
        Write-Host "Tests Failed: $FailedTests" -ForegroundColor Red  
        Write-Host "Total Tests: $TotalTests" -ForegroundColor Yellow
        Write-Host "Success Rate: $(($PassedTests / $TotalTests * 100).ToString('F1'))%" -ForegroundColor Cyan
    }
    
    Write-Host "Duration: $($duration.TotalSeconds.ToString('F2')) seconds" -ForegroundColor Gray
    
    # Cleanup
    try {
        Cleanup-TestEnvironment -TestFolder $TestContext.TestFolder
        Write-TestResult "Cleanup completed successfully" $true
    }
    catch {
        Write-TestResult "Cleanup failed: $($_.Exception.Message)" $false
    }
    
    $success = $FailedTests -eq 0
    Write-TestResult "Overall Test Result: $(if ($success) { 'SUCCESS' } else { 'FAILURE' })" $success
    
    return $success
}
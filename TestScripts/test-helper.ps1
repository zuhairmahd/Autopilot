# Comprehensive Test Helper Framework
# This file provides a unified testing framework for all test scripts

function Load-AllFunctions()
{
    <#
    .SYNOPSIS
        Loads all functions from the reorganized functions folder structure
    .DESCRIPTION
        This function recursively loads all PowerShell function files from the functions folder
        to support the reorganized codebase structure with enhanced error handling and reporting
        NOTE: This function returns a script block that should be invoked at script level
    #>
    param(
        [string]$RootPath = $null,
        [switch]$VerboseLoading = $false,
        [switch]$ReturnScriptBlock = $false
    )
    
    if (-not $RootPath)
    {
        $RootPath = Split-Path -Parent $PSScriptRoot
    }
    
    $functionsFolder = Join-Path $RootPath "functions"
    
    if (-not (Test-Path $functionsFolder))
    {
        throw "Functions folder not found at: $functionsFolder"
    }
    
    if ($VerboseLoading)
    {
        Write-Host "Loading functions from: $functionsFolder" -ForegroundColor Gray
    }
    
    try
    {
        # Get all .ps1 files recursively, excluding test files - same as main.ps1
        $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -Recurse -ErrorAction Stop
        
        $loadedCount = 0
        $errorCount = 0
        $scriptBlockCommands = @()
        
        foreach ($function in $functions)
        {
            try
            {
                if ($VerboseLoading)
                {
                    Write-Host "  Loading: $($function.Name)" -ForegroundColor Gray
                }
                
                if ($ReturnScriptBlock) {
                    # Add to script block for execution at caller level
                    $scriptBlockCommands += ". '$($function.FullName)'"
                } else {
                    # Use global scope specification to ensure functions are defined globally
                    $functionContent = Get-Content $function.FullName -Raw
                    $Global:ExecutionContext.InvokeCommand.InvokeScript($false, [scriptblock]::Create($functionContent), $null, $null)
                }
                $loadedCount++
                
                if ($VerboseLoading -and -not $ReturnScriptBlock)
                {
                    # Extract function names from the file for verification
                    $functionContent = Get-Content $function.FullName -Raw -ErrorAction SilentlyContinue
                    if ($functionContent)
                    {
                        $functionNames = [regex]::Matches($functionContent, 'function\s+([a-zA-Z0-9_-]+)') | 
                            ForEach-Object { $_.Groups[1].Value }
                        
                        foreach ($funcName in $functionNames)
                        {
                            if (Get-Command $funcName -ErrorAction SilentlyContinue)
                            {
                                Write-Host "    + Function available: $funcName" -ForegroundColor Green
                            }
                        }
                    }
                }
            }
            catch
            {
                $errorCount++
                Write-Warning "Failed to load $($function.Name): $($_.Exception.Message)"
                if ($VerboseLoading)
                {
                    Write-Host $_.ScriptStackTrace -ForegroundColor Red
                }
            }
        }
        
        if ($ReturnScriptBlock) {
            return [scriptblock]::Create($scriptBlockCommands -join "`n")
        }
        
        $totalFiles = $functions.Count
        Write-Host "Function loading summary: $loadedCount loaded, 0 skipped, $errorCount errors (Total: $totalFiles files)" -ForegroundColor Cyan
        
        if ($errorCount -gt 0)
        {
            Write-Warning "Some function files failed to load. Tests may fail if they depend on these functions."
        }
        
        return $loadedCount -gt 0
    }
    catch
    {
        Write-Error "Failed to enumerate functions: $($_.Exception.Message)"
        return $false
    }
}

function Initialize-TestEnvironment()
{
    <#
    .SYNOPSIS
        Initializes the test environment with common variables, settings, and mock data
    .DESCRIPTION
        Sets up global variables, mock data, and configuration needed by most tests
    #>
    param(
        [string]$TestName = "Unknown Test",
        [string]$RootPath = $null,
        [string]$TestFolder = $null
    )
    
    if (-not $RootPath)
    {
        $RootPath = Split-Path -Parent $PSScriptRoot
        if (-not $RootPath)
        {
            $RootPath = $PWD
        }
    }
    
    Write-TestSection "Initializing Test Environment: $TestName"
    
    # Set up global variables commonly used by functions
    $tempDir = if ($IsWindows)
    {
        $env:TEMP 
    }
    else
    {
        "/tmp" 
    }
    
    # Use test folder for logs if available, otherwise system temp
    $logBaseDir = if ($TestFolder) { $TestFolder } else { $tempDir }
    
    # Simplified: only validate that the intended log file path is syntactically valid.
    # No file or directory creation; no side effects beyond setting globals.
    $logCandidate = if ($global:LogFile -and [string]::IsNullOrWhiteSpace([string]$global:LogFile) -eq $false)
    {
        [string]$global:LogFile
    }
    else
    {
        Join-Path $logBaseDir "test.log"
    }
    try
    {
        # Throws if path contains invalid characters or format
        $null = [System.IO.Path]::GetFullPath($logCandidate)
        $global:LogFile = $logCandidate
        $global:logFile = $global:LogFile  # Lowercase alias for compatibility
    }
    catch
    {
        Write-Warning "Invalid LogFile path specified: '$logCandidate'. Continuing without a log file path."
        $global:LogFile = $null
        $global:logFile = $null
    }
    $global:jsonDepth = 100  # Standard JSON depth for settings files
    $global:SettingsFilePath = Join-Path $RootPath "settings.json"
    $global:StringsFilePath = Join-Path $RootPath "strings.json"
    $global:ConfigPath = Join-Path $RootPath ".secrets\config.json"
    
    # Initialize menu history for menu tests
    if (-not $global:MenuHistory)
    {
        $global:MenuHistory = [System.Collections.ArrayList]::new()
    }
    if (-not $global:History)
    {
        $global:History = [System.Collections.ArrayList]::new()
    }
    
    # Load mock strings data commonly needed by tests
    try
    {
        if (Test-Path $global:StringsFilePath)
        {
            $global:loadedStrings = Get-Content $global:StringsFilePath | ConvertFrom-Json
        }
        else
        {
            # Create minimal mock strings data
            $global:loadedStrings = @{
                deviceStates  = @{
                    ready    = "Device ready"
                    notReady = "Device not ready"
                    error    = "Device error"
                }
                deviceActions = @{
                    contactAdmin  = "Contact your administrator"
                    waitAndRetry  = "Wait and retry"
                    checkSettings = "Check device settings"
                }
                menuItems     = @{
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
    catch
    {
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

function Cleanup-TestEnvironment()
{
    <#
    .SYNOPSIS
        Cleans up test environment and temporary files
    #>
    param(
        [string]$TestFolder = $null
    )
    try
    {
        # Restore original error action preference
        if ($script:OriginalErrorActionPreference)
        {
            $ErrorActionPreference = $script:OriginalErrorActionPreference
        }
        
        # Clean up test folder if specified
        if ($TestFolder -and (Test-Path -LiteralPath $TestFolder))
        {
            try
            {
                # If current location is inside the test folder, move out to avoid lock
                try
                {
                    $currentPath = (Get-Location).Path
                    if ($currentPath -like (Join-Path $TestFolder '*'))
                    {
                        $fallback = if ($env:TEMP)
                        {
                            $env:TEMP 
                        }
                        else
                        {
                            [Environment]::GetFolderPath('UserProfile') 
                        }
                        Set-Location -Path $fallback -ErrorAction SilentlyContinue
                    }
                }
                catch
                { 
                }

                # Clear read-only/system attributes that can block deletion on Windows
                try
                {
                    $items = Get-ChildItem -LiteralPath $TestFolder -Recurse -Force -ErrorAction SilentlyContinue
                    foreach ($item in $items)
                    {
                        try
                        {
                            $item.Attributes = 'Normal' 
                        }
                        catch
                        { 
                        }
                    }
                    try
                    {
                        $folderItem = Get-Item -LiteralPath $TestFolder -Force -ErrorAction SilentlyContinue
                        if ($folderItem)
                        {
                            try
                            {
                                $folderItem.Attributes = 'Normal' 
                            }
                            catch
                            { 
                            } 
                        }
                    }
                    catch
                    { 
                    }
                }
                catch
                { 
                }

                # Attempt deletion with strict error handling
                Remove-Item -LiteralPath $TestFolder -Recurse -Force -ErrorAction Stop

                # Verify deletion
                if (Test-Path -LiteralPath $TestFolder)
                {
                    Write-TestResult "Test folder not fully removed: $TestFolder" $false
                }
                else
                {
                    Write-TestResult "Test folder cleaned up" $true
                }
            }
            catch
            {
                Write-Warning "Error cleaning up test folder: $($_.Exception.Message)"
                Write-TestResult "Test folder cleanup failed: $TestFolder" $false
            }
        }
        
        # Clean up global test variables (but preserve the important ones)
        if (Get-Variable -Name "loadedStrings" -Scope Global -ErrorAction SilentlyContinue)
        {
            Remove-Variable -Name "loadedStrings" -Scope Global -Force -ErrorAction SilentlyContinue
        }
    }
    catch
    {
        Write-Warning "Error during cleanup: $($_.Exception.Message)"
    }
}

function New-MockDevice()
{
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
        id              = $DeviceId
        deviceName      = $DeviceName
        serialNumber    = $SerialNumber
        isReady         = $IsReady
        issues          = $Issues
        managedDevice   = @{
            device = @{
                deviceName = $DeviceName
                id         = $DeviceId
            }
        }
        autopilotDevice = @{
            serialNumber = $SerialNumber
            id           = $DeviceId
        }
    }
}

function New-MockSettingsFile()
{
    <#
    .SYNOPSIS
        Creates a mock settings.psd1 file in the test folder
    .DESCRIPTION
        Creates a properly formatted settings file with optional content for testing
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$TestFolder,
        [string]$FileName = "test-settings.psd1",
        [hashtable]$CustomContent = @{},
        [switch]$IncludeAuth
    )
    
    $filePath = Join-Path $TestFolder $FileName
    
    # Base settings structure
    $settings = @{
        description = "Test settings file"
        version = "1.0.0"
        globalSettings = @{
            appMode = "test"
        }
    }
    
    # Add auth section if requested
    if ($IncludeAuth) {
        $settings.auth = @{
            changePwOnNextStart = $false
            authType = "PublicAuthFlow"
            noSaveRefreshToken = $false
            forceNewToken = $false
            renewalLeadTime = 5
            scope = @("offline_access", "openid", "Device.ReadWrite.All", "DeviceManagementManagedDevices.ReadWrite.All", "User.Read.All", "DeviceManagementServiceConfig.ReadWrite.All", "DeviceManagementApps.Read.All")
            cacheType = "FileSystem"
            secureString = $true
            delegated = $true
        }
    }
    
    # Merge custom content
    foreach ($key in $CustomContent.Keys) {
        $settings[$key] = $CustomContent[$key]
    }
    
    # Export to PSD1 format using Export-PowerShellDataFile
    try {
        $exportResult = Export-PowerShellDataFile -InputObject $settings -Path $filePath -Force
        if ($exportResult) {
            return $filePath
        } else {
            throw "Export-PowerShellDataFile failed"
        }
    }
    catch {
        # Fallback: create using direct PSD1 content
        $psd1Content = "@{`n"
        $psd1Content += "    description = '$($settings.description)'`n"
        $psd1Content += "    version = '$($settings.version)'`n"
        $psd1Content += "    globalSettings = @{`n"
        $psd1Content += "        appMode = '$($settings.globalSettings.appMode)'`n"
        $psd1Content += "    }`n"
        
        if ($IncludeAuth) {
            $psd1Content += "    auth = @{`n"
            $psd1Content += "        changePwOnNextStart = `$$($settings.auth.changePwOnNextStart)`n"
            $psd1Content += "        authType = '$($settings.auth.authType)'`n"
            $psd1Content += "        noSaveRefreshToken = `$$($settings.auth.noSaveRefreshToken)`n"
            $psd1Content += "        forceNewToken = `$$($settings.auth.forceNewToken)`n"
            $psd1Content += "        renewalLeadTime = $($settings.auth.renewalLeadTime)`n"
            $psd1Content += "        scope = @(`n"
            foreach ($scope in $settings.auth.scope) {
                $psd1Content += "            '$scope',`n"
            }
            $psd1Content = $psd1Content.TrimEnd(",`n") + "`n"
            $psd1Content += "        )`n"
            $psd1Content += "        cacheType = '$($settings.auth.cacheType)'`n"
            $psd1Content += "        secureString = `$$($settings.auth.secureString)`n"
            $psd1Content += "        delegated = `$$($settings.auth.delegated)`n"
            $psd1Content += "    }`n"
        }
        
        $psd1Content += "}"
        
        Set-Content -Path $filePath -Value $psd1Content -Force
        return $filePath
    }
}

function Test-FunctionExists()
{
    <#
    .SYNOPSIS
        Tests if a function is available in the current session
    #>
    param(
        [string]$FunctionName
    )
    
    try
    {
        $command = Get-Command $FunctionName -ErrorAction SilentlyContinue
        $result = $null -ne $command
        Write-Verbose "Test-FunctionExists: $FunctionName = $result"
        return $result
    }
    catch
    {
        Write-Verbose "Test-FunctionExists: Error testing $FunctionName - $($_.Exception.Message)"
        return $false
    }
}

function Test-PowerShellVersion()
{
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
        Version         = $version
        IsPS51          = $isPS51
        SupportsUnicode = $supportsUnicode
        MajorVersion    = $version.Major
        MinorVersion    = $version.Minor
    }
}

function Write-TestResult()
{
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
    
    if ($Success)
    {
        $symbol = if ($psInfo.SupportsUnicode)
        {
            "✓" 
        }
        else
        {
            "[PASS]" 
        }
        $color = if ($ForegroundColor)
        {
            $ForegroundColor 
        }
        else
        {
            "Green" 
        }
    }
    else
    {
        $symbol = if ($psInfo.SupportsUnicode)
        {
            "✗" 
        }
        else
        {
            "[FAIL]" 
        }
        $color = if ($ForegroundColor)
        {
            $ForegroundColor 
        }
        else
        {
            "Red" 
        }
    }
    
    Write-Host "$symbol $Message" -ForegroundColor $color
}

function Write-TestSection()
{
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

function Write-TestSubSection()
{
    <#
    .SYNOPSIS
        Writes a test subsection header with PowerShell 5.1 compatibility
    #>
    param(
        [string]$Title,
        [string]$ForegroundColor = "Cyan"
    )
    
    Write-Host "`n--- $Title ---" -ForegroundColor $ForegroundColor
}

function Start-UnifiedTest()
{
    <#
    .SYNOPSIS
        Unified test initialization that sets up everything needed for a test EXCEPT function loading
    .DESCRIPTION  
        This function combines initialization steps but expects functions to be loaded 
        at the script level to avoid scoping issues. Function loading should be done
        using the Load-AllFunctions at the script level before calling this function.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$TestName,
        
        [string]$TestFolder = $null,
        [string]$RootPath = $null,
        [switch]$SkipFunctionCheck = $false
    )
    
    Write-Host "Starting Unified Test: $TestName" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Cyan
    
    # Determine paths
    if (-not $RootPath)
    {
        $RootPath = Split-Path -Parent $PSScriptRoot
    }
    
    # Create test folder - use system temp if not specified
    if (-not $TestFolder)
    {
        $tempDir = if ($IsWindows) { $env:TEMP } else { "/tmp" }
        $TestFolder = Join-Path $tempDir "autopilot-test-$(Get-Random)"
        Write-TestResult "Auto-generated test folder: $TestFolder" $true
    }
    
    if ($TestFolder)
    {
        if (Test-Path $TestFolder)
        {
            Remove-Item -Path $TestFolder -Recurse -Force
        }
        New-Item -Path $TestFolder -ItemType Directory -Force | Out-Null
        Write-TestResult "Test folder created: $TestFolder" $true
    }
    
    # Check if functions are loaded (optional check)
    if (-not $SkipFunctionCheck)
    {
        Write-TestSection "Checking Function Availability"
        $coreFunction = Get-Command "Write-Log" -ErrorAction SilentlyContinue
        if ($coreFunction)
        {
            Write-TestResult "Functions appear to be loaded (Write-Log found)" $true
        }
        else
        {
            Write-TestResult "Functions may not be loaded - continuing anyway" $true
        }
    }
    
    # Initialize test environment
    try
    {
        Initialize-TestEnvironment -TestName $TestName -RootPath $RootPath -TestFolder $TestFolder
        Write-TestResult "Test environment initialized" $true
    }
    catch
    {
        Write-TestResult "Failed to initialize test environment: $($_.Exception.Message)" $false
        throw
    }
    
    # Return test context for cleanup
    return @{
        TestName   = $TestName
        TestFolder = $TestFolder 
        RootPath   = $RootPath
        StartTime  = Get-Date
    }
}

function Start-UnifiedTest-WithFunctionLoading()
{
    <#
    .SYNOPSIS
        Legacy unified test initialization that includes function loading (has scoping issues)
    .DESCRIPTION  
        This is the old version that loads functions within the function scope.
        Use Start-UnifiedTest and load functions at script level instead.
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
    if (-not $RootPath)
    {
        $RootPath = Split-Path -Parent $PSScriptRoot
    }
    
    # Create test folder - use system temp if not specified
    if (-not $TestFolder)
    {
        $tempDir = if ($IsWindows) { $env:TEMP } else { "/tmp" }
        $TestFolder = Join-Path $tempDir "autopilot-test-$(Get-Random)"
        Write-TestResult "Auto-generated test folder: $TestFolder" $true
    }
    
    if ($TestFolder)
    {
        if (Test-Path $TestFolder)
        {
            Remove-Item -Path $TestFolder -Recurse -Force
        }
        New-Item -Path $TestFolder -ItemType Directory -Force | Out-Null
        Write-TestResult "Test folder created: $TestFolder" $true
    }
    
    # Load all functions
    Write-TestSection "Loading Functions"
    try
    {
        $loadSuccess = Load-AllFunctions -RootPath $RootPath -VerboseLoading:$VerboseLoading
        if (-not $loadSuccess)
        {
            throw "Function loading failed"
        }
        Write-TestResult "Functions loaded successfully" $true
    }
    catch
    {
        Write-TestResult "Failed to load functions: $($_.Exception.Message)" $false
        throw
    }
    
    # Initialize test environment
    try
    {
        Initialize-TestEnvironment -TestName $TestName -RootPath $RootPath -TestFolder $TestFolder
        Write-TestResult "Test environment initialized" $true
    }
    catch
    {
        Write-TestResult "Failed to initialize test environment: $($_.Exception.Message)" $false
        throw
    }
    
    # Return test context for cleanup
    return @{
        TestName   = $TestName
        TestFolder = $TestFolder 
        RootPath   = $RootPath
        StartTime  = Get-Date
    }
}

function Complete-UnifiedTest()
{
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
    
    if ($TotalTests -gt 0)
    {
        Write-Host "Tests Passed: $PassedTests" -ForegroundColor Green
        Write-Host "Tests Failed: $FailedTests" -ForegroundColor Red  
        Write-Host "Total Tests: $TotalTests" -ForegroundColor Yellow
        Write-Host "Success Rate: $(($PassedTests / $TotalTests * 100).ToString('F1'))%" -ForegroundColor Cyan
    }
    
    Write-Host "Duration: $($duration.TotalSeconds.ToString('F2')) seconds" -ForegroundColor Gray
    
    # Cleanup
    try
    {
        Cleanup-TestEnvironment -TestFolder $TestContext.TestFolder
        Write-TestResult "Cleanup completed successfully" $true
    }
    catch
    {
        Write-TestResult "Cleanup failed: $($_.Exception.Message)" $false
    }
    
    $success = $FailedTests -eq 0
    Write-TestResult "Overall Test Result: $(if ($success) { 'SUCCESS' } else { 'FAILURE' })" $success
    
    return $success
}
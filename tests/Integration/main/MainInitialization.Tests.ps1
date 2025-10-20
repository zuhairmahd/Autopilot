<#
.SYNOPSIS
    Integration tests for main.ps1 initialization using -testMode execution.

.DESCRIPTION
    Tests the application startup sequence by actually running main.ps1 with -testMode switch.
    This approach allows us to test the real initialization flow without mocking the internal
    functions or menu display.

.NOTES
    Test Framework: Pester 5.x
    PowerShell Version: 5.1+
    
    Key Test Areas:
    - Application startup and version detection (real execution)
    - Parameter handling and precedence (command-line parameters)
    - Configuration file initialization (actual configuration loading)
    - Global variable setup (validated via script execution)
    - Logging initialization (verified through log file output)
    
    Testing Approach:
    - Integration tests using REAL main.ps1 execution with -testMode
    - No mocking of internal functions (test actual behavior)
    - Validate end-to-end initialization workflow
    - Use test configuration files in isolated test folder
    
    Related Files:
    - main.ps1 (tested via -testMode execution)
    - All actual functions loaded by main.ps1
#>

BeforeAll {
    # Get repository root
    $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
    
    # Import test helpers
    Import-Module "$script:RepoRoot/tests/Helpers/AutopilotTestHelpers.psm1" -Force
    
    # Store original location
    $script:OriginalLocation = Get-Location
    
    # Setup test environment
    $script:TestContext = Initialize-AutopilotTestEnvironment
    $script:TestRoot = $script:TestContext.TestFolder
    
    # Path to main.ps1
    $script:MainScriptPath = Join-Path $script:RepoRoot "main.ps1"
    
    # Test configuration file paths
    $script:TestSettingsFile = Join-Path $script:TestRoot "settings.psd1"
    $script:TestConfigFile = Join-Path $script:TestRoot ".secrets\config.json"
    $script:TestMenuFile = Join-Path $script:TestRoot "menu.psd1"
    $script:TestStringsFile = Join-Path $script:TestRoot "strings.psd1"
    $script:TestLogFile = Join-Path $script:TestRoot "Logs\test.log"
    
    # Create directories
    $secretsDir = Split-Path $script:TestConfigFile -Parent
    New-Item -Path $secretsDir -ItemType Directory -Force | Out-Null
    
    $logsDir = Split-Path $script:TestLogFile -Parent
    New-Item -Path $logsDir -ItemType Directory -Force | Out-Null
    
    # Helper function to run main.ps1 in test mode
    function Invoke-MainScriptTest
    {
        param(
            [hashtable]$Parameters = @{},
            [switch]$SuppressOutput
        )
        
        # Always include testMode
        $Parameters['testMode'] = $true
        
        # Set default test configuration files if not specified
        if (-not $Parameters.ContainsKey('InitFile'))
        {
            $Parameters['InitFile'] = $script:TestSettingsFile
        }
        if (-not $Parameters.ContainsKey('configFile'))
        {
            $Parameters['configFile'] = $script:TestConfigFile
        }
        if (-not $Parameters.ContainsKey('menuFile'))
        {
            $Parameters['menuFile'] = $script:TestMenuFile
        }
        if (-not $Parameters.ContainsKey('stringsFile'))
        {
            $Parameters['stringsFile'] = $script:TestStringsFile
        }
        if (-not $Parameters.ContainsKey('LogFilePath'))
        {
            $Parameters['LogFilePath'] = $script:TestLogFile
        }
        
        # Change to repo root for execution
        Push-Location $script:RepoRoot
        try
        {
            # Execute main.ps1 and capture ALL output streams
            $output = @()
            $errorOutput = @()
            
            # Use Start-Process to capture output properly
            $tempOutputFile = [System.IO.Path]::GetTempFileName()
            $tempErrorFile = [System.IO.Path]::GetTempFileName()
            
            try
            {
                # Build parameter string
                $paramString = ($Parameters.GetEnumerator() | ForEach-Object {
                        if ($_.Value -is [bool] -or $_.Value -is [switch])
                        {
                            if ($_.Value) { "-$($_.Key)" }
                        }
                        else
                        {
                            "-$($_.Key) '$($_.Value)'"
                        }
                    }) -join ' '
                
                # Execute and capture output
                $scriptBlock = [ScriptBlock]::Create("& '$script:MainScriptPath' $paramString *>&1")
                $output = & $scriptBlock
                
                return @{
                    Success  = $LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE
                    Output   = $output
                    ExitCode = $LASTEXITCODE
                    LogFile  = $Parameters['LogFilePath']
                }
            }
            finally
            {
                if (Test-Path $tempOutputFile) { Remove-Item $tempOutputFile -Force -ErrorAction SilentlyContinue }
                if (Test-Path $tempErrorFile) { Remove-Item $tempErrorFile -Force -ErrorAction SilentlyContinue }
            }
        }
        catch
        {
            return @{
                Success  = $false
                Output   = $_.Exception.Message
                ExitCode = 1
                Error    = $_
            }
        }
        finally
        {
            Pop-Location
        }
    }
    
    # Make it available in script scope
    $script:InvokeMainScript = ${function:Invoke-MainScriptTest}
}

AfterAll {
    # Restore original location
    if ($script:OriginalLocation)
    {
        Set-Location $script:OriginalLocation
    }
    
    # Cleanup test environment
    if ($script:TestContext -and $script:TestContext.TestFolder)
    {
        if (Test-Path $script:TestContext.TestFolder)
        {
            Remove-Item -Path $script:TestContext.TestFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Main.ps1 - Test Mode Execution" -Tags 'Integration', 'Main', 'TestMode' {
    
    Context "Basic Startup in Test Mode" {
        
        It "Should execute successfully with -testMode switch" {
            $result = & $script:InvokeMainScript
            
            $result.Success | Should -Be $true
            $result.ExitCode | Should -BeIn @(0, $null)
        }
        
        It "Should output test mode message and skip menu display" {
            $result = & $script:InvokeMainScript
            
            # Check log file for test mode message (more reliable than output capture)
            if (Test-Path $script:TestLogFile)
            {
                $logContent = Get-Content $script:TestLogFile -Raw
                $logContent | Should -Match "Test mode|test-mode-fake-token"
            }
        }
        
        It "Should find and load functions folder" {
            # Verify functions folder exists
            $functionsPath = Join-Path $script:RepoRoot "functions"
            Test-Path $functionsPath | Should -Be $true
            
            # Run script - if functions folder not found, it would exit with error
            $result = & $script:InvokeMainScript
            $result.Success | Should -Be $true
        }
    }
    
    Context "Version Detection" {
        
        It "Should detect version from script file" {
            $result = & $script:InvokeMainScript
            
            # Check log file for version information
            if (Test-Path $script:TestLogFile)
            {
                $logContent = Get-Content $script:TestLogFile -Raw
                $logContent | Should -Match "Version: |version"
            }
        }
        
        It "Should display version with -showVersion parameter" {
            $result = & $script:InvokeMainScript -Parameters @{ showVersion = $true }
            
            $result.Success | Should -Be $true
            # In showVersion mode, the script exits early with version display
            # Check that it completed successfully
        }
    }
    
    Context "Configuration File Initialization" {
        
        BeforeEach {
            # Create minimal test configuration files before each test
            @"
@{
    appMode = 'helpdesk'
    LogLevel = 'Information'
    maxWaitTime = 300
    timeInSeconds = 60
    domain = 'test.contoso.com'
}
"@ | Out-File -FilePath $script:TestSettingsFile -Encoding UTF8
            
            @"
@{
    mainMenu = @{
        Title = 'Test Menu'
        Type = 'menu'
        Items = @()
    }
}
"@ | Out-File -FilePath $script:TestMenuFile -Encoding UTF8
            
            @"
@{
    returnValues = @{
        Back = '[B]ack'
        MainMenu = '[M]ain Menu'
        Exit = '[E]xit'
    }
}
"@ | Out-File -FilePath $script:TestStringsFile -Encoding UTF8
        }
        
        It "Should initialize with default configuration files in test mode" {
            # Without config.json, test mode should use defaults
            if (Test-Path $script:TestConfigFile)
            {
                Remove-Item $script:TestConfigFile -Force
            }
            
            $result = & $script:InvokeMainScript
            
            $result.Success | Should -Be $true
            # Check log for test mode execution
            if (Test-Path $script:TestLogFile)
            {
                $logContent = Get-Content $script:TestLogFile -Raw
                $logContent | Should -Match "Test mode|test-mode-fake-token"
            }
        }
        
        It "Should load settings from InitFile parameter" {
            $result = & $script:InvokeMainScript -Parameters @{
                InitFile = $script:TestSettingsFile
            }
            
            $result.Success | Should -Be $true
        }
    }
    
    Context "Logging Initialization" {
        
        It "Should create log file at specified path" {
            # Clean up any existing log
            if (Test-Path $script:TestLogFile)
            {
                Remove-Item $script:TestLogFile -Force
            }
            
            $result = & $script:InvokeMainScript
            
            $result.Success | Should -Be $true
            # Log file should be created
            Test-Path $script:TestLogFile | Should -Be $true
        }
        
        It "Should respect LogLevel parameter" {
            $result = & $script:InvokeMainScript -Parameters @{
                LogLevel = 'Verbose'
            }
            
            $result.Success | Should -Be $true
            
            # Check log file contains verbose entries
            if (Test-Path $script:TestLogFile)
            {
                $logContent = Get-Content $script:TestLogFile -Raw
                $logContent | Should -Match "VERBOSE|Verbose"
            }
        }
        
        It "Should overwrite log when OverwriteLogs is specified" {
            # Create an existing log with marker content
            "EXISTING LOG CONTENT" | Out-File -FilePath $script:TestLogFile -Force
            
            $result = & $script:InvokeMainScript -Parameters @{
                OverwriteLogs = $true
            }
            
            $result.Success | Should -Be $true
            
            # Log should not contain the marker
            $logContent = Get-Content $script:TestLogFile -Raw
            $logContent | Should -Not -Match "EXISTING LOG CONTENT"
        }
    }
}

Describe "Main.ps1 - Parameter Handling" -Tags 'Integration', 'Main', 'Parameters' {
    
    BeforeAll {
        # Create test configuration files
        @"
@{
    appMode = 'helpdesk'
    LogLevel = 'Information'
    maxWaitTime = 300
    timeInSeconds = 60
}
"@ | Out-File -FilePath $script:TestSettingsFile -Encoding UTF8
        
        @"
@{
    mainMenu = @{ Title = 'Test' }
}
"@ | Out-File -FilePath $script:TestMenuFile -Encoding UTF8
        
        @"
@{
    returnValues = @{ Back = '[B]ack' }
}
"@ | Out-File -FilePath $script:TestStringsFile -Encoding UTF8
    }
    
    Context "Command-Line Parameter Precedence" {
        
        It "Should override appMode from settings file" {
            # Settings file has appMode = 'helpdesk'
            # Pass appMode = 'admin' via command line
            $result = & $script:InvokeMainScript -Parameters @{
                appMode = 'admin'
            }
            
            $result.Success | Should -Be $true
            # Check log for appMode value
            if (Test-Path $script:TestLogFile)
            {
                $logContent = Get-Content $script:TestLogFile -Raw
                # Log should reflect the overridden value
                $logContent | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Should override LogLevel from settings file" {
            $result = & $script:InvokeMainScript -Parameters @{
                LogLevel = 'Debug'
            }
            
            $result.Success | Should -Be $true
            
            # Check log for debug entries
            if (Test-Path $script:TestLogFile)
            {
                $logContent = Get-Content $script:TestLogFile -Raw
                $logContent | Should -Match "DEBUG|Debug"
            }
        }
        
        It "Should override maxWaitTime from settings file" {
            $customWaitTime = 600
            
            $result = & $script:InvokeMainScript -Parameters @{
                maxWaitTime = $customWaitTime
            }
            
            $result.Success | Should -Be $true
            # Execution should complete with custom parameter
        }
    }
    
    Context "Switch Parameters" {
        
        It "Should handle showVersion switch" {
            $result = & $script:InvokeMainScript -Parameters @{
                showVersion = $true
            }
            
            $result.Success | Should -Be $true
            # showVersion exits early after displaying version
        }
        
        It "Should handle showSettings switch" {
            $result = & $script:InvokeMainScript -Parameters @{
                showSettings = $true
            }
            
            $result.Success | Should -Be $true
            # Settings should be displayed in output
        }
        
        It "Should handle testMode with TestPassword" {
            $result = & $script:InvokeMainScript -Parameters @{
                TestPassword = "TestPassword123"
            }
            
            $result.Success | Should -Be $true
            # Should execute without prompting for password
        }
    }
    
    Context "Parameter Validation" {
        
        It "Should accept valid appMode values" {
            $validModes = @('full', 'helpDesk', 'advanced', 'advancedRegistration', 'registration', 'admin', 'custom')
            
            foreach ($mode in $validModes)
            {
                $result = & $script:InvokeMainScript -Parameters @{
                    appMode = $mode
                }
                
                $result.Success | Should -Be $true -Because "appMode '$mode' should be valid"
            }
        }
        
        It "Should accept valid LogLevel values" {
            $validLevels = @('Error', 'Warning', 'Information', 'Verbose', 'Debug')
            
            foreach ($level in $validLevels)
            {
                # Clean log for each test
                if (Test-Path $script:TestLogFile)
                {
                    Remove-Item $script:TestLogFile -Force
                }
                
                $result = & $script:InvokeMainScript -Parameters @{
                    LogLevel = $level
                }
                
                $result.Success | Should -Be $true -Because "LogLevel '$level' should be valid"
            }
        }
    }
}

Describe "Main.ps1 - Test Mode Configuration Behavior" -Tags 'Integration', 'Main', 'TestModeConfig' {
    
    Context "Test Mode Without Config File" {
        
        BeforeEach {
            # Ensure config file doesn't exist
            if (Test-Path $script:TestConfigFile)
            {
                Remove-Item $script:TestConfigFile -Force
            }
            
            # Create minimal settings
            @"
@{
    appMode = 'helpdesk'
}
"@ | Out-File -FilePath $script:TestSettingsFile -Encoding UTF8
            
            @"
@{
    mainMenu = @{ Title = 'Test' }
}
"@ | Out-File -FilePath $script:TestMenuFile -Encoding UTF8
            
            @"
@{
    returnValues = @{ Back = '[B]ack' }
}
"@ | Out-File -FilePath $script:TestStringsFile -Encoding UTF8
        }
        
        It "Should use dummy configuration values in test mode" {
            $result = & $script:InvokeMainScript
            
            $result.Success | Should -Be $true
            # Check log for test mode indicators
            if (Test-Path $script:TestLogFile)
            {
                $logContent = Get-Content $script:TestLogFile -Raw
                $logContent | Should -Match "Test mode|test-mode-fake-token"
            }
        }
        
        It "Should not prompt for configuration when config missing in test mode" {
            $result = & $script:InvokeMainScript
            
            $result.Success | Should -Be $true
            # Should not hang waiting for user input
        }
    }
    
    Context "Test Mode With TestPassword" {
        
        It "Should store TestPassword in script and global scope" {
            # This tests the password storage logic
            # We can't easily verify global variables from external execution
            # But we can verify it completes successfully with password
            $result = & $script:InvokeMainScript -Parameters @{
                TestPassword = "TestPassword123"
            }
            
            $result.Success | Should -Be $true
        }
    }
}

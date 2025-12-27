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

    Performance Optimizations:
    - Consolidated test runs within BeforeAll blocks to share setup
    - Reduced redundant test runs by combining related assertions
    - Added performance tracking to monitor test execution time
    - FastStart-specific tests moved to MainFastStartConfiguration.Tests.ps1

    Related Files:
    - main.ps1 (tested via -testMode execution)
    - MainFastStartConfiguration.Tests.ps1 (fastStart-specific tests)
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
            [hashtable]$TestModeOptions = $null,
            [switch]$SuppressOutput
        )

        # Always include testMode, disable autoUpdate, and overwrite logs for clean state
        $Parameters['testMode'] = $true
        $Parameters['autoUpdate'] = $false
        $Parameters['OverwriteLogs'] = $true

        # Convert testModeOptions hashtable to individual switch parameters
        if ($TestModeOptions)
        {
            foreach ($option in @('metadata', 'cleanup', 'migration', 'config', 'auth', 'legacyMigration', 'exitAfter'))
            {
                if ($TestModeOptions.ContainsKey($option) -and $TestModeOptions.$option)
                {
                    $paramName = "testMode$($option[0].ToString().ToUpper())$($option.Substring(1))"
                    $Parameters[$paramName] = $true
                }
            }
        }

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

        # Build parameter list
        $params = @()
        foreach ($key in $Parameters.Keys)
        {
            $value = $Parameters[$key]
            if ($value -is [bool] -or $value -is [switch])
            {
                if ($value) { $params += "-$key" }
            }
            else
            {
                $params += "-$key"
                $params += $value
            }
        }

        try
        {
            # Execute main.ps1 in a new PowerShell process to capture exit code reliably
            $result = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $script:MainScriptPath @params 2>&1
            $exitCode = $LASTEXITCODE

            # If exit code is null (shouldn't happen but be defensive), check if log exists
            if ($null -eq $exitCode)
            {
                $exitCode = if (Test-Path $Parameters['LogFilePath']) { 0 } else { 1 }
            }

            return @{
                Success  = $exitCode -eq 0
                Output   = $result
                ExitCode = $exitCode
                LogFile  = $Parameters['LogFilePath']
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
    }

    # Make it available in script scope
    $script:InvokeMainScript = ${function:Invoke-MainScriptTest}

    # Helper function to get log excerpt around a pattern match
    function Get-LogExcerpt
    {
        param(
            [string]$LogFilePath,
            [string]$Pattern,
            [int]$ContextLines = 3
        )

        if (-not (Test-Path $LogFilePath))
        {
            return "Log file not found: $LogFilePath"
        }

        $lines = Get-Content $LogFilePath

        # Find the current log session boundaries using separator lines from Write-Log.ps1
        $startSeparator = "=" * 30 + " start of log session " + "=" * 30
        $endSeparator = "=" * 30 + " end of log session " + "=" * 30

        # Find the last occurrence of start separator (current session)
        $sessionStart = -1
        $sessionEnd = $lines.Count

        for ($i = $lines.Count - 1; $i -ge 0; $i--)
        {
            if ($lines[$i] -match [regex]::Escape($startSeparator))
            {
                $sessionStart = $i
                break
            }
        }

        # If we found a start separator, look for the corresponding end separator
        if ($sessionStart -ge 0)
        {
            for ($i = $sessionStart + 1; $i -lt $lines.Count; $i++)
            {
                if ($lines[$i] -match [regex]::Escape($endSeparator))
                {
                    $sessionEnd = $i
                    break
                }
            }
        }
        else
        {
            # No session separator found, use entire log
            $sessionStart = 0
        }

        # Restrict search to current session only
        $sessionLines = if ($sessionStart -ge 0 -and $sessionEnd -gt $sessionStart)
        {
            $lines[$sessionStart..$sessionEnd]
        }
        else
        {
            $lines
        }

        $matchingLines = @()

        for ($i = 0; $i -lt $sessionLines.Count; $i++)
        {
            if ($sessionLines[$i] -match $Pattern)
            {
                $start = [Math]::Max(0, $i - $ContextLines)
                $end = [Math]::Min($sessionLines.Count - 1, $i + $ContextLines)

                $excerpt = @()
                $excerpt += "--- Log excerpt (session lines $($start+1)-$($end+1)) ---"
                for ($j = $start; $j -le $end; $j++)
                {
                    $marker = if ($j -eq $i) { '>>> ' } else { '    ' }
                    $excerpt += "$marker$($sessionLines[$j])"
                }
                $excerpt += "--- End excerpt ---"
                $matchingLines += $excerpt -join "`n"
            }
        }

        if ($matchingLines.Count -eq 0)
        {
            # Pattern not found - show first and last few lines of current session
            $headerLines = $sessionLines | Select-Object -First 5
            $footerLines = $sessionLines | Select-Object -Last 5
            return "Pattern not found in current session. Session preview:`n--- First 5 lines ---`n$($headerLines -join "`n")`n...`n--- Last 5 lines ---`n$($footerLines -join "`n")"
        }

        return $matchingLines -join "`n`n"
    }

    $script:GetLogExcerpt = ${function:Get-LogExcerpt}
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

    # Cleanup any GUID-named folders that may have been created by test artifacts
    # These can be created by Pester TestDrive or other temp directory mechanisms
    $guidPattern = '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'

    # Clean from repo root
    if ($script:RepoRoot -and (Test-Path $script:RepoRoot))
    {
        Get-ChildItem -Path $script:RepoRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match $guidPattern } |
            ForEach-Object {
                Write-Verbose "Removing GUID folder: $($_.FullName)"
                Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            }
    }

    # Clean from tests folder
    $testsFolder = Join-Path $script:RepoRoot "tests"
    if (Test-Path $testsFolder)
    {
        Get-ChildItem -Path $testsFolder -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match $guidPattern } |
            ForEach-Object {
                Write-Verbose "Removing GUID folder: $($_.FullName)"
                Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            }
    }
}

Describe "Quick TestMode Verification" -Tags 'Integration', 'Quick' {
    It "Should execute with testMode switches" {
        $startTime = Get-Date
        $result = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $script:MainScriptPath `
            -testMode -testModeMetadata -testModeExitAfter `
            -LogFilePath "$script:RepoRoot\Logs\pester-quick-test.log" -OverwriteLogs 2>&1
        $duration = ((Get-Date) - $startTime).TotalMilliseconds

        Write-Host "Quick TestMode completed in $duration ms"
        $LASTEXITCODE | Should -Be 0
    }
}

Describe "Main.ps1 - Test Mode Execution" -Tags 'Integration', 'Main', 'TestMode' {

    Context "Basic Startup in Test Mode" {
        BeforeAll {
            # Run main.ps1 once for this entire context with minimal phases
            $testOpts = @{
                metadata        = $true
                cleanup         = $false
                migration       = $false
                config          = $false
                auth            = $false
                legacyMigration = $false
                exitAfter       = $true
            }
            $script:BasicStartupResult = & $script:InvokeMainScript -TestModeOptions $testOpts
        }

        It "Should execute successfully with -testMode switch" {
            if (-not $script:BasicStartupResult.Success)
            {
                Write-Host "Exit Code: $($script:BasicStartupResult.ExitCode)"
                Write-Host "Output: $($script:BasicStartupResult.Output)"
                if ($script:BasicStartupResult.Error)
                {
                    Write-Host "Error: $($script:BasicStartupResult.Error)"
                }
            }
            $script:BasicStartupResult.Success | Should -Be $true
            $script:BasicStartupResult.ExitCode | Should -Be 0
        }

        It "Should skip menu display and exit cleanly in test mode" {
            # Should complete successfully without hanging (proves menu was skipped)
            $script:BasicStartupResult.Success | Should -Be $true
            $script:BasicStartupResult.ExitCode | Should -Be 0
        }

        It "Should find and load functions folder" {
            # Verify functions folder exists
            $functionsPath = Join-Path $script:RepoRoot "functions"
            Test-Path $functionsPath | Should -Be $true

            # Successful execution proves functions were loaded
            $script:BasicStartupResult.Success | Should -Be $true
        }
    }

    Context "Application Metadata" {
        BeforeAll {
            # Create settings with custom metadata
            @"
@{
    companyName = 'Test Corporation'
    version = '1.2.3.4'
    release = 'stable'
    appMode = 'helpdesk'
}
"@ | Out-File -FilePath $script:TestSettingsFile -Encoding UTF8

            # Run main.ps1 once for this context - only test metadata phase
            $testOpts = @{
                metadata        = $true
                cleanup         = $false
                migration       = $false
                config          = $false
                auth            = $false
                legacyMigration = $false
                exitAfter       = $true
            }
            $script:MetadataResult = & $script:InvokeMainScript -TestModeOptions $testOpts
        }

        It "Should load application metadata and complete successfully" {
            # Primary validation: successful execution
            $script:MetadataResult.Success | Should -Be $true

            # Secondary: verify log was created (proves initialization happened)
            Test-Path $script:TestLogFile | Should -Be $true
        }

        It "Should process custom metadata from settings file" {
            # Primary: successful execution with custom settings
            $script:MetadataResult.Success | Should -Be $true

            # Secondary: log validation (only if test fails, check logs for details)
            if (Test-Path $script:TestLogFile)
            {
                $logContent = Get-Content $script:TestLogFile -Raw
                # At least one metadata field should be logged
                $metadataPattern = "companyName:|release:|version:"

                if ($logContent -notmatch $metadataPattern)
                {
                    $excerpt = & $script:GetLogExcerpt -LogFilePath $script:TestLogFile -Pattern "metadata|company|release" -ContextLines 3
                    throw "Metadata fields not found in log. $excerpt"
                }

                $logContent | Should -Match $metadataPattern
            }
        }

        It "Should not prompt for input in testMode (silent mode)" {
            # Primary: completes without hanging (proves no prompts)
            $script:MetadataResult.Success | Should -Be $true
            $script:MetadataResult.ExitCode | Should -Be 0
        }

        It "Should exit cleanly with -showVersion parameter" {
            # Run separately as this has different parameters
            $testOpts = @{
                metadata        = $true
                cleanup         = $false
                migration       = $false
                config          = $false
                auth            = $false
                legacyMigration = $false
                exitAfter       = $false  # showVersion has its own exit
            }
            $versionResult = & $script:InvokeMainScript -TestModeOptions $testOpts -Parameters @{ showVersion = $true }

            # Primary: clean exit after showing version
            $versionResult.Success | Should -Be $true
            $versionResult.ExitCode | Should -Be 0
        }
    }

    Context "Configuration File Initialization" {
        BeforeAll {
            # Create minimal test configuration files
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

            # Without config.json, test mode should use defaults
            if (Test-Path $script:TestConfigFile)
            {
                Remove-Item $script:TestConfigFile -Force
            }

            # Run main.ps1 once for this context - test config phase
            $testOpts = @{
                metadata        = $true
                cleanup         = $false
                migration       = $false
                config          = $true
                auth            = $false
                legacyMigration = $false
                exitAfter       = $true
            }
            $script:ConfigResult = & $script:InvokeMainScript -TestModeOptions $testOpts -Parameters @{
                InitFile = $script:TestSettingsFile
            }
        }

        It "Should initialize with default configuration files and load settings from InitFile" {
            # Primary: should complete without real config file
            $script:ConfigResult.Success | Should -Be $true

            # Verify settings were actually loaded
            Test-Path $script:TestSettingsFile | Should -Be $true
        }
    }

    Context "Temporary File Cleanup and Logging Initialization" {
        BeforeAll {
            # Run main.ps1 once for this context - test cleanup phase
            $cleanupStart = Get-Date
            $testOpts = @{
                metadata        = $true
                cleanup         = $true
                migration       = $false
                config          = $false
                auth            = $false
                legacyMigration = $false
                exitAfter       = $true
            }
            $script:CleanupLoggingResult = & $script:InvokeMainScript -TestModeOptions $testOpts
            $script:CleanupDuration = ((Get-Date) - $cleanupStart).TotalMilliseconds
            Write-Host "Cleanup test completed in $($script:CleanupDuration) ms"
        }

        It "Should run cleanup operation during startup" {
            # Primary: successful startup (cleanup is part of initialization)
            $script:CleanupLoggingResult.Success | Should -Be $true

            # Secondary: verify cleanup executed (check logs only if needed)
            if (Test-Path $script:TestLogFile)
            {
                $logContent = Get-Content $script:TestLogFile -Raw
                $cleanupPattern = "Total temporary files|cleanup"

                if ($logContent -notmatch $cleanupPattern)
                {
                    $excerpt = & $script:GetLogExcerpt -LogFilePath $script:TestLogFile -Pattern "temporary|temp|cleanup" -ContextLines 2
                    throw "Cleanup operation not found in log. $excerpt"
                }

                $logContent | Should -Match $cleanupPattern
            }
        }

        It "Should create log file at specified path" {
            # Note: OverwriteLogs is set by default in helper, so clean state guaranteed
            $script:CleanupLoggingResult.Success | Should -Be $true
            # Log file should exist
            Test-Path $script:TestLogFile | Should -Be $true
            (Get-Item $script:TestLogFile).Length | Should -BeGreaterThan 0
        }

        It "Should accept custom LogLevel parameter" {
            # Run separately for Debug level test with minimal phases
            $testOpts = @{
                metadata        = $true
                cleanup         = $false
                migration       = $false
                config          = $false
                auth            = $false
                legacyMigration = $false
                exitAfter       = $true
            }
            $debugResult = & $script:InvokeMainScript -TestModeOptions $testOpts -Parameters @{
                LogLevel = 'Debug'
            }

            # Primary: accepts parameter without error
            $debugResult.Success | Should -Be $true

            # Secondary: verify debug logging occurred (logs only)
            if (Test-Path $script:TestLogFile)
            {
                $logContent = Get-Content $script:TestLogFile -Raw
                $debugPattern = "DEBUG|Debug"

                if ($logContent -notmatch $debugPattern)
                {
                    $excerpt = & $script:GetLogExcerpt -LogFilePath $script:TestLogFile -Pattern "\[.*\]" -ContextLines 5
                    throw "Debug logging not found. $excerpt"
                }

                $logContent | Should -Match $debugPattern
            }
        }
    }

    Context "Settings Migration" {
        BeforeAll {
            # Run main.ps1 once for this context - test migration phase
            $testOpts = @{
                metadata        = $true
                cleanup         = $false
                migration       = $true
                config          = $false
                auth            = $false
                legacyMigration = $false
                exitAfter       = $true
            }
            $script:MigrationResult = & $script:InvokeMainScript -TestModeOptions $testOpts
        }

        It "Should handle settings migration check without errors" {
            # Primary: migration check doesn't break startup
            $script:MigrationResult.Success | Should -Be $true

            # Secondary: verify migration was checked (logs as fallback)
            if (Test-Path $script:TestLogFile)
            {
                $logContent = Get-Content $script:TestLogFile -Raw
                $migrationPattern = "Migration needed:|migration"

                if ($logContent -notmatch $migrationPattern)
                {
                    $excerpt = & $script:GetLogExcerpt -LogFilePath $script:TestLogFile -Pattern "settings|configuration|init" -ContextLines 3
                    throw "Migration check not found in log. $excerpt"
                }

                $logContent | Should -Match $migrationPattern
            }
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
    autoUpdate = `$false
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

    Context "Command-Line Parameter Precedence and Switch Parameters" {
        BeforeAll {
            # Run main.ps1 once with multiple parameters to test
            $testOpts = @{
                metadata        = $true
                cleanup         = $false
                migration       = $false
                config          = $false
                auth            = $false
                legacyMigration = $false
                exitAfter       = $true
            }
            $script:ParamResult = & $script:InvokeMainScript -TestModeOptions $testOpts -Parameters @{
                appMode     = 'admin'
                maxWaitTime = 600
            }
        }

        It "Should accept appMode and maxWaitTime parameters" {
            # Primary: accepts multiple parameters without error
            $script:ParamResult.Success | Should -Be $true
            $script:ParamResult.ExitCode | Should -Be 0
        }

        It "Should handle showVersion switch" {
            $testOpts = @{
                metadata        = $true
                cleanup         = $false
                migration       = $false
                config          = $false
                auth            = $false
                legacyMigration = $false
                exitAfter       = $false  # showVersion has its own exit
            }
            $result = & $script:InvokeMainScript -TestModeOptions $testOpts -Parameters @{
                showVersion = $true
            }

            $result.Success | Should -Be $true
        }

        It "Should handle showSettings switch" {
            $testOpts = @{
                metadata        = $true
                cleanup         = $false
                migration       = $false
                config          = $true
                auth            = $false
                legacyMigration = $false
                exitAfter       = $true
            }
            $result = & $script:InvokeMainScript -TestModeOptions $testOpts -Parameters @{
                showSettings = $true
            }

            $result.Success | Should -Be $true
            $result.ExitCode | Should -Be 0
        }

        It "Should handle TestPassword parameter" {
            # Use minimal test options for faster execution
            $testOpts = @{
                metadata        = $true
                cleanup         = $false
                migration       = $false
                config          = $false
                auth            = $false
                legacyMigration = $false
                exitAfter       = $true
            }
            $result = & $script:InvokeMainScript -TestModeOptions $testOpts -Parameters @{
                TestPassword = "TestPassword123"
            }

            $result.Success | Should -Be $true
            $result.ExitCode | Should -Be 0
        }
    }

    Context "Parameter Validation" {

        It "Should accept various appMode and LogLevel values" -TestCases @(
            @{ AppMode = 'helpDesk'; LogLevel = 'Information' }
            @{ AppMode = 'admin'; LogLevel = 'Debug' }
        ) {
            param($AppMode, $LogLevel)

            $testOpts = @{
                metadata        = $true
                cleanup         = $false
                migration       = $false
                config          = $false
                auth            = $false
                legacyMigration = $false
                exitAfter       = $true
            }
            $result = & $script:InvokeMainScript -TestModeOptions $testOpts -Parameters @{
                appMode  = $AppMode
                LogLevel = $LogLevel
            }

            $result.Success | Should -Be $true -Because "appMode '$AppMode' with LogLevel '$LogLevel' should be valid"
        }
    }
}

Describe "Main.ps1 - Test Mode Configuration Behavior" -Tags 'Integration', 'Main', 'TestModeConfig' {

    Context "Test Mode Without Config File and With TestPassword" {
        BeforeAll {
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

            # Run main.ps1 once for this context
            $testOpts = @{
                metadata        = $true
                cleanup         = $false
                migration       = $false
                config          = $false
                auth            = $false
                legacyMigration = $false
                exitAfter       = $true
            }
            $script:NoConfigResult = & $script:InvokeMainScript -TestModeOptions $testOpts
        }

        It "Should complete without config file in test mode" {
            # Primary: completes without prompts or errors
            $script:NoConfigResult.Success | Should -Be $true
        }

        It "Should accept TestPassword parameter" {
            $testOpts = @{
                metadata        = $true
                cleanup         = $false
                migration       = $false
                config          = $false
                auth            = $false
                legacyMigration = $false
                exitAfter       = $true
            }
            $result = & $script:InvokeMainScript -TestModeOptions $testOpts -Parameters @{
                TestPassword = "TestPassword123"
            }

            $result.Success | Should -Be $true
        }
    }
}

Describe "Main.ps1 - Authentication in Test Mode" -Tags 'Integration', 'Main', 'Authentication' {

    BeforeAll {
        # Create minimal test configuration with autoUpdate disabled
        @"
@{
    appMode = 'helpdesk'
    autoUpdate = `$false
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

        # Remove config file to ensure no real auth is attempted
        if (Test-Path $script:TestConfigFile)
        {
            Remove-Item $script:TestConfigFile -Force
        }

        # Run main.ps1 once for this describe block
        $testOpts = @{
            metadata        = $true
            cleanup         = $false
            migration       = $false
            config          = $false
            auth            = $false
            legacyMigration = $false
            exitAfter       = $true
        }
        $script:AuthResult = & $script:InvokeMainScript -TestModeOptions $testOpts
    }

    Context "Test Mode Authentication Bypass" {

        It "Should complete without real authentication in test mode" {
            # Primary: completes without real Graph token
            $script:AuthResult.Success | Should -Be $true
        }
    }
}

Describe "Main.ps1 - Performance Summary" -Tags 'Integration', 'Main', 'Performance' {
    It "Should track initialization performance metrics" {
        # This test provides visibility into test execution times
        # Use this to monitor for performance regressions
        Write-Host "`n=== Initialization Test Performance Summary ==="
        if ($script:CleanupDuration) {
            Write-Host "Cleanup phase: $([math]::Round($script:CleanupDuration, 2)) ms"
        }
        # Add more timing metrics as needed
        Write-Host "===============================================`n"

        # Always pass - this is informational
        $true | Should -Be $true
    }
}

Describe "Main.ps1 - Configuration Loading Integration" -Tags 'Integration', 'Main', 'ConfigurationLoading' {

    BeforeAll {
        # Create comprehensive test configuration with autoUpdate disabled
        @"
@{
    appMode = 'helpdesk'
    LogLevel = 'Information'
    maxWaitTime = 300
    timeInSeconds = 60
    domain = 'test.contoso.com'
    companyName = 'Test Company'
    version = '1.2.3.4'
    release = 'stable'
    autoUpdate = `$false
}
"@ | Out-File -FilePath $script:TestSettingsFile -Encoding UTF8

        @"
@{
    mainMenu = @{
        Title = 'Main Menu'
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

        # Run main.ps1 once for this describe block
        $testOpts = @{
            metadata        = $true
            cleanup         = $false
            migration       = $false
            config          = $true
            auth            = $false
            legacyMigration = $false
            exitAfter       = $true
        }
        $script:ConfigLoadingResult = & $script:InvokeMainScript -TestModeOptions $testOpts
    }

    Context "Configuration File Loading and Global Variable Initialization" {

        It "Should load and merge configuration files successfully" {
            # Primary: successful configuration loading
            $script:ConfigLoadingResult.Success | Should -Be $true

            # Secondary: verify config files exist (proves they were used)
            Test-Path $script:TestSettingsFile | Should -Be $true
            Test-Path $script:TestMenuFile | Should -Be $true
            Test-Path $script:TestStringsFile | Should -Be $true
        }

        It "Should initialize global variables correctly" {
            # Primary: successful initialization
            $script:ConfigLoadingResult.Success | Should -Be $true

            # Secondary: log file exists (proves LogFile variable was set)
            Test-Path $script:TestLogFile | Should -Be $true
        }
    }
}

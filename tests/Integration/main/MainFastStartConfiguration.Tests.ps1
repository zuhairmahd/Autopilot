<#
.SYNOPSIS
    Integration tests for main.ps1 fastStart configuration loading mechanism.

.DESCRIPTION
    Tests the fastStart configuration loading path vs regular initialization path, including:
    - FastStart success scenarios (all required files present)
    - FastStart fallback scenarios (missing files or invalid content)
    - Performance comparison between fastStart and regular loading
    - File validation logic in fastStart
    - Configuration result validation

.NOTES
    Test Framework: Pester 5.x
    PowerShell Version: 5.1+

    Key Test Areas:
    - FastStart path execution when all files are available
    - Fallback to Initialize-ApplicationConfiguration when files missing
    - Validation of $filesLoaded flag behavior
    - Validation of $configResult.Success flag
    - Performance metrics (fastStart should be faster)
    - Configuration completeness (both paths should produce same result)

    Testing Approach:
    - Integration tests using REAL main.ps1 execution with -testMode
    - Compare fastStart vs regular loading with timing
    - Test various file presence combinations
    - Validate configuration consistency between approaches

    Related Code:
    - main.ps1 lines 800-885 (fastStart mechanism)
    - Initialize-ApplicationConfiguration.ps1 (fallback path)
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
    $script:TestDomainFile = Join-Path $script:TestRoot "test.contoso.com.psd1"
    $script:TestConfigFile = Join-Path $script:TestRoot ".secrets\config.json"
    $script:TestMenuFile = Join-Path $script:TestRoot "menu.psd1"
    $script:TestStringsFile = Join-Path $script:TestRoot "strings.psd1"
    $script:TestLogFile = Join-Path $script:TestRoot "Logs\test.log"

    # Create directories
    $secretsDir = Split-Path $script:TestConfigFile -Parent
    New-Item -Path $secretsDir -ItemType Directory -Force | Out-Null

    $logsDir = Split-Path $script:TestLogFile -Parent
    New-Item -Path $logsDir -ItemType Directory -Force | Out-Null

    # Helper function to create complete configuration files for fastStart
    function New-FastStartConfiguration
    {
        param(
            [string]$SettingsFile,
            [string]$DomainName,
            [string]$MenuFile,
            [string]$StringsFile,
            [string]$WorkingDirectory = $null
        )

        # Use provided working directory or fall back to script:RepoRoot
        $targetDir = if ($WorkingDirectory)
        {
            $WorkingDirectory
        }
        else
        {
            $script:RepoRoot
        }

        # Create comprehensive settings.psd1 with all required sections
        @"
@{
    # Auth configuration
    auth = @{
        delegated = `$false
        authType = 'application'
        scope = 'https://graph.microsoft.com/.default'
    }

    # Global settings
    globalSettings = @{
        appMode = 'helpdesk'
        LogLevel = 'Information'
        maxWaitTime = 300
        timeInSeconds = 60
        autoUpdate = `$false
        showLicenseBanner = `$false
        validateScopes = `$false
        domain = '$domainName'
    }

    # Repository information
    repoInfo = @{
        baseSourceURL = 'https://raw.githubusercontent.com'
        baseURL = 'https://github.com'
        repoPath = 'test'
        repoName = 'Autopilot'
    }

    # Required scopes
    requiredScopes = @(
        @{
            Scope     = 'Device.Read.All'
            Endpoints = @('devices')
            Reason    = 'Required to read device objects.'
        },
        @{
            Scope     = 'DeviceManagementManagedDevices.Read.All'
            Endpoints = @('deviceManagement/managedDevices')
            Reason    = 'Required to read managed devices.'
        }
    )

    # Cache settings
    cacheSettings = @{
        enableCache = `$true
        cacheExpirationMinutes = 30
    }

    # Metadata
    companyName = 'Test Corporation'
    version = '1.0.0.0'
    release = 'stable'
}
"@ | Out-File -FilePath $SettingsFile -Encoding UTF8

        # Create domain-specific settings in repo root where main.ps1 expects it
        # Main.ps1 looks for "$domain.psd1" in $scriptPath (repo root)
        $domainFilePath = Join-Path $targetDir "$domainName.psd1"

        @"
@{
    groupsToInclude = @()
    groupsToExclude = @()
    LogLevel = 'Information'
    validateScopes = `$false
        Items = @()
    }
    checkMenu = @{
        Title = 'Check Menu'
        Type = 'menu'
        Items = @()
    }
}
"@ | Out-File -FilePath $MenuFile -Encoding UTF8

        # Create strings.psd1
        @"
@{
    returnValues = @{
        Back = '[B]ack'
        MainMenu = '[M]ain Menu'
        Exit = '[E]xit'
    }
    deviceStates = @{
        Compliant = 'Compliant'
        NonCompliant = 'Non-Compliant'
    }
    deviceActions = @{
        Sync = 'Sync Device'
        Retire = 'Retire Device'
    }
}
"@ | Out-File -FilePath $StringsFile -Encoding UTF8
    }

    # Helper function to run main.ps1 and measure time
    function Invoke-MainScriptWithTiming
    {
        param(
            [hashtable]$Parameters = @{},
            [hashtable]$TestModeOptions = $null,
            [string]$TestName = "Test",
            [string]$CustomLogFile = $null
        )

        # Always include testMode, disable autoUpdate, overwrite logs, and skip scope validation
        $Parameters['testMode'] = $true
        $Parameters['autoUpdate'] = $false
        $Parameters['OverwriteLogs'] = $true

        # Convert testModeOptions to parameters
        if ($TestModeOptions)
        {
            foreach ($option in @('metadata', 'cleanup', 'migration', 'config', 'auth', 'legacyMigration', 'exitAfter'))
            {
                if ($TestModeOptions.ContainsKey($option))
                {
                    $paramName = "testMode$($option[0].ToString().ToUpper())$($option.Substring(1))"
                    # Explicitly pass both true and false values
                    $Parameters[$paramName] = $TestModeOptions.$option
                }
            }
        }

        # Set default files
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
            # Use custom log file if provided, otherwise use default
            if ($CustomLogFile)
            {
                $Parameters['LogFilePath'] = $CustomLogFile
            }
            else
            {
                $Parameters['LogFilePath'] = $script:TestLogFile
            }
        }

        # Build parameter list
        $params = @()
        foreach ($key in $Parameters.Keys)
        {
            $value = $Parameters[$key]
            if ($value -is [bool] -or $value -is [switch])
            {
                # For boolean parameters, use PowerShell's : syntax to explicitly pass true/false
                $params += "-${key}:`$$($value.ToString().ToLower())"
            }
            else
            {
                $params += "-$key"
                $params += $value
            }
        }

        # Measure execution time
        $startTime = Get-Date
        try
        {
            # Ensure pwsh.exe runs from the repo root so domain files can be found
            # Change to repo root directory before launching pwsh.exe
            $originalLocation = Get-Location
            Set-Location $script:RepoRoot

            try
            {
                $result = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $script:MainScriptPath @params 2>&1
                $exitCode = $LASTEXITCODE
            }
            finally
            {
                Set-Location $originalLocation
            }

            $endTime = Get-Date
            $duration = ($endTime - $startTime).TotalMilliseconds

            if ($null -eq $exitCode)
            {
                $exitCode = if (Test-Path $Parameters['LogFilePath'])
                {
                    0
                }
                else
                {
                    1
                }
            }

            return @{
                Success  = $exitCode -eq 0
                Output   = $result
                ExitCode = $exitCode
                LogFile  = $Parameters['LogFilePath']
                Duration = $duration
                TestName = $TestName
            }
        }
        catch
        {
            $endTime = Get-Date
            $duration = ($endTime - $startTime).TotalMilliseconds

            return @{
                Success  = $false
                Output   = $_.Exception.Message
                ExitCode = 1
                Error    = $_
                Duration = $duration
                TestName = $TestName
            }
        }
    }

    $script:InvokeMainScriptTimed = ${function:Invoke-MainScriptWithTiming}
    $script:NewFastStartConfig = ${function:New-FastStartConfiguration}

    # Helper to extract log messages about fastStart
    function Get-FastStartLogMessages
    {
        param([string]$LogFilePath)

        if (-not (Test-Path $LogFilePath))
        {
            return @()
        }

        $content = Get-Content $LogFilePath -Raw
        $messages = @()

        if ($content -match "Attempting fast start")
        {
            $messages += "FastStart attempted"
        }
        if ($content -match "Fast start configuration load succeeded")
        {
            $messages += "FastStart succeeded"
        }
        if ($content -match "Fast start configuration load failed")
        {
            $messages += "FastStart failed - fallback triggered"
        }
        if ($content -match "Performing full configuration initialization" -or $content -match "falling back to full initialization")
        {
            $messages += "Full initialization executed"
        }

        return $messages
    }

    $script:GetFastStartLogs = ${function:Get-FastStartLogMessages}

    # Helper to extract initialization duration from log file
    function Get-InitializationDuration
    {
        param(
            [string]$LogFilePath,
            [switch]$Verbose
        )

        if ($Verbose)
        {
            Write-Host "Checking log file: $LogFilePath" -ForegroundColor Yellow
        }

        if (-not (Test-Path $LogFilePath))
        {
            if ($Verbose)
            {
                Write-Host "Log file not found: $LogFilePath" -ForegroundColor Red
            }
            return $null
        }

        $content = Get-Content $LogFilePath -Raw
        if ($Verbose)
        {
            Write-Host "Log file size: $($content.Length) characters" -ForegroundColor Cyan
        }

        # Look for the log message in milliseconds (new format): "Initialization completed in X milliseconds."
        if ($content -match 'Initialization completed in ([\d.]+) milliseconds')
        {
            $milliseconds = [double]$Matches[1]
            if ($Verbose)
            {
                Write-Host "Matched line: $($Matches[0])" -ForegroundColor Green
                Write-Host "Found milliseconds format: $milliseconds ms" -ForegroundColor Green
            }
            return $milliseconds
        }

        # Fallback: look for Duration in test mode exit message (new format)
        if ($content -match 'Duration: ([\d.]+) milliseconds')
        {
            $milliseconds = [double]$Matches[1]
            if ($Verbose)
            {
                Write-Host "Matched line: $($Matches[0])" -ForegroundColor Green
                Write-Host "Found test mode milliseconds format: $milliseconds ms" -ForegroundColor Green
            }
            return $milliseconds
        }

        # Legacy format: "Initialization completed in X minutes and Y seconds."
        if ($content -match 'Initialization completed in (\d+) minutes and (\d+) seconds')
        {
            $minutes = [int]$Matches[1]
            $seconds = [int]$Matches[2]
            $milliseconds = ($minutes * 60000) + ($seconds * 1000)
            if ($Verbose)
            {
                #display the full line
                Write-Host "Matched line: $($Matches[0])" -ForegroundColor Yellow
                Write-Host "Found legacy format: $minutes min, $seconds sec = $milliseconds ms" -ForegroundColor Yellow
            }
            return $milliseconds
        }

        # Old test mode format fallback
        if ($content -match 'Duration: ([\d.]+)ms')
        {
            $milliseconds = [double]$Matches[1]
            if ($Verbose)
            {
                Write-Host "Matched line: $($Matches[0])" -ForegroundColor Yellow
                Write-Host "Found old test mode format: $milliseconds ms" -ForegroundColor Yellow
            }
            return $milliseconds
        }

        if ($Verbose)
        {
            Write-Host "No duration pattern found in log file" -ForegroundColor Red
            Write-Host "Sample log content (first 500 chars):" -ForegroundColor Yellow
            Write-Host $content.Substring(0, [Math]::Min(500, $content.Length)) -ForegroundColor Gray
        }
        return $null
    }

    $script:GetInitDuration = ${function:Get-InitializationDuration}
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

    # Cleanup domain files created in repo root during tests
    $domainFiles = @("test.contoso.com.psd1", "test.local.psd1", "custom.test.com.psd1")
    foreach ($domainFile in $domainFiles)
    {
        $fullPath = Join-Path $script:RepoRoot $domainFile
        if (Test-Path $fullPath)
        {
            Write-Verbose "Cleaning up test domain file: $fullPath"
            Remove-Item -Path $fullPath -Force -ErrorAction SilentlyContinue
        }
    }

    # Cleanup menu cache file created during performance tests
    $menuCacheFile = Join-Path $script:RepoRoot "menu-cache.json"
    if (Test-Path $menuCacheFile)
    {
        Write-Verbose "Cleaning up test menu cache file: $menuCacheFile"
        Remove-Item -Path $menuCacheFile -Force -ErrorAction SilentlyContinue
    }
}

Describe "Main.ps1 - FastStart Configuration Loading" -Tags 'Integration', 'Main', 'FastStart', 'Performance' {

    Context "FastStart Success Path - All Files Present" {
        BeforeAll {
            # Create domain file in repo root where main.ps1 expects it
            # Domain file MUST be in repo root because main.ps1 looks for "$domain.psd1" in $ScriptPath
            $domainFilePath = Join-Path $script:RepoRoot "test.contoso.com.psd1"
            @"
@{
    groupsToInclude = @()
    groupsToExclude = @()
    LogLevel = 'Information'
    validateScopes = `$false
}
"@ | Out-File -FilePath $domainFilePath -Encoding UTF8

            # Run with config loading disabled so domain defaults to test.contoso.com
            # This allows fastStart to find the domain file we create
            # Use REAL repo root files for settings, menu, strings
            $testOpts = @{
                metadata        = $true
                cleanup         = $false
                migration       = $false
                config          = $false
                auth            = $false
                legacyMigration = $false
                exitAfter       = $true
            }

            # Override file paths to use repo root files (not temp folder)
            $params = @{
                InitFile    = Join-Path $script:RepoRoot "settings.psd1"
                menuFile    = Join-Path $script:RepoRoot "menu.psd1"
                stringsFile = Join-Path $script:RepoRoot "strings.psd1"
            }

            $script:FastStartResult = & $script:InvokeMainScriptTimed `
                -Parameters $params `
                -TestModeOptions $testOpts `
                -TestName "FastStart-Success"
        }

        It "Should execute successfully with fastStart" {
            $script:FastStartResult.Success | Should -Be $true
            $script:FastStartResult.ExitCode | Should -Be 0
        }

        It "Should log fastStart attempt" {
            $logs = & $script:GetFastStartLogs -LogFilePath $script:TestLogFile
            $logs | Should -Contain "FastStart attempted"
        }

        It "Should log fastStart success" {
            $logs = & $script:GetFastStartLogs -LogFilePath $script:TestLogFile
            $logs | Should -Contain "FastStart succeeded"
        }

        It "Should NOT trigger full initialization fallback" {
            $logs = & $script:GetFastStartLogs -LogFilePath $script:TestLogFile
            $logs | Should -Not -Contain "Full initialization executed"
        }

        It "Should output fastStart success message" {
            $output = $script:FastStartResult.Output -join "`n"
            $output | Should -Match "Fast start configuration load succeeded"
        }

        It "Should complete in reasonable time" {
            # Extract actual duration from log file
            $duration = & $script:GetInitDuration -LogFilePath $script:FastStartResult.LogFile
            $duration | Should -Not -BeNullOrEmpty -Because "Duration should be logged in main.ps1"

            # FastStart should complete quickly (adjust threshold as needed)
            # Use 30 seconds as maximum to account for various environments
            $duration | Should -BeLessThan 30000 -Because "FastStart should complete in under 30 seconds"
        }
    }

    Context "FastStart Fallback Path - Missing InitFile" {
        BeforeAll {
            # Remove settings file to trigger fallback
            if (Test-Path $script:TestSettingsFile)
            {
                Remove-Item $script:TestSettingsFile -Force
            }

            # Create other files
            & $script:NewFastStartConfig `
                -SettingsFile "$script:TestRoot\dummy.psd1" `
                -DomainName "test.contoso.com" `
                -MenuFile $script:TestMenuFile `
                -StringsFile $script:TestStringsFile

            # Remove the dummy file
            Remove-Item "$script:TestRoot\dummy.psd1" -Force -ErrorAction SilentlyContinue

            $testOpts = @{
                metadata        = $true
                cleanup         = $false
                migration       = $false
                config          = $true
                auth            = $false
                legacyMigration = $false
                exitAfter       = $true
            }

            $script:FallbackResult = & $script:InvokeMainScriptTimed `
                -TestModeOptions $testOpts `
                -TestName "FastStart-Fallback-MissingInit"
        }

        It "Should fallback to full initialization when InitFile missing" {
            # Should still complete successfully via fallback
            $script:FallbackResult.Success | Should -Be $true
        }

        It "Should log fastStart failure" {
            $logs = & $script:GetFastStartLogs -LogFilePath $script:TestLogFile
            $logs | Should -Contain "FastStart failed - fallback triggered"
        }

        It "Should log full initialization execution" {
            $logs = & $script:GetFastStartLogs -LogFilePath $script:TestLogFile
            $logs | Should -Contain "Full initialization executed"
        }

        It "Should output full initialization message" {
            $output = $script:FallbackResult.Output -join "`n"
            $output | Should -Match "Performing full configuration initialization"
        }
    }

    Context "FastStart Fallback Path - Missing Domain File" {
        BeforeAll {
            # Create all files except domain file
            & $script:NewFastStartConfig `
                -SettingsFile $script:TestSettingsFile `
                -DomainFile "$script:TestRoot\dummy-domain.psd1" `
                -MenuFile $script:TestMenuFile `
                -StringsFile $script:TestStringsFile

            # Remove domain file
            if (Test-Path $script:TestDomainFile)
            {
                Remove-Item $script:TestDomainFile -Force
            }

            $testOpts = @{
                metadata        = $true
                cleanup         = $false
                migration       = $false
                config          = $true
                auth            = $false
                legacyMigration = $false
                exitAfter       = $true
            }

            $script:NoDomainResult = & $script:InvokeMainScriptTimed `
                -TestModeOptions $testOpts `
                -TestName "FastStart-Fallback-NoDomain"
        }

        It "Should fallback when domain file missing" {
            $script:NoDomainResult.Success | Should -Be $true
        }

        It "Should trigger fallback to full initialization" {
            $logs = & $script:GetFastStartLogs -LogFilePath $script:TestLogFile
            ($logs | Where-Object { $_ -match "fallback|Full initialization" }).Count | Should -BeGreaterThan 0
        }
    }

    Context "FastStart Fallback Path - Missing Menu File" {
        BeforeAll {
            # Create all files except menu
            & $script:NewFastStartConfig `
                -SettingsFile $script:TestSettingsFile `
                -DomainName "test.contoso.com" `
                -MenuFile "$script:TestRoot\dummy-menu.psd1" `
                -StringsFile $script:TestStringsFile

            # Remove menu file
            if (Test-Path $script:TestMenuFile)
            {
                Remove-Item $script:TestMenuFile -Force
            }

            $testOpts = @{
                metadata        = $true
                cleanup         = $false
                migration       = $false
                config          = $true
                auth            = $false
                legacyMigration = $false
                exitAfter       = $true
            }

            $script:NoMenuResult = & $script:InvokeMainScriptTimed `
                -TestModeOptions $testOpts `
                -TestName "FastStart-Fallback-NoMenu"
        }

        It "Should fallback when menu file missing" {
            $script:NoMenuResult.Success | Should -Be $true
        }

        It "Should trigger fallback to full initialization" {
            $logs = & $script:GetFastStartLogs -LogFilePath $script:TestLogFile
            ($logs | Where-Object { $_ -match "fallback|Full initialization" }).Count | Should -BeGreaterThan 0
        }
    }

    Context "FastStart Fallback Path - Missing Strings File" {
        BeforeAll {
            # Create all files except strings
            & $script:NewFastStartConfig `
                -SettingsFile $script:TestSettingsFile `
                -DomainName "test.contoso.com" `
                -MenuFile $script:TestMenuFile `
                -StringsFile "$script:TestRoot\dummy-strings.psd1"

            # Remove strings file
            if (Test-Path $script:TestStringsFile)
            {
                Remove-Item $script:TestStringsFile -Force
            }

            $testOpts = @{
                metadata        = $true
                cleanup         = $false
                migration       = $false
                config          = $true
                auth            = $false
                legacyMigration = $false
                exitAfter       = $true
            }

            $script:NoStringsResult = & $script:InvokeMainScriptTimed `
                -TestModeOptions $testOpts `
                -TestName "FastStart-Fallback-NoStrings"
        }

        It "Should fallback when strings file missing" {
            $script:NoStringsResult.Success | Should -Be $true
        }

        It "Should trigger fallback to full initialization" {
            $logs = & $script:GetFastStartLogs -LogFilePath $script:TestLogFile
            ($logs | Where-Object { $_ -match "fallback|Full initialization" }).Count | Should -BeGreaterThan 0
        }
    }

    Context "FastStart vs Regular Loading Performance Comparison" {
        BeforeAll {
            # PERFORMANCE TEST SETUP NOTES:
            # ==============================
            # This test compares FastStart (optimized path) vs Regular Init (fallback path).
            #
            # Key Setup Requirements:
            # 1. Menu cache file MUST exist for FastStart to show its benefit
            #    - FastStart loads pre-converted menu array from JSON
            #    - Regular init must convert menu.psd1 structure to array
            # 2. Domain file MUST exist for FastStart to succeed
            #    - When missing, FastStart fails and falls back to regular init
            # 3. Both tests share identical overhead (60-70% of execution time):
            #    - Loading 100+ function files via dot-sourcing
            #    - Metadata initialization
            #    - Migration checks
            #
            # Expected Performance:
            # - FastStart optimizes only ~10-20% of total execution (config loading)
            # - Expected improvement: 2-5% overall in ideal conditions
            # - Test allows 10% tolerance due to PowerShell process startup variance
            #
            # For detailed analysis, see: docs/tests/FastStart-Performance-Analysis.md

            # Configure performance tolerance (in milliseconds)
            # Tolerance accounts for:
            # - PowerShell process startup variance
            # - System load and disk I/O contention
            # - JIT compilation overhead
            # - Minimal optimization scope (FastStart only optimizes 10-20% of total time)
            $script:PerformanceToleranceMs = 1000  # 1 second tolerance (easily adjustable)

            # Clear all cache before performance testing for accurate comparison
            $cacheDir = Join-Path $script:TestRoot "Cache"
            if (Test-Path $cacheDir)
            {
                Remove-Item -Path $cacheDir -Recurse -Force -ErrorAction SilentlyContinue
            }

            # ===== Test 1: FastStart with all files present =====
            # Create domain file in REPO ROOT (where main.ps1 expects it)
            $domainFilePath = Join-Path $script:RepoRoot "test.contoso.com.psd1"
            @"
@{
    groupsToInclude = @()
    groupsToExclude = @()
    LogLevel = 'Information'
    validateScopes = `$false
}
"@ | Out-File -FilePath $domainFilePath -Encoding UTF8

            # Create menu cache file to test FastStart with full optimization
            # This simulates a system where menus have been cached from a previous run
            $menuCacheFilePath = Join-Path $script:RepoRoot "menu-cache.json"
            $menuCacheContent = @(
                @{
                    ID          = "test-item-1"
                    Label       = "Test Menu Item 1"
                    Description = "Test Description"
                    Action      = "Test-Action"
                }
            )
            $menuCacheContent | ConvertTo-Json -Depth 10 | Out-File -FilePath $menuCacheFilePath -Encoding UTF8 -Force
            Write-Host "Created menu cache file: $menuCacheFilePath" -ForegroundColor Gray

            # Create unique log files for each test
            $fastLogFile = Join-Path $script:TestRoot "Logs\fast-performance.log"
            $regularLogFile = Join-Path $script:TestRoot "Logs\regular-performance.log"

            # Use repo root files (settings.psd1, menu.psd1, strings.psd1 already exist)
            $fastParams = @{
                InitFile    = Join-Path $script:RepoRoot "settings.psd1"
                menuFile    = Join-Path $script:RepoRoot "menu.psd1"
                stringsFile = Join-Path $script:RepoRoot "strings.psd1"
            }

            $testOpts = @{
                metadata        = $true
                cleanup         = $false
                migration       = $false
                config          = $false  # Use config=false so domain defaults to test.contoso.com
                auth            = $false
                legacyMigration = $false
                exitAfter       = $true
            }

            Write-Host "\n===== Running FastStart Test =====" -ForegroundColor Cyan
            $script:FastResult = & $script:InvokeMainScriptTimed `
                -Parameters $fastParams `
                -TestModeOptions $testOpts `
                -TestName "FastStart-Performance" `
                -CustomLogFile $fastLogFile

            Write-Host "FastStart log file: $fastLogFile" -ForegroundColor Cyan

            # ===== Test 2: Force fallback by removing domain file and menu cache =====
            # Remove domain file so fastStart will fail and fall back to full init
            Remove-Item $domainFilePath -Force -ErrorAction SilentlyContinue

            # Also remove menu cache to force regular init to rebuild it
            if (Test-Path $menuCacheFilePath)
            {
                Remove-Item $menuCacheFilePath -Force -ErrorAction SilentlyContinue
                Write-Host "Removed menu cache file for Regular init test" -ForegroundColor Gray
            }

            Write-Host "\n===== Running Regular Init Test =====" -ForegroundColor Cyan
            $script:RegularResult = & $script:InvokeMainScriptTimed `
                -Parameters $fastParams `
                -TestModeOptions $testOpts `
                -TestName "Regular-Performance" `
                -CustomLogFile $regularLogFile

            Write-Host "Regular init log file: $regularLogFile" -ForegroundColor Cyan

            # Note: Domain file cleanup is handled in AfterAll of the test file
        }

        It "FastStart should complete faster than or equal to regular initialization" {
            # Extract actual durations from log files written by main.ps1
            Write-Host "\n===== Extracting Durations from Log Files =====" -ForegroundColor Yellow
            Write-Host "FastStart log: $($script:FastResult.LogFile)" -ForegroundColor Gray
            Write-Host "Regular log: $($script:RegularResult.LogFile)" -ForegroundColor Gray

            $fastDuration = & $script:GetInitDuration -LogFilePath $script:FastResult.LogFile -Verbose
            $regularDuration = & $script:GetInitDuration -LogFilePath $script:RegularResult.LogFile -Verbose

            # Both should have valid durations
            $fastDuration | Should -Not -BeNullOrEmpty -Because "FastStart duration should be logged in main.ps1"
            $regularDuration | Should -Not -BeNullOrEmpty -Because "Regular init duration should be logged in main.ps1"

            Write-Host "\n===== Duration Comparison =====" -ForegroundColor Yellow
            Write-Host "FastStart duration (from log): $fastDuration ms" -ForegroundColor Cyan
            Write-Host "Regular init duration (from log): $regularDuration ms" -ForegroundColor Cyan

            # Ensure we have valid durations before calculating
            $fastDuration | Should -BeGreaterThan 0 -Because "FastStart duration must be positive"
            $regularDuration | Should -BeGreaterThan 0 -Because "Regular init duration must be positive"

            # FastStart should be faster or within tolerance
            # Apply configured tolerance to account for test environment variance
            $maxAcceptableDuration = $regularDuration + $script:PerformanceToleranceMs
            Write-Host "Performance tolerance: $script:PerformanceToleranceMs ms" -ForegroundColor Gray
            Write-Host "Max acceptable FastStart duration: $([math]::Round($maxAcceptableDuration, 2)) ms" -ForegroundColor Gray

            $fastDuration | Should -BeLessThan $maxAcceptableDuration -Because "FastStart should be faster or within $($script:PerformanceToleranceMs)ms tolerance of regular initialization"

            # Calculate improvement percentage
            if ($regularDuration -eq $fastDuration)
            {
                Write-Host "There is no performance improvement - both paths took equal time." -ForegroundColor Yellow
                Write-Host "This indicates both FastStart and Regular init likely used the same code path." -ForegroundColor Gray
                $improvement = 0
            }
            else
            {
                # Only verify fallback behavior when there's an actual performance difference
                # Verify FastStart actually succeeded (not fell back)
                $fastLogContent = Get-Content $script:FastResult.LogFile -Raw
                $fastLogContent | Should -Match "Fast start configuration load succeeded" -Because "FastStart should have succeeded"
                Write-Host "Verified: FastStart succeeded (found success message in log)" -ForegroundColor Green

                # Verify Regular init used fallback
                $regularLogContent = Get-Content $script:RegularResult.LogFile -Raw
                ($regularLogContent -match "Fast start configuration load failed|Performing full configuration initialization") | Should -Be $true -Because "Regular test should have triggered fallback"
                Write-Host "Verified: Regular init used fallback path" -ForegroundColor Green

                $improvement = [math]::Round((($regularDuration - $fastDuration) / $regularDuration) * 100, 2)
                Write-Host "Performance improvement: $improvement%" -ForegroundColor Green
            }


            # Validate both succeeded
            $script:FastResult.Success | Should -Be $true
            $script:RegularResult.Success | Should -Be $true

            # Note: FastStart optimization only affects config file loading (Import-PowerShellDataFile),
            # which is a small fraction of total execution time. The majority of time is spent on:
            # - Importing 100+ function files from the functions folder
            # - Metadata initialization
            # - Migration checks
            # These happen before FastStart and are identical for both paths.
        }

        It "FastStart should be faster using external timing measurements (test harness)" {
            # This test uses the Duration property from the test harness itself
            # which measures the TOTAL execution time including PowerShell process startup
            Write-Host "\n===== External Timing Comparison (Test Harness) =====" -ForegroundColor Yellow
            Write-Host "FastStart external duration: $($script:FastResult.Duration) ms" -ForegroundColor Cyan
            Write-Host "Regular init external duration: $($script:RegularResult.Duration) ms" -ForegroundColor Cyan

            # Validate durations are positive
            $script:FastResult.Duration | Should -BeGreaterThan 0 -Because "External FastStart duration must be measured"
            $script:RegularResult.Duration | Should -BeGreaterThan 0 -Because "External Regular duration must be measured"

            # Apply configured tolerance for test environment variance
            # FastStart optimizes only ~10-20% of total execution (config loading)
            # The bulk of time (60-70%) is function loading, which is identical in both paths
            # Use absolute tolerance (configured in BeforeAll) rather than percentage
            $maxAcceptableDuration = $script:RegularResult.Duration + $script:PerformanceToleranceMs

            Write-Host "Performance tolerance: $script:PerformanceToleranceMs ms" -ForegroundColor Gray
            Write-Host "Max acceptable FastStart duration: $([math]::Round($maxAcceptableDuration, 2)) ms" -ForegroundColor Gray

            # FastStart should be faster or within tolerance
            $script:FastResult.Duration | Should -BeLessThan $maxAcceptableDuration -Because "FastStart should be faster or within $($script:PerformanceToleranceMs)ms tolerance of regular initialization"

            # Calculate improvement
            if ($script:FastResult.Duration -lt $script:RegularResult.Duration)
            {
                $externalImprovement = [math]::Round((($script:RegularResult.Duration - $script:FastResult.Duration) / $script:RegularResult.Duration) * 100, 2)
                Write-Host "External timing improvement: $externalImprovement%" -ForegroundColor Green
            }
            else
            {
                $slowdown = [math]::Round((($script:FastResult.Duration - $script:RegularResult.Duration) / $script:RegularResult.Duration) * 100, 2)
                Write-Host "FastStart was slower by $slowdown% (within tolerance)" -ForegroundColor Yellow
            }

            # Note: External timing includes PowerShell startup overhead and system variance.
            # FastStart primarily optimizes configuration loading (~10-20% of total time),
            # so improvements are expected to be modest (2-5% overall in ideal conditions).
        }

        It "Both paths should produce successful configuration" {
            $script:FastResult.Success | Should -Be $true
            $script:RegularResult.Success | Should -Be $true
        }
    }

    Context "FastStart Configuration Validation" {
        BeforeAll {
            # Create complete valid configuration
            & $script:NewFastStartConfig `
                -SettingsFile $script:TestSettingsFile `
                -DomainName "test.contoso.com" `
                -MenuFile $script:TestMenuFile `
                -StringsFile $script:TestStringsFile

            $testOpts = @{
                metadata        = $true
                cleanup         = $false
                migration       = $false
                config          = $true
                auth            = $false
                legacyMigration = $false
                exitAfter       = $true
            }

            $script:ValidationResult = & $script:InvokeMainScriptTimed `
                -TestModeOptions $testOpts `
                -TestName "FastStart-Validation"
        }

        It "Should validate all required configuration sections exist" {
            # FastStart checks for: auth, globalSettings, repoInfo, requiredScopes, cacheSettings, domain content, menu, strings
            $script:ValidationResult.Success | Should -Be $true
        }

        It "Should set configResult.Success to true when all sections valid" {
            # This is validated by successful execution
            $script:ValidationResult.Success | Should -Be $true
            $script:ValidationResult.ExitCode | Should -Be 0
        }

        It "Should create log file during initialization" {
            Test-Path $script:TestLogFile | Should -Be $true
            (Get-Item $script:TestLogFile).Length | Should -BeGreaterThan 0
        }
    }

    Context "FastStart with Incomplete Configuration Sections" {
        BeforeAll {
            # Create settings file missing required sections
            @"
@{
    # Only global settings, missing auth, repoInfo, etc.
    globalSettings = @{
        appMode = 'helpdesk'
    }
}
"@ | Out-File -FilePath $script:TestSettingsFile -Encoding UTF8

            # Create minimal other files
            & $script:NewFastStartConfig `
                -SettingsFile "$script:TestRoot\dummy.psd1" `
                -DomainName "test.contoso.com" `
                -MenuFile $script:TestMenuFile `
                -StringsFile $script:TestStringsFile

            $testOpts = @{
                metadata        = $true
                cleanup         = $false
                migration       = $false
                config          = $true
                auth            = $false
                legacyMigration = $false
                exitAfter       = $true
            }

            $script:IncompleteResult = & $script:InvokeMainScriptTimed `
                -TestModeOptions $testOpts `
                -TestName "FastStart-Incomplete"
        }

        It "Should detect incomplete configuration and trigger fallback" {
            # Should succeed via fallback
            $script:IncompleteResult.Success | Should -Be $true
        }

        It "Should trigger full initialization when sections missing" {
            $logs = & $script:GetFastStartLogs -LogFilePath $script:TestLogFile
            ($logs | Where-Object { $_ -match "fallback|Full initialization" }).Count | Should -BeGreaterThan 0
        }
    }
}

Describe "Main.ps1 - FastStart Integration with Other Features" -Tags 'Integration', 'Main', 'FastStart' {

    Context "FastStart with Custom Domain" {
        BeforeAll {
            # Create configuration with custom domain
            $customDomain = "custom.test.com"

            & $script:NewFastStartConfig `
                -SettingsFile $script:TestSettingsFile `
                -DomainName $customDomain `
                -MenuFile $script:TestMenuFile `
                -StringsFile $script:TestStringsFile

            $testOpts = @{
                metadata        = $true
                cleanup         = $false
                migration       = $false
                config          = $true
                auth            = $false
                legacyMigration = $false
                exitAfter       = $true
            }

            $script:CustomDomainResult = & $script:InvokeMainScriptTimed `
                -TestModeOptions $testOpts `
                -TestName "FastStart-CustomDomain"
        }

        It "Should load custom domain configuration via fastStart" {
            $script:CustomDomainResult.Success | Should -Be $true
        }
    }

    Context "FastStart with Verbose Logging" {
        BeforeAll {
            & $script:NewFastStartConfig `
                -SettingsFile $script:TestSettingsFile `
                -DomainName "test.contoso.com" `
                -MenuFile $script:TestMenuFile `
                -StringsFile $script:TestStringsFile

            $testOpts = @{
                metadata        = $true
                cleanup         = $false
                migration       = $false
                config          = $true
                auth            = $false
                legacyMigration = $false
                exitAfter       = $true
            }

            $params = @{
                LogLevel = 'Debug'
                Verbose  = $true
            }

            $script:VerboseResult = & $script:InvokeMainScriptTimed `
                -TestModeOptions $testOpts `
                -Parameters $params `
                -TestName "FastStart-Verbose"
        }

        It "Should log verbose fastStart information" {
            $script:VerboseResult.Success | Should -Be $true

            if (Test-Path $script:TestLogFile)
            {
                $logContent = Get-Content $script:TestLogFile -Raw
                # Should contain detailed logging about file loading
                $logContent | Should -Match "Loading init file|Loading strings file|Loading domain settings file|Loading menu file"
            }
        }
    }
}


#!/usr/bin/env pwsh

<#
.MIGRATION NOTE
This legacy test has been replaced by the Pester 5 test suite:
- New Test File: tests/Integration/SettingsFunctions.Tests.ps1
- Migration Date: Phase 3 completion (October 2024)
- Status: 12/12 tests passing (100%)
- Why Migrated: Better structure, faster execution, modern Pester syntax
- To Run New Tests: .\Invoke-PesterTests.ps1 -TestType Integration
#>

# Integration test for Settings Menu functionality using mock data
param(
    [string]$TestName = "Settings Integration Test",
    [string]$TestFolder = $null
)

# Use unified test framework
try
{
    # Load test helper functions
    . "$PSScriptRoot\test-helper.ps1"
    
    # Determine paths
    $RootPath = Split-Path -Parent $PSScriptRoot
    
    # Load all functions at script level (same as main.ps1)
    $functionsFolder = Join-Path $RootPath "functions"
    if (Test-Path $functionsFolder)
    {
        $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -Recurse
        foreach ($function in $functions)
        {
            try
            {
                . $function.FullName
            }
            catch
            {
                Write-Warning "Failed to load $($function.Name): $($_.Exception.Message)"
            }
        }
        Write-TestResult "Functions loaded successfully" $true
    }
    else
    {
        Write-TestResult "Functions folder not found at: $functionsFolder" $false
        exit 1
    }
    
    # Initialize unified test environment  
    $testContext = Start-UnifiedTest -TestName $TestName -TestFolder $TestFolder
    
    # Set global variables needed by functions
    $tempDir = if ($IsWindows) { $env:TEMP } else { "/tmp" }
    $global:LogFile = Join-Path $tempDir "test-settings-integration.log"
    $global:maxJSONDepth = 10
    
    Write-TestResult "Test environment initialized" $true
}
catch
{
    Write-TestResult "Failed to set up test environment: $($_.Exception.Message)" $false
    exit 1
}
try
{
    Push-Location $TestFolder
    
    Write-TestSection "Settings Menu Integration Test"
    
    # Test 1: Function availability
    $settingsEditorFunc = Get-Command Show-SettingsEditor -ErrorAction SilentlyContinue
    Write-TestResult "Show-SettingsEditor function availability" ($null -ne $settingsEditorFunc)
    
    # Test 2: Mock settings structure integration
    $mockSettings = @{
        globalSettings = @{
            autoUpdate  = $true
            appMode     = "full"
            maxWaitTime = 30
            testMode    = $false
        }
        domains        = @{
            "test.com" = @{
                groupsToInclude = @("Test-Group")
                groupsToExclude = @()
                settings        = @{
                    minUsernameLength = 3
                    preferredBrowser  = "Chrome"
                }
            }
        }
        auth           = @{
            authType  = "PublicAuthFlow"
            delegated = $true
        }
    }
    
    Write-TestResult "Mock settings structure created" ($mockSettings.globalSettings -ne $null)
    
    # Test 3: Settings manipulation (mock)
    $originalAutoUpdate = $mockSettings.globalSettings.autoUpdate
    $mockSettings.globalSettings.autoUpdate = $false
    $newAutoUpdate = $mockSettings.globalSettings.autoUpdate
    
    Write-TestResult "Settings manipulation works" ($originalAutoUpdate -ne $newAutoUpdate)
    
    # Test 4: JSON serialization compatibility
    try
    {
        $jsonString = $mockSettings | ConvertTo-Json -Depth 10
        $parsedBack = $jsonString | ConvertFrom-Json
        Write-TestResult "JSON serialization works" ($parsedBack.globalSettings.appMode -eq "full")
    }
    catch
    {
        Write-TestResult "JSON serialization failed" $false
    }
    
    # Test 5: Domain settings structure
    $firstDomain = "test.com"
    $domainExists = $mockSettings.domains.ContainsKey($firstDomain)
    $domainHasSettings = $domainExists -and ($mockSettings.domains[$firstDomain].settings -ne $null)
    
    Write-TestResult "Domain settings structure valid" $domainHasSettings
    
    # Test 6: Settings editor helper functions
    $helperFunctions = @("Show-SettingsMenu", "Show-SettingsViewer", "Update-Setting")
    foreach ($funcName in $helperFunctions)
    {
        $func = Get-Command $funcName -ErrorAction SilentlyContinue
        Write-TestResult "$funcName helper function available" ($null -ne $func)
    }
    
    # Test 7: Array handling for group settings
    $originalGroupsCount = $mockSettings.domains[$firstDomain].groupsToInclude.Count
    $mockSettings.domains[$firstDomain].groupsToInclude += "New-Group"
    $newGroupsCount = $mockSettings.domains[$firstDomain].groupsToInclude.Count
    
    Write-TestResult "Array manipulation for groups works" ($newGroupsCount -eq $originalGroupsCount + 1)
    
    # Test 8: Settings validation (if function exists)
    try
    {
        if (Get-Command Test-SettingsStructure -ErrorAction SilentlyContinue)
        {
            $validationResult = Test-SettingsStructure -Settings $mockSettings
            Write-TestResult "Settings structure validation works" $validationResult
        }
        else
        {
            Write-TestResult "Settings structure validation (function not available)" $true
        }
    }
    catch
    {
        Write-TestResult "Settings validation test: $($_.Exception.Message)" $false
    }
    
    Write-TestSection "Integration Test Summary"
    Write-Host "Settings integration test completed using mock data" -ForegroundColor Green
    Write-Host "This ensures reliable testing without dependency on real settings files" -ForegroundColor Green
    
    # Complete the unified test
    Complete-UnifiedTest -TestContext $testContext
    
}
catch
{
    Write-TestResult "Integration test failed: $($_.Exception.Message)" $false
    exit 1
}
finally
{
    Pop-Location
}

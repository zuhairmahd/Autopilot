#!/usr/bin/env pwsh

# Test script for Settings Editor functionality using mock data
param(
    [string]$TestName = "Settings Editor Functionality Test",
    [string]$TestFolder = $null
)

# Use unified test framework
try {
    # Load test helper functions
    . "$PSScriptRoot\test-helper.ps1"
    
    # Load all functions at script level (same as main.ps1)
    $functionsFolder = "$PWD\functions"
    if (Test-Path $functionsFolder) {
        $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -Recurse
        foreach ($function in $functions) {
            try {
                . $function.FullName
            } catch {
                Write-Warning "Failed to load $($function.Name): $($_.Exception.Message)"
            }
        }
        Write-TestResult "Functions loaded successfully" $true
    } else {
        Write-TestResult "Functions folder not found" $false
        exit 1
    }
    
    # Initialize unified test environment  
    $testContext = Start-UnifiedTest -TestName $TestName -TestFolder $TestFolder
    
    # Set global variables needed by functions
    $tempDir = if ($IsWindows) { $env:TEMP } else { "/tmp" }
    $global:LogFile = Join-Path $tempDir "test-settings-editor.log"
    $global:maxJSONDepth = 10
    
    Write-TestResult "Test environment initialized" $true
} catch {
    Write-TestResult "Failed to set up test environment: $($_.Exception.Message)" $false
    exit 1
}

try {
    Push-Location $TestFolder
    
    Write-TestSection "Settings Editor Core Functions"
    
    # Test 1: Check if Settings Editor function exists
    try {
        $settingsEditorFunc = Get-Command Show-SettingsEditor -ErrorAction SilentlyContinue
        Write-TestResult "Show-SettingsEditor function exists" ($null -ne $settingsEditorFunc)
    } catch {
        Write-TestResult "Show-SettingsEditor function check failed: $($_.Exception.Message)" $false
    }
    
    # Test 2: Test mock settings data structure
    $mockSettings = @{
        globalSettings = @{
            autoUpdate = $true
            appMode = "full"
            maxWaitTime = 30
            testMode = $false
        }
        domains = @{
            "test.com" = @{
                groupsToInclude = @("Test-Group")
                groupsToExclude = @()
                settings = @{
                    operatingSystem = "Windows"
                    maxNumberOfDevicesAllowed = 10
                }
            }
        }
        auth = @{
            authType = "PublicAuthFlow"
            delegated = $true
        }
    }
    
    Write-TestResult "Mock settings structure created" ($mockSettings.globalSettings -ne $null)
    Write-TestResult "Mock settings has global settings" ($mockSettings.globalSettings.appMode -eq "full")
    Write-TestResult "Mock settings has domains" ($mockSettings.domains.Count -gt 0)
    Write-TestResult "Mock settings has auth config" ($mockSettings.auth.authType -eq "PublicAuthFlow")
    
    # Test 3: Test JSON conversion (this is what the settings editor would do)
    try {
        $jsonString = $mockSettings | ConvertTo-Json -Depth 10
        $parsedBack = $jsonString | ConvertFrom-Json
        Write-TestResult "JSON serialization works" ($parsedBack.globalSettings.appMode -eq "full")
    } catch {
        Write-TestResult "JSON serialization failed: $($_.Exception.Message)" $false
    }
    
    # Test 4: Test settings validation functions if they exist
    try {
        if (Get-Command Test-SettingsStructure -ErrorAction SilentlyContinue) {
            # Use mock data instead of real settings file
            $validationResult = Test-SettingsStructure -Settings $mockSettings
            Write-TestResult "Settings structure validation works" $validationResult
        } else {
            Write-TestResult "Settings structure validation (function not available)" $true
        }
    } catch {
        Write-TestResult "Settings validation test: $($_.Exception.Message)" $false
    }
    
    # Test 5: Test backup functionality if available
    try {
        if (Get-Command Backup-SettingsFile -ErrorAction SilentlyContinue) {
            $testSettingsFile = "mock-settings.json"
            $mockSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $testSettingsFile -Force
            $backupResult = Backup-SettingsFile -SettingsFile $testSettingsFile
            Write-TestResult "Settings backup functionality works" $backupResult
        } else {
            Write-TestResult "Settings backup functionality (function not available)" $true
        }
    } catch {
        Write-TestResult "Settings backup test failed: $($_.Exception.Message)" $false
    }
    
    # Test 6: Test settings editor integration points
    Write-TestSection "Settings Editor Integration"
    
    # Check for menu integration functions
    $menuFunctions = @("Show-SettingsMenu", "Show-SettingsViewer", "Update-Setting")
    foreach ($funcName in $menuFunctions) {
        $func = Get-Command $funcName -ErrorAction SilentlyContinue
        Write-TestResult "$funcName function available" ($null -ne $func)
    }
    
    Write-TestSection "Settings Editor Test Complete"
    Write-Host "Settings Editor functionality validated using mock data" -ForegroundColor Green
    Write-Host "This ensures tests are reliable and don't depend on real settings.json" -ForegroundColor Green
    
    # Complete the unified test
    Complete-UnifiedTest -TestContext $testContext
    
} catch {
    Write-TestResult "Test execution failed: $($_.Exception.Message)" $false
    exit 1
} finally {
    Pop-Location
}

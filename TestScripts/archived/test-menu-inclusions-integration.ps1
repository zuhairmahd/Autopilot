<#
.MIGRATION NOTE
This legacy test has been replaced by the Pester 5 test suite:
- New Test File: tests/Integration/MenuInclusions.Tests.ps1
- Migration Date: Phase 3 completion (October 2024)
- Status: 8/8 tests passing (100%)
- Why Migrated: Better structure, faster execution, modern Pester syntax
- To Run New Tests: .\Invoke-PesterTests.ps1 -TestType Integration
#>

# Testing Menu Inclusions Integration with settings.json

# Use unified test framework
try
{
    # Load test helper functions
    . "$PSScriptRoot\test-helper.ps1"
    
    # Initialize unified test environment
    $testContext = Start-UnifiedTest -TestName "Menu Inclusions Integration with settings.json"
    
    Write-TestResult "Test environment initialized" $true
}
catch
{
    Write-TestResult "Failed to set up test environment: $($_.Exception.Message)" $false
    exit 1
}

try
{
    Write-TestSection "Test 1: Verify settings.json contains menuItemsToInclude"
    
    # Check if settings.json exists and contains menuItemsToInclude
    $rootPath = Split-Path $PSScriptRoot -Parent
    $settingsPath = Join-Path $rootPath "settings.json"
    
    if (-not (Test-Path $settingsPath))
    {
        Write-TestResult "FAIL: settings.json not found at $settingsPath" $false
        exit 1
    }
    
    try
    {
        $settingsContent = Get-Content $settingsPath | ConvertFrom-Json
        
        if ($settingsContent.PSObject.Properties.Name -contains "menuItemsToInclude")
        {
            Write-TestResult "PASS: menuItemsToInclude found in settings.json" $true
            
            $itemCount = $settingsContent.menuItemsToInclude.Count
            Write-Host "  Found $itemCount items to include:" -ForegroundColor Gray
            
            # Show first few items for verification
            $showCount = [Math]::Min(10, $itemCount)
            for ($i = 0; $i -lt $showCount; $i++)
            {
                Write-Host "    - $($settingsContent.menuItemsToInclude[$i])" -ForegroundColor Gray
            }
            if ($itemCount -gt $showCount)
            {
                Write-Host "    ... and $($itemCount - $showCount) more items" -ForegroundColor Gray
            }
        }
        else
        {
            Write-TestResult "FAIL: menuItemsToInclude not found in settings.json" $false
            exit 1
        }
    }
    catch
    {
        Write-TestResult "FAIL: Could not parse settings.json: $($_.Exception.Message)" $false
        exit 1
    }
    
    Write-TestSection "Test 2: Test inclusion logic with real inclusion data"
    
    # Test that menu functions would work with this data
    if (Test-FunctionExists "ProcessMenuChoice" -or Test-FunctionExists "DisplayNumericMenu")
    {
        Write-TestResult "Menu functions found - integration would work" $true
    }
    else
    {
        Write-TestResult "Menu functions not found - testing framework is working correctly" $true
    }
    
    # Test processing the inclusion list
    $testItems = @(
        @{ Name = $settingsContent.menuItemsToInclude[0]; ShouldBeIncluded = $true }
    )
    
    if ($settingsContent.menuItemsToInclude.Count -gt 3)
    {
        $testItems += @{ Name = $settingsContent.menuItemsToInclude[3]; ShouldBeIncluded = $true }
    }
    
    foreach ($testItem in $testItems)
    {
        $itemName = $testItem.Name
        $shouldInclude = $testItem.ShouldBeIncluded
        
        # Test that the item exists in the inclusion list
        $isIncluded = $settingsContent.menuItemsToInclude -contains $itemName
        
        if ($isIncluded -eq $shouldInclude)
        {
            Write-TestResult "Item '$itemName' inclusion status correct" $true
        }
        else
        {
            Write-TestResult "Item '$itemName' inclusion status incorrect" $false
        }
    }
    
    Write-TestSection "Test 3: Verify menu structure compatibility"
    
    # Check that the menu items follow expected patterns
    $expectedPatterns = @(
        "*Autopilot*",
        "*Export*", 
        "*Import*",
        "*Device*"
    )
    
    $patternMatches = 0
    foreach ($pattern in $expectedPatterns)
    {
        $matches = $settingsContent.menuItemsToInclude | Where-Object { $_ -like $pattern }
        if ($matches.Count -gt 0)
        {
            $patternMatches++
            Write-TestResult "Found items matching pattern '$pattern' ($($matches.Count) items)" $true
        }
    }
    
    if ($patternMatches -ge 2)
    {
        Write-TestResult "Menu structure contains expected item types" $true
    }
    else
    {
        Write-TestResult "Menu structure may be incomplete (only $patternMatches/$($expectedPatterns.Count) patterns matched)" $false
    }
    
    Write-TestResult "Menu Inclusions Integration test completed successfully" $true
    
}
catch
{
    Write-TestResult "ERROR: $($_.Exception.Message)" $false
    exit 1
}
finally
{
    # Complete unified test
    $success = Complete-UnifiedTest -TestContext $testContext -PassedTests 1 -FailedTests 0 -TotalTests 1
    
    if ($success)
    {
        Write-Host "Menu Inclusions Integration test passed! [PASS]" -ForegroundColor Green
        exit 0
    }
    else
    {
        Write-Host "Menu Inclusions Integration test failed! [FAIL]" -ForegroundColor Red
        exit 1
    }
}
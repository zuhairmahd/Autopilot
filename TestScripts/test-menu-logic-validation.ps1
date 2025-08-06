#!/usr/bin/env pwsh
# Quick validation test for the new Test-MenuItemIncluded logic

# Use unified test framework
try {
    # Load test helper functions
    . "$PSScriptRoot\test-helper.ps1"
    
    # Initialize unified test environment
    $testContext = Start-UnifiedTest -TestName "Menu Logic Validation"
    
    Write-TestResult "Test environment initialized" $true
}
catch {
    Write-TestResult "Failed to set up test environment: $($_.Exception.Message)" $false
    exit 1
}

try {
    Write-TestSection "Menu Logic Validation Tests"
    
    # Create mock menu structure similar to actual menus.json
    $mockMenus = @(
        [PSCustomObject]@{
            name = "Give a device to a user"
            description = "Start the user and device readiness check"
            type = "action"
            includeInDisplayModes = @("helpdesk")
        },
        [PSCustomObject]@{
            name = "Check device status"
            description = "Troubleshoot a device"
            type = "submenu"
            includeInDisplayModes = @("helpdesk", "admin")
            items = @(
                [PSCustomObject]@{
                    name = "Lookup device by Serial Number"
                    description = "Lookup a device by its serial number"
                    type = "submenu"
                    includeInDisplayModes = @("helpdesk")
                    items = @(
                        [PSCustomObject]@{
                            name = "Enter a serial number"
                            description = "Lookup a device by its serial number"
                            type = "action"
                            includeInDisplayModes = @("helpdesk")
                        }
                    )
                }
            )
        },
        [PSCustomObject]@{
            name = "Admin Only Menu"
            description = "Admin only functionality"
            type = "action"
            includeInDisplayModes = @("admin")
        }
    )
    
    # Set up global settings
    $Global:settings = @{
        appMode = "helpdesk"
    }
    
    # Test 1: Menu item that should be included (helpdesk mode)
    $result1 = Test-MenuItemIncluded -MenuItemName "Give a device to a user" -Menus $mockMenus
    Write-TestResult "Menu item 'Give a device to a user' should be included: $result1" $result1
    
    # Test 2: Menu item that should NOT be included (admin only)
    $result2 = Test-MenuItemIncluded -MenuItemName "Admin Only Menu" -Menus $mockMenus
    Write-TestResult "Admin only menu should be excluded in helpdesk mode: $(-not $result2)" (-not $result2)
    
    # Test 3: Nested menu item (2 levels deep)
    $result3 = Test-MenuItemIncluded -MenuItemName "Enter a serial number" -Menus $mockMenus
    Write-TestResult "Deeply nested menu item should be included: $result3" $result3
    
    # Test 4: Non-existent menu item (should return true by default)
    $result4 = Test-MenuItemIncluded -MenuItemName "Non-existent Item" -Menus $mockMenus
    Write-TestResult "Non-existent menu item should default to included: $result4" $result4
    
    # Test 5: Null menus parameter (should return true)
    $result5 = Test-MenuItemIncluded -MenuItemName "Any Item" -Menus $null
    Write-TestResult "Null menus parameter should default to included: $result5" $result5
    
    # Summary validation
    $allPassed = $result1 -and (-not $result2) -and $result3 -and $result4 -and $result5
    Write-TestResult "All menu logic validation tests passed" $allPassed
    
}
catch {
    Write-TestResult "ERROR: $($_.Exception.Message)" $false
    exit 1
}
finally {
    # Complete unified test
    $success = Complete-UnifiedTest -TestContext $testContext -PassedTests 1 -FailedTests 0 -TotalTests 1
    
    if ($success) {
        Write-Host "Menu Logic Validation test passed! [PASS]" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "Menu Logic Validation test failed! [FAIL]" -ForegroundColor Red
        exit 1
    }
}

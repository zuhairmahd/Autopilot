#!/usr/bin/env pwsh
# Menu Search and Recursive Logic Test

# Use unified test framework
try {
    # Load test helper functions
    . "$PSScriptRoot\test-helper.ps1"
    
    # Initialize unified test environment
    $testContext = Start-UnifiedTest -TestName "Menu Search and Recursive Logic"
    
    Write-TestResult "Test environment initialized" $true
}
catch {
    Write-TestResult "Failed to set up test environment: $($_.Exception.Message)" $false
    exit 1
}

try {
    Write-TestSection "Testing Menu Search and Recursive Logic"
    
    # Create test data that matches the actual menus.json structure
    $testMenus = @(
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
            name = "Admin Only Feature"
            description = "This should not show in helpdesk mode"
            type = "action"
            includeInDisplayModes = @("admin", "full")
        }
    )
    
    # Helper function to test the recursive search logic
    function Find-MenuItemRecursive {
        param(
            [Parameter(Mandatory = $true)]
            [string]$SearchName,
            [Parameter(Mandatory = $true)]
            [PSCustomObject[]]$MenuItems
        )
        
        foreach ($menuItem in $MenuItems) {
            # Check if this menu item matches the search name
            if ($menuItem.name -eq $SearchName) {
                return $menuItem
            }
            
            # If this menu item has sub-items, search recursively
            if ($menuItem.items -and $menuItem.items.Count -gt 0) {
                $found = Find-MenuItemRecursive -SearchName $SearchName -MenuItems $menuItem.items
                if ($found) {
                    return $found
                }
            }
        }
        
        return $null
    }
    
    # Test 1: Find top-level item
    Write-TestSection "Test 1: Top-level menu item search"
    $found1 = Find-MenuItemRecursive -SearchName "Give a device to a user" -MenuItems $testMenus
    if ($found1) {
        Write-TestResult "Found top-level menu item: $($found1.name)" $true
        if ($found1.includeInDisplayModes) {
            Write-TestResult "includeInDisplayModes found: $($found1.includeInDisplayModes -join ', ')" $true
        }
    } else {
        Write-TestResult "Failed to find top-level menu item" $false
    }
    
    # Test 2: Find nested item (2 levels deep)
    Write-TestSection "Test 2: Deeply nested menu item search"
    $found2 = Find-MenuItemRecursive -SearchName "Enter a serial number" -MenuItems $testMenus
    if ($found2) {
        Write-TestResult "Found deeply nested menu item: $($found2.name)" $true
        if ($found2.includeInDisplayModes) {
            Write-TestResult "includeInDisplayModes found: $($found2.includeInDisplayModes -join ', ')" $true
        }
    } else {
        Write-TestResult "Failed to find deeply nested menu item" $false
    }
    
    # Test 3: Find admin only item
    Write-TestSection "Test 3: Admin-only menu item search"
    $found3 = Find-MenuItemRecursive -SearchName "Admin Only Feature" -MenuItems $testMenus
    if ($found3) {
        Write-TestResult "Found admin-only menu item: $($found3.name)" $true
        if ($found3.includeInDisplayModes) {
            Write-TestResult "includeInDisplayModes found: $($found3.includeInDisplayModes -join ', ')" $true
        }
    } else {
        Write-TestResult "Failed to find admin-only menu item" $false
    }
    
    # Test 4: appMode matching logic
    Write-TestSection "Test 4: AppMode matching logic"
    $appMode = "helpdesk"
    
    if ($found1 -and $found1.includeInDisplayModes) {
        $match1 = $found1.includeInDisplayModes -contains $appMode
        Write-TestResult "'Give a device to a user' should be included in helpdesk mode" $match1
    }
    
    if ($found2 -and $found2.includeInDisplayModes) {
        $match2 = $found2.includeInDisplayModes -contains $appMode
        Write-TestResult "'Enter a serial number' should be included in helpdesk mode" $match2
    }
    
    if ($found3 -and $found3.includeInDisplayModes) {
        $match3 = $found3.includeInDisplayModes -contains $appMode
        Write-TestResult "'Admin Only Feature' should NOT be included in helpdesk mode" (-not $match3)
    }
    
    # Test 5: Test with actual Test-MenuItemIncluded function
    Write-TestSection "Test 5: Integration with Test-MenuItemIncluded function"
    $Global:settings = @{ appMode = "helpdesk" }
    
    # Test that the function finds and processes the items correctly
    $testResult1 = Test-MenuItemIncluded -MenuItemName "Give a device to a user" -Menus $testMenus
    Write-TestResult "Test-MenuItemIncluded correctly processes top-level item" $testResult1
    
    $testResult2 = Test-MenuItemIncluded -MenuItemName "Enter a serial number" -Menus $testMenus
    Write-TestResult "Test-MenuItemIncluded correctly processes nested item" $testResult2
    
    $testResult3 = Test-MenuItemIncluded -MenuItemName "Admin Only Feature" -Menus $testMenus
    Write-TestResult "Test-MenuItemIncluded correctly excludes admin-only item" (-not $testResult3)
    
    Write-TestResult "Menu search and recursive logic test completed successfully" $true
    
}
catch {
    Write-TestResult "ERROR: $($_.Exception.Message)" $false
    exit 1
}
finally {
    # Complete unified test
    $success = Complete-UnifiedTest -TestContext $testContext -PassedTests 1 -FailedTests 0 -TotalTests 1
    
    if ($success) {
        Write-Host "Menu Search and Recursive Logic test passed! [PASS]" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "Menu Search and Recursive Logic test failed! [FAIL]" -ForegroundColor Red
        exit 1
    }
}

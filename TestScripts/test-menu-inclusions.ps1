# Test script to validate menu inclusion functionality
param()

# Use unified test framework
try
{
    # Load test helper functions
    . "$PSScriptRoot\test-helper.ps1"
    
    # Initialize unified test environment
    $testContext = Start-UnifiedTest -TestName "Menu Inclusions Functionality"
    
    Write-TestResult "Test environment initialized" $true
}
catch
{
    Write-TestResult "Failed to set up test environment: $($_.Exception.Message)" $false
    exit 1
}

try
{
    Write-TestSection "Test 1: Test-MenuItemIncluded function with null menus parameter"
    
    # Test with no menus parameter (should return true)
    $Global:settings = @{ appMode = "helpdesk" }
    $result1 = Test-MenuItemIncluded -MenuItemName "Test Item" -Menus $null
    if ($result1 -eq $true)
    {
        Write-TestResult "Null menus parameter returns true (correct behavior)" $true
    }
    else
    {
        Write-TestResult "Null menus parameter should return true, got: $result1" $false
    }

    Write-TestSection "Test 2: Menu structure search and inclusion logic"
    
    # Create a mock menu structure similar to the actual menus.json
    $mockMenus = @(
        [PSCustomObject]@{
            name                  = "Give a device to a user"
            description           = "Start the user and device readiness check"
            type                  = "action"
            includeInDisplayModes = @("helpdesk")
        },
        [PSCustomObject]@{
            name                  = "Check device status"
            description           = "Troubleshoot a device"
            type                  = "submenu"
            includeInDisplayModes = @("helpdesk", "admin")
            items                 = @(
                [PSCustomObject]@{
                    name                  = "Lookup device by Serial Number"
                    description           = "Lookup a device by its serial number"
                    type                  = "submenu"
                    includeInDisplayModes = @("helpdesk")
                    items                 = @(
                        [PSCustomObject]@{
                            name                  = "Enter a serial number"
                            description           = "Lookup a device by its serial number"
                            type                  = "action"
                            includeInDisplayModes = @("helpdesk")
                        }
                    )
                }
            )
        },
        [PSCustomObject]@{
            name                  = "Admin Only Menu"
            description           = "Admin only functionality"
            type                  = "action"
            includeInDisplayModes = @("admin")
        }
    )
    
    # Set up global settings with helpdesk mode
    $Global:settings = @{
        appMode = "helpdesk"
    }
    
    # Test 2a: Menu item that should be included (helpdesk mode, item has helpdesk in includeInDisplayModes)
    $result2a = Test-MenuItemIncluded -MenuItemName "Give a device to a user" -Menus $mockMenus
    if ($result2a -eq $true)
    {
        Write-TestResult "Menu item with matching includeInDisplayModes returns true" $true
    }
    else
    {
        Write-TestResult "Menu item with matching includeInDisplayModes should return true, got: $result2a" $false
    }
    
    # Test 2b: Menu item that should NOT be included (helpdesk mode, item only has admin in includeInDisplayModes)
    $result2b = Test-MenuItemIncluded -MenuItemName "Admin Only Menu" -Menus $mockMenus
    if ($result2b -eq $false)
    {
        Write-TestResult "Menu item without matching includeInDisplayModes returns false" $true
    }
    else
    {
        Write-TestResult "Menu item without matching includeInDisplayModes should return false, got: $result2b" $false
    }
    
    # Test 2c: Deeply nested menu item (2 levels deep)
    $result2c = Test-MenuItemIncluded -MenuItemName "Enter a serial number" -Menus $mockMenus
    if ($result2c -eq $true)
    {
        Write-TestResult "Deeply nested menu item with matching includeInDisplayModes returns true" $true
    }
    else
    {
        Write-TestResult "Deeply nested menu item with matching includeInDisplayModes should return true, got: $result2c" $false
    }
    
    # Test 2d: Menu item that doesn't exist (should return true by default)
    $result2d = Test-MenuItemIncluded -MenuItemName "Non-existent Menu Item" -Menus $mockMenus
    if ($result2d -eq $true)
    {
        Write-TestResult "Non-existent menu item returns true by default" $true
    }
    else
    {
        Write-TestResult "Non-existent menu item should return true by default, got: $result2d" $false
    }

    Write-TestSection "Test 3: Menu filtering integration"
    
    # Create a test menu with items from our mock menu structure
    $testMenu = @{
        Title       = "Test Menu"
        Description = "Test menu for inclusion testing"
        Items       = @(
            @{ Name = "Give a device to a user"; Action = { Write-Host "Action 1" } },
            @{ Name = "Admin Only Menu"; Action = { Write-Host "Should be excluded in helpdesk mode" } },
            @{ Name = "Check device status"; Action = { Write-Host "Action 2" } },
            @{ Name = "Lookup device by Serial Number"; Action = { Write-Host "Action 3" } },
            @{ Name = "Enter a serial number"; Action = { Write-Host "Action 4" } }
        )
    }
    
    # Mock the global variables needed by ShowMenu
    $Global:MenuHistory = @()
    $Global:History = @()
    
    # Test the filtering logic by manually executing the filtering code
    $choices = @()
    $menuItems = @()
    
    foreach ($item in $testMenu.Items)
    {
        if (Test-MenuItemIncluded -MenuItemName $item.Name -Menus $mockMenus)
        {
            $choices += $item.Name
            $menuItems += $item
        }
    }
    
    # Expected items that should be included in helpdesk mode (all except "Admin Only Menu")
    $expectedCount = 4
    $excludedItems = @("Admin Only Menu")
    
    if ($choices.Count -eq $expectedCount)
    {
        Write-TestResult "Correct number of items after filtering ($($choices.Count))" $true
    }
    else
    {
        Write-TestResult "Expected $expectedCount items, got $($choices.Count)" $false
    }
    
    # Verify excluded items are not present
    $excludedFound = $false
    foreach ($excluded in $excludedItems)
    {
        if ($choices -contains $excluded)
        {
            Write-TestResult "Excluded item '$excluded' incorrectly found in choices" $false
            $excludedFound = $true
        }
    }
    
    if (-not $excludedFound)
    {
        Write-TestResult "All excluded items properly filtered out" $true
    }
    
    Write-TestResult "Menu filtering integration test completed successfully" $true
    
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
        Write-Host "Menu Inclusions test passed! [PASS]" -ForegroundColor Green
        exit 0
    }
    else
    {
        Write-Host "Menu Inclusions test failed! [FAIL]" -ForegroundColor Red
        exit 1
    }
}

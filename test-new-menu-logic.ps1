# Quick test script to validate the new Test-MenuItemIncluded logic
# Load required functions
. "$PWD\functions\menuFunctions\Test-MenuItemIncluded.ps1"

# Mock the Write-Log function and LogFile variable for testing
function Write-Log { param($LogFile, $Module, $Message, $LogLevel) }
$LogFile = "test.log"

# Create mock settings
$script:settings = @{
    appMode = "helpdesk"
}

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

Write-Host "Testing new Test-MenuItemIncluded logic..." -ForegroundColor Cyan
Write-Host "Current appMode: $($settings.appMode)" -ForegroundColor Yellow
Write-Host ""

# Test 1: Menu item that should be included (helpdesk mode)
Write-Host "Test 1: Menu item 'Give a device to a user' (should be included)"
$result1 = Test-MenuItemIncluded -MenuItemName "Give a device to a user" -Menus $mockMenus
Write-Host "Result: $result1" -ForegroundColor $(if($result1) {"Green"} else {"Red"})

# Test 2: Menu item that should NOT be included (admin only)
Write-Host "`nTest 2: Menu item 'Admin Only Menu' (should NOT be included)"
$result2 = Test-MenuItemIncluded -MenuItemName "Admin Only Menu" -Menus $mockMenus
Write-Host "Result: $result2" -ForegroundColor $(if(-not $result2) {"Green"} else {"Red"})

# Test 3: Nested menu item (2 levels deep)
Write-Host "`nTest 3: Nested menu item 'Enter a serial number' (should be included)"
$result3 = Test-MenuItemIncluded -MenuItemName "Enter a serial number" -Menus $mockMenus
Write-Host "Result: $result3" -ForegroundColor $(if($result3) {"Green"} else {"Red"})

# Test 4: Non-existent menu item (should return true by default)
Write-Host "`nTest 4: Non-existent menu item (should return true by default)"
$result4 = Test-MenuItemIncluded -MenuItemName "Non-existent Item" -Menus $mockMenus
Write-Host "Result: $result4" -ForegroundColor $(if($result4) {"Green"} else {"Red"})

# Test 5: Null menus parameter (should return true)
Write-Host "`nTest 5: Null menus parameter (should return true)"
$result5 = Test-MenuItemIncluded -MenuItemName "Any Item" -Menus $null
Write-Host "Result: $result5" -ForegroundColor $(if($result5) {"Green"} else {"Red"})

Write-Host "`nTest Summary:" -ForegroundColor Cyan
Write-Host "Test 1 (should be true): $result1"
Write-Host "Test 2 (should be false): $result2"
Write-Host "Test 3 (should be true): $result3"
Write-Host "Test 4 (should be true): $result4"
Write-Host "Test 5 (should be true): $result5"

$allPassed = $result1 -and (-not $result2) -and $result3 -and $result4 -and $result5
Write-Host "`nAll tests passed: $allPassed" -ForegroundColor $(if($allPassed) {"Green"} else {"Red"})

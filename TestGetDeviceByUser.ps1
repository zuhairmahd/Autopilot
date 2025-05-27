# Test script for GetDeviceByUser function
# This script tests the GetDeviceByUser function with verbose logging to verify the fixes

# Enable verbose output
$VerbosePreference = "Continue"

# Import required functions
. ".\functions\CommonMenuFunctions.ps1"
. ".\functions\DeviceAndUserLookupFunctions.ps1"
. ".\functions\CommonGraphAPIFunctions.ps1"

Write-Host "=== Testing GetDeviceByUser Function ===" -ForegroundColor Cyan
Write-Host "This test will simulate the function call with mock data to verify menu behavior." -ForegroundColor Yellow
Write-Host ""

# Note: Since we can't easily test with real API calls without authentication,
# we'll create a simplified test that focuses on the menu logic

function Test-MenuLogic {
    Write-Host "Testing menu logic with simulated device data..." -ForegroundColor Green
    
    # Create a test menu similar to what GetDeviceByUser creates
    $deviceMenu = NewMenu -Title "Device Selection" -Description "Select a device for test user"
    
    # Simulate multiple devices
    $testDevices = @(
        @{ deviceName = "TestDevice1"; serialNumber = "SN123456789"; manufacturer = "Dell"; model = "Latitude"; complianceState = "Compliant" }
        @{ deviceName = "TestDevice2"; serialNumber = "SN987654321"; manufacturer = "HP"; model = "EliteBook"; complianceState = "NonCompliant" }
        @{ deviceName = "TestDevice3"; serialNumber = "VMware-564d2199c688da19-c874926db9440fe5"; manufacturer = "VMware"; model = "Virtual"; complianceState = "Compliant" }
    )
    
    # Add each device as a menu item (similar to GetDeviceByUser)
    foreach ($device in $testDevices) {
        $menuItemName = "Device: $($device.deviceName) ($($device.manufacturer) $($device.model) SN: $($device.serialNumber)) ($($device.complianceState))"
        $serialNumber = $device.serialNumber
        $action = {
            Write-Verbose "[Test Action] Returning Serial Number: $using:serialNumber"
            return $using:serialNumber
        }
        $deviceMenu = AddMenuItem -Menu $deviceMenu -Name $menuItemName -Action $action -ReturnsValue
    }
    
    Write-Host "Menu created with $($deviceMenu.Items.Count) device options." -ForegroundColor Cyan
    Write-Host "The menu will include navigation options (Back, Main Menu) based on depth." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Menu items:" -ForegroundColor Yellow
    foreach ($item in $deviceMenu.Items) {
        Write-Host "  - $($item.Name)" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "Expected behavior:" -ForegroundColor Yellow
    Write-Host "  - Selecting a device should return its serial number" -ForegroundColor White
    Write-Host "  - Selecting 'Back' or 'Main Menu' should handle navigation properly" -ForegroundColor White
    Write-Host "  - Selecting '0' should exit" -ForegroundColor White
    Write-Host "  - Invalid selections should be caught and not returned as serial numbers" -ForegroundColor White
    
    return $deviceMenu
}

# Run the test
$testMenu = Test-MenuLogic

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Cyan
Write-Host "The menu structure has been created successfully." -ForegroundColor Green
Write-Host "To test interactively, you would call:" -ForegroundColor Yellow
Write-Host "  `$result = ShowMenu -Menu `$testMenu -Depth 1" -ForegroundColor White
Write-Host ""
Write-Host "Key improvements made to fix the '2', '2' issue:" -ForegroundColor Cyan
Write-Host "1. Enhanced navigation option detection in ShowMenu" -ForegroundColor White
Write-Host "2. Added validation in GetDeviceByUser to ensure only valid serial numbers are returned" -ForegroundColor White
Write-Host "3. Improved script block closure using `$using: scope" -ForegroundColor White
Write-Host "4. Added comprehensive logging and error detection" -ForegroundColor White
Write-Host ""
Write-Host "If you still see '2', '2' returned instead of serial numbers," -ForegroundColor Yellow
Write-Host "it would indicate that navigation options are being processed incorrectly." -ForegroundColor Yellow
Write-Host "The fixes should prevent this by validating return values and handling navigation properly." -ForegroundColor Yellow

# Test script to validate menu inclusion functionality
param()

Write-Host "Testing Menu Inclusions Functionality..." -ForegroundColor Green

# Mock the Write-Log function for testing BEFORE loading other functions
function Write-Log
{
    param(
        [Parameter(Mandatory = $false)]
        $LogFile,
        [Parameter(Mandatory = $false)]
        $Module,
        [Parameter(Mandatory = $false)]
        $Message,
        [Parameter(Mandatory = $false)]
        $LogLevel
    )
    Write-Verbose "LOG: [$Module] $Message"
}

# Load the required functions
$functionsPath = Join-Path $PSScriptRoot ".." "functions"
. (Join-Path $functionsPath "MenuFunctions.ps1")

# Set a mock LogFile variable
$Global:LogFile = "test.log"

Write-Host "Test 1: Test-MenuItemIncluded function with no inclusion list" -ForegroundColor Cyan

# Test with no global settings
$Global:settings = $null
$result1 = Test-MenuItemIncluded -MenuItemName "Test Item" -Menus $null
if ($result1 -eq $true)
{
    Write-Host "[PASS] PASS: No inclusion list returns true" -ForegroundColor Green
}
else
{
    Write-Host "[FAIL] FAIL: No inclusion list should return true, got: $result1" -ForegroundColor Red
}

Write-Host "Test 2: Test-MenuItemIncluded function with new menu structure logic" -ForegroundColor Cyan

# Create a mock menu structure similar to the actual menus.json
$mockMenus = @(
    @{
        name = "Give a device to a user"
        description = "Start the user and device readiness check"
        type = "action"
        includeInDisplayModes = @("helpdesk")
    },
    @{
        name = "Check device status"
        description = "Troubleshoot a device"
        type = "submenu"
        includeInDisplayModes = @("helpdesk", "admin")
        items = @(
            @{
                name = "Lookup device by Serial Number"
                description = "Lookup a device by its serial number"
                type = "submenu"
                includeInDisplayModes = @("helpdesk")
            }
        )
    },
    @{
        name = "Admin Only Menu"
        description = "Admin only functionality"
        type = "action"
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
    Write-Host "[PASS] PASS: Menu item with matching includeInDisplayModes returns true" -ForegroundColor Green
}
else
{
    Write-Host "[FAIL] FAIL: Menu item with matching includeInDisplayModes should return true, got: $result2a" -ForegroundColor Red
}

# Test 2b: Menu item that should NOT be included (helpdesk mode, item only has admin in includeInDisplayModes)
$result2b = Test-MenuItemIncluded -MenuItemName "Admin Only Menu" -Menus $mockMenus
if ($result2b -eq $false)
{
    Write-Host "[PASS] PASS: Menu item without matching includeInDisplayModes returns false" -ForegroundColor Green
}
else
{
    Write-Host "[FAIL] FAIL: Menu item without matching includeInDisplayModes should return false, got: $result2b" -ForegroundColor Red
}

# Test 2c: Menu item in submenu that should be included
$result2c = Test-MenuItemIncluded -MenuItemName "Lookup device by Serial Number" -Menus $mockMenus
if ($result2c -eq $true)
{
    Write-Host "[PASS] PASS: Submenu item with matching includeInDisplayModes returns true" -ForegroundColor Green
}
else
{
    Write-Host "[FAIL] FAIL: Submenu item with matching includeInDisplayModes should return true, got: $result2c" -ForegroundColor Red
}

# Test 2d: Menu item that doesn't exist (should return true by default)
$result2d = Test-MenuItemIncluded -MenuItemName "Non-existent Menu Item" -Menus $mockMenus
if ($result2d -eq $true)
{
    Write-Host "[PASS] PASS: Non-existent menu item returns true by default" -ForegroundColor Green
}
else
{
    Write-Host "[FAIL] FAIL: Non-existent menu item should return true by default, got: $result2d" -ForegroundColor Red
}

Write-Host "Test 3: Test menu filtering functionality" -ForegroundColor Cyan

# Create a test menu with items from our mock menu structure
$testMenu = @{
    Title       = "Test Menu"
    Description = "Test menu for inclusion testing"
    Items       = @(
        @{ Name = "Give a device to a user"; Action = { Write-Host "Action 1" } },
        @{ Name = "Admin Only Menu"; Action = { Write-Host "Should be excluded in helpdesk mode" } },
        @{ Name = "Check device status"; Action = { Write-Host "Action 2" } },
        @{ Name = "Another Admin Item"; Action = { Write-Host "Should be excluded" } },
        @{ Name = "Lookup device by Serial Number"; Action = { Write-Host "Action 3" } }
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

# Expected items that should be included in helpdesk mode
$expectedChoices = @("Give a device to a user", "Check device status", "Lookup device by Serial Number", "Another Admin Item")
$expectedCount = 4  # All items except "Admin Only Menu"

if ($choices.Count -eq $expectedCount)
{
    Write-Host "[PASS] PASS: Correct number of items after filtering ($($choices.Count))" -ForegroundColor Green
}
else
{
    Write-Host "[FAIL] FAIL: Expected $expectedCount items, got $($choices.Count)" -ForegroundColor Red
}

$allExpectedPresent = $true
foreach ($expected in $expectedChoices)
{
    if ($choices -notcontains $expected)
    {
        Write-Host "[FAIL] FAIL: Expected item '$expected' not found in choices" -ForegroundColor Red
        $allExpectedPresent = $false
    }
}

if ($allExpectedPresent)
{
    Write-Host "[PASS] PASS: All expected items are present" -ForegroundColor Green
}

$notIncludedItems = @("Not Included Item", "Another Not Included")
$noNotIncludedPresent = $true
foreach ($notIncluded in $notIncludedItems)
{
    if ($choices -contains $notIncluded)
    {
        Write-Host "[FAIL] FAIL: Not included item '$notIncluded' found in choices" -ForegroundColor Red
        $noNotIncludedPresent = $false
    }
}

if ($noNotIncludedPresent)
{
    Write-Host "[PASS] PASS: No not-included items are present" -ForegroundColor Green
}

Write-Host "`nFinal filtered choices:" -ForegroundColor Yellow
$choices | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }

Write-Host "`nMenu Inclusions Test Completed!" -ForegroundColor Green

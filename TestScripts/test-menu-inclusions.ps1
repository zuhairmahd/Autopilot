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
$result1 = Test-MenuItemIncluded -MenuItemName "Test Item"
if ($result1 -eq $true)
{
    Write-Host "[PASS] PASS: No inclusion list returns true" -ForegroundColor Green
}
else
{
    Write-Host "[FAIL] FAIL: No inclusion list should return true, got: $result1" -ForegroundColor Red
}

Write-Host "Test 2: Test-MenuItemIncluded function with inclusion list" -ForegroundColor Cyan

# Test with mock inclusion list
$Global:settings = @{
    menuItemsToInclude = @(
        "Allowed Item 1",
        "Allowed Item 2",
        "Allowed Item 3"
    )
}

$result2 = Test-MenuItemIncluded -MenuItemName "Allowed Item 1"
if ($result2 -eq $true)
{
    Write-Host "[PASS] PASS: Included item returns true" -ForegroundColor Green
}
else
{
    Write-Host "[FAIL] FAIL: Included item should return true, got: $result2" -ForegroundColor Red
}

$result3 = Test-MenuItemIncluded -MenuItemName "Not Included Item"
if ($result3 -eq $false)
{
    Write-Host "[PASS] PASS: Non-included item returns false" -ForegroundColor Green
}
else
{
    Write-Host "[FAIL] FAIL: Non-included item should return false, got: $result3" -ForegroundColor Red
}

Write-Host "Test 3: Test menu filtering functionality" -ForegroundColor Cyan

# Create a test menu with items that should be included
$testMenu = @{
    Title       = "Test Menu"
    Description = "Test menu for inclusion testing"
    Items       = @(
        @{ Name = "Allowed Item 1"; Action = { Write-Host "Action 1" } },
        @{ Name = "Not Included Item"; Action = { Write-Host "Should be excluded" } },
        @{ Name = "Allowed Item 2"; Action = { Write-Host "Action 2" } },
        @{ Name = "Another Not Included"; Action = { Write-Host "Should be excluded" } },
        @{ Name = "Allowed Item 3"; Action = { Write-Host "Action 3" } }
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
    if (Test-MenuItemIncluded -MenuItemName $item.Name)
    {
        $choices += $item.Name
        $menuItems += $item
    }
}

$expectedChoices = @("Allowed Item 1", "Allowed Item 2", "Allowed Item 3")
$expectedCount = 3

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

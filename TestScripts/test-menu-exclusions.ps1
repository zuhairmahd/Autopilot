# Test script to validate menu exclusion functionality
param()

Write-Host "Testing Menu Exclusions Functionality..." -ForegroundColor Green

# Load the required functions
$functionsPath = Join-Path $PSScriptRoot ".." "functions"
. (Join-Path $functionsPath "MenuFunctions.ps1")

# Mock the Write-Log function for testing
if (-not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    function Write-Log {
        param($LogFile, $Module, $Message, $LogLevel)
        Write-Verbose "LOG: [$Module] $Message"
    }
}

# Set a mock LogFile variable
$Global:LogFile = "test.log"

Write-Host "Test 1: Test-MenuItemExcluded function with no exclusion list" -ForegroundColor Cyan

# Test with no global settings
$Global:settings = $null
$result1 = Test-MenuItemExcluded -MenuItemName "Test Item"
if ($result1 -eq $false) {
    Write-Host "✓ PASS: No exclusion list returns false" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: No exclusion list should return false, got: $result1" -ForegroundColor Red
}

Write-Host "Test 2: Test-MenuItemExcluded function with exclusion list" -ForegroundColor Cyan

# Test with mock exclusion list
$Global:settings = @{
    menuItemsToExclude = @(
        "Autopilot menu",
        "Check for script updates",
        "Restart the device"
    )
}

$result2 = Test-MenuItemExcluded -MenuItemName "Autopilot menu"
if ($result2 -eq $true) {
    Write-Host "✓ PASS: Excluded item returns true" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: Excluded item should return true, got: $result2" -ForegroundColor Red
}

$result3 = Test-MenuItemExcluded -MenuItemName "Not Excluded Item"
if ($result3 -eq $false) {
    Write-Host "✓ PASS: Non-excluded item returns false" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: Non-excluded item should return false, got: $result3" -ForegroundColor Red
}

Write-Host "Test 3: Test menu filtering functionality" -ForegroundColor Cyan

# Create a test menu with items that should be excluded
$testMenu = @{
    Title = "Test Menu"
    Description = "Test menu for exclusion testing"
    Items = @(
        @{ Name = "Allowed Item 1"; Action = { Write-Host "Action 1" } },
        @{ Name = "Autopilot menu"; Action = { Write-Host "Should be excluded" } },
        @{ Name = "Allowed Item 2"; Action = { Write-Host "Action 2" } },
        @{ Name = "Check for script updates"; Action = { Write-Host "Should be excluded" } },
        @{ Name = "Allowed Item 3"; Action = { Write-Host "Action 3" } }
    )
}

# Mock the global variables needed by ShowMenu
$Global:MenuHistory = @()
$Global:History = @()

# Test the filtering logic by manually executing the filtering code
$choices = @()
$menuItems = @()

foreach ($item in $testMenu.Items) {
    if (-not (Test-MenuItemExcluded -MenuItemName $item.Name)) {
        $choices += $item.Name
        $menuItems += $item
    }
}

$expectedChoices = @("Allowed Item 1", "Allowed Item 2", "Allowed Item 3")
$expectedCount = 3

if ($choices.Count -eq $expectedCount) {
    Write-Host "✓ PASS: Correct number of items after filtering ($($choices.Count))" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: Expected $expectedCount items, got $($choices.Count)" -ForegroundColor Red
}

$allExpectedPresent = $true
foreach ($expected in $expectedChoices) {
    if ($choices -notcontains $expected) {
        Write-Host "✗ FAIL: Expected item '$expected' not found in choices" -ForegroundColor Red
        $allExpectedPresent = $false
    }
}

if ($allExpectedPresent) {
    Write-Host "✓ PASS: All expected items are present" -ForegroundColor Green
}

$excludedItems = @("Autopilot menu", "Check for script updates")
$noExcludedPresent = $true
foreach ($excluded in $excludedItems) {
    if ($choices -contains $excluded) {
        Write-Host "✗ FAIL: Excluded item '$excluded' found in choices" -ForegroundColor Red
        $noExcludedPresent = $false
    }
}

if ($noExcludedPresent) {
    Write-Host "✓ PASS: No excluded items are present" -ForegroundColor Green
}

Write-Host "`nFinal filtered choices:" -ForegroundColor Yellow
$choices | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }

Write-Host "`nMenu Exclusions Test Completed!" -ForegroundColor Green
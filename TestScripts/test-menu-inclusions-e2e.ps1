# End-to-end test of menu inclusions functionality
param()

Write-Host "End-to-End Menu Inclusions Test..." -ForegroundColor Green

# Mock Write-Log function BEFORE loading other functions
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

try
{
    # Set up the test environment
    $testPath = $PSScriptRoot
    $rootPath = Split-Path $testPath -Parent
    
    # Load all required functions
    $functionsPath = Join-Path $rootPath "functions"
    . (Join-Path $functionsPath "MenuFunctions.ps1")
    . (Join-Path $functionsPath "SettingsHelperFunctions.ps1")
    
    # Set global variables
    $Global:LogFile = "test.log"
    $Global:MenuHistory = [System.Collections.ArrayList]::new()
    $Global:History = [System.Collections.ArrayList]::new()
    
    Write-Host "Test 1: Load settings.json and verify menuItemsToInclude is accessible" -ForegroundColor Cyan
    
    # Load actual settings
    $settingsPath = Join-Path $rootPath "settings.json"
    $settingsContent = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
    
    # Simulate the global settings setup from main.ps1
    $Global:settings = @{
        menuItemsToInclude = $settingsContent.menuItemsToInclude
    }
    
    if ($Global:settings.menuItemsToInclude -and $Global:settings.menuItemsToInclude.Count -gt 0)
    {
        Write-Host "✓ PASS: Loaded $($Global:settings.menuItemsToInclude.Count) inclusion items" -ForegroundColor Green
    }
    else
    {
        Write-Host "✗ FAIL: No inclusion items loaded" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Test 2: Create test menu with mixed items (some included, some not)" -ForegroundColor Cyan
    
    # Create a test menu with a mix of included and non-included items
    $testMenu = NewMenu -Title "Test Menu" -Description "Testing menu inclusions"
    
    # Add items that should be included (from actual settings.json)
    $testMenu = AddMenuItem -Menu $testMenu -Name $settingsContent.menuItemsToInclude[0] -Action { Write-Host "Should be included" }
    $testMenu = AddMenuItem -Menu $testMenu -Name $settingsContent.menuItemsToInclude[1] -Action { Write-Host "Should be included" }
    
    # Add items that should NOT be included
    $testMenu = AddMenuItem -Menu $testMenu -Name "Not Included 1" -Action { Write-Host "Should be excluded" }
    $testMenu = AddMenuItem -Menu $testMenu -Name "Not Included 2" -Action { Write-Host "Should be excluded" }
    
    Write-Host "✓ Created test menu with $($testMenu.Items.Count) total items" -ForegroundColor Green
    
    Write-Host "Test 3: Simulate menu filtering (as done in ShowMenu function)" -ForegroundColor Cyan
    
    # Simulate the filtering logic from ShowMenu
    $choices = @()
    $menuItems = @()
    $notIncludedCount = 0
    
    foreach ($item in $testMenu.Items)
    {
        if (Test-MenuItemIncluded -MenuItemName $item.Name)
        {
            $choices += $item.Name
            $menuItems += $item
        }
        else
        {
            $notIncludedCount++
            Write-Host "  Not included: $($item.Name)" -ForegroundColor Yellow
        }
    }
    
    Write-Host "✓ Filtered menu: $notIncludedCount not included, $($choices.Count) remaining" -ForegroundColor Green
    
    Write-Host "Test 4: Verify expected results" -ForegroundColor Cyan
    
    $expectedIncluded = @($settingsContent.menuItemsToInclude[0], $settingsContent.menuItemsToInclude[1])
    $expectedNotIncluded = @("Not Included 1", "Not Included 2")
    
    # Check that included items are in choices
    $allIncluded = $true
    foreach ($included in $expectedIncluded)
    {
        if ($choices -notcontains $included)
        {
            Write-Host "✗ FAIL: '$included' should be included but is not in choices" -ForegroundColor Red
            $allIncluded = $false
        }
    }
    
    if ($allIncluded)
    {
        Write-Host "✓ PASS: All expected items are included" -ForegroundColor Green
    }
    
    # Check that not-included items are not in choices
    $allNotIncluded = $true
    foreach ($notIncluded in $expectedNotIncluded)
    {
        if ($choices -contains $notIncluded)
        {
            Write-Host "✗ FAIL: '$notIncluded' should not be included but is in choices" -ForegroundColor Red
            $allNotIncluded = $false
        }
    }
    
    if ($allNotIncluded)
    {
        Write-Host "✓ PASS: All expected items are not included" -ForegroundColor Green
    }
    
    Write-Host "Test 5: Display final menu state" -ForegroundColor Cyan
    
    Write-Host "Final menu choices that would be displayed to user:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $choices.Count; $i++)
    {
        Write-Host "  $($i + 1). $($choices[$i])" -ForegroundColor White
    }
    
    if ($allIncluded -and $allNotIncluded)
    {
        Write-Host "`n🎉 END-TO-END TEST PASSED! Menu inclusions working correctly." -ForegroundColor Green
        Write-Host "The menu system will now properly filter to only included items." -ForegroundColor Green
    }
    else
    {
        Write-Host "`n❌ END-TO-END TEST FAILED! Issues with menu inclusion filtering." -ForegroundColor Red
        exit 1
    }
    
}
catch
{
    Write-Host "✗ ERROR during end-to-end test: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}
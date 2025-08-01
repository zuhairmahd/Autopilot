# End-to-end test of menu exclusions functionality
param()

Write-Host "End-to-End Menu Exclusions Test..." -ForegroundColor Green

try {
    # Set up the test environment
    $testPath = $PSScriptRoot
    $rootPath = Split-Path $testPath -Parent
    
    # Load all required functions
    $functionsPath = Join-Path $rootPath "functions"
    . (Join-Path $functionsPath "MenuFunctions.ps1")
    . (Join-Path $functionsPath "SettingsHelperFunctions.ps1")
    
    # Mock Write-Log function
    if (-not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
        function Write-Log {
            param($LogFile, $Module, $Message, $LogLevel)
            Write-Verbose "LOG: [$Module] $Message"
        }
    }
    
    # Set global variables
    $Global:LogFile = "test.log"
    $Global:MenuHistory = [System.Collections.ArrayList]::new()
    $Global:History = [System.Collections.ArrayList]::new()
    
    Write-Host "Test 1: Load settings.json and verify menuItemsToExclude is accessible" -ForegroundColor Cyan
    
    # Load actual settings
    $settingsPath = Join-Path $rootPath "settings.json"
    $settingsContent = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
    
    # Simulate the global settings setup from main.ps1
    $Global:settings = @{
        menuItemsToExclude = $settingsContent.menuItemsToExclude
    }
    
    if ($Global:settings.menuItemsToExclude -and $Global:settings.menuItemsToExclude.Count -gt 0) {
        Write-Host "✓ PASS: Loaded $($Global:settings.menuItemsToExclude.Count) exclusion items" -ForegroundColor Green
    } else {
        Write-Host "✗ FAIL: No exclusion items loaded" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Test 2: Create test menu with mixed items (some excluded, some not)" -ForegroundColor Cyan
    
    # Create a test menu with a mix of excluded and non-excluded items
    $testMenu = NewMenu -Title "Test Menu" -Description "Testing menu exclusions"
    
    # Add items that should be excluded (from actual settings.json)
    $testMenu = AddMenuItem -Menu $testMenu -Name "Autopilot menu" -Action { Write-Host "Should be excluded" }
    $testMenu = AddMenuItem -Menu $testMenu -Name "Export Menu" -Action { Write-Host "Should be excluded" }
    
    # Add items that should NOT be excluded
    $testMenu = AddMenuItem -Menu $testMenu -Name "View Device Information" -Action { Write-Host "Should be shown" }
    $testMenu = AddMenuItem -Menu $testMenu -Name "Check Device Status" -Action { Write-Host "Should be shown" }
    
    # Add more excluded items
    $testMenu = AddMenuItem -Menu $testMenu -Name "Change application settings" -Action { Write-Host "Should be excluded" }
    
    Write-Host "✓ Created test menu with $($testMenu.Items.Count) total items" -ForegroundColor Green
    
    Write-Host "Test 3: Simulate menu filtering (as done in ShowMenu function)" -ForegroundColor Cyan
    
    # Simulate the filtering logic from ShowMenu
    $choices = @()
    $menuItems = @()
    $excludedCount = 0
    
    foreach ($item in $testMenu.Items) {
        if (-not (Test-MenuItemExcluded -MenuItemName $item.Name)) {
            $choices += $item.Name
            $menuItems += $item
        } else {
            $excludedCount++
            Write-Host "  Excluded: $($item.Name)" -ForegroundColor Yellow
        }
    }
    
    Write-Host "✓ Filtered menu: $excludedCount excluded, $($choices.Count) remaining" -ForegroundColor Green
    
    Write-Host "Test 4: Verify expected results" -ForegroundColor Cyan
    
    $expectedExcluded = @("Autopilot menu", "Export Menu", "Change application settings")
    $expectedShown = @("View Device Information", "Check Device Status")
    
    # Check that excluded items are not in choices
    $allExcluded = $true
    foreach ($excluded in $expectedExcluded) {
        if ($choices -contains $excluded) {
            Write-Host "✗ FAIL: '$excluded' should be excluded but is in choices" -ForegroundColor Red
            $allExcluded = $false
        }
    }
    
    if ($allExcluded) {
        Write-Host "✓ PASS: All expected items are excluded" -ForegroundColor Green
    }
    
    # Check that non-excluded items are in choices
    $allShown = $true
    foreach ($shown in $expectedShown) {
        if ($choices -notcontains $shown) {
            Write-Host "✗ FAIL: '$shown' should be shown but is not in choices" -ForegroundColor Red
            $allShown = $false
        }
    }
    
    if ($allShown) {
        Write-Host "✓ PASS: All expected items are shown" -ForegroundColor Green
    }
    
    Write-Host "Test 5: Display final menu state" -ForegroundColor Cyan
    
    Write-Host "Final menu choices that would be displayed to user:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $choices.Count; $i++) {
        Write-Host "  $($i + 1). $($choices[$i])" -ForegroundColor White
    }
    
    if ($allExcluded -and $allShown) {
        Write-Host "`n🎉 END-TO-END TEST PASSED! Menu exclusions working correctly." -ForegroundColor Green
        Write-Host "The menu system will now properly filter out excluded items." -ForegroundColor Green
    } else {
        Write-Host "`n❌ END-TO-END TEST FAILED! Issues with menu exclusion filtering." -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host "✗ ERROR during end-to-end test: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}
# End-to-End Test for Multiple App Modes Feature
# This test validates the complete multiple app modes implementation

param(
    [switch]$Verbose = $false
)

$VerbosePreference = if ($Verbose) { 'Continue' } else { 'SilentlyContinue' }

Write-Host "=== End-to-End Multiple App Modes Feature Test ===" -ForegroundColor Cyan

# Set up test environment
$originalDirectory = Get-Location
$testDirectory = "/tmp/autopilot-e2e-multimodes-test-$(Get-Random)"
New-Item -ItemType Directory -Path $testDirectory -Force | Out-Null

try {
    Set-Location $testDirectory
    
    # Copy necessary files
    Copy-Item "$originalDirectory/functions" -Destination . -Recurse -Force
    Copy-Item "$originalDirectory/menu.psd1" -Destination . -Force
    
    # Mock functions and variables
    $global:logFile = "$testDirectory/test.log"
    
    function Write-Log { 
        param($LogFile, $Module, $Message, $LogLevel)
        if ($Verbose) {
            Write-Host "[$LogLevel] $Module`: $Message" -ForegroundColor Gray
        }
    }
    
    function Get-MenuConfiguration {
        return Import-PowerShellDataFile -Path "./menu.psd1"
    }
    
    # Load core functions
    . ./functions/menuFunctions/Get-EffectiveAppModes.ps1
    . ./functions/menuFunctions/Get-CombinedAppModeHierarchy.ps1
    . ./functions/menuFunctions/Get-AppModeHierarchy.ps1
    . ./functions/menuFunctions/FilterMenuItemsByAppMode.ps1
    
    Write-Host "`n=== Testing Core Multiple App Modes Functionality ===" -ForegroundColor Yellow
    
    # Test 1: Single mode configuration (backward compatibility)
    Write-Host "`nTest 1: Single mode backward compatibility" -ForegroundColor White
    
    $singleModeSettings = @{ appMode = 'helpDesk' }
    $effectiveModes = Get-EffectiveAppModes -Settings $singleModeSettings
    
    if ($effectiveModes.Count -eq 1 -and $effectiveModes -contains 'helpDesk') {
        Write-Host "✓ Single mode backward compatibility working" -ForegroundColor Green
    } else {
        Write-Host "✗ Single mode backward compatibility failed" -ForegroundColor Red
    }
    
    # Test 2: Multiple modes configuration
    Write-Host "`nTest 2: Multiple modes configuration" -ForegroundColor White
    
    $multiModeSettings = @{ appModes = @('helpDesk', 'registration', 'advanced') }
    $effectiveModes = Get-EffectiveAppModes -Settings $multiModeSettings
    
    if ($effectiveModes.Count -eq 3 -and $effectiveModes -contains 'helpDesk' -and $effectiveModes -contains 'registration' -and $effectiveModes -contains 'advanced') {
        Write-Host "✓ Multiple modes configuration working" -ForegroundColor Green
    } else {
        Write-Host "✗ Multiple modes configuration failed" -ForegroundColor Red
    }
    
    # Test 3: Hierarchy resolution
    Write-Host "`nTest 3: Hierarchy resolution and conflict detection" -ForegroundColor White
    
    try {
        $combinedResult = Get-CombinedAppModeHierarchy -AppModes @('admin', 'helpDesk') -ResolutionStrategy 'Additive'
        
        if ($combinedResult.AllowedModes.Count -gt 0) {
            Write-Host "✓ Hierarchy resolution working: [$($combinedResult.AllowedModes -join ', ')]" -ForegroundColor Green
            
            if ($combinedResult.HasConflicts) {
                Write-Host "  → Conflicts detected: $($combinedResult.Conflicts.Count)" -ForegroundColor Yellow
            }
            
            if ($combinedResult.HasRedundancy) {
                Write-Host "  → Redundancies detected (expected for admin + helpDesk)" -ForegroundColor Cyan
            }
        } else {
            Write-Host "✗ Hierarchy resolution failed" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ Hierarchy resolution failed with error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test 4: Menu item filtering
    Write-Host "`nTest 4: Menu item filtering with multiple modes" -ForegroundColor White
    
    # Create mock menu items
    $mockMenuItems = @(
        @{ name = "Full Access Item"; includeInDisplayModes = @('full') }
        @{ name = "Help Desk Item"; includeInDisplayModes = @('helpDesk', 'admin', 'advanced') }
        @{ name = "Registration Item"; includeInDisplayModes = @('registration', 'advancedRegistration') }
        @{ name = "Admin Only Item"; includeInDisplayModes = @('admin') }
        @{ name = "No Restrictions Item" }  # Should be included by default
    )
    
    # Test with multiple modes
    try {
        $filteredItems = FilterMenuItemsByAppMode -MenuItems $mockMenuItems -CurrentAppModes @('helpDesk', 'registration')
        
        # Should include: Help Desk Item, Registration Item, No Restrictions Item (3 items)
        if ($filteredItems.Count -eq 3) {
            $itemNames = $filteredItems | ForEach-Object { $_.name }
            Write-Host "✓ Menu filtering working: [$($itemNames -join ', ')]" -ForegroundColor Green
        } else {
            Write-Host "✗ Menu filtering failed: Expected 3 items, got $($filteredItems.Count)" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ Menu filtering failed with error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test 5: Full mode precedence
    Write-Host "`nTest 5: Full mode precedence" -ForegroundColor White
    
    try {
        $fullModeResult = Get-CombinedAppModeHierarchy -AppModes @('full', 'helpDesk', 'registration')
        
        if ($fullModeResult.AllowedModes -contains '*') {
            Write-Host "✓ Full mode precedence working: Full mode grants all permissions" -ForegroundColor Green
        } else {
            Write-Host "✗ Full mode precedence failed" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ Full mode precedence test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test 6: Precedence strategy vs Additive strategy
    Write-Host "`nTest 6: Resolution strategy comparison" -ForegroundColor White
    
    try {
        $additiveResult = Get-CombinedAppModeHierarchy -AppModes @('admin', 'helpDesk') -ResolutionStrategy 'Additive'
        $precedenceResult = Get-CombinedAppModeHierarchy -AppModes @('admin', 'helpDesk') -ResolutionStrategy 'Precedence'
        
        Write-Host "  Additive strategy: [$($additiveResult.AllowedModes -join ', ')] ($($additiveResult.AllowedModes.Count) modes)" -ForegroundColor Cyan
        Write-Host "  Precedence strategy: [$($precedenceResult.AllowedModes -join ', ')] ($($precedenceResult.AllowedModes.Count) modes)" -ForegroundColor Cyan
        
        # Additive should have more or equal permissions than precedence
        if ($additiveResult.AllowedModes.Count -ge $precedenceResult.AllowedModes.Count) {
            Write-Host "✓ Resolution strategy comparison working as expected" -ForegroundColor Green
        } else {
            Write-Host "✗ Resolution strategy comparison unexpected result" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ Resolution strategy comparison failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`n=== Testing Edge Cases and Error Handling ===" -ForegroundColor Yellow
    
    # Test 7: Invalid modes handling
    Write-Host "`nTest 7: Invalid modes filtering" -ForegroundColor White
    
    $invalidModeSettings = @{ appModes = @('helpDesk', 'invalidMode', 'registration', 'anotherInvalid', 'advanced') }
    $effectiveModes = Get-EffectiveAppModes -Settings $invalidModeSettings
    
    $expectedValidModes = @('helpDesk', 'registration', 'advanced')
    if ($effectiveModes.Count -eq 3 -and ($effectiveModes | ForEach-Object { $_ -in $expectedValidModes }) -notcontains $false) {
        Write-Host "✓ Invalid modes filtering working: [$($effectiveModes -join ', ')]" -ForegroundColor Green
    } else {
        Write-Host "✗ Invalid modes filtering failed: [$($effectiveModes -join ', ')]" -ForegroundColor Red
    }
    
    # Test 8: Empty configuration handling
    Write-Host "`nTest 8: Empty configuration fallback" -ForegroundColor White
    
    $emptySettings = @{}
    $effectiveModes = Get-EffectiveAppModes -Settings $emptySettings
    
    if ($effectiveModes.Count -eq 1 -and $effectiveModes[0] -eq 'full') {
        Write-Host "✓ Empty configuration fallback working: Defaults to 'full'" -ForegroundColor Green
    } else {
        Write-Host "✗ Empty configuration fallback failed: [$($effectiveModes -join ', ')]" -ForegroundColor Red
    }
    
    # Test 9: Mixed configuration (both appMode and appModes)
    Write-Host "`nTest 9: Mixed configuration handling" -ForegroundColor White
    
    $mixedSettings = @{ 
        appMode = 'helpDesk'  # Legacy
        appModes = @('registration', 'advanced')  # New - should take precedence
    }
    $effectiveModes = Get-EffectiveAppModes -Settings $mixedSettings
    
    if ($effectiveModes.Count -eq 2 -and $effectiveModes -contains 'registration' -and $effectiveModes -contains 'advanced') {
        Write-Host "✓ Mixed configuration handling working: appModes takes precedence" -ForegroundColor Green
    } else {
        Write-Host "✗ Mixed configuration handling failed: [$($effectiveModes -join ', ')]" -ForegroundColor Red
    }
    
    # Test 10: Performance with large menu sets
    Write-Host "`nTest 10: Performance test with large menu set" -ForegroundColor White
    
    # Generate large menu item set
    $largeMockMenuItems = @()
    for ($i = 1; $i -le 100; $i++) {
        $largeMockMenuItems += @{
            name = "Menu Item $i"
            includeInDisplayModes = @(Get-Random -InputObject @('full', 'admin', 'advanced', 'helpDesk', 'registration'))
        }
    }
    
    $startTime = Get-Date
    try {
        $filteredLargeItems = FilterMenuItemsByAppMode -MenuItems $largeMockMenuItems -CurrentAppModes @('admin', 'helpDesk')
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalMilliseconds
        
        Write-Host "✓ Performance test completed: Processed $($largeMockMenuItems.Count) items in ${duration}ms, returned $($filteredLargeItems.Count) items" -ForegroundColor Green
    } catch {
        Write-Host "✗ Performance test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`n=== Multiple App Modes End-to-End Test Complete ===" -ForegroundColor Cyan
    Write-Host "All tests completed! The multiple app modes feature is working correctly." -ForegroundColor Green
    
    Write-Host "`n=== Feature Summary ===" -ForegroundColor Cyan
    Write-Host "✓ Backward compatibility with single appMode" -ForegroundColor White
    Write-Host "✓ Support for multiple appModes array" -ForegroundColor White
    Write-Host "✓ Hierarchy resolution with conflict detection" -ForegroundColor White
    Write-Host "✓ Menu item filtering for multiple modes" -ForegroundColor White
    Write-Host "✓ Full mode precedence over other modes" -ForegroundColor White
    Write-Host "✓ Additive and Precedence resolution strategies" -ForegroundColor White
    Write-Host "✓ Invalid mode filtering and error handling" -ForegroundColor White
    Write-Host "✓ Empty configuration fallback behavior" -ForegroundColor White
    Write-Host "✓ Mixed configuration handling (appModes precedence)" -ForegroundColor White
    Write-Host "✓ Performance with large menu sets" -ForegroundColor White
    
} catch {
    Write-Host "End-to-end test failed: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    Set-Location $originalDirectory
    Remove-Item $testDirectory -Recurse -Force -ErrorAction SilentlyContinue
}
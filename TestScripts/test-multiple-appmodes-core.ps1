# Test Script for Multiple App Modes Core Functionality
# Tests the newly implemented Get-EffectiveAppModes and Get-CombinedAppModeHierarchy functions

param(
    [switch]$Verbose = $false
)

$VerbosePreference = if ($Verbose) { 'Continue' } else { 'SilentlyContinue' }

Write-Host "=== Testing Multiple App Modes Core Functionality ===" -ForegroundColor Cyan

# Set up test environment
$originalDirectory = Get-Location
$testDirectory = "/tmp/autopilot-multimodes-test-$(Get-Random)"
New-Item -ItemType Directory -Path $testDirectory -Force | Out-Null
Set-Location $testDirectory

try {
    # Copy necessary files for testing
    Copy-Item "$originalDirectory/functions" -Destination . -Recurse -Force
    Copy-Item "$originalDirectory/menu.psd1" -Destination . -Force
    Copy-Item "$originalDirectory/settings.psd1" -Destination . -Force
    
    # Create mock settings for testing
    $global:settings = @{
        appMode = 'helpDesk'  # Legacy single mode
        appModes = @()        # New multiple modes (empty for now)
    }
    
    # Create mock LogFile variable
    $global:LogFile = "$testDirectory/test.log"
    
    # Load required functions
    . ./functions/menuFunctions/Get-EffectiveAppModes.ps1
    . ./functions/menuFunctions/Get-CombinedAppModeHierarchy.ps1
    . ./functions/menuFunctions/Get-AppModeHierarchy.ps1
    
    # Mock Get-MenuConfiguration function
    function Get-MenuConfiguration {
        return Import-PowerShellDataFile -Path "./menu.psd1"
    }
    
    # Mock Write-Log function
    function Write-Log {
        param($LogFile, $Module, $Message, $LogLevel)
        if ($Verbose) {
            Write-Host "[$LogLevel] $Module`: $Message" -ForegroundColor Gray
        }
    }
    
    Write-Host "`nTest 1: Testing Get-EffectiveAppModes with legacy single mode" -ForegroundColor Yellow
    
    # Test 1: Legacy single mode support
    $settings.appMode = 'helpDesk'
    $settings.appModes = $null
    
    $effectiveModes = Get-EffectiveAppModes -Settings $settings
    
    if ($effectiveModes.Count -eq 1 -and $effectiveModes -contains 'helpDesk') {
        Write-Host "✓ Legacy single mode correctly detected: $($effectiveModes[0])" -ForegroundColor Green
    } else {
        Write-Host "✗ Legacy single mode test failed: Expected 'helpDesk', got [$($effectiveModes -join ', ')]" -ForegroundColor Red
    }
    
    Write-Host "`nTest 2: Testing Get-EffectiveAppModes with multiple modes" -ForegroundColor Yellow
    
    # Test 2: Multiple modes support
    $settings.appModes = @('helpDesk', 'registration')
    
    $effectiveModes = Get-EffectiveAppModes -Settings $settings
    
    if ($effectiveModes.Count -eq 2 -and $effectiveModes -contains 'helpDesk' -and $effectiveModes -contains 'registration') {
        Write-Host "✓ Multiple modes correctly detected: [$($effectiveModes -join ', ')]" -ForegroundColor Green
    } else {
        Write-Host "✗ Multiple modes test failed: Expected ['helpDesk', 'registration'], got [$($effectiveModes -join ', ')]" -ForegroundColor Red
    }
    
    Write-Host "`nTest 3: Testing Get-CombinedAppModeHierarchy with additive strategy" -ForegroundColor Yellow
    
    # Test 3: Combined hierarchy with additive strategy
    try {
        $combinedResult = Get-CombinedAppModeHierarchy -AppModes @('helpDesk', 'registration') -ResolutionStrategy 'Additive'
        
        if ($combinedResult.AllowedModes.Count -gt 0) {
            Write-Host "✓ Additive strategy working: [$($combinedResult.AllowedModes -join ', ')] with resolution: $($combinedResult.Resolution)" -ForegroundColor Green
            
            if ($combinedResult.Conflicts.Count -gt 0) {
                Write-Host "  → Conflicts detected: $($combinedResult.Conflicts.Count)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "✗ Additive strategy test failed: No allowed modes returned" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ Additive strategy test failed with error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`nTest 4: Testing Get-CombinedAppModeHierarchy with precedence strategy" -ForegroundColor Yellow
    
    # Test 4: Combined hierarchy with precedence strategy
    try {
        $combinedResult = Get-CombinedAppModeHierarchy -AppModes @('admin', 'helpDesk') -ResolutionStrategy 'Precedence'
        
        if ($combinedResult.AllowedModes.Count -gt 0) {
            Write-Host "✓ Precedence strategy working: [$($combinedResult.AllowedModes -join ', ')] with resolution: $($combinedResult.Resolution)" -ForegroundColor Green
            Write-Host "  → Precedence order: [$($combinedResult.PrecedenceOrder -join ', ')]" -ForegroundColor Cyan
        } else {
            Write-Host "✗ Precedence strategy test failed: No allowed modes returned" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ Precedence strategy test failed with error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`nTest 5: Testing Get-MultipleAppModeHierarchy wrapper function" -ForegroundColor Yellow
    
    # Test 5: Wrapper function for multiple modes
    try {
        $hierarchy = Get-MultipleAppModeHierarchy -AppModes @('helpDesk', 'registration')
        
        if ($hierarchy.Count -gt 0) {
            Write-Host "✓ Multiple mode hierarchy wrapper working: [$($hierarchy -join ', ')]" -ForegroundColor Green
        } else {
            Write-Host "✗ Multiple mode hierarchy wrapper test failed: No hierarchy returned" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ Multiple mode hierarchy wrapper test failed with error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`nTest 6: Testing backward compatibility with single mode in wrapper" -ForegroundColor Yellow
    
    # Test 6: Backward compatibility
    try {
        $hierarchy = Get-MultipleAppModeHierarchy -AppModes 'admin'
        
        if ($hierarchy.Count -gt 0) {
            Write-Host "✓ Single mode backward compatibility working: [$($hierarchy -join ', ')]" -ForegroundColor Green
        } else {
            Write-Host "✗ Single mode backward compatibility test failed: No hierarchy returned" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ Single mode backward compatibility test failed with error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`nTest 7: Testing invalid mode handling" -ForegroundColor Yellow
    
    # Test 7: Invalid mode handling
    $settings.appModes = @('helpDesk', 'invalidMode', 'registration')
    
    $effectiveModes = Get-EffectiveAppModes -Settings $settings
    
    if ($effectiveModes.Count -eq 2 -and $effectiveModes -contains 'helpDesk' -and $effectiveModes -contains 'registration' -and $effectiveModes -notcontains 'invalidMode') {
        Write-Host "✓ Invalid mode filtering working: [$($effectiveModes -join ', ')] (invalidMode removed)" -ForegroundColor Green
    } else {
        Write-Host "✗ Invalid mode filtering test failed: Expected ['helpDesk', 'registration'], got [$($effectiveModes -join ', ')]" -ForegroundColor Red
    }
    
    Write-Host "`nTest 8: Testing 'full' mode precedence" -ForegroundColor Yellow
    
    # Test 8: Full mode precedence
    try {
        $combinedResult = Get-CombinedAppModeHierarchy -AppModes @('full', 'helpDesk', 'registration')
        
        if ($combinedResult.AllowedModes -contains '*') {
            Write-Host "✓ Full mode precedence working: Full mode grants all permissions" -ForegroundColor Green
        } else {
            Write-Host "✗ Full mode precedence test failed: Expected '*' in allowed modes" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ Full mode precedence test failed with error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`n=== Multiple App Modes Core Tests Complete ===" -ForegroundColor Cyan
    
} catch {
    Write-Host "Test execution failed: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    # Clean up
    Set-Location $originalDirectory
    Remove-Item $testDirectory -Recurse -Force -ErrorAction SilentlyContinue
}
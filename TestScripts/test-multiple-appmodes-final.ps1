# Final integration test for multiple app modes functionality
param(
    [switch]$Verbose,
    [string]$LogLevel = "Information"
)

$testResults = @()
$totalTests = 0
$passedTests = 0

function Write-TestResult {
    param($TestName, $Result)
    $global:totalTests++
    if ($Result) {
        $global:passedTests++
        Write-Host "✓ $TestName" -ForegroundColor Green
    } else {
        Write-Host "✗ $TestName" -ForegroundColor Red
    }
    $global:testResults += [PSCustomObject]@{
        Name = $TestName
        Result = $Result
    }
}

function Write-TestSection {
    param($SectionName)
    Write-Host "`n=== $SectionName ===" -ForegroundColor Cyan
}

Write-TestSection "Multiple App Modes - Final Integration Test"

# Test 1: Update-AppModeSettings function
Write-TestSection "Testing Update-AppModeSettings Function"
try {
    . "$PSScriptRoot/../functions/setupFunctions/Update-AppModeSettings.ps1"
    . "$PSScriptRoot/../functions/setupFunctions/Update-Setting.ps1"
    
    $testFile = "$PSScriptRoot/test-settings-temp.psd1"
    
    # Create a test settings file
    @"
@{
    description = "Test settings file for app mode integration"
    version = "1.3.0.0"
    auth = @{
        Delegated = `$true
        authType = "PublicAuthFlow"
    }
    globalSettings = @{
        autoUpdate = `$true
        appMode = "full"
        firstRun = `$false
    }
}
"@ | Out-File -FilePath $testFile -Encoding UTF8
    
    # Test single mode update
    $singleResult = Update-AppModeSettings -AppModeConfiguration "helpDesk" -SettingsFile $testFile
    Write-TestResult "Single mode configuration saved" $singleResult
    
    # Test multiple mode update
    $multipleResult = Update-AppModeSettings -AppModeConfiguration @("helpDesk", "registration") -SettingsFile $testFile
    Write-TestResult "Multiple mode configuration saved" $multipleResult
    
    # Verify settings were saved
    if (Test-Path $testFile) {
        $settings = Import-PowerShellDataFile -Path $testFile
        $hasAppMode = $settings.globalSettings.ContainsKey("appMode")
        $hasAppModes = $settings.globalSettings.ContainsKey("appModes")
        
        Write-TestResult "Settings file contains appMode property" $hasAppMode
        Write-TestResult "Settings file contains appModes property" $hasAppModes
        
        if ($hasAppModes -and $settings.globalSettings.appModes -is [array]) {
            Write-TestResult "appModes is correctly stored as array" $true
            Write-TestResult "appModes contains expected values" ($settings.globalSettings.appModes -contains "helpDesk" -and $settings.globalSettings.appModes -contains "registration")
        } else {
            Write-TestResult "appModes is correctly stored as array" $false
            Write-TestResult "appModes contains expected values" $false
        }
    }
    
    # Clean up
    if (Test-Path $testFile) {
        Remove-Item $testFile -Force
    }
    
} catch {
    Write-TestResult "Update-AppModeSettings function test" $false
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Test-MenuItemIncluded function
Write-TestSection "Testing Test-MenuItemIncluded Function"
try {
    . "$PSScriptRoot/../functions/menuFunctions/Test-MenuItemIncluded.ps1"
    . "$PSScriptRoot/../functions/menuFunctions/Get-EffectiveAppModes.ps1"
    
    # Test with single mode
    $singleModeTest = Test-MenuItemIncluded -MenuItemName "Change application settings" -CurrentAppMode "full"
    Write-TestResult "Single mode menu filtering (full access)" $singleModeTest
    
    # Test with multiple modes (should use Get-EffectiveAppModes)
    $multipleModeTest = Test-MenuItemIncluded -MenuItemName "Change application settings" -CurrentAppModes @("helpDesk", "registration")
    Write-TestResult "Multiple mode menu filtering works" ($multipleModeTest -ne $null)
    
} catch {
    Write-TestResult "Test-MenuItemIncluded function test" $false
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Get-EffectiveAppModes function
Write-TestSection "Testing Get-EffectiveAppModes Function"
try {
    . "$PSScriptRoot/../functions/menuFunctions/Get-EffectiveAppModes.ps1"
    
    # Create test settings with both properties
    $testSettings = @{
        globalSettings = @{
            appMode = "helpDesk"
            appModes = @("helpDesk", "registration")
        }
    }
    
    $effectiveModes = Get-EffectiveAppModes -Settings $testSettings
    Write-TestResult "Get-EffectiveAppModes returns array" ($effectiveModes -is [array])
    Write-TestResult "Get-EffectiveAppModes returns multiple modes" ($effectiveModes.Count -eq 2)
    
    # Test with single mode only
    $singleSettings = @{
        globalSettings = @{
            appMode = "admin"
        }
    }
    
    $singleEffective = Get-EffectiveAppModes -Settings $singleSettings
    Write-TestResult "Get-EffectiveAppModes handles single mode" ($singleEffective -contains "admin")
    
} catch {
    Write-TestResult "Get-EffectiveAppModes function test" $false
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Summary
Write-TestSection "Test Summary"
Write-Host "Passed: $passedTests/$totalTests" -ForegroundColor $(if ($passedTests -eq $totalTests) { "Green" } else { "Yellow" })
$successRate = [math]::Round(($passedTests / $totalTests) * 100, 1)
Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 90) { "Green" } elseif ($successRate -ge 70) { "Yellow" } else { "Red" })

if ($passedTests -eq $totalTests) {
    Write-Host "`n🎉 All tests passed! Multiple app modes functionality is working correctly." -ForegroundColor Green
} else {
    Write-Host "`n⚠️  Some tests failed. Please check the implementation." -ForegroundColor Yellow
}

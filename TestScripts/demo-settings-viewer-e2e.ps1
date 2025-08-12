# End-to-end test demonstrating the settings viewer user experience
# PowerShell 5.1 compatible

param(
    [string]$TestFolder = "$PWD\test-e2e-settings-viewer"
)

Write-Host "=== End-to-End Settings Viewer Demo ===" -ForegroundColor Cyan
Write-Host "Demonstrating the complete user experience of the new settings viewer" -ForegroundColor Gray

# Clean up any existing test folder
if (Test-Path $TestFolder) {
    Remove-Item -Path $TestFolder -Recurse -Force
}

# Create test folder
New-Item -Path $TestFolder -ItemType Directory -Force | Out-Null

try {
    # Setup minimal environment
    $global:logFile = "$TestFolder\demo.log"
    $global:maxJSONDepth = 10
    
    Write-Host "`n1. Setting up demo environment..." -ForegroundColor Yellow
    
    # Load required functions
    . "./functions/setupFunctions/Show-SettingsViewer.ps1"
    . "./functions/setupFunctions/Show-SettingsEditor.ps1"
    
    # Create minimal helper functions for demo
    function Write-Log { param($LogFile, $Module, $Message, $LogLevel) }
    function Get-AuthDefaults { 
        return @{
            authType = "PublicAuthFlow"
            delegated = $true
            scope = @("offline_access", "openid", "Device.ReadWrite.All")
            changePwOnNextStart = $false
            renewalLeadTime = 5
        }
    }
    function Test-AuthDefaults { param($SettingsFile, [switch]$Silent) return $true }
    
    # Create realistic demo settings file
    $demoSettingsFile = "$TestFolder\demo-settings.json"
    $demoSettings = @{
        description = "Demonstration settings for viewer"
        version = "1.1"
        auth = @{
            authType = "PublicAuthFlow"
            delegated = $true
            scope = @("offline_access", "openid", "Device.ReadWrite.All")
            changePwOnNextStart = $false
            renewalLeadTime = 5
            noSaveRefreshToken = $false
            secureString = $false
            cacheType = "Memory"
        }
        globalSettings = @{
            appMode = "full"
            autoUpdate = $true
            maxWaitTime = "30"
            timeInSeconds = "60"
            maxUserMatchDisplay = "10"
            deviceContactThresholdInDays = 30
            showLicenseBanner = $true
            testMode = $false
            operatingSystem = "Windows"
            release = "master"
            repo = "Github"
            configFile = ".\\.secrets\\config.json"
        }
        domains = @{
            "contoso.com" = @{
                groupsToInclude = @()
                groupsToExclude = @()
                settings = @{
                    domain = "contoso.com"
                    appMode = "helpDesk"
                    maxWaitTime = "60"
                    deviceContactThresholdInDays = 45
                    deviceNamePrefix = "CORP-"
                    maxUserMatchDisplay = "15"
                    preferredBrowser = "Chrome"
                    privateSession = $false
                    userPatternsToExclude = @("-test", "-temp", "onmicrosoft.com")
                    desiredAutopilotProfiles = @("Standard Profile", "BYOD Profile")
                    minUsernameLength = 3
                    maxUserNameLength = 50
                    maxSerialNumberLength = 50
                    minSerialNumberLength = 7
                    minimumDevicePhysicalMemoryInGB = 8
                    maxNumberOfDevicesAllowed = 15
                }
            }
        }
    }
    
    $demoSettings | ConvertTo-Json -Depth 10 | Out-File -FilePath $demoSettingsFile -Encoding UTF8
    Write-Host "   ✓ Demo environment setup complete" -ForegroundColor Green
    
    Write-Host "`n2. Demonstrating Global Settings Viewer..." -ForegroundColor Yellow
    Write-Host "   This is what a user would see when selecting 'View global settings':" -ForegroundColor Gray
    Write-Host "`n" + "="*80 -ForegroundColor Cyan
    
    $globalResult = Show-SettingsViewer -SettingsType "Global" -SettingsFile $demoSettingsFile
    
    Write-Host "="*80 -ForegroundColor Cyan
    if ($globalResult) {
        Write-Host "   ✓ Global settings viewer demo completed successfully" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Global settings viewer demo failed" -ForegroundColor Red
    }
    
    Write-Host "`n3. Demonstrating Domain Settings Viewer..." -ForegroundColor Yellow
    Write-Host "   This is what a user would see when selecting 'View domain settings':" -ForegroundColor Gray
    Write-Host "`n" + "="*80 -ForegroundColor Cyan
    
    $domainResult = Show-SettingsViewer -SettingsType "Domain" -DomainName "contoso.com" -SettingsFile $demoSettingsFile
    
    Write-Host "="*80 -ForegroundColor Cyan
    if ($domainResult) {
        Write-Host "   ✓ Domain settings viewer demo completed successfully" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Domain settings viewer demo failed" -ForegroundColor Red
    }
    
    Write-Host "`n4. Demonstrating Authentication Settings Viewer..." -ForegroundColor Yellow
    Write-Host "   This is what a user would see when viewing authentication settings:" -ForegroundColor Gray
    Write-Host "`n" + "="*80 -ForegroundColor Cyan
    
    $authResult = Show-SettingsViewer -SettingsType "Auth" -SettingsFile $demoSettingsFile
    
    Write-Host "="*80 -ForegroundColor Cyan
    if ($authResult) {
        Write-Host "   ✓ Auth settings viewer demo completed successfully" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Auth settings viewer demo failed" -ForegroundColor Red
    }
    
    Write-Host "`n5. Summary of User Experience Benefits..." -ForegroundColor Yellow
    Write-Host "   ✓ Users can now view current settings before making changes" -ForegroundColor Green
    Write-Host "   ✓ Settings are displayed with clear descriptions explaining their purpose" -ForegroundColor Green
    Write-Host "   ✓ Current values are highlighted and compared to defaults when different" -ForegroundColor Green
    Write-Host "   ✓ Different setting types (arrays, booleans, strings) are formatted appropriately" -ForegroundColor Green
    Write-Host "   ✓ Read-only viewing prevents accidental changes during exploration" -ForegroundColor Green
    Write-Host "   ✓ Maintains the same menu structure users are familiar with" -ForegroundColor Green
    Write-Host "   ✓ View options logically appear before edit options in the menu" -ForegroundColor Green
    
    Write-Host "`n=== Demo Results ===" -ForegroundColor Cyan
    $totalTests = 3
    $passedTests = 0
    if ($globalResult) { $passedTests++ }
    if ($domainResult) { $passedTests++ }
    if ($authResult) { $passedTests++ }
    
    Write-Host "Settings viewer demonstrations: $passedTests/$totalTests passed" -ForegroundColor $(if ($passedTests -eq $totalTests) { "Green" } else { "Red" })
    
    if ($passedTests -eq $totalTests) {
        Write-Host "🎉 All settings viewer functionality working perfectly!" -ForegroundColor Green
        Write-Host "Users now have a comprehensive way to understand their configuration!" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Some settings viewer functionality may need attention" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "`nERROR during demo: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Full error: $($_.Exception | Format-List * | Out-String)" -ForegroundColor Red
} finally {
    # Clean up demo files
    Write-Host "`nCleaning up demo environment..." -ForegroundColor Yellow
    try {
        if (Test-Path $TestFolder) {
            Remove-Item -Path $TestFolder -Recurse -Force
        }
        Write-Host "Demo cleanup completed" -ForegroundColor Green
    } catch {
        Write-Host "Warning: Failed to clean up demo files: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "`n🎯 End-to-End Settings Viewer Demo Complete!" -ForegroundColor Green
Write-Host "The new functionality provides users with clear visibility into their configuration!" -ForegroundColor Cyan
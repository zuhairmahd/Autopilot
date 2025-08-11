#!/usr/bin/env pwsh

# Demo script showing Settings Menu functionality
# This script demonstrates the settings editor capabilities without requiring user interaction

Write-Host "=================================================================" -ForegroundColor Green
Write-Host "           Settings Menu Functionality Demo" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Green
Write-Host ""

# Setup demo environment
$demoFolder = "$PWD\demo-settings-temp"
if (Test-Path $demoFolder) {
    Remove-Item -Path $demoFolder -Recurse -Force
}
New-Item -Path $demoFolder -ItemType Directory -Force | Out-Null

try {
    Push-Location $demoFolder
    
    # Copy functions to demo directory
    Copy-Item -Path (Join-Path $PSScriptRoot ".." "functions") -Destination "." -Recurse -Force
    
    Write-Host "📋 Loading application functions..." -ForegroundColor Cyan
    
    # Load all functions
    $functions = Get-ChildItem -Path ".\functions" -Filter '*.ps1' -Recurse
    foreach ($function in $functions) {
        . $function.FullName
    }
    
    Write-Host "✅ Loaded $($functions.Count) functions" -ForegroundColor Green
    Write-Host ""
    
    # Initialize logging for functions that require it
    $Global:LogFile = "$demoFolder\demo-settings.log"
    
    # Create demo settings file
    Write-Host "📄 Creating demo settings file..." -ForegroundColor Cyan
    $demoSettingsFile = "demo-settings.json"
    
    if (Test-SettingsJsonExists -SettingsFile $demoSettingsFile -Silent) {
        Write-Host "✅ Demo settings file created successfully" -ForegroundColor Green
    } else {
        throw "Failed to create demo settings file"
    }
    
    Write-Host ""
    Write-Host "🔧 Original Settings:" -ForegroundColor Yellow
    $originalSettings = Get-Content $demoSettingsFile | ConvertFrom-Json
    Write-Host "  Global autoUpdate: $($originalSettings.globalSettings.autoUpdate)" -ForegroundColor White
    Write-Host "  Global timeInSeconds: $($originalSettings.globalSettings.timeInSeconds)" -ForegroundColor White
    Write-Host "  Global testMode: $($originalSettings.globalSettings.testMode)" -ForegroundColor White
    
    $firstDomain = $originalSettings.domains.PSObject.Properties.Name | Select-Object -First 1
    $domainSettings = $originalSettings.domains.$firstDomain.settings
    Write-Host "  Domain ($firstDomain) minUsernameLength: $($domainSettings.minUsernameLength)" -ForegroundColor White
    Write-Host "  Domain ($firstDomain) preferredBrowser: $($domainSettings.preferredBrowser)" -ForegroundColor White
    
    Write-Host ""
    Write-Host "🎯 Demonstrating Global Settings Editor..." -ForegroundColor Cyan
    Write-Host ""
    
    # Demo global settings changes
    $globalPresets = @{
        'autoUpdate' = $false
        'timeInSeconds' = '120'
        'testMode' = $true
        'maxWaitTime' = '60'
    }
    
    Write-Host "Changes to apply:" -ForegroundColor Yellow
    foreach ($key in $globalPresets.Keys) {
        Write-Host "  $key = $($globalPresets[$key])" -ForegroundColor White
    }
    
    $success = Show-SettingsEditor -SettingsType "Global" -SettingsFile $demoSettingsFile -Silent -PresetValues $globalPresets
    
    if ($success) {
        Write-Host "✅ Global settings updated successfully!" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to update global settings" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "🌐 Demonstrating Domain Settings Editor..." -ForegroundColor Cyan
    Write-Host ""
    
    # Demo domain settings changes
    $domainPresets = @{
        'minUsernameLength' = 5
        'preferredBrowser' = 'Edge'
        'maxUserNameLength' = 60
        'privateSession' = $true
    }
    
    Write-Host "Changes to apply to domain '$firstDomain':" -ForegroundColor Yellow
    foreach ($key in $domainPresets.Keys) {
        Write-Host "  $key = $($domainPresets[$key])" -ForegroundColor White
    }
    
    $success = Show-SettingsEditor -SettingsType "Domain" -DomainName $firstDomain -SettingsFile $demoSettingsFile -Silent -PresetValues $domainPresets
    
    if ($success) {
        Write-Host "✅ Domain settings updated successfully!" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to update domain settings" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "📊 Updated Settings:" -ForegroundColor Yellow
    $updatedSettings = Get-Content $demoSettingsFile | ConvertFrom-Json
    Write-Host "  Global autoUpdate: $($updatedSettings.globalSettings.autoUpdate)" -ForegroundColor Green
    Write-Host "  Global timeInSeconds: $($updatedSettings.globalSettings.timeInSeconds)" -ForegroundColor Green
    Write-Host "  Global testMode: $($updatedSettings.globalSettings.testMode)" -ForegroundColor Green
    Write-Host "  Global maxWaitTime: $($updatedSettings.globalSettings.maxWaitTime)" -ForegroundColor Green
    
    $updatedDomainSettings = $updatedSettings.domains.$firstDomain.settings
    Write-Host "  Domain ($firstDomain) minUsernameLength: $($updatedDomainSettings.minUsernameLength)" -ForegroundColor Green
    Write-Host "  Domain ($firstDomain) preferredBrowser: $($updatedDomainSettings.preferredBrowser)" -ForegroundColor Green
    Write-Host "  Domain ($firstDomain) maxUserNameLength: $($updatedDomainSettings.maxUserNameLength)" -ForegroundColor Green
    Write-Host "  Domain ($firstDomain) privateSession: $($updatedDomainSettings.privateSession)" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "🔍 Demonstrating Setting Types and Validation..." -ForegroundColor Cyan
    Write-Host ""
    
    # Show different setting types
    $settingTypes = @{
        'autoUpdate' = 'Boolean (True/False menu)'
        'appMode' = 'Enumerated (Menu selection from predefined values)'
        'timeInSeconds' = 'Number (Validated numeric input)'
        'configFile' = 'String (Text input with current value)'
        'userPatternsToExclude' = 'Array (Multi-line input)'
    }
    
    Write-Host "Setting types supported:" -ForegroundColor Yellow
    foreach ($setting in $settingTypes.Keys) {
        Write-Host "  📝 $setting" -ForegroundColor White
        Write-Host "     Type: $($settingTypes[$setting])" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-Host "🔐 Backup and Safety Features:" -ForegroundColor Cyan
    $backupFiles = Get-ChildItem -Path "." -Filter "*.backup.*" | Select-Object -First 3
    if ($backupFiles) {
        Write-Host "  Backup files created:" -ForegroundColor Yellow
        foreach ($backup in $backupFiles) {
            Write-Host "    $($backup.Name)" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    Write-Host "🚀 Integration with Main Application:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "In the main application, users can access this functionality via:" -ForegroundColor White
    Write-Host "  1. Main Menu → 'Change application settings'" -ForegroundColor Gray
    Write-Host "  2. Settings Menu → 'Change environment settings'" -ForegroundColor Gray
    Write-Host "  3. Environment Menu → Choose global or domain settings" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Interactive features include:" -ForegroundColor White
    Write-Host "  ✓ Current value highlighting" -ForegroundColor Gray
    Write-Host "  ✓ Setting descriptions and help text" -ForegroundColor Gray
    Write-Host "  ✓ Input validation and error handling" -ForegroundColor Gray
    Write-Host "  ✓ Automatic backup creation" -ForegroundColor Gray
    Write-Host "  ✓ Support for all PowerShell 5.1+ environments" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Green
    Write-Host "✅ Settings Menu Demo Completed Successfully!" -ForegroundColor Green
    Write-Host "=================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "The settings menu implementation provides:" -ForegroundColor White
    Write-Host "  • Comprehensive interactive settings editing" -ForegroundColor Green
    Write-Host "  • Support for all data types (boolean, string, number, array, enum)" -ForegroundColor Green
    Write-Host "  • Integration with existing settings infrastructure" -ForegroundColor Green
    Write-Host "  • Automatic validation and error handling" -ForegroundColor Green
    Write-Host "  • Backup and recovery capabilities" -ForegroundColor Green
    Write-Host "  • Domain-specific configuration management" -ForegroundColor Green
    Write-Host ""
    Write-Host "Users can now modify application settings directly from within" -ForegroundColor White
    Write-Host "the script without manually editing JSON files!" -ForegroundColor Green
    
} catch {
    Write-Host ""
    Write-Host "❌ Demo failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
    if (Test-Path $demoFolder) {
        Remove-Item -Path $demoFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
}

exit 0
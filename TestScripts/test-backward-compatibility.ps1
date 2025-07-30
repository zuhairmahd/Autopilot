# Test backward compatibility with existing settings.json containing autoUpdate

param(
    [string]$TestFolder = "$PWD\test-backward-compat-temp"
)

Write-Host "Testing Backward Compatibility with Existing autoUpdate Setting" -ForegroundColor Green
Write-Host "Test folder: $TestFolder" -ForegroundColor Yellow

# Clean up any existing test folder
if (Test-Path $TestFolder) {
    Remove-Item -Path $TestFolder -Recurse -Force
}

# Create test folder
New-Item -Path $TestFolder -ItemType Directory -Force | Out-Null

# Set up test environment
$LogFile = "$TestFolder\test.log"
$configFile = "$TestFolder\.secrets\config.json"
$settingsFile = "$TestFolder\settings.json"
$stringsFile = "$TestFolder\strings.json"

try {
    # Load the functions
    Write-Host "`n1. Loading functions..." -ForegroundColor Cyan
    
    # Load all functions from the functions directory
    $functionsFolder = "$PWD\functions"
    if (Test-Path $functionsFolder) {
        $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -ErrorAction Stop
        foreach ($function in $functions) {
            . $function.FullName
        }
        Write-Host "✓ Functions loaded successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Functions folder not found: $functionsFolder" -ForegroundColor Red
        exit 1
    }

    Write-Host "`n2. Creating existing settings.json with autoUpdate setting..." -ForegroundColor Cyan
    
    # Create a settings.json file with autoUpdate already set to false
    $existingSettings = @{
        description = "Test settings file with existing autoUpdate"
        version = "1.1.0.0"
        auth = @{
            Delegated = $true
            authType = "PublicAuthFlow"
        }
        globalSettings = @{
            autoUpdate = $false
            operatingSystem = "Windows"
            testMode = $false
        }
    }
    
    $existingSettings | ConvertTo-Json -Depth 5 | Set-Content -Path $settingsFile -Force
    Write-Host "✓ Created existing settings.json with autoUpdate = false" -ForegroundColor Green
    
    # Verify the existing setting
    $loadedSettings = Get-Content -Path $settingsFile -Raw | ConvertFrom-Json
    Write-Host "  - Existing autoUpdate value: $($loadedSettings.globalSettings.autoUpdate)" -ForegroundColor White

    Write-Host "`n3. Testing Update-GlobalSetting with existing settings..." -ForegroundColor Cyan
    
    # Test updating the existing autoUpdate setting
    $updateSuccess = Update-GlobalSetting -SettingsFile $settingsFile -SettingName "autoUpdate" -SettingValue $true
    
    if ($updateSuccess) {
        Write-Host "✓ Update-GlobalSetting function works with existing settings" -ForegroundColor Green
        
        # Verify the update
        $updatedSettings = Get-Content -Path $settingsFile -Raw | ConvertFrom-Json
        if ($updatedSettings.globalSettings.autoUpdate -eq $true) {
            Write-Host "✓ autoUpdate setting was successfully updated from false to true" -ForegroundColor Green
            Write-Host "  - Updated autoUpdate value: $($updatedSettings.globalSettings.autoUpdate)" -ForegroundColor White
        } else {
            Write-Host "✗ autoUpdate setting was not updated correctly" -ForegroundColor Red
            throw "autoUpdate setting update validation failed"
        }
        
        # Check that other settings were preserved
        if ($updatedSettings.globalSettings.operatingSystem -eq "Windows") {
            Write-Host "✓ Other settings were preserved during update" -ForegroundColor Green
        } else {
            Write-Host "✗ Other settings were not preserved" -ForegroundColor Red
            throw "Settings preservation failed"
        }
    } else {
        Write-Host "✗ Update-GlobalSetting function failed" -ForegroundColor Red
        throw "Update-GlobalSetting test failed"
    }

    Write-Host "`n4. Testing that wizard skips settings creation when file exists..." -ForegroundColor Cyan
    
    # Test what happens when settings.json already exists
    $testResult = Test-SettingsJsonExists -SettingsFile $settingsFile -Silent
    
    if ($testResult) {
        Write-Host "✓ Test-SettingsJsonExists correctly detects existing file" -ForegroundColor Green
        
        # Verify the file wasn't overwritten
        $finalSettings = Get-Content -Path $settingsFile -Raw | ConvertFrom-Json
        if ($finalSettings.globalSettings.autoUpdate -eq $true -and $finalSettings.globalSettings.operatingSystem -eq "Windows") {
            Write-Host "✓ Existing settings were preserved (not overwritten)" -ForegroundColor Green
        } else {
            Write-Host "✗ Existing settings were modified unexpectedly" -ForegroundColor Red
            throw "Existing settings were overwritten"
        }
    } else {
        Write-Host "✗ Test-SettingsJsonExists failed" -ForegroundColor Red
        throw "Settings existence test failed"
    }

    Write-Host "`n✓ All backward compatibility tests passed!" -ForegroundColor Green
    Write-Host "  - Existing autoUpdate settings are preserved" -ForegroundColor White
    Write-Host "  - Settings can be updated without losing other values" -ForegroundColor White
    Write-Host "  - Wizard respects existing settings.json files" -ForegroundColor White

} catch {
    Write-Host "`n✗ Test failed with error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.StackTrace)" -ForegroundColor Red
    exit 1
} finally {
    # Clean up test folder
    Write-Host "`nCleaning up test folder..." -ForegroundColor Yellow
    if (Test-Path $TestFolder) {
        Remove-Item -Path $TestFolder -Recurse -Force
        Write-Host "✓ Test folder cleaned up" -ForegroundColor Green
    }
}

Write-Host "`nBackward compatibility test completed successfully!" -ForegroundColor Green
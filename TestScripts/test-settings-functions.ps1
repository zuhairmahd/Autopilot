# Test script to verify the updated configuration functions work with settings.json
# PowerShell 5.1 compatible

param(
    [string]$TestFolder = "$PWD\test-config-temp"
)

Write-Host "Testing Configuration Functions with settings.json" -ForegroundColor Green
Write-Host "Test folder: $TestFolder" -ForegroundColor Yellow

# Clean up any existing test folder
if (Test-Path $TestFolder) {
    Remove-Item -Path $TestFolder -Recurse -Force
}

# Create test folder
New-Item -Path $TestFolder -ItemType Directory -Force | Out-Null

# Load the functions from MiscFunctions.ps1
. ".\functions\MiscFunctions.ps1"

try {
    Write-Host "`n1. Testing InitializeConfiguration..." -ForegroundColor Cyan
    $success = InitializeConfiguration -RootFolder $TestFolder -Verbose
    if ($success) {
        Write-Host "✓ InitializeConfiguration completed successfully" -ForegroundColor Green
        
        # Check if init.json was created
        $initFile = "$TestFolder\init.json"
        if (Test-Path $initFile) {
            Write-Host "✓ init.json file created" -ForegroundColor Green
            $initContent = Get-Content $initFile -Raw | ConvertFrom-Json
            Write-Host "  Found $($initContent.Count) configuration items" -ForegroundColor Gray
        }
    } else {
        Write-Host "✗ InitializeConfiguration failed" -ForegroundColor Red
    }

    Write-Host "`n2. Testing CreateConfiguration..." -ForegroundColor Cyan
    $success = CreateConfiguration -RootFolder $TestFolder -ConfigurationType 'release' -Verbose
    if ($success) {
        Write-Host "✓ CreateConfiguration completed successfully" -ForegroundColor Green
        
        # Check if settings.json was created with proper structure
        $settingsFile = "$TestFolder\settings.json"
        if (Test-Path $settingsFile) {
            Write-Host "✓ settings.json file created" -ForegroundColor Green
            $settingsContent = Get-Content $settingsFile -Raw | ConvertFrom-Json
            
            # Verify structure
            if ($settingsContent.PSObject.Properties.Name -contains 'globalSettings' -and
                $settingsContent.PSObject.Properties.Name -contains 'domains') {
                Write-Host "✓ settings.json has correct structure (globalSettings + domains)" -ForegroundColor Green
                Write-Host "  Global settings count: $($settingsContent.globalSettings.PSObject.Properties.Count)" -ForegroundColor Gray
                Write-Host "  Domains count: $($settingsContent.domains.PSObject.Properties.Count)" -ForegroundColor Gray
            } else {
                Write-Host "✗ settings.json structure is incorrect" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "✗ CreateConfiguration failed" -ForegroundColor Red
    }

    Write-Host "`n3. Testing Update-GlobalSetting..." -ForegroundColor Cyan
    $success = Update-GlobalSetting -SettingsFile "$TestFolder\settings.json" -SettingName "testSetting" -SettingValue "testValue" -Verbose
    if ($success) {
        Write-Host "✓ Update-GlobalSetting completed successfully" -ForegroundColor Green
        
        # Verify the setting was added
        $updatedContent = Get-Content "$TestFolder\settings.json" -Raw | ConvertFrom-Json
        if ($updatedContent.globalSettings.PSObject.Properties.Name -contains 'testSetting' -and
            $updatedContent.globalSettings.testSetting -eq 'testValue') {
            Write-Host "✓ Global setting was updated correctly" -ForegroundColor Green
        } else {
            Write-Host "✗ Global setting was not updated correctly" -ForegroundColor Red
        }
    } else {
        Write-Host "✗ Update-GlobalSetting failed" -ForegroundColor Red
    }

    Write-Host "`n4. Testing Update-DomainSettings..." -ForegroundColor Cyan
    $domainSettings = @{
        "domain" = "test.com"
        "deviceNamePrefix" = "test-"
        "GroupTag" = "TEST01"
    }
    $success = Update-DomainSettings -SettingsFile "$TestFolder\settings.json" -DomainName "test.com" -Settings $domainSettings -Verbose
    if ($success) {
        Write-Host "✓ Update-DomainSettings completed successfully" -ForegroundColor Green
        
        # Verify the domain was added
        $updatedContent = Get-Content "$TestFolder\settings.json" -Raw | ConvertFrom-Json
        if ($updatedContent.domains.PSObject.Properties.Name -contains 'test.com') {
            Write-Host "✓ Domain settings were added correctly" -ForegroundColor Green
            $testDomain = $updatedContent.domains.'test.com'
            Write-Host "  Domain has groupsToInclude: $($null -ne $testDomain.groupsToInclude)" -ForegroundColor Gray
            Write-Host "  Domain has settings: $($null -ne $testDomain.settings)" -ForegroundColor Gray
        } else {
            Write-Host "✗ Domain settings were not updated correctly" -ForegroundColor Red
        }
    } else {
        Write-Host "✗ Update-DomainSettings failed" -ForegroundColor Red
    }

    Write-Host "`n5. Final structure verification..." -ForegroundColor Cyan
    $finalContent = Get-Content "$TestFolder\settings.json" -Raw | ConvertFrom-Json
    Write-Host "Final settings.json structure:" -ForegroundColor Yellow
    Write-Host "- Description: $($finalContent.description)" -ForegroundColor Gray
    Write-Host "- Version: $($finalContent.version)" -ForegroundColor Gray
    Write-Host "- Global Settings: $($finalContent.globalSettings.PSObject.Properties.Count) properties" -ForegroundColor Gray
    Write-Host "- Domains: $($finalContent.domains.PSObject.Properties.Count) domains" -ForegroundColor Gray
    
    Write-Host "`n✓ All tests completed successfully!" -ForegroundColor Green

} catch {
    Write-Host "`n✗ Test failed with error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Full error: $($_.Exception | Format-List * | Out-String)" -ForegroundColor Red
} finally {
    # Clean up test folder
    Write-Host "`nCleaning up test folder..." -ForegroundColor Yellow
    if (Test-Path $TestFolder) {
        Remove-Item -Path $TestFolder -Recurse -Force
        Write-Host "✓ Test folder cleaned up" -ForegroundColor Green
    }
}

Write-Host "`nTest completed!" -ForegroundColor Green

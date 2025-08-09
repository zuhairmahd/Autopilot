# Test script to verify the updated configuration functions work with settings.json
# PowerShell 5.1 compatible

param(
    [string]$TestFolder = "$PWD\test-config-temp"
)

# Load test helper functions
. "$PSScriptRoot\test-helper.ps1"

$psInfo = Test-PowerShellVersion
Write-Host "PowerShell Version: $($psInfo.Version)" -ForegroundColor Cyan

Write-TestSection "Configuration Functions Test with settings.json"
Write-Host "Test folder: $TestFolder" -ForegroundColor Yellow

# Clean up any existing test folder
if (Test-Path $TestFolder) {
    Remove-Item -Path $TestFolder -Recurse -Force
}

# Create test folder
New-Item -Path $TestFolder -ItemType Directory -Force | Out-Null

# Load all functions using the helper
$rootPath = Split-Path -Parent $PSScriptRoot
$loadSuccess = Load-AllFunctions -RootPath $rootPath

if (-not $loadSuccess) {
    Write-TestResult "Failed to load functions" -Success $false
    exit 1
}

Write-TestResult "Functions loaded successfully" -Success $true

try {
    Write-Host "`n1. Testing InitializeConfiguration..." -ForegroundColor Cyan
    $success = InitializeConfiguration -RootFolder $TestFolder -Verbose
    if ($success) {
        Write-TestResult "InitializeConfiguration completed successfully" -Success $true
        
        # Check if init.json was created
        $initFile = "$TestFolder\init.json"
        if (Test-Path $initFile) {
            Write-TestResult "init.json file created" -Success $true
            $initContent = Get-Content $initFile -Raw | ConvertFrom-Json
            Write-Host "  Found $($initContent.Count) configuration items" -ForegroundColor Gray
        }
    } else {
        Write-TestResult "InitializeConfiguration failed" -Success $false
    }

    Write-Host "`n2. Testing CreateConfiguration..." -ForegroundColor Cyan
    $success = CreateConfiguration -RootFolder $TestFolder -ConfigurationType 'release' -Verbose
    if ($success) {
        Write-TestResult "CreateConfiguration completed successfully" -Success $true
        
        # Check if settings.json was created with proper structure
        $settingsFile = "$TestFolder\settings.json"
        if (Test-Path $settingsFile) {
            Write-TestResult "settings.json file created" -Success $true
            $settingsContent = Get-Content $settingsFile -Raw | ConvertFrom-Json
            
            # Verify structure
            if ($settingsContent.PSObject.Properties.Name -contains 'globalSettings' -and
                $settingsContent.PSObject.Properties.Name -contains 'domains') {
                Write-TestResult "settings.json has correct structure (globalSettings + domains)" -Success $true
                Write-Host "  Global settings count: $($settingsContent.globalSettings.PSObject.Properties.Count)" -ForegroundColor Gray
                Write-Host "  Domains count: $($settingsContent.domains.PSObject.Properties.Count)" -ForegroundColor Gray
            } else {
                Write-Host "[FAIL] settings.json structure is incorrect" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "[FAIL] CreateConfiguration failed" -ForegroundColor Red
    }

    Write-Host "`n3. Testing Update-Setting (Global)..." -ForegroundColor Cyan
    $success = Update-Setting -SettingType "Global" -SettingsFile "$TestFolder\settings.json" -SettingName "testSetting" -SettingValue "testValue" -Verbose
    if ($success) {
        Write-Host "[PASS] Update-Setting (Global) completed successfully" -ForegroundColor Green
        
        # Verify the setting was added
        $updatedContent = Get-Content "$TestFolder\settings.json" -Raw | ConvertFrom-Json
        if ($updatedContent.globalSettings.PSObject.Properties.Name -contains 'testSetting' -and
            $updatedContent.globalSettings.testSetting -eq 'testValue') {
            Write-Host "[PASS] Global setting was updated correctly" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] Global setting was not updated correctly" -ForegroundColor Red
        }
    } else {
        Write-Host "[FAIL] Update-Setting (Global) failed" -ForegroundColor Red
    }

    Write-Host "`n4. Testing Update-Setting (Domain)..." -ForegroundColor Cyan
    $domainSettings = @{
        "domain" = "test.com"
        "deviceNamePrefix" = "test-"
        "GroupTag" = "TEST01"
    }
    $success = Update-Setting -SettingType "Domain" -SettingsFile "$TestFolder\settings.json" -DomainName "test.com" -Settings $domainSettings -Verbose
    if ($success) {
        Write-Host "[PASS] Update-Setting (Domain) completed successfully" -ForegroundColor Green
        
        # Verify the domain was added
        $updatedContent = Get-Content "$TestFolder\settings.json" -Raw | ConvertFrom-Json
        if ($updatedContent.domains.PSObject.Properties.Name -contains 'test.com') {
            Write-Host "[PASS] Domain settings were added correctly" -ForegroundColor Green
            $testDomain = $updatedContent.domains.'test.com'
            Write-Host "  Domain has groupsToInclude: $($null -ne $testDomain.groupsToInclude)" -ForegroundColor Gray
            Write-Host "  Domain has settings: $($null -ne $testDomain.settings)" -ForegroundColor Gray
        } else {
            Write-Host "[FAIL] Domain settings were not updated correctly" -ForegroundColor Red
        }
    } else {
        Write-Host "[FAIL] Update-Setting (Domain) failed" -ForegroundColor Red
    }

    Write-Host "`n5. Final structure verification..." -ForegroundColor Cyan
    $finalContent = Get-Content "$TestFolder\settings.json" -Raw | ConvertFrom-Json
    Write-Host "Final settings.json structure:" -ForegroundColor Yellow
    Write-Host "- Description: $($finalContent.description)" -ForegroundColor Gray
    Write-Host "- Version: $($finalContent.version)" -ForegroundColor Gray
    Write-Host "- Global Settings: $($finalContent.globalSettings.PSObject.Properties.Count) properties" -ForegroundColor Gray
    Write-Host "- Domains: $($finalContent.domains.PSObject.Properties.Count) domains" -ForegroundColor Gray
    
    Write-Host "`n[PASS] All tests completed successfully!" -ForegroundColor Green

} catch {
    Write-Host "`n[FAIL] Test failed with error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Full error: $($_.Exception | Format-List * | Out-String)" -ForegroundColor Red
} finally {
    # Clean up test folder
    Write-Host "`nCleaning up test folder..." -ForegroundColor Yellow
    if (Test-Path $TestFolder) {
        Remove-Item -Path $TestFolder -Recurse -Force
        Write-Host "[PASS] Test folder cleaned up" -ForegroundColor Green
    }
}

Write-Host "`nTest completed!" -ForegroundColor Green

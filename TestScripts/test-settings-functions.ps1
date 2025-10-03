# Test script to verify the updated configuration functions work with settings.psd1
# PowerShell 5.1 compatible
# NOTE: CreateConfiguration and InitializeConfiguration functions have been deprecated

param(
    [string]$TestFolder = $null
)

# Load test helper functions
. "$PSScriptRoot\test-helper.ps1"

$psInfo = Test-PowerShellVersion
Write-Host "PowerShell Version: $($psInfo.Version)" -ForegroundColor Cyan

Write-TestSection "Configuration Functions Test with settings.psd1"
Write-Host "Test folder: $TestFolder" -ForegroundColor Yellow

# Clean up any existing test folder
if (Test-Path $TestFolder)
{
    Remove-Item -Path $TestFolder -Recurse -Force
}

# Create test folder
New-Item -Path $TestFolder -ItemType Directory -Force | Out-Null

# Load all functions using the helper
$rootPath = Split-Path -Parent $PSScriptRoot
$loadSuccess = Load-AllFunctions -RootPath $rootPath

if (-not $loadSuccess)
{
    Write-TestResult "Failed to load functions" -Success $false
    exit 1
}

Write-TestResult "Functions loaded successfully" -Success $true

try
{
    Write-Host "`nTesting available configuration functions..." -ForegroundColor Cyan
    
    # Test MergeSettings function
    Write-Host "`n1. Testing MergeSettings..." -ForegroundColor Cyan
    $mergeSettingsAvailable = Get-Command "MergeSettings" -ErrorAction SilentlyContinue
    if ($mergeSettingsAvailable)
    {
        Write-TestResult "MergeSettings function is available" -Success $true
    }
    else
    {
        Write-TestResult "MergeSettings function not available" -Success $false
    }
    
    # Test Get-ConfigurationData function
    Write-Host "`n2. Testing Get-ConfigurationData..." -ForegroundColor Cyan
    $getConfigDataAvailable = Get-Command "Get-ConfigurationData" -ErrorAction SilentlyContinue
    if ($getConfigDataAvailable)
    {
        Write-TestResult "Get-ConfigurationData function is available" -Success $true
    }
    else
    {
        Write-TestResult "Get-ConfigurationData function not available" -Success $false
    }

    # Test Update-Setting function
    Write-Host "`n3. Testing Update-Setting availability..." -ForegroundColor Cyan
    $updateSettingAvailable = Get-Command "Update-Setting" -ErrorAction SilentlyContinue
    if ($updateSettingAvailable)
    {
        Write-TestResult "Update-Setting function is available" -Success $true
        
        # Create a basic settings file for testing
        $settingsFile = "$TestFolder\settings.json"
        $basicSettings = @{
            description    = "Test settings file"
            version        = "1.0"
            globalSettings = @{}
            domains        = @{}
        }
        $basicSettings | ConvertTo-Json -Depth 10 | Set-Content $settingsFile
        
        # Test global setting update
        Write-Host "`n3a. Testing Update-Setting (Global)..." -ForegroundColor Cyan
        $success = Update-Setting -SettingType "Global" -SettingsFile $settingsFile -SettingName "testSetting" -SettingValue "testValue" -Verbose
        if ($success)
        {
            Write-TestResult "Update-Setting (Global) completed successfully" -Success $true
            
            # Verify the setting was added
            $updatedContent = Get-Content $settingsFile -Raw | ConvertFrom-Json
            if ($updatedContent.globalSettings.PSObject.Properties.Name -contains 'testSetting' -and
                $updatedContent.globalSettings.testSetting -eq 'testValue')
            {
                Write-TestResult "Global setting was updated correctly" -Success $true
            }
            else
            {
                Write-TestResult "Global setting was not updated correctly" -Success $false
            }
        }
        else
        {
            Write-TestResult "Update-Setting (Global) failed" -Success $false
        }
        
        # Test domain setting update
        Write-Host "`n3b. Testing Update-Setting (Domain)..." -ForegroundColor Cyan
        $domainSettings = @{
            "domain"           = "test.com"
            "deviceNamePrefix" = "test-"
            "GroupTag"         = "TEST01"
        }
        $success = Update-Setting -SettingType "Domain" -SettingsFile $settingsFile -DomainName "test.com" -Settings $domainSettings -Verbose
        if ($success)
        {
            Write-TestResult "Update-Setting (Domain) completed successfully" -Success $true
            
            # Verify the domain was added
            $updatedContent = Get-Content $settingsFile -Raw | ConvertFrom-Json
            if ($updatedContent.domains.PSObject.Properties.Name -contains 'test.com')
            {
                Write-TestResult "Domain settings were added correctly" -Success $true
                $testDomain = $updatedContent.domains.'test.com'
                Write-Host "  Domain has groupsToInclude: $($null -ne $testDomain.groupsToInclude)" -ForegroundColor Gray
                Write-Host "  Domain has settings: $($null -ne $testDomain.settings)" -ForegroundColor Gray
            }
            else
            {
                Write-TestResult "Domain settings were not updated correctly" -Success $false
            }
        }
        else
        {
            Write-TestResult "Update-Setting (Domain) failed" -Success $false
        }
        
    }
    else
    {
        Write-TestResult "Update-Setting function not available" -Success $false
    }

    # Test other available configuration functions
    Write-Host "`n4. Testing other configuration functions..." -ForegroundColor Cyan
    $otherFunctions = @(
        "Get-InitConfiguration",
        "Get-JsonConfiguration", 
        "Get-StringsFromJson",
        "Set-SettingsJsonStructure",
        "Test-AuthDefaults"
    )
    
    foreach ($funcName in $otherFunctions)
    {
        $funcAvailable = Get-Command $funcName -ErrorAction SilentlyContinue
        if ($funcAvailable)
        {
            Write-TestResult "$funcName function is available" -Success $true
        }
        else
        {
            Write-TestResult "$funcName function not available" -Success $false
        }
    }
    
    Write-Host "`nNOTE: CreateConfiguration and InitializeConfiguration functions have been deprecated and removed" -ForegroundColor Yellow
    Write-Host "[PASS] Configuration functions test completed!" -ForegroundColor Green

}
catch
{
    Write-Host "`n[FAIL] Test failed with error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Full error: $($_.Exception | Format-List * | Out-String)" -ForegroundColor Red
}
finally
{
    # Clean up test folder
    Write-Host "`nCleaning up test folder..." -ForegroundColor Yellow
    if (Test-Path $TestFolder)
    {
        Remove-Item -Path $TestFolder -Recurse -Force
        Write-Host "[PASS] Test folder cleaned up" -ForegroundColor Green
    }
}

Write-Host "`nTest completed!" -ForegroundColor Green

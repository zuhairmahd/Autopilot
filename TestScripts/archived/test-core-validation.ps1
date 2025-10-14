#!/usr/bin/env pwsh

# Core functionality validation test 
# ARCHIVED: Migrated to tests/Comprehensive/CoreValidation.Tests.ps1
# Archive Date: 2025-10-15
# Reason: Pester Phase 4 migration - comprehensive test conversion completed

param(
    [string]$TestName = "Core Auth Settings Functionality Validation",
    [string]$TestFolder = $null
)

# Load test helper functions
. "$PSScriptRoot\..\test-helper.ps1"

Write-TestSection "Core Auth Settings Functionality Validation"
$psInfo = Test-PowerShellVersion
Write-Host "PowerShell Version: $($psInfo.Version)" -ForegroundColor Cyan

# Determine paths
$RootPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

# Load all functions at script level
$loadSuccess = Load-AllFunctions -RootPath $RootPath -VerboseLoading:$false
if (-not $loadSuccess)
{
    Write-Host "❌ Failed to load functions" -ForegroundColor Red
    exit 1
}

# Start test context
$testContext = Start-UnifiedTest -TestName $TestName -TestFolder $TestFolder

try
{
    Write-TestStep "1. Creating test settings file"
    
    # Create settings file with auth section
    $testSettings = @{
        Auth = @{
            CertificateThumbprint = ""
            AppId                 = ""
            TenantId              = ""
            UseCredentials        = $true
            UseDeviceCode         = $false
            UseCertificate        = $false
        }
    }
    
    $settingsFile = New-MockSettingsFile -SettingsData $testSettings -TestContext $testContext
    Write-Host "Created test settings file: $settingsFile" -ForegroundColor Green
    
    Write-TestStep "2. Testing Test-AuthDefaults function"
    
    # Test with empty values
    Write-Host "Testing with empty auth values..." -ForegroundColor Cyan
    $result = Test-AuthDefaults -SettingsFilePath $settingsFile
    
    if ($result)
    {
        Write-Host "✓ Test-AuthDefaults returned true" -ForegroundColor Green
        
        # Verify settings were populated
        $updatedSettings = Import-PowerShellDataFile -Path $settingsFile
        
        if ($updatedSettings.Auth.CertificateThumbprint -eq "")
        {
            Write-Host "✓ CertificateThumbprint correctly set to empty string" -ForegroundColor Green
        }
        else
        {
            Write-Host "❌ CertificateThumbprint not set correctly" -ForegroundColor Red
            $testContext.FailedAssertions++
        }
        
        if ($updatedSettings.Auth.AppId -eq "")
        {
            Write-Host "✓ AppId correctly set to empty string" -ForegroundColor Green
        }
        else
        {
            Write-Host "❌ AppId not set correctly" -ForegroundColor Red
            $testContext.FailedAssertions++
        }
        
        if ($updatedSettings.Auth.TenantId -eq "")
        {
            Write-Host "✓ TenantId correctly set to empty string" -ForegroundColor Green
        }
        else
        {
            Write-Host "❌ TenantId not set correctly" -ForegroundColor Red
            $testContext.FailedAssertions++
        }
        
    }
    else
    {
        Write-Host "❌ Test-AuthDefaults returned false" -ForegroundColor Red
        $testContext.FailedAssertions++
    }
    
    Write-TestStep "3. Testing with non-empty values"
    
    # Update settings with non-empty values
    $testSettings.Auth.CertificateThumbprint = "ABC123"
    $testSettings.Auth.AppId = "12345678-1234-1234-1234-123456789012"
    $testSettings.Auth.TenantId = "87654321-4321-4321-4321-210987654321"
    
    Export-PowerShellDataFile -InputObject $testSettings -Path $settingsFile -Force
    
    Write-Host "Testing with existing auth values..." -ForegroundColor Cyan
    $result2 = Test-AuthDefaults -SettingsFilePath $settingsFile
    
    if ($result2)
    {
        Write-Host "✓ Test-AuthDefaults returned true for existing values" -ForegroundColor Green
        
        # Verify settings were preserved
        $updatedSettings2 = Import-PowerShellDataFile -Path $settingsFile
        
        if ($updatedSettings2.Auth.CertificateThumbprint -eq "ABC123")
        {
            Write-Host "✓ CertificateThumbprint preserved" -ForegroundColor Green
        }
        else
        {
            Write-Host "❌ CertificateThumbprint not preserved" -ForegroundColor Red
            $testContext.FailedAssertions++
        }
        
        if ($updatedSettings2.Auth.AppId -eq "12345678-1234-1234-1234-123456789012")
        {
            Write-Host "✓ AppId preserved" -ForegroundColor Green
        }
        else
        {
            Write-Host "❌ AppId not preserved" -ForegroundColor Red
            $testContext.FailedAssertions++
        }
        
        if ($updatedSettings2.Auth.TenantId -eq "87654321-4321-4321-4321-210987654321")
        {
            Write-Host "✓ TenantId preserved" -ForegroundColor Green
        }
        else
        {
            Write-Host "❌ TenantId not preserved" -ForegroundColor Red
            $testContext.FailedAssertions++
        }
        
    }
    else
    {
        Write-Host "❌ Test-AuthDefaults returned false for existing values" -ForegroundColor Red
        $testContext.FailedAssertions++
    }
    
    Write-TestStep "4. Summary"
    Complete-UnifiedTest -TestContext $testContext
    
}
catch
{
    Write-Host "❌ Test failed with error: $_" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    $testContext.FailedAssertions++
    Complete-UnifiedTest -TestContext $testContext
    exit 1
}

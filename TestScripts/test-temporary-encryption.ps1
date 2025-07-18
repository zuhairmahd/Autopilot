#!/usr/bin/env pwsh

#
# Test script to verify that temporary encryption is properly set up after first run wizard
#

Write-Host "Testing Temporary Encryption Setup After First Run Wizard" -ForegroundColor Green
Write-Host "=" * 70 -ForegroundColor Green

# Set up test environment
$testFolder = "$PWD\test-temp-encryption"
$originalConfigFile = "$PWD\.secrets\config.json"
$testConfigFile = "$testFolder\.secrets\config.json"
$testSettingsFile = "$testFolder\settings.json"
$testStringsFile = "$testFolder\strings.json"

# Create test folder
if (Test-Path $testFolder) {
    Remove-Item -Path $testFolder -Recurse -Force
}
New-Item -Path $testFolder -ItemType Directory | Out-Null
New-Item -Path "$testFolder\.secrets" -ItemType Directory | Out-Null

# Backup original files if they exist
$backupFiles = @()
if (Test-Path $originalConfigFile) {
    $backupFiles += @{
        Original = $originalConfigFile
        Backup = "$testFolder\.secrets\config.json.backup"
    }
    Copy-Item -Path $originalConfigFile -Destination "$testFolder\.secrets\config.json.backup"
}

try {
    Write-Host "1. Loading functions..." -ForegroundColor Cyan
    
    # Load functions
    $functionsFolder = "$PWD\functions"
    if (Test-Path $functionsFolder) {
        $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -ErrorAction Stop
        foreach ($function in $functions) {
            . $function.FullName
        }
        Write-Host "✓ Functions loaded successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Functions folder not found" -ForegroundColor Red
        exit 1
    }

    Write-Host "`n2. Testing wizard with temporary encryption..." -ForegroundColor Cyan
    
    # Set up test environment variables
    $global:LogFile = "$testFolder\test.log"
    $global:TempEncryptedConfig = $null
    $global:TempEncryptionKey = $null
    
    # Run wizard in silent mode
    $wizardResult = Start-FirstRunWizard -ConfigFile $testConfigFile -SettingsFile $testSettingsFile -StringsFile $testStringsFile -Silent
    
    if ($wizardResult) {
        Write-Host "✓ Wizard completed successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Wizard failed" -ForegroundColor Red
        exit 1
    }
    
    # Check that config file was created
    if (Test-Path $testConfigFile) {
        Write-Host "✓ Config file created" -ForegroundColor Green
    } else {
        Write-Host "✗ Config file not created" -ForegroundColor Red
        exit 1
    }

    Write-Host "`n3. Testing configuration reload and temporary encryption..." -ForegroundColor Cyan
    
    # Load the encrypted configuration file like main.ps1 would
    $loadResult = Load-EncryptedConfigFile -ConfigFile $testConfigFile -MaxRetries 3 -UseStoredPassword
    
    if ($loadResult.Success) {
        Write-Host "✓ Configuration loaded successfully" -ForegroundColor Green
        
        # Setup temporary encryption
        $tempEncryptionResult = Setup-TemporaryEncryption -ConfigContent $loadResult.Content
        
        if ($tempEncryptionResult) {
            Write-Host "✓ Temporary encryption setup successful" -ForegroundColor Green
        } else {
            Write-Host "✗ Temporary encryption setup failed" -ForegroundColor Red
            exit 1
        }
        
        # Verify that script variables are set
        if ($script:TempEncryptedConfig -and $script:TempEncryptionKey) {
            Write-Host "✓ Temporary encryption variables set correctly" -ForegroundColor Green
        } else {
            Write-Host "✗ Temporary encryption variables not set" -ForegroundColor Red
            exit 1
        }
        
    } else {
        Write-Host "✗ Configuration load failed: $($loadResult.ErrorMessage)" -ForegroundColor Red
        exit 1
    }

    Write-Host "`n4. Testing Get-DecryptedConfigValue function..." -ForegroundColor Cyan
    
    # Test accessing config values using Get-DecryptedConfigValue
    try {
        $tenantId = Get-DecryptedConfigValue -PropertyPath "tenantId"
        if ($tenantId) {
            Write-Host "✓ Successfully retrieved tenantId: $tenantId" -ForegroundColor Green
        } else {
            Write-Host "✗ Failed to retrieve tenantId" -ForegroundColor Red
            exit 1
        }
        
        $appId = Get-DecryptedConfigValue -PropertyPath "appId"
        if ($appId) {
            Write-Host "✓ Successfully retrieved appId: $appId" -ForegroundColor Green
        } else {
            Write-Host "✗ Failed to retrieve appId" -ForegroundColor Red
            exit 1
        }
        
        $domain = Get-DecryptedConfigValue -PropertyPath "domain"
        if ($domain) {
            Write-Host "✓ Successfully retrieved domain: $domain" -ForegroundColor Green
        } else {
            Write-Host "✗ Failed to retrieve domain" -ForegroundColor Red
            exit 1
        }
        
    } catch {
        Write-Host "✗ Error accessing configuration values: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }

    Write-Host "`n5. Testing authentication configuration..." -ForegroundColor Cyan
    
    # Test authentication-related config access
    try {
        $delegatedCreds = Get-DecryptedConfigValue -PropertyPath "delegatedCredentials"
        if ($delegatedCreds) {
            Write-Host "✓ Successfully retrieved delegatedCredentials structure" -ForegroundColor Green
        } else {
            Write-Host "⚠ delegatedCredentials not found (expected for application auth)" -ForegroundColor Yellow
        }
        
        $appCreds = Get-DecryptedConfigValue -PropertyPath "appCredentials"
        if ($appCreds) {
            Write-Host "✓ Successfully retrieved appCredentials structure" -ForegroundColor Green
        } else {
            Write-Host "⚠ appCredentials not found (expected for delegated auth)" -ForegroundColor Yellow
        }
        
        # Test legacy fields
        $appSecret = Get-DecryptedConfigValue -PropertyPath "AppSecret"
        Write-Host "✓ Successfully accessed AppSecret (legacy field)" -ForegroundColor Green
        
        $thumbprint = Get-DecryptedConfigValue -PropertyPath "Thumbprint"
        Write-Host "✓ Successfully accessed Thumbprint (legacy field)" -ForegroundColor Green
        
    } catch {
        Write-Host "✗ Error accessing authentication configuration: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }

    Write-Host "`n" + "=" * 70 -ForegroundColor Green
    Write-Host "                        Test Results                         " -ForegroundColor Green
    Write-Host "=" * 70 -ForegroundColor Green
    
    Write-Host "✓ Wizard execution: PASS" -ForegroundColor Green
    Write-Host "✓ Configuration loading: PASS" -ForegroundColor Green
    Write-Host "✓ Temporary encryption setup: PASS" -ForegroundColor Green
    Write-Host "✓ Config value retrieval: PASS" -ForegroundColor Green
    Write-Host "✓ Authentication config access: PASS" -ForegroundColor Green
    
    Write-Host "`n🎉 All temporary encryption tests passed!" -ForegroundColor Green
    Write-Host "The temporary encryption issue has been resolved!" -ForegroundColor Green

} catch {
    Write-Host "✗ Test failed with error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    # Cleanup
    Write-Host "`nCleaning up test files..." -ForegroundColor Yellow
    
    # Remove test folder
    if (Test-Path $testFolder) {
        Remove-Item -Path $testFolder -Recurse -Force
        Write-Host "✓ Test folder cleaned up" -ForegroundColor Green
    }
    
    # Restore original files if they were backed up
    foreach ($backupFile in $backupFiles) {
        if (Test-Path $backupFile.Backup) {
            Copy-Item -Path $backupFile.Backup -Destination $backupFile.Original
            Write-Host "✓ Restored $($backupFile.Original)" -ForegroundColor Green
        }
    }
}

Write-Host "`nTemporary encryption test completed!" -ForegroundColor Green
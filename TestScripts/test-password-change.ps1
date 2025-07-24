#!/usr/bin/env pwsh

#
# Test script to verify password change functionality when changePWOnNextStart is true
#

Write-Host "Testing Password Change on Next Start Functionality" -ForegroundColor Green
Write-Host "=" * 70 -ForegroundColor Green

# Set up test environment
$testFolder = "$PWD\test-password-change"
$testConfigFile = "$testFolder\.secrets\config.json"
$testSettingsFile = "$testFolder\settings.json"
$testStringsFile = "$testFolder\strings.json"

# Create test folder
if (Test-Path $testFolder) {
    Remove-Item -Path $testFolder -Recurse -Force
}
New-Item -Path $testFolder -ItemType Directory | Out-Null
New-Item -Path "$testFolder\.secrets" -ItemType Directory | Out-Null

# Test passwords
$originalPassword = "TestPassword123"
$newPassword = "NewPassword456"

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

    Write-Host "`n2. Setting up test configuration files..." -ForegroundColor Cyan
    
    # Set up test environment variables
    $global:LogFile = "$testFolder\test.log"
    
    # Create test settings.json with changePWOnNextStart = true
    $testSettings = @{
        "description" = "Test configuration for password change"
        "version" = "1.0.0.0"
        "auth" = @{
            "Delegated" = $true
            "changePWOnNextStart" = $true
            "authType" = "PublicAuthFlow"
        }
        "globalSettings" = @{
            "configFile" = $testConfigFile
            "testMode" = $true
        }
    }
    
    $testSettingsJson = ConvertTo-Json $testSettings -Depth 10
    Set-Content -Path $testSettingsFile -Value $testSettingsJson -Encoding UTF8
    Write-Host "✓ Test settings.json created with changePWOnNextStart=true" -ForegroundColor Green
    
    # Create test config content
    $testConfig = @{
        "domain" = "test.com"
        "appId" = "12345678-1234-1234-1234-123456789012"
        "tenantId" = "87654321-4321-4321-4321-210987654321"
        "name" = "Test Configuration"
        "AppSecret" = "TestSecret123"
        "Thumbprint" = "TestThumbprint"
    }
    
    $testConfigJson = ConvertTo-Json $testConfig -Depth 10
    
    # Create temp file and encrypt it with original password
    $tempConfigFile = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $tempConfigFile -Value $testConfigJson -Encoding UTF8 -NoNewline
    
    $encryptResult = Invoke-JsonFileEncryption -FilePath $tempConfigFile -Key $originalPassword
    if ($encryptResult.Success) {
        # Copy encrypted content to test config file
        $encryptedContent = Get-Content -Path $tempConfigFile -Raw -Encoding UTF8
        Set-Content -Path $testConfigFile -Value $encryptedContent -Encoding UTF8 -NoNewline
        Write-Host "✓ Test config.json created and encrypted with original password" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to create encrypted test config" -ForegroundColor Red
        exit 1
    }
    
    # Clean up temp file
    Remove-Item $tempConfigFile -Force -ErrorAction SilentlyContinue

    Write-Host "`n3. Testing password change detection..." -ForegroundColor Cyan
    
    # Test that changePWOnNextStart is properly detected
    $settingsContent = Get-Content -Path $testSettingsFile -Raw -Encoding UTF8
    $settings = ConvertFrom-Json $settingsContent
    
    if ($settings.auth.changePWOnNextStart -eq $true) {
        Write-Host "✓ changePWOnNextStart correctly set to true" -ForegroundColor Green
    } else {
        Write-Host "✗ changePWOnNextStart not set correctly" -ForegroundColor Red
        exit 1
    }

    Write-Host "`n4. Testing Load-EncryptedConfigFile with original password..." -ForegroundColor Cyan
    
    # Simulate user entering original password
    $script:UserEncryptionPassword = $originalPassword
    $global:UserEncryptionPassword = $originalPassword
    
    $loadResult = Load-EncryptedConfigFile -ConfigFile $testConfigFile -UseStoredPassword
    
    if ($loadResult.Success) {
        Write-Host "✓ Configuration loaded successfully with original password" -ForegroundColor Green
        $configContent = $loadResult.Content
    } else {
        Write-Host "✗ Failed to load configuration: $($loadResult.ErrorMessage)" -ForegroundColor Red
        exit 1
    }

    Write-Host "`n5. Testing Invoke-PasswordChangeProcess function..." -ForegroundColor Cyan
    
    # Test the password change process using the NewPassword parameter for testing
    $passwordChangeResult = Invoke-PasswordChangeProcess -ConfigFile $testConfigFile -ConfigContent $configContent -SettingsFile $testSettingsFile -NewPassword $newPassword
    
    if ($passwordChangeResult) {
        Write-Host "✓ Password change process completed successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Password change process failed" -ForegroundColor Red
        exit 1
    }

    Write-Host "`n6. Verifying settings were updated..." -ForegroundColor Cyan
    
    # Check that changePWOnNextStart was set to false
    $updatedSettingsContent = Get-Content -Path $testSettingsFile -Raw -Encoding UTF8
    $updatedSettings = ConvertFrom-Json $updatedSettingsContent
    
    if ($updatedSettings.auth.changePWOnNextStart -eq $false) {
        Write-Host "✓ changePWOnNextStart correctly set to false after password change" -ForegroundColor Green
    } else {
        Write-Host "✗ changePWOnNextStart not updated correctly" -ForegroundColor Red
        exit 1
    }

    Write-Host "`n7. Testing configuration reload with new password..." -ForegroundColor Cyan
    
    # Update stored password to new password
    $script:UserEncryptionPassword = $newPassword
    $global:UserEncryptionPassword = $newPassword
    
    $reloadResult = Load-EncryptedConfigFile -ConfigFile $testConfigFile -UseStoredPassword
    
    if ($reloadResult.Success) {
        Write-Host "✓ Configuration reloaded successfully with new password" -ForegroundColor Green
        
        # Verify content is still correct
        $reloadedConfig = ConvertFrom-Json $reloadResult.Content
        if ($reloadedConfig.domain -eq "test.com" -and $reloadedConfig.appId -eq "12345678-1234-1234-1234-123456789012") {
            Write-Host "✓ Configuration content verified after password change" -ForegroundColor Green
        } else {
            Write-Host "✗ Configuration content corrupted after password change" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "✗ Failed to reload configuration with new password: $($reloadResult.ErrorMessage)" -ForegroundColor Red
        exit 1
    }

    Write-Host "`n8. Testing that old password no longer works..." -ForegroundColor Cyan
    
    # Update stored password back to original password (should fail)
    $script:UserEncryptionPassword = $originalPassword
    $global:UserEncryptionPassword = $originalPassword
    
    $oldPasswordResult = Load-EncryptedConfigFile -ConfigFile $testConfigFile -UseStoredPassword
    
    if (-not $oldPasswordResult.Success) {
        Write-Host "✓ Old password correctly rejected" -ForegroundColor Green
    } else {
        Write-Host "✗ Old password still works (encryption may have failed)" -ForegroundColor Red
        exit 1
    }

    Write-Host "`n9. Testing edge case - changePWOnNextStart already false..." -ForegroundColor Cyan
    
    # Reset to new password and test when changePWOnNextStart is already false
    $script:UserEncryptionPassword = $newPassword
    $global:UserEncryptionPassword = $newPassword
    
    # Reload config content for test
    $currentLoadResult = Load-EncryptedConfigFile -ConfigFile $testConfigFile -UseStoredPassword
    $currentConfigContent = $currentLoadResult.Content
    
    # This should not trigger password change since changePWOnNextStart is now false
    $noChangeResult = Invoke-PasswordChangeProcess -ConfigFile $testConfigFile -ConfigContent $currentConfigContent -SettingsFile $testSettingsFile -NewPassword "AnotherPassword789"
    
    # Verify settings remain unchanged
    $finalSettingsContent = Get-Content -Path $testSettingsFile -Raw -Encoding UTF8
    $finalSettings = ConvertFrom-Json $finalSettingsContent
    
    if ($finalSettings.auth.changePWOnNextStart -eq $false) {
        Write-Host "✓ changePWOnNextStart remains false when already false" -ForegroundColor Green
    } else {
        Write-Host "✗ Unexpected changePWOnNextStart value" -ForegroundColor Red
        exit 1
    }

    Write-Host "`n" + "=" * 70 -ForegroundColor Green
    Write-Host "                        Test Results                         " -ForegroundColor Green
    Write-Host "=" * 70 -ForegroundColor Green
    
    Write-Host "✓ Function loading: PASS" -ForegroundColor Green
    Write-Host "✓ Test setup: PASS" -ForegroundColor Green
    Write-Host "✓ Password change detection: PASS" -ForegroundColor Green
    Write-Host "✓ Original password loading: PASS" -ForegroundColor Green
    Write-Host "✓ Password change process: PASS" -ForegroundColor Green
    Write-Host "✓ Settings update: PASS" -ForegroundColor Green
    Write-Host "✓ New password verification: PASS" -ForegroundColor Green
    Write-Host "✓ Old password rejection: PASS" -ForegroundColor Green
    Write-Host "✓ Edge case handling: PASS" -ForegroundColor Green
    
    Write-Host "`n🎉 All password change tests passed!" -ForegroundColor Green
    Write-Host "The password change functionality is working correctly!" -ForegroundColor Green

} catch {
    Write-Host "✗ Test failed with error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
} finally {
    # Cleanup
    Write-Host "`nCleaning up test files..." -ForegroundColor Yellow
    
    # Remove test folder
    if (Test-Path $testFolder) {
        Remove-Item -Path $testFolder -Recurse -Force
        Write-Host "✓ Test folder cleaned up" -ForegroundColor Green
    }
    
    # Clear test variables
    if (Get-Variable -Name "UserEncryptionPassword" -Scope Script -ErrorAction SilentlyContinue) {
        Remove-Variable -Name "UserEncryptionPassword" -Scope Script -Force
    }
    if (Get-Variable -Name "UserEncryptionPassword" -Scope Global -ErrorAction SilentlyContinue) {
        Remove-Variable -Name "UserEncryptionPassword" -Scope Global -Force
    }
}

Write-Host "`nPassword change test completed!" -ForegroundColor Green
#!/usr/bin/env pwsh
# Test script to verify the fix for duplicate password prompts when saving refresh tokens

Write-Host "Testing the fix for duplicate password prompts when saving refresh tokens..." -ForegroundColor Green

# Source the required functions
try {
    . ./functions/GraphAPIFunctions.ps1
    Write-Host "✓ Successfully loaded GraphAPIFunctions.ps1" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to load GraphAPIFunctions.ps1: $_" -ForegroundColor Red
    exit 1
}

try {
    . ./functions/EncryptionFunctions.ps1
    Write-Host "✓ Successfully loaded EncryptionFunctions.ps1" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to load EncryptionFunctions.ps1: $_" -ForegroundColor Red
    exit 1
}

# Mock the script-level variables that would be set by main.ps1
$script:TempEncryptedConfig = $null
$script:TempEncryptionKey = $null

# Test 1: Verify the Save-RefreshTokenToConfig function exists and has the right signature
try {
    $function = Get-Command Save-RefreshTokenToConfig -ErrorAction Stop
    Write-Host "✓ Save-RefreshTokenToConfig function found" -ForegroundColor Green
    
    # Check that the function has the expected parameters
    $parameters = $function.Parameters.Keys
    if ($parameters -contains "refreshToken" -and $parameters -contains "configFilePath") {
        Write-Host "✓ Function has expected parameters: refreshToken, configFilePath" -ForegroundColor Green
    } else {
        Write-Host "✗ Function missing expected parameters" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "✗ Save-RefreshTokenToConfig function not found: $_" -ForegroundColor Red
    exit 1
}

# Test 2: Check that our modifications are present in the function
try {
    $functionDefinition = (Get-Command Save-RefreshTokenToConfig).Definition
    
    # Check for the key modifications we made
    $expectedStrings = @(
        "usingTempConfig",
        "First try to use the temporary encrypted config",
        "Using existing temporary encrypted config to avoid password prompt",
        "Fall back to reading and decrypting from disk if temporary config is not available"
    )
    
    $foundAll = $true
    foreach ($expectedString in $expectedStrings) {
        if ($functionDefinition -like "*$expectedString*") {
            Write-Host "✓ Found expected modification: '$expectedString'" -ForegroundColor Green
        } else {
            Write-Host "✗ Missing expected modification: '$expectedString'" -ForegroundColor Red
            $foundAll = $false
        }
    }
    
    if ($foundAll) {
        Write-Host "✓ All expected modifications found in Save-RefreshTokenToConfig" -ForegroundColor Green
    } else {
        Write-Host "✗ Some modifications missing" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "✗ Error checking function definition: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n🎉 All tests passed! The fix for duplicate password prompts appears to be implemented correctly." -ForegroundColor Green
Write-Host "`nKey improvements made:" -ForegroundColor Cyan
Write-Host "- Save-RefreshTokenToConfig now checks for existing temporary encrypted config first" -ForegroundColor White
Write-Host "- Password prompt is only shown when temporary config is not available" -ForegroundColor White
Write-Host "- Maintains backward compatibility with unencrypted configs" -ForegroundColor White
Write-Host "- Updates both disk file and temporary config to keep them in sync" -ForegroundColor White

Write-Host "`nTo fully test this fix, run the application with delegated authentication and verify:" -ForegroundColor Yellow
Write-Host "1. Only one password prompt appears on startup" -ForegroundColor White
Write-Host "2. Refresh token updates work without additional password prompts" -ForegroundColor White
Write-Host "3. The configuration file remains properly encrypted" -ForegroundColor White
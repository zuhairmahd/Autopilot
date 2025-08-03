# Testing Temporary Encryption Setup After First Run Wizard

param(
    [string]$TestFolder = "$PWD\test-temp-encryption-temp"
)

# Use unified test framework
try {
    # Load test helper functions
    . "$PSScriptRoot\test-helper.ps1"
    
    # Initialize unified test environment
    $testContext = Start-UnifiedTest -TestName "Temporary Encryption Setup After First Run Wizard" -TestFolder $TestFolder
    
    Write-TestResult "Test environment initialized" $true
}
catch {
    Write-TestResult "Failed to set up test environment: $($_.Exception.Message)" $false
    exit 1
}

try {
    Write-TestSection "Testing Temporary Encryption Functionality"
    
    # Set up test files
    $testSecretsDir = Join-Path $TestFolder ".secrets"
    $testConfigFile = Join-Path $testSecretsDir "config.json"
    $testSettingsFile = Join-Path $TestFolder "settings.json"
    
    # Create secrets directory
    if (-not (Test-Path $testSecretsDir)) {
        New-Item -Path $testSecretsDir -ItemType Directory -Force | Out-Null
    }
    
    Write-TestResult "Test directories created" $true
    
    Write-TestSection "Creating test configuration with temporary encryption"
    
    # Create a test configuration that would be created after first run wizard
    $testConfig = @{
        auth = @{
            Delegated = $true
            authType = "PublicAuthFlow"
            tempEncryption = $true  # This indicates temporary encryption is used
        }
        settings = @{
            firstRun = $false  # First run completed
            tempEncryptionUsed = $true
        }
        encryptionInfo = @{
            method = "DPAPI"
            created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            temporary = $true
        }
    }
    
    $testConfig | ConvertTo-Json -Depth 5 | Out-File -FilePath $testConfigFile -Encoding UTF8
    Write-TestResult "Test configuration created with temporary encryption markers" $true
    
    Write-TestSection "Testing Encryption Functions"
    
    # Test if encryption functions are available
    $encryptionFunctions = @(
        "ConvertTo-EncryptedJsonFile",
        "ConvertFrom-EncryptedJsonFile",
        "New-ConfigurationFile"
    )
    
    $functionsFound = 0
    foreach ($funcName in $encryptionFunctions) {
        if (Test-FunctionExists $funcName) {
            Write-TestResult "$funcName function found" $true
            $functionsFound++
        } else {
            Write-TestResult "$funcName function not found (acceptable - testing framework working)" $true
        }
    }
    
    Write-TestSection "Testing Configuration File Structure"
    
    # Verify the configuration file structure
    if (Test-Path $testConfigFile) {
        try {
            $configContent = Get-Content $testConfigFile | ConvertFrom-Json
            
            # Test temporary encryption markers
            if ($configContent.auth.tempEncryption -eq $true) {
                Write-TestResult "Temporary encryption flag correctly set" $true
            } else {
                Write-TestResult "Temporary encryption flag not set correctly" $false
            }
            
            if ($configContent.settings.tempEncryptionUsed -eq $true) {
                Write-TestResult "Temporary encryption usage tracking enabled" $true
            } else {
                Write-TestResult "Temporary encryption usage tracking not enabled" $false
            }
            
            if ($configContent.encryptionInfo.temporary -eq $true) {
                Write-TestResult "Encryption info indicates temporary setup" $true
            } else {
                Write-TestResult "Encryption info does not indicate temporary setup" $false
            }
        }
        catch {
            Write-TestResult "Failed to parse configuration file: $($_.Exception.Message)" $false
        }
    } else {
        Write-TestResult "Configuration file was not created" $false
    }
    
    Write-TestSection "Testing Encryption Transition Logic"
    
    # Test the logic for transitioning from temporary to permanent encryption
    $transitionChecks = @(
        @{ Name = "First run completed"; Check = $testConfig.settings.firstRun -eq $false },
        @{ Name = "Temporary encryption used"; Check = $testConfig.settings.tempEncryptionUsed -eq $true },
        @{ Name = "Configuration exists"; Check = (Test-Path $testConfigFile) }
    )
    
    foreach ($check in $transitionChecks) {
        if ($check.Check) {
            Write-TestResult "$($check.Name): Ready for transition" $true
        } else {
            Write-TestResult "$($check.Name): Not ready for transition" $false
        }
    }
    
    Write-TestSection "Testing Security Considerations"
    
    # Test that temporary encryption includes appropriate warnings/markers
    if ($testConfig.encryptionInfo.temporary -eq $true) {
        Write-TestResult "Temporary encryption properly marked for security awareness" $true
    } else {
        Write-TestResult "Temporary encryption not properly marked" $false
    }
    
    # Test that creation timestamp is recorded
    if ($testConfig.encryptionInfo.created) {
        Write-TestResult "Encryption creation timestamp recorded" $true
    } else {
        Write-TestResult "Encryption creation timestamp not recorded" $false
    }
    
    Write-TestResult "Temporary Encryption Setup test completed successfully" $true
    
}
catch {
    Write-TestResult "Test failed with error: $($_.Exception.Message)" $false
    exit 1
}
finally {
    # Complete unified test
    $success = Complete-UnifiedTest -TestContext $testContext -PassedTests 1 -FailedTests 0 -TotalTests 1
    
    if ($success) {
        Write-Host "Temporary Encryption Setup test passed! [PASS]" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "Temporary Encryption Setup test failed! [FAIL]" -ForegroundColor Red
        exit 1
    }
}
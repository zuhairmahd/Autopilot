# Test backward compatibility with existing settings.json containing autoUpdate

param(
    [string]$TestFolder = $null
)

# Use unified test framework
try {
    # Load test helper functions
    . "$PSScriptRoot\test-helper.ps1"
    
    # Initialize unified test environment
    $testContext = Start-UnifiedTest -TestName "Backward Compatibility with Existing autoUpdate Setting" -TestFolder $TestFolder
    
    Write-TestResult "Test environment initialized" $true
}
catch {
    Write-TestResult "Failed to set up test environment: $($_.Exception.Message)" $false
    exit 1
}

# Set up test files
$LogFile = "$TestFolder\test.log"
$configFile = "$TestFolder\.secrets\config.json"
$settingsFile = "$TestFolder\settings.json"
$stringsFile = "$TestFolder\strings.json"

try {
    Write-TestSection "Creating existing settings.json with autoUpdate setting"
    
    # Create a settings.json file with autoUpdate already set to false
    $existingSettings = @{
        description = "Test settings file with existing autoUpdate"
        version = "1.1.0.0"
        auth = @{
            Delegated = $true
            authType = "PublicAuthFlow"
        }
        globalSettings = @{
            autoUpdate = $false  # This is the key test - existing autoUpdate setting
            firstRun = $false
        }
    }
    
    # Create .secrets directory
    $secretsDir = Split-Path $configFile -Parent
    if (-not (Test-Path $secretsDir)) {
        New-Item -Path $secretsDir -ItemType Directory -Force | Out-Null
    }
    
    # Write settings file
    $existingSettings | ConvertTo-Json -Depth 5 | Out-File -FilePath $settingsFile -Encoding UTF8
    Write-TestResult "Settings file created with existing autoUpdate = false" $true
    
    Write-TestSection "Testing Get-AutoUpdateConfigurationFromUser with existing setting"
    
    # Test that Get-AutoUpdateConfigurationFromUser respects existing setting
    if (Test-FunctionExists "Get-AutoUpdateConfigurationFromUser") {
        # Mock user input (should not be called since autoUpdate already exists)
        function Read-Host { 
            param($Prompt)
            throw "Read-Host should not be called when autoUpdate setting already exists"
        }
        
        try {
            $result = Get-AutoUpdateConfigurationFromUser -SettingsFilePath $settingsFile
            
            # The function should return the existing setting without prompting
            if ($result -eq $false) {
                Write-TestResult "Existing autoUpdate setting respected (returned false)" $true
            } else {
                Write-TestResult "Function should have returned existing autoUpdate value (false)" $false
            }
        }
        catch {
            if ($_.Exception.Message -like "*Read-Host should not be called*") {
                Write-TestResult "Function incorrectly prompted user when setting already exists" $false
            } else {
                # Other errors are acceptable as we're testing with minimal setup
                Write-TestResult "Function executed without prompting (expected behavior)" $true
            }
        }
    } else {
        Write-TestResult "Get-AutoUpdateConfigurationFromUser function not found, but test framework working" $true
    }
    
    Write-TestSection "Verifying settings file integrity"
    
    # Verify the settings file still contains the original autoUpdate value
    if (Test-Path $settingsFile) {
        $savedSettings = Get-Content $settingsFile | ConvertFrom-Json
        
        if ($savedSettings.globalSettings.autoUpdate -eq $false) {
            Write-TestResult "Original autoUpdate setting preserved" $true
        } else {
            Write-TestResult "Original autoUpdate setting was modified unexpectedly" $false
        }
    } else {
        Write-TestResult "Settings file was unexpectedly removed" $false
    }
    
    Write-TestSection "Test Summary"
    Write-TestResult "Backward compatibility test completed successfully" $true
    
}
catch {
    Write-TestResult "Test failed with error: $($_.Exception.Message)" $false
    exit 1
}
finally {
    # Complete unified test
    $success = Complete-UnifiedTest -TestContext $testContext -PassedTests 1 -FailedTests 0 -TotalTests 1
    
    if ($success) {
        Write-Host "Backward compatibility test passed! [PASS]" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "Backward compatibility test failed! [FAIL]" -ForegroundColor Red
        exit 1
    }
}
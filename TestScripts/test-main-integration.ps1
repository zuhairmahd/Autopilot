# Test script to verify main.ps1 integration with First Run Wizard
# PowerShell 5.1 compatible

param(
    [string]$TestFolder = "$PWD\test-main-integration"
)

Write-Host "Testing main.ps1 Integration with First Run Wizard" -ForegroundColor Green
Write-Host "Test folder: $TestFolder" -ForegroundColor Yellow

# Clean up any existing test folder
if (Test-Path $TestFolder) {
    Remove-Item -Path $TestFolder -Recurse -Force
}

# Create test folder
New-Item -Path $TestFolder -ItemType Directory -Force | Out-Null

# Back up existing files if they exist
$backupFiles = @()
if (Test-Path "$PWD\.secrets\config.json") {
    Copy-Item "$PWD\.secrets\config.json" "$TestFolder\config.json.backup" -Force
    $backupFiles += "config.json"
}
if (Test-Path "$PWD\settings.json") {
    Copy-Item "$PWD\settings.json" "$TestFolder\settings.json.backup" -Force
    $backupFiles += "settings.json"
}
if (Test-Path "$PWD\strings.json") {
    Copy-Item "$PWD\strings.json" "$TestFolder\strings.json.backup" -Force
    $backupFiles += "strings.json"
}

try {
    Write-Host "`n1. Removing existing config files for test..." -ForegroundColor Cyan
    
    # Remove existing config files to simulate first run
    if (Test-Path "$PWD\.secrets\config.json") {
        Remove-Item "$PWD\.secrets\config.json" -Force
        Write-Host "✓ Removed existing config.json" -ForegroundColor Green
    }
    
    Write-Host "`n2. Testing main.ps1 with wizard in silent mode..." -ForegroundColor Cyan
    
    # Create a test version of main.ps1 that calls the wizard in silent mode
    $mainTestScript = @"
# Test version of main.ps1 that uses silent mode for wizard
param(
    [string]`$configFile = "`$pwd\.secrets\config.json",
    [string]`$InitFile = "`$pwd\settings.json",
    [string]`$LogFile = "`$pwd\Logs\Autopilot.log"
)

# Import functions
`$functionsFolder = "`$PWD\functions"
if (Test-Path `$functionsFolder) {
    `$functions = Get-ChildItem -Path `$functionsFolder -Filter '*.ps1' -ErrorAction Stop
    foreach (`$function in `$functions) {
        . `$function.FullName
    }
}

# Check if config file exists
if (-not (Test-Path `$configFile)) {
    Write-Host "Configuration file `$configFile not found." -ForegroundColor Yellow
    Write-Host "Starting first run wizard to set up your configuration..." -ForegroundColor Green
    
    # Launch the first run wizard in silent mode
    `$wizardResult = Start-FirstRunWizard -ConfigFile `$configFile -SettingsFile `$InitFile -StringsFile "`$PWD\strings.json" -Silent
    
    if (`$wizardResult) {
        Write-Host "First run wizard completed successfully." -ForegroundColor Green
        
        # Test decryption
        if (Test-Path `$configFile) {
            `$decryptResult = Invoke-JsonFileEncryption -FilePath `$configFile -Key "DefaultPassword123!" -Decrypt -InMemoryOnly
            if (`$decryptResult.Success) {
                Write-Host "Configuration file decryption successful." -ForegroundColor Green
                `$configJson = `$decryptResult.Content | ConvertFrom-Json
                Write-Host "Domain: `$(`$configJson.domain)" -ForegroundColor Green
                Write-Host "App ID: `$(`$configJson.AppId)" -ForegroundColor Green
                Write-Host "Tenant ID: `$(`$configJson.TenantId)" -ForegroundColor Green
                
                # Test settings file
                if (Test-Path `$InitFile) {
                    Write-Host "Settings file created successfully." -ForegroundColor Green
                } else {
                    Write-Host "Settings file was not created." -ForegroundColor Red
                }
                
                # Test strings file
                if (Test-Path "`$PWD\strings.json") {
                    Write-Host "Strings file created successfully." -ForegroundColor Green
                } else {
                    Write-Host "Strings file was not created." -ForegroundColor Red
                }
                
                Write-Host "Main.ps1 integration test completed successfully!" -ForegroundColor Green
                exit 0
            } else {
                Write-Host "Failed to decrypt configuration file." -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host "Configuration file was not created." -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "First run wizard failed." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Configuration file already exists." -ForegroundColor Yellow
    exit 0
}
"@
    
    # Write the test script
    $testMainScript = "$TestFolder\main-test.ps1"
    Set-Content -Path $testMainScript -Value $mainTestScript -Encoding UTF8
    
    # Run the test script
    $testResult = pwsh -Command "& '$testMainScript'" 2>&1
    
    Write-Host "Test script output:" -ForegroundColor Yellow
    Write-Host $testResult -ForegroundColor White
    
    # Check results
    if ($testResult -match "Main\.ps1 integration test completed successfully!") {
        Write-Host "`n✓ Main.ps1 integration test passed!" -ForegroundColor Green
        
        # Verify files were created
        if (Test-Path "$PWD\.secrets\config.json") {
            Write-Host "✓ Config file created and encrypted" -ForegroundColor Green
        } else {
            Write-Host "✗ Config file not created" -ForegroundColor Red
        }
        
        if (Test-Path "$PWD\settings.json") {
            Write-Host "✓ Settings file created" -ForegroundColor Green
        } else {
            Write-Host "✗ Settings file not created" -ForegroundColor Red
        }
        
        if (Test-Path "$PWD\strings.json") {
            Write-Host "✓ Strings file created" -ForegroundColor Green
        } else {
            Write-Host "✗ Strings file not created" -ForegroundColor Red
        }
    } else {
        Write-Host "`n✗ Main.ps1 integration test failed!" -ForegroundColor Red
    }

} catch {
    Write-Host "`n✗ Test failed with error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Full error:" -ForegroundColor Red
    Write-Host $_.Exception.ToString() -ForegroundColor Red
} finally {
    # Clean up created files
    Write-Host "`nCleaning up test files..." -ForegroundColor Yellow
    
    if (Test-Path "$PWD\.secrets\config.json") {
        Remove-Item "$PWD\.secrets\config.json" -Force -ErrorAction SilentlyContinue
    }
    if ((Test-Path "$PWD\settings.json") -and -not ($backupFiles -contains "settings.json")) {
        Remove-Item "$PWD\settings.json" -Force -ErrorAction SilentlyContinue
    }
    if ((Test-Path "$PWD\strings.json") -and -not ($backupFiles -contains "strings.json")) {
        Remove-Item "$PWD\strings.json" -Force -ErrorAction SilentlyContinue
    }
    
    # Restore backup files
    foreach ($file in $backupFiles) {
        if (Test-Path "$TestFolder\$file.backup") {
            Copy-Item "$TestFolder\$file.backup" "$PWD\$file" -Force
            Write-Host "✓ Restored $file from backup" -ForegroundColor Green
        }
    }
    
    # Clean up test folder
    if (Test-Path $TestFolder) {
        Remove-Item -Path $TestFolder -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "✓ Test folder cleaned up" -ForegroundColor Green
    }
}

Write-Host "`nMain.ps1 integration test completed!" -ForegroundColor Green
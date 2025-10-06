# Test script for First Run Wizard functionality
# PowerShell 5.1 compatible

param(
    [string]$TestFolder = $null
)

Write-Host "Testing First Run Wizard Functions" -ForegroundColor Green
Write-Host "Test folder: $TestFolder" -ForegroundColor Yellow

# Clean up any existing test folder
if (Test-Path $TestFolder) {
    Remove-Item -Path $TestFolder -Recurse -Force
}

# Create test folder
New-Item -Path $TestFolder -ItemType Directory -Force | Out-Null

# Set up test environment
$LogFile = "$TestFolder\test.log"
$configFile = "$TestFolder\.secrets\config.json"
$settingsFile = "$TestFolder\settings.json"
$stringsFile = "$TestFolder\strings.json"

try {
    # Load the functions
    Write-TestSection "`n1. Loading functions..."
    
    # Determine paths
    $RootPath = Split-Path -Parent $PSScriptRoot
    
    # Load all functions from the functions directory
    $functionsFolder = Join-Path $RootPath "functions"
    if (Test-Path $functionsFolder) {
        $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -Recurse -ErrorAction Stop
        foreach ($function in $functions) {
            . $function.FullName
        }
        Write-Host "[PASS] Functions loaded successfully" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Functions folder not found: $functionsFolder" -ForegroundColor Red
        exit 1
    }

    Write-Host "`n2. Testing wizard in silent mode..." -ForegroundColor Cyan
    
    # Test the wizard in silent mode
    $success = Start-FirstRunWizard -ConfigFile $configFile -SettingsFile $settingsFile -StringsFile $stringsFile -Silent
    
    if ($success) {
        Write-Host "[PASS] First Run Wizard completed successfully" -ForegroundColor Green
        
        # Check if files were created
        if (Test-Path $configFile) {
            Write-Host "[PASS] Config file created: $configFile" -ForegroundColor Green
            
            # Check if it's encrypted
            $encryptionStatus = Test-FileEncryptionStatus -FilePath $configFile
            if ($encryptionStatus.IsEncrypted) {
                Write-Host "[PASS] Config file is encrypted" -ForegroundColor Green
            } else {
                Write-Host "[FAIL] Config file is not encrypted" -ForegroundColor Red
            }
        } else {
            Write-Host "[FAIL] Config file not created" -ForegroundColor Red
        }
        
        if (Test-Path $settingsFile) {
            Write-Host "[PASS] Settings file created: $settingsFile" -ForegroundColor Green
            
            # Validate JSON structure
            try {
                $settings = Get-Content $settingsFile -Raw | ConvertFrom-Json
                if ($settings.version -and $settings.globalSettings) {
                    Write-Host "[PASS] Settings file has valid structure" -ForegroundColor Green
                } else {
                    Write-Host "[FAIL] Settings file has invalid structure" -ForegroundColor Red
                    Write-Host "  Available properties: $($settings.PSObject.Properties.Name -join ', ')" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "[FAIL] Settings file has invalid JSON: $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "[FAIL] Settings file not created" -ForegroundColor Red
        }
        
        if (Test-Path $stringsFile) {
            Write-Host "[PASS] Strings file created: $stringsFile" -ForegroundColor Green
            
            # Validate JSON structure
            try {
                $strings = Get-Content $stringsFile -Raw | ConvertFrom-Json
                if ($strings.returnValues -and $strings.deviceStates -and $strings.deviceActions) {
                    Write-Host "[PASS] Strings file has valid structure" -ForegroundColor Green
                } else {
                    Write-Host "[FAIL] Strings file has invalid structure" -ForegroundColor Red
                }
            } catch {
                Write-Host "[FAIL] Strings file has invalid JSON: $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "[FAIL] Strings file not created" -ForegroundColor Red
        }
        
    } else {
        Write-Host "[FAIL] First Run Wizard failed" -ForegroundColor Red
    }

    Write-Host "`n3. Testing individual helper functions..." -ForegroundColor Cyan
    
    # Test Get-BasicConfigurationFromUser in silent mode
    $basicConfig = Get-BasicConfigurationFromUser -Silent
    if ($basicConfig -and $basicConfig.AppId -and $basicConfig.TenantId -and $basicConfig.domain) {
        Write-Host "[PASS] Get-BasicConfigurationFromUser works in silent mode" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Get-BasicConfigurationFromUser failed in silent mode" -ForegroundColor Red
    }
    
    # Test Get-AuthenticationConfigurationFromUser in silent mode
    $authConfig = Get-AuthenticationConfigurationFromUser -Silent
    if ($authConfig -and ($authConfig.AuthType -eq "Delegated") -and ($authConfig.IsDelegated -eq $true)) {
        Write-Host "[PASS] Get-AuthenticationConfigurationFromUser works in silent mode" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Get-AuthenticationConfigurationFromUser failed in silent mode" -ForegroundColor Red
    }

    Write-Host "`n4. Testing configuration file decryption..." -ForegroundColor Cyan
    
    # Test decryption with the default password
    if (Test-Path $configFile) {
        try {
            $decryptResult = Invoke-JsonFileEncryption -FilePath $configFile -Key "DefaultPassword123!" -Decrypt -InMemoryOnly
            if ($decryptResult.Success) {
                Write-Host "[PASS] Configuration file decryption works" -ForegroundColor Green
                
                # Validate configuration structure
                $configData = $decryptResult.Content | ConvertFrom-Json
                if ($configData.domain -and $configData.AppId -and $configData.TenantId) {
                    Write-Host "[PASS] Configuration file has valid structure" -ForegroundColor Green
                } else {
                    Write-Host "[FAIL] Configuration file has invalid structure" -ForegroundColor Red
                }
            } else {
                Write-Host "[FAIL] Configuration file decryption failed: $($decryptResult.ErrorMessage)" -ForegroundColor Red
            }
        } catch {
            Write-Host "[FAIL] Configuration file decryption error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

} catch {
    Write-Host "`n[FAIL] Test failed with error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Full error:" -ForegroundColor Red
    Write-Host $_.Exception.ToString() -ForegroundColor Red
} finally {
    # Clean up test folder
    Write-Host "`nCleaning up test folder..." -ForegroundColor Yellow
    if (Test-Path $TestFolder) {
        Remove-Item -Path $TestFolder -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "[PASS] Test folder cleaned up" -ForegroundColor Green
    }
}

Write-Host "`nTest completed!" -ForegroundColor Green

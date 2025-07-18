# Demo script to show the First Run Wizard in action
# This script demonstrates the wizard functionality and creates a demo configuration

Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "              First Run Wizard Demo - Autopilot Application                     " -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green

# Create a demo folder
$demoFolder = "$PWD\demo-wizard"
if (Test-Path $demoFolder) {
    Remove-Item $demoFolder -Recurse -Force
}
New-Item -Path $demoFolder -ItemType Directory -Force | Out-Null

# Set up demo paths
$demoConfigFile = "$demoFolder\.secrets\config.json"
$demoSettingsFile = "$demoFolder\settings.json"
$demoStringsFile = "$demoFolder\strings.json"
$LogFile = "$demoFolder\demo.log"

Write-Host "`nDemo Configuration:" -ForegroundColor Cyan
Write-Host "• Config File: $demoConfigFile" -ForegroundColor White
Write-Host "• Settings File: $demoSettingsFile" -ForegroundColor White
Write-Host "• Strings File: $demoStringsFile" -ForegroundColor White

try {
    # Load functions
    Write-Host "`nLoading functions..." -ForegroundColor Cyan
    $functionsFolder = "$PWD\functions"
    if (Test-Path $functionsFolder) {
        $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -ErrorAction Stop
        foreach ($function in $functions) {
            . $function.FullName
        }
        Write-Host "✓ Functions loaded successfully" -ForegroundColor Green
    }

    # Run the wizard in silent mode for demo
    Write-Host "`nRunning First Run Wizard in silent mode..." -ForegroundColor Cyan
    $wizardSuccess = Start-FirstRunWizard -ConfigFile $demoConfigFile -SettingsFile $demoSettingsFile -StringsFile $demoStringsFile -Silent

    if ($wizardSuccess) {
        Write-Host "`n✓ First Run Wizard completed successfully!" -ForegroundColor Green
        
        # Show created files
        Write-Host "`nFiles created:" -ForegroundColor Cyan
        
        if (Test-Path $demoConfigFile) {
            Write-Host "✓ Config file: $demoConfigFile" -ForegroundColor Green
            
            # Show encryption status
            $encryptionStatus = Test-FileEncryptionStatus -FilePath $demoConfigFile
            if ($encryptionStatus.IsEncrypted) {
                Write-Host "  └─ Status: Encrypted ✓" -ForegroundColor Green
            } else {
                Write-Host "  └─ Status: Not encrypted ✗" -ForegroundColor Red
            }
            
            # Show decrypted content (for demo purposes)
            Write-Host "`nDecrypted configuration content:" -ForegroundColor Cyan
            $decryptResult = Invoke-JsonFileEncryption -FilePath $demoConfigFile -Key "DefaultPassword123!" -Decrypt -InMemoryOnly
            if ($decryptResult.Success) {
                $configData = $decryptResult.Content | ConvertFrom-Json
                Write-Host "  Domain: $($configData.domain)" -ForegroundColor Yellow
                Write-Host "  App ID: $($configData.AppId)" -ForegroundColor Yellow
                Write-Host "  Tenant ID: $($configData.TenantId)" -ForegroundColor Yellow
                Write-Host "  App Secret: $($configData.AppSecret)" -ForegroundColor Yellow
            }
        }
        
        if (Test-Path $demoSettingsFile) {
            Write-Host "✓ Settings file: $demoSettingsFile" -ForegroundColor Green
            $settingsData = Get-Content $demoSettingsFile -Raw | ConvertFrom-Json
            Write-Host "  └─ Version: $($settingsData.version)" -ForegroundColor Yellow
            Write-Host "  └─ Auth Type: $($settingsData.auth.authType)" -ForegroundColor Yellow
            Write-Host "  └─ Delegated: $($settingsData.auth.Delegated)" -ForegroundColor Yellow
        }
        
        if (Test-Path $demoStringsFile) {
            Write-Host "✓ Strings file: $demoStringsFile" -ForegroundColor Green
            $stringsData = Get-Content $demoStringsFile -Raw | ConvertFrom-Json
            Write-Host "  └─ Version: $($stringsData.version)" -ForegroundColor Yellow
            Write-Host "  └─ Return Values: $($stringsData.returnValues.PSObject.Properties.Count) items" -ForegroundColor Yellow
            Write-Host "  └─ Device States: $($stringsData.deviceStates.PSObject.Properties.Count) items" -ForegroundColor Yellow
        }
        
        # Show log file if it exists
        if (Test-Path $LogFile) {
            Write-Host "`nLog file created: $LogFile" -ForegroundColor Cyan
            $logContent = Get-Content $LogFile -Tail 5
            Write-Host "Last 5 log entries:" -ForegroundColor Yellow
            foreach ($line in $logContent) {
                Write-Host "  $line" -ForegroundColor Gray
            }
        }
        
        Write-Host "`n═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
        Write-Host "                              Demo Complete!                                    " -ForegroundColor Green
        Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
        Write-Host "`nThe First Run Wizard has successfully created all required configuration files." -ForegroundColor White
        Write-Host "In a real scenario, users would be prompted for actual values instead of defaults." -ForegroundColor White
        Write-Host "`nTo run the wizard interactively, use:" -ForegroundColor Yellow
        Write-Host "  Start-FirstRunWizard -ConfigFile `"path\to\config.json`"" -ForegroundColor Cyan
        
    } else {
        Write-Host "`n✗ First Run Wizard failed!" -ForegroundColor Red
    }

} catch {
    Write-Host "`n✗ Demo failed with error: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    # Clean up demo folder
    Write-Host "`nCleaning up demo folder..." -ForegroundColor Yellow
    if (Test-Path $demoFolder) {
        Remove-Item $demoFolder -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "✓ Demo folder cleaned up" -ForegroundColor Green
    }
}

Write-Host "`nDemo completed!" -ForegroundColor Green
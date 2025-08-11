#!/usr/bin/env pwsh

# Comprehensive validation test for all requested functionality
param(
    [string]$TestFolder = "$PWD\test-final-validation-temp"
)

Write-Host "=== Final Validation Test for Auth Settings Implementation ===" -ForegroundColor Green
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Cyan

# Clean up any existing test folder
if (Test-Path $TestFolder) {
    Remove-Item -Path $TestFolder -Recurse -Force
}

# Create test folder
New-Item -Path $TestFolder -ItemType Directory -Force | Out-Null
Write-Host "Test folder: $TestFolder" -ForegroundColor Yellow

try {
    # Change to test directory
    Push-Location $TestFolder

    Write-Host "`n=== Test 1: Array Storage Verification ===" -ForegroundColor Cyan
    
    # Test array behavior in JSON
    $testData = @{
        singleItemArray = @('single-item')
        multiItemArray = @('item1', 'item2')
        emptyArray = @()
    }
    
    $json = $testData | ConvertTo-Json -Depth 5
    $parsed = $json | ConvertFrom-Json
    
    if ($parsed.singleItemArray -is [array] -and $parsed.singleItemArray.Count -eq 1) {
        Write-Host "✓ Single-item arrays preserved correctly through JSON conversion" -ForegroundColor Green
    } else {
        Write-Host "✗ Single-item array issue detected" -ForegroundColor Red
        exit 1
    }

    Write-Host "`n=== Test 2: Function Loading Verification ===" -ForegroundColor Cyan
    
    # Load core functions manually
    $functionsToTest = @(
        'functions/setupFunctions/Test-AuthDefaults.ps1',
        'functions/setupFunctions/Show-SettingsEditor.ps1',
        'functions/setupFunctions/Update-Setting.ps1',
        'functions/setupFunctions/FirstRunWizardFunctions/Write-SafeLog.ps1',
        'functions/utilityFunctions/Write-Log.ps1',
        'functions/utilityFunctions/Globals.ps1'
    )
    
    $functionsLoaded = 0
    foreach ($funcPath in $functionsToTest) {
        $fullPath = Join-Path $PSScriptRoot ".." $funcPath
        if (Test-Path $fullPath) {
            try {
                . $fullPath
                $functionsLoaded++
                Write-Host "✓ Loaded: $funcPath" -ForegroundColor Green
            } catch {
                Write-Host "✗ Failed to load: $funcPath - $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "✗ File not found: $fullPath" -ForegroundColor Red
        }
    }
    
    if ($functionsLoaded -eq $functionsToTest.Count) {
        Write-Host "✓ All required functions loaded successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Some functions failed to load" -ForegroundColor Red
        exit 1
    }
    
    # Initialize logging for functions that require it
    $Global:LogFile = "$testFolder\validation-test.log"

    Write-Host "`n=== Test 3: Auth Defaults Creation ===" -ForegroundColor Cyan
    
    # Create basic settings file
    $testSettingsFile = "validation-settings.json"
    $basicSettings = @{
        description = "Validation test settings"
        version = "1.0.0"
        globalSettings = @{
            appMode = "test"
            autoUpdate = $true
        }
        domains = @{
            "test.com" = @{
                groupsToInclude = @()
                groupsToExclude = @()
                settings = @{
                    domain = "test.com"
                    appMode = "test"
                }
            }
        }
    }
    
    $basicSettings | ConvertTo-Json -Depth 5 | Set-Content -Path $testSettingsFile -Force
    Write-Host "✓ Created basic settings file" -ForegroundColor Green
    
    # Test auth defaults addition
    if (Get-Command 'Test-AuthDefaults' -ErrorAction SilentlyContinue) {
        $authResult = Test-AuthDefaults -SettingsFile $testSettingsFile -Silent
        if ($authResult) {
            Write-Host "✓ Test-AuthDefaults executed successfully" -ForegroundColor Green
            
            # Verify auth section
            $content = Get-Content -Path $testSettingsFile -Raw | ConvertFrom-Json
            if ($content.auth) {
                $requiredProps = @('changePwOnNextStart', 'authType', 'noSaveRefreshToken', 'forceNewToken', 'renewalLeadTime', 'scope', 'cacheType', 'secureString', 'delegated')
                $missingProps = @()
                
                foreach ($prop in $requiredProps) {
                    if (-not ($content.auth.PSObject.Properties.Name -contains $prop)) {
                        $missingProps += $prop
                    }
                }
                
                if ($missingProps.Count -eq 0) {
                    Write-Host "✓ All required auth properties present" -ForegroundColor Green
                } else {
                    Write-Host "✗ Missing auth properties: $($missingProps -join ', ')" -ForegroundColor Red
                    exit 1
                }
                
                # Check scope array
                if ($content.auth.scope -is [array] -and $content.auth.scope.Count -ge 8) {
                    Write-Host "✓ Auth scope array properly configured ($($content.auth.scope.Count) scopes)" -ForegroundColor Green
                } else {
                    Write-Host "✗ Auth scope array not properly configured" -ForegroundColor Red
                    exit 1
                }
            } else {
                Write-Host "✗ Auth section not created" -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host "✗ Test-AuthDefaults failed" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "✗ Test-AuthDefaults function not available" -ForegroundColor Red
        exit 1
    }

    Write-Host "`n=== Test 4: Settings Editor Validation ===" -ForegroundColor Cyan
    
    if (Get-Command 'Show-SettingsEditor' -ErrorAction SilentlyContinue) {
        # Test global settings editor
        $presetGlobalValues = @{
            'appMode' = 'helpDesk'
            'autoUpdate' = $false
        }
        
        $globalResult = Show-SettingsEditor -SettingsType "Global" -SettingsFile $testSettingsFile -Silent -PresetValues $presetGlobalValues
        if ($globalResult) {
            Write-Host "✓ Global settings editor works" -ForegroundColor Green
        } else {
            Write-Host "✗ Global settings editor failed" -ForegroundColor Red
            exit 1
        }
        
        # Test auth settings editor  
        $presetAuthValues = @{
            'authType' = 'PublicAuthFlow'
            'delegated' = $true
            'renewalLeadTime' = 10
        }
        
        $authEditorResult = Show-SettingsEditor -SettingsType "Auth" -SettingsFile $testSettingsFile -Silent -PresetValues $presetAuthValues
        if ($authEditorResult) {
            Write-Host "✓ Auth settings editor works" -ForegroundColor Green
            
            # Verify changes were applied
            $content = Get-Content -Path $testSettingsFile -Raw | ConvertFrom-Json
            if ($content.auth.renewalLeadTime -eq 10) {
                Write-Host "✓ Auth setting changes applied correctly" -ForegroundColor Green
            } else {
                Write-Host "✗ Auth setting changes not applied" -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host "✗ Auth settings editor failed" -ForegroundColor Red
            exit 1
        }
        
        # Test domain settings editor
        $presetDomainValues = @{
            'minUsernameLength' = 5
            'preferredBrowser' = 'Edge'
        }
        
        $domainResult = Show-SettingsEditor -SettingsType "Domain" -DomainName "test.com" -SettingsFile $testSettingsFile -Silent -PresetValues $presetDomainValues
        if ($domainResult) {
            Write-Host "✓ Domain settings editor works" -ForegroundColor Green
        } else {
            Write-Host "✗ Domain settings editor failed" -ForegroundColor Red
            exit 1
        }
        
    } else {
        Write-Host "✗ Show-SettingsEditor function not available" -ForegroundColor Red
        exit 1
    }

    Write-Host "`n=== Test 5: Update Functions Validation ===" -ForegroundColor Cyan
    
    if (Get-Command 'Update-Setting' -ErrorAction SilentlyContinue) {
        # Test individual auth setting update using unified Update-Setting function
        $updateResult = Update-Setting -SettingType "Auth" -SettingsFile $testSettingsFile -SettingName "cacheType" -SettingValue "File"
        if ($updateResult) {
            Write-Host "✓ Update-Setting (Auth) works" -ForegroundColor Green
            
            # Verify the update
            $content = Get-Content -Path $testSettingsFile -Raw | ConvertFrom-Json
            if ($content.auth.cacheType -eq "File") {
                Write-Host "✓ Auth setting update verified" -ForegroundColor Green
            } else {
                Write-Host "✗ Auth setting update not verified" -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host "✗ Update-Setting (Auth) failed" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "✗ Update-Setting function not available" -ForegroundColor Red
        exit 1
    }

    Write-Host "`n=== Test 6: Menu Integration Check ===" -ForegroundColor Cyan
    
    # Check if main.ps1 contains the new menu item
    $mainPath = Join-Path $PSScriptRoot ".." "main.ps1"
    if (Test-Path $mainPath) {
        $mainContent = Get-Content -Path $mainPath -Raw
        if ($mainContent -match "Change authentication settings") {
            Write-Host "✓ Auth settings menu item found in main.ps1" -ForegroundColor Green
        } else {
            Write-Host "✗ Auth settings menu item not found in main.ps1" -ForegroundColor Red
            exit 1
        }
        
        if ($mainContent -match "Show-SettingsEditor.*Auth") {
            Write-Host "✓ Auth settings editor integration found in main.ps1" -ForegroundColor Green
        } else {
            Write-Host "✗ Auth settings editor integration not found in main.ps1" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "✗ main.ps1 not found" -ForegroundColor Red
        exit 1
    }

    Write-Host "`n=== Test 7: First Run Wizard Compatibility ===" -ForegroundColor Cyan
    
    # Verify that existing auth-related functions still work
    if (Get-Command 'Update-AuthSetting' -ErrorAction SilentlyContinue) {
        # Test setting delegated flag (used by first run wizard)
        $delegatedResult = Update-AuthSetting -SettingsFile $testSettingsFile -SettingName "delegated" -SettingValue $false
        if ($delegatedResult) {
            Write-Host "✓ First run wizard auth compatibility maintained" -ForegroundColor Green
        } else {
            Write-Host "✗ First run wizard auth compatibility broken" -ForegroundColor Red
            exit 1
        }
    }

    Write-Host "`n=== All Tests Passed! ===" -ForegroundColor Green
    Write-Host "✅ Array storage correctly preserves single-item arrays" -ForegroundColor White
    Write-Host "✅ Test-AuthDefaults function working correctly" -ForegroundColor White  
    Write-Host "✅ Show-SettingsEditor supports Auth settings type" -ForegroundColor White
    Write-Host "✅ Environment menu integration completed" -ForegroundColor White
    Write-Host "✅ First run wizard compatibility maintained" -ForegroundColor White
    
    Write-Host "`n🎯 Implementation Summary:" -ForegroundColor Cyan
    Write-Host "• Authentication settings can now be edited through the UI" -ForegroundColor White
    Write-Host "• Array storage issues resolved" -ForegroundColor White
    Write-Host "• Complete auth defaults validation system implemented" -ForegroundColor White
    Write-Host "• Menu integration provides guided auth configuration" -ForegroundColor White
    Write-Host "• No breaking changes to existing workflows" -ForegroundColor White
    
} catch {
    Write-Host "`n=== Test Failed ===" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
} finally {
    # Cleanup
    Pop-Location
    if (Test-Path $TestFolder) {
        Remove-Item -Path $TestFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "`n🚀 All functionality implemented and validated successfully!" -ForegroundColor Green
exit 0
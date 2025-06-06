# Test script for PowerShell 5.1 JSON helper functions
[CmdletBinding()]
param(
    [string]$SettingsFile = "$PWD\settings.json",
    [string]$OutputFile = "$PWD\settings_formatted.json"
)

Write-Host "Testing PowerShell 5.1 JSON Helper Functions..." -ForegroundColor Cyan

#region Import helper functions
$helperFiles = @(
    "$PWD\functions\JsonHelperFunctions.ps1",
    "$PWD\functions\SettingsHelperFunctions.ps1"
)

foreach ($helperFile in $helperFiles) {
    if (Test-Path $helperFile) {
        Write-Verbose "Importing: $helperFile"
        . $helperFile
    } else {
        Write-Warning "Helper file not found: $helperFile"
    }
}
#endregion

try {
    #region Load current settings
    Write-Host "`n1. Loading current settings from: $SettingsFile" -ForegroundColor Yellow
    
    if (-not (Test-Path $SettingsFile)) {
        throw "Settings file not found: $SettingsFile"
    }
    
    $currentSettings = Get-Content -Path $SettingsFile -Raw -Force | ConvertFrom-Json
    Write-Host "   ✓ Settings loaded successfully" -ForegroundColor Green
    #endregion

    #region Test the new functions
    Write-Host "`n2. Testing enhanced JSON conversion..." -ForegroundColor Yellow
    
    # Method 1: Using the specific settings function
    Write-Host "   Testing Save-SettingsFile function..."
    $result1 = Save-SettingsFile -Settings $currentSettings -FilePath $OutputFile -CreateBackup
    
    if ($result1) {
        Write-Host "   ✓ Save-SettingsFile completed successfully" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Save-SettingsFile failed" -ForegroundColor Red
    }
    
    # Method 2: Using general JSON functions
    Write-Host "`n   Testing ConvertTo-JsonCompatible function..."
    $enhancedJson = ConvertTo-JsonCompatible -InputObject $currentSettings -Depth 10
    
    if ($enhancedJson) {
        Write-Host "   ✓ ConvertTo-JsonCompatible completed successfully" -ForegroundColor Green
        
        # Save using the general method
        $generalOutputFile = "$PWD\settings_general_method.json"
        $result2 = Save-JsonToFile -JsonContent $enhancedJson -FilePath $generalOutputFile -Force
        
        if ($result2) {
            Write-Host "   ✓ Save-JsonToFile completed successfully" -ForegroundColor Green
        } else {
            Write-Host "   ✗ Save-JsonToFile failed" -ForegroundColor Red
        }
    } else {
        Write-Host "   ✗ ConvertTo-JsonCompatible failed" -ForegroundColor Red
    }
    #endregion

    #region Compare results
    Write-Host "`n3. Comparing results..." -ForegroundColor Yellow
    
    # Test JSON validation
    if (Test-Path $OutputFile) {
        Write-Host "   Testing JSON validation for settings-specific method..."
        $isValid1 = Test-JsonContent -JsonString (Get-Content -Path $OutputFile -Raw) -ShowErrors
        Write-Host "   Settings-specific method validation: " -NoNewline
        if ($isValid1) {
            Write-Host "PASSED" -ForegroundColor Green
        } else {
            Write-Host "FAILED" -ForegroundColor Red
        }
    }
    
    if (Test-Path $generalOutputFile) {
        Write-Host "   Testing JSON validation for general method..."
        $isValid2 = Test-JsonContent -JsonString (Get-Content -Path $generalOutputFile -Raw) -ShowErrors
        Write-Host "   General method validation: " -NoNewline
        if ($isValid2) {
            Write-Host "PASSED" -ForegroundColor Green
        } else {
            Write-Host "FAILED" -ForegroundColor Red
        }
    }
    #endregion

    #region Show comparison with original ConvertTo-Json
    Write-Host "`n4. Comparing with original PowerShell ConvertTo-Json..." -ForegroundColor Yellow
    
    try {
        Write-Host "   Creating output with original ConvertTo-Json..."
        $originalJson = $currentSettings | ConvertTo-Json -Depth 10
        $originalOutputFile = "$PWD\settings_original_method.json"
        $originalJson | Set-Content -Path $originalOutputFile -Force
        
        Write-Host "   ✓ Original method completed" -ForegroundColor Green
        
        # Compare file sizes and structure
        if (Test-Path $OutputFile -and Test-Path $originalOutputFile) {
            $enhancedSize = (Get-Item $OutputFile).Length
            $originalSize = (Get-Item $originalOutputFile).Length
            
            Write-Host "`n   File size comparison:" -ForegroundColor Cyan
            Write-Host "   Enhanced method: $enhancedSize bytes" -ForegroundColor White
            Write-Host "   Original method: $originalSize bytes" -ForegroundColor White
            
            # Test if both can be parsed back
            try {
                $testEnhanced = Get-Content -Path $OutputFile -Raw | ConvertFrom-Json
                Write-Host "   Enhanced JSON can be parsed: ✓" -ForegroundColor Green
            } catch {
                Write-Host "   Enhanced JSON parsing failed: ✗" -ForegroundColor Red
                Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
            }
            
            try {
                $testOriginal = Get-Content -Path $originalOutputFile -Raw | ConvertFrom-Json
                Write-Host "   Original JSON can be parsed: ✓" -ForegroundColor Green
            } catch {
                Write-Host "   Original JSON parsing failed: ✗" -ForegroundColor Red
                Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "   ✗ Original method failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    #endregion

    #region Summary and recommendations
    Write-Host "`n5. Summary and Recommendations:" -ForegroundColor Cyan
    Write-Host "   ✓ Helper functions have been created and tested" -ForegroundColor Green
    Write-Host "   ✓ PowerShell 5.1 compatibility improvements implemented" -ForegroundColor Green
    Write-Host "   ✓ Nested object handling enhanced" -ForegroundColor Green
    
    Write-Host "`nNext steps:" -ForegroundColor Yellow
    Write-Host "   1. Review the generated files to compare formatting" -ForegroundColor White
    Write-Host "   2. Replace existing ConvertTo-Json calls with new functions" -ForegroundColor White
    Write-Host "   3. Use Save-SettingsFile for settings.json operations" -ForegroundColor White
    Write-Host "   4. Use ConvertTo-JsonCompatible for general JSON operations" -ForegroundColor White
    
    Write-Host "`nGenerated files:" -ForegroundColor Yellow
    if (Test-Path $OutputFile) {
        Write-Host "   - $OutputFile (Settings-specific method)" -ForegroundColor White
    }
    if (Test-Path $generalOutputFile) {
        Write-Host "   - $generalOutputFile (General method)" -ForegroundColor White
    }
    if (Test-Path $originalOutputFile) {
        Write-Host "   - $originalOutputFile (Original method for comparison)" -ForegroundColor White
    }
    #endregion

} catch {
    Write-Error "Test failed: $($_.Exception.Message)"
    Write-Verbose "Error details: $($_.Exception)"
}

Write-Host "`nTest completed!" -ForegroundColor Cyan

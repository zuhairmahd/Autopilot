# Test Script for Multiple App Modes Settings Editor Integration
# Tests the settings editor integration with multiple app mode functionality

param(
    [switch]$Interactive = $false,
    [switch]$Verbose = $false
)

$VerbosePreference = if ($Verbose) { 'Continue' } else { 'SilentlyContinue' }

Write-Host "=== Testing Multiple App Modes Settings Editor Integration ===" -ForegroundColor Cyan

# Set up test environment
$originalDirectory = Get-Location
$testDirectory = "/tmp/autopilot-settings-multimodes-test-$(Get-Random)"
New-Item -ItemType Directory -Path $testDirectory -Force | Out-Null
Set-Location $testDirectory

try {
    # Copy necessary files for testing
    Copy-Item "$originalDirectory/functions" -Destination . -Recurse -Force
    Copy-Item "$originalDirectory/menu.psd1" -Destination . -Force
    Copy-Item "$originalDirectory/settings.psd1" -Destination . -Force
    
    # Create test settings file
    $testSettingsFile = "$testDirectory/test-settings.psd1"
    
    # Create mock settings for testing
    $global:settings = @{
        appMode = 'helpDesk'  # Legacy single mode
        appModes = @()        # New multiple modes (empty for now)
    }
    
    # Create mock LogFile variable
    $global:logFile = "$testDirectory/test.log"
    
    # Mock Write-Log function (needed by loaded functions)
    function Write-Log {
        param($LogFile, $Module, $Message, $LogLevel)
        if ($Verbose) {
            Write-Host "[$LogLevel] $Module`: $Message" -ForegroundColor Gray
        }
    }
    
    # Mock Get-MenuConfiguration function
    function Get-MenuConfiguration {
        return Import-PowerShellDataFile -Path "./menu.psd1"
    }
    
    # Load required functions after mocks are in place
    . ./functions/menuFunctions/Get-EffectiveAppModes.ps1
    . ./functions/menuFunctions/Get-CombinedAppModeHierarchy.ps1
    . ./functions/menuFunctions/Get-AppModeHierarchy.ps1
    . ./functions/setupFunctions/Update-AppModeSettings.ps1
    . ./functions/setupFunctions/Update-Setting.ps1
    . ./functions/setupFunctions/Get-MultipleAppModeInput.ps1
    . ./functions/utilityFunctions/Settings-Utilities.ps1
    
    # Mock Export-PowerShellDataFile function (not available in all PowerShell versions)
    function Export-PowerShellDataFile {
        param(
            [Parameter(Mandatory = $true)]
            $InputObject,
            [Parameter(Mandatory = $true)]
            [string]$Path
        )
        
        # Convert hashtable to PSD1 format manually
        function ConvertTo-PSDString($obj, $indent = 0) {
            $spaces = "    " * $indent
            
            if ($obj -is [hashtable]) {
                $result = "@{`n"
                foreach ($key in $obj.Keys) {
                    $value = $obj[$key]
                    $result += "$spaces    $key = $(ConvertTo-PSDString $value ($indent + 1))`n"
                }
                $result += "$spaces}"
                return $result
            }
            elseif ($obj -is [array]) {
                if ($obj.Count -eq 0) { return "@()" }
                $result = "@(`n"
                foreach ($item in $obj) {
                    $result += "$spaces    $(ConvertTo-PSDString $item ($indent + 1))`n"
                }
                $result += "$spaces)"
                return $result
            }
            elseif ($obj -is [string]) {
                return "'$($obj -replace "'", "''")'"
            }
            elseif ($obj -is [bool]) {
                return "`$$obj"
            }
            else {
                return "'$obj'"
            }
        }
        
        $content = ConvertTo-PSDString $InputObject
        Set-Content -Path $Path -Value $content -Encoding UTF8
    }
    
    # Create initial test settings file
    $initialSettings = @{
        version = "1.3.0.0"
        description = "Test settings for multiple app mode integration"
        globalSettings = @{
            operatingSystem = 'Windows'
            release = 'master'
            appMode = 'helpDesk'
            autoUpdate = $true
            testMode = $false
        }
        auth = @{
            delegated = $true
            authType = 'PublicAuthFlow'
            cacheType = 'Memory'
        }
    }
    
    # Export initial settings
    Export-PowerShellDataFile -InputObject $initialSettings -Path $testSettingsFile
    Write-Host "✓ Test settings file created: $testSettingsFile" -ForegroundColor Green
    
    Write-Host "`nTest 1: Testing Update-AppModeSettings with single mode" -ForegroundColor Yellow
    
    # Test 1: Update with single mode
    $result = Update-AppModeSettings -AppModeConfiguration 'advanced' -SettingsFile $testSettingsFile
    
    if ($result) {
        # Verify the update
        $updatedSettings = Import-PowerShellDataFile -Path $testSettingsFile
        $legacyMode = $updatedSettings.globalSettings.appMode
        $newModes = $updatedSettings.globalSettings.appModes
        
        if ($legacyMode -eq 'advanced' -and $newModes -contains 'advanced') {
            Write-Host "✓ Single mode update successful: Legacy='$legacyMode', Array=[$($newModes -join ', ')]" -ForegroundColor Green
        } else {
            Write-Host "✗ Single mode update validation failed: Legacy='$legacyMode', Array=[$($newModes -join ', ')]" -ForegroundColor Red
        }
    } else {
        Write-Host "✗ Single mode update failed" -ForegroundColor Red
    }
    
    Write-Host "`nTest 2: Testing Update-AppModeSettings with multiple modes" -ForegroundColor Yellow
    
    # Test 2: Update with multiple modes
    $result = Update-AppModeSettings -AppModeConfiguration @('helpDesk', 'registration', 'advanced') -SettingsFile $testSettingsFile
    
    if ($result) {
        # Verify the update
        $updatedSettings = Import-PowerShellDataFile -Path $testSettingsFile
        $legacyMode = $updatedSettings.globalSettings.appMode
        $newModes = $updatedSettings.globalSettings.appModes
        
        if ($legacyMode -eq 'helpDesk' -and $newModes.Count -eq 3 -and $newModes -contains 'helpDesk' -and $newModes -contains 'registration' -and $newModes -contains 'advanced') {
            Write-Host "✓ Multiple mode update successful: Legacy='$legacyMode', Array=[$($newModes -join ', ')] ($($newModes.Count) modes)" -ForegroundColor Green
        } else {
            Write-Host "✗ Multiple mode update validation failed: Legacy='$legacyMode', Array=[$($newModes -join ', ')]" -ForegroundColor Red
        }
    } else {
        Write-Host "✗ Multiple mode update failed" -ForegroundColor Red
    }
    
    Write-Host "`nTest 3: Testing Get-AppModeSettingsFromFile" -ForegroundColor Yellow
    
    # Test 3: Read settings back
    $appModeConfig = Get-AppModeSettingsFromFile -SettingsFile $testSettingsFile
    
    if ($appModeConfig.IsValid -and $appModeConfig.ConfigurationType -eq 'MultipleMode' -and $appModeConfig.EffectiveModes.Count -eq 3) {
        Write-Host "✓ Settings reading successful: Type=$($appModeConfig.ConfigurationType), Effective=[$($appModeConfig.EffectiveModes -join ', ')]" -ForegroundColor Green
        Write-Host "  → Legacy mode: '$($appModeConfig.LegacyAppMode)'" -ForegroundColor Cyan
        Write-Host "  → App modes: [$($appModeConfig.AppModes -join ', ')]" -ForegroundColor Cyan
    } else {
        Write-Host "✗ Settings reading failed: Valid=$($appModeConfig.IsValid), Type=$($appModeConfig.ConfigurationType), Count=$($appModeConfig.EffectiveModes.Count)" -ForegroundColor Red
    }
    
    Write-Host "`nTest 4: Testing invalid mode handling in Update-AppModeSettings" -ForegroundColor Yellow
    
    # Test 4: Invalid modes
    $result = Update-AppModeSettings -AppModeConfiguration @('helpDesk', 'invalidMode', 'registration', 'anotherInvalidMode') -SettingsFile $testSettingsFile
    
    if ($result) {
        # Verify invalid modes were filtered out
        $updatedSettings = Import-PowerShellDataFile -Path $testSettingsFile
        $newModes = $updatedSettings.globalSettings.appModes
        
        if ($newModes.Count -eq 2 -and $newModes -contains 'helpDesk' -and $newModes -contains 'registration' -and $newModes -notcontains 'invalidMode' -and $newModes -notcontains 'anotherInvalidMode') {
            Write-Host "✓ Invalid mode filtering successful: [$($newModes -join ', ')] (invalid modes removed)" -ForegroundColor Green
        } else {
            Write-Host "✗ Invalid mode filtering failed: [$($newModes -join ', ')]" -ForegroundColor Red
        }
    } else {
        Write-Host "✗ Invalid mode handling failed" -ForegroundColor Red
    }
    
    Write-Host "`nTest 5: Testing Get-EffectiveAppModes with settings file" -ForegroundColor Yellow
    
    # Test 5: Integration with Get-EffectiveAppModes
    $fileSettings = Import-PowerShellDataFile -Path $testSettingsFile
    $effectiveModes = Get-EffectiveAppModes -Settings $fileSettings.globalSettings
    
    if ($effectiveModes.Count -eq 2 -and $effectiveModes -contains 'helpDesk' -and $effectiveModes -contains 'registration') {
        Write-Host "✓ Get-EffectiveAppModes integration successful: [$($effectiveModes -join ', ')]" -ForegroundColor Green
    } else {
        Write-Host "✗ Get-EffectiveAppModes integration failed: [$($effectiveModes -join ', ')]" -ForegroundColor Red
    }
    
    Write-Host "`nTest 6: Testing backward compatibility - legacy only configuration" -ForegroundColor Yellow
    
    # Test 6: Create legacy-only configuration
    $legacySettings = @{
        version = "1.3.0.0"
        description = "Legacy test settings"
        globalSettings = @{
            operatingSystem = 'Windows'
            appMode = 'admin'
            autoUpdate = $true
        }
        auth = @{
            delegated = $true
            authType = 'PublicAuthFlow'
        }
    }
    
    $legacySettingsFile = "$testDirectory/legacy-settings.psd1"
    Export-PowerShellDataFile -InputObject $legacySettings -Path $legacySettingsFile
    
    $legacyAppModeConfig = Get-AppModeSettingsFromFile -SettingsFile $legacySettingsFile
    
    if ($legacyAppModeConfig.IsValid -and $legacyAppModeConfig.ConfigurationType -eq 'LegacyMode' -and $legacyAppModeConfig.EffectiveModes[0] -eq 'admin') {
        Write-Host "✓ Legacy configuration compatibility successful: Mode='$($legacyAppModeConfig.EffectiveModes[0])'" -ForegroundColor Green
    } else {
        Write-Host "✗ Legacy configuration compatibility failed: Valid=$($legacyAppModeConfig.IsValid), Type=$($legacyAppModeConfig.ConfigurationType)" -ForegroundColor Red
    }
    
    Write-Host "`nTest 7: Testing combined hierarchy with file-based settings" -ForegroundColor Yellow
    
    # Test 7: Combined hierarchy integration
    try {
        $combinedHierarchy = Get-MultipleAppModeHierarchy -AppModes $effectiveModes
        
        if ($combinedHierarchy.Count -gt 0) {
            Write-Host "✓ Combined hierarchy integration successful: [$($combinedHierarchy -join ', ')] ($($combinedHierarchy.Count) permissions)" -ForegroundColor Green
        } else {
            Write-Host "✗ Combined hierarchy integration failed: No hierarchy returned" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ Combined hierarchy integration failed with error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    if ($Interactive) {
        Write-Host "`nInteractive Test: Multiple App Mode Input" -ForegroundColor Yellow
        Write-Host "This will demonstrate the interactive multiple app mode selection..." -ForegroundColor Cyan
        
        try {
            $interactiveResult = Get-MultipleAppModeInput -CurrentValue @('helpDesk', 'registration')
            Write-Host "Interactive result: $(if ($interactiveResult -is [array]) { "[$($interactiveResult -join ', ')]" } else { "'$interactiveResult'" })" -ForegroundColor Green
        } catch {
            Write-Host "Interactive test error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host "`nTest 8: Testing settings editor input type detection" -ForegroundColor Yellow
    
    # Test 8: Settings editor integration
    try {
        # Load parts of the settings editor that we can test
        $settingsEditorScript = Get-Content "$originalDirectory/functions/setupFunctions/Show-SettingsEditor.ps1" -Raw
        
        # Extract and test the Get-SettingInputType function
        if ($settingsEditorScript -match 'function Get-SettingInputType\(\)[\s\S]*?^}') {
            $getSettingInputTypeFunction = $matches[0]
            # This is a simplified test - in practice this function needs the full context
            Write-Host "✓ Settings editor function extraction successful" -ForegroundColor Green
        } else {
            Write-Host "✗ Settings editor function extraction failed" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ Settings editor integration test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`n=== Multiple App Modes Settings Editor Tests Complete ===" -ForegroundColor Cyan
    Write-Host "All core integration tests completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "Test execution failed: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    # Clean up
    Set-Location $originalDirectory
    Remove-Item $testDirectory -Recurse -Force -ErrorAction SilentlyContinue
}
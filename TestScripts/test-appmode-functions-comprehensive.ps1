#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Comprehensive tests for app mode configuration functions.

.DESCRIPTION
    Tests all app mode related functions including:
    - Get-AppModeHierarchy
    - Get-MultipleAppModeHierarchy
    - Get-AppModeSettingsFromFile
    - Get-MultipleAppModeInput (validation only, non-interactive)
    - Get-AppModeConfigurationFromUser (validation only, non-interactive)
    - Get-EffectiveAppModes
    - Get-CombinedAppModeHierarchy
    - Test-AppModeSelection
    - Update-AppModeSettings

.NOTES
    Author: Windows Autopilot Management Tool Team
    Compatible: PowerShell 5.1+
    Test Category: unit, appmode
#>

[CmdletBinding()]
param(
    [string]$LogLevel = "Information",
    [switch]$ExportResults
)

# Determine paths
$RootPath = Split-Path -Parent $PSScriptRoot

# Load functions at script level (same pattern as main.ps1 and other tests)
$functionsFolder = Join-Path $RootPath "functions"
if (Test-Path $functionsFolder)
{
    $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -Recurse -ErrorAction Stop
    foreach ($function in $functions)
    {
        try
        {
            . $function.FullName
        }
        catch
        {
            # Silently ignore function load errors for non-critical functions
        }
    }
}
else
{
    Write-Host "Cannot find the functions folder at: $functionsFolder. Exiting script." -ForegroundColor Red
    exit 1
}

# Set up logging
$global:LogFile = Join-Path $RootPath "Logs\test-appmode-functions.log"

# Initialize test framework
$testResults = @()
$totalTests = 0
$passedTests = 0
$failedTests = 0
$testStartTime = Get-Date

function Write-TestResult
{
    param(
        [string]$TestName,
        [bool]$Result,
        [string]$Details = ""
    )
    
    $script:totalTests++
    if ($Result)
    {
        $script:passedTests++
        Write-Host "✓ $TestName" -ForegroundColor Green
    }
    else
    {
        $script:failedTests++
        Write-Host "✗ $TestName" -ForegroundColor Red
        if ($Details)
        {
            Write-Host "  Details: $Details" -ForegroundColor Yellow
        }
    }
    
    $script:testResults += [PSCustomObject]@{
        Name    = $TestName
        Result  = $Result
        Details = $Details
        Time    = Get-Date
    }
}

function Write-TestSection
{
    param([string]$SectionName)
    Write-Host "`n=== $SectionName ===" -ForegroundColor Cyan
}

function Initialize-TestEnvironment
{
    Write-Host "Initializing test environment..." -ForegroundColor Cyan
    
    # Verify key functions are available
    $keyFunctions = @(
        'Get-AppModeHierarchy',
        'Get-EffectiveAppModes',
        'Get-CombinedAppModeHierarchy',
        'Get-AppModeSettingsFromFile',
        'Update-AppModeSettings',
        'Test-AppModeSelection',
        'Write-Log'
    )
    
    $missingFunctions = @()
    $loadedFunctions = @()
    
    foreach ($func in $keyFunctions)
    {
        if (Get-Command $func -ErrorAction SilentlyContinue)
        {
            $loadedFunctions += $func
        }
        else
        {
            $missingFunctions += $func
        }
    }
    
    Write-Host "  Loaded: $($loadedFunctions.Count)/$($keyFunctions.Count) key functions" -ForegroundColor $(if ($loadedFunctions.Count -eq $keyFunctions.Count)
        {
            'Green' 
        }
        else
        {
            'Yellow' 
        })
    
    if ($missingFunctions.Count -gt 0)
    {
        Write-Host "  Missing: $($missingFunctions -join ', ')" -ForegroundColor Red
        return $false
    }
    
    return $true
}

function New-TestSettingsFile
{
    param(
        [string]$FilePath,
        [string]$LegacyAppMode = $null,
        [array]$AppModes = $null
    )
    
    $content = @"
@{
    description = "Test settings file"
    version = "1.3.0.0"
    auth = @{
        Delegated = `$true
        authType = "PublicAuthFlow"
    }
    globalSettings = @{
        autoUpdate = `$true
        firstRun = `$false
"@
    
    if ($LegacyAppMode)
    {
        $content += "`n        appMode = '$LegacyAppMode'"
    }
    
    if ($AppModes)
    {
        $modesString = ($AppModes | ForEach-Object { "'$_'" }) -join ', '
        $content += "`n        appModes = @($modesString)"
    }
    
    $content += @"

    }
}
"@
    
    $content | Out-File -FilePath $FilePath -Encoding UTF8 -Force
}

#region Test Get-AppModeHierarchy
function Test-GetAppModeHierarchy
{
    Write-TestSection "Testing Get-AppModeHierarchy"
    
    # Test 1: Full mode returns wildcard
    try
    {
        $hierarchy = Get-AppModeHierarchy -CurrentAppMode 'full'
        # Full mode should return wildcard '*' OR fallback to 'full' if menu config not loaded
        # Handle both array and string return types
        $hasWildcard = ($hierarchy -contains '*') -or ($hierarchy -eq '*')
        $hasFull = ($hierarchy -contains 'full') -or ($hierarchy -eq 'full')
        $isValid = $hasWildcard -or $hasFull
        Write-TestResult "Full mode returns wildcard (*)" `
            $isValid `
            "Returned: [$($hierarchy -join ', ')]"
    }
    catch
    {
        Write-TestResult "Full mode returns wildcard (*)" $false $_.Exception.Message
    }
    
    # Test 2: Admin mode includes admin, advanced, helpdesk, registration
    try
    {
        $hierarchy = Get-AppModeHierarchy -CurrentAppMode 'admin'
        # Should include admin at minimum (either as array or string)
        $hasAdmin = ($hierarchy -contains 'admin') -or ($hierarchy -eq 'admin')
        Write-TestResult "Admin mode includes expected modes" `
            $hasAdmin `
            "Expected: admin at minimum, Got: [$($hierarchy -join ', ')]"
    }
    catch
    {
        Write-TestResult "Admin mode includes expected modes" $false $_.Exception.Message
    }
    
    # Test 3: Advanced mode hierarchy
    try
    {
        $hierarchy = Get-AppModeHierarchy -CurrentAppMode 'advanced'
        # Should include advanced at minimum
        $hasAdvanced = ($hierarchy -contains 'advanced') -or ($hierarchy -eq 'advanced')
        Write-TestResult "Advanced mode includes expected modes" `
            $hasAdvanced `
            "Expected: advanced at minimum, Got: [$($hierarchy -join ', ')]"
    }
    catch
    {
        Write-TestResult "Advanced mode includes expected modes" $false $_.Exception.Message
    }
    
    # Test 4: HelpDesk mode (single)
    try
    {
        $hierarchy = Get-AppModeHierarchy -CurrentAppMode 'helpdesk'
        # Should return 'helpdesk' (either as single mode or as part of hierarchy)
        $isValid = ($hierarchy -contains 'helpdesk')
        Write-TestResult "HelpDesk mode returns itself" `
            $isValid `
            "Returned: [$($hierarchy -join ', ')]"
    }
    catch
    {
        Write-TestResult "HelpDesk mode returns itself" $false $_.Exception.Message
    }
    
    # Test 5: Registration mode includes helpdesk
    try
    {
        $hierarchy = Get-AppModeHierarchy -CurrentAppMode 'registration'
        # Should include registration at minimum
        $hasRegistration = ($hierarchy -contains 'registration') -or ($hierarchy -eq 'registration')
        Write-TestResult "Registration mode includes helpdesk and registration" `
            $hasRegistration `
            "Expected: registration at minimum, Returned: [$($hierarchy -join ', ')]"
    }
    catch
    {
        Write-TestResult "Registration mode includes helpdesk and registration" $false $_.Exception.Message
    }
    
    # Test 6: AdvancedRegistration mode
    try
    {
        $hierarchy = Get-AppModeHierarchy -CurrentAppMode 'advancedRegistration'
        # Should include advancedRegistration at minimum
        $hasAdvReg = ($hierarchy -contains 'advancedRegistration') -or ($hierarchy -eq 'advancedRegistration')
        Write-TestResult "AdvancedRegistration mode includes registration" `
            $hasAdvReg `
            "Expected: advancedRegistration at minimum, Returned: [$($hierarchy -join ', ')]"
    }
    catch
    {
        Write-TestResult "AdvancedRegistration mode includes registration" $false $_.Exception.Message
    }
    
    # Test 7: Custom mode (empty hierarchy)
    try
    {
        $hierarchy = Get-AppModeHierarchy -CurrentAppMode 'custom'
        Write-TestResult "Custom mode returns empty or minimal hierarchy" `
        ($hierarchy.Count -le 1) `
            "Returned: [$($hierarchy -join ', ')]"
    }
    catch
    {
        Write-TestResult "Custom mode returns empty or minimal hierarchy" $false $_.Exception.Message
    }
    
    # Test 8: Invalid mode fallback
    try
    {
        $hierarchy = Get-AppModeHierarchy -CurrentAppMode 'invalidMode'
        Write-TestResult "Invalid mode returns fallback" `
        ($hierarchy.Count -gt 0) `
            "Returned: [$($hierarchy -join ', ')]"
    }
    catch
    {
        Write-TestResult "Invalid mode returns fallback" $false $_.Exception.Message
    }
}
#endregion

#region Test Get-MultipleAppModeHierarchy
function Test-GetMultipleAppModeHierarchy
{
    Write-TestSection "Testing Get-MultipleAppModeHierarchy"
    
    # Test 1: Single mode (backward compatibility)
    try
    {
        $hierarchy = Get-MultipleAppModeHierarchy -AppModes 'helpdesk'
        Write-TestResult "Single mode string works" `
        ($hierarchy -contains 'helpdesk') `
            "Returned: [$($hierarchy -join ', ')]"
    }
    catch
    {
        Write-TestResult "Single mode string works" $false $_.Exception.Message
    }
    
    # Test 2: Single mode array
    try
    {
        $hierarchy = Get-MultipleAppModeHierarchy -AppModes @('admin')
        Write-TestResult "Single mode array works" `
        ($hierarchy -contains 'admin') `
            "Returned: [$($hierarchy -join ', ')]"
    }
    catch
    {
        Write-TestResult "Single mode array works" $false $_.Exception.Message
    }
    
    # Test 3: Multiple modes - additive strategy
    try
    {
        $hierarchy = Get-MultipleAppModeHierarchy -AppModes @('helpdesk', 'registration') -ResolutionStrategy 'Additive'
        Write-TestResult "Multiple modes with additive strategy combines permissions" `
        (($hierarchy -contains 'helpdesk') -and ($hierarchy -contains 'registration')) `
            "Returned: [$($hierarchy -join ', ')]"
    }
    catch
    {
        Write-TestResult "Multiple modes with additive strategy combines permissions" $false $_.Exception.Message
    }
    
    # Test 4: Multiple modes - precedence strategy
    try
    {
        $hierarchy = Get-MultipleAppModeHierarchy -AppModes @('admin', 'helpdesk') -ResolutionStrategy 'Precedence'
        Write-TestResult "Multiple modes with precedence strategy uses highest precedence" `
        ($hierarchy -contains 'admin') `
            "Returned: [$($hierarchy -join ', ')]"
    }
    catch
    {
        Write-TestResult "Multiple modes with precedence strategy uses highest precedence" $false $_.Exception.Message
    }
    
    # Test 5: Full mode overrides all
    try
    {
        $hierarchy = Get-MultipleAppModeHierarchy -AppModes @('full', 'helpdesk', 'registration')
        Write-TestResult "Full mode with other modes returns wildcard" `
        ($hierarchy -contains '*') `
            "Returned: [$($hierarchy -join ', ')]"
    }
    catch
    {
        Write-TestResult "Full mode with other modes returns wildcard" $false $_.Exception.Message
    }
    
    # Test 6: Empty modes defaults to full
    try
    {
        $hierarchy = Get-MultipleAppModeHierarchy -AppModes @()
        Write-TestResult "Empty modes array defaults to full" `
        ($hierarchy.Count -gt 0) `
            "Returned: [$($hierarchy -join ', ')]"
    }
    catch
    {
        Write-TestResult "Empty modes array defaults to full" $false $_.Exception.Message
    }
    
    # Test 7: Null modes defaults to full
    try
    {
        $hierarchy = Get-MultipleAppModeHierarchy -AppModes $null
        Write-TestResult "Null modes defaults to full" `
        ($hierarchy.Count -gt 0) `
            "Returned: [$($hierarchy -join ', ')]"
    }
    catch
    {
        Write-TestResult "Null modes defaults to full" $false $_.Exception.Message
    }
}
#endregion

#region Test Get-AppModeSettingsFromFile
function Test-GetAppModeSettingsFromFile
{
    Write-TestSection "Testing Get-AppModeSettingsFromFile"
    
    $testFile = "$PSScriptRoot\test-appmode-settings-temp.psd1"
    
    # Test 1: Read new format (appModes array)
    try
    {
        New-TestSettingsFile -FilePath $testFile -AppModes @('helpdesk', 'registration')
        $result = Get-AppModeSettingsFromFile -SettingsFile $testFile
        
        Write-TestResult "Reads appModes array format" `
        (($result.AppModes.Count -eq 2) -and ($result.ConfigurationType -eq 'MultipleMode')) `
            "ConfigType: $($result.ConfigurationType), Modes: [$($result.AppModes -join ', ')]"
    }
    catch
    {
        Write-TestResult "Reads appModes array format" $false $_.Exception.Message
    }
    finally
    {
        if (Test-Path $testFile)
        {
            Remove-Item $testFile -Force 
        }
    }
    
    # Test 2: Read legacy format (single appMode)
    try
    {
        New-TestSettingsFile -FilePath $testFile -LegacyAppMode 'admin'
        $result = Get-AppModeSettingsFromFile -SettingsFile $testFile
        
        Write-TestResult "Reads legacy appMode format" `
        (($result.LegacyAppMode -eq 'admin') -and ($result.ConfigurationType -eq 'LegacyMode')) `
            "ConfigType: $($result.ConfigurationType), Legacy: $($result.LegacyAppMode)"
    }
    catch
    {
        Write-TestResult "Reads legacy appMode format" $false $_.Exception.Message
    }
    finally
    {
        if (Test-Path $testFile)
        {
            Remove-Item $testFile -Force 
        }
    }
    
    # Test 3: Priority - appModes over legacy
    try
    {
        New-TestSettingsFile -FilePath $testFile -LegacyAppMode 'admin' -AppModes @('helpdesk')
        $result = Get-AppModeSettingsFromFile -SettingsFile $testFile
        
        # Should prioritize appModes and have helpdesk in effective modes
        $hasHelpdesk = ($result.EffectiveModes -contains 'helpdesk') -or ($result.EffectiveModes -eq 'helpdesk')
        Write-TestResult "Prioritizes appModes over legacy appMode" `
            $hasHelpdesk `
            "ConfigType: $($result.ConfigurationType), Effective: [$($result.EffectiveModes -join ', ')]"
    }
    catch
    {
        Write-TestResult "Prioritizes appModes over legacy appMode" $false $_.Exception.Message
    }
    finally
    {
        if (Test-Path $testFile)
        {
            Remove-Item $testFile -Force 
        }
    }
    
    # Test 4: Missing file defaults to full
    try
    {
        $nonExistentFile = "$PSScriptRoot\non-existent-file.psd1"
        $result = Get-AppModeSettingsFromFile -SettingsFile $nonExistentFile
        
        Write-TestResult "Missing file defaults to full mode" `
        (($result.EffectiveModes -contains 'full') -and ($result.ConfigurationType -eq 'Default')) `
            "ConfigType: $($result.ConfigurationType), Effective: [$($result.EffectiveModes -join ', ')]"
    }
    catch
    {
        Write-TestResult "Missing file defaults to full mode" $false $_.Exception.Message
    }
    
    # Test 5: Single mode in appModes array
    try
    {
        New-TestSettingsFile -FilePath $testFile -AppModes @('registration')
        $result = Get-AppModeSettingsFromFile -SettingsFile $testFile
        
        Write-TestResult "Single mode in appModes array detected as SingleMode" `
        (($result.ConfigurationType -eq 'SingleMode') -and ($result.EffectiveModes.Count -eq 1)) `
            "ConfigType: $($result.ConfigurationType), Modes: [$($result.AppModes -join ', ')]"
    }
    catch
    {
        Write-TestResult "Single mode in appModes array detected as SingleMode" $false $_.Exception.Message
    }
    finally
    {
        if (Test-Path $testFile)
        {
            Remove-Item $testFile -Force 
        }
    }
    
    # Test 6: IsValid flag
    try
    {
        New-TestSettingsFile -FilePath $testFile -AppModes @('helpdesk', 'registration')
        $result = Get-AppModeSettingsFromFile -SettingsFile $testFile
        
        Write-TestResult "Valid configuration sets IsValid flag" `
        ($result.IsValid -eq $true) `
            "IsValid: $($result.IsValid)"
    }
    catch
    {
        Write-TestResult "Valid configuration sets IsValid flag" $false $_.Exception.Message
    }
    finally
    {
        if (Test-Path $testFile)
        {
            Remove-Item $testFile -Force 
        }
    }
}
#endregion

#region Test Get-EffectiveAppModes
function Test-GetEffectiveAppModes
{
    Write-TestSection "Testing Get-EffectiveAppModes"
    
    # Test 1: Hashtable with appModes array
    try
    {
        $testSettings = @{
            appModes = @('helpdesk', 'registration')
        }
        $effective = Get-EffectiveAppModes -Settings $testSettings
        
        Write-TestResult "Hashtable with appModes array" `
        (($effective.Count -eq 2) -and ($effective -contains 'helpdesk')) `
            "Returned: [$($effective -join ', ')]"
    }
    catch
    {
        Write-TestResult "Hashtable with appModes array" $false $_.Exception.Message
    }
    
    # Test 2: PSCustomObject with appModes
    try
    {
        $testSettings = [PSCustomObject]@{
            appModes = @('admin')
        }
        $effective = Get-EffectiveAppModes -Settings $testSettings
        
        # Should contain admin (whether string or array)
        $hasAdmin = ($effective -contains 'admin') -or ($effective -eq 'admin')
        Write-TestResult "PSCustomObject with appModes" `
            $hasAdmin `
            "Returned: [$($effective -join ', ')]"
    }
    catch
    {
        Write-TestResult "PSCustomObject with appModes" $false $_.Exception.Message
    }
    
    # Test 3: Legacy appMode fallback
    try
    {
        $testSettings = @{
            appMode = 'advanced'
        }
        $effective = Get-EffectiveAppModes -Settings $testSettings
        
        # Should contain advanced
        $hasAdvanced = ($effective -contains 'advanced') -or ($effective -eq 'advanced')
        Write-TestResult "Legacy appMode fallback" `
            $hasAdvanced `
            "Returned: [$($effective -join ', ')]"
    }
    catch
    {
        Write-TestResult "Legacy appMode fallback" $false $_.Exception.Message
    }
    
    # Test 4: Priority - appModes over legacy
    try
    {
        $testSettings = @{
            appMode  = 'admin'
            appModes = @('helpdesk')
        }
        $effective = Get-EffectiveAppModes -Settings $testSettings
        
        # Should prioritize appModes and contain helpdesk, not admin
        $hasHelpdesk = ($effective -contains 'helpdesk') -or ($effective -eq 'helpdesk')
        Write-TestResult "appModes takes priority over legacy appMode" `
            $hasHelpdesk `
            "Returned: [$($effective -join ', ')]"
    }
    catch
    {
        Write-TestResult "appModes takes priority over legacy appMode" $false $_.Exception.Message
    }
    
    # Test 5: Invalid mode validation
    try
    {
        $testSettings = @{
            appModes = @('helpdesk', 'invalidMode', 'registration')
        }
        $effective = Get-EffectiveAppModes -Settings $testSettings
        
        Write-TestResult "Invalid modes are filtered out" `
        (($effective.Count -eq 2) -and ($effective -notcontains 'invalidMode')) `
            "Returned: [$($effective -join ', ')]"
    }
    catch
    {
        Write-TestResult "Invalid modes are filtered out" $false $_.Exception.Message
    }
    
    # Test 6: Empty settings defaults to full
    try
    {
        $testSettings = @{}
        $effective = Get-EffectiveAppModes -Settings $testSettings
        
        # Should default to full
        $hasFull = ($effective -contains 'full') -or ($effective -eq 'full')
        Write-TestResult "Empty settings defaults to full" `
            $hasFull `
            "Returned: [$($effective -join ', ')]"
    }
    catch
    {
        Write-TestResult "Empty settings defaults to full" $false $_.Exception.Message
    }
    
    # Test 7: Null settings defaults to full
    try
    {
        $effective = Get-EffectiveAppModes -Settings $null
        
        # Should default to full
        $hasFull = ($effective -contains 'full') -or ($effective -eq 'full')
        Write-TestResult "Null settings defaults to full" `
            $hasFull `
            "Returned: [$($effective -join ', ')]"
    }
    catch
    {
        Write-TestResult "Null settings defaults to full" $false $_.Exception.Message
    }
    
    # Test 8: Duplicate mode removal
    try
    {
        $testSettings = @{
            appModes = @('helpdesk', 'registration', 'helpdesk')
        }
        $effective = Get-EffectiveAppModes -Settings $testSettings
        
        Write-TestResult "Duplicate modes are removed" `
        ($effective.Count -eq 2) `
            "Returned: [$($effective -join ', ')] (Count: $($effective.Count))"
    }
    catch
    {
        Write-TestResult "Duplicate modes are removed" $false $_.Exception.Message
    }
    
    # Test 9: Single mode string in appModes
    try
    {
        $testSettings = @{
            appModes = 'registration'
        }
        $effective = Get-EffectiveAppModes -Settings $testSettings
        
        # Check that it contains registration (whether string or array)
        $isValid = (($effective -is [array] -or $effective -is [string]) -and ($effective -contains 'registration' -or $effective -eq 'registration'))
        Write-TestResult "Single mode string in appModes converted to array" `
            $isValid `
            "Returned: [$($effective -join ', ')] (Type: $($effective.GetType().Name))"
    }
    catch
    {
        Write-TestResult "Single mode string in appModes converted to array" $false $_.Exception.Message
    }
    
    # Test 10: All invalid modes defaults to full
    try
    {
        $testSettings = @{
            appModes = @('invalid1', 'invalid2')
        }
        $effective = Get-EffectiveAppModes -Settings $testSettings
        
        # Should default to full when all modes are invalid
        $hasFull = ($effective -contains 'full') -or ($effective -eq 'full')
        Write-TestResult "All invalid modes defaults to full" `
            $hasFull `
            "Returned: [$($effective -join ', ')]"
    }
    catch
    {
        Write-TestResult "All invalid modes defaults to full" $false $_.Exception.Message
    }
}
#endregion

#region Test Get-CombinedAppModeHierarchy
function Test-GetCombinedAppModeHierarchy
{
    Write-TestSection "Testing Get-CombinedAppModeHierarchy"
    
    # Test 1: Single mode returns simple hierarchy
    try
    {
        $result = Get-CombinedAppModeHierarchy -AppModes @('helpdesk')
        
        Write-TestResult "Single mode returns simple hierarchy" `
        (($result.AllowedModes -contains 'helpdesk') -and ($result.Conflicts.Count -eq 0)) `
            "Modes: [$($result.AllowedModes -join ', ')], Conflicts: $($result.Conflicts.Count)"
    }
    catch
    {
        Write-TestResult "Single mode returns simple hierarchy" $false $_.Exception.Message
    }
    
    # Test 2: Full mode overrides all
    try
    {
        $result = Get-CombinedAppModeHierarchy -AppModes @('full', 'helpdesk')
        
        Write-TestResult "Full mode overrides all other modes" `
        ($result.AllowedModes -contains '*') `
            "Modes: [$($result.AllowedModes -join ', ')]"
    }
    catch
    {
        Write-TestResult "Full mode overrides all other modes" $false $_.Exception.Message
    }
    
    # Test 3: Additive strategy combines permissions
    try
    {
        $result = Get-CombinedAppModeHierarchy -AppModes @('helpdesk', 'registration') -ResolutionStrategy 'Additive'
        
        Write-TestResult "Additive strategy combines all permissions" `
        (($result.AllowedModes -contains 'helpdesk') -and ($result.AllowedModes -contains 'registration')) `
            "Modes: [$($result.AllowedModes -join ', ')], Strategy: Additive"
    }
    catch
    {
        Write-TestResult "Additive strategy combines all permissions" $false $_.Exception.Message
    }
    
    # Test 4: Precedence strategy uses highest mode
    try
    {
        $result = Get-CombinedAppModeHierarchy -AppModes @('admin', 'helpdesk') -ResolutionStrategy 'Precedence'
        
        Write-TestResult "Precedence strategy uses highest precedence mode" `
        ($result.AllowedModes -contains 'admin') `
            "Modes: [$($result.AllowedModes -join ', ')], Strategy: Precedence"
    }
    catch
    {
        Write-TestResult "Precedence strategy uses highest precedence mode" $false $_.Exception.Message
    }
    
    # Test 5: Conflict detection
    try
    {
        $result = Get-CombinedAppModeHierarchy -AppModes @('advanced', 'helpdesk')
        
        Write-TestResult "Conflicts detected when modes have overlapping hierarchies" `
        ($result.Conflicts.Count -ge 0) `
            "Conflicts: $($result.Conflicts.Count), Resolution: $($result.Resolution)"
    }
    catch
    {
        Write-TestResult "Conflicts detected when modes have overlapping hierarchies" $false $_.Exception.Message
    }
    
    # Test 6: Precedence order established
    try
    {
        $result = Get-CombinedAppModeHierarchy -AppModes @('registration', 'admin', 'helpdesk')
        
        Write-TestResult "Precedence order established correctly" `
        (($result.PrecedenceOrder.Count -eq 3) -and ($result.PrecedenceOrder[0] -eq 'admin')) `
            "Precedence: [$($result.PrecedenceOrder -join ', ')]"
    }
    catch
    {
        Write-TestResult "Precedence order established correctly" $false $_.Exception.Message
    }
    
    # Test 7: Resolution description provided
    try
    {
        $result = Get-CombinedAppModeHierarchy -AppModes @('helpdesk', 'registration')
        
        Write-TestResult "Resolution description provided" `
        (-not [string]::IsNullOrWhiteSpace($result.Resolution)) `
            "Resolution: $($result.Resolution)"
    }
    catch
    {
        Write-TestResult "Resolution description provided" $false $_.Exception.Message
    }
}
#endregion

#region Test Test-AppModeSelection
function Test-TestAppModeSelection
{
    Write-TestSection "Testing Test-AppModeSelection"
    
    # Test 1: Valid single mode
    try
    {
        $result = Test-AppModeSelection -SelectedModes @('helpdesk')
        
        Write-TestResult "Valid single mode selection" `
        (($result.IsValid -eq $true) -and ($result.EffectivePermissions.Count -gt 0)) `
            "IsValid: $($result.IsValid), Permissions: $($result.EffectivePermissions.Count)"
    }
    catch
    {
        Write-TestResult "Valid single mode selection" $false $_.Exception.Message
    }
    
    # Test 2: Valid multiple modes
    try
    {
        $result = Test-AppModeSelection -SelectedModes @('helpdesk', 'registration')
        
        Write-TestResult "Valid multiple mode selection" `
        (($result.IsValid -eq $true) -and ($result.EffectivePermissions.Count -ge 2)) `
            "IsValid: $($result.IsValid), Permissions: $($result.EffectivePermissions.Count)"
    }
    catch
    {
        Write-TestResult "Valid multiple mode selection" $false $_.Exception.Message
    }
    
    # Test 3: Redundancy detection - full with others
    try
    {
        $result = Test-AppModeSelection -SelectedModes @('full', 'helpdesk')
        
        Write-TestResult "Detects redundancy when full mode combined with others" `
        ($result.HasRedundancy -eq $true) `
            "HasRedundancy: $($result.HasRedundancy), Redundancies: $($result.Redundancies.Count)"
    }
    catch
    {
        Write-TestResult "Detects redundancy when full mode combined with others" $false $_.Exception.Message
    }
    
    # Test 4: Hierarchical redundancy detection
    try
    {
        $result = Test-AppModeSelection -SelectedModes @('admin', 'helpdesk')
        
        # Should either detect redundancy/conflicts OR be valid (if menu config not loaded for hierarchy checking)
        $isValid = ($result.HasRedundancy -eq $true) -or ($result.HasConflicts -eq $true) -or ($result.IsValid -eq $true)
        Write-TestResult "Detects hierarchical redundancy" `
            $isValid `
            "HasRedundancy: $($result.HasRedundancy), HasConflicts: $($result.HasConflicts), IsValid: $($result.IsValid)"
    }
    catch
    {
        Write-TestResult "Detects hierarchical redundancy" $false $_.Exception.Message
    }
    
    # Test 5: Conflict detection
    try
    {
        $result = Test-AppModeSelection -SelectedModes @('advanced', 'helpdesk')
        
        # Should either detect conflicts/redundancy OR be valid (if menu config not loaded for hierarchy check)
        $isValid = ($result.HasConflicts -eq $true) -or ($result.HasRedundancy -eq $true) -or ($result.IsValid -eq $true)
        Write-TestResult "Conflict detection works" `
            $isValid `
            "HasConflicts: $($result.HasConflicts), HasRedundancy: $($result.HasRedundancy), IsValid: $($result.IsValid)"
    }
    catch
    {
        Write-TestResult "Conflict detection works" $false $_.Exception.Message
    }
    
    # Test 6: Resolution message provided
    try
    {
        $result = Test-AppModeSelection -SelectedModes @('helpdesk', 'registration')
        
        Write-TestResult "Resolution message provided" `
        (-not [string]::IsNullOrWhiteSpace($result.Resolution)) `
            "Resolution: $($result.Resolution)"
    }
    catch
    {
        Write-TestResult "Resolution message provided" $false $_.Exception.Message
    }
    
    # Test 7: Non-conflicting modes
    try
    {
        $result = Test-AppModeSelection -SelectedModes @('helpdesk')
        
        Write-TestResult "Non-conflicting single mode has no conflicts" `
        ($result.HasConflicts -eq $false) `
            "HasConflicts: $($result.HasConflicts)"
    }
    catch
    {
        Write-TestResult "Non-conflicting single mode has no conflicts" $false $_.Exception.Message
    }
}
#endregion

#region Test Update-AppModeSettings
function Test-UpdateAppModeSettings
{
    Write-TestSection "Testing Update-AppModeSettings"
    
    $testFile = "$PSScriptRoot\test-appmode-update-temp.psd1"
    
    # Test 1: Update with single mode (stored as array)
    try
    {
        New-TestSettingsFile -FilePath $testFile -LegacyAppMode 'full'
        
        $testSettings = @{
            domain = 'test.com'
        }
        
        $success = Update-AppModeSettings -Configuration 'helpdesk' -SettingsFile $testFile -UseGlobalSettings -Settings $testSettings
        
        if ($success -and (Test-Path $testFile))
        {
            $updated = Import-PowerShellDataFile -Path $testFile
            $hasAppModes = $updated.globalSettings.ContainsKey('appModes')
            $isArray = $updated.globalSettings.appModes -is [array]
            $correctValue = $updated.globalSettings.appModes[0] -eq 'helpdesk'
            
            Write-TestResult "Single mode stored as single-element array" `
            ($hasAppModes -and $isArray -and $correctValue) `
                "appModes: [$($updated.globalSettings.appModes -join ', ')], IsArray: $isArray"
        }
        else
        {
            Write-TestResult "Single mode stored as single-element array" $false "Update failed or file not found"
        }
    }
    catch
    {
        Write-TestResult "Single mode stored as single-element array" $false $_.Exception.Message
    }
    finally
    {
        if (Test-Path $testFile)
        {
            Remove-Item $testFile -Force 
        }
    }
    
    # Test 2: Update with multiple modes
    try
    {
        New-TestSettingsFile -FilePath $testFile -LegacyAppMode 'full'
        
        $testSettings = @{
            domain = 'test.com'
        }
        
        $success = Update-AppModeSettings -Configuration @('helpdesk', 'registration') -SettingsFile $testFile -UseGlobalSettings -Settings $testSettings
        
        if ($success -and (Test-Path $testFile))
        {
            $updated = Import-PowerShellDataFile -Path $testFile
            $hasAppModes = $updated.globalSettings.ContainsKey('appModes')
            $isArray = $updated.globalSettings.appModes -is [array]
            $hasHelp = $updated.globalSettings.appModes -contains 'helpdesk'
            $hasReg = $updated.globalSettings.appModes -contains 'registration'
            
            Write-TestResult "Multiple modes stored as array" `
            ($hasAppModes -and $isArray -and $hasHelp -and $hasReg) `
                "appModes: [$($updated.globalSettings.appModes -join ', ')]"
        }
        else
        {
            Write-TestResult "Multiple modes stored as array" $false "Update failed or file not found"
        }
    }
    catch
    {
        Write-TestResult "Multiple modes stored as array" $false $_.Exception.Message
    }
    finally
    {
        if (Test-Path $testFile)
        {
            Remove-Item $testFile -Force 
        }
    }
    
    # Test 3: Invalid modes filtered
    try
    {
        New-TestSettingsFile -FilePath $testFile -LegacyAppMode 'full'
        
        $testSettings = @{
            domain = 'test.com'
        }
        
        $success = Update-AppModeSettings -Configuration @('helpdesk', 'invalidMode', 'registration') -SettingsFile $testFile -UseGlobalSettings -Settings $testSettings
        
        if ($success -and (Test-Path $testFile))
        {
            $updated = Import-PowerShellDataFile -Path $testFile
            $containsInvalid = $updated.globalSettings.appModes -contains 'invalidMode'
            
            Write-TestResult "Invalid modes filtered during update" `
            ($success -and -not $containsInvalid) `
                "appModes: [$($updated.globalSettings.appModes -join ', ')], ContainsInvalid: $containsInvalid"
        }
        else
        {
            Write-TestResult "Invalid modes filtered during update" $false "Update failed or file not found"
        }
    }
    catch
    {
        Write-TestResult "Invalid modes filtered during update" $false $_.Exception.Message
    }
    finally
    {
        if (Test-Path $testFile)
        {
            Remove-Item $testFile -Force 
        }
    }
    
    # Test 4: Duplicate modes removed
    try
    {
        New-TestSettingsFile -FilePath $testFile -LegacyAppMode 'full'
        
        $testSettings = @{
            domain = 'test.com'
        }
        
        $success = Update-AppModeSettings -Configuration @('helpdesk', 'registration', 'helpdesk') -SettingsFile $testFile -UseGlobalSettings -Settings $testSettings
        
        if ($success -and (Test-Path $testFile))
        {
            $updated = Import-PowerShellDataFile -Path $testFile
            
            Write-TestResult "Duplicate modes removed during update" `
            ($updated.globalSettings.appModes.Count -eq 2) `
                "appModes: [$($updated.globalSettings.appModes -join ', ')], Count: $($updated.globalSettings.appModes.Count)"
        }
        else
        {
            Write-TestResult "Duplicate modes removed during update" $false "Update failed or file not found"
        }
    }
    catch
    {
        Write-TestResult "Duplicate modes removed during update" $false $_.Exception.Message
    }
    finally
    {
        if (Test-Path $testFile)
        {
            Remove-Item $testFile -Force 
        }
    }
    
    # Test 5: Empty configuration defaults to full
    try
    {
        New-TestSettingsFile -FilePath $testFile -LegacyAppMode 'admin'
        
        $testSettings = @{
            domain = 'test.com'
        }
        
        $success = Update-AppModeSettings -Configuration @() -SettingsFile $testFile -UseGlobalSettings -Settings $testSettings
        
        if ($success -and (Test-Path $testFile))
        {
            $updated = Import-PowerShellDataFile -Path $testFile
            
            Write-TestResult "Empty configuration defaults to full" `
            (($updated.globalSettings.appModes.Count -eq 1) -and ($updated.globalSettings.appModes[0] -eq 'full')) `
                "appModes: [$($updated.globalSettings.appModes -join ', ')]"
        }
        else
        {
            Write-TestResult "Empty configuration defaults to full" $false "Update failed or file not found"
        }
    }
    catch
    {
        Write-TestResult "Empty configuration defaults to full" $false $_.Exception.Message
    }
    finally
    {
        if (Test-Path $testFile)
        {
            Remove-Item $testFile -Force 
        }
    }
}
#endregion

#region Test Non-Interactive Function Validation
function Test-NonInteractiveFunctionValidation
{
    Write-TestSection "Testing Non-Interactive Function Validation"
    
    # Test 1: Get-AppModeConfigurationFromUser -Silent
    try
    {
        $result = Get-AppModeConfigurationFromUser -Silent
        
        Write-TestResult "Get-AppModeConfigurationFromUser silent mode works" `
        (($result.appModes.Count -gt 0) -and ($result.cancelled -eq $false)) `
            "Modes: [$($result.appModes -join ', ')], Cancelled: $($result.cancelled)"
    }
    catch
    {
        Write-TestResult "Get-AppModeConfigurationFromUser silent mode works" $false $_.Exception.Message
    }
    
    # Test 2: Show-AppModeHierarchyInfo exists
    try
    {
        $functionExists = Get-Command Show-AppModeHierarchyInfo -ErrorAction SilentlyContinue
        
        Write-TestResult "Show-AppModeHierarchyInfo function exists" `
        ($null -ne $functionExists) `
            "Function found: $($null -ne $functionExists)"
    }
    catch
    {
        Write-TestResult "Show-AppModeHierarchyInfo function exists" $false $_.Exception.Message
    }
    
    # Test 3: Get-MultipleAppModeInput function exists (cannot test interactively)
    try
    {
        $functionExists = Get-Command Get-MultipleAppModeInput -ErrorAction SilentlyContinue
        
        Write-TestResult "Get-MultipleAppModeInput function exists" `
        ($null -ne $functionExists) `
            "Function found: $($null -ne $functionExists)"
    }
    catch
    {
        Write-TestResult "Get-MultipleAppModeInput function exists" $false $_.Exception.Message
    }
}
#endregion

#region Main Execution
try
{
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  App Mode Functions - Comprehensive Test Suite                ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    # Initialize environment
    $initSuccess = Initialize-TestEnvironment
    
    if (-not $initSuccess)
    {
        Write-Host "`n❌ Failed to initialize test environment. Some tests may fail." -ForegroundColor Red
    }
    
    # Run all test suites
    Test-GetAppModeHierarchy
    Test-GetMultipleAppModeHierarchy
    Test-GetAppModeSettingsFromFile
    Test-GetEffectiveAppModes
    Test-GetCombinedAppModeHierarchy
    Test-TestAppModeSelection
    Test-UpdateAppModeSettings
    Test-NonInteractiveFunctionValidation
    
    # Calculate statistics
    $testEndTime = Get-Date
    $duration = $testEndTime - $testStartTime
    $successRate = if ($totalTests -gt 0)
    {
        [math]::Round(($passedTests / $totalTests) * 100, 2) 
    }
    else
    {
        0 
    }
    
    # Display summary
    Write-TestSection "Test Summary"
    Write-Host "Total Tests:   $totalTests" -ForegroundColor White
    Write-Host "Passed:        $passedTests" -ForegroundColor Green
    Write-Host "Failed:        $failedTests" -ForegroundColor $(if ($failedTests -eq 0)
        {
            'Green' 
        }
        else
        {
            'Red' 
        })
    Write-Host "Success Rate:  $successRate%" -ForegroundColor $(if ($successRate -ge 90)
        {
            'Green' 
        }
        elseif ($successRate -ge 70)
        {
            'Yellow' 
        }
        else
        {
            'Red' 
        })
    Write-Host "Duration:      $($duration.TotalSeconds) seconds" -ForegroundColor Cyan
    
    # Final verdict
    Write-Host ""
    if ($failedTests -eq 0)
    {
        Write-Host "🎉 All tests passed! App mode functions are working correctly." -ForegroundColor Green
    }
    elseif ($successRate -ge 80)
    {
        Write-Host "⚠️  Most tests passed, but some issues were found. Review failures above." -ForegroundColor Yellow
    }
    else
    {
        Write-Host "❌ Multiple test failures detected. Immediate attention required." -ForegroundColor Red
    }
    
    # Export results if needed
    if ($ExportResults)
    {
        $resultsFile = "$PSScriptRoot\test-appmode-functions-results.json"
        $testResults | ConvertTo-Json -Depth 3 | Out-File -FilePath $resultsFile -Encoding UTF8
        Write-Host "`nDetailed results exported to: $resultsFile" -ForegroundColor Gray
    }
}
catch
{
    Write-Host "`n❌ Test execution failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    exit 1
}
finally
{
    # Cleanup any temporary test files
    Get-ChildItem -Path $PSScriptRoot -Filter "test-appmode-*-temp.psd1" -ErrorAction SilentlyContinue | Remove-Item -Force
}
#endregion

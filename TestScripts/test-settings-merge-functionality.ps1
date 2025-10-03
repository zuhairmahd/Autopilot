# Test script for settings merge functionality
# PowerShell 5.1 compatible test

param(
    [string]$TestFolder = "$env:TEMP\AutopilotSettingsTest"
)

Write-Host "Testing Settings Merge Functionality" -ForegroundColor Cyan
Write-Host "Test folder: $TestFolder" -ForegroundColor Yellow

# Clean up any existing test folder
if (Test-Path $TestFolder)
{
    Remove-Item -Path $TestFolder -Recurse -Force
}

# Create test folder
New-Item -Path $TestFolder -ItemType Directory -Force | Out-Null

# Load all functions
$rootPath = Split-Path -Parent $PSScriptRoot
Write-Host "Loading functions from: $rootPath" -ForegroundColor Yellow

# Load required functions
$functionsPath = Join-Path $rootPath "functions"
$setupFunctionsPath = Join-Path $functionsPath "setupFunctions"

# Key functions to load
$requiredFunctions = @(
    "$setupFunctionsPath\Get-ApplicationDefaults.ps1",
    "$setupFunctionsPath\FirstRunWizardFunctions\Merge-ConfigurationDefaults.ps1",
    "$setupFunctionsPath\Merge-SettingsWithDefaults.ps1"
)

$loadedCount = 0
foreach ($funcFile in $requiredFunctions)
{
    if (Test-Path $funcFile)
    {
        try
        {
            . $funcFile
            $loadedCount++
            Write-Host "✓ Loaded: $(Split-Path -Leaf $funcFile)" -ForegroundColor Green
        }
        catch
        {
            Write-Host "✗ Failed to load: $(Split-Path -Leaf $funcFile) - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    else
    {
        Write-Host "✗ Not found: $(Split-Path -Leaf $funcFile)" -ForegroundColor Red
    }
}

Write-Host "`nLoaded $loadedCount of $($requiredFunctions.Count) required functions" -ForegroundColor Cyan

# Test 1: Test Merge-SettingsWithDefaults function availability
Write-Host "`n1. Testing function availability..." -ForegroundColor Cyan
$mergeFunc = Get-Command "Merge-SettingsWithDefaults" -ErrorAction SilentlyContinue
if ($mergeFunc)
{
    Write-Host "✓ Merge-SettingsWithDefaults function is available" -ForegroundColor Green
}
else
{
    Write-Host "✗ Merge-SettingsWithDefaults function not available" -ForegroundColor Red
}

$defaultsFunc = Get-Command "Get-ApplicationDefaults" -ErrorAction SilentlyContinue
if ($defaultsFunc)
{
    Write-Host "✓ Get-ApplicationDefaults function is available" -ForegroundColor Green
}
else
{
    Write-Host "✗ Get-ApplicationDefaults function not available" -ForegroundColor Red
}

# Test 2: Test getting default settings
Write-Host "`n2. Testing default settings retrieval..." -ForegroundColor Cyan
try
{
    $globalDefaults = Get-ApplicationDefaults -DefaultType "Global"
    if ($globalDefaults -and $globalDefaults.Keys.Count -gt 0)
    {
        Write-Host "✓ Retrieved $($globalDefaults.Keys.Count) global default settings" -ForegroundColor Green
        Write-Host "  Sample keys: $($globalDefaults.Keys | Select-Object -First 5 | ConvertTo-Json -Compress)" -ForegroundColor Gray
    }
    else
    {
        Write-Host "✗ Failed to get global defaults or empty result" -ForegroundColor Red
    }
}
catch
{
    Write-Host "✗ Error getting global defaults: $($_.Exception.Message)" -ForegroundColor Red
}

try
{
    $domainDefaults = Get-ApplicationDefaults -DefaultType "Domain" -DomainName "test.com"
    if ($domainDefaults -and $domainDefaults.Keys.Count -gt 0)
    {
        Write-Host "✓ Retrieved $($domainDefaults.Keys.Count) domain default settings" -ForegroundColor Green
        Write-Host "  Sample keys: $($domainDefaults.Keys | Select-Object -First 5 | ConvertTo-Json -Compress)" -ForegroundColor Gray
    }
    else
    {
        Write-Host "✗ Failed to get domain defaults or empty result" -ForegroundColor Red
    }
}
catch
{
    Write-Host "✗ Error getting domain defaults: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Test merging with incomplete settings
Write-Host "`n3. Testing settings merge functionality..." -ForegroundColor Cyan

# Create incomplete global settings (missing some keys)
$incompleteGlobalSettings = @{
    appMode    = "full"
    autoUpdate = $true
    # Missing other keys that should be in defaults
}

Write-Host "Created incomplete global settings with $($incompleteGlobalSettings.Keys.Count) keys" -ForegroundColor Gray

if ($mergeFunc -and $defaultsFunc)
{
    try
    {
        $mergedGlobal = Merge-SettingsWithDefaults -ExistingSettings $incompleteGlobalSettings -SettingType "Global" -BoundParameters @{}
        if ($mergedGlobal)
        {
            Write-Host "✓ Successfully merged global settings - result has $($mergedGlobal.Keys.Count) keys" -ForegroundColor Green
            
            # Check that original values were preserved
            if ($mergedGlobal.appMode -eq "full" -and $mergedGlobal.autoUpdate -eq $true)
            {
                Write-Host "✓ Original values preserved during merge" -ForegroundColor Green
            }
            else
            {
                Write-Host "✗ Original values not preserved during merge" -ForegroundColor Red
            }
        }
        else
        {
            Write-Host "? No merge needed - all defaults already present" -ForegroundColor Yellow
        }
    }
    catch
    {
        Write-Host "✗ Error during global settings merge: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test domain settings merge
    $incompleteDomainSettings = @{
        domain          = "test.com"
        groupsToInclude = @("Test-Group")
        # Missing other keys that should be in defaults
    }
    
    Write-Host "Created incomplete domain settings with $($incompleteDomainSettings.Keys.Count) keys" -ForegroundColor Gray
    
    try
    {
        $mergedDomain = Merge-SettingsWithDefaults -ExistingSettings $incompleteDomainSettings -SettingType "Local" -Domain "test.com" -BoundParameters @{}
        if ($mergedDomain)
        {
            Write-Host "✓ Successfully merged domain settings - result has $($mergedDomain.Keys.Count) keys" -ForegroundColor Green
            
            # Check that original values were preserved
            if ($mergedDomain.domain -eq "test.com" -and $mergedDomain.groupsToInclude.Count -eq 1)
            {
                Write-Host "✓ Original domain values preserved during merge" -ForegroundColor Green
            }
            else
            {
                Write-Host "✗ Original domain values not preserved during merge" -ForegroundColor Red
            }
        }
        else
        {
            Write-Host "? No domain merge needed - all defaults already present" -ForegroundColor Yellow
        }
    }
    catch
    {
        Write-Host "✗ Error during domain settings merge: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else
{
    Write-Host "⚠ Skipping merge tests - required functions not available" -ForegroundColor Yellow
}

# Test 4: Test command-line override filtering
Write-Host "`n4. Testing command-line override filtering..." -ForegroundColor Cyan

if ($mergeFunc)
{
    $settingsWithOverrides = @{
        appMode = "helpdesk"  # This should be preserved
    }
    
    $boundParams = @{
        appMode = "helpdesk"  # This is a command-line override
    }
    
    try
    {
        $mergedWithOverrides = Merge-SettingsWithDefaults -ExistingSettings $settingsWithOverrides -SettingType "Global" -BoundParameters $boundParams
        if ($mergedWithOverrides)
        {
            # Check that appMode wasn't changed from default due to override
            if ($mergedWithOverrides.appMode -eq "helpdesk")
            {
                Write-Host "✓ Command-line override preserved correctly" -ForegroundColor Green
            }
            else
            {
                Write-Host "✗ Command-line override not preserved" -ForegroundColor Red
            }
        }
        else
        {
            Write-Host "? No merge with overrides - test inconclusive" -ForegroundColor Yellow
        }
    }
    catch
    {
        Write-Host "✗ Error testing command-line overrides: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else
{
    Write-Host "⚠ Skipping override tests - merge function not available" -ForegroundColor Yellow
}

Write-Host "`n✓ Settings merge functionality test completed" -ForegroundColor Cyan
Write-Host "Check the results above for any issues." -ForegroundColor Gray

# Cleanup
Remove-Item -Path $TestFolder -Recurse -Force -ErrorAction SilentlyContinue
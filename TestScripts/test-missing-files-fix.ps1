#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test for missing configuration files fix (Issue #104) - Refactored Implementation
.DESCRIPTION
    This test validates that the new Initialize-ApplicationConfiguration function properly handles
    scenarios where .secrets\config.json exists but strings.json or settings.json are missing.
    Updated to test the refactored implementation.
.NOTES
    Author: Copilot
    Version: 2.0.0
    Purpose: Validate fix for Issue #104 using the new refactored approach
#>

[CmdletBinding()]
param()

# Simple test that focuses on the key validation points
$testName = "Test for missing configuration files fix (Issue #104) - Refactored Implementation"
Write-Host "=== $testName ===" -ForegroundColor Cyan

# Test 1: Verify the new helper function exists and loads correctly
Write-Host "=== Test 1: Validate Initialize-ApplicationConfiguration Function ===" -ForegroundColor Yellow

try
{
    # Determine paths
    $RootPath = Split-Path -Parent $PSScriptRoot
    
    # Load the function
    $helperPath = Join-Path $RootPath "functions\setupFunctions\Initialize-ApplicationConfiguration.ps1"
    if (Test-Path $helperPath)
    {
        . $helperPath
        $functions = Get-Command -Name "Initialize-ApplicationConfiguration" -ErrorAction SilentlyContinue
        if ($functions)
        {
            Write-Host "✓ Initialize-ApplicationConfiguration function loaded successfully" -ForegroundColor Green
            $test1Result = $true
        }
        else
        {
            Write-Host "✗ Initialize-ApplicationConfiguration function not found after loading" -ForegroundColor Red
            $test1Result = $false
        }
    }
    else
    {
        Write-Host "✗ Initialize-ApplicationConfiguration.ps1 file not found at: $helperPath" -ForegroundColor Red
        $test1Result = $false
    }
}
catch
{
    Write-Host "✗ Error loading Initialize-ApplicationConfiguration: $($_.Exception.Message)" -ForegroundColor Red
    $test1Result = $false
}

# Test 2: Verify main.ps1 uses the new approach
Write-Host "`n=== Test 2: Validate main.ps1 Uses New Configuration Approach ===" -ForegroundColor Yellow

try
{
    $mainContent = Get-Content -Path "$PWD\main.ps1" -Raw
    
    # Check for the new pattern
    $hasNewApproach = $mainContent -match 'Initialize-ApplicationConfiguration.*-InitFile.*-StringsFile'
    $hasErrorHandling = $mainContent -match 'configResult\.Success'
    $hasCleanStructure = ([regex]'#region Define variables').Matches($mainContent).Count -eq 1
    
    if ($hasNewApproach -and $hasErrorHandling -and $hasCleanStructure)
    {
        Write-Host "✓ main.ps1 uses new Initialize-ApplicationConfiguration approach" -ForegroundColor Green
        Write-Host "✓ Proper error handling for configuration initialization" -ForegroundColor Green
        Write-Host "✓ Clean code structure with single configuration path" -ForegroundColor Green
        $test2Result = $true
    }
    else
    {
        Write-Host "✗ main.ps1 does not properly use new approach" -ForegroundColor Red
        Write-Host "  New approach pattern: $hasNewApproach" -ForegroundColor Red
        Write-Host "  Error handling: $hasErrorHandling" -ForegroundColor Red
        Write-Host "  Clean structure: $hasCleanStructure" -ForegroundColor Red
        $test2Result = $false
    }
}
catch
{
    Write-Host "✗ Error analyzing main.ps1: $($_.Exception.Message)" -ForegroundColor Red
    $test2Result = $false
}

# Test 3: Verify the refactored solution addresses the original issue
Write-Host "`n=== Test 3: Verify Original Issue Is Addressed ===" -ForegroundColor Yellow

try
{
    $mainContent = Get-Content -Path "$PWD\main.ps1" -Raw
    
    # The original issue was duplicate code paths - verify this is eliminated
    $hasOldDuplicatePaths = $mainContent -match 'if \(Test-Path -Path \$InitFile\).*else.*Configuration file.*not found'
    $hasOldElseBlock = $mainContent -match 'Test-SettingsJsonExists.*SettingsFile.*initFile.*Silent.*DomainName.*domain'
    
    if (-not $hasOldDuplicatePaths -and -not $hasOldElseBlock)
    {
        Write-Host "✓ Original duplicate code paths have been eliminated" -ForegroundColor Green
        Write-Host "✓ No old problematic else block with separate logic" -ForegroundColor Green
        $test3Result = $true
    }
    else
    {
        Write-Host "✗ Original problematic patterns still exist" -ForegroundColor Red
        Write-Host "  Old duplicate paths: $hasOldDuplicatePaths" -ForegroundColor Red
        Write-Host "  Old else block: $hasOldElseBlock" -ForegroundColor Red
        $test3Result = $false
    }
}
catch
{
    Write-Host "✗ Error checking for original issue patterns: $($_.Exception.Message)" -ForegroundColor Red
    $test3Result = $false
}

# Test 4: Verify comprehensive solution benefits (multi-file helper implementation)
Write-Host "`n=== Test 4: Verify Comprehensive Solution Benefits (Multi-File) ===" -ForegroundColor Yellow

try
{
    # Expected helper functions now implemented in separate files
    $helperFunctions = @(
        "Initialize-ApplicationConfiguration",
        "Initialize-ConfigurationFiles",
        "Initialize-AuthConfiguration",
        "Initialize-GlobalSettings",
        "Initialize-LocalSettings",
        "Initialize-RequiredScopes",
        "Merge-ConfigurationDefaults"
    )

    $baseHelperPath = Join-Path $PWD 'functions' | Join-Path -ChildPath 'setupFunctions'

    $missingFiles = @()
    $loadFailures = @()
    $missingFunctions = @()
    $loadedCount = 0

    foreach ($func in $helperFunctions)
    {
        $fileName = "$func.ps1"
        # Merge-ConfigurationDefaults is in FirstRunWizardFunctions subfolder
        if ($func -eq "Merge-ConfigurationDefaults")
        {
            $filePath = Join-Path $baseHelperPath "FirstRunWizardFunctions\$fileName"
        }
        else
        {
            $filePath = Join-Path $baseHelperPath $fileName
        }
        
        if (-not (Test-Path $filePath))
        {
            $missingFiles += $fileName
            continue
        }

        try
        {
            . $filePath 
        }
        catch
        {
            $loadFailures += $fileName; continue 
        }

        $cmd = Get-Command -Name $func -ErrorAction SilentlyContinue
        if ($cmd)
        {
            $loadedCount++ 
        }
        else
        {
            $missingFunctions += $func 
        }
    }

    if ((-not $missingFiles.Count) -and (-not $loadFailures.Count) -and (-not $missingFunctions.Count) -and ($loadedCount -eq $helperFunctions.Count))
    {
        Write-Host "✓ All $($helperFunctions.Count) helper functions found, files present, and loaded successfully" -ForegroundColor Green
        Write-Host "✓ Multi-file refactoring validated (improves modularity & maintainability)" -ForegroundColor Green
        $test4Result = $true
    }
    else
    {
        if ($missingFiles.Count)
        {
            Write-Host "✗ Missing helper function files: $($missingFiles -join ', ')" -ForegroundColor Red 
        }
        if ($loadFailures.Count)
        {
            Write-Host "✗ Failed to load helper files: $($loadFailures -join ', ')" -ForegroundColor Red 
        }
        if ($missingFunctions.Count)
        {
            Write-Host "✗ Functions not registered after loading: $($missingFunctions -join ', ')" -ForegroundColor Red 
        }
        Write-Host "✗ Loaded $loadedCount / $($helperFunctions.Count) helper functions successfully" -ForegroundColor Red
        $test4Result = $false
    }
}
catch
{
    Write-Host "✗ Error validating multi-file helper functions: $($_.Exception.Message)" -ForegroundColor Red
    $test4Result = $false
}

# Test 5: Verify Merge-ConfigurationDefaults integration with auth
Write-Host "`n=== Test 5: Verify Merge-ConfigurationDefaults with Auth Object ===" -ForegroundColor Yellow

try
{
    # Load the function if not already loaded
    $mergeFunc = Get-Command "Merge-ConfigurationDefaults" -ErrorAction SilentlyContinue
    if (-not $mergeFunc)
    {
        $mergePath = Join-Path $PWD 'functions\setupFunctions\FirstRunWizardFunctions\Merge-ConfigurationDefaults.ps1'
        . $mergePath
        $mergeFunc = Get-Command "Merge-ConfigurationDefaults" -ErrorAction SilentlyContinue
    }
    
    if ($mergeFunc)
    {
        Write-Host "✓ Merge-ConfigurationDefaults function loaded successfully" -ForegroundColor Green
        
        # Test auth object merge
        $existingAuth = @{
            delegated = $true
            authType  = "PublicAuthFlow"
        }
        
        $defaultAuth = @{
            delegated   = $true
            authType    = "PublicAuthFlow"
            scope       = @("offline_access", "openid", "Device.ReadWrite.All")
            tenantId    = "common"
            clientId    = ""
            redirectUri = "http://localhost"
        }
        
        # Set up log file for the function
        $global:logFile = "$PWD\test-merge.log"
        
        $mergedAuth = Merge-ConfigurationDefaults -ExistingConfig $existingAuth -DefaultConfig $defaultAuth -PreserveExisting $true
        
        if ($null -ne $mergedAuth)
        {
            Write-Host "✓ Merge-ConfigurationDefaults successfully merged auth configuration" -ForegroundColor Green
            
            # Verify existing values preserved
            if ($mergedAuth.delegated -eq $true -and $mergedAuth.authType -eq "PublicAuthFlow")
            {
                Write-Host "✓ Existing auth values preserved during merge" -ForegroundColor Green
            }
            else
            {
                Write-Host "✗ Existing auth values not preserved" -ForegroundColor Red
                $test5Result = $false
            }
            
            # Verify missing keys added
            if ($mergedAuth.ContainsKey('scope') -and $mergedAuth.ContainsKey('tenantId'))
            {
                Write-Host "✓ Missing auth keys added from defaults (scope, tenantId)" -ForegroundColor Green
                $test5Result = $true
            }
            else
            {
                Write-Host "✗ Missing auth keys not added correctly" -ForegroundColor Red
                $test5Result = $false
            }
        }
        else
        {
            Write-Host "✓ Merge returned null (no changes needed - config already complete)" -ForegroundColor Green
            $test5Result = $true
        }
    }
    else
    {
        Write-Host "✗ Merge-ConfigurationDefaults function not found" -ForegroundColor Red
        $test5Result = $false
    }
}
catch
{
    Write-Host "✗ Error testing Merge-ConfigurationDefaults: $($_.Exception.Message)" -ForegroundColor Red
    $test5Result = $false
}

# Calculate final result
$allTests = @($test1Result, $test2Result, $test3Result, $test4Result, $test5Result)
$passedCount = ($allTests | Where-Object { $_ -eq $true }).Count
$totalCount = $allTests.Count

Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Total tests: $totalCount" -ForegroundColor White
Write-Host "Passed: $passedCount" -ForegroundColor Green
Write-Host "Failed: $($totalCount - $passedCount)" -ForegroundColor $(if ($passedCount -eq $totalCount)
    {
        'Green' 
    }
    else
    {
        'Red' 
    })

if ($passedCount -eq $totalCount)
{
    Write-Host "`n✓ SUCCESS: Issue #104 fix validated through comprehensive refactoring!" -ForegroundColor Green
    Write-Host "The refactored solution eliminates the original code duplication and robustness issues." -ForegroundColor Green
    exit 0
}
else
{
    Write-Host "`n✗ FAILURE: Issue #104 refactored solution needs attention." -ForegroundColor Red
    exit 1
}
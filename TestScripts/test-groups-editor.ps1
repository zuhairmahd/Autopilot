#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Test script for the Show-GroupsEditor function.

.DESCRIPTION
    Tests the groups editor functionality including function loading,
    domain detection, and basic editing operations.
#>

# Import required functions
$scriptRoot = Split-Path -Parent $PSCommandPath
$functionsPath = Join-Path $scriptRoot "../functions"

# Load all functions recursively
Write-Host "Loading functions..." -ForegroundColor Cyan
$functionFiles = Get-ChildItem -Path $functionsPath -Filter "*.ps1" -Recurse
foreach ($file in $functionFiles) {
    try {
        . $file.FullName
        Write-Verbose "Loaded: $($file.Name)"
    }
    catch {
        Write-Warning "Failed to load $($file.Name): $($_.Exception.Message)"
    }
}

# Set global variables that the functions expect
$global:maxJSONDepth = 10
$global:logFile = "test.log"

# Test 1: Function exists and can be called
Write-Host "`n=== Test 1: Function Availability ===" -ForegroundColor Yellow
try {
    $functionExists = Get-Command Show-GroupsEditor -ErrorAction SilentlyContinue
    if ($functionExists) {
        Write-Host "✓ Show-GroupsEditor function is available" -ForegroundColor Green
    } else {
        Write-Host "✗ Show-GroupsEditor function not found" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "✗ Error checking function availability: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 2: Test helper functions
Write-Host "`n=== Test 2: Helper Functions ===" -ForegroundColor Yellow
try {
    $helperFunctions = @('Get-GroupArrayInput', 'Compare-ArrayContents', 'Update-DomainGroupSetting')
    foreach ($funcName in $helperFunctions) {
        $func = Get-Command $funcName -ErrorAction SilentlyContinue
        if ($func) {
            Write-Host "✓ $funcName function is available" -ForegroundColor Green
        } else {
            Write-Host "✗ $funcName function not found" -ForegroundColor Red
        }
    }
}
catch {
    Write-Host "✗ Error checking helper functions: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 3: Array comparison function
Write-Host "`n=== Test 3: Array Comparison Logic ===" -ForegroundColor Yellow
try {
    # Test empty arrays
    $result1 = Compare-ArrayContents -Array1 @() -Array2 @()
    if ($result1 -eq $false) {
        Write-Host "✓ Empty arrays comparison works correctly (no change)" -ForegroundColor Green
    } else {
        Write-Host "✗ Empty arrays comparison failed" -ForegroundColor Red
    }
    
    # Test different arrays
    $result2 = Compare-ArrayContents -Array1 @("group1", "group2") -Array2 @("group1", "group3")
    if ($result2 -eq $true) {
        Write-Host "✓ Different arrays comparison works correctly (change detected)" -ForegroundColor Green
    } else {
        Write-Host "✗ Different arrays comparison failed" -ForegroundColor Red
    }
    
    # Test same arrays
    $result3 = Compare-ArrayContents -Array1 @("group1", "group2") -Array2 @("group1", "group2")
    if ($result3 -eq $false) {
        Write-Host "✓ Same arrays comparison works correctly (no change)" -ForegroundColor Green
    } else {
        Write-Host "✗ Same arrays comparison failed" -ForegroundColor Red
    }
}
catch {
    Write-Host "✗ Error testing array comparison: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Settings file validation
Write-Host "`n=== Test 4: Settings File Validation ===" -ForegroundColor Yellow
$settingsFile = Join-Path $scriptRoot "../settings.json"
if (Test-Path $settingsFile) {
    Write-Host "✓ Settings file exists: $settingsFile" -ForegroundColor Green
    
    try {
        $settings = Get-Content $settingsFile -Raw | ConvertFrom-Json
        if ($settings.domains) {
            Write-Host "✓ Settings file has domains section" -ForegroundColor Green
            
            $domainNames = $settings.domains.PSObject.Properties.Name
            Write-Host "   Available domains: $($domainNames -join ', ')" -ForegroundColor Cyan
            
            # Check first domain for group properties
            if ($domainNames.Count -gt 0) {
                $firstDomain = $domainNames[0]
                $domain = $settings.domains.$firstDomain
                
                $hasInclude = $domain.PSObject.Properties.Name -contains 'groupsToInclude'
                $hasExclude = $domain.PSObject.Properties.Name -contains 'groupsToExclude'
                
                if ($hasInclude) {
                    Write-Host "✓ Domain has groupsToInclude property" -ForegroundColor Green
                } else {
                    Write-Host "✗ Domain missing groupsToInclude property" -ForegroundColor Red
                }
                
                if ($hasExclude) {
                    Write-Host "✓ Domain has groupsToExclude property" -ForegroundColor Green
                } else {
                    Write-Host "✗ Domain missing groupsToExclude property" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "✗ Settings file missing domains section" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "✗ Error parsing settings file: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "✗ Settings file not found: $settingsFile" -ForegroundColor Red
}

# Test 5: Menu integration check
Write-Host "`n=== Test 5: Menu Integration Check ===" -ForegroundColor Yellow
$mainFile = Join-Path $scriptRoot "../main.ps1"
if (Test-Path $mainFile) {
    $mainContent = Get-Content $mainFile -Raw
    if ($mainContent -match "Show-GroupsEditor") {
        Write-Host "✓ Groups editor is integrated into main.ps1" -ForegroundColor Green
    } else {
        Write-Host "✗ Groups editor not found in main.ps1" -ForegroundColor Red
    }
    
    if ($mainContent -match "Edit group inclusion/exclusion settings") {
        Write-Host "✓ Menu item for groups editor found" -ForegroundColor Green
    } else {
        Write-Host "✗ Menu item for groups editor not found" -ForegroundColor Red
    }
} else {
    Write-Host "✗ Main file not found: $mainFile" -ForegroundColor Red
}

Write-Host "`n=== Groups Editor Tests Complete ===" -ForegroundColor Cyan
Write-Host "All basic functionality tests completed." -ForegroundColor White
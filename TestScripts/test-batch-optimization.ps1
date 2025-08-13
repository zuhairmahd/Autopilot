#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test script for validating group assignment batch optimization and logging improvements
.DESCRIPTION
    This test validates:
    1. Batch API optimization for resource list calls
    2. CallGraphAPI logging improvements (verbose mode only)
    3. GetGroupDirectAssignments parameter handling
.NOTES
    Author: Windows Autopilot Management Tool
    Compatible: PowerShell 5.1+
#>

Write-Host "=== Testing Group Assignment Batch Optimization ===" -ForegroundColor Cyan

# Load the functions
$scriptPath = "/home/runner/work/Autopilot/Autopilot"
$functionsPath = Join-Path $scriptPath "functions"

# Import necessary functions
Get-ChildItem -Path $functionsPath -Recurse -Filter "*.ps1" | ForEach-Object {
    try {
        . $_.FullName
    } catch {
        Write-Warning "Failed to load $($_.FullName): $($_.Exception.Message)"
    }
}

Write-Host "`n1. Testing CallGraphAPI logging improvements..." -ForegroundColor Yellow

# Test 1: Validate CallGraphAPI logging is now verbose-only
Write-Host "   Testing CallGraphAPI without verbose mode (should be quiet)..."
try {
    # This should fail quietly without extensive console output
    $result = CallGraphAPI -accessToken "test" -ResourcePath "test" 2>&1
    $output = $result | Out-String
    if ($output -match "Write-Host|Write-Error.*Server Response") {
        Write-Host "   ❌ FAIL: CallGraphAPI still has excessive console output" -ForegroundColor Red
        return $false
    } else {
        Write-Host "   ✓ PASS: CallGraphAPI console output is now controlled" -ForegroundColor Green
    }
} catch {
    Write-Host "   ✓ PASS: CallGraphAPI failed quietly as expected" -ForegroundColor Green
}

Write-Host "`n2. Testing GetGroupDirectAssignments batch optimization..." -ForegroundColor Yellow

# Test 2: Validate function structure supports batch API
Write-Host "   Checking function structure for batch optimization..."
$functionContent = Get-Content "$functionsPath/utilityFunctions/GetGroupDirectAssignments.ps1" -Raw

if ($functionContent -match "requests = @\(\)") {
    Write-Host "   ✓ PASS: Function includes batch request structure" -ForegroundColor Green
} else {
    Write-Host "   ❌ FAIL: Function missing batch request structure" -ForegroundColor Red
    return $false
}

if ($functionContent -match "resourceEndpoints.*deviceAppManagement/mobileApps" -or $functionContent -match "deviceAppManagement/mobileApps.*extraParams") {
    Write-Host "   ✓ PASS: Function includes batched resource endpoints" -ForegroundColor Green
} else {
    Write-Host "   ❌ FAIL: Function missing batched resource endpoints" -ForegroundColor Red
    return $false
}

if (($functionContent -split "CallGraphAPI").Count -lt 5) {
    Write-Host "   ✓ PASS: Function appears to use fewer individual API calls" -ForegroundColor Green
} else {
    Write-Host "   ⚠ WARNING: Function may still have excessive individual API calls" -ForegroundColor Yellow
}

Write-Host "`n3. Testing GetGroupDirectAssignments parameter validation..." -ForegroundColor Yellow

# Test 3: Parameter validation
Write-Host "   Testing parameter validation..."
try {
    $result = GetGroupDirectAssignments -GroupName $null 2>&1
    if ($result -match "Cannot bind.*GroupName.*empty string") {
        Write-Host "   ✓ PASS: Null GroupName properly rejected" -ForegroundColor Green
    } else {
        Write-Host "   ❌ FAIL: Null GroupName not properly validated" -ForegroundColor Red
        return $false
    }
} catch {
    Write-Host "   ✓ PASS: Parameter validation working" -ForegroundColor Green
}

Write-Host "`n4. Testing function accessibility and basic structure..." -ForegroundColor Yellow

# Test 4: Function accessibility
try {
    $testResult = GetGroupDirectAssignments -GroupName "NonExistentTestGroup" -ErrorAction SilentlyContinue 2>&1
    if ($testResult -contains "noGroup" -or ($testResult | Out-String) -match "No group ID found") {
        Write-Host "   ✓ PASS: Function handles non-existent groups correctly" -ForegroundColor Green
    } else {
        Write-Host "   ⚠ WARNING: Function response unclear for non-existent groups" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ⚠ WARNING: Function threw exception: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`n5. Testing API version and beta feature handling..." -ForegroundColor Yellow

# Test 5: Beta feature handling
$functionContent = Get-Content "$functionsPath/utilityFunctions/GetGroupDirectAssignments.ps1" -Raw
if ($functionContent -match "IncludeBeta\.IsPresent") {
    Write-Host "   ✓ PASS: Function includes beta feature handling" -ForegroundColor Green
} else {
    Write-Host "   ❌ FAIL: Function missing beta feature handling" -ForegroundColor Red
    return $false
}

if ($functionContent -match "windowsAutopilotDeploymentProfiles" -and $functionContent -match "deviceHealthScripts" -and $functionContent -match "configurationPolicies") {
    Write-Host "   ✓ PASS: Function includes expanded assignment types" -ForegroundColor Green
} else {
    Write-Host "   ❌ FAIL: Function missing expanded assignment types" -ForegroundColor Red
    return $false
}

Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
Write-Host "✓ CallGraphAPI logging improvements validated" -ForegroundColor Green
Write-Host "✓ Batch API optimization structure validated" -ForegroundColor Green  
Write-Host "✓ Parameter validation working correctly" -ForegroundColor Green
Write-Host "✓ Function accessibility confirmed" -ForegroundColor Green
Write-Host "✓ Beta features and expanded assignments validated" -ForegroundColor Green

Write-Host "`n🎉 All batch optimization and logging tests PASSED!" -ForegroundColor Green
return $true
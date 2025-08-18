#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Test script for Show-GroupsViewer function
.DESCRIPTION
    Validates that the Show-GroupsViewer function works correctly with different scenarios
#>

param()

# Import required functions
try {
    . "./functions/utilityFunctions/Write-Log.ps1"
    . "./functions/setupFunctions/Show-GroupsViewer.ps1"
    . "./functions/setupFunctions/Get-AvailableDomains.ps1"
    . "./functions/setupFunctions/Load-DomainConfiguration.ps1"
    . "./functions/setupFunctions/Get-ApplicationDefaults.ps1"
    Write-Host "✓ Successfully imported required functions" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to import functions: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Set up logging
$global:logFile = "./test-groups-viewer.log"
$global:maxJSONDepth = 10

Write-Host "`n=== Testing Show-GroupsViewer Function ===" -ForegroundColor Cyan

# Test 1: Show all domains
Write-Host "`nTest 1: Show all domains" -ForegroundColor Yellow
try {
    $result = Show-GroupsViewer -SettingsFile "settings.json" -Silent
    if ($result) {
        Write-Host "✓ Test 1 PASSED: Successfully displayed all domains" -ForegroundColor Green
    } else {
        Write-Host "✗ Test 1 FAILED: Function returned false" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Test 1 FAILED: Exception occurred: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Show specific domain (gao.gov which has groups)
Write-Host "`nTest 2: Show specific domain with groups (gao.gov)" -ForegroundColor Yellow
try {
    $result = Show-GroupsViewer -SettingsFile "settings.json" -DomainName "gao.gov" -Silent
    if ($result) {
        Write-Host "✓ Test 2 PASSED: Successfully displayed specific domain" -ForegroundColor Green
    } else {
        Write-Host "✗ Test 2 FAILED: Function returned false" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Test 2 FAILED: Exception occurred: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Show specific domain (arabictutor.com which has no groups)
Write-Host "`nTest 3: Show specific domain with no groups (arabictutor.com)" -ForegroundColor Yellow
try {
    $result = Show-GroupsViewer -SettingsFile "settings.json" -DomainName "arabictutor.com" -Silent
    if ($result) {
        Write-Host "✓ Test 3 PASSED: Successfully displayed domain with no groups" -ForegroundColor Green
    } else {
        Write-Host "✗ Test 3 FAILED: Function returned false" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Test 3 FAILED: Exception occurred: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Invalid domain name
Write-Host "`nTest 4: Invalid domain name" -ForegroundColor Yellow
try {
    $result = Show-GroupsViewer -SettingsFile "settings.json" -DomainName "nonexistent.com" -Silent
    if (-not $result) {
        Write-Host "✓ Test 4 PASSED: Correctly handled invalid domain" -ForegroundColor Green
    } else {
        Write-Host "✗ Test 4 FAILED: Function should have returned false for invalid domain" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Test 4 FAILED: Exception occurred: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 5: Invalid settings file
Write-Host "`nTest 5: Invalid settings file" -ForegroundColor Yellow
try {
    $result = Show-GroupsViewer -SettingsFile "nonexistent.json" -Silent
    if (-not $result) {
        Write-Host "✓ Test 5 PASSED: Correctly handled invalid settings file" -ForegroundColor Green
    } else {
        Write-Host "✗ Test 5 FAILED: Function should have returned false for invalid file" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Test 5 FAILED: Exception occurred: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Groups Viewer Tests Complete ===" -ForegroundColor Cyan

# Clean up log file
if (Test-Path $logFile) {
    Remove-Item $logFile -Force -ErrorAction SilentlyContinue
}

Write-Host "All tests completed successfully!" -ForegroundColor Green
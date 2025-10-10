#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Test script to verify the single group saving issue is fixed.

.DESCRIPTION
    Tests the Update-DomainGroupSetting function with single and multiple groups
    to ensure proper saving and verification.
#>

# Import required functions
$scriptRoot = Split-Path -Parent $PSCommandPath
$functionsPath = Join-Path $scriptRoot "../functions"

# Load all functions recursively
Write-Host "Loading functions..." -ForegroundColor Cyan
$functionFiles = Get-ChildItem -Path $functionsPath -Filter "*.ps1" -Recurse
foreach ($file in $functionFiles)
{
    try
    {
        . $file.FullName
        Write-Verbose "Loaded: $($file.Name)"
    }
    catch
    {
        Write-Warning "Failed to load $($file.Name): $($_.Exception.Message)"
    }
}

# Set global variables that the functions expect
$global:maxJSONDepth = 10
$global:logFile = Join-Path $scriptRoot "test-single-group.log"

# Create test directory and settings
$testDir = Join-Path $scriptRoot "temp-test-single-group"
$settingsFile = Join-Path $testDir "settings.json"
$domainName = "test-single-group.local"

try
{
    # Clean up and create test directory
    if (Test-Path $testDir)
    {
        Remove-Item $testDir -Recurse -Force
    }
    New-Item -Path $testDir -ItemType Directory -Force | Out-Null

    # Create minimal settings.json
    $settings = @{
        domains        = @{
            $domainName = @{
                settings = @{
                    domain = $domainName
                }
            }
        }
        globalSettings = @{}
    }
    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsFile

    Write-Host "`n=== Test 1: Single Group Saving ===" -ForegroundColor Yellow
    
    # Test single group
    $singleGroup = @(@{
            name = "Single Test Group"
            id   = "12345678-1234-1234-1234-123456789abc"
        })
    
    Write-Host "Testing single group save..." -ForegroundColor Cyan
    $result1 = Update-DomainGroupSetting -SettingsFile $settingsFile -DomainName $domainName -GroupType "groupsToInclude" -Groups $singleGroup
    
    if ($result1)
    {
        Write-Host "✓ Single group save succeeded" -ForegroundColor Green
    }
    else
    {
        Write-Host "✗ Single group save failed" -ForegroundColor Red
    }

    Write-Host "`n=== Test 2: Multiple Groups Saving ===" -ForegroundColor Yellow
    
    # Test multiple groups
    $multipleGroups = @(
        @{
            name = "Test Group 1"
            id   = "12345678-1234-1234-1234-123456789abc"
        },
        @{
            name = "Test Group 2"
            id   = "87654321-4321-4321-4321-abcdef123456"
        }
    )
    
    Write-Host "Testing multiple groups save..." -ForegroundColor Cyan
    $result2 = Update-DomainGroupSetting -SettingsFile $settingsFile -DomainName $domainName -GroupType "groupsToExclude" -Groups $multipleGroups
    
    if ($result2)
    {
        Write-Host "✓ Multiple groups save succeeded" -ForegroundColor Green
    }
    else
    {
        Write-Host "✗ Multiple groups save failed" -ForegroundColor Red
    }

    Write-Host "`n=== Test 3: Empty Groups Saving ===" -ForegroundColor Yellow
    
    # Test empty array
    $emptyGroups = @()
    
    Write-Host "Testing empty groups save..." -ForegroundColor Cyan
    $result3 = Update-DomainGroupSetting -SettingsFile $settingsFile -DomainName $domainName -GroupType "groupsToInclude" -Groups $emptyGroups
    
    if ($result3)
    {
        Write-Host "✓ Empty groups save succeeded" -ForegroundColor Green
    }
    else
    {
        Write-Host "✗ Empty groups save failed" -ForegroundColor Red
    }

    # Verify final configuration
    Write-Host "`n=== Final Configuration Verification ===" -ForegroundColor Yellow
    $finalConfig = Get-DomainConfigurationFromFiles -DomainName $domainName -ConfigurationPath $testDir
    
    Write-Host "Groups to Include: $($finalConfig.groupsToInclude.Count) groups" -ForegroundColor Cyan
    Write-Host "Groups to Exclude: $($finalConfig.groupsToExclude.Count) groups" -ForegroundColor Cyan
    
    if ($finalConfig.groupsToExclude.Count -eq 2)
    {
        Write-Host "✓ Multiple groups verification passed" -ForegroundColor Green
    }
    else
    {
        Write-Host "✗ Multiple groups verification failed" -ForegroundColor Red
    }

    # Overall result
    $allPassed = $result1 -and $result2 -and $result3
    Write-Host "`n=== Overall Result ===" -ForegroundColor Yellow
    if ($allPassed)
    {
        Write-Host "✓ All tests passed!" -ForegroundColor Green
    }
    else
    {
        Write-Host "✗ Some tests failed!" -ForegroundColor Red
    }

}
finally
{
    # Clean up
    if (Test-Path $testDir)
    {
        Remove-Item $testDir -Recurse -Force
    }
    # Clean up log file
    if (Test-Path $global:logFile)
    {
        Remove-Item $global:logFile -Force -ErrorAction SilentlyContinue
    }
}
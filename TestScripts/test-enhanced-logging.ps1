#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Test script to verify enhanced logging and count issue fixes.
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
$global:logFile = Join-Path $scriptRoot "test-count-logging.log"

# Test enhanced logging
Write-Host "`n=== Enhanced Logging Test ===" -ForegroundColor Yellow

# Create test directory and settings
$testDir = Join-Path $scriptRoot "temp-test-enhanced-logging"
$settingsFile = Join-Path $testDir "settings.json"
$domainName = "test-enhanced.local"

try {
    # Clean up and create test directory
    if (Test-Path $testDir) {
        Remove-Item $testDir -Recurse -Force
    }
    New-Item -Path $testDir -ItemType Directory -Force | Out-Null

    # Create minimal settings.json
    $settings = @{
        domains = @{
            $domainName = @{
                settings = @{
                    domain = $domainName
                }
            }
        }
        globalSettings = @{}
    }
    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsFile

    # Test single group with verbose logging
    $singleGroup = @(@{
        name = "Enhanced Test Group"
        id = "12345678-1234-1234-1234-123456789abc"
    })
    
    Write-Host "Testing Update-DomainGroupSetting with enhanced logging..." -ForegroundColor Cyan
    $result = Update-DomainGroupSetting -SettingsFile $settingsFile -DomainName $domainName -GroupType "groupsToExclude" -Groups $singleGroup
    
    if ($result) {
        Write-Host "✓ Enhanced logging test passed" -ForegroundColor Green
    } else {
        Write-Host "✗ Enhanced logging test failed" -ForegroundColor Red
    }

    # Check for existence of enhanced log entries
    if (Test-Path $global:logFile) {
        $logContent = Get-Content $global:logFile
        $enhancedEntries = $logContent | Where-Object { $_ -like "*SafeCount*" -or $_ -like "*Raw data*" -or $_ -like "*After array conversion*" }
        
        if ($enhancedEntries.Count -gt 0) {
            Write-Host "✓ Enhanced logging entries found: $($enhancedEntries.Count)" -ForegroundColor Green
        } else {
            Write-Host "✗ No enhanced logging entries found" -ForegroundColor Red
        }
    }

} finally {
    # Clean up
    if (Test-Path $testDir) {
        Remove-Item $testDir -Recurse -Force
    }
}

Write-Host "✓ Enhanced logging verification complete" -ForegroundColor Green
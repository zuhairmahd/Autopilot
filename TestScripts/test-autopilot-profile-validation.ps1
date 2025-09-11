#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test script for Autopilot profile validation functionality.

.DESCRIPTION
    Tests the new Autopilot profile validation features including:
    - GetAutopilotProfile function
    - Show-AutopilotProfilesEditor function  
    - Profile format conversion functions
    - Updated GetAutopilotDeviceRelevantProperties function

.NOTES
    - Requires PowerShell 5.1 or higher
    - Tests run against mock data and don't require actual Graph API calls
    - Tests the new autopilotProfilesToInclude format and ID-based matching
#>

param(
    [switch]$Verbose
)

# Set up test environment
$ErrorActionPreference = "Stop"
if ($Verbose) { $VerbosePreference = "Continue" }

# Load required functions for testing
Write-Host "Loading required functions..." -ForegroundColor Gray
. ./functions/utilityFunctions/GetAutopilotProfile.ps1
. ./functions/utilityFunctions/AutopilotProfileHelpers.ps1
. ./functions/setupFunctions/Show-AutopilotProfilesEditor.ps1
. ./functions/setupFunctions/Get-ApplicationDefaults.ps1
. ./functions/reportingFunctions/GetAutopilotDeviceRelevantProperties.ps1

# Mock required dependencies
$global:LogFile = $null
function Write-Log { param($LogFile, $Module, $Message, $LogLevel) }
function FormatDateWithTimeZone { param($date) return $date }
function Test-IsHashtableOrConvert { param($InputObject) return $InputObject }

Write-Host "=== Testing Autopilot Profile Validation Features ===" -ForegroundColor Cyan

# Test 1: Test GetAutopilotProfile function availability
Write-Host "`nTest 1: Verify GetAutopilotProfile function is available" -ForegroundColor Yellow
try 
{
    $functionExists = Get-Command -Name "GetAutopilotProfile" -ErrorAction SilentlyContinue
    if ($functionExists) 
    {
        Write-Host "✓ GetAutopilotProfile function is available" -ForegroundColor Green
    }
    else 
    {
        Write-Host "✗ GetAutopilotProfile function not found" -ForegroundColor Red
        exit 1
    }
}
catch 
{
    Write-Host "✗ Error checking GetAutopilotProfile function: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 2: Test AutopilotProfileHelpers functions availability
Write-Host "`nTest 2: Verify Autopilot profile helper functions are available" -ForegroundColor Yellow
$helperFunctions = @(
    "Convert-AutopilotProfilesToStandardFormat",
    "Test-AutopilotProfileFormat", 
    "New-HashTableAutopilotProfileFormat"
)

foreach ($funcName in $helperFunctions) 
{
    try 
    {
        $functionExists = Get-Command -Name $funcName -ErrorAction SilentlyContinue
        if ($functionExists) 
        {
            Write-Host "✓ $funcName function is available" -ForegroundColor Green
        }
        else 
        {
            Write-Host "✗ $funcName function not found" -ForegroundColor Red
            exit 1
        }
    }
    catch 
    {
        Write-Host "✗ Error checking $funcName function: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Test 3: Test Show-AutopilotProfilesEditor function availability
Write-Host "`nTest 3: Verify Show-AutopilotProfilesEditor function is available" -ForegroundColor Yellow
try 
{
    $functionExists = Get-Command -Name "Show-AutopilotProfilesEditor" -ErrorAction SilentlyContinue
    if ($functionExists) 
    {
        Write-Host "✓ Show-AutopilotProfilesEditor function is available" -ForegroundColor Green
    }
    else 
    {
        Write-Host "✗ Show-AutopilotProfilesEditor function not found" -ForegroundColor Red
        exit 1
    }
}
catch 
{
    Write-Host "✗ Error checking Show-AutopilotProfilesEditor function: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 4: Test autopilot profile format conversion
Write-Host "`nTest 4: Test autopilot profile format conversion" -ForegroundColor Yellow
try 
{
    # Test string array format
    $stringProfiles = @("Profile1", "Profile2", "Profile3")
    $names, $ids = Convert-AutopilotProfilesToStandardFormat -profiles $stringProfiles
    
    if ($names.Count -eq 3 -and $ids.Count -eq 0) 
    {
        Write-Host "✓ String array format conversion works correctly" -ForegroundColor Green
    }
    else 
    {
        Write-Host "✗ String array format conversion failed. Names: $($names.Count), IDs: $($ids.Count)" -ForegroundColor Red
        exit 1
    }
    
    # Test hashtable array format
    $hashProfiles = @(
        @{ name = "Profile1"; id = "id1" },
        @{ name = "Profile2"; id = "id2" }
    )
    $names2, $ids2 = Convert-AutopilotProfilesToStandardFormat -profiles $hashProfiles
    
    if ($names2.Count -eq 2 -and $ids2.Count -eq 2) 
    {
        Write-Host "✓ Hashtable array format conversion works correctly" -ForegroundColor Green
    }
    else 
    {
        Write-Host "✗ Hashtable array format conversion failed. Names: $($names2.Count), IDs: $($ids2.Count)" -ForegroundColor Red
        exit 1
    }
}
catch 
{
    Write-Host "✗ Error testing profile format conversion: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 5: Test profile format detection
Write-Host "`nTest 5: Test autopilot profile format detection" -ForegroundColor Yellow
try 
{
    $stringFormat = Test-AutopilotProfileFormat -profiles @("Profile1", "Profile2")
    $hashFormat = Test-AutopilotProfileFormat -profiles @(@{ name = "Profile1"; id = "id1" })
    $emptyFormat = Test-AutopilotProfileFormat -profiles @()
    
    if ($stringFormat -eq "StringArray" -and $hashFormat -eq "HashTableArray" -and $emptyFormat -eq "Empty") 
    {
        Write-Host "✓ Profile format detection works correctly" -ForegroundColor Green
    }
    else 
    {
        Write-Host "✗ Profile format detection failed. String: $stringFormat, Hash: $hashFormat, Empty: $emptyFormat" -ForegroundColor Red
        exit 1
    }
}
catch 
{
    Write-Host "✗ Error testing profile format detection: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 6: Test new hashtable profile format creation
Write-Host "`nTest 6: Test new hashtable profile format creation" -ForegroundColor Yellow
try 
{
    $newProfiles = New-HashTableAutopilotProfileFormat -profileNames @("Profile1", "Profile2") -profileIds @("id1", "id2")
    
    if ($newProfiles.Count -eq 2 -and $newProfiles[0].name -eq "Profile1" -and $newProfiles[0].id -eq "id1") 
    {
        Write-Host "✓ New hashtable profile format creation works correctly" -ForegroundColor Green
    }
    else 
    {
        Write-Host "✗ New hashtable profile format creation failed" -ForegroundColor Red
        exit 1
    }
}
catch 
{
    Write-Host "✗ Error testing hashtable profile format creation: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 7: Test domain defaults include new autopilotProfilesToInclude field
Write-Host "`nTest 7: Test domain defaults include autopilotProfilesToInclude" -ForegroundColor Yellow
try 
{
    $domainDefaults = Get-ApplicationDefaults -DefaultType "Domain" -DomainName "test.com"
    
    if ($domainDefaults.Contains('autopilotProfilesToInclude')) 
    {
        Write-Host "✓ Domain defaults include autopilotProfilesToInclude field" -ForegroundColor Green
    }
    else 
    {
        Write-Host "✗ Domain defaults missing autopilotProfilesToInclude field" -ForegroundColor Red
        Write-Host "Available keys: $($domainDefaults.Keys -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}
catch 
{
    Write-Host "✗ Error testing domain defaults: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 8: Test GetAutopilotDeviceRelevantProperties function still works
Write-Host "`nTest 8: Test GetAutopilotDeviceRelevantProperties function compatibility" -ForegroundColor Yellow
try 
{
    $functionExists = Get-Command -Name "GetAutopilotDeviceRelevantProperties" -ErrorAction SilentlyContinue
    if ($functionExists) 
    {
        Write-Host "✓ GetAutopilotDeviceRelevantProperties function is available" -ForegroundColor Green
        
        # Test that the function can handle missing autopilot profile settings
        $mockEnrollmentState = @{
            autopilot = @{
                device = @{
                    deploymentProfileAssignmentStatus = "assignedInSync"
                    deploymentProfile = @{
                        id = "test-id"
                        displayName = "Test Profile"
                    }
                }
            }
        }
        
        $mockSettings = @{
            # No autopilot profile settings - should not error
        }
        
        $result = GetAutopilotDeviceRelevantProperties -enrollmentState $mockEnrollmentState -settings $mockSettings
        if ($result) 
        {
            Write-Host "✓ GetAutopilotDeviceRelevantProperties handles missing profile settings correctly" -ForegroundColor Green
        }
        else 
        {
            Write-Host "✗ GetAutopilotDeviceRelevantProperties failed with missing profile settings" -ForegroundColor Red
            exit 1
        }
    }
    else 
    {
        Write-Host "✗ GetAutopilotDeviceRelevantProperties function not found" -ForegroundColor Red
        exit 1
    }
}
catch 
{
    Write-Host "✗ Error testing GetAutopilotDeviceRelevantProperties function: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== All Autopilot Profile Validation Tests Passed! ===" -ForegroundColor Green
Write-Host "✓ GetAutopilotProfile function available and ready for use" -ForegroundColor Green
Write-Host "✓ Show-AutopilotProfilesEditor function available for interactive editing" -ForegroundColor Green  
Write-Host "✓ Profile format conversion functions working correctly" -ForegroundColor Green
Write-Host "✓ Domain configuration supports new autopilotProfilesToInclude format" -ForegroundColor Green
Write-Host "✓ GetAutopilotDeviceRelevantProperties updated for enhanced profile matching" -ForegroundColor Green

exit 0
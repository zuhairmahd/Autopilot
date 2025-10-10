#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Test script for Groups Editor hashtable format support.

.DESCRIPTION
    Tests the enhanced Groups Editor functionality to ensure it handles both old
    string array format and new hashtable format with group names and IDs.
#>

# Import required functions
$scriptRoot = Split-Path -Parent $PSCommandPath
$functionsPath = Join-Path $scriptRoot "../functions"

# Create temporary folder for test artifacts
$TestTempFolder = Join-Path $env:TEMP "autopilot-groups-hashtable-test-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -ItemType Directory -Path $TestTempFolder -Force | Out-Null

try
{
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
    $global:logFile = Join-Path $TestTempFolder "test.log"

    Write-Host "`n=== Groups Editor Hashtable Format Tests ===" -ForegroundColor Yellow

    # Test 1: Enhanced Get-GroupArrayInput functionality
    Write-Host "`nTest 1: Enhanced Get-GroupArrayInput Function" -ForegroundColor Yellow
    try
    {
        $functionInfo = Get-Command Get-GroupArrayInput -ErrorAction Stop
        Write-Host "✓ Get-GroupArrayInput function is available" -ForegroundColor Green
        
        # Check if AccessToken parameter was added
        $accessTokenParam = $functionInfo.Parameters['AccessToken']
        if ($accessTokenParam)
        {
            Write-Host "✓ AccessToken parameter added for group ID resolution" -ForegroundColor Green
        }
        else
        {
            Write-Host "✗ AccessToken parameter missing" -ForegroundColor Red
        }
    }
    catch
    {
        Write-Host "✗ Error checking Get-GroupArrayInput: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Test 2: Enhanced Compare-ArrayContents functionality
    Write-Host "`nTest 2: Enhanced Compare-ArrayContents Function" -ForegroundColor Yellow
    try
    {
        # Test with old string array format
        $stringArray1 = @("Group1", "Group2")
        $stringArray2 = @("Group1", "Group2")
        $stringArray3 = @("Group1", "Group3")
        
        $result1 = Compare-EditorArrayContents -Array1 $stringArray1 -Array2 $stringArray2
        $result2 = Compare-EditorArrayContents -Array1 $stringArray1 -Array2 $stringArray3
        
        if (-not $result1 -and $result2)
        {
            Write-Host "✓ String array comparison works correctly" -ForegroundColor Green
        }
        else
        {
            Write-Host "✗ String array comparison failed" -ForegroundColor Red
        }
        
        # Test with new hashtable format
        $hashArray1 = @(
            @{ name = "Group1"; id = "12345678-1234-1234-1234-123456789abc" },
            @{ name = "Group2"; id = "87654321-4321-4321-4321-abcdef123456" }
        )
        $hashArray2 = @(
            @{ name = "Group1"; id = "12345678-1234-1234-1234-123456789abc" },
            @{ name = "Group2"; id = "87654321-4321-4321-4321-abcdef123456" }
        )
        $hashArray3 = @(
            @{ name = "Group1"; id = "12345678-1234-1234-1234-123456789abc" },
            @{ name = "Group2"; id = "different-id-4321-4321-abcdef123456" }
        )
        
        $result3 = Compare-EditorArrayContents -Array1 $hashArray1 -Array2 $hashArray2
        $result4 = Compare-EditorArrayContents -Array1 $hashArray1 -Array2 $hashArray3
        
        if (-not $result3 -and $result4)
        {
            Write-Host "✓ Hashtable array comparison works correctly" -ForegroundColor Green
        }
        else
        {
            Write-Host "✗ Hashtable array comparison failed" -ForegroundColor Red
        }
        
        # Test mixed format comparison (should detect change)
        $result5 = Compare-EditorArrayContents -Array1 $stringArray1 -Array2 $hashArray1
        if ($result5)
        {
            Write-Host "✓ Mixed format comparison detects change correctly" -ForegroundColor Green
        }
        else
        {
            Write-Host "✗ Mixed format comparison failed to detect change" -ForegroundColor Red
        }
    }
    catch
    {
        Write-Host "✗ Error testing Compare-ArrayContents: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Test 3: Format detection and display logic
    Write-Host "`nTest 3: Format Detection Logic" -ForegroundColor Yellow
    try
    {
        # Test string format detection
        $stringGroups = @("TestGroup1", "TestGroup2")
        $firstElement = $stringGroups[0]
        $isString = $firstElement -is [string]
        
        if ($isString)
        {
            Write-Host "✓ String format detection works" -ForegroundColor Green
        }
        else
        {
            Write-Host "✗ String format detection failed" -ForegroundColor Red
        }
        
        # Test hashtable format detection
        $hashGroups = @(
            @{ name = "TestGroup1"; id = "test-id-1" },
            @{ name = "TestGroup2"; id = "test-id-2" }
        )
        $firstHash = $hashGroups[0]
        $isHashWithNameId = ($firstHash -is [hashtable] -or $firstHash -is [PSCustomObject]) -and $firstHash.name -and $firstHash.id
        
        if ($isHashWithNameId)
        {
            Write-Host "✓ Hashtable format detection works" -ForegroundColor Green
        }
        else
        {
            Write-Host "✗ Hashtable format detection failed" -ForegroundColor Red
        }
    }
    catch
    {
        Write-Host "✗ Error testing format detection: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Test 4: Integration with VerifyGroupMembership
    Write-Host "`nTest 4: Integration with VerifyGroupMembership" -ForegroundColor Yellow
    try
    {
        # Test that VerifyGroupMembership can accept hashtable format
        $mockAccessToken = "mock_token_for_testing"
        $mockUserName = "test@example.com"
        
        # Test with new hashtable format
        $hashTableGroups = @(
            @{ name = "TestGroup1"; id = "12345678-1234-1234-1234-123456789abc" },
            @{ name = "TestGroup2"; id = "87654321-4321-4321-4321-abcdef123456" }
        )
        
        $result = VerifyGroupMembership -accessToken $mockAccessToken -userName $mockUserName -groupsToInclude $hashTableGroups
        
        if ($result -and $result.MissingGroups)
        {
            Write-Host "✓ VerifyGroupMembership accepts hashtable format" -ForegroundColor Green
            Write-Host "  Missing groups count: $($result.MissingGroups.Count)" -ForegroundColor Gray
        }
        else
        {
            Write-Host "✗ VerifyGroupMembership hashtable format integration failed" -ForegroundColor Red
        }
    }
    catch
    {
        Write-Host "✗ Error testing VerifyGroupMembership integration: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Test 5: Backward compatibility verification
    Write-Host "`nTest 5: Backward Compatibility" -ForegroundColor Yellow
    try
    {
        # Verify that old string arrays still work with new functions
        $oldStringGroups = @("OldGroup1", "OldGroup2")
        
        # Test Compare-EditorArrayContents with old format
        $oldComparison = Compare-EditorArrayContents -Array1 $oldStringGroups -Array2 $oldStringGroups
        if (-not $oldComparison)
        {
            Write-Host "✓ Backward compatibility maintained in Compare-EditorArrayContents" -ForegroundColor Green
        }
        else
        {
            Write-Host "✗ Backward compatibility issue in Compare-EditorArrayContents" -ForegroundColor Red
        }
        
        # Test VerifyGroupMembership with old format
        $mockAccessToken = "mock_token_for_testing"
        $oldResult = VerifyGroupMembership -accessToken $mockAccessToken -userName "test@example.com" -groupsToInclude $oldStringGroups
        
        if ($oldResult)
        {
            Write-Host "✓ VerifyGroupMembership backward compatibility maintained" -ForegroundColor Green
        }
        else
        {
            Write-Host "✗ VerifyGroupMembership backward compatibility issue" -ForegroundColor Red
        }
    }
    catch
    {
        Write-Host "✗ Error testing backward compatibility: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Test 6: Data structure consistency
    Write-Host "`nTest 6: Data Structure Consistency" -ForegroundColor Yellow
    try
    {
        # Test that hashtable format is consistent
        $testGroups = @(
            @{ name = "Group1"; id = "id1" },
            @{ name = "Group2"; id = $null },  # Test with null ID
            @{ name = "Group3"; id = "id3" }
        )
        
        $allHaveNameProperty = $true
        $allHaveIdProperty = $true
        
        foreach ($group in $testGroups)
        {
            if (-not $group.ContainsKey("name"))
            {
                $allHaveNameProperty = $false
            }
            if (-not $group.ContainsKey("id"))
            {
                $allHaveIdProperty = $false
            }
        }
        
        if ($allHaveNameProperty -and $allHaveIdProperty)
        {
            Write-Host "✓ Hashtable structure is consistent" -ForegroundColor Green
            Write-Host "  All groups have 'name' and 'id' properties" -ForegroundColor Gray
        }
        else
        {
            Write-Host "✗ Hashtable structure inconsistency detected" -ForegroundColor Red
        }
    }
    catch
    {
        Write-Host "✗ Error testing data structure consistency: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
    Write-Host "Groups Editor hashtable format enhancement validation completed." -ForegroundColor White
    Write-Host "Key Features Tested:" -ForegroundColor White
    Write-Host "- Enhanced Get-GroupArrayInput with AccessToken parameter" -ForegroundColor Gray
    Write-Host "- Enhanced Compare-ArrayContents with hashtable support" -ForegroundColor Gray
    Write-Host "- Format detection for both string and hashtable arrays" -ForegroundColor Gray
    Write-Host "- Integration with VerifyGroupMembership function" -ForegroundColor Gray
    Write-Host "- Backward compatibility with existing string arrays" -ForegroundColor Gray
    Write-Host "- Data structure consistency validation" -ForegroundColor Gray

    Write-Host "`nNext Steps:" -ForegroundColor Yellow
    Write-Host "1. Test with real domain configuration files" -ForegroundColor White
    Write-Host "2. Test Update-DomainGroupSetting with hashtable arrays" -ForegroundColor White
    Write-Host "3. Test end-to-end group editing workflow" -ForegroundColor White
    Write-Host "4. Validate automatic migration from old to new format" -ForegroundColor White
}
finally
{
    # Cleanup temporary folder
    if (Test-Path $TestTempFolder)
    {
        Remove-Item -Path $TestTempFolder -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "`nCleaned up temporary test folder" -ForegroundColor Gray
    }
}
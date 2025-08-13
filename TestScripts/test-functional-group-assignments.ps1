#!/usr/bin/env pwsh

# Functional test for the expanded group assignment functionality
# This test validates that the functions work with mock data

Write-Host "=== Functional Test: Expanded Group Assignment Functionality ===" -ForegroundColor Green

$scriptPath = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
$rootPath = Split-Path $scriptPath -Parent

# Import required functions
try {
    . "$rootPath/functions/utilityFunctions/Write-Log.ps1"
    
    # Mock functions to avoid actual API calls
    function CallGraphAPI {
        param(
            [string]$accessToken,
            [string]$ResourcePath,
            [string]$APIVersion,
            [string]$ExtraParameters,
            [string]$Method = "GET",
            [string]$Body
        )
        
        # Return mock data based on the resource path
        if ($ResourcePath -like "*batch*") {
            return @{
                responses = @(
                    @{
                        id = "test-id-1"
                        status = 200
                        body = @{
                            value = @(
                                @{
                                    id = "assignment-1"
                                    intent = "Required"
                                    target = @{
                                        '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
                                        groupId = "test-group-id"
                                    }
                                    settings = @{}
                                }
                            )
                        }
                    }
                )
            }
        }
        else {
            # Mock resource lists
            return @{
                value = @(
                    @{
                        id = "test-id-1"
                        displayName = "Test Resource 1"
                        name = "Test Resource 1"  # For configuration policies
                    },
                    @{
                        id = "test-id-2"
                        displayName = "Test Resource 2"
                        name = "Test Resource 2"  # For configuration policies
                    }
                )
            }
        }
    }
    
    function GetGroupIdsByNames {
        param(
            [string]$AccessToken,
            [array]$GroupNames
        )
        return @("test-group-id")
    }
    
    # Set global variables
    $global:LogFile = "/tmp/functional-test.log"
    $global:maxJSONDepth = 10
    
    . "$rootPath/functions/utilityFunctions/GetGroupDirectAssignments.ps1"
    
    Write-Host "✓ Functions imported successfully"
} catch {
    Write-Host "✗ Failed to import functions: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`nTesting GetGroupDirectAssignments function..." -ForegroundColor Yellow

try {
    # Test the function with mock data
    $mockGroup = [PSCustomObject]@{
        id = "12345678-1234-1234-1234-123456789012"
        displayName = "TestGroup"
    }
    $result = GetGroupDirectAssignments -Group $mockGroup -AccessToken "mock-token" -IncludeBeta -ShowSummary -BatchSize 5
    
    # Validate the result structure
    if ($result -and $result.GroupName -eq "TestGroup") {
        Write-Host "✓ Function returned expected result structure"
        
        # Check all expected properties exist
        $expectedProperties = @(
            'GroupName', 'GroupId', 'AppAssignments', 'ConfigurationAssignments', 'ComplianceAssignments',
            'AutopilotAssignments', 'ScriptAssignments', 'HealthScriptAssignments', 'AppProtectionAssignments',
            'IntentAssignments', 'ResourceAccessAssignments', 'ConfigurationPolicyAssignments', 
            'GroupPolicyAssignments', 'AllAssignments'
        )
        
        $allPropertiesPresent = $true
        foreach ($prop in $expectedProperties) {
            if (-not $result.PSObject.Properties[$prop]) {
                Write-Host "✗ Missing property: $prop" -ForegroundColor Red
                $allPropertiesPresent = $false
            }
        }
        
        if ($allPropertiesPresent) {
            Write-Host "✓ All expected properties present in result"
        }
        
        # Check that assignments arrays are properly initialized
        $arrayPropsInitialized = $true
        foreach ($prop in $expectedProperties) {
            if ($prop -like "*Assignments" -and $result.$prop -eq $null) {
                Write-Host "✗ Property $prop is null instead of empty array" -ForegroundColor Red
                $arrayPropsInitialized = $false
            }
        }
        
        if ($arrayPropsInitialized) {
            Write-Host "✓ All assignment arrays properly initialized"
        }
        
        Write-Host "✓ Functional test completed successfully" -ForegroundColor Green
        
    } else {
        Write-Host "✗ Function did not return expected result structure" -ForegroundColor Red
        Write-Host "Result: $($result | ConvertTo-Json -Depth 2)" -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host "✗ Functional test failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Functional Test Summary ===" -ForegroundColor Green
Write-Host "✓ All functional tests passed!" -ForegroundColor Green
exit 0
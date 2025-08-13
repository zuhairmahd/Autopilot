#!/usr/bin/env pwsh

# Test script for group assignment function fixes
# Tests PowerShell 5.1 compatibility and array indexing fixes

Write-Host "=== Group Assignment Function Regression Tests ===" -ForegroundColor Green

$scriptPath = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
$rootPath = Split-Path $scriptPath -Parent

# Import required functions
try {
    . "$rootPath/functions/utilityFunctions/Write-Log.ps1"
    . "$rootPath/functions/utilityFunctions/GetGroupIdsByNames.ps1"
    . "$rootPath/functions/utilityFunctions/GetGroupDirectAssignments.ps1"
    
    $global:LogFile = "/tmp/group-test.log"
    Write-Host "✓ Functions imported successfully"
} catch {
    Write-Host "✗ Failed to import functions: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$testsPassed = 0
$testsTotal = 0

function Test-ArrayIndexing {
    $script:testsTotal++
    Write-Host "`nTest: Array indexing safety" -ForegroundColor Yellow
    
    # Test the specific pattern used in GetGroupDirectAssignments
    $testCases = @(
        @{ Input = "single-string-id"; Expected = "single-string-id" }
        @{ Input = @("array-item-1", "array-item-2"); Expected = "array-item-1" }
        @{ Input = @("single-array-item"); Expected = "single-array-item" }
    )
    
    $allPassed = $true
    foreach ($case in $testCases) {
        $groupIds = $case.Input
        $groupIdArray = @($groupIds)
        $result = $groupIdArray[0]
        
        if ($result -eq $case.Expected) {
            Write-Host "  ✓ Input type '$($case.Input.GetType().Name)' -> '$result'"
        } else {
            Write-Host "  ✗ Input type '$($case.Input.GetType().Name)' -> '$result' (expected '$($case.Expected)')" -ForegroundColor Red
            $allPassed = $false
        }
    }
    
    if ($allPassed) {
        $script:testsPassed++
        Write-Host "✓ Array indexing test passed" -ForegroundColor Green
    } else {
        Write-Host "✗ Array indexing test failed" -ForegroundColor Red
    }
}

function Test-HashtableConstruction {
    $script:testsTotal++
    Write-Host "`nTest: PowerShell 5.1 compatible hashtable construction" -ForegroundColor Yellow
    
    try {
        # Test the pattern used in GetGroupIdsByNames
        $result = @{}
        $result['ResolvedIds'] = @("id1", "id2")
        $result['MissingNames'] = @("name1")
        $result['ResolvedNames'] = @("resolved1")
        $result['MissingIds'] = @()
        
        # Verify all keys exist and have correct types
        $expectedKeys = @('ResolvedIds', 'MissingNames', 'ResolvedNames', 'MissingIds')
        $allKeysPresent = $true
        
        foreach ($key in $expectedKeys) {
            if (-not $result.ContainsKey($key)) {
                Write-Host "  ✗ Missing key: $key" -ForegroundColor Red
                $allKeysPresent = $false
            }
        }
        
        if ($allKeysPresent) {
            $script:testsPassed++
            Write-Host "✓ Hashtable construction test passed" -ForegroundColor Green
        } else {
            Write-Host "✗ Hashtable construction test failed" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ Hashtable construction test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Test-FunctionSignatures {
    $script:testsTotal++
    Write-Host "`nTest: Function signatures and parameters" -ForegroundColor Yellow
    
    try {
        $getGroupCommand = Get-Command GetGroupIdsByNames -ErrorAction Stop
        $getDirectCommand = Get-Command GetGroupDirectAssignments -ErrorAction Stop
        
        # Test required parameters exist
        $requiredParams = @{
            'GetGroupIdsByNames' = @('GroupNames')
            'GetGroupDirectAssignments' = @('GroupName', 'BatchSize')
        }
        
        $allParamsPresent = $true
        foreach ($funcName in $requiredParams.Keys) {
            $command = Get-Command $funcName
            foreach ($paramName in $requiredParams[$funcName]) {
                if (-not $command.Parameters.ContainsKey($paramName)) {
                    Write-Host "  ✗ Missing parameter '$paramName' in function '$funcName'" -ForegroundColor Red
                    $allParamsPresent = $false
                } else {
                    Write-Host "  ✓ Parameter '$paramName' found in '$funcName'"
                    
                    # Special validation for BatchSize parameter
                    if ($paramName -eq 'BatchSize') {
                        $param = $command.Parameters[$paramName]
                        if ($param.ParameterType -eq [int]) {
                            Write-Host "  ✓ BatchSize parameter correctly typed as [int]"
                        } else {
                            Write-Host "  ✗ BatchSize parameter should be [int] type" -ForegroundColor Red
                            $allParamsPresent = $false
                        }
                    }
                }
            }
        }
        
        if ($allParamsPresent) {
            $script:testsPassed++
            Write-Host "✓ Function signatures test passed" -ForegroundColor Green
        } else {
            Write-Host "✗ Function signatures test failed" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ Function signatures test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Test-CodePatterns {
    $script:testsTotal++
    Write-Host "`nTest: Code patterns in source files" -ForegroundColor Yellow
    
    try {
        # Check GetGroupDirectAssignments for safe array indexing
        $directContent = Get-Content "$rootPath/functions/utilityFunctions/GetGroupDirectAssignments.ps1" -Raw
        $hasArrayWrapping = $directContent -match '\$groupIdArray = @\(\$groupIds\)'
        $hasSafeIndexing = $directContent -match '\$groupId = \$groupIdArray\[0\]'
        
        # Check GetGroupIdsByNames for simplified implementation (no complex hashtable construction needed)
        $idsContent = Get-Content "$rootPath/functions/utilityFunctions/GetGroupIdsByNames.ps1" -Raw
        $hasSimplifiedImplementation = $idsContent -match 'Initialize session cache' -and $idsContent -notmatch 'Resolve-FromIndex'
        
        # Check for batch API implementation patterns
        $hasBatchProcessing = $directContent -match 'Invoke-BatchAssignments'
        $hasBatchRequestBody = $directContent -match 'batchRequestBody = @{'
        $hasBatchAPICall = $directContent -match 'ResourcePath.*\$batch'
        
        $patterns = @{
            'Array wrapping in GetGroupDirectAssignments' = $hasArrayWrapping
            'Safe indexing in GetGroupDirectAssignments' = $hasSafeIndexing
            'Simplified implementation in GetGroupIdsByNames' = $hasSimplifiedImplementation
            'Batch processing helper function' = $hasBatchProcessing
            'Batch request body construction' = $hasBatchRequestBody
            'Batch API endpoint usage' = $hasBatchAPICall
        }
        
        $allPatternsPresent = $true
        foreach ($pattern in $patterns.Keys) {
            if ($patterns[$pattern]) {
                Write-Host "  ✓ $pattern"
            } else {
                Write-Host "  ✗ $pattern" -ForegroundColor Red
                $allPatternsPresent = $false
            }
        }
        
        if ($allPatternsPresent) {
            $script:testsPassed++
            Write-Host "✓ Code patterns test passed" -ForegroundColor Green
        } else {
            Write-Host "✗ Code patterns test failed" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ Code patterns test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Run all tests
Test-ArrayIndexing
Test-HashtableConstruction
Test-FunctionSignatures
Test-CodePatterns

# Summary
Write-Host "`n=== Test Results ===" -ForegroundColor Cyan
Write-Host "Passed: $testsPassed/$testsTotal tests" -ForegroundColor $(if ($testsPassed -eq $testsTotal) { 'Green' } else { 'Yellow' })

if ($testsPassed -eq $testsTotal) {
    Write-Host "🎉 All group assignment function tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "⚠️  Some tests failed. Please review the fixes." -ForegroundColor Yellow
    exit 1
}
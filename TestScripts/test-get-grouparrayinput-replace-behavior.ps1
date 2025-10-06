#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Test script for Get-GroupArrayInput replace/add behavior.

.DESCRIPTION
    Tests that Get-GroupArrayInput properly respects user choice:
    - Option 1: Replace existing groups (old groups should be removed)
    - Option 2: Add to existing groups (old + new groups)
    - Option 3: Keep existing groups unchanged
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
$global:logFile = Join-Path $scriptRoot "test-grouparrayinput.log"

Write-Host "`n=== Get-GroupArrayInput Replace/Add Behavior Tests ===" -ForegroundColor Yellow

# Helper function to create mock Read-Host that simulates user input
$global:mockReadHostResponses = @()
$global:mockReadHostIndex = 0

function Mock-ReadHost
{
    param([string]$Prompt)
    
    if ($global:mockReadHostIndex -lt $global:mockReadHostResponses.Count)
    {
        $response = $global:mockReadHostResponses[$global:mockReadHostIndex]
        $global:mockReadHostIndex++
        Write-Host "$Prompt : $response" -ForegroundColor Gray
        return $response
    }
    else
    {
        throw "Mock-ReadHost: No more responses available. Prompt was: $Prompt"
    }
}

# Test 1: Option 1 - Replace existing groups
Write-Host "`nTest 1: Option 1 - Replace Existing Groups" -ForegroundColor Yellow
Write-Host "Testing that option 1 removes old groups and only keeps new ones" -ForegroundColor Gray
try
{
    # Setup: existing groups
    $existingGroups = @(
        @{ name = "OldGroup1"; id = "old-id-1" },
        @{ name = "OldGroup2"; id = "old-id-2" }
    )
    
    # Mock user responses: 
    # 1. Choice "1" for replace
    # 2. "NewGroup1" as first group name
    # 3. Empty string to finish
    $global:mockReadHostResponses = @("1", "NewGroup1", "")
    $global:mockReadHostIndex = 0
    
    # Replace Read-Host
    Remove-Item function:\Read-Host -ErrorAction SilentlyContinue
    Set-Item function:\Read-Host -Value ${function:Mock-ReadHost}
    
    # Mock Get-EntraDirectoryObject to return a single match
    function global:Get-EntraDirectoryObject
    {
        param([string]$EntityType, [string]$EntityName, [string]$AccessToken, [switch]$findSimilar)
        
        if ($EntityName -eq "NewGroup1")
        {
            $result = @{
                value = @(
                    @{
                        displayName = "NewGroup1"
                        id          = "new-id-1"
                    }
                )
            }
            return $result, $false
        }
        return @{ value = @() }, $false
    }
    
    # Call the function
    $result = Get-GroupArrayInput -CurrentGroups $existingGroups -GroupType "include" -AccessToken "mock_token"
    
    # Verify results
    if ($result.Count -eq 1 -and $result[0].name -eq "NewGroup1" -and $result[0].id -eq "new-id-1")
    {
        Write-Host "✓ Option 1 works: Old groups removed, only new group returned" -ForegroundColor Green
        Write-Host "  Result: $($result.Count) group(s)" -ForegroundColor Gray
        Write-Host "  Group: $($result[0].name) (ID: $($result[0].id))" -ForegroundColor Gray
        
        # Verify old groups are NOT in the result
        $hasOldGroups = $false
        foreach ($group in $result)
        {
            if ($group.name -eq "OldGroup1" -or $group.name -eq "OldGroup2")
            {
                $hasOldGroups = $true
                break
            }
        }
        
        if (-not $hasOldGroups)
        {
            Write-Host "  ✓ Verified: Old groups are NOT in result" -ForegroundColor Green
        }
        else
        {
            Write-Host "  ✗ ERROR: Old groups still present in result" -ForegroundColor Red
        }
    }
    else
    {
        Write-Host "✗ Option 1 FAILED: Expected 1 new group, got $($result.Count)" -ForegroundColor Red
        Write-Host "  Result details:" -ForegroundColor Gray
        foreach ($group in $result)
        {
            Write-Host "    - $($group.name) (ID: $($group.id))" -ForegroundColor Gray
        }
    }
}
catch
{
    Write-Host "✗ Test 1 Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
}
finally
{
    # Restore original functions
    $functionFiles = Get-ChildItem -Path $functionsPath -Filter "*.ps1" -Recurse
    foreach ($file in $functionFiles)
    {
        . $file.FullName
    }
}

# Test 2: Option 2 - Add to existing groups
Write-Host "`nTest 2: Option 2 - Add to Existing Groups" -ForegroundColor Yellow
Write-Host "Testing that option 2 keeps old groups and adds new ones" -ForegroundColor Gray
try
{
    # Setup: existing groups
    $existingGroups = @(
        @{ name = "OldGroup1"; id = "old-id-1" },
        @{ name = "OldGroup2"; id = "old-id-2" }
    )
    
    # Mock user responses:
    # 1. Choice "2" for add
    # 2. "NewGroup1" as first group name
    # 3. Empty string to finish
    $global:mockReadHostResponses = @("2", "NewGroup1", "")
    $global:mockReadHostIndex = 0
    
    # Replace Read-Host
    Remove-Item function:\Read-Host -ErrorAction SilentlyContinue
    Set-Item function:\Read-Host -Value ${function:Mock-ReadHost}
    
    # Mock Get-EntraDirectoryObject
    function global:Get-EntraDirectoryObject
    {
        param([string]$EntityType, [string]$EntityName, [string]$AccessToken, [switch]$findSimilar)
        
        if ($EntityName -eq "NewGroup1")
        {
            $result = @{
                value = @(
                    @{
                        displayName = "NewGroup1"
                        id          = "new-id-1"
                    }
                )
            }
            return $result, $false
        }
        return @{ value = @() }, $false
    }
    
    # Call the function
    $result = Get-GroupArrayInput -CurrentGroups $existingGroups -GroupType "include" -AccessToken "mock_token"
    
    # Verify results: should have 3 groups total (2 old + 1 new)
    if ($result.Count -eq 3)
    {
        $hasOldGroup1 = $false
        $hasOldGroup2 = $false
        $hasNewGroup1 = $false
        
        foreach ($group in $result)
        {
            if ($group.name -eq "OldGroup1")
            {
                $hasOldGroup1 = $true 
            }
            if ($group.name -eq "OldGroup2")
            {
                $hasOldGroup2 = $true 
            }
            if ($group.name -eq "NewGroup1")
            {
                $hasNewGroup1 = $true 
            }
        }
        
        if ($hasOldGroup1 -and $hasOldGroup2 -and $hasNewGroup1)
        {
            Write-Host "✓ Option 2 works: Old groups kept, new group added" -ForegroundColor Green
            Write-Host "  Result: $($result.Count) group(s)" -ForegroundColor Gray
            Write-Host "  ✓ Has OldGroup1" -ForegroundColor Green
            Write-Host "  ✓ Has OldGroup2" -ForegroundColor Green
            Write-Host "  ✓ Has NewGroup1" -ForegroundColor Green
        }
        else
        {
            Write-Host "✗ Option 2 FAILED: Missing expected groups" -ForegroundColor Red
            Write-Host "  Has OldGroup1: $hasOldGroup1" -ForegroundColor Gray
            Write-Host "  Has OldGroup2: $hasOldGroup2" -ForegroundColor Gray
            Write-Host "  Has NewGroup1: $hasNewGroup1" -ForegroundColor Gray
        }
    }
    else
    {
        Write-Host "✗ Option 2 FAILED: Expected 3 groups, got $($result.Count)" -ForegroundColor Red
        Write-Host "  Result details:" -ForegroundColor Gray
        foreach ($group in $result)
        {
            Write-Host "    - $($group.name) (ID: $($group.id))" -ForegroundColor Gray
        }
    }
}
catch
{
    Write-Host "✗ Test 2 Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
}
finally
{
    # Restore original functions
    $functionFiles = Get-ChildItem -Path $functionsPath -Filter "*.ps1" -Recurse
    foreach ($file in $functionFiles)
    {
        . $file.FullName
    }
}

# Test 3: Option 3 - Keep existing groups unchanged
Write-Host "`nTest 3: Option 3 - Keep Existing Groups Unchanged" -ForegroundColor Yellow
Write-Host "Testing that option 3 returns original groups without changes" -ForegroundColor Gray
try
{
    # Setup: existing groups
    $existingGroups = @(
        @{ name = "OldGroup1"; id = "old-id-1" },
        @{ name = "OldGroup2"; id = "old-id-2" }
    )
    
    # Mock user responses:
    # 1. Choice "3" for keep unchanged
    $global:mockReadHostResponses = @("3")
    $global:mockReadHostIndex = 0
    
    # Replace Read-Host
    Remove-Item function:\Read-Host -ErrorAction SilentlyContinue
    Set-Item function:\Read-Host -Value ${function:Mock-ReadHost}
    
    # Call the function
    $result = Get-GroupArrayInput -CurrentGroups $existingGroups -GroupType "include" -AccessToken "mock_token"
    
    # Verify results: should have exactly 2 groups (unchanged)
    if ($result.Count -eq 2 -and $result[0].name -eq "OldGroup1" -and $result[1].name -eq "OldGroup2")
    {
        Write-Host "✓ Option 3 works: Original groups returned unchanged" -ForegroundColor Green
        Write-Host "  Result: $($result.Count) group(s)" -ForegroundColor Gray
        Write-Host "  Groups: $($result[0].name), $($result[1].name)" -ForegroundColor Gray
    }
    else
    {
        Write-Host "✗ Option 3 FAILED: Expected 2 unchanged groups, got $($result.Count)" -ForegroundColor Red
        Write-Host "  Result details:" -ForegroundColor Gray
        foreach ($group in $result)
        {
            Write-Host "    - $($group.name) (ID: $($group.id))" -ForegroundColor Gray
        }
    }
}
catch
{
    Write-Host "✗ Test 3 Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
}
finally
{
    # Restore original functions
    $functionFiles = Get-ChildItem -Path $functionsPath -Filter "*.ps1" -Recurse
    foreach ($file in $functionFiles)
    {
        . $file.FullName
    }
}

# Test 4: Empty array scenario
Write-Host "`nTest 4: Empty Array - Should Allow New Groups" -ForegroundColor Yellow
Write-Host "Testing that empty array allows creating new group list" -ForegroundColor Gray
try
{
    # Setup: no existing groups
    $existingGroups = @()
    
    # Mock user responses:
    # 1. "NewGroup1" as first group name
    # 2. Empty string to finish
    $global:mockReadHostResponses = @("NewGroup1", "")
    $global:mockReadHostIndex = 0
    
    # Replace Read-Host
    Remove-Item function:\Read-Host -ErrorAction SilentlyContinue
    Set-Item function:\Read-Host -Value ${function:Mock-ReadHost}
    
    # Mock Get-EntraDirectoryObject
    function global:Get-EntraDirectoryObject
    {
        param([string]$EntityType, [string]$EntityName, [string]$AccessToken, [switch]$findSimilar)
        
        if ($EntityName -eq "NewGroup1")
        {
            $result = @{
                value = @(
                    @{
                        displayName = "NewGroup1"
                        id          = "new-id-1"
                    }
                )
            }
            return $result, $false
        }
        return @{ value = @() }, $false
    }
    
    # Call the function
    $result = Get-GroupArrayInput -CurrentGroups $existingGroups -GroupType "include" -AccessToken "mock_token"
    
    # Verify results
    if ($result.Count -eq 1 -and $result[0].name -eq "NewGroup1")
    {
        Write-Host "✓ Empty array works: New group added successfully" -ForegroundColor Green
        Write-Host "  Result: $($result.Count) group(s)" -ForegroundColor Gray
        Write-Host "  Group: $($result[0].name) (ID: $($result[0].id))" -ForegroundColor Gray
    }
    else
    {
        Write-Host "✗ Empty array test FAILED: Expected 1 group, got $($result.Count)" -ForegroundColor Red
        Write-Host "  Result details:" -ForegroundColor Gray
        foreach ($group in $result)
        {
            Write-Host "    - $($group.name) (ID: $($group.id))" -ForegroundColor Gray
        }
    }
}
catch
{
    Write-Host "✗ Test 4 Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
}
finally
{
    # Restore original functions
    $functionFiles = Get-ChildItem -Path $functionsPath -Filter "*.ps1" -Recurse
    foreach ($file in $functionFiles)
    {
        . $file.FullName
    }
}

Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Get-GroupArrayInput Replace/Add Behavior Tests Completed" -ForegroundColor White
Write-Host "`nExpected Behavior:" -ForegroundColor Yellow
Write-Host "- Option 1 (Replace): Old groups removed, only new groups in result" -ForegroundColor White
Write-Host "- Option 2 (Add): Old groups kept, new groups added to result" -ForegroundColor White
Write-Host "- Option 3 (Keep): Original groups returned unchanged" -ForegroundColor White
Write-Host "- Empty array: Should not prompt for replace/add choice" -ForegroundColor White

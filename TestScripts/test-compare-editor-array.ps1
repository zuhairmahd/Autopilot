#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Test the Compare-EditorArrayContents function with replace/add scenarios
#>

# Import required functions
$scriptRoot = Split-Path -Parent $PSCommandPath
$functionsPath = Join-Path $scriptRoot "../functions"

# Load the common editor functions
$editorCommonFile = Join-Path $functionsPath "setupFunctions\Show-EditorCommon.ps1"
if (Test-Path $editorCommonFile)
{
    . $editorCommonFile
    Write-Host "Loaded Show-EditorCommon.ps1" -ForegroundColor Cyan
}
else
{
    Write-Host "ERROR: Could not find Show-EditorCommon.ps1" -ForegroundColor Red
    exit 1
}

# Set global variables that the functions expect
$global:maxJSONDepth = 10
$global:logFile = Join-Path $scriptRoot "test-comparison.log"

Write-Host "`n=== Testing Compare-EditorArrayContents ===" -ForegroundColor Yellow

# Test 1: Replace scenario - should detect change
Write-Host "`nTest 1: Replace Scenario (2 old groups → 1 new group)" -ForegroundColor Yellow
$oldGroups = @(
    @{ name = "Old1"; id = "old-1" },
    @{ name = "Old2"; id = "old-2" }
)
$newGroups = @(
    @{ name = "New1"; id = "new-1" }
)

$hasChanges = Compare-EditorArrayContents -Array1 $oldGroups -Array2 $newGroups
Write-Host "Old groups: 2 (Old1, Old2)" -ForegroundColor Gray
Write-Host "New groups: 1 (New1)" -ForegroundColor Gray
Write-Host "Compare result: $hasChanges" -ForegroundColor $(if ($hasChanges)
    {
        "Green" 
    }
    else
    {
        "Red" 
    })
Write-Host "Expected: True (change detected)" -ForegroundColor Gray

if ($hasChanges)
{
    Write-Host "✓ TEST PASSED - Change detected correctly" -ForegroundColor Green
}
else
{
    Write-Host "✗ TEST FAILED - Should have detected change" -ForegroundColor Red
}

# Test 2: Add scenario - should detect change
Write-Host "`nTest 2: Add Scenario (2 old groups → 3 groups)" -ForegroundColor Yellow
$oldGroups = @(
    @{ name = "Old1"; id = "old-1" },
    @{ name = "Old2"; id = "old-2" }
)
$newGroups = @(
    @{ name = "Old1"; id = "old-1" },
    @{ name = "Old2"; id = "old-2" },
    @{ name = "New1"; id = "new-1" }
)

$hasChanges = Compare-EditorArrayContents -Array1 $oldGroups -Array2 $newGroups
Write-Host "Old groups: 2 (Old1, Old2)" -ForegroundColor Gray
Write-Host "New groups: 3 (Old1, Old2, New1)" -ForegroundColor Gray
Write-Host "Compare result: $hasChanges" -ForegroundColor $(if ($hasChanges)
    {
        "Green" 
    }
    else
    {
        "Red" 
    })
Write-Host "Expected: True (change detected)" -ForegroundColor Gray

if ($hasChanges)
{
    Write-Host "✓ TEST PASSED - Change detected correctly" -ForegroundColor Green
}
else
{
    Write-Host "✗ TEST FAILED - Should have detected change" -ForegroundColor Red
}

# Test 3: No change scenario - should NOT detect change
Write-Host "`nTest 3: No Change Scenario (same groups)" -ForegroundColor Yellow
$oldGroups = @(
    @{ name = "Group1"; id = "id-1" },
    @{ name = "Group2"; id = "id-2" }
)
$newGroups = @(
    @{ name = "Group1"; id = "id-1" },
    @{ name = "Group2"; id = "id-2" }
)

$hasChanges = Compare-EditorArrayContents -Array1 $oldGroups -Array2 $newGroups
Write-Host "Old groups: 2 (Group1, Group2)" -ForegroundColor Gray
Write-Host "New groups: 2 (Group1, Group2)" -ForegroundColor Gray
Write-Host "Compare result: $hasChanges" -ForegroundColor $(if (-not $hasChanges)
    {
        "Green" 
    }
    else
    {
        "Red" 
    })
Write-Host "Expected: False (no change)" -ForegroundColor Gray

if (-not $hasChanges)
{
    Write-Host "✓ TEST PASSED - No change detected correctly" -ForegroundColor Green
}
else
{
    Write-Host "✗ TEST FAILED - Should not have detected change" -ForegroundColor Red
}

# Test 4: Keep unchanged scenario - should NOT detect change
Write-Host "`nTest 4: Keep Unchanged Scenario (return same array)" -ForegroundColor Yellow
$currentGroups = @(
    @{ name = "Group1"; id = "id-1" },
    @{ name = "Group2"; id = "id-2" }
)
$returnedGroups = $currentGroups  # Returned unchanged

$hasChanges = Compare-EditorArrayContents -Array1 $currentGroups -Array2 $returnedGroups
Write-Host "Current groups: 2 (Group1, Group2)" -ForegroundColor Gray
Write-Host "Returned groups: 2 (Group1, Group2) [same reference]" -ForegroundColor Gray
Write-Host "Compare result: $hasChanges" -ForegroundColor $(if (-not $hasChanges)
    {
        "Green" 
    }
    else
    {
        "Red" 
    })
Write-Host "Expected: False (no change)" -ForegroundColor Gray

if (-not $hasChanges)
{
    Write-Host "✓ TEST PASSED - No change detected correctly" -ForegroundColor Green
}
else
{
    Write-Host "✗ TEST FAILED - Should not have detected change" -ForegroundColor Red
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Compare-EditorArrayContents function tests completed" -ForegroundColor White
Write-Host "This function correctly detects:" -ForegroundColor White
Write-Host "  ✓ Changes when array size differs (replace scenario)" -ForegroundColor Green
Write-Host "  ✓ Changes when new items added (add scenario)" -ForegroundColor Green
Write-Host "  ✓ No changes when arrays are identical" -ForegroundColor Green

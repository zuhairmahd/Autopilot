#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Tests the integrated Get-EditorReplaceOrAddChoice feedback in Get-AutopilotProfileArrayInput.

.DESCRIPTION
    Validates that Autopilot profiles editor uses the same enhanced feedback pattern as groups editor.
#>

$ErrorActionPreference = "Stop"

Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "  TEST: Autopilot Profiles Editor Feedback Integration" -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Cyan

# Import required modules
$projectRoot = Split-Path $PSScriptRoot -Parent

# Mock functions BEFORE importing the actual modules
function global:Read-Host
{
    param([string]$Prompt)
    throw "Read-Host should not be called in automated tests"
}

function global:Resolve-SingleAutopilotProfileInteractive
{
    param($ProfileName, $AccessToken, $ExistingItems)
    return @{
        name = $ProfileName
        id   = "test-id-$ProfileName"
    }
}

function global:Write-Log
{
    param($LogFile, $Module, $Message, $LogLevel)
    # Suppress logging in tests
}

# Import modules after mocks are in place
. "$projectRoot\functions\setupFunctions\Show-EditorCommon.ps1"
. "$projectRoot\functions\setupFunctions\Show-AutopilotProfilesEditor.ps1"

# Test 1: Verify Get-EditorReplaceOrAddChoice is called
Write-Host "`n[TEST 1] Verify Get-EditorReplaceOrAddChoice integration" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Gray

$testPassed = $false
try
{
    # Mock Get-EditorReplaceOrAddChoice to verify it's called with correct parameters
    $script:editorChoiceCalled = $false
    $script:editorChoiceItemType = $null
    
    # Override the imported function with our mock
    function global:Get-EditorReplaceOrAddChoice
    {
        param($CurrentArray, $ItemType)
        $script:editorChoiceCalled = $true
        $script:editorChoiceItemType = $ItemType
        
        # Return keep unchanged to exit quickly
        return @{
            ShouldReplaceExisting = $false
            ShouldProceed         = $false
        }
    }
    
    # Also mock Write-Host to suppress output
    function global:Write-Host
    {
        param($Object, $ForegroundColor, $NoNewline)
        # Suppress output
    }
    
    $currentProfiles = @(
        @{ name = "Profile1"; id = "id1" }
    )
    
    try
    {
        $result = Get-AutopilotProfileArrayInput -CurrentProfiles $currentProfiles -AccessToken "test-token" -ErrorAction Stop
    }
    catch
    {
        Write-Host "[INFO] Function call completed with: $_" -ForegroundColor Cyan
    }
    
    if ($script:editorChoiceCalled)
    {
        Write-Host "[PASS] Get-EditorReplaceOrAddChoice was called" -ForegroundColor Green
        
        if ($script:editorChoiceItemType -eq 'profile')
        {
            Write-Host "[PASS] ItemType parameter is 'profile'" -ForegroundColor Green
            $testPassed = $true
        }
        else
        {
            Write-Host "[FAIL] ItemType was '$($script:editorChoiceItemType)', expected 'profile'" -ForegroundColor Red
        }
    }
    else
    {
        Write-Host "[FAIL] Get-EditorReplaceOrAddChoice was not called" -ForegroundColor Red
    }
}
catch
{
    Write-Host "[FAIL] Exception: $_" -ForegroundColor Red
}

if (-not $testPassed)
{
    Write-Host "`n[OVERALL] TEST FAILED" -ForegroundColor Red
    exit 1
}

# Test 2: Verify decision.ShouldReplaceExisting is used (not $shouldReplaceExisting variable)
Write-Host "`n[TEST 2] Verify decision object usage" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Gray

$testPassed = $false
try
{
    # Check that the function code doesn't reference $shouldReplaceExisting
    $functionCode = (Get-Command Get-AutopilotProfileArrayInput).ScriptBlock.ToString()
    
    # Should NOT contain old variable reference
    if ($functionCode -notmatch '\$shouldReplaceExisting')
    {
        Write-Host "[PASS] Function does not use deprecated `$shouldReplaceExisting variable" -ForegroundColor Green
        $testPassed = $true
    }
    else
    {
        Write-Host "[FAIL] Function still references `$shouldReplaceExisting variable" -ForegroundColor Red
        Write-Host "       Should use `$decision.ShouldReplaceExisting instead" -ForegroundColor Yellow
    }
    
    # Should contain new decision object references
    if ($functionCode -match '\$decision\.ShouldReplaceExisting')
    {
        Write-Host "[PASS] Function uses `$decision.ShouldReplaceExisting" -ForegroundColor Green
    }
    else
    {
        Write-Host "[FAIL] Function does not use `$decision.ShouldReplaceExisting" -ForegroundColor Red
        $testPassed = $false
    }
    
    if ($functionCode -match '\$decision\.ShouldProceed')
    {
        Write-Host "[PASS] Function uses `$decision.ShouldProceed" -ForegroundColor Green
    }
    else
    {
        Write-Host "[FAIL] Function does not use `$decision.ShouldProceed" -ForegroundColor Red
        $testPassed = $false
    }
}
catch
{
    Write-Host "[FAIL] Exception: $_" -ForegroundColor Red
}

if (-not $testPassed)
{
    Write-Host "`n[OVERALL] TEST FAILED" -ForegroundColor Red
    exit 1
}

# Test 3: Verify mode banners are present
Write-Host "`n[TEST 3] Verify mode banners and feedback" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Gray

$testPassed = $false
try
{
    $functionCode = (Get-Command Get-AutopilotProfileArrayInput).ScriptBlock.ToString()
    
    $checks = @(
        @{ Pattern = 'MODE: REPLACE - Old profiles will be removed'; Description = 'Replace mode banner' }
        @{ Pattern = 'MODE: ADD - New profiles will be added'; Description = 'Add mode banner' }
        @{ Pattern = '\[!\] REPLACE MODE:'; Description = 'Replace mode indicator' }
        @{ Pattern = '\[\+\] ADD MODE:'; Description = 'Add mode indicator' }
        @{ Pattern = 'SUMMARY - REPLACE MODE'; Description = 'Replace summary' }
        @{ Pattern = 'SUMMARY - ADD MODE'; Description = 'Add summary' }
        @{ Pattern = 'NO CHANGES - Keeping .* existing profiles'; Description = 'Keep unchanged banner' }
    )
    
    $allPassed = $true
    foreach ($check in $checks)
    {
        if ($functionCode -match [regex]::Escape($check.Pattern))
        {
            Write-Host "[PASS] Found: $($check.Description)" -ForegroundColor Green
        }
        else
        {
            Write-Host "[FAIL] Missing: $($check.Description)" -ForegroundColor Red
            $allPassed = $false
        }
    }
    
    $testPassed = $allPassed
}
catch
{
    Write-Host "[FAIL] Exception: $_" -ForegroundColor Red
}

if (-not $testPassed)
{
    Write-Host "`n[OVERALL] TEST FAILED" -ForegroundColor Red
    exit 1
}

# Test 4: Verify ASCII characters (no Unicode)
Write-Host "`n[TEST 4] Verify ASCII characters only" -ForegroundColor Yellow
Write-Host "=======================================" -ForegroundColor Gray

$testPassed = $false
try
{
    $functionCode = (Get-Command Get-AutopilotProfileArrayInput).ScriptBlock.ToString()
    
    # Check for Unicode characters that should have been replaced
    $unicodePatterns = @(
        @{ Char = '\u2713'; Name = 'Checkmark' }
        @{ Char = '\u2192'; Name = 'Arrow' }
        @{ Char = '\u2550'; Name = 'Box drawing' }
        @{ Char = '\u26a0'; Name = 'Warning sign' }
    )
    
    $allPassed = $true
    foreach ($pattern in $unicodePatterns)
    {
        if ($functionCode -match $pattern.Char)
        {
            Write-Host "[FAIL] Found Unicode character: $($pattern.Name)" -ForegroundColor Red
            $allPassed = $false
        }
    }
    
    if ($allPassed)
    {
        Write-Host "[PASS] No Unicode characters found - using ASCII only" -ForegroundColor Green
        $testPassed = $true
    }
}
catch
{
    Write-Host "[FAIL] Exception: $_" -ForegroundColor Red
}

if (-not $testPassed)
{
    Write-Host "`n[OVERALL] TEST FAILED" -ForegroundColor Red
    exit 1
}

Write-Host "`n===============================================================" -ForegroundColor Cyan
Write-Host "  ALL TESTS PASSED" -ForegroundColor Green
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor White
Write-Host "  [+] Get-EditorReplaceOrAddChoice integrated correctly" -ForegroundColor Green
Write-Host "  [+] Decision object pattern implemented" -ForegroundColor Green
Write-Host "  [+] Mode banners and feedback messages present" -ForegroundColor Green
Write-Host "  [+] ASCII characters only (PowerShell 5.1 compatible)" -ForegroundColor Green
Write-Host ""

exit 0

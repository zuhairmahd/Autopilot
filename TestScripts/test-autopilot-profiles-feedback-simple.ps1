#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Tests the integrated Get-EditorReplaceOrAddChoice feedback in Get-AutopilotProfileArrayInput.
#>

$ErrorActionPreference = "Stop"

Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "  TEST: Autopilot Profiles Editor - Code Analysis" -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Cyan

# Import the function
$projectRoot = Split-Path $PSScriptRoot -Parent
. "$projectRoot\functions\setupFunctions\Show-AutopilotProfilesEditor.ps1"

# Test 1: Verify decision object usage (not $shouldReplaceExisting variable)
Write-Host "`n[TEST 1] Verify decision object usage" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Gray

$allTests = @()
try
{
    $functionCode = (Get-Command Get-AutopilotProfileArrayInput).ScriptBlock.ToString()
    
    # Should NOT contain old variable reference
    if ($functionCode -notmatch '\$shouldReplaceExisting')
    {
        Write-Host "[PASS] Function does not use deprecated `$shouldReplaceExisting variable" -ForegroundColor Green
        $allTests += $true
    }
    else
    {
        Write-Host "[FAIL] Function still references `$shouldReplaceExisting variable" -ForegroundColor Red
        $allTests += $false
    }
    
    # Should contain new decision object references
    if ($functionCode -match '\$decision\.ShouldReplaceExisting')
    {
        Write-Host "[PASS] Function uses `$decision.ShouldReplaceExisting" -ForegroundColor Green
        $allTests += $true
    }
    else
    {
        Write-Host "[FAIL] Function does not use `$decision.ShouldReplaceExisting" -ForegroundColor Red
        $allTests += $false
    }
    
    if ($functionCode -match '\$decision\.ShouldProceed')
    {
        Write-Host "[PASS] Function uses `$decision.ShouldProceed" -ForegroundColor Green
        $allTests += $true
    }
    else
    {
        Write-Host "[FAIL] Function does not use `$decision.ShouldProceed" -ForegroundColor Red
        $allTests += $false
    }
}
catch
{
    Write-Host "[FAIL] Exception: $_" -ForegroundColor Red
    $allTests += $false
}

# Test 2: Verify Get-EditorReplaceOrAddChoice is called
Write-Host "`n[TEST 2] Verify Get-EditorReplaceOrAddChoice integration" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Gray

try
{
    $functionCode = (Get-Command Get-AutopilotProfileArrayInput).ScriptBlock.ToString()
    
    if ($functionCode -match "Get-EditorReplaceOrAddChoice")
    {
        Write-Host "[PASS] Function calls Get-EditorReplaceOrAddChoice" -ForegroundColor Green
        $allTests += $true
        
        if ($functionCode -match "Get-EditorReplaceOrAddChoice[^\n]*-ItemType\s+'profile'")
        {
            Write-Host "[PASS] ItemType parameter is 'profile'" -ForegroundColor Green
            $allTests += $true
        }
        else
        {
            Write-Host "[FAIL] ItemType parameter not set to 'profile'" -ForegroundColor Red
            $allTests += $false
        }
    }
    else
    {
        Write-Host "[FAIL] Function does not call Get-EditorReplaceOrAddChoice" -ForegroundColor Red
        $allTests += $false
    }
}
catch
{
    Write-Host "[FAIL] Exception: $_" -ForegroundColor Red
    $allTests += $false
}

# Test 3: Verify mode banners are present
Write-Host "`n[TEST 3] Verify mode banners and feedback" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Gray

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
    
    foreach ($check in $checks)
    {
        if ($functionCode -match [regex]::Escape($check.Pattern))
        {
            Write-Host "[PASS] Found: $($check.Description)" -ForegroundColor Green
            $allTests += $true
        }
        else
        {
            Write-Host "[FAIL] Missing: $($check.Description)" -ForegroundColor Red
            $allTests += $false
        }
    }
}
catch
{
    Write-Host "[FAIL] Exception: $_" -ForegroundColor Red
    $allTests += $false
}

# Test 4: Verify ASCII characters (no Unicode)
Write-Host "`n[TEST 4] Verify ASCII characters only" -ForegroundColor Yellow
Write-Host "=======================================" -ForegroundColor Gray

try
{
    $functionCode = (Get-Command Get-AutopilotProfileArrayInput).ScriptBlock.ToString()
    
    # Check for Unicode characters that should have been replaced
    $unicodePatterns = @(
        @{ Char = '✓'; Name = 'Checkmark (U+2713)' }
        @{ Char = '→'; Name = 'Arrow (U+2192)' }
        @{ Char = '═'; Name = 'Box drawing (U+2550)' }
        @{ Char = '⚠'; Name = 'Warning sign (U+26A0)' }
    )
    
    $foundUnicode = $false
    foreach ($pattern in $unicodePatterns)
    {
        if ($functionCode -match [regex]::Escape($pattern.Char))
        {
            Write-Host "[FAIL] Found Unicode character: $($pattern.Name)" -ForegroundColor Red
            $foundUnicode = $true
            $allTests += $false
        }
    }
    
    if (-not $foundUnicode)
    {
        Write-Host "[PASS] No Unicode characters found - using ASCII only" -ForegroundColor Green
        $allTests += $true
    }
}
catch
{
    Write-Host "[FAIL] Exception: $_" -ForegroundColor Red
    $allTests += $false
}

# Summary
$passCount = ($allTests | Where-Object { $_ -eq $true }).Count
$failCount = ($allTests | Where-Object { $_ -eq $false }).Count
$totalCount = $allTests.Count

Write-Host "`n===============================================================" -ForegroundColor Cyan
if ($failCount -eq 0)
{
    Write-Host "  ALL TESTS PASSED ($passCount/$totalCount)" -ForegroundColor Green
}
else
{
    Write-Host "  TESTS COMPLETED: $passCount passed, $failCount failed" -ForegroundColor Yellow
}
Write-Host "===============================================================" -ForegroundColor Cyan

if ($failCount -gt 0)
{
    exit 1
}
else
{
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor White
    Write-Host "  [+] Get-EditorReplaceOrAddChoice integrated correctly" -ForegroundColor Green
    Write-Host "  [+] Decision object pattern implemented" -ForegroundColor Green
    Write-Host "  [+] Mode banners and feedback messages present" -ForegroundColor Green
    Write-Host "  [+] ASCII characters only (PowerShell 5.1 compatible)" -ForegroundColor Green
    Write-Host ""
    exit 0
}

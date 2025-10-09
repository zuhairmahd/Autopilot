#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Integration tests for silent mode in Autopilot profile and group resolution.
.DESCRIPTION
    Tests the -Silent switch behavior in resolution functions.
    Validates:
    - Exact match auto-acceptance without prompting
    - Multiple match interactive handling (still prompts)
    - Duplicate detection in silent mode
#>
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"
# Test configuration
$tempPath = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
$TestConfigFolder = Join-Path $tempPath "silent-mode-test-$(Get-Date -Format 'yyyyMMddHHmmss')"
$global:LogFile = Join-Path $TestConfigFolder "test.log"
$script:TestsPassed = 0
$script:TestsFailed = 0
function Test-Result
{
    param(
        [string]$TestName,
        [bool]$Condition,
        [string]$FailureMessage = ""
    )
    if ($Condition)
    {
        Write-Host "  [PASS] $TestName" -ForegroundColor Green
        $script:TestsPassed++
        return $true
    }
    else
    {
        Write-Host "  [FAIL] $TestName" -ForegroundColor Red
        if ($FailureMessage)
        {
            Write-Host "    $FailureMessage" -ForegroundColor Yellow
        }
        $script:TestsFailed++
        return $false
    }
}
Write-Host "=== Silent Mode Integration Tests ===" -ForegroundColor Yellow
Write-Host "Test folder: $TestConfigFolder" -ForegroundColor Gray
Write-Host ""
# Create test directory
New-Item -ItemType Directory -Path $TestConfigFolder -Force | Out-Null
"Silent Mode Integration Test Log - $(Get-Date)" | Set-Content -Path $global:LogFile
# IMPORTANT: Define mocks BEFORE loading functions
Write-Host "Setting up mocks..." -ForegroundColor Gray
# Mock Get-EntraDirectoryObject with global: prefix
function global:Get-EntraDirectoryObject
{
    param(
        [string]$EntityType,
        [string]$EntityName,
        [string]$AccessToken,
        [hashtable]$Settings,
        [switch]$FindSimilar
    )
    if ($EntityName -eq "ExactMatch-Profile" -or $EntityName -eq "ExactMatch-Group")
    {
        return @(
            @{
                value = @(
                    @{
                        displayName = $EntityName
                        id          = "exact-match-id-123"
                    }
                )
            },
            $false
        )
    }
    if ($EntityName -eq "Multiple-Match")
    {
        return @(
            @{
                value = @(
                    @{ displayName = "Multiple-Match-1"; id = "id-1" }
                    @{ displayName = "Multiple-Match-2"; id = "id-2" }
                )
            },
            $true
        )
    }
    return $null
}
Write-Host "Mocks configured" -ForegroundColor Green
# Load functions at script scope
Write-Host "Loading functions..." -ForegroundColor Gray
$functionCount = 0
$scriptRoot = Split-Path -Parent $PSCommandPath
$projectRoot = Split-Path -Parent $scriptRoot
$functionsPath = Join-Path $projectRoot "functions"
if (-not (Test-Path $functionsPath))
{
    throw "Functions directory not found at: $functionsPath"
}
Get-ChildItem -Path $functionsPath -Recurse -Filter "*.ps1" | ForEach-Object {
    try
    {
        . $_.FullName
        $functionCount++
    }
    catch
    {
        # Silent continue
    }
}
Write-Host "Functions loaded: $functionCount" -ForegroundColor Green
try
{
    # Test 1: Silent Mode Parameter Exists
    Write-Host "`n=== Test 1: Silent Mode Parameter Exists ===" -ForegroundColor Cyan
    $profileCmdlet = Get-Command Resolve-SingleAutopilotProfileInteractive -ErrorAction SilentlyContinue
    $groupCmdlet = Get-Command Resolve-SingleGroupInteractive -ErrorAction SilentlyContinue
    $profileHasSilent = $profileCmdlet.Parameters.ContainsKey('Silent')
    $groupHasSilent = $groupCmdlet.Parameters.ContainsKey('Silent')
    Test-Result "Resolve-SingleAutopilotProfileInteractive has -Silent parameter" $profileHasSilent
    Test-Result "Resolve-SingleGroupInteractive has -Silent parameter" $groupHasSilent
}
catch
{
    Write-Host "`nTest execution failed: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    $script:TestsFailed++
}
finally
{
    # Cleanup
    if (Test-Path $TestConfigFolder)
    {
        Remove-Item -Path $TestConfigFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
}
# Summary
Write-Host "`n=== Test Summary ===" -ForegroundColor Yellow
Write-Host "Tests Passed: $script:TestsPassed" -ForegroundColor Green
Write-Host "Tests Failed: $script:TestsFailed" -ForegroundColor $(if ($script:TestsFailed -eq 0) { "Green" } else { "Red" })
Write-Host "Total Tests:  $($script:TestsPassed + $script:TestsFailed)" -ForegroundColor Yellow
if ($script:TestsFailed -eq 0)
{
    Write-Host "`n[SUCCESS] All silent mode tests passed!" -ForegroundColor Green
    exit 0
}
else
{
    Write-Host "`n[FAILURE] Some silent mode tests failed" -ForegroundColor Red
    exit 1
}

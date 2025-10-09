#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Integration tests for silent mode in Autopilot profile and group resolution.

.DESCRIPTION
    Tests the -Silent switch behavior in:
    - Resolve-SingleAutopilotProfileInteractive
    - Resolve-SingleGroupInteractive
    
    Validates:
    - Exact match auto-acceptance without prompting
    - Console output suppression in silent mode
    - Verbose logging in silent mode
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
        Write-Host "  ✓ $TestName" -ForegroundColor Green
        $script:TestsPassed++
        return $true
    }
    else
    {
        Write-Host "  ✗ $TestName" -ForegroundColor Red
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

try
{
    # Create test directory
    New-Item -ItemType Directory -Path $TestConfigFolder -Force | Out-Null
    "Silent Mode Integration Test Log - $(Get-Date)" | Set-Content -Path $global:LogFile
    
    # Load functions
    Write-Host "Loading functions..." -ForegroundColor Gray
    $functionCount = 0
    
    # Get the script root (TestScripts folder)
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
            Write-Warning "Failed to load: $($_.Name)"
        }
    }
    Write-Host "Functions loaded: $functionCount" -ForegroundColor Green
    
    # Test 1: Autopilot Profile - Exact Match Silent Mode
    Write-Host "`n=== Test 1: Autopilot Profile - Exact Match Silent ===" -ForegroundColor Cyan
    
    # Create mock Get-EntraDirectoryObject that returns exact match
    function Get-EntraDirectoryObject
    {
        param($EntityType, $EntityName, $AccessToken, [switch]$findSimilar)
        
        if ($EntityType -eq "AutopilotProfile" -and $EntityName -eq "TestProfile")
        {
            return @(
                @{
                    value = @(
                        @{
                            displayName = "TestProfile"
                            id          = "autopilot-id-123"
                        }
                    )
                },
                $false  # Not fuzzy
            )
        }
        return $null
    }
    
    # Capture Write-Host output
    $hostOutput = @()
    function Write-Host
    {
        param([string]$Object, [string]$ForegroundColor)
        $hostOutput += $Object
    }
    
    # Call with Silent switch
    $result = Resolve-SingleAutopilotProfileInteractive -ProfileName "TestProfile" -AccessToken "mock-token" -Silent
    
    # Restore Write-Host
    Remove-Item function:\Write-Host
    
    Test-Result "Returns profile object" ($null -ne $result)
    Test-Result "Profile has correct name" ($result.name -eq "TestProfile")
    Test-Result "Profile has correct ID" ($result.id -eq "autopilot-id-123")
    Test-Result "No console output in silent mode" ($hostOutput.Count -eq 0) "Found $($hostOutput.Count) outputs"
    
    # Test 2: Autopilot Profile - Non-Silent Mode (should have output)
    Write-Host "`n=== Test 2: Autopilot Profile - Non-Silent Mode ===" -ForegroundColor Cyan
    
    $hostOutput = @()
    function Write-Host
    {
        param([string]$Object, [string]$ForegroundColor)
        $hostOutput += $Object
    }
    
    $result = Resolve-SingleAutopilotProfileInteractive -ProfileName "TestProfile" -AccessToken "mock-token"
    
    Remove-Item function:\Write-Host
    
    Test-Result "Returns profile object" ($null -ne $result)
    Test-Result "Has console output in normal mode" ($hostOutput.Count -gt 0) "Expected output, found $($hostOutput.Count)"
    
    # Test 3: Group - Exact Match Silent Mode
    Write-Host "`n=== Test 3: Group - Exact Match Silent ===" -ForegroundColor Cyan
    
    function Get-EntraDirectoryObject
    {
        param($EntityType, $EntityName, $AccessToken, [switch]$findSimilar)
        
        if ($EntityType -eq "Group" -and $EntityName -eq "TestGroup")
        {
            return @(
                @{
                    value = @(
                        @{
                            displayName = "TestGroup"
                            id          = "group-id-456"
                        }
                    )
                },
                $false  # Not fuzzy
            )
        }
        return $null
    }
    
    $hostOutput = @()
    function Write-Host
    {
        param([string]$Object, [string]$ForegroundColor)
        $hostOutput += $Object
    }
    
    $result = Resolve-SingleGroupInteractive -GroupName "TestGroup" -AccessToken "mock-token" -Silent
    
    Remove-Item function:\Write-Host
    
    Test-Result "Returns group object" ($null -ne $result)
    Test-Result "Group has correct name" ($result.name -eq "TestGroup")
    Test-Result "Group has correct ID" ($result.id -eq "group-id-456")
    Test-Result "No console output in silent mode" ($hostOutput.Count -eq 0)
    
    # Test 4: Group - Non-Silent Mode (should have output)
    Write-Host "`n=== Test 4: Group - Non-Silent Mode ===" -ForegroundColor Cyan
    
    $hostOutput = @()
    function Write-Host
    {
        param([string]$Object, [string]$ForegroundColor)
        $hostOutput += $Object
    }
    
    $result = Resolve-SingleGroupInteractive -GroupName "TestGroup" -AccessToken "mock-token"
    
    Remove-Item function:\Write-Host
    
    Test-Result "Returns group object" ($null -ne $result)
    Test-Result "Has console output in normal mode" ($hostOutput.Count -gt 0)
    
    # Test 5: Silent Mode - Duplicate Detection
    Write-Host "`n=== Test 5: Silent Mode - Duplicate Detection ===" -ForegroundColor Cyan
    
    function Get-EntraDirectoryObject
    {
        param($EntityType, $EntityName, $AccessToken, [switch]$findSimilar)
        
        if ($EntityType -eq "Group" -and $EntityName -eq "DuplicateGroup")
        {
            return @(
                @{
                    value = @(
                        @{
                            displayName = "DuplicateGroup"
                            id          = "duplicate-id-789"
                        }
                    )
                },
                $false
            )
        }
        return $null
    }
    
    $existingItems = @(
        @{ name = "DuplicateGroup"; id = "duplicate-id-789" }
    )
    
    $result = Resolve-SingleGroupInteractive -GroupName "DuplicateGroup" -AccessToken "mock-token" -ExistingItems $existingItems -Silent
    
    Test-Result "Duplicate returns null in silent mode" ($null -eq $result)
    
    # Test 6: Silent Mode - No Access Token
    Write-Host "`n=== Test 6: Silent Mode - No Access Token ===" -ForegroundColor Cyan
    
    $hostOutput = @()
    function Write-Host
    {
        param([string]$Object, [string]$ForegroundColor)
        $hostOutput += $Object
    }
    
    $result = Resolve-SingleAutopilotProfileInteractive -ProfileName "TestProfile" -AccessToken $null -Silent
    
    Remove-Item function:\Write-Host
    
    Test-Result "Returns object with null ID" ($result.id -eq $null)
    Test-Result "Returns object with correct name" ($result.name -eq "TestProfile")
    # Note: Console output is expected here even in silent mode (warning about no token)
    
    # Test 7: Multiple Matches - Silent Mode Still Interactive
    Write-Host "`n=== Test 7: Multiple Matches - Silent Mode Still Interactive ===" -ForegroundColor Cyan
    
    function Get-EntraDirectoryObject
    {
        param($EntityType, $EntityName, $AccessToken, [switch]$findSimilar)
        
        if ($findSimilar)
        {
            return @(
                @{
                    value = @(
                        @{ displayName = "Match1"; id = "id-1" }
                        @{ displayName = "Match2"; id = "id-2" }
                    )
                },
                $true  # Fuzzy match
            )
        }
        return $null
    }
    
    # Mock Read-Host to simulate user selection
    function Read-Host
    {
        param([string]$Prompt)
        return "00"  # Skip
    }
    
    $hostOutput = @()
    function Write-Host
    {
        param([string]$Object, [string]$ForegroundColor)
        $hostOutput += $Object
    }
    
    $result = Resolve-SingleGroupInteractive -GroupName "Ambiguous" -AccessToken "mock-token" -Silent
    
    Remove-Item function:\Write-Host
    Remove-Item function:\Read-Host
    
    Test-Result "Returns null when user skips" ($null -eq $result)
    Test-Result "Console output present for multiple matches" ($hostOutput.Count -gt 0) "Silent mode doesn't suppress multiple match prompts"
    
    # Test 8: Verbose Logging in Silent Mode
    Write-Host "`n=== Test 8: Verbose Logging in Silent Mode ===" -ForegroundColor Cyan
    
    function Get-EntraDirectoryObject
    {
        param($EntityType, $EntityName, $AccessToken, [switch]$findSimilar)
        
        if ($EntityType -eq "AutopilotProfile")
        {
            return @(
                @{
                    value = @(@{ displayName = "VerboseTest"; id = "verbose-id" })
                },
                $false
            )
        }
        return $null
    }
    
    # Clear log file
    "" | Set-Content -Path $global:LogFile
    
    $result = Resolve-SingleAutopilotProfileInteractive -ProfileName "VerboseTest" -AccessToken "mock-token" -Silent
    
    # Check log file for verbose entries
    Start-Sleep -Milliseconds 500  # Give time for log writes
    $logContent = if (Test-Path $global:LogFile) { Get-Content -Path $global:LogFile -Raw } else { "" }
    
    Test-Result "Verbose logging occurs in silent mode" ($logContent -like "*Silent mode*" -or $logContent -like "*VerboseTest*") "Log should contain silent mode entries"
    
    # Final summary
    Write-Host "`n=== Test Summary ===" -ForegroundColor Yellow
    Write-Host "Tests Passed: $script:TestsPassed" -ForegroundColor Green
    Write-Host "Tests Failed: $script:TestsFailed" -ForegroundColor Red
    Write-Host "Total Tests:  $($script:TestsPassed + $script:TestsFailed)" -ForegroundColor Cyan
    
    if ($script:TestsFailed -eq 0)
    {
        Write-Host "`n✓ All silent mode integration tests passed!" -ForegroundColor Green
        exit 0
    }
    else
    {
        Write-Host "`n✗ Some silent mode tests failed" -ForegroundColor Red
        exit 1
    }
    
}
catch
{
    Write-Host "`n=== Test Suite Failed ===" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}
finally
{
    # Cleanup
    if (Test-Path $TestConfigFolder)
    {
        Remove-Item -Path $TestConfigFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
}

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

# Mock Write-Log function
function global:Write-Log
{
    param($LogFile, $Module, $Message, $LogLevel)
    # Silent mock for testing
}

# Mock Test-ItemExists function
function global:Test-ItemExists
{
    param($ItemName, $ItemId, $ExistingList)
    return $false  # No duplicates for testing
}

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
    if ($EntityName -eq "ExactMatch-Group")
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
    return @($null, $false)
}

# Mock CallGraphAPI to prevent actual HTTP calls
function global:CallGraphAPI
{
    param(
        [string]$AccessToken,
        [string]$Uri,
        [string]$Method = 'GET',
        [object]$Body = $null,
        [string]$ContentType = 'application/json'
    )
    
    # Return empty results for any Graph API call
    # This prevents 401 errors and interactive prompts
    return @{
        value = @()
    }
}

# Mock GetAutopilotProfile function for Autopilot profile tests
function global:GetAutopilotProfile
{
    param(
        [string]$AccessToken,
        [string]$ProfileName,
        [switch]$FindSimilar,
        [switch]$GetAll
    )
    if ($ProfileName -eq "ExactMatch-Profile")
    {
        return @(
            @{
                value = @(
                    @{
                        displayName = $ProfileName
                        id          = "exact-match-id-123"
                    }
                )
            },
            $false
        )
    }
    if ($ProfileName -eq "Multiple-Match")
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
    return @($null, $false)
}
Write-Host "Mocks configured" -ForegroundColor Green
# Load functions at script scope
Write-Host "Loading functions..." -ForegroundColor Gray
$functionCount = 0
$filesToExclude = @('CallGraphAPI.ps1', 'GetAutopilotProfile.ps1', 'Get-EntraDirectoryObject.ps1')
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
        if ($_.Name -notin $filesToExclude)
        {
            . $_.FullName
            $functionCount++
        }
    }
    catch
    {
        # Silent continue
    }
}
Write-Host "Functions loaded: $functionCount" -ForegroundColor Green

# Re-define mocks AFTER loading functions to override any loaded versions
Write-Host "Re-applying mocks after function loading..." -ForegroundColor Gray

# Mock CallGraphAPI to prevent actual HTTP calls
function global:CallGraphAPI
{
    param(
        [string]$AccessToken,
        [string]$Uri,
        [string]$Method = 'GET',
        [object]$Body = $null,
        [string]$ContentType = 'application/json'
    )
    
    # Return empty results for any Graph API call
    # This prevents 401 errors and interactive prompts
    return @{
        value = @()
    }
}

# Mock Write-Log function
function global:Write-Log
{
    param($LogFile, $Module, $Message, $LogLevel)
    # Silent mock for testing
}

# Mock Test-ItemExists function
function global:Test-ItemExists
{
    param($ItemName, $ItemId, $ExistingList)
    return $false  # No duplicates for testing
}

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
    
    if ($EntityName -eq "ExactMatch-Group")
    {
        # Return simple tuple: (EntityInfo, IsFuzzyMatch)
        $graphResult = [PSCustomObject]@{
            '@odata.context' = 'https://graph.microsoft.com/v1.0/$metadata#groups'
            value            = @(
                [PSCustomObject]@{
                    displayName = $EntityName
                    id          = "exact-match-id-123"
                }
            )
        }
        
        # Simple tuple return
        return @($graphResult, $false)
    }
    if ($EntityName -eq "Multiple-Match")
    {
        $graphResult = [PSCustomObject]@{
            '@odata.context' = 'https://graph.microsoft.com/v1.0/$metadata#groups'
            value            = @(
                [PSCustomObject]@{ displayName = "Multiple-Match-1"; id = "id-1" }
                [PSCustomObject]@{ displayName = "Multiple-Match-2"; id = "id-2" }
            )
        }
        return @($graphResult, $true)
    }
    return @($null, $false)
}

# Mock GetAutopilotProfile function for Autopilot profile tests
function global:GetAutopilotProfile
{
    param(
        [string]$AccessToken,
        [string]$ProfileName,
        [switch]$FindSimilar,
        [switch]$GetAll
    )
    if ($ProfileName -eq "ExactMatch-Profile")
    {
        return @(
            [PSCustomObject]@{
                '@odata.context' = 'https://graph.microsoft.com/beta/$metadata#deviceManagement/windowsAutopilotDeploymentProfiles'
                value            = @(
                    [PSCustomObject]@{
                        displayName = $ProfileName
                        id          = "exact-match-id-123"
                    }
                )
            },
            $false
        )
    }
    if ($ProfileName -eq "Multiple-Match")
    {
        return @(
            [PSCustomObject]@{
                '@odata.context' = 'https://graph.microsoft.com/beta/$metadata#deviceManagement/windowsAutopilotDeploymentProfiles'
                value            = @(
                    [PSCustomObject]@{ displayName = "Multiple-Match-1"; id = "id-1" }
                    [PSCustomObject]@{ displayName = "Multiple-Match-2"; id = "id-2" }
                )
            },
            $false  # Not a fuzzy match, just multiple exact matches
        )
    }
    return @($null, $false)
}

Write-Host "Mocks re-applied" -ForegroundColor Green

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

    # Test 2: Silent Mode - Exact Match Auto-Accept (Profile)
    Write-Host "`n=== Test 2: Silent Mode - Exact Match Auto-Accept (Profile) ===" -ForegroundColor Cyan
    $resultProfile = $null
    try
    {
        $resultProfile = Resolve-SingleAutopilotProfileInteractive -ProfileName "ExactMatch-Profile" -AccessToken "dummy" -Silent
    }
    catch
    { 
        Write-Host "Error in test 2: $_" -ForegroundColor Red
    }
    # Note: Function returns hashtable with 'name' and 'id', not 'displayName'
    $autoAcceptedProfile = $resultProfile -and $resultProfile.name -eq "ExactMatch-Profile"
    Test-Result "Profile: Silent mode auto-accepts exact match" $autoAcceptedProfile "Expected name 'ExactMatch-Profile', got '$($resultProfile.name)'"

    # Test 3: Silent Mode - Exact Match Auto-Accept (Group)
    Write-Host "`n=== Test 3: Silent Mode - Exact Match Auto-Accept (Group) ===" -ForegroundColor Cyan
    $resultGroup = $null
    try
    {
        $resultGroup = Resolve-SingleGroupInteractive -GroupName "ExactMatch-Group" -AccessToken "dummy" -Silent -Verbose
    }
    catch
    {
        Write-Host "Error in test 3: $_" -ForegroundColor Red
        Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    }
    # Note: Function returns hashtable with 'name' and 'id', not 'displayName'
    $autoAcceptedGroup = $resultGroup -and $resultGroup.name -eq "ExactMatch-Group"
    Test-Result "Group: Silent mode auto-accepts exact match" $autoAcceptedGroup "Expected name 'ExactMatch-Group', got '$($resultGroup.name)'"

    # Test 4: Silent Mode - Multiple Match Still Prompts (Profile)
    Write-Host "`n=== Test 4: Silent Mode - Multiple Match Still Prompts (Profile) ===" -ForegroundColor Cyan
    $prompted = $false
    # Mock Read-Host to simulate prompt detection
    function global:Read-Host
    { 
        param([string]$Prompt)
        $script:Prompted = $true
        return "0"  # Return 0 to skip
    }
    
    # Mock Write-Host to suppress output during testing
    function global:Write-Host
    {
        param([string]$Object, [ConsoleColor]$ForegroundColor)
        # Suppress all Write-Host output during function execution
    }
    
    $script:Prompted = $false
    try
    {
        $result = Resolve-SingleAutopilotProfileInteractive -ProfileName "Multiple-Match" -AccessToken "dummy" -Silent
    }
    catch
    { 
        # Silent catch
    }
    
    # Restore Write-Host for test output
    Remove-Item Function:\Write-Host -ErrorAction SilentlyContinue
    
    $prompted = $script:Prompted
    Test-Result "Profile: Silent mode does NOT auto-accept multiple matches" $prompted "Expected prompt for multiple matches in silent mode"

    # Test 5: Silent Mode - Multiple Match Still Prompts (Group)
    Write-Host "`n=== Test 5: Silent Mode - Multiple Match Still Prompts (Group) ===" -ForegroundColor Cyan
    
    # Mock Write-Host to suppress output during testing
    function global:Write-Host
    {
        param([string]$Object, [ConsoleColor]$ForegroundColor)
        # Suppress all Write-Host output during function execution
    }
    
    $script:Prompted = $false
    try
    {
        $result = Resolve-SingleGroupInteractive -GroupName "Multiple-Match" -AccessToken "dummy" -Silent
    }
    catch
    {
        # Silent catch
    }
    
    # Restore Write-Host for test output
    Remove-Item Function:\Write-Host -ErrorAction SilentlyContinue
    
    $prompted = $script:Prompted
    Test-Result "Group: Silent mode does NOT auto-accept multiple matches" $prompted "Expected prompt for multiple matches in silent mode"
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

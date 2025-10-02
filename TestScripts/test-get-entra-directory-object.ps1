#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Comprehensive tests for Get-EntraDirectoryObject function
.DESCRIPTION
    Tests the unified directory object retrieval function covering:
    - User search (exact, fuzzy, none)
    - Group search (exact, fuzzy, none)
    - Caching behavior for both types
    - Exclusion patterns
    - Error handling
    - Access token validation
.NOTES
    Author: Windows Autopilot Management Tool Team
    Version: 1.0.0
    Test Category: unit, integration
    Dependencies: Get-EntraDirectoryObject, CallGraphAPI
#>

[CmdletBinding()]
param(
    [switch]$Interactive
)

# Test configuration
$script:TestName = "Get-EntraDirectoryObject"
$script:TestsPassed = 0
$script:TestsFailed = 0
$script:TestsSkipped = 0

#region Helper Functions
function Write-TestHeader
{
    param([string]$Message)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " $Message" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
}

function Write-TestSection
{
    param([string]$Message)
    Write-Host "`n--- $Message ---" -ForegroundColor Yellow
}

function Write-TestResult
{
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Details = ""
    )
    
    if ($Passed)
    {
        Write-Host "[PASS] $TestName" -ForegroundColor Green
        $script:TestsPassed++
    }
    else
    {
        Write-Host "[FAIL] $TestName" -ForegroundColor Red
        $script:TestsFailed++
        if ($Details)
        {
            Write-Host "       Details: $Details" -ForegroundColor Red
        }
    }
}

function Write-TestSummary
{
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " Test Summary: $script:TestName" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Passed:  $script:TestsPassed" -ForegroundColor Green
    Write-Host "Failed:  $script:TestsFailed" -ForegroundColor Red
    Write-Host "Skipped: $script:TestsSkipped" -ForegroundColor Yellow
    Write-Host "Total:   $($script:TestsPassed + $script:TestsFailed + $script:TestsSkipped)" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    return ($script:TestsFailed -eq 0)
}
#endregion

#region Setup Test Environment
Write-TestHeader "Setting Up Test Environment"

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptPath
$functionsPath = Join-Path $projectRoot "functions"
$userFunctionsPath = Join-Path $functionsPath "UserAndGroupFunctions"

try
{
    . (Join-Path $userFunctionsPath "Get-EntraDirectoryObject.ps1")
    Write-Host "[OK] Get-EntraDirectoryObject loaded" -ForegroundColor Green
}
catch
{
    Write-Host "[ERROR] Failed to load function: $_" -ForegroundColor Red
    exit 1
}

# Mock global variables
$global:LogFile = Join-Path $scriptPath "test-get-entra-directory-object.log"
$global:returnValues = @{
    noUserFoundInDirectoryMessage = "User not found in directory"
    noGroupFoundMessage           = "Group not found"
    noAccessTokenMessage          = "Access token is required"
}

$global:settings = @{
    userPatternsToExclude  = @("admin", "test")
    groupPatternsToExclude = @("Archive", "Disabled")
}

# Mock Write-Log
function Write-Log
{
    param($LogFile, $Module, $Message, $LogLevel)
    if ($VerbosePreference -eq 'Continue')
    {
        Write-Verbose "[$Module] $Message"
    }
}

# Clear caches
$global:DirectoryObjectCache = @{}

# Test data
$script:MockUsers = @{
    "john.doe@contoso.com"   = @{
        userPrincipalName = "john.doe@contoso.com"
        displayName       = "John Doe"
        givenName         = "John"
        surname           = "Doe"
        mail              = "john.doe@contoso.com"
        id                = "user-123"
    }
    "jane.smith@contoso.com" = @{
        userPrincipalName = "jane.smith@contoso.com"
        displayName       = "Jane Smith"
        givenName         = "Jane"
        surname           = "Smith"
        mail              = "jane.smith@contoso.com"
        id                = "user-456"
    }
    "john.admin@contoso.com" = @{
        userPrincipalName = "john.admin@contoso.com"
        displayName       = "John Admin"
        givenName         = "John"
        surname           = "Admin"
        mail              = "john.admin@contoso.com"
        id                = "user-789"
    }
}

$script:MockGroups = @{
    "Marketing Team"    = @{
        displayName = "Marketing Team"
        id          = "group-123"
    }
    "Sales Team"        = @{
        displayName = "Sales Team"
        id          = "group-456"
    }
    "Archive Marketing" = @{
        displayName = "Archive Marketing"
        id          = "group-789"
    }
}

# Mock CallGraphAPI
function CallGraphAPI
{
    param(
        [string]$accessToken,
        [string]$ResourcePath,
        [string]$Filter,
        [string]$ExtraParameters,
        [switch]$consistencyLevel
    )
    
    Write-Verbose "[CallGraphAPI] Called with ResourcePath: $ResourcePath, Filter: $Filter"
    
    # User exact match
    if ($ResourcePath -like "users/*")
    {
        $upn = $ResourcePath -replace "users/", ""
        if ($script:MockUsers.ContainsKey($upn))
        {
            return $script:MockUsers[$upn]
        }
        return 404
    }
    
    # Group exact match
    if ($ResourcePath -eq "groups" -and $Filter -like "displayName eq*")
    {
        $groupName = $Filter -replace "displayName eq '(.+)'", '$1'
        $matching = $script:MockGroups.Values | Where-Object { $_.displayName -eq $groupName }
        if ($matching)
        {
            return [PSCustomObject]@{
                '@odata.context' = 'https://graph.microsoft.com/v1.0/$metadata#groups'
                value            = @($matching)
            }
        }
        return [PSCustomObject]@{ value = @() }
    }
    
    # User fuzzy search
    if ($ResourcePath -eq "users" -and $Filter -like "startswith*")
    {
        $searchTerm = ($Filter -replace "startswith\(givenName, '(.+?)'\).*", '$1').Trim()
        $matching = $script:MockUsers.Values | Where-Object { 
            $_.givenName -like "$searchTerm*" -or $_.surname -like "$searchTerm*" 
        }
        return [PSCustomObject]@{
            '@odata.context' = 'https://graph.microsoft.com/v1.0/$metadata#users'
            value            = @($matching)
        }
    }
    
    # Group fuzzy search - $search
    if ($ResourcePath -eq "groups" -and $ExtraParameters -like "*search=*")
    {
        $searchTerm = [uri]::UnescapeDataString(($ExtraParameters -replace '.*search=([^&]+).*', '$1'))
        $searchTerm = $searchTerm -replace '"displayName:(.+)"', '$1'
        $matching = $script:MockGroups.Values | Where-Object { $_.displayName -like "*$searchTerm*" }
        return [PSCustomObject]@{
            '@odata.context' = 'https://graph.microsoft.com/v1.0/$metadata#groups'
            value            = @($matching)
        }
    }
    
    # Group fuzzy search - startsWith filter
    if ($ResourcePath -eq "groups" -and $Filter -like "startsWith*")
    {
        $searchTerm = $Filter -replace "startsWith\(displayName, '(.+?)'\)", '$1'
        $matching = $script:MockGroups.Values | Where-Object { $_.displayName -like "$searchTerm*" }
        return [PSCustomObject]@{
            '@odata.context' = 'https://graph.microsoft.com/v1.0/$metadata#groups'
            value            = @($matching)
        }
    }
    
    # Group fuzzy search - contains filter
    if ($ResourcePath -eq "groups" -and $Filter -like "contains*")
    {
        $searchTerm = $Filter -replace "contains\(displayName, '(.+?)'\)", '$1'
        $matching = $script:MockGroups.Values | Where-Object { $_.displayName -like "*$searchTerm*" }
        return [PSCustomObject]@{
            '@odata.context' = 'https://graph.microsoft.com/v1.0/$metadata#groups'
            value            = @($matching)
        }
    }
    
    return 404
}

Write-Host "[OK] Test environment ready" -ForegroundColor Green
#endregion

#region Test Cases
Write-TestHeader "Running Test Cases"

#region Test 1: User Exact Match
Write-TestSection "Test 1: User Exact Match"

try
{
    $global:DirectoryObjectCache = @{}
    $result = Get-EntraDirectoryObject -EntityType User -EntityName "john.doe@contoso.com" -AccessToken "test-token"
    
    Write-TestResult "1.1 - User exact match returns result" ($null -ne $result)
    Write-TestResult "1.2 - User exact match returns tuple" ($result -is [array] -and $result.Count -eq 2)
    Write-TestResult "1.3 - User exact match fuzzy flag is false" ($result[1] -eq $false)
    Write-TestResult "1.4 - User exact match returns correct user" ($result[0].value[0].userPrincipalName -eq "john.doe@contoso.com")
}
catch
{
    Write-TestResult "1.1 - User exact match" $false "Exception: $_"
}

#endregion

#region Test 2: Group Exact Match
Write-TestSection "Test 2: Group Exact Match"

try
{
    $global:DirectoryObjectCache = @{}
    $result = Get-EntraDirectoryObject -EntityType Group -EntityName "Marketing Team" -AccessToken "test-token"
    
    Write-TestResult "2.1 - Group exact match returns result" ($null -ne $result)
    Write-TestResult "2.2 - Group exact match returns tuple" ($result -is [array] -and $result.Count -eq 2)
    Write-TestResult "2.3 - Group exact match fuzzy flag is false" ($result[1] -eq $false)
    Write-TestResult "2.4 - Group exact match returns correct group" ($result[0].value[0].displayName -eq "Marketing Team")
}
catch
{
    Write-TestResult "2.1 - Group exact match" $false "Exception: $_"
}

#endregion

#region Test 3: User Fuzzy Search
Write-TestSection "Test 3: User Fuzzy Search"

try
{
    $global:DirectoryObjectCache = @{}
    $result = Get-EntraDirectoryObject -EntityType User -EntityName "john" -AccessToken "test-token" -FindSimilar
    
    Write-TestResult "3.1 - User fuzzy search returns results" ($null -ne $result -and $result[0].value.Count -gt 0)
    Write-TestResult "3.2 - User fuzzy search fuzzy flag is true" ($result[1] -eq $true)
    Write-TestResult "3.3 - User fuzzy search finds John after exclusions" ($result[0].value.Count -ge 1)
    Write-TestResult "3.4 - User fuzzy search excludes admin pattern" (-not ($result[0].value.userPrincipalName -contains "john.admin@contoso.com"))
}
catch
{
    Write-TestResult "3.1 - User fuzzy search" $false "Exception: $_"
}

#endregion

#region Test 4: Group Fuzzy Search
Write-TestSection "Test 4: Group Fuzzy Search"

try
{
    $global:DirectoryObjectCache = @{}
    $result = Get-EntraDirectoryObject -EntityType Group -EntityName "Team" -AccessToken "test-token" -FindSimilar
    
    Write-TestResult "4.1 - Group fuzzy search returns results" ($null -ne $result -and $result[0].value.Count -gt 0)
    Write-TestResult "4.2 - Group fuzzy search fuzzy flag is true" ($result[1] -eq $true)
    Write-TestResult "4.3 - Group fuzzy search finds teams" ($result[0].value.Count -ge 1)
    Write-TestResult "4.4 - Group fuzzy search excludes archive pattern" (-not ($result[0].value.displayName -contains "Archive Marketing"))
}
catch
{
    Write-TestResult "4.1 - Group fuzzy search" $false "Exception: $_"
}

#endregion

#region Test 5: Caching
Write-TestSection "Test 5: Caching Behavior"

try
{
    $global:DirectoryObjectCache = @{}
    
    # First call should cache
    $result1 = Get-EntraDirectoryObject -EntityType User -EntityName "jane.smith@contoso.com" -AccessToken "test-token"
    $cacheSize1 = $global:DirectoryObjectCache.Count
    
    # Second call should use cache
    $result2 = Get-EntraDirectoryObject -EntityType User -EntityName "jane.smith@contoso.com" -AccessToken "test-token"
    $cacheSize2 = $global:DirectoryObjectCache.Count
    
    Write-TestResult "5.1 - First call caches result" ($cacheSize1 -eq 1)
    Write-TestResult "5.2 - Second call uses cache" ($cacheSize2 -eq 1)
    Write-TestResult "5.3 - Cached results match" ($result1[0].value[0].userPrincipalName -eq $result2[0].value[0].userPrincipalName)
    
    # Different EntityType should create separate cache entry
    $null = Get-EntraDirectoryObject -EntityType Group -EntityName "Sales Team" -AccessToken "test-token"
    $cacheSize3 = $global:DirectoryObjectCache.Count
    
    Write-TestResult "5.4 - Different EntityType creates new cache entry" ($cacheSize3 -eq 2)
}
catch
{
    Write-TestResult "5.1 - Caching" $false "Exception: $_"
}

#endregion

#region Test 6: Error Handling
Write-TestSection "Test 6: Error Handling"

try
{
    $result = Get-EntraDirectoryObject -EntityType User -EntityName "" -AccessToken "test-token"
    Write-TestResult "6.1 - Empty EntityName handled" ($result -eq $global:returnValues.noAccessTokenMessage -or $result -eq $global:returnValues.noUserFoundInDirectoryMessage)
}
catch
{
    Write-TestResult "6.1 - Empty EntityName" $false "Exception: $_"
}

try
{
    $result = Get-EntraDirectoryObject -EntityType User -EntityName "test@contoso.com" -AccessToken ""
    Write-TestResult "6.2 - Empty AccessToken returns error" ($result -eq $global:returnValues.noAccessTokenMessage)
}
catch
{
    Write-TestResult "6.2 - Empty AccessToken" $false "Exception: $_"
}

try
{
    $global:DirectoryObjectCache = @{}
    $result = Get-EntraDirectoryObject -EntityType User -EntityName "nonexistent@contoso.com" -AccessToken "test-token"
    Write-TestResult "6.3 - Nonexistent user returns not found" ($result -eq $global:returnValues.noUserFoundInDirectoryMessage)
}
catch
{
    Write-TestResult "6.3 - Nonexistent user" $false "Exception: $_"
}

try
{
    $global:DirectoryObjectCache = @{}
    $result = Get-EntraDirectoryObject -EntityType Group -EntityName "Nonexistent Group" -AccessToken "test-token"
    Write-TestResult "6.4 - Nonexistent group returns not found" ($result -eq $global:returnValues.noGroupFoundMessage)
}
catch
{
    Write-TestResult "6.4 - Nonexistent group" $false "Exception: $_"
}

#endregion

#region Test 7: No Fuzzy Search When Not Requested
Write-TestSection "Test 7: No Fuzzy Search Without FindSimilar"

try
{
    $global:DirectoryObjectCache = @{}
    $result = Get-EntraDirectoryObject -EntityType User -EntityName "nonexistent@contoso.com" -AccessToken "test-token"
    Write-TestResult "7.1 - No fuzzy search without FindSimilar flag" ($result -eq $global:returnValues.noUserFoundInDirectoryMessage)
}
catch
{
    Write-TestResult "7.1 - No fuzzy search" $false "Exception: $_"
}

#endregion

#endregion

#region Cleanup and Summary
Write-TestHeader "Test Execution Complete"

$allTestsPassed = Write-TestSummary

if ($allTestsPassed)
{
    Write-Host "`nAll tests passed successfully!" -ForegroundColor Green
    exit 0
}
else
{
    Write-Host "`nSome tests failed. Please review the results above." -ForegroundColor Red
    exit 1
}
#endregion

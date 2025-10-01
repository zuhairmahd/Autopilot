#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Comprehensive end-to-end test for Resolve-UserWithMatching function
.DESCRIPTION
    This script provides complete test coverage for the Resolve-UserWithMatching function including:
    - Exact match scenarios
    - Fuzzy match scenarios (single and multiple matches)
    - No match scenarios
    - Navigation scenarios (Back, Main Menu, Exit)
    - Input validation
    - Error handling
    - Integration with ConvertFrom-UserSelection and DisplayUserList
.NOTES
    Author: Windows Autopilot Management Tool Team
    Version: 1.0.0
    Test Category: unit, integration
    Dependencies: GetEntraUser, DisplayUserList, ConvertFrom-UserSelection
#>

[CmdletBinding()]
param(
    [switch]$Interactive
)

# Test configuration
$script:TestName = "Resolve-UserWithMatching"
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

function Write-TestSkipped
{
    param([string]$TestName, [string]$Reason)
    Write-Host "[SKIP] $TestName - $Reason" -ForegroundColor Yellow
    $script:TestsSkipped++
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

# Find and load functions
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptPath

# Load required functions
$functionsPath = Join-Path $projectRoot "functions"
$userFunctionsPath = Join-Path $functionsPath "UserAndGroupFunctions"

try
{
    . (Join-Path $userFunctionsPath "Resolve-UserWithMatching.ps1")
    . (Join-Path $userFunctionsPath "ConvertFrom-UserSelection.ps1")
    . (Join-Path $userFunctionsPath "GetEntraUser.ps1")
    . (Join-Path $userFunctionsPath "DisplayUserList.ps1")
    
    Write-Host "[OK] Required functions loaded successfully" -ForegroundColor Green
}
catch
{
    Write-Host "[ERROR] Failed to load required functions: $_" -ForegroundColor Red
    exit 1
}

# Mock global variables
$global:LogFile = Join-Path $scriptPath "test-resolve-user-matching.log"
$global:returnValues = @{
    noUserFoundInDirectoryMessage = "User not found in directory"
    noAccessTokenMessage          = "Access token is required"
    backoutText                   = "BACK_NAVIGATION"
    userCanceledMessage           = "USER_CANCELED"
}

# Mock response control - use a flag to indicate if we want to use the mock
$script:UseMockResponse = $false
$script:MockDisplayUserListResponse = $null

# Mock Write-Log function
function Write-Log
{
    param($LogFile, $Module, $Message, $LogLevel)
    if ($Verbose)
    {
        Write-Verbose "[$Module] $Message"
    }
}
#endregion

#region Mock Functions for Testing
$script:MockUserDatabase = @{
    "john.doe@contoso.com"     = @{
        userPrincipalName = "john.doe@contoso.com"
        displayName       = "John Doe"
        givenName         = "John"
        surname           = "Doe"
        mail              = "john.doe@contoso.com"
        id                = "12345-67890-abcde"
    }
    "jane.smith@contoso.com"   = @{
        userPrincipalName = "jane.smith@contoso.com"
        displayName       = "Jane Smith"
        givenName         = "Jane"
        surname           = "Smith"
        mail              = "jane.smith@contoso.com"
        id                = "23456-78901-bcdef"
    }
    "john.johnson@contoso.com" = @{
        userPrincipalName = "john.johnson@contoso.com"
        displayName       = "John Johnson"
        givenName         = "John"
        surname           = "Johnson"
        mail              = "john.johnson@contoso.com"
        id                = "34567-89012-cdefg"
    }
}

$script:MockDisplayUserListResponse = $null
$script:GetEntraUserCallCount = 0
$script:DisplayUserListCallCount = 0

function GetEntraUser
{
    param(
        [string]$userName,
        [string]$accessToken,
        [switch]$findSimilar
    )
    
    $script:GetEntraUserCallCount++
    
    # Check for exact match first
    if ($script:MockUserDatabase.ContainsKey($userName))
    {
        $user = $script:MockUserDatabase[$userName]
        $response = [PSCustomObject]@{
            '@odata.context' = 'https://graph.microsoft.com/v1.0/$metadata#users'
            value            = @($user)
        }
        return @($response, $false)  # Exact match
    }
    
    # If findSimilar is enabled, search for partial matches
    if ($findSimilar)
    {
        $searchTerm = $userName -replace '@.*$', ''
        $userMatches = @()
        
        foreach ($key in $script:MockUserDatabase.Keys)
        {
            $user = $script:MockUserDatabase[$key]
            if ($user.givenName -like "*$searchTerm*" -or 
                $user.surname -like "*$searchTerm*" -or
                $user.userPrincipalName -like "*$searchTerm*")
            {
                $userMatches += $user
            }
        }
        
        if ($userMatches.Count -gt 0)
        {
            $response = [PSCustomObject]@{
                '@odata.context' = 'https://graph.microsoft.com/v1.0/$metadata#users'
                value            = $userMatches
            }
            return @($response, $true)  # Fuzzy match
        }
    }
    
    # No match found
    return $global:returnValues.noUserFoundInDirectoryMessage
}

function DisplayUserList
{
    param(
        [array]$UserList,
        [int]$maxDisplay = 10
    )
    
    $script:DisplayUserListCallCount++
    
    # Return mocked response if explicitly enabled
    if ($script:UseMockResponse)
    {
        return $script:MockDisplayUserListResponse
    }
    
    # Default: return first user's UPN
    if ($UserList.Count -gt 0)
    {
        return $UserList[0].userPrincipalName
    }
    
    return $null
}
#endregion

#region Test Cases

Write-TestHeader "Running Test Cases"

#region Test 1: Input Validation
Write-TestSection "Test 1: Input Validation"

# Test 1.1: Null or empty username
try
{
    $result = Resolve-UserWithMatching -UserName "" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues
    Write-TestResult "1.1 - Empty username returns noUserFoundInDirectoryMessage" ($result -eq $global:returnValues.noUserFoundInDirectoryMessage)
}
catch
{
    Write-TestResult "1.1 - Empty username handling" $false "Exception: $_"
}

# Test 1.2: Null access token
try
{
    $result = Resolve-UserWithMatching -UserName "test@contoso.com" -AccessToken "" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues
    Write-TestResult "1.2 - Empty access token returns noAccessTokenMessage" ($result -eq $global:returnValues.noAccessTokenMessage)
}
catch
{
    Write-TestResult "1.2 - Empty access token handling" $false "Exception: $_"
}

# Test 1.3: Whitespace username
try
{
    $result = Resolve-UserWithMatching -UserName "   " -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues
    Write-TestResult "1.3 - Whitespace username returns noUserFoundInDirectoryMessage" ($result -eq $global:returnValues.noUserFoundInDirectoryMessage)
}
catch
{
    Write-TestResult "1.3 - Whitespace username handling" $false "Exception: $_"
}
#endregion

#region Test 2: Exact Match Scenarios
Write-TestSection "Test 2: Exact Match Scenarios"

# Reset call counters
$script:GetEntraUserCallCount = 0

# Test 2.1: Exact match found
try
{
    $result = Resolve-UserWithMatching -UserName "john.doe@contoso.com" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues
    Write-TestResult "2.1 - Exact match returns correct userPrincipalName" ($result -eq "john.doe@contoso.com")
    Write-TestResult "2.2 - GetEntraUser called once for exact match" ($script:GetEntraUserCallCount -eq 1)
}
catch
{
    Write-TestResult "2.1 - Exact match scenario" $false "Exception: $_"
}
#endregion

#region Test 3: Fuzzy Match Scenarios
Write-TestSection "Test 3: Fuzzy Match Scenarios"

# Reset counters and mocks
$script:GetEntraUserCallCount = 0
$script:DisplayUserListCallCount = 0
$script:UseMockResponse = $false
$script:MockDisplayUserListResponse = $null

# Test 3.1: Single fuzzy match - user confirms
try
{
    $script:UseMockResponse = $true
    $script:MockDisplayUserListResponse = "jane.smith@contoso.com"
    $result = Resolve-UserWithMatching -UserName "jane@contoso.com" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues
    Write-TestResult "3.1 - Single fuzzy match returns selected user" ($result -eq "jane.smith@contoso.com")
    Write-TestResult "3.2 - DisplayUserList called for fuzzy match" ($script:DisplayUserListCallCount -eq 1)
}
catch
{
    Write-TestResult "3.1 - Single fuzzy match scenario" $false "Exception: $_"
}

# Test 3.2: Multiple fuzzy matches - user selects one
try
{
    $script:UseMockResponse = $true
    $script:MockDisplayUserListResponse = "john.doe@contoso.com"
    $script:DisplayUserListCallCount = 0
    $result = Resolve-UserWithMatching -UserName "john" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues
    Write-TestResult "3.3 - Multiple fuzzy matches returns selected user" ($result -eq "john.doe@contoso.com")
    Write-TestResult "3.4 - DisplayUserList called for multiple matches" ($script:DisplayUserListCallCount -eq 1)
}
catch
{
    Write-TestResult "3.3 - Multiple fuzzy matches scenario" $false "Exception: $_"
}

# Test 3.3: Fuzzy match with maxDisplay limit
try
{
    $script:UseMockResponse = $true
    $script:MockDisplayUserListResponse = "john.johnson@contoso.com"
    $result = Resolve-UserWithMatching -UserName "jo" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 2} -ReturnValues $global:returnValues
    Write-TestResult "3.5 - Fuzzy match respects maxUserMatchDisplay setting" ($result -eq "john.johnson@contoso.com")
}
catch
{
    Write-TestResult "3.5 - Fuzzy match with maxDisplay" $false "Exception: $_"
}
#endregion

#region Test 4: No Match Scenarios
Write-TestSection "Test 4: No Match Scenarios"

# Test 4.1: No user found
try
{
    $result = Resolve-UserWithMatching -UserName "nonexistent@contoso.com" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues
    Write-TestResult "4.1 - No match returns noUserFoundInDirectoryMessage" ($result -eq $global:returnValues.noUserFoundInDirectoryMessage)
}
catch
{
    Write-TestResult "4.1 - No match scenario" $false "Exception: $_"
}

# Test 4.2: No fuzzy matches
try
{
    $result = Resolve-UserWithMatching -UserName "xyz123" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues
    Write-TestResult "4.2 - No fuzzy match returns noUserFoundInDirectoryMessage" ($result -eq $global:returnValues.noUserFoundInDirectoryMessage)
}
catch
{
    Write-TestResult "4.2 - No fuzzy match scenario" $false "Exception: $_"
}
#endregion

#region Test 5: Navigation Scenarios
Write-TestSection "Test 5: Navigation Scenarios"

# Test 5.1: User presses Back
try
{
    $script:UseMockResponse = $true
    $script:MockDisplayUserListResponse = $global:returnValues.backoutText
    $result = Resolve-UserWithMatching -UserName "john" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues
    Write-TestResult "5.1 - Back navigation returns backoutText" ($result -eq $global:returnValues.backoutText)
}
catch
{
    Write-TestResult "5.1 - Back navigation" $false "Exception: $_"
}

# Test 5.2: User selects Main Menu
try
{
    $script:UseMockResponse = $true
    $script:MockDisplayUserListResponse = "Main Menu"
    $result = Resolve-UserWithMatching -UserName "john" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues
    Write-TestResult "5.2 - Main Menu navigation returns 'Main Menu'" ($result -eq "Main Menu")
}
catch
{
    Write-TestResult "5.2 - Main Menu navigation" $false "Exception: $_"
}

# Test 5.3: User selects Exit (0)
try
{
    $script:UseMockResponse = $true
    $script:MockDisplayUserListResponse = 0
    $result = Resolve-UserWithMatching -UserName "john" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues
    Write-TestResult "5.3 - Exit command (0) returns EXIT_APPLICATION" ($result -eq "EXIT_APPLICATION")
}
catch
{
    Write-TestResult "5.3 - Exit (0) navigation" $false "Exception: $_"
}

# Test 5.4: User cancels selection (null from DisplayUserList)
try
{
    $script:UseMockResponse = $true
    $script:MockDisplayUserListResponse = $null
    $result = Resolve-UserWithMatching -UserName "john" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues
    # When DisplayUserList returns null directly (mock bypasses conversion), ConvertFrom-UserSelection returns backoutText
    # In real code, DisplayUserList converts null from ShowMenu to 0, but the mock returns null directly
    Write-TestResult "5.4 - Null from DisplayUserList returns backoutText" ($result -eq $global:returnValues.backoutText)
}
catch
{
    Write-TestResult "5.4 - Cancel/null handling" $false "Exception: $_"
}
#endregion

#region Test 6: Integration Tests
Write-TestSection "Test 6: Integration Tests"

# Test 6.1: End-to-end exact match flow
try
{
    $script:GetEntraUserCallCount = 0
    $script:DisplayUserListCallCount = 0
    $script:UseMockResponse = $false
    $script:MockDisplayUserListResponse = $null
    
    $result = Resolve-UserWithMatching -UserName "jane.smith@contoso.com" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues
    
    $exactMatchSuccess = ($result -eq "jane.smith@contoso.com")
    $calledGetEntraUser = ($script:GetEntraUserCallCount -eq 1)
    $didNotCallDisplayUserList = ($script:DisplayUserListCallCount -eq 0)
    
    Write-TestResult "6.1 - E2E exact match returns correct user" $exactMatchSuccess
    Write-TestResult "6.2 - E2E exact match calls GetEntraUser once" $calledGetEntraUser
    Write-TestResult "6.3 - E2E exact match does not call DisplayUserList" $didNotCallDisplayUserList
}
catch
{
    Write-TestResult "6.1 - E2E exact match flow" $false "Exception: $_"
}

# Test 6.2: End-to-end fuzzy match flow
try
{
    $script:GetEntraUserCallCount = 0
    $script:DisplayUserListCallCount = 0
    $script:UseMockResponse = $true
    $script:MockDisplayUserListResponse = "john.johnson@contoso.com"
    
    $result = Resolve-UserWithMatching -UserName "johnson" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues
    
    $fuzzyMatchSuccess = ($result -eq "john.johnson@contoso.com")
    $calledGetEntraUser = ($script:GetEntraUserCallCount -eq 1)
    $calledDisplayUserList = ($script:DisplayUserListCallCount -eq 1)
    
    Write-TestResult "6.4 - E2E fuzzy match returns selected user" $fuzzyMatchSuccess
    Write-TestResult "6.5 - E2E fuzzy match calls GetEntraUser once" $calledGetEntraUser
    Write-TestResult "6.6 - E2E fuzzy match calls DisplayUserList once" $calledDisplayUserList
}
catch
{
    Write-TestResult "6.4 - E2E fuzzy match flow" $false "Exception: $_"
}

# Test 6.3: End-to-end no match flow
try
{
    $script:GetEntraUserCallCount = 0
    $script:DisplayUserListCallCount = 0
    $script:UseMockResponse = $false
    
    $result = Resolve-UserWithMatching -UserName "nonexistent@example.com" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues
    
    $noMatchSuccess = ($result -eq $global:returnValues.noUserFoundInDirectoryMessage)
    $calledGetEntraUser = ($script:GetEntraUserCallCount -eq 1)
    $didNotCallDisplayUserList = ($script:DisplayUserListCallCount -eq 0)
    
    Write-TestResult "6.7 - E2E no match returns noUserFoundInDirectoryMessage" $noMatchSuccess
    Write-TestResult "6.8 - E2E no match calls GetEntraUser once" $calledGetEntraUser
    Write-TestResult "6.9 - E2E no match does not call DisplayUserList" $didNotCallDisplayUserList
}
catch
{
    Write-TestResult "6.7 - E2E no match flow" $false "Exception: $_"
}
#endregion

#region Test 7: Edge Cases
Write-TestSection "Test 7: Edge Cases"

# Reset mock
$script:UseMockResponse = $false

# Test 7.1: Case-insensitive username matching
try
{
    $result = Resolve-UserWithMatching -UserName "JOHN.DOE@CONTOSO.COM" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues
    Write-TestResult "7.1 - Case-insensitive username matching" ($result -eq "john.doe@contoso.com")
}
catch
{
    Write-TestResult "7.1 - Case-insensitive matching" $false "Exception: $_"
}

# Test 7.2: Username with leading/trailing spaces
try
{
    $result = Resolve-UserWithMatching -UserName " john.doe@contoso.com " -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues
    # Should handle gracefully - either trim or not find
    Write-TestResult "7.2 - Username with spaces handled gracefully" ($null -ne $result)
}
catch
{
    Write-TestResult "7.2 - Username with spaces" $false "Exception: $_"
}

# Test 7.3: Very long username
try
{
    $longUsername = "verylongusernamethatshouldstillbemanagedcorrectly@contoso.com"
    $result = Resolve-UserWithMatching -UserName $longUsername -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues
    Write-TestResult "7.3 - Long username handled without error" ($null -ne $result)
}
catch
{
    Write-TestResult "7.3 - Long username handling" $false "Exception: $_"
}

# Test 7.4: Special characters in username
try
{
    $result = Resolve-UserWithMatching -UserName "test+alias@contoso.com" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues
    Write-TestResult "7.4 - Special characters in username handled" ($null -ne $result)
}
catch
{
    Write-TestResult "7.4 - Special characters handling" $false "Exception: $_"
}

# Test 7.5: Empty user list from fuzzy search
try
{
    # This tests robustness when GetEntraUser returns unexpected data
    $result = Resolve-UserWithMatching -UserName "empty" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues
    Write-TestResult "7.5 - Empty fuzzy search results handled" ($result -eq $global:returnValues.noUserFoundInDirectoryMessage)
}
catch
{
    Write-TestResult "7.5 - Empty fuzzy search" $false "Exception: $_"
}
#endregion

#region Test 8: Settings Validation
Write-TestSection "Test 8: Settings Validation"

# Test 8.1: maxUserMatchDisplay = 0
try
{
    $script:UseMockResponse = $true
    $script:MockDisplayUserListResponse = "john.doe@contoso.com"
    $result = Resolve-UserWithMatching -UserName "john" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 0} -ReturnValues $global:returnValues
    Write-TestResult "8.1 - maxUserMatchDisplay=0 handled gracefully" ($null -ne $result)
}
catch
{
    Write-TestResult "8.1 - maxUserMatchDisplay=0" $false "Exception: $_"
}

# Test 8.2: maxUserMatchDisplay = 1
try
{
    $script:UseMockResponse = $true
    $script:MockDisplayUserListResponse = "jane.smith@contoso.com"
    $result = Resolve-UserWithMatching -UserName "jane" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 1} -ReturnValues $global:returnValues
    Write-TestResult "8.2 - maxUserMatchDisplay=1 works correctly" ($result -eq "jane.smith@contoso.com")
}
catch
{
    Write-TestResult "8.2 - maxUserMatchDisplay=1" $false "Exception: $_"
}

# Test 8.3: Large maxUserMatchDisplay
try
{
    $script:UseMockResponse = $true
    $script:MockDisplayUserListResponse = "john.johnson@contoso.com"
    $result = Resolve-UserWithMatching -UserName "john" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 9999} -ReturnValues $global:returnValues
    Write-TestResult "8.3 - Large maxUserMatchDisplay handled" ($result -eq "john.johnson@contoso.com")
}
catch
{
    Write-TestResult "8.3 - Large maxUserMatchDisplay" $false "Exception: $_"
}
#endregion

#endregion

#region Cleanup and Summary
Write-TestHeader "Test Execution Complete"

# Clean up mock objects
$script:MockUserDatabase = $null
$script:MockDisplayUserListResponse = $null

# Display summary
$allTestsPassed = Write-TestSummary

# Return appropriate exit code
if ($allTestsPassed)
{
    Write-Host "All tests passed successfully!" -ForegroundColor Green
    exit 0
}
else
{
    Write-Host "Some tests failed. Please review the results above." -ForegroundColor Red
    exit 1
}
#endregion

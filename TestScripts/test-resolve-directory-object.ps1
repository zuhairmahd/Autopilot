#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Comprehensive end-to-end test for Resolve-DirectoryObject function
.DESCRIPTION
    This script provides complete test coverage for the Resolve-DirectoryObject function including:
    - User and Group resolution scenarios
    - Exact match scenarios
    - Fuzzy match scenarios (single and multiple matches)
    - No match scenarios
    - Navigation scenarios (Back, Main Menu, Exit)
    - Input validation
    - Error handling
    - Integration with ConvertFrom-DirectoryObjectSelection and Show-DirectoryObjectList
    - NoPrompt parameter for automated testing
.NOTES
    Author: Windows Autopilot Management Tool Team
    Version: 3.0.0 (Unified DirectoryObject version)
    Test Category: unit, integration
    Dependencies: Get-EntraDirectoryObject, Show-DirectoryObjectList, ConvertFrom-DirectoryObjectSelection
#>

[CmdletBinding()]
param(
    [switch]$Interactive
)

# Test configuration
$script:TestName = "Resolve-DirectoryObject"
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
    . (Join-Path $userFunctionsPath "Resolve-DirectoryObject.ps1")
    . (Join-Path $userFunctionsPath "ConvertFrom-DirectoryObjectSelection.ps1")
    . (Join-Path $userFunctionsPath "Get-EntraDirectoryObject.ps1")
    . (Join-Path $userFunctionsPath "Show-DirectoryObjectList.ps1")
    
    Write-Host "[OK] Required functions loaded successfully" -ForegroundColor Green
}
catch
{
    Write-Host "[ERROR] Failed to load required functions: $_" -ForegroundColor Red
    exit 1
}

# Mock global variables
$global:LogFile = Join-Path $scriptPath "test-resolve-directory-object.log"
$global:returnValues = @{
    noUserFoundInDirectoryMessage = "User not found in directory"
    noGroupFoundMessage           = "Group not found in directory"
    noAccessTokenMessage          = "Access token is required"
    backoutText                   = "BACK_NAVIGATION"
    userCanceledMessage           = "USER_CANCELED"
}

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
    "john.doe@contoso.com"     = [PSCustomObject]@{
        userPrincipalName = "john.doe@contoso.com"
        displayName       = "John Doe"
        givenName         = "John"
        surname           = "Doe"
        mail              = "john.doe@contoso.com"
        id                = "12345-67890-abcde"
    }
    "jane.smith@contoso.com"   = [PSCustomObject]@{
        userPrincipalName = "jane.smith@contoso.com"
        displayName       = "Jane Smith"
        givenName         = "Jane"
        surname           = "Smith"
        mail              = "jane.smith@contoso.com"
        id                = "23456-78901-bcdef"
    }
    "john.johnson@contoso.com" = [PSCustomObject]@{
        userPrincipalName = "john.johnson@contoso.com"
        displayName       = "John Johnson"
        givenName         = "John"
        surname           = "Johnson"
        mail              = "john.johnson@contoso.com"
        id                = "34567-89012-cdefg"
    }
}

$script:MockGroupDatabase = @{
    "Marketing Team"    = [PSCustomObject]@{
        displayName = "Marketing Team"
        id          = "group-id-1"
    }
    "Sales Team"        = [PSCustomObject]@{
        displayName = "Sales Team"
        id          = "group-id-2"
    }
    "Marketing Support" = [PSCustomObject]@{
        displayName = "Marketing Support"
        id          = "group-id-3"
    }
}

# Mock control flags
$script:MockShowDirectoryObjectListEnabled = $true  # Enable mocking by default
$script:MockShowDirectoryObjectListBypass = $false  # Don't bypass null→0 conversion by default
$script:MockShowDirectoryObjectListResponse = $null
$script:ShowDirectoryObjectListCallCount = 0
$script:DirectoryObjectCache = @{}

# Mock CallGraphAPI function
function CallGraphAPI
{
    param(
        [string]$AccessToken,
        [string]$ResourcePath,
        [string]$APIVersion = 'beta',
        [string]$Method = 'get',
        [string]$Filter = $null,
        [string]$Search = $null,
        [string]$ExtraParameters = $null,
        [string]$Body = $null,
        [switch]$ConsistencyLevel,
        [switch]$SecureString
    )
    
    # Simulate API call for users
    if ($ResourcePath -like "users/*")
    {
        # Direct user lookup by UPN (users/john.doe@contoso.com)
        $userName = $ResourcePath -replace '^users/', ''
        if ($script:MockUserDatabase.ContainsKey($userName))
        {
            # Return single user object (not wrapped in value array for direct lookup)
            # Must return as PSCustomObject, not hashtable
            $user = $script:MockUserDatabase[$userName]
            return [PSCustomObject]@{
                userPrincipalName = $user.userPrincipalName
                displayName       = $user.displayName
                givenName         = $user.givenName
                surname           = $user.surname
                mail              = $user.mail
                id                = $user.id
            }
        }
        # Return error code for not found
        return 404
    }
    elseif ($ResourcePath -eq "users" -and $Filter)
    {
        # Filter query for users
        if ($Filter -match 'userPrincipalName eq ''([^'']+)''')
        {
            $userName = $Matches[1]
            if ($script:MockUserDatabase.ContainsKey($userName))
            {
                return [PSCustomObject]@{
                    '@odata.context' = 'https://graph.microsoft.com/v1.0/$metadata#users'
                    value            = @($script:MockUserDatabase[$userName])
                }
            }
        }
        elseif ($Filter -match 'startsWith\(userPrincipalName,''([^'']+)''\)')
        {
            $searchTerm = $Matches[1]
            $userMatches = [System.Collections.ArrayList]::new()
            foreach ($key in $script:MockUserDatabase.Keys)
            {
                $user = $script:MockUserDatabase[$key]
                if ($user.userPrincipalName -like "$searchTerm*")
                {
                    [void]$userMatches.Add($user)
                }
            }
            return [PSCustomObject]@{
                '@odata.context' = 'https://graph.microsoft.com/v1.0/$metadata#users'
                value            = $userMatches.ToArray()
            }
        }
        # Handle fuzzy search pattern: startswith(givenName, 'x') or startsWith(surname, 'x')
        elseif ($Filter -match "startswith?\((?:givenName|surname),\s*'([^']+)'")
        {
            $searchTerm = $Matches[1]
            $userMatches = [System.Collections.ArrayList]::new()
            foreach ($key in $script:MockUserDatabase.Keys)
            {
                $user = $script:MockUserDatabase[$key]
                if ($user.givenName -like "$searchTerm*" -or 
                    $user.surname -like "$searchTerm*" -or
                    $user.userPrincipalName -like "$searchTerm*" -or
                    $user.displayName -like "*$searchTerm*")
                {
                    [void]$userMatches.Add($user)
                }
            }
            return [PSCustomObject]@{
                '@odata.context' = 'https://graph.microsoft.com/v1.0/$metadata#users'
                value            = $userMatches.ToArray()
            }
        }
        
        return [PSCustomObject]@{
            '@odata.context' = 'https://graph.microsoft.com/v1.0/$metadata#users'
            value            = @()
        }
    }
    elseif ($ResourcePath -eq "users" -and $Search)
    {
        # $search query for users - match on any part of userPrincipalName
        if ($Search -match '"userPrincipalName:([^"]+)"')
        {
            $searchTerm = $Matches[1]
            $userMatches = [System.Collections.ArrayList]::new()
            foreach ($key in $script:MockUserDatabase.Keys)
            {
                $user = $script:MockUserDatabase[$key]
                # Match on userPrincipalName, displayName, or givenName
                if ($user.userPrincipalName -like "*$searchTerm*" -or
                    $user.displayName -like "*$searchTerm*" -or
                    $user.givenName -like "*$searchTerm*")
                {
                    [void]$userMatches.Add($user)
                }
            }
            return [PSCustomObject]@{
                '@odata.context' = 'https://graph.microsoft.com/v1.0/$metadata#users'
                value            = $userMatches.ToArray()
            }
        }
        
        return [PSCustomObject]@{
            '@odata.context' = 'https://graph.microsoft.com/v1.0/$metadata#users'
            value            = @()
        }
    }
    
    # Simulate API call for groups
    if ($ResourcePath -eq "groups" -and $Filter)
    {
        # Exact match by displayName
        if ($Filter -match 'displayName eq ''([^'']+)''')
        {
            $groupName = $Matches[1]
            if ($script:MockGroupDatabase.ContainsKey($groupName))
            {
                return [PSCustomObject]@{
                    '@odata.context' = 'https://graph.microsoft.com/v1.0/$metadata#groups'
                    value            = @($script:MockGroupDatabase[$groupName])
                }
            }
        }
        # startsWith filter
        elseif ($Filter -match 'startsWith\(displayName,''([^'']+)''\)')
        {
            $searchTerm = $Matches[1]
            $groupMatches = [System.Collections.ArrayList]::new()
            foreach ($key in $script:MockGroupDatabase.Keys)
            {
                $group = $script:MockGroupDatabase[$key]
                if ($group.displayName -like "$searchTerm*")
                {
                    [void]$groupMatches.Add($group)
                }
            }
            return [PSCustomObject]@{
                '@odata.context' = 'https://graph.microsoft.com/v1.0/$metadata#groups'
                value            = $groupMatches.ToArray()
            }
        }
        # contains filter (fallback pattern)
        elseif ($Filter -match 'contains\(displayName,''([^'']+)''\)')
        {
            $searchTerm = $Matches[1]
            $groupMatches = [System.Collections.ArrayList]::new()
            foreach ($key in $script:MockGroupDatabase.Keys)
            {
                $group = $script:MockGroupDatabase[$key]
                if ($group.displayName -like "*$searchTerm*")
                {
                    [void]$groupMatches.Add($group)
                }
            }
            return [PSCustomObject]@{
                '@odata.context' = 'https://graph.microsoft.com/v1.0/$metadata#groups'
                value            = $groupMatches.ToArray()
            }
        }
        
        return [PSCustomObject]@{
            '@odata.context' = 'https://graph.microsoft.com/v1.0/$metadata#groups'
            value            = @()
        }
    }
    elseif ($ResourcePath -eq "groups" -and ($Search -or ($ExtraParameters -match 'search=')))
    {
        # $search query for groups - can be in $Search parameter or embedded in ExtraParameters
        $searchValue = $Search
        if (-not $searchValue -and $ExtraParameters -match 'search=([^&]+)')
        {
            # Extract URL-encoded search from extraParameters and decode it
            $searchValue = [uri]::UnescapeDataString($Matches[1])
        }
        
        # Match on displayName - handle both quoted and unquoted patterns
        if ($searchValue -match '"?displayName:([^"&]+)"?')
        {
            $searchTerm = $Matches[1]
            $groupMatches = [System.Collections.ArrayList]::new()
            foreach ($key in $script:MockGroupDatabase.Keys)
            {
                $group = $script:MockGroupDatabase[$key]
                if ($group.displayName -like "*$searchTerm*")
                {
                    [void]$groupMatches.Add($group)
                }
            }
            return [PSCustomObject]@{
                '@odata.context' = 'https://graph.microsoft.com/v1.0/$metadata#groups'
                value            = $groupMatches.ToArray()
            }
        }
        
        return [PSCustomObject]@{
            '@odata.context' = 'https://graph.microsoft.com/v1.0/$metadata#groups'
            value            = @()
        }
    }
    
    return $null
}

# Mock menu functions
function NewMenu
{
    param([string]$Title)
    $menu = New-Object PSObject
    Add-Member -InputObject $menu -MemberType NoteProperty -Name Title -Value $Title
    Add-Member -InputObject $menu -MemberType NoteProperty -Name Items -Value ([System.Collections.ArrayList]::new())
    return $menu
}

function AddMenuItem
{
    param(
        [PSCustomObject]$Menu,
        [string]$Name,
        [string]$Display,
        [object]$ReturnValue,
        [scriptblock]$Action,
        [switch]$ReturnsValue
    )
    
    # Handle both old and new parameter styles
    $displayText = if ($Name)
    {
        $Name 
    }
    else
    {
        $Display 
    }
    $returnVal = if ($Action)
    {
        $Action 
    }
    else
    {
        $ReturnValue 
    }
    
    [void]$Menu.Items.Add(@{ Display = $displayText; Return = $returnVal; Action = $returnVal })
    
    # IMPORTANT: Return the menu object so chained assignments work
    return $Menu
}

function ShowMenu
{
    param([PSCustomObject]$Menu)
    
    $script:ShowDirectoryObjectListCallCount++
    
    # Return mocked response if mockingEnabled flag is set
    if ($script:MockShowDirectoryObjectListEnabled)
    {
        return $script:MockShowDirectoryObjectListResponse
    }
    
    # Default: return first item
    if ($Menu.Items.Count -gt 0)
    {
        return $Menu.Items[0].Return
    }
    
    return $null
}

# Mock Show-DirectoryObjectList completely to prevent any user interaction
# This ensures the test runs in fully automated mode without prompts
function Show-DirectoryObjectList
{
    param(
        $EntityList,
        $EntityType,
        $MaxDisplay,
        [switch]$NoPrompt
    )
    
    $script:ShowDirectoryObjectListCallCount++
    
    # If bypass flag is set and response is null, return null directly
    # This allows testing ConvertFrom-DirectoryObjectSelection without the null→0 conversion
    if ($script:MockShowDirectoryObjectListBypass -and $null -eq $script:MockShowDirectoryObjectListResponse)
    {
        return $null
    }
    
    # For single item with NoPrompt, auto-return it
    # Note: EntityList is passed as an array directly, not wrapped in .value property
    if ($NoPrompt -and $EntityList.Count -eq 1)
    {
        if ($EntityType -eq "User")
        {
            return $EntityList[0].userPrincipalName
        }
        else
        {
            return $EntityList[0].displayName
        }
    }
    
    # For multiple items or non-NoPrompt scenarios, use the mocked response
    # This prevents ShowMenu from being called, which would prompt for input
    # Check if MockShowDirectoryObjectListEnabled is set (not just if response is not null)
    if ($script:MockShowDirectoryObjectListEnabled)
    {
        # If response is explicitly null, convert to 0 (exit) like the real function does
        if ($null -eq $script:MockShowDirectoryObjectListResponse)
        {
            return 0
        }
        return $script:MockShowDirectoryObjectListResponse
    }
    
    # Default: return first item to avoid prompting (when mocking is disabled)
    if ($EntityList.Count -gt 0)
    {
        if ($EntityType -eq "User")
        {
            return $EntityList[0].userPrincipalName
        }
        else
        {
            return $EntityList[0].displayName
        }
    }
    
    # Return 0 (exit) if no items
    return 0
}
#endregion

#region Test Cases

Write-TestHeader "Running Test Cases"

#region Test 1: Input Validation
Write-TestSection "Test 1: Input Validation"

# Test 1.1: Null or empty entity name
try
{
    $result = Resolve-DirectoryObject -EntityName "" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues -EntityType "User"
    Write-TestResult "1.1 - Empty username returns noUserFoundInDirectoryMessage" ($result -eq $global:returnValues.noUserFoundInDirectoryMessage)
}
catch
{
    Write-TestResult "1.1 - Empty username handling" $false "Exception: $_"
}

# Test 1.2: Null access token
try
{
    $result = Resolve-DirectoryObject -EntityName "test@contoso.com" -AccessToken "" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues -EntityType "User"
    Write-TestResult "1.2 - Empty access token returns noAccessTokenMessage" ($result -eq $global:returnValues.noAccessTokenMessage)
}
catch
{
    Write-TestResult "1.2 - Empty access token handling" $false "Exception: $_"
}

# Test 1.3: Whitespace entity name
try
{
    $result = Resolve-DirectoryObject -EntityName "   " -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues -EntityType "User"
    Write-TestResult "1.3 - Whitespace username returns noUserFoundInDirectoryMessage" ($result -eq $global:returnValues.noUserFoundInDirectoryMessage)
}
catch
{
    Write-TestResult "1.3 - Whitespace username handling" $false "Exception: $_"
}

# Test 1.4: Empty group name
try
{
    $result = Resolve-DirectoryObject -EntityName "" -AccessToken "test-token" -Settings @{maxGroupMatchDisplay = 10} -ReturnValues $global:returnValues -EntityType "Group"
    Write-TestResult "1.4 - Empty group name returns noGroupFoundMessage" ($result -eq $global:returnValues.noGroupFoundMessage)
}
catch
{
    Write-TestResult "1.4 - Empty group name handling" $false "Exception: $_"
}
#endregion

#region Test 2: Exact Match Scenarios
Write-TestSection "Test 2: Exact Match Scenarios"

# Reset cache
$script:DirectoryObjectCache = @{}

# Test 2.1: User exact match
try
{
    $result = Resolve-DirectoryObject -EntityName "john.doe@contoso.com" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues -EntityType "User"
    Write-TestResult "2.1 - User exact match returns correct userPrincipalName" ($result -eq "john.doe@contoso.com")
}
catch
{
    Write-TestResult "2.1 - User exact match scenario" $false "Exception: $_"
}

# Test 2.2: Group exact match
try
{
    $result = Resolve-DirectoryObject -EntityName "Marketing Team" -AccessToken "test-token" -Settings @{maxGroupMatchDisplay = 10} -ReturnValues $global:returnValues -EntityType "Group"
    Write-TestResult "2.2 - Group exact match returns correct displayName" ($result -eq "Marketing Team")
}
catch
{
    Write-TestResult "2.2 - Group exact match scenario" $false "Exception: $_"
}
#endregion

#region Test 3: Fuzzy Match Scenarios with NoPrompt
Write-TestSection "Test 3: Fuzzy Match Scenarios with NoPrompt"

# Reset mocks
$script:MockShowDirectoryObjectListResponse = $null
$script:ShowDirectoryObjectListCallCount = 0
$script:DirectoryObjectCache = @{}

# Test 3.1: Single user fuzzy match with NoPrompt
try
{
    # Search for "jane" which should fuzzy match "jane.smith@contoso.com"
    $result = Resolve-DirectoryObject -EntityName "jane" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues -EntityType "User" -NoPrompt
    Write-TestResult "3.1 - Single user fuzzy match with NoPrompt auto-accepts" ($result -eq "jane.smith@contoso.com")
}
catch
{
    Write-TestResult "3.1 - Single user fuzzy match with NoPrompt" $false "Exception: $_"
}

# Test 3.2: Single group fuzzy match with NoPrompt
try
{
    $script:DirectoryObjectCache = @{}
    # Search for "Sales" which should fuzzy match "Sales Team"
    $result = Resolve-DirectoryObject -EntityName "Sales" -AccessToken "test-token" -Settings @{maxGroupMatchDisplay = 10} -ReturnValues $global:returnValues -EntityType "Group" -NoPrompt
    Write-TestResult "3.2 - Single group fuzzy match with NoPrompt auto-accepts" ($result -eq "Sales Team")
}
catch
{
    Write-TestResult "3.2 - Single group fuzzy match with NoPrompt" $false "Exception: $_"
}

# Test 3.3: Multiple users fuzzy match with mocked selection
try
{
    $script:DirectoryObjectCache = @{}
    $script:MockShowDirectoryObjectListResponse = "john.doe@contoso.com"
    $script:ShowDirectoryObjectListCallCount = 0
    $result = Resolve-DirectoryObject -EntityName "john" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues -EntityType "User"
    Write-TestResult "3.3 - Multiple users fuzzy match returns selected user" ($result -eq "john.doe@contoso.com")
    Write-TestResult "3.4 - Multiple users calls ShowMenu once" ($script:ShowDirectoryObjectListCallCount -eq 1)
}
catch
{
    Write-TestResult "3.3 - Multiple users fuzzy match" $false "Exception: $_"
}

# Test 3.4: Multiple groups fuzzy match with mocked selection
try
{
    $script:DirectoryObjectCache = @{}
    $script:MockShowDirectoryObjectListResponse = "Marketing Support"
    $script:ShowDirectoryObjectListCallCount = 0
    $result = Resolve-DirectoryObject -EntityName "Marketing" -AccessToken "test-token" -Settings @{maxGroupMatchDisplay = 10} -ReturnValues $global:returnValues -EntityType "Group"
    Write-TestResult "3.5 - Multiple groups fuzzy match returns selected group" ($result -eq "Marketing Support")
    Write-TestResult "3.6 - Multiple groups calls ShowMenu once" ($script:ShowDirectoryObjectListCallCount -eq 1)
}
catch
{
    Write-TestResult "3.5 - Multiple groups fuzzy match" $false "Exception: $_"
}

# Test 3.5: Fuzzy match with maxDisplay limit
try
{
    $script:DirectoryObjectCache = @{}
    $script:MockShowDirectoryObjectListResponse = "john.johnson@contoso.com"
    $result = Resolve-DirectoryObject -EntityName "jo" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 2} -ReturnValues $global:returnValues -EntityType "User"
    Write-TestResult "3.7 - Fuzzy match respects maxUserMatchDisplay setting" ($result -eq "john.johnson@contoso.com")
}
catch
{
    Write-TestResult "3.7 - Fuzzy match with maxDisplay" $false "Exception: $_"
}
#endregion

#region Test 4: No Match Scenarios
Write-TestSection "Test 4: No Match Scenarios"

# Reset cache
$script:DirectoryObjectCache = @{}

# Test 4.1: No user found
try
{
    $result = Resolve-DirectoryObject -EntityName "nonexistent@contoso.com" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues -EntityType "User"
    Write-TestResult "4.1 - No user match returns noUserFoundInDirectoryMessage" ($result -eq $global:returnValues.noUserFoundInDirectoryMessage)
}
catch
{
    Write-TestResult "4.1 - No user match scenario" $false "Exception: $_"
}

# Test 4.2: No fuzzy matches for user
try
{
    $result = Resolve-DirectoryObject -EntityName "xyz123" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues -EntityType "User"
    Write-TestResult "4.2 - No user fuzzy match returns noUserFoundInDirectoryMessage" ($result -eq $global:returnValues.noUserFoundInDirectoryMessage)
}
catch
{
    Write-TestResult "4.2 - No user fuzzy match scenario" $false "Exception: $_"
}

# Test 4.3: No group found
try
{
    $result = Resolve-DirectoryObject -EntityName "NonexistentGroup" -AccessToken "test-token" -Settings @{maxGroupMatchDisplay = 10} -ReturnValues $global:returnValues -EntityType "Group"
    Write-TestResult "4.3 - No group match returns noGroupFoundMessage" ($result -eq $global:returnValues.noGroupFoundMessage)
}
catch
{
    Write-TestResult "4.3 - No group match scenario" $false "Exception: $_"
}
#endregion

#region Test 5: Navigation Scenarios
Write-TestSection "Test 5: Navigation Scenarios"

# Reset cache
$script:DirectoryObjectCache = @{}

# Test 5.1: User presses Back
try
{
    $script:MockShowDirectoryObjectListResponse = $global:returnValues.backoutText
    $result = Resolve-DirectoryObject -EntityName "john" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues -EntityType "User"
    Write-TestResult "5.1 - Back navigation returns backoutText" ($result -eq $global:returnValues.backoutText)
}
catch
{
    Write-TestResult "5.1 - Back navigation" $false "Exception: $_"
}

# Test 5.2: User selects Main Menu
try
{
    $script:DirectoryObjectCache = @{}
    $script:MockShowDirectoryObjectListResponse = "Main Menu"
    $result = Resolve-DirectoryObject -EntityName "john" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues -EntityType "User"
    Write-TestResult "5.2 - Main Menu navigation returns 'Main Menu'" ($result -eq "Main Menu")
}
catch
{
    Write-TestResult "5.2 - Main Menu navigation" $false "Exception: $_"
}

# Test 5.3: User selects Exit (0)
try
{
    $script:DirectoryObjectCache = @{}
    $script:MockShowDirectoryObjectListResponse = 0
    $result = Resolve-DirectoryObject -EntityName "john" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues -EntityType "User"
    Write-TestResult "5.3 - Exit command (0) returns EXIT_APPLICATION" ($result -eq "EXIT_APPLICATION")
}
catch
{
    Write-TestResult "5.3 - Exit (0) navigation" $false "Exception: $_"
}

# Test 5.4: User cancels selection (null - converted to exit by Show-DirectoryObjectList)
try
{
    $script:DirectoryObjectCache = @{}
    $script:MockShowDirectoryObjectListResponse = $null
    $result = Resolve-DirectoryObject -EntityName "john" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues -EntityType "User"
    # Note: Show-DirectoryObjectList converts null from ShowMenu to 0, which becomes "EXIT_APPLICATION"
    Write-TestResult "5.4 - Null selection returns EXIT_APPLICATION" ($result -eq "EXIT_APPLICATION")
}
catch
{
    Write-TestResult "5.4 - Cancel/null handling" $false "Exception: $_"
}

# Test 5.5: Group Back navigation
try
{
    $script:DirectoryObjectCache = @{}
    $script:MockShowDirectoryObjectListResponse = $global:returnValues.backoutText
    $result = Resolve-DirectoryObject -EntityName "Marketing" -AccessToken "test-token" -Settings @{maxGroupMatchDisplay = 10} -ReturnValues $global:returnValues -EntityType "Group"
    Write-TestResult "5.5 - Group Back navigation returns backoutText" ($result -eq $global:returnValues.backoutText)
}
catch
{
    Write-TestResult "5.5 - Group Back navigation" $false "Exception: $_"
}

# Test 5.6: Group Exit navigation
try
{
    $script:DirectoryObjectCache = @{}
    $script:MockShowDirectoryObjectListResponse = 0
    $result = Resolve-DirectoryObject -EntityName "Marketing" -AccessToken "test-token" -Settings @{maxGroupMatchDisplay = 10} -ReturnValues $global:returnValues -EntityType "Group"
    Write-TestResult "5.6 - Group Exit navigation returns EXIT_APPLICATION" ($result -eq "EXIT_APPLICATION")
}
catch
{
    Write-TestResult "5.6 - Group Exit navigation" $false "Exception: $_"
}
#endregion

#region Test 6: Settings Validation
Write-TestSection "Test 6: Settings Validation"

# Reset cache and mocks
$script:DirectoryObjectCache = @{}
$script:MockShowDirectoryObjectListResponse = "john.doe@contoso.com"

# Test 6.1: maxUserMatchDisplay = 1
try
{
    $result = Resolve-DirectoryObject -EntityName "john" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 1} -ReturnValues $global:returnValues -EntityType "User"
    Write-TestResult "6.1 - maxUserMatchDisplay=1 works correctly" ($result -eq "john.doe@contoso.com")
}
catch
{
    Write-TestResult "6.1 - maxUserMatchDisplay=1" $false "Exception: $_"
}

# Test 6.2: Large maxUserMatchDisplay
try
{
    $script:DirectoryObjectCache = @{}
    $script:MockShowDirectoryObjectListResponse = "john.johnson@contoso.com"
    $result = Resolve-DirectoryObject -EntityName "john" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 9999} -ReturnValues $global:returnValues -EntityType "User"
    Write-TestResult "6.2 - Large maxUserMatchDisplay handled" ($result -eq "john.johnson@contoso.com")
}
catch
{
    Write-TestResult "6.2 - Large maxUserMatchDisplay" $false "Exception: $_"
}

# Test 6.3: maxGroupMatchDisplay = 1
try
{
    $script:DirectoryObjectCache = @{}
    $script:MockShowDirectoryObjectListResponse = "Marketing Team"
    $result = Resolve-DirectoryObject -EntityName "Marketing" -AccessToken "test-token" -Settings @{maxGroupMatchDisplay = 1} -ReturnValues $global:returnValues -EntityType "Group"
    Write-TestResult "6.3 - maxGroupMatchDisplay=1 works correctly" ($result -eq "Marketing Team")
}
catch
{
    Write-TestResult "6.3 - maxGroupMatchDisplay=1" $false "Exception: $_"
}
#endregion

#region Test 7: Backward Compatibility
Write-TestSection "Test 7: Backward Compatibility"

# Reset cache
$script:DirectoryObjectCache = @{}

# Test 7.1: Default to User entity type
try
{
    $result = Resolve-DirectoryObject -EntityName "john.doe@contoso.com" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues
    Write-TestResult "7.1 - Default entity type is User" ($result -eq "john.doe@contoso.com")
}
catch
{
    Write-TestResult "7.1 - Default entity type" $false "Exception: $_"
}

# Test 7.2: Explicit User entity type
try
{
    $script:DirectoryObjectCache = @{}
    $result = Resolve-DirectoryObject -EntityName "jane.smith@contoso.com" -AccessToken "test-token" -Settings @{maxUserMatchDisplay = 10} -ReturnValues $global:returnValues -EntityType "User"
    Write-TestResult "7.2 - Explicit User entity type works" ($result -eq "jane.smith@contoso.com")
}
catch
{
    Write-TestResult "7.2 - Explicit User entity type" $false "Exception: $_"
}

# Test 7.3: Explicit Group entity type
try
{
    $script:DirectoryObjectCache = @{}
    $result = Resolve-DirectoryObject -EntityName "Sales Team" -AccessToken "test-token" -Settings @{maxGroupMatchDisplay = 10} -ReturnValues $global:returnValues -EntityType "Group"
    Write-TestResult "7.3 - Explicit Group entity type works" ($result -eq "Sales Team")
}
catch
{
    Write-TestResult "7.3 - Explicit Group entity type" $false "Exception: $_"
}
#endregion

#endregion

#region Cleanup and Summary
Write-TestHeader "Test Execution Complete"

# Clean up mock objects
$script:MockUserDatabase = $null
$script:MockGroupDatabase = $null
$script:MockShowDirectoryObjectListResponse = $null
$script:DirectoryObjectCache = $null

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

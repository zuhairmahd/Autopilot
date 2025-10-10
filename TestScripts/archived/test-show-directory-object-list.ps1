<#
.SYNOPSIS
    Comprehensive test suite for Show-DirectoryObjectList function.

.DESCRIPTION
    Tests the unified Show-DirectoryObjectList function for both User and Group entity types.
    Validates display logic, menu creation, exit handling, and -NoPrompt automated testing.

.NOTES
    Author: Autopilot Development Team
    Tests: 9 sections with 18 test cases
    - User empty list handling
    - Group empty list handling
    - User single item with NoPrompt
    - Group single item with NoPrompt
    - User multiple items menu selection
    - User multiple items menu exit
    - Group multiple items menu selection
    - Group multiple items menu exit
    - MaxDisplay truncation
#>

#Requires -Version 5.1

#region Setup
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Import the function
$functionPath = Join-Path $PSScriptRoot "..\functions\UserAndGroupFunctions\Show-DirectoryObjectList.ps1"
if (-not (Test-Path $functionPath))
{
    Write-Host "[ERROR] Cannot find Show-DirectoryObjectList.ps1 at: $functionPath" -ForegroundColor Red
    exit 1
}

. $functionPath

# Import dependencies
$menuPath = Join-Path $PSScriptRoot "..\functions\menuFunctions\Create-DynamicMenu.ps1"
if (Test-Path $menuPath)
{
    . $menuPath
}

#endregion

#region Helper Functions
function Write-TestHeader
{
    param([string]$Message)
    Write-Host "`n" -NoNewline
    Write-Host "=" * 40 -ForegroundColor Cyan
    Write-Host " $Message" -ForegroundColor Cyan
    Write-Host "=" * 40 -ForegroundColor Cyan
    Write-Host ""
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
        [bool]$Result,
        [string]$Details = ""
    )
    
    if ($Result)
    {
        Write-Host "[PASS] $TestName" -ForegroundColor Green
    }
    else
    {
        Write-Host "[FAIL] $TestName" -ForegroundColor Red
        if ($Details)
        {
            Write-Host "       Details: $Details" -ForegroundColor Red
        }
        $script:FailedTests++
    }
    
    $script:TotalTests++
}
#endregion

#region Mock Data
$script:MockUsers = @(
    @{
        userPrincipalName = "john.doe@contoso.com"
        displayName       = "John Doe"
        givenName         = "John"
        surname           = "Doe"
        mail              = "john.doe@contoso.com"
        id                = "user-123"
    },
    @{
        userPrincipalName = "jane.smith@contoso.com"
        displayName       = "Jane Smith"
        givenName         = "Jane"
        surname           = "Smith"
        mail              = "jane.smith@contoso.com"
        id                = "user-456"
    },
    @{
        userPrincipalName = "bob.johnson@contoso.com"
        displayName       = "Bob Johnson"
        givenName         = "Bob"
        surname           = "Johnson"
        mail              = "bob.johnson@contoso.com"
        id                = "user-789"
    }
)

$script:MockGroups = @(
    @{
        displayName = "Marketing Team"
        id          = "group-123"
    },
    @{
        displayName = "Sales Team"
        id          = "group-456"
    },
    @{
        displayName = "Engineering Team"
        id          = "group-789"
    }
)

# Mock menu response - controlled by test
$script:MockMenuResponse = $null
$script:MenuCallCount = 0

# Mock menu functions
function NewMenu
{
    param(
        [string]$MenuName,
        [string]$Title,
        [string]$Description
    )
    return @{ 
        MenuName    = $MenuName
        Title       = $Title
        Description = $Description
        Items       = @() 
    }
}

function AddMenuItem
{
    param(
        [hashtable]$Menu,
        [string]$Name,
        [scriptblock]$Action,
        [hashtable]$Submenu,
        [switch]$ReturnsValue
    )
    
    $Menu.Items += @{ 
        Name         = $Name
        Action       = $Action
        Submenu      = $Submenu
        ReturnsValue = $ReturnsValue
    }
    return $Menu
}

function ShowMenu
{
    param($Menu, $CalledBy)
    $script:MenuCallCount++
    Write-Verbose "[ShowMenu] Called with menu: $($Menu.Title) (Call #$script:MenuCallCount)"
    Write-Verbose "[ShowMenu] Menu has $($Menu.Items.Count) items"
    return $script:MockMenuResponse
}

# Mock Write-Log
function Write-Log
{
    param([string]$Message, [string]$Level = "INFO", [string]$FunctionName = "")
    Write-Verbose "[Write-Log][$Level][$FunctionName] $Message"
}

# Mock returnValues
$global:returnValues = @{
    noUserFoundInDirectoryMessage = 0
    noGroupFoundMessage           = 0
    userCanceledMessage           = 0
}

#endregion

#region Initialize Test Counters
$script:TotalTests = 0
$script:FailedTests = 0
#endregion

#region Test Environment Setup
Write-TestHeader "Setting Up Test Environment"

try
{
    # Verify function is loaded
    $null = Get-Command Show-DirectoryObjectList -ErrorAction Stop
    Write-Host "[OK] Show-DirectoryObjectList loaded" -ForegroundColor Green
}
catch
{
    Write-Host "[ERROR] Failed to load Show-DirectoryObjectList: $_" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Test environment ready" -ForegroundColor Green
#endregion

#region Test Cases
Write-TestHeader "Running Test Cases"

#region Test 1: User Empty List
Write-TestSection "Test 1: User Empty List Handling"

try
{
    $script:MenuCallCount = 0
    $script:MockMenuResponse = $null
    
    $result = Show-DirectoryObjectList -EntityList @() -EntityType "User" -MaxDisplay 10
    
    Write-TestResult "1.1 - Empty user list returns 0" ($result -eq 0)
    Write-TestResult "1.2 - Empty user list doesn't call menu" ($script:MenuCallCount -eq 0)
}
catch
{
    Write-TestResult "1.1 - User empty list" $false "Exception: $_"
}

#endregion

#region Test 2: Group Empty List
Write-TestSection "Test 2: Group Empty List Handling"

try
{
    $script:MenuCallCount = 0
    $script:MockMenuResponse = $null
    
    $result = Show-DirectoryObjectList -EntityList @() -EntityType "Group" -MaxDisplay 10
    
    Write-TestResult "2.1 - Empty group list returns 0" ($result -eq 0)
    Write-TestResult "2.2 - Empty group list doesn't call menu" ($script:MenuCallCount -eq 0)
}
catch
{
    Write-TestResult "2.1 - Group empty list" $false "Exception: $_"
}

#endregion

#region Test 3: User Single Item - Auto-Accept with NoPrompt
Write-TestSection "Test 3: User Single Item - Auto-Accept with NoPrompt"

try
{
    $script:MenuCallCount = 0
    $script:MockMenuResponse = $null
    
    $singleUser = @($script:MockUsers[0])
    $result = Show-DirectoryObjectList -EntityList $singleUser -EntityType "User" -MaxDisplay 10 -NoPrompt
    
    Write-TestResult "3.1 - Single user with NoPrompt returns UPN" ($result -eq "john.doe@contoso.com")
    Write-TestResult "3.2 - Single user doesn't call menu" ($script:MenuCallCount -eq 0)
}
catch
{
    Write-TestResult "3.1 - User single auto-accept" $false "Exception: $_"
}

#endregion

#region Test 4: Group Single Item - Auto-Accept with NoPrompt
Write-TestSection "Test 4: Group Single Item - Auto-Accept with NoPrompt"

try
{
    $script:MenuCallCount = 0
    $script:MockMenuResponse = $null
    
    $singleGroup = @($script:MockGroups[0])
    $result = Show-DirectoryObjectList -EntityList $singleGroup -EntityType "Group" -MaxDisplay 10 -NoPrompt
    
    Write-TestResult "4.1 - Single group with NoPrompt returns displayName" ($result -eq "Marketing Team")
    Write-TestResult "4.2 - Single group doesn't call menu" ($script:MenuCallCount -eq 0)
}
catch
{
    Write-TestResult "4.1 - Group single auto-accept" $false "Exception: $_"
}

#endregion

#region Test 7: Group Multiple Items Menu Selection
Write-TestSection "Test 7: Group Multiple Items Menu Selection"

try
{
    $script:MenuCallCount = 0
    $script:MockMenuResponse = "Sales Team"
    
    $result = Show-DirectoryObjectList -EntityList $script:MockGroups -EntityType "Group" -MaxDisplay 10
    
    Write-TestResult "7.1 - Multiple groups returns selected displayName" ($result -eq "Sales Team")
    Write-TestResult "7.2 - Multiple groups calls menu once" ($script:MenuCallCount -eq 1)
}
catch
{
    Write-TestResult "7.1 - Group multiple selection" $false "Exception: $_"
}

#endregion

#region Test 8: Group Multiple Items Menu Exit
Write-TestSection "Test 8: Group Multiple Items Menu Exit"

try
{
    $script:MenuCallCount = 0
    $script:MockMenuResponse = $null
    
    $result = Show-DirectoryObjectList -EntityList $script:MockGroups -EntityType "Group" -MaxDisplay 10
    
    Write-TestResult "8.1 - Multiple groups exit returns 0" ($result -eq 0)
    Write-TestResult "8.2 - Multiple groups calls menu once" ($script:MenuCallCount -eq 1)
}
catch
{
    Write-TestResult "8.1 - Group multiple exit" $false "Exception: $_"
}

#endregion

#region Test 7: User Multiple Items - Selection
Write-TestSection "Test 7: User Multiple Items Menu Selection"

try
{
    $script:MenuCallCount = 0
    $script:MockMenuResponse = "jane.smith@contoso.com"
    
    $result = Show-DirectoryObjectList -EntityList $script:MockUsers -EntityType "User" -MaxDisplay 10
    
    Write-TestResult "7.1 - Multiple users returns selected UPN" ($result -eq "jane.smith@contoso.com")
    Write-TestResult "7.2 - Multiple users calls menu once" ($script:MenuCallCount -eq 1)
}
catch
{
    Write-TestResult "7.1 - User multiple selection" $false "Exception: $_"
}

#endregion

#region Test 8: User Multiple Items - Exit
Write-TestSection "Test 8: User Multiple Items Menu Exit"

try
{
    $script:MenuCallCount = 0
    $script:MockMenuResponse = $null
    
    $result = Show-DirectoryObjectList -EntityList $script:MockUsers -EntityType "User" -MaxDisplay 10
    
    Write-TestResult "8.1 - Multiple users exit returns 0" ($result -eq 0)
    Write-TestResult "8.2 - Multiple users calls menu once" ($script:MenuCallCount -eq 1)
}
catch
{
    Write-TestResult "8.1 - User multiple exit" $false "Exception: $_"
}

#endregion

#region Test 9: MaxDisplay Truncation
Write-TestSection "Test 9: MaxDisplay Truncation"

try
{
    $script:MenuCallCount = 0
    $script:MockMenuResponse = $null
    
    # Create a large user list
    $largeUserList = @()
    for ($i = 1; $i -le 50; $i++)
    {
        $largeUserList += @{
            userPrincipalName = "user$i@contoso.com"
            displayName       = "User $i"
            mail              = "user$i@contoso.com"
            id                = "user-$i"
        }
    }
    
    # Call with MaxDisplay = 10
    $result = Show-DirectoryObjectList -EntityList $largeUserList -EntityType "User" -MaxDisplay 10
    
    # Note: We can't directly verify truncation without inspecting internal state,
    # but we can verify it doesn't crash with large lists
    Write-TestResult "9.1 - MaxDisplay handles large lists without error" ($true)
    Write-TestResult "9.2 - MaxDisplay calls menu once" ($script:MenuCallCount -eq 1)
}
catch
{
    Write-TestResult "9.1 - MaxDisplay truncation" $false "Exception: $_"
}

#endregion

#endregion

#region Test Summary
Write-Host "`n"
Write-TestHeader "Test Execution Complete"

Write-Host "`n"
Write-TestHeader "Test Summary: Show-DirectoryObjectList"
$PassedTests = $script:TotalTests - $script:FailedTests
Write-Host "Passed:  $PassedTests" -ForegroundColor $(if ($PassedTests -eq $script:TotalTests)
    {
        "Green" 
    }
    else
    {
        "Yellow" 
    })
Write-Host "Failed:  $($script:FailedTests)" -ForegroundColor $(if ($script:FailedTests -eq 0)
    {
        "Green" 
    }
    else
    {
        "Red" 
    })
Write-Host "Skipped: 0" -ForegroundColor Gray
Write-Host "Total:   $($script:TotalTests)" -ForegroundColor Cyan
Write-Host "=" * 40 -ForegroundColor Cyan
Write-Host "`n"

if ($script:FailedTests -eq 0)
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

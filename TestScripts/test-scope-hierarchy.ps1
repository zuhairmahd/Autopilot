<#
.SYNOPSIS
    Test script for Test-ScopeHierarchy function
.DESCRIPTION
    Validates that the hierarchical scope comparison correctly identifies when
    higher-privilege scopes satisfy lower-privilege requirements.
#>

# Import required functions
$scriptRoot = if ($PSScriptRoot)
{
    Split-Path -Parent $PSScriptRoot 
}
else
{
    "C:\Users\zuhai\code\Autopilot" 
}
. "$scriptRoot\functions\graphFunctions\Test-ScopeHierarchy.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test-ScopeHierarchy Validation Suite" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$testsPassed = 0
$testsFailed = 0

function Test-Case
{
    param(
        [string]$TestName,
        [string]$RequiredScope,
        [string[]]$AvailableScopes,
        [bool]$ExpectedResult
    )
    
    Write-Host "Test: $TestName" -ForegroundColor Yellow
    Write-Host "  Required  : $RequiredScope" -ForegroundColor Gray
    Write-Host "  Available : $($AvailableScopes -join ', ')" -ForegroundColor Gray
    Write-Host "  Expected  : $ExpectedResult" -ForegroundColor Gray
    
    $result = Test-ScopeHierarchy -RequiredScope $RequiredScope -AvailableScopes $AvailableScopes -Verbose
    
    if ($result -eq $ExpectedResult)
    {
        Write-Host "  Result    : PASS`n" -ForegroundColor Green
        $script:testsPassed++
        return $true
    }
    else
    {
        Write-Host "  Result    : FAIL (Got: $result, Expected: $ExpectedResult)`n" -ForegroundColor Red
        $script:testsFailed++
        return $false
    }
}

Write-Host "=== Operation Hierarchy Tests ===" -ForegroundColor Cyan

# ReadWrite should satisfy Read requirement
Test-Case -TestName "Device.ReadWrite.All satisfies Device.Read.All" `
    -RequiredScope "Device.Read.All" `
    -AvailableScopes @("Device.ReadWrite.All") `
    -ExpectedResult $true

# Read should NOT satisfy ReadWrite requirement
Test-Case -TestName "Device.Read.All does NOT satisfy Device.ReadWrite.All" `
    -RequiredScope "Device.ReadWrite.All" `
    -AvailableScopes @("Device.Read.All") `
    -ExpectedResult $false

# ReadWrite should satisfy Read requirement (User resource)
Test-Case -TestName "User.ReadWrite.All satisfies User.Read.All" `
    -RequiredScope "User.Read.All" `
    -AvailableScopes @("User.ReadWrite.All") `
    -ExpectedResult $true

# Manage should satisfy ReadWrite
Test-Case -TestName "Group.Manage.All satisfies Group.ReadWrite.All" `
    -RequiredScope "Group.ReadWrite.All" `
    -AvailableScopes @("Group.Manage.All") `
    -ExpectedResult $true

Write-Host "`n=== Constraint Hierarchy Tests ===" -ForegroundColor Cyan

# .All should satisfy non-.All requirement
Test-Case -TestName "User.Read.All satisfies User.Read" `
    -RequiredScope "User.Read" `
    -AvailableScopes @("User.Read.All") `
    -ExpectedResult $true

# Non-.All should NOT satisfy .All requirement
Test-Case -TestName "User.Read does NOT satisfy User.Read.All" `
    -RequiredScope "User.Read.All" `
    -AvailableScopes @("User.Read") `
    -ExpectedResult $false

# .All should satisfy .OwnedBy
Test-Case -TestName "Application.ReadWrite.All satisfies Application.ReadWrite.OwnedBy" `
    -RequiredScope "Application.ReadWrite.OwnedBy" `
    -AvailableScopes @("Application.ReadWrite.All") `
    -ExpectedResult $true

# .OwnedBy should NOT satisfy .All
Test-Case -TestName "Application.ReadWrite.OwnedBy does NOT satisfy Application.ReadWrite.All" `
    -RequiredScope "Application.ReadWrite.All" `
    -AvailableScopes @("Application.ReadWrite.OwnedBy") `
    -ExpectedResult $false

Write-Host "`n=== Combined Hierarchy Tests ===" -ForegroundColor Cyan

# Higher operation + broader constraint satisfies lower operation + narrower constraint
Test-Case -TestName "Device.ReadWrite.All satisfies Device.Read" `
    -RequiredScope "Device.Read" `
    -AvailableScopes @("Device.ReadWrite.All") `
    -ExpectedResult $true

# Same operation, broader constraint
Test-Case -TestName "Mail.Read.All satisfies Mail.Read" `
    -RequiredScope "Mail.Read" `
    -AvailableScopes @("Mail.Read.All") `
    -ExpectedResult $true

# Higher operation, same constraint
Test-Case -TestName "Calendars.ReadWrite satisfies Calendars.Read" `
    -RequiredScope "Calendars.Read" `
    -AvailableScopes @("Calendars.ReadWrite") `
    -ExpectedResult $true

Write-Host "`n=== Exact Match Tests ===" -ForegroundColor Cyan

# Exact match should always work
Test-Case -TestName "Exact match: Device.Read.All" `
    -RequiredScope "Device.Read.All" `
    -AvailableScopes @("Device.Read.All") `
    -ExpectedResult $true

# Case-insensitive exact match
Test-Case -TestName "Case-insensitive: device.read.all matches Device.Read.All" `
    -RequiredScope "Device.Read.All" `
    -AvailableScopes @("device.read.all") `
    -ExpectedResult $true

Write-Host "`n=== Multiple Available Scopes Tests ===" -ForegroundColor Cyan

# Should find satisfying scope among multiple available
Test-Case -TestName "Find Device.ReadWrite.All among multiple scopes" `
    -RequiredScope "Device.Read.All" `
    -AvailableScopes @("User.Read.All", "Device.ReadWrite.All", "Mail.Read") `
    -ExpectedResult $true

# No satisfying scope among multiple
Test-Case -TestName "No satisfying scope among multiple" `
    -RequiredScope "Device.ReadWrite.All" `
    -AvailableScopes @("User.Read.All", "Device.Read.All", "Mail.Read") `
    -ExpectedResult $false

Write-Host "`n=== Edge Cases ===" -ForegroundColor Cyan

# Empty available scopes
Test-Case -TestName "Empty available scopes array" `
    -RequiredScope "Device.Read.All" `
    -AvailableScopes @() `
    -ExpectedResult $false

# Different resource
Test-Case -TestName "Different resource: User vs Device" `
    -RequiredScope "Device.Read.All" `
    -AvailableScopes @("User.ReadWrite.All") `
    -ExpectedResult $false

# ReadBasic should NOT satisfy Read (ReadBasic < Read)
Test-Case -TestName "ReadBasic does NOT satisfy Read" `
    -RequiredScope "User.Read.All" `
    -AvailableScopes @("User.ReadBasic.All") `
    -ExpectedResult $false

# Read should satisfy ReadBasic (Read > ReadBasic)
Test-Case -TestName "User.Read.All satisfies User.ReadBasic.All" `
    -RequiredScope "User.ReadBasic.All" `
    -AvailableScopes @("User.Read.All") `
    -ExpectedResult $true

Write-Host "`n=== Real-World Scenarios ===" -ForegroundColor Cyan

# Common scenario: App has broader permissions
Test-Case -TestName "App has Device.ReadWrite.All, needs Device.Read.All" `
    -RequiredScope "Device.Read.All" `
    -AvailableScopes @("Device.ReadWrite.All", "User.Read.All", "Group.Read.All") `
    -ExpectedResult $true

# Common scenario: App lacks write permission
Test-Case -TestName "App has Device.Read.All, needs Device.ReadWrite.All" `
    -RequiredScope "Device.ReadWrite.All" `
    -AvailableScopes @("Device.Read.All", "User.Read.All", "Group.Read.All") `
    -ExpectedResult $false

# Common scenario: Sufficient delegated permissions
Test-Case -TestName "Delegated User.ReadWrite satisfies User.Read" `
    -RequiredScope "User.Read" `
    -AvailableScopes @("User.ReadWrite", "offline_access", "openid") `
    -ExpectedResult $true

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Test Results Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Tests : $($testsPassed + $testsFailed)" -ForegroundColor White
Write-Host "Passed      : $testsPassed" -ForegroundColor Green
Write-Host "Failed      : $testsFailed" -ForegroundColor $(if ($testsFailed -eq 0)
    {
        'Green' 
    }
    else
    {
        'Red' 
    })
Write-Host "========================================`n" -ForegroundColor Cyan

if ($testsFailed -eq 0)
{
    Write-Host "All tests passed! ✓" -ForegroundColor Green
    exit 0
}
else
{
    Write-Host "Some tests failed. Review the output above." -ForegroundColor Red
    exit 1
}

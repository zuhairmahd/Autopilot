<#
.SYNOPSIS
    Debug script for ProfileAssignment batch API issue

.DESCRIPTION
    Adds detailed logging to trace the batch API request/response flow
    for the failing ProfileAssignment test.
#>

Import-Module "$PSScriptRoot/../tests/Helpers/AutopilotTestHelpers.psm1" -Force
Import-Module "$PSScriptRoot/../tests/Helpers/AutopilotGraphMocks.psm1" -Force

Write-Host "`n=== ProfileAssignment Debug Test ===" -ForegroundColor Cyan

# Initialize test environment
$TestContext = Initialize-AutopilotTestEnvironment
$RepoRoot = $TestContext.RootPath

# Load the function
. (Join-Path $RepoRoot "functions/UserAndGroupFunctions/Get-GroupDirectAssignments.ps1")

# Initialize mocks
Initialize-GraphMockEnvironment -ClearCache

# Add mock data
Write-Host "`n1. Adding mock data..." -ForegroundColor Yellow
Add-MockAutopilotProfile -DisplayName "Test-Profile-1" -Id "profile-test-01"
Add-MockGroup -DisplayName "Test-Group-1" -Id "group-test-01"

# Verify mock data was added
$profileCount = if ($script:MockProfiles) { $script:MockProfiles.Keys.Count } else { 0 }
$groupCount = if ($script:MockGroups) { $script:MockGroups.Keys.Count } else { 0 }
Write-Host "   - Mock profiles: $profileCount profiles" -ForegroundColor Gray
Write-Host "   - Mock groups: $groupCount groups" -ForegroundColor Gray

# Add assignment
Write-Host "`n2. Adding profile assignment..." -ForegroundColor Yellow
Add-MockProfileAssignment -ProfileId "profile-test-01" -TargetId "group-test-01"
$assignmentCount = if ($script:MockProfileAssignments) { $script:MockProfileAssignments.Count } else { 0 }
Write-Host "   - Mock assignments: $assignmentCount assignments" -ForegroundColor Gray

# Display assignment details
if ($script:MockProfileAssignments.Count -gt 0)
{
    $assignment = $script:MockProfileAssignments[0]
    Write-Host "   - Assignment profileId: $($assignment.profileId)" -ForegroundColor Gray
    Write-Host "   - Assignment target @odata.type: $($assignment.target.'@odata.type')" -ForegroundColor Gray
    Write-Host "   - Assignment target groupId: $($assignment.target.groupId)" -ForegroundColor Gray
}

# Mock CallGraphAPI
Write-Host "`n3. Setting up CallGraphAPI mock..." -ForegroundColor Yellow
function global:CallGraphAPI
{
    param($accessToken, $ResourcePath, $Filter, $ExtraParameters, [switch]$consistencyLevel, [string]$Method = 'GET', $Body = $null, [string]$apiVersion = 'v1.0')

    Write-Host "   [CallGraphAPI] Method=$Method, Path=$ResourcePath" -ForegroundColor DarkGray
    if ($Method -eq 'POST' -and $ResourcePath -eq '$batch')
    {
        Write-Host "   [CallGraphAPI] Batch request detected" -ForegroundColor DarkGray
        if ($Body)
        {
            $bodyObj = $Body | ConvertFrom-Json
            Write-Host "   [CallGraphAPI] Batch has $($bodyObj.requests.Count) requests" -ForegroundColor DarkGray
            foreach ($req in $bodyObj.requests)
            {
                Write-Host "   [CallGraphAPI]   - Request ID: $($req.id), URL: $($req.url)" -ForegroundColor DarkGray
            }
        }
    }

    $result = Invoke-MockGraphAPI -accessToken $accessToken -ResourcePath $ResourcePath `
        -Filter $Filter -ExtraParameters $ExtraParameters -consistencyLevel:$consistencyLevel `
        -Method $Method -Body $Body -apiVersion $apiVersion

    if ($Method -eq 'POST' -and $ResourcePath -eq '$batch' -and $result.responses)
    {
        Write-Host "   [CallGraphAPI] Batch response has $($result.responses.Count) responses" -ForegroundColor DarkGray
        foreach ($resp in $result.responses)
        {
            $valueCount = if ($resp.body.value) { $resp.body.value.Count } else { 0 }
            Write-Host "   [CallGraphAPI]   - Response ID: $($resp.id), Status: $($resp.status), Items: $valueCount" -ForegroundColor DarkGray

            # Show autopilot profiles in detail
            if ($resp.id -eq 'autopilotProfiles' -and $resp.body.value)
            {
                Write-Host "   [CallGraphAPI]     Autopilot Profiles:" -ForegroundColor Cyan
                foreach ($prof in $resp.body.value)
                {
                    Write-Host "   [CallGraphAPI]       - $($prof.displayName) ($($prof.id))" -ForegroundColor Cyan
                }
            }
        }
    }

    return $result
}

# Create test group and token
$token = New-MockAuthToken
$testGroup = @{
    id          = "group-test-01"
    displayName = "Test-Group-1"
}

# Execute the function
Write-Host "`n4. Calling Get-GroupDirectAssignments..." -ForegroundColor Yellow
$result = Get-GroupDirectAssignments -AccessToken $token -GroupName $testGroup -IncludeBeta

# Display results
Write-Host "`n5. Results:" -ForegroundColor Yellow
Write-Host "   - Result is null: $($null -eq $result)" -ForegroundColor Gray
if ($result)
{
    Write-Host "   - GroupName: $($result.GroupName)" -ForegroundColor Gray
    Write-Host "   - GroupId: $($result.GroupId)" -ForegroundColor Gray
    Write-Host "   - AutopilotAssignments count: $($result.AutopilotAssignments.Count)" -ForegroundColor Gray
    Write-Host "   - AllAssignments count: $($result.AllAssignments.Count)" -ForegroundColor Gray

    if ($result.AutopilotAssignments.Count -gt 0)
    {
        Write-Host "`n   Autopilot Assignments:" -ForegroundColor Green
        foreach ($assignment in $result.AutopilotAssignments)
        {
            Write-Host "     - Id: $($assignment.Id)" -ForegroundColor Green
            Write-Host "     - Name: $($assignment.Name)" -ForegroundColor Green
            Write-Host "     - Type: $($assignment.Type)" -ForegroundColor Green
        }
    }
    else
    {
        Write-Host "`n   No Autopilot assignments found!" -ForegroundColor Red
    }
}

# Cleanup
Write-Host "`n6. Cleaning up..." -ForegroundColor Yellow
Remove-TestEnvironment -TestContext $TestContext
Clear-GraphMockEnvironment

Write-Host "`n=== Debug Test Complete ===`n" -ForegroundColor Cyan

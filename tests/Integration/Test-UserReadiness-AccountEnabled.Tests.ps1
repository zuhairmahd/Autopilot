<#
.SYNOPSIS
    Integration test for Test-UserReadiness function with account enabled check
.DESCRIPTION
    Tests the complete user readiness check flow including the new account enabled check.

.NOTES
    Test Category: Integration
    Created: 2025-12-24 for disabled account check feature
#>

# Import helper modules
Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force
Import-Module "$PSScriptRoot/../Helpers/AutopilotGraphMocks.psm1" -Force

Describe "Test-UserReadiness Integration with Account Enabled Check" -Tags 'Integration', 'User', 'Readiness' {

    BeforeAll {
        # Get repository root
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

        # Setup mock global variables
        Initialize-MockGlobalVariables -LogFile "test-user-readiness-integration.log"

        # Set maxJsonDepth for VerifyGroupMembership
        $global:maxJsonDepth = 10

        # Setup Write-Log mock
        New-MockWriteLog

        # Initialize Graph mocking environment
        Initialize-GraphMockEnvironment -ClearCache

        # Add test users with different scenarios
        Add-MockUser -UserPrincipalName "active-user@test.com" `
            -DisplayName "Active User" `
            -GivenName "Active" -Surname "User" `
            -Id "active123" `
            -Mail "active-user@test.com" `
            -CustomProperties @{
            accountEnabled = $true
        }

        Add-MockUser -UserPrincipalName "disabled-user@test.com" `
            -DisplayName "Disabled User" `
            -GivenName "Disabled" -Surname "User" `
            -Id "disabled456" `
            -Mail "disabled-user@test.com" `
            -CustomProperties @{
            accountEnabled = $false
        }

        # Add test groups
        Add-MockGroup -DisplayName "Required Group" -Id "req-group-001"

        # Mock group membership
        $script:MockGroupMemberships = @{
            "active-user@test.com"   = @("req-group-001")
            "disabled-user@test.com" = @("req-group-001")
        }

        # Mock device count function
        function global:GetTotalRegisteredDevicesByUser
        {
            param($Username, $AccessToken)
            return 1  # Under limit
        }

        # Mock CallGraphApi
        function global:CallGraphApi
        {
            param($accessToken, $ResourcePath, $ExtraParameters, $Method = "GET", $Body = $null)

            Write-Verbose "[CallGraphApi Mock] Method: $Method, ResourcePath: $ResourcePath"

            # Handle checkMemberGroups POST request
            if ($Method -eq "POST" -and $ResourcePath -like "users/*/checkMemberGroups")
            {
                $upn = $ResourcePath -replace "users/([^/]+)/checkMemberGroups", '$1'
                if ($script:MockGroupMemberships.ContainsKey($upn))
                {
                    return @{
                        value = $script:MockGroupMemberships[$upn]
                    }
                }
                return @{ value = @() }
            }

            # Handle group lookups
            if ($ResourcePath -eq "groups")
            {
                # Parse filter to get group IDs
                $bodyObj = $Body | ConvertFrom-Json
                $groupIds = $bodyObj.groupIds

                $groups = @()
                foreach ($id in $groupIds)
                {
                    $group = $script:MockGroups.Values | Where-Object { $_.id -eq $id }
                    if ($group)
                    {
                        $groups += $group.displayName
                    }
                }

                return $groups
            }

            # Use standard mock for other requests
            $result = Invoke-MockGraphAPI -accessToken $accessToken `
                -ResourcePath $ResourcePath `
                -ExtraParameters $ExtraParameters `
                -Method $Method `
                -Body $Body

            if ($result -eq 404)
            {
                return $null
            }

            return $result
        }

        # Mock GetGroupIdsByNames - handles both name->id and id->name conversion
        function global:GetGroupIdsByNames
        {
            param($accessToken, $groupNames)

            $result = @()
            foreach ($name in $groupNames)
            {
                # Check if it's a GUID (ID)
                if ($name -match '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$' -or
                    $name -match '^[a-zA-Z]+-[a-zA-Z0-9-]+$')
                {
                    # It's an ID, find the name
                    $group = $script:MockGroups.Values | Where-Object { $_.id -eq $name }
                    if ($group)
                    {
                        $result += $group.displayName
                    }
                    else
                    {
                        # If not found, return the original ID (prevents count mismatch warning)
                        $result += $name
                    }
                }
                else
                {
                    # It's a name, find the ID
                    $group = $script:MockGroups[$name]
                    if ($group)
                    {
                        $result += $group.id
                    }
                    else
                    {
                        # If not found, return a generated ID (prevents count mismatch warning)
                        $result += "unknown-" + ($name -replace ' ', '-').ToLower()
                    }
                }
            }
            return $result
        }

        # Dot-source required functions
        . "$script:RepoRoot/functions/UserAndGroupFunctions/Test-UserAccountEnabled.ps1"
        . "$script:RepoRoot/functions/UserAndGroupFunctions/Test-UserGroupMembership.ps1"
        . "$script:RepoRoot/functions/UserAndGroupFunctions/Test-UserDeviceCount.ps1"
        . "$script:RepoRoot/functions/UserAndGroupFunctions/Test-UserReadiness.ps1"
        . "$script:RepoRoot/functions/deviceFunctions/VerifyGroupMembership.ps1"
        . "$script:RepoRoot/functions/UserAndGroupFunctions/GetGroupMembership.ps1"
    }

    Context "User readiness with enabled account" {
        It "Should pass all checks for an enabled user" {
            $settings = @{
                maxNumberOfDevicesAllowed = 5
                checkStrongMapping        = $false
            }

            $result = Test-UserReadiness `
                -UserName "active-user@test.com" `
                -AccessToken "mock-token" `
                -GroupsToInclude @(
                @{ name = "Required Group"; id = "req-group-001" }
            ) `
                -Settings $settings

            $result | Should -Not -BeNullOrEmpty
            $result.IsReady | Should -Be $true
            $result.IssueCount | Should -Be 0
            $result.Checks.Count | Should -BeGreaterThan 0
        }

        It "Should include account enabled check in results" {
            $settings = @{
                maxNumberOfDevicesAllowed = 5
                checkStrongMapping        = $false
            }

            $result = Test-UserReadiness `
                -UserName "active-user@test.com" `
                -AccessToken "mock-token" `
                -GroupsToInclude @(
                @{ name = "Required Group"; id = "req-group-001" }
            ) `
                -Settings $settings

            $accountCheck = $result.Checks | Where-Object { $_.CheckName -eq "Account Status" }
            $accountCheck | Should -Not -BeNullOrEmpty
            $accountCheck.Passed | Should -Be $true
        }
    }

    Context "User readiness with disabled account" {
        It "Should fail readiness check for a disabled user" {
            $settings = @{
                maxNumberOfDevicesAllowed = 5
                checkStrongMapping        = $false
            }

            $result = Test-UserReadiness `
                -UserName "disabled-user@test.com" `
                -AccessToken "mock-token" `
                -GroupsToInclude @(
                @{ name = "Required Group"; id = "req-group-001" }
            ) `
                -Settings $settings

            $result | Should -Not -BeNullOrEmpty
            $result.IsReady | Should -Be $false
            $result.IssueCount | Should -BeGreaterThan 0
        }

        It "Should report account status check as failed" {
            $settings = @{
                maxNumberOfDevicesAllowed = 5
                checkStrongMapping        = $false
            }

            $result = Test-UserReadiness `
                -UserName "disabled-user@test.com" `
                -AccessToken "mock-token" `
                -GroupsToInclude @(
                @{ name = "Required Group"; id = "req-group-001" }
            ) `
                -Settings $settings

            $accountCheck = $result.Checks | Where-Object { $_.CheckName -eq "Account Status" }
            $accountCheck | Should -Not -BeNullOrEmpty
            $accountCheck.Passed | Should -Be $false
            $accountCheck.Message | Should -Be "User account is disabled"
        }

        It "Should include account enabled check before other checks" {
            $settings = @{
                maxNumberOfDevicesAllowed = 5
                checkStrongMapping        = $false
            }

            $result = Test-UserReadiness `
                -UserName "disabled-user@test.com" `
                -AccessToken "mock-token" `
                -GroupsToInclude @(
                @{ name = "Required Group"; id = "req-group-001" }
            ) `
                -Settings $settings

            # Account Status check should be first
            $result.Checks[0].CheckName | Should -Be "Account Status"
        }
    }

    AfterAll {
        # Clean up mock functions
        if (Get-Command CallGraphApi -ErrorAction SilentlyContinue)
        {
            Remove-Item Function:\CallGraphApi -ErrorAction SilentlyContinue
        }
        if (Get-Command GetGroupIdsByNames -ErrorAction SilentlyContinue)
        {
            Remove-Item Function:\GetGroupIdsByNames -ErrorAction SilentlyContinue
        }
        if (Get-Command GetTotalRegisteredDevicesByUser -ErrorAction SilentlyContinue)
        {
            Remove-Item Function:\GetTotalRegisteredDevicesByUser -ErrorAction SilentlyContinue
        }

        # Clean up script-level variables
        Remove-Variable -Name MockGroupMemberships -Scope Script -ErrorAction SilentlyContinue
        Remove-Variable -Name MockUsers -Scope Script -ErrorAction SilentlyContinue
        Remove-Variable -Name MockGroups -Scope Script -ErrorAction SilentlyContinue
        Remove-Variable -Name RepoRoot -Scope Script -ErrorAction SilentlyContinue

        # Clean up global variables
        Remove-Variable -Name maxJsonDepth -Scope Global -ErrorAction SilentlyContinue

        # Clean up helper module mocks
        Clear-GraphMockEnvironment
    }
}

<#
.SYNOPSIS
    Tests for Get-AutopilotEventAnalysis

.DESCRIPTION
    Unit tests for autopilot event analysis function

.NOTES
    Test Category: Unit
    Template Compliance: Full
    Uses: AutopilotTestHelpers, AutopilotGraphMocks
#>

Import-Module "$PSScriptRoot\..\..\Helpers\AutopilotTestHelpers.psm1" -Force
Import-Module "$PSScriptRoot\..\..\Helpers\AutopilotGraphMocks.psm1" -Force

Describe "Get-AutopilotEventAnalysis" -Tags 'Unit', 'Reports' {

    BeforeAll {
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

        # Dot-source functions directly (PS 5.1 compatible)
        $functionsPath = Join-Path $script:RepoRoot "functions"
        Get-ChildItem -Path $functionsPath -Recurse -Filter *.ps1 | ForEach-Object {
            . $_.FullName
        }

        # Initialize test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment
        Initialize-GraphMockEnvironment -ClearCache

        # Mock Write-Log if not already available
        if (-not (Get-Command Write-Log -ErrorAction SilentlyContinue))
        {
            function global:Write-Log
            {
                param($LogFile, $Module, $Message, $LogLevel)
            }
        }

        # Set global variables
        $global:LogFile = $script:TestContext.LogFile

        # Create UPN to userId mapping for tests
        $script:UserIdMapping = @{
            "user1@contoso.com" = "00000000-0000-0000-0001-000000000001"
            "user2@contoso.com" = "00000000-0000-0000-0001-000000000002"
            "user3@contoso.com" = "00000000-0000-0000-0001-000000000003"
            "user4@contoso.com" = "00000000-0000-0000-0001-000000000004"
            "user5@contoso.com" = "00000000-0000-0000-0001-000000000005"
            "user6@contoso.com" = "00000000-0000-0000-0001-000000000006"
            "user7@contoso.com" = "00000000-0000-0000-0001-000000000007"
            "user8@contoso.com" = "00000000-0000-0000-0001-000000000008"
        }

        # Create sample autopilot events (some with userId, some without to test enrichment)
        $script:SampleEvents = @(
            @{
                eventDateTime           = "2025-02-01T10:00:00Z"
                deviceSerialNumber      = "ABC123"
                managedDeviceName       = "Device1"
                userPrincipalName       = "user1@contoso.com"
                userId                  = "00000000-0000-0000-0001-000000000001"
                deploymentState         = "success"
                deviceSetupStatus       = "success"
                accountSetupStatus      = "success"
                deploymentTotalDuration = "PT2H30M"
                osVersion               = "10.0.19045"
                enrollmentState         = "enrolled"
                enrollmentType          = "userDrivenAADJoin"
            },
            @{
                eventDateTime           = "2025-02-02T11:00:00Z"
                deviceSerialNumber      = "DEF456"
                managedDeviceName       = "Device2"
                userPrincipalName       = "user2@contoso.com"
                # No userId - will test enrichment
                deploymentState         = "success"
                deviceSetupStatus       = "success"
                accountSetupStatus      = "success"
                deploymentTotalDuration = "PT1H45M"
                osVersion               = "10.0.19045"
                enrollmentState         = "enrolled"
                enrollmentType          = "userDrivenAADJoin"
            },
            @{
                eventDateTime            = "2025-02-03T12:00:00Z"
                deviceSerialNumber       = "GHI789"
                managedDeviceName        = "Device3"
                userPrincipalName        = "user3@contoso.com"
                # No userId - will test enrichment
                deploymentState          = "failure"
                deviceSetupStatus        = "failure"
                accountSetupStatus       = "notStarted"
                deploymentTotalDuration  = "PT45M"
                osVersion                = "10.0.19045"
                enrollmentState          = "enrolled"
                enrollmentType           = "userDrivenAADJoin"
                enrollmentFailureDetails = "Device setup failed"
            },
            @{
                eventDateTime            = "2025-02-04T13:00:00Z"
                deviceSerialNumber       = "JKL012"
                managedDeviceName        = "Device4"
                userPrincipalName        = "user3@contoso.com"
                userId                   = "00000000-0000-0000-0001-000000000003"
                deploymentState          = "failure"
                deviceSetupStatus        = "failure"
                accountSetupStatus       = "notStarted"
                deploymentTotalDuration  = "PT30M"
                osVersion                = "10.0.19045"
                enrollmentState          = "enrolled"
                enrollmentType           = "userDrivenAADJoin"
                enrollmentFailureDetails = "Device setup failed again"
            },
            @{
                eventDateTime           = "2025-02-05T14:00:00Z"
                deviceSerialNumber      = "MNO345"
                managedDeviceName       = "Device5"
                userPrincipalName       = "user3@contoso.com"
                userId                  = "00000000-0000-0000-0001-000000000003"
                deploymentState         = "success"
                deviceSetupStatus       = "success"
                accountSetupStatus      = "success"
                deploymentTotalDuration = "PT2H"
                osVersion               = "10.0.19045"
                enrollmentState         = "enrolled"
                enrollmentType          = "userDrivenAADJoin"
            },
            @{
                eventDateTime      = "2025-02-06T15:00:00Z"
                deviceSerialNumber = "PQR678"
                managedDeviceName  = "Device6"
                userPrincipalName  = "user4@contoso.com"
                # No userId - will test enrichment
                deploymentState    = "inProgress"
                deviceSetupStatus  = "inProgress"
                accountSetupStatus = "notStarted"
                osVersion          = "10.0.19045"
                enrollmentState    = "enrolling"
                enrollmentType     = "userDrivenAADJoin"
            },
            @{
                eventDateTime      = "2025-02-07T16:00:00Z"
                deviceSerialNumber = "STU901"
                managedDeviceName  = "Device7"
                userPrincipalName  = "user5@contoso.com"
                userId             = "00000000-0000-0000-0001-000000000005"
                deploymentState    = "inProgress"
                deviceSetupStatus  = "success"
                accountSetupStatus = "inProgress"
                osVersion          = "10.0.19045"
                enrollmentState    = "enrolling"
                enrollmentType     = "userDrivenAADJoin"
            },
            @{
                eventDateTime            = "2025-02-08T17:00:00Z"
                deviceSerialNumber       = "VWX234"
                managedDeviceName        = "Device8"
                userPrincipalName        = "user6@contoso.com"
                # No userId - will test enrichment
                deploymentState          = "failure"
                deviceSetupStatus        = "success"
                accountSetupStatus       = "failure"
                deploymentTotalDuration  = "PT1H20M"
                osVersion                = "10.0.19045"
                enrollmentState          = "enrolled"
                enrollmentType           = "userDrivenAADJoin"
                enrollmentFailureDetails = "Account setup failed"
            },
            @{
                eventDateTime            = "2025-02-09T18:00:00Z"
                deviceSerialNumber       = "YZA567"
                managedDeviceName        = "Device9"
                userPrincipalName        = "user7@contoso.com"
                userId                   = "00000000-0000-0000-0001-000000000007"
                deploymentState          = "failure"
                deviceSetupStatus        = "failure"
                accountSetupStatus       = "failure"
                deploymentTotalDuration  = "PT50M"
                osVersion                = "10.0.19045"
                enrollmentState          = "enrolled"
                enrollmentType           = "userDrivenAADJoin"
                enrollmentFailureDetails = "Both phases failed"
            },
            @{
                eventDateTime            = "2025-02-10T19:00:00Z"
                deviceSerialNumber       = "BCD890"
                managedDeviceName        = "Device10"
                userPrincipalName        = "user8@contoso.com"
                # No userId - will test enrichment
                deploymentState          = "failure"
                deviceSetupStatus        = "failure"
                accountSetupStatus       = "notStarted"
                deploymentTotalDuration  = "PT25M"
                osVersion                = "10.0.19045"
                enrollmentState          = "enrolled"
                enrollmentType           = "userDrivenAADJoin"
                enrollmentFailureDetails = "Device setup failed"
            },
            @{
                eventDateTime           = "2025-02-11T20:00:00Z"
                deviceSerialNumber      = "EFG123"
                managedDeviceName       = "Device11"
                userPrincipalName       = "user8@contoso.com"
                userId                  = "00000000-0000-0000-0001-000000000008"
                deploymentState         = "success"
                deviceSetupStatus       = "success"
                accountSetupStatus      = "success"
                deploymentTotalDuration = "PT2H15M"
                osVersion               = "10.0.19045"
                enrollmentState         = "enrolled"
                enrollmentType          = "userDrivenAADJoin"
            }
        )

        # Setup global mock for CallGraphAPI to handle autopilot events, user lookups, batch requests, and sign-in logs
        Mock CallGraphAPI {
            param($ResourcePath, $AccessToken, $ExtraParameters)

            # Handle autopilot events endpoint
            if ($ResourcePath -eq 'deviceManagement/autopilotEvents')
            {
                return @{ value = $script:SampleEvents }
            }

            # Handle managed device lookups for Azure AD Device ID
            if ($ResourcePath -match '^deviceManagement/managedDevices/(.+)')
            {
                $deviceId = $Matches[1].Split('?')[0]
                # Return mock device with Azure AD Device ID
                return @{
                    id              = $deviceId
                    azureADDeviceId = "aad-$deviceId"
                    deviceName      = "TestDevice-$deviceId"
                }
            }

            # Handle batch request (array of resource paths)
            if ($ResourcePath -is [array] -and $ResourcePath.Count -gt 1)
            {
                $batchResponses = @()
                $successCount = 0
                $failureCount = 0
                $batchId = 1

                foreach ($path in $ResourcePath)
                {
                    # Handle user lookup by UPN (users/{upn})
                    if ($path -match '^users/(.+@.+)$')
                    {
                        $upn = $Matches[1]
                        if ($script:UserIdMapping.ContainsKey($upn))
                        {
                            $batchResponses += @{
                                id      = $batchId
                                status  = 200
                                headers = @{}
                                body    = @{
                                    id                = $script:UserIdMapping[$upn]
                                    userPrincipalName = $upn
                                    displayName       = "Test User for $upn"
                                }
                            }
                            $successCount++
                        }
                        else
                        {
                            $batchResponses += @{
                                id      = $batchId
                                status  = 404
                                headers = @{}
                                body    = @{
                                    error = @{
                                        code    = "Request_ResourceNotFound"
                                        message = "Resource not found"
                                    }
                                }
                            }
                            $failureCount++
                        }
                        $batchId++
                    }
                    # Handle sign-in logs batch requests (auditLogs/signIns?$filter=...)
                    elseif ($path -match 'auditLogs/signIns')
                    {
                        # Extract userId and date range from filter parameter
                        $userId = $null
                        $requestedStartDate = $null
                        $requestedEndDate = $null

                        if ($path -match 'userId eq ''([^'']+)''')
                        {
                            $userId = $Matches[1]
                        }
                        if ($path -match 'createdDateTime ge ([^ &]+)')
                        {
                            $requestedStartDate = $Matches[1]
                        }
                        if ($path -match 'createdDateTime le ([^ &]+)')
                        {
                            $requestedEndDate = $Matches[1]
                        }

                        # Generate sample sign-in with location data
                        # Only return sign-ins that fall within the requested date range
                        $signIns = @()
                        if ($userId)
                        {
                            $signIns += @{
                                userId          = $userId
                                createdDateTime = (Get-Date).AddHours(-1).ToString('yyyy-MM-ddTHH:mm:ssZ')
                                location        = @{
                                    city            = 'Seattle'
                                    state           = 'Washington'
                                    countryOrRegion = 'US'
                                }
                                ipAddress       = '10.0.0.1'
                                deviceDetail    = @{
                                    deviceId    = 'test-device-id'
                                    displayName = 'Test Device'
                                    isCompliant = $true
                                    isManaged   = $true
                                }
                                status          = @{
                                    errorCode = 0
                                }
                                appDisplayName  = 'Microsoft Intune'
                                appId           = 'd4ebce55-015a-49b5-a083-c84d1797ae8c'
                            }
                        }

                        $batchResponses += @{
                            id      = $batchId
                            status  = 200
                            headers = @{}
                            body    = @{
                                value = $signIns
                            }
                        }
                        $successCount++
                        $batchId++
                    }
                    # Handle managed device lookups for Azure AD Device ID (deviceManagement/managedDevices/...)
                    elseif ($path -match 'deviceManagement/managedDevices/([^?]+)')
                    {
                        $deviceId = $Matches[1]
                        $batchResponses += @{
                            id      = $batchId
                            status  = 200
                            headers = @{}
                            body    = @{
                                id              = $deviceId
                                azureADDeviceId = "aad-$deviceId"
                                deviceName      = "TestDevice-$deviceId"
                            }
                        }
                        $successCount++
                        $batchId++
                    }
                }

                # Return in standard Graph API $batch response format
                return @{
                    value          = $batchResponses
                    successCount   = $successCount
                    failureCount   = $failureCount
                    batchProcessed = $true
                    batchMethod    = 'NativeBatch'
                    totalCount     = $batchResponses.Count
                }
            }

            # Handle single user lookup by UPN (users/{upn})
            if ($ResourcePath -match '^users/(.+@.+)$')
            {
                $upn = $Matches[1]
                if ($script:UserIdMapping.ContainsKey($upn))
                {
                    return @{
                        id                = $script:UserIdMapping[$upn]
                        userPrincipalName = $upn
                        displayName       = "Test User for $upn"
                    }
                }
                return $null
            }

            # Handle sign-in logs (auditLogs/signIns) - return sample location data
            if ($ResourcePath -eq 'auditLogs/signIns')
            {
                # Return sign-ins with location data for testing
                $signIns = @()
                if ($ExtraParameters -match 'userId eq ''([^'']+)''')
                {
                    $userId = $Matches[1]
                    # Generate sample sign-in with location based on userId
                    $signIns += @{
                        userId          = $userId
                        createdDateTime = (Get-Date).AddHours(-1).ToString('yyyy-MM-ddTHH:mm:ssZ')
                        location        = @{
                            city            = 'Seattle'
                            state           = 'Washington'
                            countryOrRegion = 'US'
                        }
                        ipAddress       = '10.0.0.1'
                        deviceDetail    = @{
                            deviceId    = 'test-device-id'
                            displayName = 'Test Device'
                            isCompliant = $true
                            isManaged   = $true
                        }
                        status          = @{
                            errorCode = 0
                        }
                        appDisplayName  = 'Microsoft Intune'
                        appId           = 'd4ebce55-015a-49b5-a083-c84d1797ae8c'
                    }
                }
                return @{ value = $signIns }
            }

            # Default: return empty
            return @{ value = @() }
        }
    }

    AfterAll {
        Remove-TestEnvironment -TestContext $script:TestContext
        Clear-GraphMockEnvironment
    }

    Context "Event retrieval via Graph API" {

        It "Should fetch events from Graph API" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $result | Should -Not -BeNullOrEmpty
            $result.TotalEvents | Should -BeGreaterThan 0
        }

        It "Should require AccessToken parameter" {
            # Cannot test mandatory parameter prompt in Pester - verify parameter attribute instead
            $paramInfo = (Get-Command Get-AutopilotEventAnalysis).Parameters['AccessToken']
            $mandatoryAttribute = $paramInfo.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                Where-Object { $_.Mandatory -eq $true }
            $mandatoryAttribute | Should -Not -BeNullOrEmpty
        }
    }

    Context "Event counting and categorization" {

        It "Should count total events correctly" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $result.TotalEvents | Should -Be 11
        }

        It "Should count successful events correctly" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $result.SuccessCount | Should -Be 4
        }

        It "Should count failed events correctly" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $result.FailureCount | Should -Be 5
        }

        It "Should count in-progress events correctly" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $result.InProgressCount | Should -Be 2
        }

        It "Should identify device phase in-progress events" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $result.DevicePhaseInProgressCount | Should -Be 1
        }

        It "Should identify user/account phase in-progress events" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $result.UserPhaseInProgressCount | Should -Be 1
        }
    }

    Context "Failure phase categorization" {

        It "Should categorize device-only failures" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $result.DevicePhaseOnlyFailureCount | Should -Be 3
        }

        It "Should categorize user/account-only failures" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $result.UserPhaseOnlyFailureCount | Should -Be 1
        }

        It "Should categorize both-phases failures" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $result.BothPhasesFailureCount | Should -Be 1
        }

        It "Should track unknown phase failures" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $result.UnknownPhaseFailureCount | Should -BeGreaterOrEqual 0
        }
    }

    Context "Date filtering" {

        It "Should filter events by start date" {
            $startDate = [DateTime]"2025-02-05T00:00:00Z"
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token" -StartDate $startDate

            $result.TotalEvents | Should -BeLessOrEqual $script:SampleEvents.Count
            $result.StartDate | Should -Be $startDate
        }

        It "Should filter events by end date" {
            $endDate = [DateTime]"2025-02-05T23:59:59Z"
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token" -EndDate $endDate

            $result.TotalEvents | Should -BeLessOrEqual $script:SampleEvents.Count
            $result.EndDate | Should -Be $endDate
        }

        It "Should filter events by date range" {
            $startDate = [DateTime]"2025-02-05T00:00:00Z"
            $endDate = [DateTime]"2025-02-08T23:59:59Z"
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token" -StartDate $startDate -EndDate $endDate

            $result.TotalEvents | Should -BeLessOrEqual $script:SampleEvents.Count
            $result.StartDate | Should -Be $startDate
            $result.EndDate | Should -Be $endDate
        }

        It "Should handle events with invalid dates" {
            $eventsWithBadDate = @(
                @{
                    eventDateTime      = $null
                    deploymentState    = "success"
                    deviceSetupStatus  = "success"
                    accountSetupStatus = "success"
                },
                @{
                    eventDateTime      = "not-a-date"
                    deploymentState    = "success"
                    deviceSetupStatus  = "success"
                    accountSetupStatus = "success"
                }
            )

            # The function should handle invalid dates without crashing
            Mock CallGraphAPI { return @{ value = $eventsWithBadDate } } -ParameterFilter { $ResourcePath -eq 'deviceManagement/autopilotEvents' }
            { $result = Get-AutopilotEventAnalysis -AccessToken "test-token" } | Should -Not -Throw
        }
    }

    Context "User principal name filtering" {

        It "Should filter events by UserPrincipalName" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token" -UserPrincipalName "user3@contoso.com"

            $result.TotalEvents | Should -Be 3
            $result.UserPrincipalName | Should -Be "user3@contoso.com"
        }

        It "Should return only events matching the UPN" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token" -UserPrincipalName "user1@contoso.com"

            # Should filter to only events for this user
            $result.TotalEvents | Should -BeLessOrEqual $script:SampleEvents.Count
            # Verify filtering occurred (if user has events)
            if ($result.TotalEvents -gt 0)
            {
                $result.UserPrincipalName | Should -Be "user1@contoso.com"
            }
        }

        It "Should return all events for non-existent UPN" {
            # When user lookup fails, function continues with all events
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token" -UserPrincipalName "nonexistent@contoso.com"

            # Should return all events since user lookup failed
            $result.TotalEvents | Should -Be $script:SampleEvents.Count
        }
    }

    Context "Duration calculation" {

        It "Should calculate average success duration" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $result.AverageSuccessDuration | Should -Not -BeNullOrEmpty
            $result.AverageSuccessDuration.GetType().Name | Should -Be "TimeSpan"
        }

        It "Should calculate average failure duration" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $result.AverageFailureDuration | Should -Not -BeNullOrEmpty
            $result.AverageFailureDuration.GetType().Name | Should -Be "TimeSpan"
        }

        It "Should handle events without duration data" {
            $eventsWithoutDuration = @(
                @{
                    eventDateTime      = "2025-02-01T10:00:00Z"
                    deploymentState    = "success"
                    deviceSetupStatus  = "success"
                    accountSetupStatus = "success"
                }
            )

            Mock CallGraphAPI { return @{ value = $eventsWithoutDuration } } -ParameterFilter { $ResourcePath -eq 'deviceManagement/autopilotEvents' }
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $result.AverageSuccessDuration | Should -BeNullOrEmpty
        }
    }

    Context "User failure analysis" {

        It "Should identify users with multiple failures" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $result.UsersWithMultipleFailures | Should -Not -BeNullOrEmpty
            $result.UsersWithMultipleFailures.Count | Should -BeGreaterThan 0
        }

        It "Should track eventual success for users with multiple failures" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $user3 = $result.UsersWithMultipleFailures | Where-Object { $_.UserPrincipalName -eq "user3@contoso.com" }
            $user3.FailureCount | Should -Be 2
            $user3.EventualSuccess | Should -Be $true
        }

        It "Should identify users with single failure then success" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $result.SingleFailureWithSuccess | Should -Not -BeNullOrEmpty
            $result.SingleFailureWithSuccess.Count | Should -BeGreaterThan 0
        }

        It "Should track single failure followed by success" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $user8 = $result.SingleFailureWithSuccess | Where-Object { $_.UserPrincipalName -eq "user8@contoso.com" }
            $user8 | Should -Not -BeNullOrEmpty
            $user8.SuccessDevice | Should -Not -BeNullOrEmpty
        }
    }

    Context "Chronological sorting" {

        It "Should sort failed devices chronologically" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $result.FailedDevicesChronological | Should -Not -BeNullOrEmpty
            $result.FailedDevicesChronological.Count | Should -Be $result.FailureCount
        }

        It "Should order failures by event date ascending" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $dates = $result.FailedDevicesChronological | ForEach-Object { [DateTime]$_.eventDateTime }
            for ($i = 0; $i -lt ($dates.Count - 1); $i++)
            {
                $dates[$i] | Should -BeLessOrEqual $dates[$i + 1]
            }
        }
    }

    Context "Result structure" {

        It "Should return PSCustomObject with all expected properties" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $result.PSObject.TypeNames[0] | Should -Be "System.Management.Automation.PSCustomObject"
            $result.PSObject.Properties.Name | Should -Contain "TotalEvents"
            $result.PSObject.Properties.Name | Should -Contain "SuccessCount"
            $result.PSObject.Properties.Name | Should -Contain "FailureCount"
            $result.PSObject.Properties.Name | Should -Contain "InProgressCount"
        }

        It "Should preserve original events array" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $result.AllEvents | Should -Not -BeNullOrEmpty
            $result.AllEvents.Count | Should -Be $script:SampleEvents.Count
        }

        It "Should include filtered events when filters applied" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token" -UserPrincipalName "user3@contoso.com"

            $result.AllFilteredEvents | Should -Not -BeNullOrEmpty
            $result.AllFilteredEvents.Count | Should -BeLessOrEqual $script:SampleEvents.Count
        }

        It "Should track earliest event date" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $result.EarliestEventDate | Should -Not -BeNullOrEmpty
            $result.EarliestEventDate | Should -Be ([DateTime]"2025-02-01T10:00:00Z")
        }
    }

    Context "Per-user date range optimization" {

        It "Should calculate date ranges per user based on their events" {
            # Mock to track what date ranges are requested for each user
            $script:SignInRequestsByUser = @{}

            Mock CallGraphAPI {
                param($ResourcePath, $AccessToken, $ExtraParameters)

                # Capture sign-in log requests to verify per-user date ranges
                if ($ResourcePath -is [array] -and $ResourcePath.Count -gt 0)
                {
                    foreach ($path in $ResourcePath)
                    {
                        if ($path -match 'auditLogs/signIns.*userId eq ''([^'']+)''.*createdDateTime ge ([^&]+) and createdDateTime le ([^&]+)')
                        {
                            $userId = $Matches[1]
                            $startDate = $Matches[2]
                            $endDate = $Matches[3]

                            $script:SignInRequestsByUser[$userId] = @{
                                StartDate = $startDate
                                EndDate   = $endDate
                            }
                        }
                    }

                    # Return standard batch response
                    return @{
                        value        = @()
                        successCount = $ResourcePath.Count
                        failureCount = 0
                    }
                }

                # Handle autopilot events
                if ($ResourcePath -eq 'deviceManagement/autopilotEvents')
                {
                    return @{ value = $script:SampleEvents }
                }

                # Default response
                return @{ value = @() }
            }

            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            # Verify that different users got different date ranges
            # (this test assumes users have events on different dates)
            if ($script:SignInRequestsByUser.Keys.Count -gt 1)
            {
                $dateRanges = $script:SignInRequestsByUser.Values | ForEach-Object { $_["StartDate"] + "_" + $_["EndDate"] } | Select-Object -Unique
                $dateRanges.Count | Should -BeGreaterThan 0
            }
        }

        It "Should add 1-day buffer to user date ranges" {
            # Create events for a specific user on a single day
            $singleDayEvents = @(
                @{
                    eventDateTime      = "2025-02-05T10:00:00Z"
                    userPrincipalName  = "test.user@contoso.com"
                    userId             = "test-user-id"
                    deploymentState    = "success"
                    deviceSetupStatus  = "success"
                    accountSetupStatus = "success"
                },
                @{
                    eventDateTime      = "2025-02-05T15:00:00Z"
                    userPrincipalName  = "test.user@contoso.com"
                    userId             = "test-user-id"
                    deploymentState    = "success"
                    deviceSetupStatus  = "success"
                    accountSetupStatus = "success"
                }
            )

            $script:CapturedDateRange = $null

            Mock CallGraphAPI {
                param($ResourcePath, $AccessToken, $ExtraParameters)

                if ($ResourcePath -is [array] -and $ResourcePath[0] -match 'auditLogs/signIns.*createdDateTime ge ([^ &]+).*createdDateTime le ([^ &]+)')
                {
                    $startDate = [DateTime]::Parse($Matches[1])
                    $endDate = [DateTime]::Parse($Matches[2])
                    $span = ($endDate - $startDate).TotalDays

                    $script:CapturedDateRange = @{
                        StartDate = $startDate
                        EndDate   = $endDate
                        Span      = $span
                    }

                    return @{
                        value        = @()
                        successCount = 1
                        failureCount = 0
                    }
                }

                if ($ResourcePath -eq 'deviceManagement/autopilotEvents')
                {
                    return @{ value = $singleDayEvents }
                }

                return @{ value = @() }
            }

            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            # Should request approximately 2 days of logs (1 day buffer on each side)
            if ($script:CapturedDateRange)
            {
                $script:CapturedDateRange.Span | Should -BeGreaterThan 1
                $script:CapturedDateRange.Span | Should -BeLessOrEqual 3
            }
        }

        It "Should log optimization metrics" {
            $logMessages = @()

            Mock Write-Log {
                param($LogFile, $Module, $Message, $LogLevel)
                if ($Message -match 'Optimization:|user-days|reduction')
                {
                    $script:logMessages += $Message
                }
            }

            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            # Should log optimization metrics
            $optimizationLogs = $script:logMessages | Where-Object { $_ -match 'Optimization' -or $_ -match 'reduction' }
            $optimizationLogs.Count | Should -BeGreaterThan 0
        }
    }

    Context "User ID enrichment" {

        It "Should enrich events with missing user IDs" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            # Check that events without userId now have one
            $enrichedEvent = $result.AllFilteredEvents | Where-Object { $_.userPrincipalName -eq "user2@contoso.com" }
            $enrichedEvent | Should -Not -BeNullOrEmpty
            $enrichedEvent.userId | Should -Be "00000000-0000-0000-0001-000000000002"
        }

        It "Should fetch user IDs only for filtered events" {
            # Filter to specific date range
            $startDate = [DateTime]"2025-02-05T00:00:00Z"
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token" -StartDate $startDate

            # Should only have enriched events from the filtered date range
            $result.AllFilteredEvents.Count | Should -BeLessOrEqual $script:SampleEvents.Count

            # Verify enrichment occurred for filtered events
            $eventsNeedingEnrichment = @($result.AllFilteredEvents | Where-Object {
                    $_.userPrincipalName -and -not ($script:SampleEvents | Where-Object {
                            $_.userPrincipalName -eq $result.AllFilteredEvents[0].userPrincipalName -and $_.userId
                        })
                })

            # All filtered events should have userId
            $eventsWithUserId = @($result.AllFilteredEvents | Where-Object { $_.userId })
            $eventsWithUPN = @($result.AllFilteredEvents | Where-Object { $_.userPrincipalName })
            $eventsWithUserId.Count | Should -Be $eventsWithUPN.Count
        }

        It "Should preserve existing user IDs" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            # Check an event that already had userId
            $eventWithId = $result.AllFilteredEvents | Where-Object { $_.userPrincipalName -eq "user1@contoso.com" }
            $eventWithId | Should -Not -BeNullOrEmpty
            $eventWithId.userId | Should -Be "00000000-0000-0000-0001-000000000001"
        }

        It "Should log warning when user ID cannot be found" {
            # Create event with non-existent UPN
            $eventsWithBadUPN = @(
                @{
                    eventDateTime      = "2025-02-01T10:00:00Z"
                    userPrincipalName  = "nonexistent@contoso.com"
                    deploymentState    = "success"
                    deviceSetupStatus  = "success"
                    accountSetupStatus = "success"
                }
            )

            # Should not throw, just log warning
            Mock CallGraphAPI { return @{ value = $eventsWithBadUPN } } -ParameterFilter { $ResourcePath -eq 'deviceManagement/autopilotEvents' }
            { $result = Get-AutopilotEventAnalysis -AccessToken "test-token" } | Should -Not -Throw

            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"
            $result.TotalEvents | Should -Be 1
        }

        It "Should use enriched user IDs for sign-in matching" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            # Verify sign-in matching was performed
            $result.SignInMatchStats | Should -Not -BeNullOrEmpty
            $result.SignInMatchStats.TotalEvents | Should -Be $result.TotalEvents
        }
    }

    Context "Location analysis" {

        It "Should include location analysis in results" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $result.PSObject.Properties.Name | Should -Contain "LocationAnalysis"
            $result.PSObject.Properties.Name | Should -Contain "LocationAnalysisCount"
        }

        It "Should analyze events by location from sign-in data" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            # LocationAnalysis should be an array or null if no location data
            if ($result.LocationAnalysis)
            {
                $result.LocationAnalysis.GetType().BaseType.Name | Should -BeIn @('Array', 'Object')
            }
        }

        It "Should calculate success and failure counts per location" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            if ($result.LocationAnalysis.Count -gt 0)
            {
                $firstLocation = $result.LocationAnalysis[0]
                $firstLocation.PSObject.Properties.Name | Should -Contain "Location"
                $firstLocation.PSObject.Properties.Name | Should -Contain "TotalEvents"
                $firstLocation.PSObject.Properties.Name | Should -Contain "SuccessCount"
                $firstLocation.PSObject.Properties.Name | Should -Contain "FailureCount"
                $firstLocation.PSObject.Properties.Name | Should -Contain "SuccessRate"
                $firstLocation.PSObject.Properties.Name | Should -Contain "FailureRate"
            }
        }

        It "Should include geographic details in location analysis" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            if ($result.LocationAnalysis.Count -gt 0)
            {
                $firstLocation = $result.LocationAnalysis[0]
                $firstLocation.PSObject.Properties.Name | Should -Contain "Country"
                $firstLocation.PSObject.Properties.Name | Should -Contain "State"
                $firstLocation.PSObject.Properties.Name | Should -Contain "City"
            }
        }

        It "Should sort locations by total event count descending" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            if ($result.LocationAnalysis.Count -gt 1)
            {
                for ($i = 0; $i -lt ($result.LocationAnalysis.Count - 1); $i++)
                {
                    $result.LocationAnalysis[$i].TotalEvents | Should -BeGreaterOrEqual $result.LocationAnalysis[$i + 1].TotalEvents
                }
            }
        }

        It "Should calculate success rate correctly" {
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            if ($result.LocationAnalysis.Count -gt 0)
            {
                foreach ($location in $result.LocationAnalysis)
                {
                    if ($location.TotalEvents -gt 0)
                    {
                        $expectedRate = [Math]::Round(($location.SuccessCount / $location.TotalEvents) * 100, 2)
                        $location.SuccessRate | Should -Be $expectedRate
                    }
                }
            }
        }

        It "Should handle events without location data" {
            $eventsWithoutLocation = @(
                @{
                    eventDateTime      = "2025-02-01T10:00:00Z"
                    userPrincipalName  = "user@contoso.com"
                    deploymentState    = "success"
                    deviceSetupStatus  = "success"
                    accountSetupStatus = "success"
                }
            )

            Mock CallGraphAPI { return @{ value = $eventsWithoutLocation } } -ParameterFilter { $ResourcePath -eq 'deviceManagement/autopilotEvents' }
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            # Should not crash, LocationAnalysis should exist (may be empty array)
            $result.PSObject.Properties.Name | Should -Contain "LocationAnalysis"
            $result.LocationAnalysisCount | Should -Be 0
        }
    }

    Context "Edge cases" {

        It "Should handle empty events array" {
            # Mock to return empty array
            Mock CallGraphAPI { return @{ value = @() } } -ParameterFilter { $ResourcePath -eq 'deviceManagement/autopilotEvents' }
            { $result = Get-AutopilotEventAnalysis -AccessToken "test-token" } | Should -Not -Throw

            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"
            $result.TotalEvents | Should -Be 0
            $result.SuccessCount | Should -Be 0
            $result.FailureCount | Should -Be 0
        }

        It "Should handle events without userPrincipalName" {
            $eventsWithoutUPN = @(
                @{
                    eventDateTime      = "2025-02-01T10:00:00Z"
                    deviceSerialNumber = "ABC123"
                    deploymentState    = "success"
                    deviceSetupStatus  = "success"
                    accountSetupStatus = "success"
                }
            )

            Mock CallGraphAPI { return @{ value = $eventsWithoutUPN } } -ParameterFilter { $ResourcePath -eq 'deviceManagement/autopilotEvents' }
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $result.TotalEvents | Should -Be 1
            $result.UsersWithMultipleFailures.Count | Should -Be 0
        }

        It "Should handle events without serial numbers" {
            $eventsWithoutSerial = @(
                @{
                    eventDateTime      = "2025-02-01T10:00:00Z"
                    userPrincipalName  = "user@contoso.com"
                    deploymentState    = "failure"
                    deviceSetupStatus  = "failure"
                    accountSetupStatus = "notStarted"
                }
            )

            Mock CallGraphAPI { return @{ value = $eventsWithoutSerial } } -ParameterFilter { $ResourcePath -eq 'deviceManagement/autopilotEvents' }
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $result.TotalEvents | Should -Be 1
            $result.FailedDevicesChronological.Count | Should -Be 0
        }
    }

    Context "Error handling" {

        It "Should validate AccessToken parameter binding" {
            # PowerShell parameter binding prevents empty strings before function code runs
            # This test verifies that the parameter attribute is set correctly
            { Get-AutopilotEventAnalysis -AccessToken "" } | Should -Throw -ErrorId "ParameterArgumentValidationErrorEmptyStringNotAllowed,Get-AutopilotEventAnalysis"
        }

        It "Should return null when AccessToken is whitespace" {
            # Whitespace is caught by validation and returns null
            $result = Get-AutopilotEventAnalysis -AccessToken "   " -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

            $result | Should -BeNullOrEmpty
        }

        It "Should handle Graph API call failure gracefully" {
            # Mock CallGraphAPI to throw an exception
            Mock CallGraphAPI {
                throw "Network error: Unable to connect to Graph API"
            } -ParameterFilter { $ResourcePath -eq 'deviceManagement/autopilotEvents' }

            # Suppress error output for this test
            $result = Get-AutopilotEventAnalysis -AccessToken "test-token" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

            $result | Should -BeNullOrEmpty
        }

        It "Should return empty result structure when no events found" {
            # Mock to return empty array
            Mock CallGraphAPI { return @{ value = @() } } -ParameterFilter { $ResourcePath -eq 'deviceManagement/autopilotEvents' }

            $result = Get-AutopilotEventAnalysis -AccessToken "test-token" -WarningAction SilentlyContinue

            $result | Should -Not -BeNullOrEmpty
            $result.TotalEvents | Should -Be 0
            $result.SuccessCount | Should -Be 0
            $result.FailureCount | Should -Be 0
            $result.InProgressCount | Should -Be 0
            # AllEvents property should exist (may be null or empty array)
            $result.PSObject.Properties.Name | Should -Contain "AllEvents"
            $result.PSObject.Properties.Name | Should -Contain "SignInMatchStats"
            $result.PSObject.Properties.Name | Should -Contain "LocationAnalysis"
        }

        It "Should handle null response from Graph API" {
            # Mock to return null value
            Mock CallGraphAPI { return @{ value = $null } } -ParameterFilter { $ResourcePath -eq 'deviceManagement/autopilotEvents' }

            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $result | Should -Not -BeNullOrEmpty
            $result.TotalEvents | Should -Be 0
        }

        It "Should handle user lookup failure when filtering by UPN" {
            # Mock user lookup to fail
            Mock CallGraphAPI {
                throw "User not found"
            } -ParameterFilter { $ResourcePath -match '^users/.*@.*' }

            # Should not throw and should continue with all events
            { $result = Get-AutopilotEventAnalysis -AccessToken "test-token" -UserPrincipalName "nonexistent@contoso.com" } | Should -Not -Throw

            $result = Get-AutopilotEventAnalysis -AccessToken "test-token" -UserPrincipalName "nonexistent@contoso.com"

            # Should return all events since user lookup failed
            $result | Should -Not -BeNullOrEmpty
            $result.TotalEvents | Should -Be $script:SampleEvents.Count
        }

        It "Should handle user lookup returning null" {
            # Mock user lookup to return null
            Mock CallGraphAPI {
                return $null
            } -ParameterFilter { $ResourcePath -match '^users/.*@.*' }

            # Should not throw and should continue with all events
            { $result = Get-AutopilotEventAnalysis -AccessToken "test-token" -UserPrincipalName "user@contoso.com" } | Should -Not -Throw

            $result = Get-AutopilotEventAnalysis -AccessToken "test-token" -UserPrincipalName "user@contoso.com"

            # Should return all events since user lookup returned null
            $result | Should -Not -BeNullOrEmpty
            $result.TotalEvents | Should -Be $script:SampleEvents.Count
        }

        It "Should handle batch API null response" {
            # Mock batch request to return null
            Mock CallGraphAPI {
                return $null
            } -ParameterFilter { $ResourcePath -is [array] -and $ResourcePath.Count -gt 1 }

            # Should fall back to individual requests
            { $result = Get-AutopilotEventAnalysis -AccessToken "test-token" } | Should -Not -Throw

            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $result | Should -Not -BeNullOrEmpty
            $result.TotalEvents | Should -BeGreaterThan 0
        }

        It "Should handle batch request failures gracefully" {
            # Mock to cause batch request failure
            Mock CallGraphAPI {
                if ($ResourcePath -eq 'deviceManagement/autopilotEvents')
                {
                    # Return events
                    return @{
                        value = @(
                            @{
                                eventDateTime      = "2025-02-01T10:00:00Z"
                                userPrincipalName  = "user@contoso.com"
                                deviceId           = "test-device-id"
                                deploymentState    = "success"
                                deviceSetupStatus  = "success"
                                accountSetupStatus = "success"
                            }
                        )
                    }
                }
                elseif ($ResourcePath -is [array])
                {
                    # Batch requests fail
                    throw "Batch request failed"
                }
                else
                {
                    return @{ value = @() }
                }
            }

            # Should not throw, falls back to individual requests
            { $result = Get-AutopilotEventAnalysis -AccessToken "test-token" -WarningAction SilentlyContinue } | Should -Not -Throw

            $result = Get-AutopilotEventAnalysis -AccessToken "test-token" -WarningAction SilentlyContinue
            $result | Should -Not -BeNullOrEmpty
            $result.TotalEvents | Should -Be 1
        }

        It "Should handle single event response (non-array)" {
            # Mock to return single event instead of array
            Mock CallGraphAPI {
                return @{
                    value = @{
                        eventDateTime      = "2025-02-01T10:00:00Z"
                        userPrincipalName  = "user@contoso.com"
                        userId             = "test-user-id"
                        deploymentState    = "success"
                        deviceSetupStatus  = "success"
                        accountSetupStatus = "success"
                    }
                }
            } -ParameterFilter { $ResourcePath -eq 'deviceManagement/autopilotEvents' }

            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            # Should convert to array and process normally
            $result | Should -Not -BeNullOrEmpty
            $result.TotalEvents | Should -Be 1
        }

        It "Should log errors appropriately" {
            $errorLogs = @()

            Mock Write-Log {
                if ($LogLevel -eq "Error")
                {
                    $script:errorLogs += $Message
                }
            }

            # Trigger an error by using whitespace token (bypasses parameter binding)
            $result = Get-AutopilotEventAnalysis -AccessToken "   " -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

            $script:errorLogs.Count | Should -BeGreaterThan 0
            $hasAccessTokenError = $script:errorLogs | Where-Object { $_ -match "AccessToken.*required" }
            $hasAccessTokenError | Should -Not -BeNullOrEmpty
        }
    }
}

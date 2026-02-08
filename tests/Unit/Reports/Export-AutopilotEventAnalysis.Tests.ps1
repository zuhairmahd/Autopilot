<#
.SYNOPSIS
    Tests for Export-AutopilotEventAnalysis

.DESCRIPTION
    Unit tests for autopilot event analysis export function

.NOTES
    Test Category: Unit
    Template Compliance: Full
    Uses: AutopilotTestHelpers
#>

Import-Module "$PSScriptRoot\..\..\Helpers\AutopilotTestHelpers.psm1" -Force

Describe "Export-AutopilotEventAnalysis" -Tags 'Unit', 'Reports' {

    BeforeAll {
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

        # Dot-source functions directly (PS 5.1 compatible)
        $functionsPath = Join-Path $script:RepoRoot "functions"
        Get-ChildItem -Path $functionsPath -Recurse -Filter *.ps1 | ForEach-Object {
            . $_.FullName
        }

        # Initialize test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment

        # Mock Write-Log if not already available
        if (-not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
            function global:Write-Log { param($LogFile, $Module, $Message, $LogLevel) }
        }

        # Set global variables
        $global:LogFile = $script:TestContext.LogFile

        # Create mock analysis data
        $script:MockAnalysisData = [PSCustomObject]@{
            TotalEvents                 = 10
            TotalEventsBeforeFilter     = 15
            StartDate                   = [DateTime]"2025-02-01T00:00:00Z"
            EndDate                     = [DateTime]"2025-02-10T23:59:59Z"
            UserPrincipalName           = $null
            EarliestEventDate           = [DateTime]"2025-02-01T10:00:00Z"
            SuccessCount                = 5
            InProgressCount             = 2
            DevicePhaseInProgressCount  = 1
            UserPhaseInProgressCount    = 1
            FailureCount                = 3
            AverageSuccessDuration      = New-TimeSpan -Hours 2 -Minutes 30
            AverageFailureDuration      = New-TimeSpan -Hours 1 -Minutes 15
            DevicePhaseOnlyFailureCount = 1
            UserPhaseOnlyFailureCount   = 1
            BothPhasesFailureCount      = 1
            UnknownPhaseFailureCount    = 0
            SignInMatchStats            = @{
                TotalEvents      = 10
                MatchedEvents    = 8
                HighConfidence   = 5
                MediumConfidence = 2
                LowConfidence    = 1
            }
            SuccessfulEvents            = @(
                @{
                    eventDateTime = "2025-02-01T10:00:00Z"
                    deviceSerialNumber = "ABC123"
                    managedDeviceName = "Device1"
                    userPrincipalName = "user1@contoso.com"
                    deploymentState = "success"
                    deviceSetupStatus = "success"
                    accountSetupStatus = "success"
                    osVersion = "10.0.19045"
                    enrollmentState = "enrolled"
                    enrollmentType = "userDrivenAADJoin"
                    windowsAutopilotDeploymentProfileDisplayName = "Profile1"
                    deploymentDuration = "PT2H"
                    deploymentTotalDuration = "PT2H30M"
                    SignIn_MatchFound = $true
                    SignIn_ConfidenceScore = 90
                    SignIn_MatchedOn = "UserId, DeviceId, Time_Within1Hour"
                    SignIn_Location_City = "Seattle"
                    SignIn_Location_State = "Washington"
                    SignIn_Location_Country = "US"
                    SignIn_IPAddress = "192.168.1.1"
                    SignIn_Status = "Success"
                }
            )
            InProgressEvents            = @(
                @{
                    eventDateTime = "2025-02-08T17:00:00Z"
                    deviceSerialNumber = "PQR678"
                    managedDeviceName = "Device6"
                    userPrincipalName = "user4@contoso.com"
                    deploymentState = "inProgress"
                    deviceSetupStatus = "inProgress"
                    accountSetupStatus = "notStarted"
                    osVersion = "10.0.19045"
                    enrollmentState = "enrolling"
                    enrollmentType = "userDrivenAADJoin"
                    windowsAutopilotDeploymentProfileDisplayName = "Profile1"
                    deploymentDuration = "PT1H"
                    deploymentTotalDuration = "PT1H"
                    SignIn_MatchFound = $true
                    SignIn_ConfidenceScore = 85
                    SignIn_MatchedOn = "UserId, DeviceId, Time_Within1Hour"
                    SignIn_Location_City = "Portland"
                    SignIn_Location_State = "Oregon"
                    SignIn_Location_Country = "US"
                    SignIn_IPAddress = "10.0.1.1"
                    SignIn_Status = "Success"
                }
            )
            FailedEvents                = @(
                @{
                    eventDateTime = "2025-02-03T12:00:00Z"
                    deviceSerialNumber = "GHI789"
                    managedDeviceName = "Device3"
                    userPrincipalName = "user3@contoso.com"
                    deploymentState = "failure"
                    deviceSetupStatus = "failure"
                    accountSetupStatus = "notStarted"
                    osVersion = "10.0.19045"
                    enrollmentState = "enrolled"
                    enrollmentType = "userDrivenAADJoin"
                    windowsAutopilotDeploymentProfileDisplayName = "Profile1"
                    deploymentDuration = "PT30M"
                    deploymentTotalDuration = "PT45M"
                    enrollmentFailureDetails = "Device setup failed"
                    SignIn_MatchFound = $true
                    SignIn_ConfidenceScore = 70
                    SignIn_MatchedOn = "UserId, Time_Within2Hours"
                    SignIn_Location_City = "San Francisco"
                    SignIn_Location_State = "California"
                    SignIn_Location_Country = "US"
                    SignIn_IPAddress = "172.16.0.1"
                    SignIn_Status = "Failure"
                    SignIn_FailureReason = "Device registration failed"
                    SignIn_ErrorCode = 50034
                }
            )
            UsersWithMultipleFailures   = @(
                [PSCustomObject]@{
                    UserPrincipalName = "user3@contoso.com"
                    FailureCount      = 2
                    EventualSuccess   = $true
                    SuccessDevice     = @{ deviceSerialNumber = "MNO345"; eventDateTime = "2025-02-05T14:00:00Z" }
                    FailedDevices     = @(
                        @{ deviceSerialNumber = "DEF456"; eventDateTime = "2025-02-03T12:00:00Z" },
                        @{ deviceSerialNumber = "GHI789"; eventDateTime = "2025-02-04T13:00:00Z" }
                    )
                    LastFailureDate   = "2025-02-04T13:00:00Z"
                }
            )
            SingleFailureWithSuccess    = @(
                [PSCustomObject]@{
                    UserPrincipalName = "user8@contoso.com"
                    FailureDate       = "2025-02-10T19:00:00Z"
                    FailureDevice     = @{ deviceSerialNumber = "BCD890" }
                    SuccessDate       = "2025-02-11T20:00:00Z"
                    SuccessDevice     = @{ deviceSerialNumber = "EFG123" }
                }
            )
            AllFilteredEvents           = @(
                @{
                    eventDateTime = "2025-02-01T10:00:00Z"
                    deviceId = "device-001"
                    userId = "user-001"
                    deviceSerialNumber = "ABC123"
                    managedDeviceName = "Device1"
                    userPrincipalName = "user1@contoso.com"
                    deploymentState = "success"
                    deviceSetupStatus = "success"
                    accountSetupStatus = "success"
                    osVersion = "10.0.19045"
                    enrollmentState = "enrolled"
                    enrollmentType = "userDrivenAADJoin"
                    windowsAutopilotDeploymentProfileDisplayName = "Profile1"
                    deploymentDuration = "PT2H"
                    deploymentTotalDuration = "PT2H30M"
                    deviceRegisteredDateTime = "2025-02-01T08:00:00Z"
                    enrollmentStartDateTime = "2025-02-01T09:00:00Z"
                    deploymentStartDateTime = "2025-02-01T09:30:00Z"
                    deploymentEndDateTime = "2025-02-01T12:00:00Z"
                    deviceSetupDuration = "PT1H30M"
                    accountSetupDuration = "PT30M"
                    SignIn_MatchFound = $true
                    SignIn_ConfidenceScore = 95
                    SignIn_MatchedOn = "UserId, DeviceId, Time_Within1Hour, IntuneApp"
                    SignIn_Location_City = "Seattle"
                    SignIn_Location_State = "Washington"
                    SignIn_Location_Country = "US"
                    SignIn_IPAddress = "192.168.1.1"
                    SignIn_Status = "Success"
                    SignIn_FailureReason = $null
                    SignIn_ErrorCode = $null
                    SignIn_AppDisplayName = "Microsoft Intune Enrollment"
                    SignIn_DeviceDisplayName = "Device1"
                    SignIn_IsCompliant = $true
                    SignIn_IsManaged = $true
                }
            )
        }

        # Create test output directory
        $script:TestOutputPath = Join-Path $script:TestContext.TestFolder "ExportTests"
        if (-not (Test-Path $script:TestOutputPath)) {
            New-Item -Path $script:TestOutputPath -ItemType Directory -Force | Out-Null
        }
    }

    AfterAll {
        Remove-TestEnvironment -TestContext $script:TestContext
    }

    Context "Interactive export option 1 (default)" {

        It "Should export summary, failures, and user analysis by default" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "1" }
                if ($Prompt -like "*output path*") { return $script:TestOutputPath }
                return ""
            }
            Mock Write-Host { }

            $result = Export-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData

            $result.Success | Should -Be $true
            $result.ExportedFiles.Count | Should -BeGreaterThan 0
        }

        It "Should create summary CSV file" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "1" }
                if ($Prompt -like "*output path*") { return $script:TestOutputPath }
                return ""
            }
            Mock Write-Host { }

            $result = Export-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData

            $summaryFile = $result.ExportedFiles | Where-Object { $_ -like "*Summary*" }
            $summaryFile | Should -Not -BeNullOrEmpty
            Test-Path $summaryFile | Should -Be $true
        }

        It "Should create failures CSV file when failures exist" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "1" }
                if ($Prompt -like "*output path*") { return $script:TestOutputPath }
                return ""
            }
            Mock Write-Host { }

            $result = Export-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData

            $failuresFile = $result.ExportedFiles | Where-Object { $_ -like "*Failures*" }
            $failuresFile | Should -Not -BeNullOrEmpty
        }

        It "Should create user analysis CSV files" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "1" }
                if ($Prompt -like "*output path*") { return $script:TestOutputPath }
                return ""
            }
            Mock Write-Host { }

            $result = Export-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData

            $userFiles = $result.ExportedFiles | Where-Object { $_ -like "*Users*" }
            $userFiles | Should -Not -BeNullOrEmpty
        }
    }

    Context "Interactive export option 2 (everything)" {

        It "Should export all data when option 2 selected" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "2" }
                if ($Prompt -like "*output path*") { return $script:TestOutputPath }
                return ""
            }
            Mock Write-Host { }

            $result = Export-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData

            $result.Success | Should -Be $true
            $result.FileCount | Should -BeGreaterThan 3
        }

        It "Should include all events CSV" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "2" }
                if ($Prompt -like "*output path*") { return $script:TestOutputPath }
                return ""
            }
            Mock Write-Host { }

            $result = Export-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData

            $allEventsFile = $result.ExportedFiles | Where-Object { $_ -like "*AllEvents*" }
            $allEventsFile | Should -Not -BeNullOrEmpty
        }

        It "Should include successes CSV" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "2" }
                if ($Prompt -like "*output path*") { return $script:TestOutputPath }
                return ""
            }
            Mock Write-Host { }

            $result = Export-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData

            $successesFile = $result.ExportedFiles | Where-Object { $_ -like "*Successes*" }
            $successesFile | Should -Not -BeNullOrEmpty
        }

        It "Should include in-progress CSV when in-progress events exist" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "2" }
                if ($Prompt -like "*output path*") { return $script:TestOutputPath }
                return ""
            }
            Mock Write-Host { }

            $result = Export-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData

            $inProgressFile = $result.ExportedFiles | Where-Object { $_ -like "*InProgress*" }
            $inProgressFile | Should -Not -BeNullOrEmpty
        }
    }

    Context "Interactive export option 3 (custom)" {

        It "Should export only selected data types" {
            $script:CallCount = 0
            Mock Read-Host {
                param($Prompt)
                $script:CallCount++
                # Sequence: option, path, summary, failures, successes, inProgress, allEvents, userAnalysis
                switch ($script:CallCount) {
                    1 { return "3" }       # export option
                    2 { return $script:TestOutputPath }  # output path
                    3 { return "Y" }       # Summary
                    4 { return "N" }       # Failures
                    5 { return "N" }       # Successes
                    6 { return "N" }       # In-Progress
                    7 { return "N" }       # All Events
                    8 { return "N" }       # User Analysis
                    default { return "" }
                }
            }
            Mock Write-Host { }

            $result = Export-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData

            $result.Success | Should -Be $true
            $result.FileCount | Should -Be 1
            $result.ExportedFiles[0] | Should -BeLike "*Summary*"
        }

        It "Should respect case-insensitive Y/N input" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "3" }
                if ($Prompt -like "*output path*") { return $script:TestOutputPath }
                if ($Prompt -like "*Summary*") { return "y" }
                if ($Prompt -like "*Failures*") { return "n" }
                if ($Prompt -like "*Successes*") { return "n" }
                if ($Prompt -like "*In-Progress*") { return "n" }
                if ($Prompt -like "*All Events*") { return "n" }
                if ($Prompt -like "*User Analysis*") { return "n" }
                return ""
            }
            Mock Write-Host { }

            $result = Export-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData

            $result.Success | Should -Be $true
        }

        It "Should export multiple custom selections" {
            $script:CallCount = 0
            Mock Read-Host {
                param($Prompt)
                $script:CallCount++
                # Sequence: option, path, summary, failures, successes, inProgress, allEvents, userAnalysis
                switch ($script:CallCount) {
                    1 { return "3" }       # export option
                    2 { return $script:TestOutputPath }  # output path
                    3 { return "Y" }       # Summary
                    4 { return "Y" }       # Failures
                    5 { return "N" }       # Successes
                    6 { return "N" }       # In-Progress
                    7 { return "N" }       # All Events
                    8 { return "N" }       # User Analysis
                    default { return "" }
                }
            }
            Mock Write-Host { }

            $result = Export-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData

            $result.Success | Should -Be $true
            $result.FileCount | Should -BeGreaterOrEqual 2
        }
    }

    Context "Output path handling" {

        It "Should use current directory when path is blank" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "1" }
                if ($Prompt -like "*output path*") { return "" }
                return ""
            }
            Mock Write-Host { }

            $result = Export-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData

            $result.OutputPath | Should -Not -BeNullOrEmpty
        }

        It "Should use specified output path" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "1" }
                if ($Prompt -like "*output path*") { return $script:TestOutputPath }
                return ""
            }
            Mock Write-Host { }

            $result = Export-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData

            $result.OutputPath | Should -BeLike "*$($script:TestOutputPath)*"
        }

        It "Should resolve relative paths" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "1" }
                if ($Prompt -like "*output path*") { return "." }
                return ""
            }
            Mock Write-Host { }

            $result = Export-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData

            $result.OutputPath | Should -Not -Be "."
        }
    }

    Context "Result object structure" {

        It "Should return structured result object" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "1" }
                if ($Prompt -like "*output path*") { return $script:TestOutputPath }
                return ""
            }
            Mock Write-Host { }

            $result = Export-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData

            $result.PSObject.Properties.Name | Should -Contain "Success"
            $result.PSObject.Properties.Name | Should -Contain "ExportedFiles"
            $result.PSObject.Properties.Name | Should -Contain "OutputPath"
            $result.PSObject.Properties.Name | Should -Contain "FileCount"
            $result.PSObject.Properties.Name | Should -Contain "Error"
        }

        It "Should set Success to true on successful export" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "1" }
                if ($Prompt -like "*output path*") { return $script:TestOutputPath }
                return ""
            }
            Mock Write-Host { }

            $result = Export-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData

            $result.Success | Should -Be $true
        }

        It "Should populate ExportedFiles array" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "1" }
                if ($Prompt -like "*output path*") { return $script:TestOutputPath }
                return ""
            }
            Mock Write-Host { }

            $result = Export-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData

            $result.ExportedFiles | Should -Not -BeNullOrEmpty
            $result.ExportedFiles.Count | Should -BeGreaterThan 0
        }

        It "Should set FileCount correctly" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "1" }
                if ($Prompt -like "*output path*") { return $script:TestOutputPath }
                return ""
            }
            Mock Write-Host { }

            $result = Export-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData

            $result.FileCount | Should -Be $result.ExportedFiles.Count
        }
    }

    Context "CSV file content validation" {

        It "Should create valid CSV files" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "1" }
                if ($Prompt -like "*output path*") { return $script:TestOutputPath }
                return ""
            }
            Mock Write-Host { }

            $result = Export-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData

            foreach ($file in $result.ExportedFiles) {
                Test-Path $file | Should -Be $true
                $content = Get-Content $file -First 1
                $content | Should -Not -BeNullOrEmpty
            }
        }

        It "Should include headers in CSV files" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "2" }
                if ($Prompt -like "*output path*") { return $script:TestOutputPath }
                return ""
            }
            Mock Write-Host { }

            $result = Export-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData
            $summaryFile = $result.ExportedFiles | Where-Object { $_ -like "*Summary*" }

            if ($summaryFile) {
                $content = Import-Csv $summaryFile
                $content[0].PSObject.Properties.Name | Should -Contain "Metric"
                $content[0].PSObject.Properties.Name | Should -Contain "Value"
            }
        }

        It "Should format dates consistently in exports" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "2" }
                if ($Prompt -like "*output path*") { return $script:TestOutputPath }
                return ""
            }
            Mock Write-Host { }

            $result = Export-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData
            $failuresFile = $result.ExportedFiles | Where-Object { $_ -like "*Failures*" }

            if ($failuresFile) {
                $content = Import-Csv $failuresFile
                if ($content.Count -gt 0) {
                    $content[0].EventDate | Should -Match '\d{4}-\d{2}-\d{2}'
                }
            }
        }
    }

    Context "Pipeline input" {

        It "Should accept AnalysisData from pipeline" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "1" }
                if ($Prompt -like "*output path*") { return $script:TestOutputPath }
                return ""
            }
            Mock Write-Host { }

            { $script:MockAnalysisData | Export-AutopilotEventAnalysis } | Should -Not -Throw
        }

        It "Should process piped data correctly" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "1" }
                if ($Prompt -like "*output path*") { return $script:TestOutputPath }
                return ""
            }
            Mock Write-Host { }

            $result = $script:MockAnalysisData | Export-AutopilotEventAnalysis

            $result.Success | Should -Be $true
        }
    }

    Context "Edge cases" {

        It "Should handle empty events gracefully" {
            $emptyAnalysisData = [PSCustomObject]@{
                TotalEvents = 0
                SuccessCount = 0
                FailureCount = 0
                InProgressCount = 0
                SuccessfulEvents = @()
                FailedEvents = @()
                InProgressEvents = @()
                UsersWithMultipleFailures = @()
                SingleFailureWithSuccess = @()
                AllFilteredEvents = @()
            }

            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "1" }
                if ($Prompt -like "*output path*") { return $script:TestOutputPath }
                return ""
            }
            Mock Write-Host { }

            $result = Export-AutopilotEventAnalysis -AnalysisData $emptyAnalysisData

            $result.Success | Should -Be $true
        }

        It "Should handle invalid export option gracefully" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "99" }
                if ($Prompt -like "*output path*") { return $script:TestOutputPath }
                return ""
            }
            Mock Write-Host { }

            # Invalid option should default to option 1
            $result = Export-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData

            $result.Success | Should -Be $true
        }

        It "Should handle null/missing durations" {
            $dataWithoutDurations = $script:MockAnalysisData.PSObject.Copy()
            $dataWithoutDurations.AverageSuccessDuration = $null
            $dataWithoutDurations.AverageFailureDuration = $null

            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "1" }
                if ($Prompt -like "*output path*") { return $script:TestOutputPath }
                return ""
            }
            Mock Write-Host { }

            { Export-AutopilotEventAnalysis -AnalysisData $dataWithoutDurations } | Should -Not -Throw
        }
    }

    Context "Timestamp uniqueness" {

        It "Should create files with unique timestamps" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "1" }
                if ($Prompt -like "*output path*") { return $script:TestOutputPath }
                return ""
            }
            Mock Write-Host { }

            $result1 = Export-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData
            Start-Sleep -Seconds 2
            $result2 = Export-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData

            $result1.ExportedFiles[0] | Should -Not -Be $result2.ExportedFiles[0]
        }
    }

    Context "Sign-in enrichment data" {

        It "Should include sign-in enrichment columns when exporting all events" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "2" }
                if ($Prompt -like "*output path*") { return $script:TestOutputPath }
                return ""
            }
            Mock Write-Host { }

            $result = Export-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData
            $allEventsFile = $result.ExportedFiles | Where-Object { $_ -like "*AllEvents*" }

            if ($allEventsFile) {
                $csvData = Import-Csv $allEventsFile
                $headers = $csvData[0].PSObject.Properties.Name
                $headers | Should -Contain "SignIn_MatchFound"
                $headers | Should -Contain "SignIn_ConfidenceScore"
                $headers | Should -Contain "SignIn_Location_City"
                $headers | Should -Contain "SignIn_Location_State"
                $headers | Should -Contain "SignIn_Location_Country"
                $headers | Should -Contain "SignIn_IPAddress"
                $headers | Should -Contain "SignIn_Status"
            }
        }

        It "Should export sign-in match confidence scores" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "2" }
                if ($Prompt -like "*output path*") { return $script:TestOutputPath }
                return ""
            }
            Mock Write-Host { }

            $result = Export-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData
            $allEventsFile = $result.ExportedFiles | Where-Object { $_ -like "*AllEvents*" }

            if ($allEventsFile) {
                $csvData = Import-Csv $allEventsFile
                $csvData[0].SignIn_ConfidenceScore | Should -Not -BeNullOrEmpty
            }
        }

        It "Should export sign-in location data" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "2" }
                if ($Prompt -like "*output path*") { return $script:TestOutputPath }
                return ""
            }
            Mock Write-Host { }

            $result = Export-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData
            $allEventsFile = $result.ExportedFiles | Where-Object { $_ -like "*AllEvents*" }

            if ($allEventsFile) {
                $csvData = Import-Csv $allEventsFile
                $csvData[0].SignIn_Location_City | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "Smart data-aware export" {

        BeforeEach {
            # Ensure test output directory exists and is clean for each test
            if (Test-Path $script:TestOutputPath) {
                Remove-Item -Path "$script:TestOutputPath\*" -Force -ErrorAction SilentlyContinue
            }
            else {
                New-Item -Path $script:TestOutputPath -ItemType Directory -Force | Out-Null
            }
        }

        It "Should analyze available data and display summary" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "1" }
                if ($Prompt -like "*output path*") { return $script:TestOutputPath }
                return ""
            }
            
            $capturedOutput = @()
            Mock Write-Host {
                param($Object)
                $script:capturedOutput += $Object
            }

            $result = Export-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData

            # Should display available data summary
            $availableDataOutput = $script:capturedOutput -join ' '
            $availableDataOutput | Should -Match "Available Data"
            $result.Success | Should -Be $true
        }

        It "Should skip location export when LocationAnalysisCount is 0" {
            # Create analysis data without location analysis
            $analysisWithoutLocation = [PSCustomObject]@{
                TotalEvents              = 5
                SuccessCount             = 3
                FailureCount             = 2
                InProgressCount          = 0
                LocationAnalysisCount    = 0
                LocationAnalysis         = @()
                UsersWithMultipleFailures = @(
                    [PSCustomObject]@{
                        UserPrincipalName = "user1@contoso.com"
                        FailureCount      = 1
                        EventualSuccess   = $true
                    }
                )
                SingleFailureWithSuccess = @()
                AllFilteredEvents        = @(
                    @{ eventDateTime = "2025-02-01T10:00:00Z"; deploymentState = "success" }
                )
                SuccessfulEvents         = @(@{ eventDateTime = "2025-02-01T10:00:00Z" })
                FailedEvents             = @(@{ eventDateTime = "2025-02-02T10:00:00Z" })
                InProgressEvents         = @()
                AllEvents                = @()
                AverageSuccessDuration   = New-TimeSpan -Hours 2
                AverageFailureDuration   = New-TimeSpan -Hours 1
                DevicePhaseOnlyFailureCount = 1
                UserPhaseOnlyFailureCount = 1
                BothPhasesFailureCount    = 0
                UnknownPhaseFailureCount  = 0
                DevicePhaseInProgressCount = 0
                UserPhaseInProgressCount  = 0
            }

            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "2" }
                if ($Prompt -like "*output path*") { return $script:TestOutputPath }
                return ""
            }
            Mock Write-Host { }

            $result = Export-AutopilotEventAnalysis -AnalysisData $analysisWithoutLocation

            # Should not have location analysis file
            $locationFile = $result.ExportedFiles | Where-Object { $_ -like "*LocationAnalysis*" }
            $locationFile | Should -BeNullOrEmpty
            $result.Success | Should -Be $true
        }

        It "Should handle analysis with no failures gracefully" {
            $analysisNoFailures = [PSCustomObject]@{
                TotalEvents              = 10
                SuccessCount             = 10
                FailureCount             = 0
                InProgressCount          = 0
                LocationAnalysisCount    = 0
                LocationAnalysis         = @()
                UsersWithMultipleFailures = @()
                SingleFailureWithSuccess = @()
                AllFilteredEvents        = @()
                SuccessfulEvents         = @()
                FailedEvents             = @()
                InProgressEvents         = @()
                AllEvents                = @()
                AverageSuccessDuration   = New-TimeSpan -Hours 2
                DevicePhaseOnlyFailureCount = 0
                UserPhaseOnlyFailureCount = 0
                BothPhasesFailureCount    = 0
                UnknownPhaseFailureCount  = 0
                DevicePhaseInProgressCount = 0
                UserPhaseInProgressCount  = 0
            }

            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "1" }
                if ($Prompt -like "*output path*") { return $script:TestOutputPath }
                return ""
            }
            Mock Write-Host { }

            { Export-AutopilotEventAnalysis -AnalysisData $analysisNoFailures } | Should -Not -Throw
            
            $result = Export-AutopilotEventAnalysis -AnalysisData $analysisNoFailures
            $result.Success | Should -Be $true
            
            # Should not have failures file since no failures
            $failuresFile = $result.ExportedFiles | Where-Object { $_ -like "*Failures*" }
            $failuresFile | Should -BeNullOrEmpty
        }
    }
}

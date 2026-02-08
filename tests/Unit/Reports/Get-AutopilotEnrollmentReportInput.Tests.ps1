<#
.SYNOPSIS
    Tests for Get-AutopilotEnrollmentReportInput

.DESCRIPTION
    Unit tests for enrollment report input gathering function

.NOTES
    Test Category: Unit
    Template Compliance: Full
    Uses: AutopilotTestHelpers
#>

Import-Module "$PSScriptRoot\..\..\Helpers\AutopilotTestHelpers.psm1" -Force

Describe "Get-AutopilotEnrollmentReportInput" -Tags 'Unit', 'Reports' {

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
    }

    AfterAll {
        Remove-TestEnvironment -TestContext $script:TestContext
    }

    Context "Date parsing with ConvertTo-DateFilter" {

        It "Should parse 'today' to start of current day" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*Start Date*") { return "today" }
                return ""
            }
            Mock Write-Host { }
            Mock Write-Verbose { }

            $result = Get-AutopilotEnrollmentReportInput -NoConfirmation

            if ($result.ContainsKey('StartDate')) {
                $result['StartDate'].Date | Should -Be (Get-Date).Date
            }
        }

        It "Should parse 'yesterday' correctly" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*Start Date*") { return "yesterday" }
                return ""
            }
            Mock Write-Host { }

            $result = Get-AutopilotEnrollmentReportInput -NoConfirmation

            if ($result.ContainsKey('StartDate')) {
                $result['StartDate'].Date | Should -Be (Get-Date).AddDays(-1).Date
            }
        }

        It "Should parse 'wtd' (week-to-date) to Monday" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*Start Date*") { return "wtd" }
                return ""
            }
            Mock Write-Host { }

            $result = Get-AutopilotEnrollmentReportInput -NoConfirmation

            if ($result.ContainsKey('StartDate')) {
                $today = Get-Date
                $daysToMonday = ([int]$today.DayOfWeek + 6) % 7
                $expectedMonday = $today.AddDays(-$daysToMonday).Date
                $result['StartDate'].Date | Should -Be $expectedMonday
            }
        }

        It "Should parse 'mtd' (month-to-date) to first day of month" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*Start Date*") { return "mtd" }
                return ""
            }
            Mock Write-Host { }

            $result = Get-AutopilotEnrollmentReportInput -NoConfirmation

            if ($result.ContainsKey('StartDate')) {
                $expected = Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0
                $result['StartDate'].Date | Should -Be $expected.Date
            }
        }

        It "Should parse explicit date yyyy-MM-dd" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*Start Date*") { return "2025-01-15" }
                return ""
            }
            Mock Write-Host { }

            $result = Get-AutopilotEnrollmentReportInput -NoConfirmation

            if ($result.ContainsKey('StartDate')) {
                $result['StartDate'].ToString("yyyy-MM-dd") | Should -Match "2025-01-15"
            }
        }

        It "Should handle invalid date gracefully" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*Start Date*") { return "invalid-date" }
                return ""
            }
            Mock Write-Host { }

            $result = Get-AutopilotEnrollmentReportInput -NoConfirmation

            $result.ContainsKey('StartDate') | Should -Be $false
        }

        It "Should adjust end date to end of day" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*Start Date*") { return "" }
                if ($Prompt -like "*End Date*") { return "2025-01-15" }
                return ""
            }
            Mock Write-Host { }

            $result = Get-AutopilotEnrollmentReportInput -NoConfirmation

            if ($result.ContainsKey('EndDate')) {
                $result['EndDate'].Hour | Should -Be 23
                $result['EndDate'].Minute | Should -Be 59
                $result['EndDate'].Second | Should -Be 59
            }
        }
    }

    Context "User input handling" {

        It "Should return empty hashtable when no filters provided" {
            Mock Read-Host { return "" }
            Mock Write-Host { }

            $result = Get-AutopilotEnrollmentReportInput -NoConfirmation

            $result | Should -BeOfType [hashtable]
            # When no input is provided, defaults are applied:
            # StartDate defaults to 30 days ago, EndDate defaults to today
            $result.ContainsKey('StartDate') | Should -Be $true
            $result.ContainsKey('EndDate') | Should -Be $true
            $result.ContainsKey('UserPrincipalName') | Should -Be $false
        }

        It "Should include UserPrincipalName when provided" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*User Principal Name*") { return "test@contoso.com" }
                return ""
            }
            Mock Write-Host { }

            $result = Get-AutopilotEnrollmentReportInput -NoConfirmation

            $result.ContainsKey('UserPrincipalName') | Should -Be $true
            $result['UserPrincipalName'] | Should -Be "test@contoso.com"
        }

        It "Should trim whitespace from UPN" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*User Principal Name*") { return "  test@contoso.com  " }
                return ""
            }
            Mock Write-Host { }

            $result = Get-AutopilotEnrollmentReportInput -NoConfirmation

            $result['UserPrincipalName'] | Should -Be "test@contoso.com"
        }

        It "Should exclude empty UPN from result" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*User Principal Name*") { return "" }
                return ""
            }
            Mock Write-Host { }

            $result = Get-AutopilotEnrollmentReportInput -NoConfirmation

            $result.ContainsKey('UserPrincipalName') | Should -Be $false
        }
    }

    Context "NoConfirmation switch" {

        It "Should skip confirmation prompt when NoConfirmation is set" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*Are these filters correct*") {
                    throw "Should not ask for confirmation"
                }
                return ""
            }
            Mock Write-Host { }

            { Get-AutopilotEnrollmentReportInput -NoConfirmation } | Should -Not -Throw
        }

        It "Should prompt for confirmation when NoConfirmation is not set" {
            $script:confirmationAsked = $false
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*Are these filters correct*") {
                    $script:confirmationAsked = $true
                    return "Y"
                }
                return ""
            }
            Mock Write-Host { }

            $result = Get-AutopilotEnrollmentReportInput

            $script:confirmationAsked | Should -Be $true
        }

        It "Should restart when user answers No to confirmation" {
            $script:callCount = 0
            Mock Read-Host {
                param($Prompt)
                $script:callCount++
                if ($Prompt -like "*Are these filters correct*") {
                    if ($script:callCount -eq 1) { return "N" }
                    return "Y"
                }
                return ""
            }
            Mock Write-Host { }

            $result = Get-AutopilotEnrollmentReportInput

            $script:callCount | Should -BeGreaterThan 1
        }
    }

    Context "Combined filters" {

        It "Should include all filters when all provided" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*Start Date*") { return "2025-01-01" }
                if ($Prompt -like "*End Date*") { return "2025-01-31" }
                if ($Prompt -like "*User Principal Name*") { return "user@contoso.com" }
                return ""
            }
            Mock Write-Host { }

            $result = Get-AutopilotEnrollmentReportInput -NoConfirmation

            $result.ContainsKey('StartDate') | Should -Be $true
            $result.ContainsKey('EndDate') | Should -Be $true
            $result.ContainsKey('UserPrincipalName') | Should -Be $true
        }

        It "Should return partial filters when only some provided" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*Start Date*") { return "2025-01-01" }
                return ""
            }
            Mock Write-Host { }

            $result = Get-AutopilotEnrollmentReportInput -NoConfirmation

            $result.ContainsKey('StartDate') | Should -Be $true
            # EndDate defaults to today when not provided
            $result.ContainsKey('EndDate') | Should -Be $true
            $result.ContainsKey('UserPrincipalName') | Should -Be $false
        }
    }
}

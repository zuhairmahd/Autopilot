<#
.SYNOPSIS
    Integration tests for report generation and export.

.DESCRIPTION
    Tests the application's ability to export a report to a CSV file.
    This test focuses on the ExportDeviceReport function.
    Addresses Phase 3 of the Pester Migration Plan.

.NOTES
    Test Category: Integration
    Template Compliance: Full
    Uses: AutopilotTestHelpers
#>

Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Report Generation Integration" -Tags 'Integration', 'Reporting' {

    BeforeAll {
        $script:TestContext = Initialize-AutopilotTestEnvironment
        $script:RepoRoot = $TestContext.RootPath

        # Load the function to be tested
        . (Join-Path $script:RepoRoot "functions/reportingFunctions/ExportDeviceReport.ps1")
        
        # Mock Write-Log as it is called by the function
        function global:Write-Log { param($LogFile, $Module, $Message, $LogLevel) }
    }

    AfterAll {
        Remove-TestEnvironment -TestContext $script:TestContext
    }

    Context "CSV Export" {
        It "Should export a report to a CSV file in the specified path" {
            # Arrange
            $reportData = [ordered]@{
                "Device Name" = "TEST-DEVICE"
                "Serial Number" = "TEST-SERIAL"
                "Status" = "Ready"
            }
            $outputPath = Join-Path $script:TestContext.TempPath "test-report.csv"

            # Act
            $result = ExportDeviceReport -formattedOutput $reportData -ExportFormat "CSV" -outputFile $outputPath

            # Assert
            $result | Should -Be $true
            (Test-Path $outputPath) | Should -Be $true

            $csvContent = Import-Csv -Path $outputPath
            $csvContent.Count | Should -Be 3
            $csvContent[0].Property | Should -Be "Device Name"
            $csvContent[0].Value | Should -Be "TEST-DEVICE"
            $csvContent[2].Property | Should -Be "Status"
            $csvContent[2].Value | Should -Be "Ready"
        }
    }
}

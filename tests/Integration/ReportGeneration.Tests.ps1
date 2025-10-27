<#
.SYNOPSIS
    Integration tests for report generation and export.

.DESCRIPTION
    Tests the application's ability to export a report to a CSV file.
    This test focuses on the Export-DeviceReport function.
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
        . (Join-Path $script:RepoRoot "functions/reportingFunctions/Export-DeviceReport.ps1")
        
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
                "Device Name"   = "TEST-DEVICE"
                "Serial Number" = "TEST-SERIAL"
                "Status"        = "Ready"
            }
            $outputPath = Join-Path $script:TestContext.TestFolder "test-report.csv"

            # Act
            $result = Export-DeviceReport -formattedOutput $reportData -ExportFormat "CSV" -outputFile $outputPath

            # Assert
            $result | Should -Be $true
            (Test-Path $outputPath) | Should -Be $true

            $csvContent = Import-Csv -Path $outputPath
            $csvContent.Count | Should -Be 3 -Because "should have 3 rows (one per property)"
            
            # Check that all expected properties are present (order may vary)
            $properties = $csvContent.Property
            $properties | Should -Contain "Device Name"
            $properties | Should -Contain "Serial Number"
            $properties | Should -Contain "Status"
            
            # Verify values match properties
            $deviceNameRow = $csvContent | Where-Object { $_.Property -eq "Device Name" }
            $deviceNameRow.Value | Should -Be "TEST-DEVICE"
            
            $serialNumberRow = $csvContent | Where-Object { $_.Property -eq "Serial Number" }
            $serialNumberRow.Value | Should -Be "TEST-SERIAL"
            
            $statusRow = $csvContent | Where-Object { $_.Property -eq "Status" }
            $statusRow.Value | Should -Be "Ready"
        }
    }
}

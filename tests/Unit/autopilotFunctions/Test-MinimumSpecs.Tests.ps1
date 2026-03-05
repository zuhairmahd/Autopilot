<#
.SYNOPSIS
    Unit tests for Test-MinimumSpecs function
.DESCRIPTION
    Validates success and failure paths, strict mode behavior, and console output formatting
#>

Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: Test-MinimumSpecs" -Tags 'Unit', 'AutopilotFunctions' {
    BeforeAll {
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName

        # Load dependencies
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        . "$script:RepoRoot/functions/autopilotFunctions/Test-MinimumSpecs.ps1"

        Mock Write-Log {}
        Mock Read-Host {}

        function Get-SystemInformation
        {
        }
        function Test-PIVReader
        {
        }

        $script:logFile = "TestDrive:\autopilot.log"
    }

    Context "When requirements are satisfied" {
        BeforeEach {
            $script:settings = @{
                minimumDevicePhysicalMemoryInGB = 8
                operatingSystem                 = "Windows 10"
                operatingSystemVersion          = 10
                minimumOSServiceRelease         = "22h2"
                runPIVTest                      = $false
            }

            Mock Get-SystemInformation { return [PSCustomObject]@{ TotalMemoryGB = 16; OSName = "Windows 10 Enterprise"; OSVersion = "10.0.19045.1234"; OSMajorVersion = 10; OSServiceRelease = "22h2"; OSBuild = 19045 } }
            Mock Test-PIVReader { return @{ Success = $true } }
        }

        It "returns a success result when device meets minimum specs" {
            $result = Test-MinimumSpecs -settings $script:settings

            $result.Success | Should -Be $true
            ($result.Checks | Where-Object { $_.Passed -ne $true }) | Should -BeNullOrEmpty
            $result.Message | Should -Match "meets minimum specifications"
        }
    }

    Context "When requirements are not met" {
        BeforeEach {
            $script:settings = @{
                minimumDevicePhysicalMemoryInGB = 16
                operatingSystem                 = "Windows 11"
                operatingSystemVersion          = 11
                minimumOSServiceRelease         = "23h2"
                runPIVTest                      = $true
            }

            Mock Get-SystemInformation { return [PSCustomObject]@{ TotalMemoryGB = 8; OSName = "Windows 10 Enterprise"; OSVersion = "10.0.19044.1234"; OSMajorVersion = 10; OSServiceRelease = "22h2"; OSBuild = 19044 } }
            Mock Test-PIVReader { return @{ Success = $false } }
        }

        It "returns failure object with expected and actual values" {
            $result = Test-MinimumSpecs -settings $script:settings

            $result.Success | Should -Be $false
            $result.Message | Should -Match "Expected memory >= 16"
            $result.Message | Should -Match "Expected operating system containing 'Windows 11'"
            $result.Message | Should -Match "Expected Windows 11 or higher"
            $result.Message | Should -Match "Expected service release 23h2 or higher"
            $result.Message | Should -Match "Expected PIV reader"
        }

        It "throws when strict mode is enabled" {
            { Test-MinimumSpecs -settings $script:settings -strictMode } | Should -Throw "*Expected memory >= 16*"
        }
    }

    Context "When writing console output" {
        BeforeEach {
            $script:settings = @{
                minimumDevicePhysicalMemoryInGB = 8
                operatingSystem                 = "Windows 10"
                operatingSystemVersion          = 10
                minimumOSServiceRelease         = "22h2"
                runPIVTest                      = $true
            }

            Mock Test-PIVReader { return @{ Success = $true } }
            Mock Write-Host {}
        }

        It "uses green for passing checks and red for failing ones" {
            Mock Get-SystemInformation { return [PSCustomObject]@{ TotalMemoryGB = 4; OSName = "Windows 10 Pro"; OSVersion = "10.0.19045.1234"; OSMajorVersion = 10; OSServiceRelease = "22h2"; OSBuild = 19045 } }

            Test-MinimumSpecs -settings $script:settings -writeToConsole

            Should -Invoke Write-Host -ParameterFilter { $Object -like "Has correct OS:*" -and $ForegroundColor -eq "Green" } -Times 1 -Scope It
            Should -Invoke Write-Host -ParameterFilter { $Object -like "Has minimum OS version:*" -and $ForegroundColor -eq "Green" } -Times 1 -Scope It
            Should -Invoke Write-Host -ParameterFilter { $Object -like "Has minimum OS service release:*" -and $ForegroundColor -eq "Green" } -Times 1 -Scope It
            Should -Invoke Write-Host -ParameterFilter { $Object -like "Has correct memory:*" -and $ForegroundColor -eq "Red" } -Times 1 -Scope It
            Should -Invoke Write-Host -ParameterFilter { $Object -like "PIV reader status OK:*" -and $ForegroundColor -eq "Green" } -Times 1 -Scope It
        }

        It "uses yellow when a value is unknown" {
            Mock Get-SystemInformation { return [PSCustomObject]@{ TotalMemoryGB = $null; OSName = $null; OSVersion = $null; OSMajorVersion = $null; OSServiceRelease = $null; OSBuild = $null } }

            Test-MinimumSpecs -settings $script:settings -writeToConsole

            Should -Invoke Write-Host -ParameterFilter { $Object -like "Has correct OS:*Unknown" -and $ForegroundColor -eq "Yellow" } -Times 1 -Scope It
            Should -Invoke Write-Host -ParameterFilter { $Object -like "Has minimum OS version:*Unknown" -and $ForegroundColor -eq "Yellow" } -Times 1 -Scope It
            Should -Invoke Write-Host -ParameterFilter { $Object -like "Has minimum OS service release:*Unknown" -and $ForegroundColor -eq "Yellow" } -Times 1 -Scope It
            Should -Invoke Write-Host -ParameterFilter { $Object -like "Has correct memory:*Unknown" -and $ForegroundColor -eq "Yellow" } -Times 1 -Scope It
        }

        It "prompts the user when running the PIV test" {
            Mock Get-SystemInformation { return [PSCustomObject]@{ TotalMemoryGB = 8; OSName = "Windows 10 Enterprise"; OSVersion = "10.0.19045.1234"; OSMajorVersion = 10; OSServiceRelease = "22h2"; OSBuild = 19045 } }
            Mock Read-Host {}

            Test-MinimumSpecs -settings $script:settings -writeToConsole

            Should -Invoke Write-Host -ParameterFilter { $Object -like "Please insert your PIV card*" } -Times 1 -Scope It
            Should -Invoke Read-Host -Times 1 -Scope It
            Should -Invoke Test-PIVReader -Times 1 -Scope It
        }
    }
}

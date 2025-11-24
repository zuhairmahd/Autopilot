# Test-ResourcePlatformMatch.Tests.ps1
# Unit tests for Test-ResourcePlatformMatch helper

#Requires -Version 5.1

BeforeAll {
    $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
    Import-Module "$script:RepoRoot/tests/Helpers/AutopilotTestHelpers.psm1" -Force

    $script:TestEnv = Initialize-AutopilotTestEnvironment

    . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
    . "$script:RepoRoot/functions/UserAndGroupFunctions/Get-GroupAssignments-Common.ps1"

    $global:logFile = Join-Path $script:TestEnv.TestFolder "TestResourcePlatformMatch.log"
}

Describe "Function: Test-ResourcePlatformMatch" -Tags 'Unit', 'PlatformFiltering' {

    BeforeEach {
        Mock Write-Log { }
    }

    It "Includes Windows resources when OData type contains Windows hints" {
        $resource = [PSCustomObject]@{
            displayName  = "Win32 App"
            '@odata.type' = "#microsoft.graph.win32LobApp"
        }

        Test-ResourcePlatformMatch -Resource $resource -TargetOS "Windows" | Should -BeTrue
    }

    It "Infers Windows platform from metadata even when OData type is neutral" {
        $resource = [PSCustomObject]@{
            displayName   = "Settings Catalog Policy"
            '@odata.type' = "#microsoft.graph.deviceManagementConfigurationPolicy"
            platforms     = "windows10"
        }

        Test-ResourcePlatformMatch -Resource $resource -TargetOS "Windows" | Should -BeTrue
    }

    It "Defaults to include neutral resources for Windows targets" {
        $resource = [PSCustomObject]@{
            displayName   = "Device Management Script"
            '@odata.type' = "#microsoft.graph.deviceManagementScript"
        }

        Test-ResourcePlatformMatch -Resource $resource -TargetOS "Windows" | Should -BeTrue
    }

    It "Excludes iOS-only resources when filtering for Windows" {
        $resource = [PSCustomObject]@{
            displayName   = "iOS App"
            '@odata.type' = "#microsoft.graph.iosLobApp"
        }

        Test-ResourcePlatformMatch -Resource $resource -TargetOS "Windows" | Should -BeFalse
    }

    It "Requires explicit hints for non-Windows targets" {
        $resource = [PSCustomObject]@{
            displayName   = "Neutral Policy"
            '@odata.type' = "#microsoft.graph.deviceManagementConfigurationPolicy"
        }

        Test-ResourcePlatformMatch -Resource $resource -TargetOS "iOS" | Should -BeFalse
    }

    It "Matches iOS when hints are present" {
        $resource = [PSCustomObject]@{
            displayName   = "iOS Catalog Policy"
            '@odata.type' = "#microsoft.graph.deviceManagementConfigurationPolicy"
            platforms     = @("ios")
        }

        Test-ResourcePlatformMatch -Resource $resource -TargetOS "iOS" | Should -BeTrue
    }
}

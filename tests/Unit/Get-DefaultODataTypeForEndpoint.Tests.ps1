# Get-DefaultODataTypeForEndpoint.Tests.ps1
# Unit tests for Get-DefaultODataTypeForEndpoint helper

#Requires -Version 5.1

BeforeAll {
    $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
    Import-Module "$script:RepoRoot/tests/Helpers/AutopilotTestHelpers.psm1" -Force

    $script:TestEnv = Initialize-AutopilotTestEnvironment

    . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
    . "$script:RepoRoot/functions/UserAndGroupFunctions/Get-GroupAssignments-Common.ps1"

    $global:logFile = Join-Path $script:TestEnv.TestFolder "GetDefaultODataTypeForEndpoint.log"
}

Describe "Function: Get-DefaultODataTypeForEndpoint" -Tags 'Unit', 'Assignments' {

    BeforeEach {
        Mock Write-Log { }
    }

    It "Returns Windows feature update profile type even when endpoint casing differs" {
        $result = Get-DefaultODataTypeForEndpoint -EndpointId "WindowsFeatureUpdates"
        $result | Should -Be "#microsoft.graph.windowsFeatureUpdateProfile"
    }

    It "Provides autopilot deployment profile type for beta endpoints" {
        $result = Get-DefaultODataTypeForEndpoint -EndpointId "autopilotProfiles"
        $result | Should -Be "#microsoft.graph.windowsAutopilotDeploymentProfile"
    }

    It "Returns null when endpoint is unknown" {
        $result = Get-DefaultODataTypeForEndpoint -EndpointId "customEndpoint"
        $result | Should -Be $null
    }
}

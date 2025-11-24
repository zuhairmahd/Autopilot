# Test-ResourceSupportsAssignments.Tests.ps1
# Validates metadata bypass logic for Windows Update profile types

#Requires -Version 5.1

BeforeAll {
    $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
    Import-Module "$script:RepoRoot/tests/Helpers/AutopilotTestHelpers.psm1" -Force
    $script:TestEnv = Initialize-AutopilotTestEnvironment

    . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
    . "$script:RepoRoot/functions/UserAndGroupFunctions/Get-GroupAssignments-Common.ps1"

    $global:logFile = Join-Path $script:TestEnv.TestFolder "TestResourceSupportsAssignments.log"
}

Describe "Function: Test-ResourceSupportsAssignments" -Tags 'Unit', 'Assignments' {
    BeforeEach {
        Mock Write-Log { }
        Set-Variable -Scope Script -Name MetadataCache -Value @{} -Force
    }

    Context "Windows Update profile types" {
        It "Treats windowsFeatureUpdateProfile as assignment-capable" {
            $resource = [pscustomobject]@{
                '@odata.type' = '#microsoft.graph.windowsFeatureUpdateProfile'
                ResourceType  = 'deviceConfigs'
            }

            Test-ResourceSupportsAssignments -Resource $resource -AccessToken 'token' | Should -BeTrue
            $script:MetadataCache.ContainsKey('#microsoft.graph.windowsfeatureupdateprofile') | Should -BeTrue
        }

        It "Treats windowsQualityUpdateProfile as assignment-capable" {
            $resource = [pscustomobject]@{
                '@odata.type' = '#microsoft.graph.windowsQualityUpdateProfile'
                ResourceType  = 'deviceConfigs'
            }

            Test-ResourceSupportsAssignments -Resource $resource -AccessToken 'token' | Should -BeTrue
        }

        It "Treats windowsDriverUpdateProfile as assignment-capable" {
            $resource = [pscustomobject]@{
                '@odata.type' = '#microsoft.graph.windowsDriverUpdateProfile'
                ResourceType  = 'deviceConfigs'
            }

            Test-ResourceSupportsAssignments -Resource $resource -AccessToken 'token' | Should -BeTrue
        }
    }
}

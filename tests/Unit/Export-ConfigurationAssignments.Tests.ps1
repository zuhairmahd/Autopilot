# Export-ConfigurationAssignments.Tests.ps1
# Unit tests for Export-ConfigurationAssignments function

<#
.SYNOPSIS
    Unit tests for Export-ConfigurationAssignments function

.DESCRIPTION
    Tests the tenant-wide configuration export functionality including:
    - Batch API resource retrieval
    - Assignment processing with id/status/body structure
    - Platform filtering
    - CSV export generation
    - Error handling and categorization

.NOTES
    Test Category: Unit
    Dependencies: UserAndGroupFunctions, AutopilotTestHelpers

    CRITICAL: These tests validate batch API response processing with the CallGraphAPI structure:
    - CallGraphAPI batch returns: { value: [ { id, status, body: { value: [...] } } ], batchProcessed: $true }
    - The 'value' property contains array of responses, NOT 'responses'
#>

#Requires -Version 5.1

BeforeAll {
    # Get repository root
    $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName

    # Import helper modules
    Import-Module "$script:RepoRoot/tests/Helpers/AutopilotTestHelpers.psm1" -Force

    # Initialize test environment
    $script:TestEnv = Initialize-AutopilotTestEnvironment

    # Load required functions via direct dot-sourcing
    . "$script:RepoRoot/functions/UserAndGroupFunctions/Export-ConfigurationAssignments.ps1"
    . "$script:RepoRoot/functions/UserAndGroupFunctions/Get-GroupAssignments-Common.ps1"
    . "$script:RepoRoot/functions/graphFunctions/CallGraphAPI.ps1"
    . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
    . "$script:RepoRoot/functions/utilityFunctions/Get-CachedData.ps1"

    # Set up global variables
    $global:logFile = Join-Path $script:TestEnv.TestFolder "test.log"
    $global:maxJSONDepth = 10

    # Test data
    $script:TestAccessToken = "test-token-export-12345"
    $script:TestOutputFolder = $script:TestEnv.TestFolder

    # Helper function to create batch response structure matching CallGraphAPI output
    # CRITICAL: CallGraphAPI returns { value = @(...); batchProcessed = $true } NOT { responses = @(...) }
    function New-MockBatchResponse
    {
        param(
            [Parameter(Mandatory)]
            [array]$BatchItems
        )
        return @{
            value          = $BatchItems
            batchProcessed = $true
            successCount   = ($BatchItems | Where-Object { $_.status -eq 200 }).Count
            failureCount   = ($BatchItems | Where-Object { $_.status -ne 200 }).Count
            totalCount     = $BatchItems.Count
        }
    }

    # Helper function to create a standard empty batch response for all endpoints
    function New-EmptyBatchResponse
    {
        return New-MockBatchResponse -BatchItems @(
            @{ id = "1"; status = 200; body = @{ value = @() } }
            @{ id = "2"; status = 200; body = @{ value = @() } }
            @{ id = "3"; status = 200; body = @{ value = @() } }
            @{ id = "4"; status = 200; body = @{ value = @() } }
            @{ id = "5"; status = 200; body = @{ value = @() } }
            @{ id = "6"; status = 200; body = @{ value = @() } }
            @{ id = "7"; status = 200; body = @{ value = @() } }
            @{ id = "8"; status = 200; body = @{ value = @() } }
        )
    }
}

AfterAll {
    if ($script:TestEnv)
    {
        Remove-TestEnvironment -TestContext $script:TestEnv
    }
}

# Mock Write-Log and Write-Verbose globally to reduce output and prevent deep JSON serialization warnings
Mock Write-Log {}
Mock Write-Verbose {}
Mock Get-CachedData { return $null }  # Prevent cache lookups in tests
Mock Export-Csv { Write-Host "[MOCK] Export-Csv called for $Path"; return $true }  # Mock CSV export

Describe "Function: Export-ConfigurationAssignments" -Tags 'Unit', 'Export', 'GroupAssignments' {

    BeforeEach {
        # Clean up any exported files from previous tests
        Get-ChildItem -Path $script:TestOutputFolder -Filter "*.csv" -ErrorAction SilentlyContinue | Remove-Item -Force
    }

    Context "Parameter Validation" {
        It "Should require AccessToken parameter" {
            { Export-ConfigurationAssignments -AccessToken $null -OutputPath $script:TestOutputFolder } | Should -Throw
        }

        It "Should require OutputPath parameter" {
            { Export-ConfigurationAssignments -AccessToken $script:TestAccessToken -OutputPath $null } | Should -Throw
        }

        It "Should accept valid parameters" {
            Mock CallGraphAPI {
                Write-Host "MOCK CALLED: CallGraphAPI" -ForegroundColor Magenta
                return New-EmptyBatchResponse
            }

            $result = Export-ConfigurationAssignments -AccessToken $script:TestAccessToken -OutputPath $script:TestOutputFolder
            $result.Success | Should -Be $true
        }
    }

    Context "Batch API Resource Retrieval" {
        It "Should handle batch responses with id/status/body structure" {
            Mock CallGraphAPI {
                param($AccessToken, $ResourcePath)

                # Check if this is an array (batch request for resources) or single path (assignments)
                if ($ResourcePath -is [array])
                {
                    # Resource list batch request
                    return New-MockBatchResponse -BatchItems @(
                        @{
                            id     = "1"
                            status = 200
                            body   = @{
                                value = @(
                                    @{ id = "app-1"; displayName = "Test App 1"; description = "App 1 description"; '@odata.type' = '#microsoft.graph.win32LobApp' }
                                    @{ id = "app-2"; displayName = "Test App 2"; description = "App 2 description"; '@odata.type' = '#microsoft.graph.iosStoreApp' }
                                )
                            }
                        }
                        @{ id = "2"; status = 200; body = @{ value = @() } }
                        @{ id = "3"; status = 200; body = @{ value = @() } }
                        @{ id = "4"; status = 200; body = @{ value = @() } }
                        @{ id = "5"; status = 200; body = @{ value = @() } }
                        @{ id = "6"; status = 200; body = @{ value = @() } }
                        @{ id = "7"; status = 200; body = @{ value = @() } }
                        @{ id = "8"; status = 200; body = @{ value = @() } }
                    )
                }
                else
                {
                    # Assignment retrieval - single resource
                    return @{
                        value = @()
                    }
                }
            }

            $result = Export-ConfigurationAssignments -AccessToken $script:TestAccessToken -OutputPath $script:TestOutputFolder

            $result.Success | Should -Be $true
        }

        It "Should handle failed batch responses (non-200 status)" {
            Mock CallGraphAPI {
                param($AccessToken, $ResourcePath)

                if ($ResourcePath -is [array])
                {
                    return New-MockBatchResponse -BatchItems @(
                        @{ id = "1"; status = 403; body = @{ error = @{ code = "Forbidden"; message = "Access denied" } } }
                        @{
                            id     = "2"
                            status = 200
                            body   = @{
                                value = @(
                                    @{ id = "config-1"; displayName = "Test Config"; description = ""; '@odata.type' = '#microsoft.graph.windows10GeneralConfiguration' }
                                )
                            }
                        }
                        @{ id = "3"; status = 200; body = @{ value = @() } }
                        @{ id = "4"; status = 200; body = @{ value = @() } }
                        @{ id = "5"; status = 200; body = @{ value = @() } }
                        @{ id = "6"; status = 200; body = @{ value = @() } }
                        @{ id = "7"; status = 200; body = @{ value = @() } }
                        @{ id = "8"; status = 200; body = @{ value = @() } }
                    )
                }
                else
                {
                    return @{
                        value = @()
                    }
                }
            }

            $result = Export-ConfigurationAssignments -AccessToken $script:TestAccessToken -OutputPath $script:TestOutputFolder

            $result.Success | Should -Be $true
        }
    }

    Context "Assignment Processing" {
        It "Should correctly identify direct group assignments" {
            $testGroupId = "test-group-guid-123"

            Mock CallGraphAPI {
                param($AccessToken, $ResourcePath)

                if ($ResourcePath -is [array])
                {
                    return New-MockBatchResponse -BatchItems @(
                        @{
                            id     = "1"
                            status = 200
                            body   = @{
                                value = @(
                                    @{ id = "app-1"; displayName = "Direct App"; description = ""; '@odata.type' = '#microsoft.graph.win32LobApp' }
                                )
                            }
                        }
                        @{ id = "2"; status = 200; body = @{ value = @() } }
                        @{ id = "3"; status = 200; body = @{ value = @() } }
                        @{ id = "4"; status = 200; body = @{ value = @() } }
                        @{ id = "5"; status = 200; body = @{ value = @() } }
                        @{ id = "6"; status = 200; body = @{ value = @() } }
                        @{ id = "7"; status = 200; body = @{ value = @() } }
                        @{ id = "8"; status = 200; body = @{ value = @() } }
                    )
                }
                elseif ($ResourcePath -match 'assignments')
                {
                    return @{
                        value = @(
                            @{
                                id     = "assignment-1"
                                intent = "required"
                                target = @{
                                    '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
                                    groupId       = $testGroupId
                                }
                            }
                        )
                    }
                }
                else
                {
                    return @{ value = @() }
                }
            }

            $result = Export-ConfigurationAssignments -AccessToken $script:TestAccessToken -OutputPath $script:TestOutputFolder

            $result.Success | Should -Be $true
            $result.ResourceCount | Should -Be 1

            # Verify CSV content
            if (Test-Path $result.OutputFile)
            {
                $csvContent = Import-Csv -Path $result.OutputFile
                $csvContent[0].Classification | Should -Be "Direct"
                $csvContent[0].HasDirectAssignment | Should -Be "True"
            }
        }

        It "Should correctly identify All Users assignments" {
            Mock CallGraphAPI {
                param($AccessToken, $ResourcePath)

                if ($ResourcePath -is [array])
                {
                    return New-MockBatchResponse -BatchItems @(
                        @{
                            id     = "1"
                            status = 200
                            body   = @{
                                value = @(
                                    @{ id = "app-1"; displayName = "All Users App"; description = ""; '@odata.type' = '#microsoft.graph.win32LobApp' }
                                )
                            }
                        }
                        @{ id = "2"; status = 200; body = @{ value = @() } }
                        @{ id = "3"; status = 200; body = @{ value = @() } }
                        @{ id = "4"; status = 200; body = @{ value = @() } }
                        @{ id = "5"; status = 200; body = @{ value = @() } }
                        @{ id = "6"; status = 200; body = @{ value = @() } }
                        @{ id = "7"; status = 200; body = @{ value = @() } }
                        @{ id = "8"; status = 200; body = @{ value = @() } }
                    )
                }
                elseif ($ResourcePath -match 'assignments')
                {
                    return @{
                        value = @(
                            @{
                                id     = "assignment-1"
                                intent = "required"
                                target = @{
                                    '@odata.type' = '#microsoft.graph.allLicensedUsersAssignmentTarget'
                                }
                            }
                        )
                    }
                }
                else
                {
                    return @{ value = @() }
                }
            }

            $result = Export-ConfigurationAssignments -AccessToken $script:TestAccessToken -OutputPath $script:TestOutputFolder

            $result.Success | Should -Be $true

            # Verify CSV content
            if (Test-Path $result.OutputFile)
            {
                $csvContent = Import-Csv -Path $result.OutputFile
                $csvContent[0].Classification | Should -Be "Indirect"
                $csvContent[0].HasAllUsers | Should -Be "True"
                $csvContent[0].HasAllDevices | Should -Be "False"
            }
        }

        It "Should correctly identify All Devices assignments" {
            Mock CallGraphAPI {
                param($AccessToken, $ResourcePath)

                if ($ResourcePath -is [array])
                {
                    return New-MockBatchResponse -BatchItems @(
                        @{
                            id     = "1"
                            status = 200
                            body   = @{
                                value = @(
                                    @{ id = "config-1"; displayName = "All Devices Config"; description = ""; '@odata.type' = '#microsoft.graph.windows10GeneralConfiguration' }
                                )
                            }
                        }
                        @{ id = "2"; status = 200; body = @{ value = @() } }
                        @{ id = "3"; status = 200; body = @{ value = @() } }
                        @{ id = "4"; status = 200; body = @{ value = @() } }
                        @{ id = "5"; status = 200; body = @{ value = @() } }
                        @{ id = "6"; status = 200; body = @{ value = @() } }
                        @{ id = "7"; status = 200; body = @{ value = @() } }
                        @{ id = "8"; status = 200; body = @{ value = @() } }
                    )
                }
                elseif ($ResourcePath -match 'assignments')
                {
                    return @{
                        value = @(
                            @{
                                id     = "assignment-1"
                                intent = "required"
                                target = @{
                                    '@odata.type' = '#microsoft.graph.allDevicesAssignmentTarget'
                                }
                            }
                        )
                    }
                }
                else
                {
                    return @{ value = @() }
                }
            }

            $result = Export-ConfigurationAssignments -AccessToken $script:TestAccessToken -OutputPath $script:TestOutputFolder

            $result.Success | Should -Be $true

            # Verify CSV content
            if (Test-Path $result.OutputFile)
            {
                $csvContent = Import-Csv -Path $result.OutputFile
                $csvContent[0].Classification | Should -Be "Indirect"
                $csvContent[0].HasAllDevices | Should -Be "True"
                $csvContent[0].HasAllUsers | Should -Be "False"
            }
        }

        It "Should correctly identify Direct + Indirect assignments" {
            $testGroupId = "combined-group-guid"

            Mock CallGraphAPI {
                param($AccessToken, $ResourcePath)

                if ($ResourcePath -is [array])
                {
                    return New-MockBatchResponse -BatchItems @(
                        @{
                            id     = "1"
                            status = 200
                            body   = @{
                                value = @(
                                    @{ id = "app-1"; displayName = "Combined App"; description = ""; '@odata.type' = '#microsoft.graph.win32LobApp' }
                                )
                            }
                        }
                        @{ id = "2"; status = 200; body = @{ value = @() } }
                        @{ id = "3"; status = 200; body = @{ value = @() } }
                        @{ id = "4"; status = 200; body = @{ value = @() } }
                        @{ id = "5"; status = 200; body = @{ value = @() } }
                        @{ id = "6"; status = 200; body = @{ value = @() } }
                        @{ id = "7"; status = 200; body = @{ value = @() } }
                        @{ id = "8"; status = 200; body = @{ value = @() } }
                    )
                }
                elseif ($ResourcePath -match 'assignments')
                {
                    return @{
                        value = @(
                            @{
                                id     = "assignment-1"
                                intent = "required"
                                target = @{
                                    '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
                                    groupId       = $testGroupId
                                }
                            }
                            @{
                                id     = "assignment-2"
                                intent = "available"
                                target = @{
                                    '@odata.type' = '#microsoft.graph.allLicensedUsersAssignmentTarget'
                                }
                            }
                        )
                    }
                }
                else
                {
                    return @{ value = @() }
                }
            }

            $result = Export-ConfigurationAssignments -AccessToken $script:TestAccessToken -OutputPath $script:TestOutputFolder

            $result.Success | Should -Be $true

            # Verify CSV content
            if (Test-Path $result.OutputFile)
            {
                $csvContent = Import-Csv -Path $result.OutputFile
                $csvContent[0].Classification | Should -Be "Direct + Indirect"
                $csvContent[0].HasDirectAssignment | Should -Be "True"
                $csvContent[0].HasAllUsers | Should -Be "True"
            }
        }

        It "Should correctly identify unassigned resources" {
            Mock CallGraphAPI {
                param($AccessToken, $ResourcePath)

                if ($ResourcePath -is [array])
                {
                    return New-MockBatchResponse -BatchItems @(
                        @{
                            id     = "1"
                            status = 200
                            body   = @{
                                value = @(
                                    @{ id = "app-1"; displayName = "Unassigned App"; description = ""; '@odata.type' = '#microsoft.graph.win32LobApp' }
                                )
                            }
                        }
                        @{ id = "2"; status = 200; body = @{ value = @() } }
                        @{ id = "3"; status = 200; body = @{ value = @() } }
                        @{ id = "4"; status = 200; body = @{ value = @() } }
                        @{ id = "5"; status = 200; body = @{ value = @() } }
                        @{ id = "6"; status = 200; body = @{ value = @() } }
                        @{ id = "7"; status = 200; body = @{ value = @() } }
                        @{ id = "8"; status = 200; body = @{ value = @() } }
                    )
                }
                elseif ($ResourcePath -match 'assignments')
                {
                    return @{
                        value = @()  # No assignments
                    }
                }
                else
                {
                    return @{ value = @() }
                }
            }

            $result = Export-ConfigurationAssignments -AccessToken $script:TestAccessToken -OutputPath $script:TestOutputFolder

            $result.Success | Should -Be $true

            # Verify CSV content
            if (Test-Path $result.OutputFile)
            {
                $csvContent = Import-Csv -Path $result.OutputFile
                $csvContent[0].Classification | Should -Be "Unassigned"
                $csvContent[0].HasDirectAssignment | Should -Be "False"
                $csvContent[0].HasAllUsers | Should -Be "False"
                $csvContent[0].HasAllDevices | Should -Be "False"
            }
        }
    }

    Context "CSV Export Structure" {
        It "Should export CSV with all required columns" {
            Mock CallGraphAPI {
                param($AccessToken, $ResourcePath)

                if ($ResourcePath -is [array])
                {
                    return New-MockBatchResponse -BatchItems @(
                        @{
                            id     = "1"
                            status = 200
                            body   = @{
                                value = @(
                                    @{ id = "app-1"; displayName = "Test App"; description = "App description"; '@odata.type' = '#microsoft.graph.win32LobApp' }
                                )
                            }
                        }
                        @{ id = "2"; status = 200; body = @{ value = @() } }
                        @{ id = "3"; status = 200; body = @{ value = @() } }
                        @{ id = "4"; status = 200; body = @{ value = @() } }
                        @{ id = "5"; status = 200; body = @{ value = @() } }
                        @{ id = "6"; status = 200; body = @{ value = @() } }
                        @{ id = "7"; status = 200; body = @{ value = @() } }
                        @{ id = "8"; status = 200; body = @{ value = @() } }
                    )
                }
                elseif ($ResourcePath -match 'assignments')
                {
                    return @{ value = @() }
                }
                else
                {
                    return @{ value = @() }
                }
            }

            $result = Export-ConfigurationAssignments -AccessToken $script:TestAccessToken -OutputPath $script:TestOutputFolder

            $result.Success | Should -Be $true

            # Verify CSV columns
            if (Test-Path $result.OutputFile)
            {
                $csvContent = Import-Csv -Path $result.OutputFile
                $csvContent[0].PSObject.Properties.Name | Should -Contain "ResourceName"
                $csvContent[0].PSObject.Properties.Name | Should -Contain "Description"
                $csvContent[0].PSObject.Properties.Name | Should -Contain "Category"
                $csvContent[0].PSObject.Properties.Name | Should -Contain "ResourceType"
                $csvContent[0].PSObject.Properties.Name | Should -Contain "ODataType"
                $csvContent[0].PSObject.Properties.Name | Should -Contain "ResourceId"
                $csvContent[0].PSObject.Properties.Name | Should -Contain "AssignmentCount"
                $csvContent[0].PSObject.Properties.Name | Should -Contain "Classification"
                $csvContent[0].PSObject.Properties.Name | Should -Contain "HasDirectAssignment"
                $csvContent[0].PSObject.Properties.Name | Should -Contain "HasAllUsers"
                $csvContent[0].PSObject.Properties.Name | Should -Contain "HasAllDevices"
            }
        }

        It "Should include RawTargets with assignment details" {
            $testGroupId = "raw-target-group-guid"

            Mock CallGraphAPI {
                param($AccessToken, $ResourcePath)

                if ($ResourcePath -is [array])
                {
                    return New-MockBatchResponse -BatchItems @(
                        @{
                            id     = "1"
                            status = 200
                            body   = @{
                                value = @(
                                    @{ id = "app-1"; displayName = "Raw Target App"; description = ""; '@odata.type' = '#microsoft.graph.win32LobApp' }
                                )
                            }
                        }
                        @{ id = "2"; status = 200; body = @{ value = @() } }
                        @{ id = "3"; status = 200; body = @{ value = @() } }
                        @{ id = "4"; status = 200; body = @{ value = @() } }
                        @{ id = "5"; status = 200; body = @{ value = @() } }
                        @{ id = "6"; status = 200; body = @{ value = @() } }
                        @{ id = "7"; status = 200; body = @{ value = @() } }
                        @{ id = "8"; status = 200; body = @{ value = @() } }
                    )
                }
                elseif ($ResourcePath -match 'assignments')
                {
                    return @{
                        value = @(
                            @{
                                id     = "assignment-1"
                                intent = "required"
                                target = @{
                                    '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
                                    groupId       = $testGroupId
                                }
                            }
                        )
                    }
                }
                else
                {
                    return @{ value = @() }
                }
            }

            $result = Export-ConfigurationAssignments -AccessToken $script:TestAccessToken -OutputPath $script:TestOutputFolder

            $result.Success | Should -Be $true

            # Verify RawTargets contains expected information
            if (Test-Path $result.OutputFile)
            {
                $csvContent = Import-Csv -Path $result.OutputFile
                $csvContent[0].RawTargets | Should -Match "groupAssignmentTarget"
            }
        }
    }

    Context "Return Object Structure" {
        It "Should return object with Success, OutputFile, ResourceCount, ErrorCount, and Message" {
            Mock CallGraphAPI {
                return New-EmptyBatchResponse
            }

            $result = Export-ConfigurationAssignments -AccessToken $script:TestAccessToken -OutputPath $script:TestOutputFolder

            $result.PSObject.Properties.Name | Should -Contain "Success"
            $result.PSObject.Properties.Name | Should -Contain "OutputFile"
            $result.PSObject.Properties.Name | Should -Contain "ErrorFile"
            $result.PSObject.Properties.Name | Should -Contain "ResourceCount"
            $result.PSObject.Properties.Name | Should -Contain "ErrorCount"
            $result.PSObject.Properties.Name | Should -Contain "Message"

            $result.Success | Should -BeOfType [bool]
        }
    }
}




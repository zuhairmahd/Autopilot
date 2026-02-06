<#
.SYNOPSIS
    Unit tests for Get-UserSignInActivity function

.DESCRIPTION
    Tests sign-in activity retrieval from Microsoft Graph auditLogs/signIns endpoint.
    Covers successful retrieval, error handling, conditional access parsing, and
    analysis pattern generation.

.NOTES
    Test Category: Unit
    Function: Get-UserSignInActivity
    Module: graphFunctions
    Coverage Target: Sign-in data extraction, error handling, CA policy parsing

    Approach:
    - Direct dot-sourcing for PS 5.1 compatibility
    - Mock CallGraphAPI to simulate Graph API responses
    - Test all response scenarios (success, failure, no data, API errors)
    - Validate return object structure and field extraction
#>

Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: Get-UserSignInActivity" -Tags 'Unit', 'GraphFunctions' {
    BeforeAll {
        # Get repository root and load dependencies
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName

        # Load dependencies
        . (Join-Path $script:RepoRoot "functions/utilityFunctions/Write-Log.ps1")

        # Load function under test
        . (Join-Path $script:RepoRoot "functions/graphFunctions/Get-UserSignInActivity.ps1")

        # Mock Write-Log for all tests
        Mock Write-Log {}

        # Initialize required variables
        $script:LogFile = "TestDrive:\test.log"
        $global:LogFile = "TestDrive:\test.log"
        $script:testAccessToken = "test-access-token-12345"
        $script:testUPN = "john.doe@contoso.com"
    }

    AfterAll {
        Remove-Variable -Name LogFile -Scope Global -ErrorAction SilentlyContinue
    }

    Context "When retrieving successful sign-in events" {
        It "Should return sign-in data for a user with successful sign-ins" {
            Mock CallGraphAPI {
                return @{
                    value = @(
                        @{
                            id                              = "signin-001"
                            createdDateTime                 = "2025-01-15T10:30:00Z"
                            userDisplayName                 = "John Doe"
                            userPrincipalName               = "john.doe@contoso.com"
                            appDisplayName                  = "Microsoft Teams"
                            ipAddress                       = "192.168.1.100"
                            clientAppUsed                   = "Browser"
                            isInteractive                   = $true
                            conditionalAccessStatus         = "success"
                            location                        = @{
                                city             = "Seattle"
                                state            = "Washington"
                                countryOrRegion  = "US"
                            }
                            status                          = @{
                                errorCode        = 0
                                failureReason    = $null
                                additionalDetails = $null
                            }
                            appliedConditionalAccessPolicies = @(
                                @{
                                    id                      = "policy-001"
                                    displayName             = "Require MFA"
                                    result                  = "success"
                                    enforcedGrantControls   = @("Mfa")
                                    enforcedSessionControls = @()
                                }
                            )
                        }
                    )
                }
            }

            $result = Get-UserSignInActivity -accessToken $script:testAccessToken -userPrincipalName $script:testUPN

            $result.Success | Should -Be $true
            $result.SignIns.Count | Should -Be 1
            $result.LatestSignIn | Should -Not -BeNullOrEmpty
            $result.LatestSignIn.IPAddress | Should -Be "192.168.1.100"
            $result.LatestSignIn.LocationCity | Should -Be "Seattle"
            $result.LatestSignIn.LocationState | Should -Be "Washington"
            $result.LatestSignIn.LocationCountryOrRegion | Should -Be "US"
            $result.LatestSignIn.SignInSucceeded | Should -Be $true
            $result.LatestSignIn.ErrorCode | Should -Be 0
            $result.LatestSignIn.ConditionalAccessStatus | Should -Be "success"
            $result.LatestSignIn.CABlockedByPolicy | Should -Be $false
            $result.LatestSignIn.AppDisplayName | Should -Be "Microsoft Teams"
        }

        It "Should parse conditional access policies correctly" {
            Mock CallGraphAPI {
                return @{
                    value = @(
                        @{
                            id                              = "signin-002"
                            createdDateTime                 = "2025-01-15T09:00:00Z"
                            userDisplayName                 = "John Doe"
                            userPrincipalName               = "john.doe@contoso.com"
                            appDisplayName                  = "Outlook"
                            ipAddress                       = "10.0.0.50"
                            clientAppUsed                   = "Mobile Apps and Desktop clients"
                            isInteractive                   = $true
                            conditionalAccessStatus         = "success"
                            location                        = @{
                                city            = "Redmond"
                                state           = "Washington"
                                countryOrRegion = "US"
                            }
                            status                          = @{
                                errorCode        = 0
                                failureReason    = $null
                                additionalDetails = $null
                            }
                            appliedConditionalAccessPolicies = @(
                                @{
                                    id                      = "policy-001"
                                    displayName             = "Require MFA"
                                    result                  = "success"
                                    enforcedGrantControls   = @("Mfa")
                                    enforcedSessionControls = @()
                                }
                                @{
                                    id                      = "policy-002"
                                    displayName             = "Require Compliant Device"
                                    result                  = "notApplied"
                                    enforcedGrantControls   = @("CompliantDevice")
                                    enforcedSessionControls = @()
                                }
                            )
                        }
                    )
                }
            }

            $result = Get-UserSignInActivity -accessToken $script:testAccessToken -userPrincipalName $script:testUPN

            $result.Success | Should -Be $true
            $result.LatestSignIn.CAPoliciesApplied.Count | Should -Be 2
            $result.LatestSignIn.CAPoliciesApplied[0].PolicyName | Should -Be "Require MFA"
            $result.LatestSignIn.CAPoliciesApplied[0].Result | Should -Be "success"
            $result.LatestSignIn.CAPoliciesApplied[0].EnforcedGrantControls | Should -Contain "Mfa"
            $result.LatestSignIn.CAPoliciesApplied[1].PolicyName | Should -Be "Require Compliant Device"
            $result.LatestSignIn.CAPoliciesApplied[1].Result | Should -Be "notApplied"
        }

        It "Should handle multiple sign-in events and set LatestSignIn to first" {
            Mock CallGraphAPI {
                return @{
                    value = @(
                        @{
                            id                      = "signin-latest"
                            createdDateTime         = "2025-01-15T12:00:00Z"
                            userDisplayName         = "John Doe"
                            userPrincipalName       = "john.doe@contoso.com"
                            appDisplayName          = "Teams"
                            ipAddress               = "10.0.0.1"
                            clientAppUsed           = "Browser"
                            isInteractive           = $true
                            conditionalAccessStatus = "notApplied"
                            location                = @{ city = "Seattle"; state = "WA"; countryOrRegion = "US" }
                            status                  = @{ errorCode = 0; failureReason = $null; additionalDetails = $null }
                            appliedConditionalAccessPolicies = @()
                        }
                        @{
                            id                      = "signin-older"
                            createdDateTime         = "2025-01-14T08:00:00Z"
                            userDisplayName         = "John Doe"
                            userPrincipalName       = "john.doe@contoso.com"
                            appDisplayName          = "Outlook"
                            ipAddress               = "10.0.0.2"
                            clientAppUsed           = "Browser"
                            isInteractive           = $true
                            conditionalAccessStatus = "notApplied"
                            location                = @{ city = "Portland"; state = "OR"; countryOrRegion = "US" }
                            status                  = @{ errorCode = 0; failureReason = $null; additionalDetails = $null }
                            appliedConditionalAccessPolicies = @()
                        }
                    )
                }
            }

            $result = Get-UserSignInActivity -accessToken $script:testAccessToken -userPrincipalName $script:testUPN

            $result.Success | Should -Be $true
            $result.SignIns.Count | Should -Be 2
            $result.LatestSignIn.SignInId | Should -Be "signin-latest"
            $result.LatestSignIn.IPAddress | Should -Be "10.0.0.1"
        }
    }

    Context "When sign-in failed" {
        It "Should correctly identify failed sign-ins" {
            Mock CallGraphAPI {
                return @{
                    value = @(
                        @{
                            id                      = "signin-fail-001"
                            createdDateTime         = "2025-01-15T10:00:00Z"
                            userDisplayName         = "John Doe"
                            userPrincipalName       = "john.doe@contoso.com"
                            appDisplayName          = "Azure Portal"
                            ipAddress               = "203.0.113.50"
                            clientAppUsed           = "Browser"
                            isInteractive           = $true
                            conditionalAccessStatus = "notApplied"
                            location                = @{ city = "Unknown"; state = $null; countryOrRegion = "CN" }
                            status                  = @{
                                errorCode        = 50053
                                failureReason    = "Sign-in was blocked because it came from an IP address with malicious activity"
                                additionalDetails = "Basic Authentication blocked."
                            }
                            appliedConditionalAccessPolicies = @()
                        }
                    )
                }
            }

            $result = Get-UserSignInActivity -accessToken $script:testAccessToken -userPrincipalName $script:testUPN

            $result.Success | Should -Be $true
            $result.LatestSignIn.SignInSucceeded | Should -Be $false
            $result.LatestSignIn.ErrorCode | Should -Be 50053
            $result.LatestSignIn.FailureReason | Should -Be "Sign-in was blocked because it came from an IP address with malicious activity"
            $result.LatestSignIn.AdditionalDetails | Should -Be "Basic Authentication blocked."
        }

        It "Should detect conditional access policy failures" {
            Mock CallGraphAPI {
                return @{
                    value = @(
                        @{
                            id                              = "signin-ca-fail"
                            createdDateTime                 = "2025-01-15T11:00:00Z"
                            userDisplayName                 = "John Doe"
                            userPrincipalName               = "john.doe@contoso.com"
                            appDisplayName                  = "SharePoint"
                            ipAddress                       = "198.51.100.25"
                            clientAppUsed                   = "Browser"
                            isInteractive                   = $true
                            conditionalAccessStatus         = "failure"
                            location                        = @{ city = "London"; state = "England"; countryOrRegion = "GB" }
                            status                          = @{
                                errorCode        = 53003
                                failureReason    = "Access has been blocked by Conditional Access policies."
                                additionalDetails = $null
                            }
                            appliedConditionalAccessPolicies = @(
                                @{
                                    id                      = "policy-block"
                                    displayName             = "Block External Access"
                                    result                  = "failure"
                                    enforcedGrantControls   = @("Block")
                                    enforcedSessionControls = @()
                                }
                            )
                        }
                    )
                }
            }

            $result = Get-UserSignInActivity -accessToken $script:testAccessToken -userPrincipalName $script:testUPN

            $result.Success | Should -Be $true
            $result.LatestSignIn.SignInSucceeded | Should -Be $false
            $result.LatestSignIn.CABlockedByPolicy | Should -Be $true
            $result.LatestSignIn.ConditionalAccessStatus | Should -Be "failure"
            $result.LatestSignIn.CAPoliciesApplied[0].PolicyName | Should -Be "Block External Access"
            $result.LatestSignIn.CAPoliciesApplied[0].Result | Should -Be "failure"
            $result.LatestSignIn.FailureReason | Should -Be "Access has been blocked by Conditional Access policies."
        }
    }

    Context "When no sign-in data is available" {
        It "Should handle empty response gracefully" {
            Mock CallGraphAPI {
                return @{
                    value = @()
                }
            }

            $result = Get-UserSignInActivity -accessToken $script:testAccessToken -userPrincipalName $script:testUPN

            $result.Success | Should -Be $true
            $result.SignIns.Count | Should -Be 0
            $result.LatestSignIn | Should -BeNullOrEmpty
            $result.Message | Should -Match "No sign-in events found"
        }
    }

    Context "When Graph API returns errors" {
        It "Should handle 403 Forbidden (insufficient permissions)" {
            Mock CallGraphAPI {
                return 403
            }

            $result = Get-UserSignInActivity -accessToken $script:testAccessToken -userPrincipalName $script:testUPN

            $result.Success | Should -Be $false
            $result.Message | Should -Match "error status 403"
            $result.Message | Should -Match "AuditLog.Read.All"
        }

        It "Should handle null response from API" {
            Mock CallGraphAPI {
                return $null
            }

            $result = Get-UserSignInActivity -accessToken $script:testAccessToken -userPrincipalName $script:testUPN

            $result.Success | Should -Be $false
            $result.Message | Should -Match "No response received"
        }

        It "Should handle 401 Unauthorized" {
            Mock CallGraphAPI {
                return 401
            }

            $result = Get-UserSignInActivity -accessToken $script:testAccessToken -userPrincipalName $script:testUPN

            $result.Success | Should -Be $false
            $result.Message | Should -Match "error status 401"
        }

        It "Should handle exception from CallGraphAPI" {
            Mock CallGraphAPI {
                throw "Network connection failed"
            }

            $result = Get-UserSignInActivity -accessToken $script:testAccessToken -userPrincipalName $script:testUPN -ErrorAction SilentlyContinue

            $result.Success | Should -Be $false
            $result.Message | Should -Match "Error retrieving sign-in activity"
        }
    }

    Context "When handling location data" {
        It "Should handle missing location fields" {
            Mock CallGraphAPI {
                return @{
                    value = @(
                        @{
                            id                      = "signin-noloc"
                            createdDateTime         = "2025-01-15T10:00:00Z"
                            userDisplayName         = "John Doe"
                            userPrincipalName       = "john.doe@contoso.com"
                            appDisplayName          = "Teams"
                            ipAddress               = "10.0.0.1"
                            clientAppUsed           = "Browser"
                            isInteractive           = $true
                            conditionalAccessStatus = "notApplied"
                            location                = $null
                            status                  = @{ errorCode = 0; failureReason = $null; additionalDetails = $null }
                            appliedConditionalAccessPolicies = @()
                        }
                    )
                }
            }

            $result = Get-UserSignInActivity -accessToken $script:testAccessToken -userPrincipalName $script:testUPN

            $result.Success | Should -Be $true
            $result.LatestSignIn.LocationCity | Should -BeNullOrEmpty
            $result.LatestSignIn.LocationState | Should -BeNullOrEmpty
            $result.LatestSignIn.LocationCountryOrRegion | Should -BeNullOrEmpty
        }

        It "Should handle partial location data" {
            Mock CallGraphAPI {
                return @{
                    value = @(
                        @{
                            id                      = "signin-partial-loc"
                            createdDateTime         = "2025-01-15T10:00:00Z"
                            userDisplayName         = "John Doe"
                            userPrincipalName       = "john.doe@contoso.com"
                            appDisplayName          = "Outlook"
                            ipAddress               = "10.0.0.1"
                            clientAppUsed           = "Browser"
                            isInteractive           = $true
                            conditionalAccessStatus = "notApplied"
                            location                = @{
                                city            = $null
                                state           = $null
                                countryOrRegion = "US"
                            }
                            status                  = @{ errorCode = 0; failureReason = $null; additionalDetails = $null }
                            appliedConditionalAccessPolicies = @()
                        }
                    )
                }
            }

            $result = Get-UserSignInActivity -accessToken $script:testAccessToken -userPrincipalName $script:testUPN

            $result.Success | Should -Be $true
            $result.LatestSignIn.LocationCity | Should -BeNullOrEmpty
            $result.LatestSignIn.LocationCountryOrRegion | Should -Be "US"
        }
    }

    Context "When calling Graph API with correct parameters" {
        It "Should use v1.0 API version" {
            Mock CallGraphAPI {
                return @{ value = @() }
            } -ParameterFilter { $APIVersion -eq "v1.0" }

            $result = Get-UserSignInActivity -accessToken $script:testAccessToken -userPrincipalName $script:testUPN

            Should -Invoke CallGraphAPI -Times 1 -ParameterFilter { $APIVersion -eq "v1.0" }
        }

        It "Should pass correct resource path" {
            Mock CallGraphAPI {
                return @{ value = @() }
            } -ParameterFilter { $ResourcePath -eq "auditLogs/signIns" }

            $result = Get-UserSignInActivity -accessToken $script:testAccessToken -userPrincipalName $script:testUPN

            Should -Invoke CallGraphAPI -Times 1 -ParameterFilter { $ResourcePath -eq "auditLogs/signIns" }
        }

        It "Should include user UPN in filter" {
            Mock CallGraphAPI {
                return @{ value = @() }
            } -ParameterFilter { $Filter -like "*john.doe@contoso.com*" }

            $result = Get-UserSignInActivity -accessToken $script:testAccessToken -userPrincipalName $script:testUPN

            Should -Invoke CallGraphAPI -Times 1 -ParameterFilter { $Filter -like "*john.doe@contoso.com*" }
        }

        It "Should include date range in filter" {
            Mock CallGraphAPI {
                return @{ value = @() }
            } -ParameterFilter { $Filter -like "*createdDateTime ge*" }

            $result = Get-UserSignInActivity -accessToken $script:testAccessToken -userPrincipalName $script:testUPN

            Should -Invoke CallGraphAPI -Times 1 -ParameterFilter { $Filter -like "*createdDateTime ge*" }
        }

        It "Should include top and orderby in extra parameters" {
            Mock CallGraphAPI {
                return @{ value = @() }
            } -ParameterFilter { $ExtraParameters -like "*top=*" -and $ExtraParameters -like "*orderby=*" }

            $result = Get-UserSignInActivity -accessToken $script:testAccessToken -userPrincipalName $script:testUPN

            Should -Invoke CallGraphAPI -Times 1 -ParameterFilter { $ExtraParameters -like "*top=*" -and $ExtraParameters -like "*orderby=*" }
        }

        It "Should respect custom maxResults parameter" {
            Mock CallGraphAPI {
                return @{ value = @() }
            } -ParameterFilter { $ExtraParameters -like "*top=10*" }

            $result = Get-UserSignInActivity -accessToken $script:testAccessToken -userPrincipalName $script:testUPN -maxResults 10

            Should -Invoke CallGraphAPI -Times 1 -ParameterFilter { $ExtraParameters -like "*top=10*" }
        }
    }

    Context "When processing mixed success and failure sign-ins" {
        It "Should correctly count successes and failures across multiple sign-ins" {
            Mock CallGraphAPI {
                return @{
                    value = @(
                        @{
                            id = "s1"; createdDateTime = "2025-01-15T12:00:00Z"
                            userDisplayName = "John Doe"; userPrincipalName = "john.doe@contoso.com"
                            appDisplayName = "Teams"; ipAddress = "10.0.0.1"; clientAppUsed = "Browser"
                            isInteractive = $true; conditionalAccessStatus = "success"
                            location = @{ city = "Seattle"; state = "WA"; countryOrRegion = "US" }
                            status = @{ errorCode = 0; failureReason = $null; additionalDetails = $null }
                            appliedConditionalAccessPolicies = @()
                        }
                        @{
                            id = "s2"; createdDateTime = "2025-01-15T11:00:00Z"
                            userDisplayName = "John Doe"; userPrincipalName = "john.doe@contoso.com"
                            appDisplayName = "Outlook"; ipAddress = "10.0.0.2"; clientAppUsed = "Browser"
                            isInteractive = $true; conditionalAccessStatus = "failure"
                            location = @{ city = "London"; state = "England"; countryOrRegion = "GB" }
                            status = @{ errorCode = 53003; failureReason = "Blocked by CA"; additionalDetails = $null }
                            appliedConditionalAccessPolicies = @()
                        }
                        @{
                            id = "s3"; createdDateTime = "2025-01-15T10:00:00Z"
                            userDisplayName = "John Doe"; userPrincipalName = "john.doe@contoso.com"
                            appDisplayName = "SharePoint"; ipAddress = "10.0.0.1"; clientAppUsed = "Browser"
                            isInteractive = $true; conditionalAccessStatus = "success"
                            location = @{ city = "Seattle"; state = "WA"; countryOrRegion = "US" }
                            status = @{ errorCode = 0; failureReason = $null; additionalDetails = $null }
                            appliedConditionalAccessPolicies = @()
                        }
                    )
                }
            }

            $result = Get-UserSignInActivity -accessToken $script:testAccessToken -userPrincipalName $script:testUPN

            $result.Success | Should -Be $true
            $result.SignIns.Count | Should -Be 3

            $successes = ($result.SignIns | Where-Object { $_.SignInSucceeded -eq $true })
            $failures = ($result.SignIns | Where-Object { $_.SignInSucceeded -eq $false })
            $caBlocked = ($result.SignIns | Where-Object { $_.CABlockedByPolicy -eq $true })

            @($successes).Count | Should -Be 2
            @($failures).Count | Should -Be 1
            @($caBlocked).Count | Should -Be 1
        }
    }

    Context "When handling single sign-in object response" {
        It "Should handle a response with an id property as a single sign-in" {
            Mock CallGraphAPI {
                return @{
                    id                      = "single-signin"
                    createdDateTime         = "2025-01-15T10:00:00Z"
                    userDisplayName         = "John Doe"
                    userPrincipalName       = "john.doe@contoso.com"
                    appDisplayName          = "Teams"
                    ipAddress               = "10.0.0.1"
                    clientAppUsed           = "Browser"
                    isInteractive           = $true
                    conditionalAccessStatus = "notApplied"
                    location                = @{ city = "Seattle"; state = "WA"; countryOrRegion = "US" }
                    status                  = @{ errorCode = 0; failureReason = $null; additionalDetails = $null }
                    appliedConditionalAccessPolicies = @()
                }
            }

            $result = Get-UserSignInActivity -accessToken $script:testAccessToken -userPrincipalName $script:testUPN

            $result.Success | Should -Be $true
            $result.SignIns.Count | Should -Be 1
            $result.LatestSignIn.SignInId | Should -Be "single-signin"
        }
    }
}

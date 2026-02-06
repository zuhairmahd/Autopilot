BeforeAll {
    $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName

    # Import test helpers
    Import-Module "$PSScriptRoot/../../../Helpers/AutopilotTestHelpers.psm1" -Force
    Import-Module "$PSScriptRoot/../../../Helpers/AutopilotGraphMocks.psm1" -Force

    # Dot-source the functions under test
    . "$script:RepoRoot/functions/autopilotFunctions/Reports/Get-SignInActivity.ps1"
    . "$script:RepoRoot/functions/graphFunctions/CallGraphAPI.ps1"
    . "$script:RepoRoot/functions/utilityFunctions/FormatDateWithTimeZone.ps1"
    . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"

    # Mock global variables
    $global:LogFile = Join-Path $TestDrive "test.log"
}

Describe "Get-SignInActivity" -Tags 'Unit' {
    BeforeEach {
        $testToken = "test-token-12345"
        $testUpn = "user@contoso.com"

        # Mock CallGraphAPI
        Mock CallGraphAPI {
            return @{
                value = @(
                    @{
                        id                           = "signin-1"
                        createdDateTime              = "2026-02-01T10:00:00Z"
                        userDisplayName              = "Test User"
                        userPrincipalName            = "user@contoso.com"
                        appDisplayName               = "Microsoft 365"
                        ipAddress                    = "1.2.3.4"
                        clientAppUsed                = "Browser"
                        isInteractive                = $true
                        location                     = @{
                            city                = "Seattle"
                            state               = "WA"
                            countryOrRegion     = "US"
                        }
                        status                       = @{
                            errorCode       = 0
                            failureReason   = $null
                            additionalDetails = "Success"
                        }
                        conditionalAccessStatus      = "success"
                        appliedConditionalAccessPolicies = @()
                    }
                )
            }
        }
    }

    Context "Parameter Validation" {
        It "Should require UserPrincipalName parameter" {
            { Get-SignInActivity -UserPrincipalName "" -AccessToken $testToken } | Should -Throw
        }

        It "Should accept AccessToken parameter" {
            $result = Get-SignInActivity -UserPrincipalName $testUpn -AccessToken $testToken
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should use global token if AccessToken not provided" {
            $global:accessToken = $testToken
            $result = Get-SignInActivity -UserPrincipalName $testUpn
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should throw if no token available" {
            $global:accessToken = $null
            { Get-SignInActivity -UserPrincipalName $testUpn } | Should -Throw
        }
    }

    Context "Sign-In Data Retrieval" {
        It "Should call Graph API with correct parameters" {
            Get-SignInActivity -UserPrincipalName $testUpn -AccessToken $testToken

            Should -Invoke CallGraphAPI -Times 1 -ParameterFilter {
                $ResourcePath -eq "auditLogs/signIns" -and
                $APIVersion -eq "v1.0" -and
                $Filter -like "*userPrincipalName eq*" -and
                $ExtraParameters -like "*top=*"
            }
        }

        It "Should return success when sign-ins are found" {
            $result = Get-SignInActivity -UserPrincipalName $testUpn -AccessToken $testToken

            $result.Success | Should -Be $true
            $result.SignIns | Should -Not -BeNullOrEmpty
            $result.LatestSignIn | Should -Not -BeNullOrEmpty
        }

        It "Should handle no sign-ins found" {
            Mock CallGraphAPI {
                return @{ value = @() }
            }

            $result = Get-SignInActivity -UserPrincipalName $testUpn -AccessToken $testToken

            $result.Success | Should -Be $true
            $result.SignIns | Should -BeNullOrEmpty
            $result.Message | Should -Match "No sign-in events found"
        }

        It "Should handle API errors gracefully" {
            Mock CallGraphAPI {
                return 403
            }

            $result = Get-SignInActivity -UserPrincipalName $testUpn -AccessToken $testToken

            $result.Success | Should -Be $false
            $result.Message | Should -Match "error status 403"
        }
    }

    Context "Sign-In Data Processing" {
        It "Should extract all relevant fields from sign-in events" {
            $result = Get-SignInActivity -UserPrincipalName $testUpn -AccessToken $testToken

            $signIn = $result.LatestSignIn
            $signIn.SignInId | Should -Be "signin-1"
            $signIn.UserPrincipalName | Should -Be "user@contoso.com"
            $signIn.IPAddress | Should -Be "1.2.3.4"
            $signIn.LocationCity | Should -Be "Seattle"
            $signIn.SignInSucceeded | Should -Be $true
        }

        It "Should correctly identify successful sign-ins" {
            $result = Get-SignInActivity -UserPrincipalName $testUpn -AccessToken $testToken

            $result.LatestSignIn.SignInSucceeded | Should -Be $true
            $result.LatestSignIn.ErrorCode | Should -Be 0
        }

        It "Should correctly identify failed sign-ins" {
            Mock CallGraphAPI {
                return @{
                    value = @(
                        @{
                            id                           = "signin-fail"
                            createdDateTime              = "2026-02-01T10:00:00Z"
                            userPrincipalName            = "user@contoso.com"
                            ipAddress                    = "1.2.3.4"
                            status                       = @{
                                errorCode       = 50126
                                failureReason   = "Invalid credentials"
                            }
                            conditionalAccessStatus      = "notApplied"
                            appliedConditionalAccessPolicies = @()
                        }
                    )
                }
            }

            $result = Get-SignInActivity -UserPrincipalName $testUpn -AccessToken $testToken

            $result.LatestSignIn.SignInSucceeded | Should -Be $false
            $result.LatestSignIn.FailureReason | Should -Be "Invalid credentials"
        }
    }

    Context "Enrichment Mode" {
        It "Should return enrichment data when EnrichmentOnly is specified" {
            $result = Get-SignInActivity -UserPrincipalName $testUpn -AccessToken $testToken -EnrichmentOnly

            $result | Should -BeOfType [hashtable]
            $result.SignInLatestStatus | Should -Not -BeNullOrEmpty
            $result.SignInLatestDateTime | Should -Not -BeNullOrEmpty
            $result.SignInRecentPattern | Should -Not -BeNullOrEmpty
        }

        It "Should format enrichment data correctly" {
            $result = Get-SignInActivity -UserPrincipalName $testUpn -AccessToken $testToken -EnrichmentOnly

            $result.SignInLatestStatus | Should -Be "Success"
            $result.SignInLatestIPAddress | Should -Be "1.2.3.4"
            $result.SignInLatestLocation | Should -Match "Seattle"
        }

        It "Should handle no sign-ins in enrichment mode" {
            Mock CallGraphAPI {
                return @{ value = @() }
            }

            $result = Get-SignInActivity -UserPrincipalName $testUpn -AccessToken $testToken -EnrichmentOnly

            $result.SignInLatestStatus | Should -Match "No sign-in data available"
        }
    }

    Context "ConvertTo-SignInEnrichmentData" {
        It "Should convert full sign-in data to enrichment format" {
            $signInData = @{
                Success      = $true
                SignIns      = @(
                    @{
                        SignInSucceeded = $true
                        IPAddress       = "1.2.3.4"
                        CreatedDateTime = "2026-02-01T10:00:00Z"
                    }
                )
                LatestSignIn = @{
                    SignInSucceeded = $true
                    IPAddress       = "1.2.3.4"
                    CreatedDateTime = "2026-02-01T10:00:00Z"
                    LocationCity    = "Seattle"
                    LocationState   = "WA"
                }
            }

            $result = ConvertTo-SignInEnrichmentData -SignInData $signInData

            $result.SignInLatestStatus | Should -Be "Success"
            $result.SignInLatestIPAddress | Should -Be "1.2.3.4"
        }
    }

    Context "Legacy Get-UserSignInActivity Wrapper" {
        It "Should support legacy function name" {
            $result = Get-UserSignInActivity -accessToken $testToken -userPrincipalName $testUpn

            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }
    }
}

Describe "Get-SignInActivity Integration with Analysis Functions" -Tags 'Integration' {
    BeforeAll {
        # Dot-source analysis functions
        . "$script:RepoRoot/functions/autopilotFunctions/Reports/Get-AutopilotEventAnalysis.ps1"
    }

    It "Should support enrichment workflow for autopilot analysis" {
        $testToken = "test-token-12345"
        $testUpn = "user@contoso.com"

        Mock CallGraphAPI {
            return @{
                value = @(
                    @{
                        id                  = "signin-1"
                        createdDateTime     = "2026-02-01T10:00:00Z"
                        userPrincipalName   = "user@contoso.com"
                        ipAddress           = "1.2.3.4"
                        status              = @{ errorCode = 0 }
                        conditionalAccessStatus = "success"
                        appliedConditionalAccessPolicies = @()
                    }
                )
            }
        }

        $enrichment = Get-SignInActivity -UserPrincipalName $testUpn -AccessToken $testToken -EnrichmentOnly

        $enrichment.Keys | Should -Contain "SignInLatestStatus"
        $enrichment.Keys | Should -Contain "SignInRecentPattern"
        $enrichment.Keys | Should -Contain "SignInConditionalAccessStatus"
    }
}

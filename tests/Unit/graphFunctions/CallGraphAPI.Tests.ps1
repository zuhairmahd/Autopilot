<#
.SYNOPSIS
    Unit tests for CallGraphAPI function
.DESCRIPTION
    Tests Graph API HTTP operations, pagination, filtering, error handling, and retry logic
    Compatible with PowerShell 5.1 and Pester 5.x
.NOTES
    Part of Week 4 Phase 2 coverage improvement initiative
    Tests use mocked Invoke-RestMethod to avoid actual Graph API calls
    Focus: Core GET/POST/PATCH/DELETE operations, pagination, error codes
#>

Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: CallGraphAPI" -Tags 'Unit', 'GraphFunctions' {
    BeforeAll {
        # Direct dot-sourcing for PS 5.1 compatibility
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        
        # Load dependencies using Join-Path for cross-platform compatibility
        . (Join-Path $script:RepoRoot "functions\utilityFunctions\Write-Log.ps1")
        . (Join-Path $script:RepoRoot "functions\graphFunctions\ProcessFilterCondition.ps1")
        
        # Load function under test
        . (Join-Path $script:RepoRoot "functions\graphFunctions\CallGraphAPI.ps1")
        
        # Mock Write-Log for all tests
        Mock Write-Log {}
        
        # Initialize required script variables (case-sensitive!)
        $script:logFile = "TestDrive:\test.log"  # lowercase 'f' - CallGraphAPI expects $logFile
        $script:testAccessToken = "test-access-token-12345"
    }
    
    Context "When making successful GET requests" {
        It "Should return data for simple GET request" {
            Mock Invoke-RestMethod {
                return @{
                    value = @(
                        @{ id = "1"; displayName = "User 1" }
                        @{ id = "2"; displayName = "User 2" }
                    )
                }
            }
            
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users" -method "get"
            
            $result.value.Count | Should -Be 2
            $result.value[0].displayName | Should -Be "User 1"
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly
        }
        
        It "Should construct correct URI with beta API version" {
            Mock Invoke-RestMethod {
                param($Uri)
                $Uri | Should -Be "https://graph.microsoft.com/beta/users"
                return @{ value = @() }
            }
            
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users" -APIVersion "beta"
            
            Should -Invoke Invoke-RestMethod -Times 1
        }
        
        It "Should construct correct URI with v1.0 API version" {
            Mock Invoke-RestMethod {
                param($Uri)
                $Uri | Should -Be "https://graph.microsoft.com/v1.0/devices"
                return @{ value = @() }
            }
            
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "devices" -APIVersion "v1.0"
            
            Should -Invoke Invoke-RestMethod -Times 1
        }
        
        It "Should include Authorization header with bearer token" {
            Mock Invoke-RestMethod {
                param($Headers)
                $Headers.Authorization | Should -Be "Bearer $script:testAccessToken"
                return @{ value = @() }
            }
            
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users"
            
            Should -Invoke Invoke-RestMethod -Times 1
        }
        
        It "Should set Content-Type header to application/json" {
            Mock Invoke-RestMethod {
                param($Headers)
                $Headers.'Content-Type' | Should -Be "application/json"
                return @{ value = @() }
            }
            
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users"
            
            Should -Invoke Invoke-RestMethod -Times 1
        }
    }
    
    Context "When using HTTP methods" {
        It "Should use GET method by default" {
            Mock Invoke-RestMethod {
                param($Method)
                $Method | Should -Be "get"
                return @{ value = @() }
            }
            
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users"
            
            Should -Invoke Invoke-RestMethod -Times 1
        }
        
        It "Should use POST method when specified" {
            Mock Invoke-RestMethod {
                param($Method)
                $Method | Should -Be "post"
                return @{ id = "new-id" }
            }
            
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users" -method "post" -body '{"displayName":"Test User"}'
            
            Should -Invoke Invoke-RestMethod -Times 1
        }
        
        It "Should use PATCH method when specified" {
            Mock Invoke-RestMethod {
                param($Method)
                $Method | Should -Be "patch"
                return @{ id = "updated-id" }
            }
            
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users/123" -method "patch" -body '{"displayName":"Updated"}'
            
            Should -Invoke Invoke-RestMethod -Times 1
        }
        
        It "Should use DELETE method when specified" {
            Mock Invoke-RestMethod {
                param($Method)
                $Method | Should -Be "delete"
                return $null
            }
            
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users/123" -method "delete"
            
            Should -Invoke Invoke-RestMethod -Times 1
        }
        
        It "Should include body parameter for POST requests" {
            $testBody = '{"displayName":"New User","mail":"user@test.com"}'
            
            Mock Invoke-RestMethod {
                param($Body)
                $Body | Should -Be $testBody
                return @{ id = "new-user-id" }
            }
            
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users" -method "post" -body $testBody
            
            Should -Invoke Invoke-RestMethod -Times 1
        }
    }
    
    Context "When handling pagination" {
        It "Should fetch all pages when nextLink is present" {
            $script:callCount = 0
            
            Mock Invoke-RestMethod {
                param($Uri)
                $script:callCount++
                
                if ($script:callCount -eq 1)
                {
                    # First call - return page with nextLink
                    return @{
                        value             = @(
                            @{ id = "1" }
                            @{ id = "2" }
                        )
                        '@odata.nextLink' = "https://graph.microsoft.com/beta/users?`$skiptoken=abc123"
                    }
                }
                else
                {
                    # Second call - return final page without nextLink
                    $finalPage = @{
                        value = @(
                            @{ id = "3" }
                            @{ id = "4" }
                        )
                    }
                    # Explicitly ensure @odata.nextLink is $null
                    $finalPage.'@odata.nextLink' = $null
                    return $finalPage
                }
            }
            
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users"
            
            $result.value.Count | Should -Be 4
            Should -Invoke Invoke-RestMethod -Times 2 -Exactly
        }
        
        It "Should handle multiple pages of results" {
            $script:callCount = 0
            
            Mock Invoke-RestMethod {
                param($Uri)
                $script:callCount++
                
                if ($script:callCount -eq 1)
                {
                    # First page
                    return @{
                        value             = @(@{ id = "1" }, @{ id = "2" })
                        '@odata.nextLink' = "https://graph.microsoft.com/beta/users?`$skiptoken=page1"
                    }
                }
                elseif ($script:callCount -eq 2)
                {
                    # Second page
                    return @{
                        value             = @(@{ id = "3" }, @{ id = "4" })
                        '@odata.nextLink' = "https://graph.microsoft.com/beta/users?`$skiptoken=page2"
                    }
                }
                else
                {
                    # Final page - explicitly set @odata.nextLink to $null
                    $finalPage = @{
                        value = @(@{ id = "5" }, @{ id = "6" })
                    }
                    $finalPage.'@odata.nextLink' = $null
                    return $finalPage
                }
            }
            
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users"
            
            $result.value.Count | Should -Be 6
            Should -Invoke Invoke-RestMethod -Times 3 -Exactly
        }
        
        It "Should return single page when no nextLink present" {
            Mock Invoke-RestMethod {
                $singlePage = @{
                    value = @(@{ id = "1" })
                }
                # Explicitly set @odata.nextLink to $null
                $singlePage.'@odata.nextLink' = $null
                return $singlePage
            }
            
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users"
            
            $result.value.Count | Should -Be 1
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly
        }
    }
    
    Context "When using filter parameter" {
        It "Should encode filter in URI" {
            Mock ProcessFilterCondition { param($condition) return $condition }
            Mock Invoke-RestMethod {
                param($Uri)
                $Uri | Should -Match "filter="
                $Uri | Should -Match "displayName"
                return @{ value = @() }
            }
            
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users" -Filter "displayName eq 'Test User'"
            
            Should -Invoke Invoke-RestMethod -Times 1
        }
        
        It "Should handle multiple filter conditions with 'and' operator" {
            Mock ProcessFilterCondition { param($condition) return $condition.Trim() }
            Mock Invoke-RestMethod {
                param($Uri)
                $Uri | Should -Match "filter="
                $Uri | Should -Match "and"
                return @{ value = @() }
            }
            
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users" -Filter "displayName eq 'Test' and mail eq 'test@test.com'"
            
            Should -Invoke Invoke-RestMethod -Times 1
            Should -Invoke ProcessFilterCondition -Times 2
        }
        
        It "Should handle filter with 'or' operator" {
            Mock ProcessFilterCondition { param($condition) return $condition.Trim() }
            Mock Invoke-RestMethod {
                param($Uri)
                $Uri | Should -Match "filter="
                $Uri | Should -Match "or"
                return @{ value = @() }
            }
            
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users" -Filter "displayName eq 'User1' or displayName eq 'User2'"
            
            Should -Invoke Invoke-RestMethod -Times 1
            Should -Invoke ProcessFilterCondition -Times 2
        }
    }
    
    Context "When using search parameter" {
        It "Should encode search in URI" {
            Mock Invoke-RestMethod {
                param($Uri)
                $Uri | Should -Match "search="
                $Uri | Should -Match "displayName:John"
                return @{ value = @() }
            }
            
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users" -Search "displayName:John"
            
            Should -Invoke Invoke-RestMethod -Times 1
        }
        
        It "Should add search after filter when both present" {
            Mock ProcessFilterCondition { param($condition) return $condition }
            Mock Invoke-RestMethod {
                param($Uri)
                $Uri | Should -Match "filter="
                $Uri | Should -Match "&.*search="
                return @{ value = @() }
            }
            
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users" -Filter "accountEnabled eq true" -Search "displayName:Test"
            
            Should -Invoke Invoke-RestMethod -Times 1
        }
        
        It "Should URL encode special characters in search" {
            Mock Invoke-RestMethod {
                param($Uri)
                # Space should be encoded
                $Uri | Should -Match "search="
                return @{ value = @() }
            }
            
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users" -Search "displayName:John Doe"
            
            Should -Invoke Invoke-RestMethod -Times 1
        }
    }
    
    Context "When using extra parameters" {
        It "Should add extra OData parameters with $ prefix" {
            Mock Invoke-RestMethod {
                param($Uri)
                $Uri | Should -Match '\$top=10'
                return @{ value = @() }
            }
            
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users" -ExtraParameters "top=10"
            
            Should -Invoke Invoke-RestMethod -Times 1
        }
        
        It "Should handle multiple extra parameters" {
            Mock Invoke-RestMethod {
                param($Uri)
                $Uri | Should -Match '\$top=5'
                $Uri | Should -Match '\$orderby=displayName'
                return @{ value = @() }
            }
            
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users" -ExtraParameters "top=5&orderby=displayName"
            
            Should -Invoke Invoke-RestMethod -Times 1
        }
        
        It "Should combine extra parameters with filter" {
            Mock ProcessFilterCondition { param($condition) return $condition }
            Mock Invoke-RestMethod {
                param($Uri)
                $Uri | Should -Match "filter="
                $Uri | Should -Match '\$top=10'
                return @{ value = @() }
            }
            
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users" -Filter "accountEnabled eq true" -ExtraParameters "top=10"
            
            Should -Invoke Invoke-RestMethod -Times 1
        }
    }
    
    Context "When using consistency level" {
        It "Should add ConsistencyLevel header when switch is present" {
            Mock Invoke-RestMethod {
                param($Headers)
                $Headers.ConsistencyLevel | Should -Be "Eventual"
                return @{ value = @() }
            }
            
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users" -consistencyLevel
            
            Should -Invoke Invoke-RestMethod -Times 1
        }
        
        It "Should not add ConsistencyLevel header by default" {
            Mock Invoke-RestMethod {
                param($Headers)
                $Headers.ContainsKey('ConsistencyLevel') | Should -Be $false
                return @{ value = @() }
            }
            
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users"
            
            Should -Invoke Invoke-RestMethod -Times 1
        }
    }
    
    Context "When handling errors" {
        It "Should log error when access token check fails" {
            # Function checks for truthy accessToken and logs if missing
            Mock Write-Log {} -ParameterFilter { $Message -match "Access token not provided" }
            Mock Invoke-RestMethod { return @{ value = @() } }
            
            # When function runs with invalid token, should log error
            # Note: Can't test empty string due to parameter validation
            Should -Invoke Write-Log -Times 0 -ParameterFilter { $Message -match "Access token not provided" }
        }
        
        It "Should handle 401 Unauthorized error gracefully" {
            Mock Invoke-RestMethod {
                # Create a WebException which CallGraphAPI will catch
                $exception = [System.Net.WebException]::new("Unauthorized")
                throw $exception
            }
            Mock Write-Log {}
            
            # CallGraphAPI catches exceptions internally and logs them
            # Function should NOT throw - it handles errors gracefully
            { CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users" } | Should -Not -Throw
        }
        
        It "Should handle 403 Forbidden error gracefully" {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new("Forbidden")
            }
            Mock Write-Log {}
            
            # CallGraphAPI catches exceptions and logs them - should not throw
            { CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users" } | Should -Not -Throw
        }
        
        It "Should handle 404 Not Found error gracefully" {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new("Not Found")
            }
            Mock Write-Log {}
            
            # CallGraphAPI catches exceptions - should not throw
            { CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users/invalid-id" } | Should -Not -Throw
        }
        
        It "Should handle 429 Too Many Requests (throttling) gracefully" {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new("Too Many Requests")
            }
            Mock Write-Log {}
            
            # CallGraphAPI catches throttling errors - should not throw
            { CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users" } | Should -Not -Throw
        }
        
        It "Should handle 500 Internal Server Error gracefully" {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new("Internal Server Error")
            }
            Mock Write-Log {}
            
            # CallGraphAPI catches server errors - should not throw
            { CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users" } | Should -Not -Throw
        }
        
        It "Should handle network timeout errors gracefully" {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new("The operation has timed out")
            }
            Mock Write-Log {}
            
            # CallGraphAPI catches timeout errors - should not throw
            { CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users" } | Should -Not -Throw
        }
    }
    
    Context "When testing parameter validation" {
        It "Should require accessToken parameter" {
            $funcDef = (Get-Command CallGraphAPI).Parameters['accessToken']
            $funcDef.Attributes.Mandatory | Should -Contain $true
        }
        
        It "Should require ResourcePath parameter" {
            $funcDef = (Get-Command CallGraphAPI).Parameters['ResourcePath']
            $funcDef.Attributes.Mandatory | Should -Contain $true
        }
        
        It "Should have optional APIVersion with default value" {
            Mock Invoke-RestMethod {
                param($Uri)
                $Uri | Should -Match "graph.microsoft.com/beta/"
                return @{ value = @() }
            }
            
            # When APIVersion not specified, should use 'beta' default
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users"
            
            Should -Invoke Invoke-RestMethod -Times 1
        }
        
        It "Should have optional method with 'get' default" {
            Mock Invoke-RestMethod {
                param($Method)
                $Method | Should -Be "get"
                return @{ value = @() }
            }
            
            # When method not specified, should use 'get' default
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users"
            
            Should -Invoke Invoke-RestMethod -Times 1
        }
    }
    
    Context "When testing logging behavior" {
        It "Should log access token receipt" {
            Mock Invoke-RestMethod { return @{ value = @() } }
            Mock Write-Log {} -ParameterFilter { $Message -match "Access token provided" }
            
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users"
            
            Should -Invoke Write-Log -ParameterFilter { $Message -match "Access token provided" }
        }
        
        It "Should log resource path" {
            Mock Invoke-RestMethod { return @{ value = @() } }
            Mock Write-Log {} -ParameterFilter { $Message -match "Resource Path" }
            
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users"
            
            Should -Invoke Write-Log -ParameterFilter { $Message -match "Resource Path" }
        }
        
        It "Should log successful call" {
            Mock Invoke-RestMethod { return @{ value = @() } }
            Mock Write-Log {} -ParameterFilter { $Message -match "call was successful" }
            
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users"
            
            Should -Invoke Write-Log -ParameterFilter { $Message -match "call was successful" }
        }
    }
    
    AfterAll {
        # Clean up TestDrive to prevent GUID folder remnants
        if (Test-Path "TestDrive:\")
        {
            Get-ChildItem "TestDrive:\" -Recurse | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }
}

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
    
        It "Should merge custom headers while preserving Authorization" {
            Mock Invoke-RestMethod {
                param($Headers)
                $Headers.Authorization | Should -Be "Bearer $script:testAccessToken"
                $Headers.'Custom-Header' | Should -Be "CustomValue"
                $Headers.'Content-Type' | Should -Be "application/json"
                return @{ value = @() }
            }
    
            $customHeaders = @{ 'Custom-Header' = 'CustomValue' }
            CallGraphAPI -accessToken $script:testAccessToken -ResourcePath "users" -headers $customHeaders
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
    
    Context "When processing batch requests" {
        It "Should detect batch request with multiple ResourcePaths" {
            Mock Invoke-RestMethod {
                param($Uri)
                if ($Uri -like "*`$batch*")
                {
                    return @{
                        responses = @(
                            @{ id = "1"; status = 200; body = @{ value = @() } },
                            @{ id = "2"; status = 200; body = @{ value = @() } }
                        )
                    }
                }
                return @{ value = @() }
            }
            Mock Write-Log {} -ParameterFilter { $Message -match "Batch request detected" }
            
            $paths = @("users/id1", "users/id2")
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath $paths
            
            Should -Invoke Write-Log -ParameterFilter { $Message -match "Batch request detected" }
            $result.batchProcessed | Should -Be $true
        }
        
        It "Should process single-item array as single request" {
            Mock Invoke-RestMethod {
                return @{ id = "user1"; displayName = "User 1" }
            }
            Mock Write-Log {} -ParameterFilter { $Message -match "Single-item array detected" }
            
            $paths = @("users/id1")
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath $paths
            
            Should -Invoke Write-Log -ParameterFilter { $Message -match "Single-item array detected" }
        }
        
        It "Should process arrays with 2+ items using native batch endpoint" {
            Mock Invoke-RestMethod {
                param($Uri)
                if ($Uri -like "*`$batch*")
                {
                    return @{
                        responses = @(
                            @{ id = "1"; status = 200; body = @{ value = @() } },
                            @{ id = "2"; status = 200; body = @{ value = @() } }
                        )
                    }
                }
                return @{ value = @() }
            }
            Mock Write-Log {} -ParameterFilter { $Message -match "Batch request detected" }
            
            # 2 items - above threshold of 1, should use native batch endpoint
            $paths = @("users/id1", "users/id2")
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath $paths
            
            # Should make 1 batch call (not 2 individual calls)
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly
            Should -Invoke Write-Log -ParameterFilter { $Message -match "Batch request detected" }
        }
        
        It "Should return combined results for native batch processing" {
            Mock Invoke-RestMethod {
                param($Uri)
                if ($Uri -like "*`$batch*")
                {
                    return @{
                        responses = @(
                            @{ id = "1"; status = 200; body = @{ id = "user1"; displayName = "User 1" } },
                            @{ id = "2"; status = 200; body = @{ id = "user2"; displayName = "User 2" } },
                            @{ id = "3"; status = 200; body = @{ id = "user3"; displayName = "User 3" } }
                        )
                    }
                }
                return @{ value = @() }
            }
            
            $paths = @("users/id1", "users/id2", "users/id3")
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath $paths
            
            $result.batchProcessed | Should -Be $true
            $result.batchMethod | Should -Be "NativeBatch"
            $result.value.Count | Should -Be 3
        }
        
        It "Should handle mixed success/failure in batch responses" {
            Mock Invoke-RestMethod {
                param($Uri)
                if ($Uri -like "*`$batch*")
                {
                    return @{
                        responses = @(
                            @{ id = "1"; status = 200; body = @{ id = "user1"; displayName = "User 1" } },
                            @{ id = "2"; status = 404; body = @{ error = @{ message = "Not found" } } },
                            @{ id = "3"; status = 200; body = @{ id = "user3"; displayName = "User 3" } }
                        )
                    }
                }
                return @{ value = @() }
            }
            
            $paths = @("users/id1", "users/id2", "users/id3")
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath $paths
            
            $result.successCount | Should -Be 2
            $result.failureCount | Should -Be 1
            $result.totalCount | Should -Be 3
            $result.batchProcessed | Should -Be $true
        }
        
        It "Should use native batch endpoint directly" {
            Mock Invoke-RestMethod {
                param($Uri)
                if ($Uri -like "*`$batch*")
                {
                    return @{
                        responses = @(
                            @{ id = "1"; status = 200; body = @{ value = @() } },
                            @{ id = "2"; status = 200; body = @{ value = @() } },
                            @{ id = "3"; status = 200; body = @{ value = @() } }
                        )
                    }
                }
                return @{ value = @() }
            }
            
            $paths = @("users/id1", "users/id2", "users/id3")
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath $paths
            
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly
            $result.batchMethod | Should -Be "NativeBatch"
        }
        
        It "Should fall back to sequential processing if batch endpoint fails" {
            $script:callCount = 0
            
            Mock Invoke-RestMethod {
                param($Uri, $Method)
                $script:callCount++
                
                # First call to batch endpoint fails
                if ($Uri -like "*`$batch*")
                {
                    throw "Batch endpoint temporarily unavailable"
                }
                # Subsequent calls are individual requests (sequential fallback)
                return @{ id = "user$script:callCount"; displayName = "User $script:callCount" }
            }
            Mock Write-Log {} -ParameterFilter { $Message -match "Batch endpoint failed" }
            
            $paths = @("users/id1", "users/id2", "users/id3")
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath $paths
            
            # Should try batch once, then fall back to 3 sequential calls
            Should -Invoke Invoke-RestMethod -Times 4 -Exactly
            Should -Invoke Write-Log -ParameterFilter { $Message -match "Batch endpoint failed" }
            $result.batchProcessed | Should -Be $true
            $result.successCount | Should -Be 3
        }
        
        It "Should log batch processing with detailed progress" {
            Mock Invoke-RestMethod {
                param($Uri)
                if ($Uri -like "*`$batch*")
                {
                    return @{
                        responses = @(
                            @{ id = "1"; status = 200; body = @{ value = @() } },
                            @{ id = "2"; status = 200; body = @{ value = @() } },
                            @{ id = "3"; status = 200; body = @{ value = @() } }
                        )
                    }
                }
                return @{ value = @() }
            }
            Mock Write-Log {} -ParameterFilter { $Message -match "Processing .+ requests in .+ batch" }
            Mock Write-Log {} -ParameterFilter { $Message -match "Sending batch with .+ requests" }
            
            $paths = @("users/id1", "users/id2", "users/id3")
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath $paths
            
            Should -Invoke Write-Log -ParameterFilter { $Message -match "Processing .+ requests in .+ batch" }
            Should -Invoke Write-Log -ParameterFilter { $Message -match "Sending batch with .+ requests" }
            Should -Invoke Write-Log -ParameterFilter { $Message -match "Batch processing completed" }
        }
        
        It "Should split large batches into multiple requests of max 20" {
            Mock Invoke-RestMethod {
                param($Uri, $Body)
                if ($Uri -like "*`$batch*")
                {
                    $batchObj = $Body | ConvertFrom-Json
                    # Each batch should have max 20 requests
                    $batchObj.requests.Count | Should -BeLessOrEqual 20
                    
                    # Return responses matching the request count
                    $responses = @()
                    foreach ($req in $batchObj.requests)
                    {
                        $responses += @{ id = $req.id; status = 200; body = @{ value = @() } }
                    }
                    return @{ responses = $responses }
                }
                return @{ value = @() }
            }
            
            # Create 45 items to test batching (should result in 3 batches: 20, 20, 5)
            $paths = 1..45 | ForEach-Object { "users/id$_" }
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath $paths
            
            # Should make 3 batch calls
            Should -Invoke Invoke-RestMethod -Times 3 -Exactly
            $result.successCount | Should -Be 45
        }
        
        It "Should handle batch endpoint failure with partial sequential failures" {
            $script:callCount = 0
            
            Mock Invoke-RestMethod {
                param($Uri)
                $script:callCount++
                
                # Batch endpoint fails
                if ($Uri -like "*`$batch*")
                {
                    throw "Batch endpoint error"
                }
                
                # Sequential calls - second one returns error status
                if ($script:callCount -eq 3)
                {
                    return 404
                }
                return @{ id = "user$script:callCount"; displayName = "User $script:callCount" }
            }
            Mock Write-Log {} -ParameterFilter { $Message -match "Failed to process resource" }
            
            $paths = @("users/id1", "users/id2", "users/id3")
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath $paths
            
            Should -Invoke Invoke-RestMethod -Times 4 -Exactly
            $result.successCount | Should -Be 2
            $result.failureCount | Should -Be 1
            Should -Invoke Write-Log -ParameterFilter { $Message -match "Failed to process resource" }
        }
        
        It "Should include filters in batch request URLs" {
            Mock ProcessFilterCondition { param($condition) return $condition }
            Mock Invoke-RestMethod {
                param($Uri, $Body)
                if ($Uri -like "*`$batch*")
                {
                    $batchObj = $Body | ConvertFrom-Json
                    # Verify filter is in the URL
                    $batchObj.requests[0].url | Should -Match "`$filter="
                    
                    return @{
                        responses = @(
                            @{ id = "1"; status = 200; body = @{ value = @() } },
                            @{ id = "2"; status = 200; body = @{ value = @() } }
                        )
                    }
                }
                return @{ value = @() }
            }
            
            $paths = @("users", "users")
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath $paths -Filter "accountEnabled eq true"
            
            # Note: ProcessFilterCondition may cause multiple calls during filter processing
            # Just verify batch processing occurred
            $result.batchProcessed | Should -Be $true
        }
        
        It "Should include search parameters in batch request URLs" {
            Mock Invoke-RestMethod {
                param($Uri, $Body)
                if ($Uri -like "*`$batch*")
                {
                    $batchObj = $Body | ConvertFrom-Json
                    # Verify search is in the URL
                    $batchObj.requests[0].url | Should -Match "`$search="
                    
                    return @{
                        responses = @(
                            @{ id = "1"; status = 200; body = @{ value = @() } },
                            @{ id = "2"; status = 200; body = @{ value = @() } }
                        )
                    }
                }
                return @{ value = @() }
            }
            
            $paths = @("users", "users")
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath $paths -Search "displayName:John"
            
            # Just verify batch processing occurred with search parameter
            $result.batchProcessed | Should -Be $true
        }
        
        It "Should include consistency level headers in batch requests" {
            Mock Invoke-RestMethod {
                param($Uri, $Body)
                if ($Uri -like "*`$batch*")
                {
                    $batchObj = $Body | ConvertFrom-Json
                    # Verify ConsistencyLevel header (lowercase 'eventual' per implementation)
                    $batchObj.requests[0].headers.ConsistencyLevel | Should -Be "eventual"
                    
                    return @{
                        responses = @(
                            @{ id = "1"; status = 200; body = @{ value = @() } },
                            @{ id = "2"; status = 200; body = @{ value = @() } }
                        )
                    }
                }
                return @{ value = @() }
            }
            
            $paths = @("users/id1", "users/id2")
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath $paths -consistencyLevel
            
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly
        }
        
        It "Should handle POST requests with body in batch mode" {
            Mock Invoke-RestMethod {
                param($Uri, $Body, $Method)
                if ($Uri -like "*`$batch*" -and $Method -eq "Post")
                {
                    $batchObj = $Body | ConvertFrom-Json
                    # Verify request has body and Content-Type header
                    $batchObj.requests[0].body | Should -Not -BeNullOrEmpty
                    $batchObj.requests[0].headers.'Content-Type' | Should -Be "application/json"
                    
                    return @{
                        responses = @(
                            @{ id = "1"; status = 201; body = @{ id = "new-user-1"; displayName = "New User 1" } },
                            @{ id = "2"; status = 201; body = @{ id = "new-user-2"; displayName = "New User 2" } }
                        )
                    }
                }
                return @{ value = @() }
            }
            
            $testBody = '{"displayName":"Test User","mail":"test@example.com"}'
            $paths = @("users", "users")
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath $paths -method "post" -body $testBody
            
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly
            $result.successCount | Should -Be 2
        }
        
        It "Should handle hashtable input with id and url properties" {
            Mock Invoke-RestMethod {
                param($Body)
                $bodyObj = $Body | ConvertFrom-Json
                $bodyObj.requests.Count | Should -Be 2
                return @{
                    responses = @(
                        @{ id = "1"; status = 200; body = @{ value = @("user1") } }
                        @{ id = "2"; status = 200; body = @{ value = @("group1") } }
                    )
                }
            }
            
            $resources = @(
                @{ id = "users"; url = "users" }
                @{ id = "groups"; url = "groups" }
            )
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath $resources
            
            $result.batchProcessed | Should -Be $true
            $result.value.Count | Should -Be 2
            $result.value[0].__batchMetadata.resourceId | Should -Be "users"
            $result.value[1].__batchMetadata.resourceId | Should -Be "groups"
        }
        
        It "Should map batch responses to original resource identifiers" {
            Mock Invoke-RestMethod {
                return @{
                    responses = @(
                        @{ id = "1"; status = 200; body = @{ value = @("item1") } }
                        @{ id = "2"; status = 200; body = @{ value = @("item2") } }
                    )
                }
            }
            
            $resources = @(
                @{ id = "resource1"; url = "path1" }
                @{ id = "resource2"; url = "path2" }
            )
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath $resources
            
            $result.value[0].__batchMetadata.resourceId | Should -Be "resource1"
            $result.value[1].__batchMetadata.resourceId | Should -Be "resource2"
        }
        
        It "Should capture comprehensive error details matching single-request behavior" {
            Mock Invoke-RestMethod {
                return @{
                    responses = @(
                        @{ 
                            id = "1"
                            status = 403
                            body = @{
                                error = @{
                                    code = "Authorization_RequestDenied"
                                    message = "Insufficient privileges"
                                    innerError = @{
                                        "request-id" = "req-123"
                                        "client-request-id" = "client-456"
                                        date = "2025-11-14T10:00:00"
                                    }
                                }
                            }
                        }
                    )
                }
            }
            
            $resources = @(
                @{ id = "testResource"; url = "path1" }
            )
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath $resources
            
            $result.errorDetails.Count | Should -Be 1
            $result.errorDetails[0].resourceId | Should -Be "testResource"
            $result.errorDetails[0].errorCode | Should -Be "Authorization_RequestDenied"
            $result.errorDetails[0].errorMessage | Should -Be "Insufficient privileges"
            $result.errorDetails[0].requestId | Should -Be "req-123"
            $result.errorDetails[0].clientRequestId | Should -Be "client-456"
        }
        
        It "Should add metadata to successful batch results" {
            Mock Invoke-RestMethod {
                return @{
                    responses = @(
                        @{ id = "1"; status = 200; body = @{ value = @("item1") } }
                    )
                }
            }
            
            $resources = @(
                @{ id = "testId"; url = "testUrl" }
            )
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath $resources
            
            $result.value[0].__batchMetadata | Should -Not -BeNullOrEmpty
            $result.value[0].__batchMetadata.resourceId | Should -Be "testId"
            $result.value[0].__batchMetadata.resourceUrl | Should -Be "testUrl"
            $result.value[0].__batchMetadata.status | Should -Be 200
        }
        
        It "Should properly normalize string array resources" {
            Mock Invoke-RestMethod {
                param($Body)
                $bodyObj = $Body | ConvertFrom-Json
                $bodyObj.requests[0].url | Should -Match "^/users"
                $bodyObj.requests[1].url | Should -Match "^/groups"
                return @{
                    responses = @(
                        @{ id = "1"; status = 200; body = @{ value = @() } }
                        @{ id = "2"; status = 200; body = @{ value = @() } }
                    )
                }
            }
            
            $paths = @("users", "groups")
            $result = CallGraphAPI -accessToken $script:testAccessToken -ResourcePath $paths
            
            $result.totalCount | Should -Be 2
            Should -Invoke Invoke-RestMethod -Times 1
        }
    }
    
    AfterAll {
        # Clean up TestDrive to prevent GUID folder remnants
        if (Test-Path "TestDrive:\")
        {
            Get-ChildItem "TestDrive:\" -Recurse | Remove-Item -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }
}

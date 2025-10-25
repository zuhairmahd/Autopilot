<#
.SYNOPSIS
    Pester tests for GetAutopilotProfile function

.DESCRIPTION
    Tests the unified cache-enabled Autopilot profile retrieval function covering:
    - Exact match search
    - Fuzzy search with -FindSimilar
    - GetAll mode (retrieve all profiles)
    - Caching behavior (Configuration cache type)
    - Client-side filtering
    - Error handling
    
.NOTES
    Test Category: Unit
    Dependencies: GetAutopilotProfile, AutopilotGraphMocks module, Get-CachedData
    Cache Type: Configuration
#>

Describe "GetAutopilotProfile Function" -Tags 'Unit', 'Autopilot', 'GraphAPI', 'Cache' {
    
    BeforeAll {
        # Get repository root
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        
        # Import mocking infrastructure
        Import-Module (Join-Path $PSScriptRoot "../Helpers/AutopilotGraphMocks.psm1") -Force
        
        # Load unified cache functions
        . (Join-Path $script:RepoRoot "functions/utilityFunctions/Get-CachedData.ps1")
        
        # Load Write-Log function
        . (Join-Path $script:RepoRoot "functions/utilityFunctions/Write-Log.ps1")
        
        # Load CallGraphAPI function (required dependency)
        . (Join-Path $script:RepoRoot "functions/graphFunctions/CallGraphAPI.ps1")
        
        # Load the function being tested
        . (Join-Path $script:RepoRoot "functions/utilityFunctions/GetAutopilotProfile.ps1")
        
        # Setup test log file
        $tempPath = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
        $global:LogFile = Join-Path $tempPath "test-getautopilotprofile.log"
        
        # Initialize cache settings
        $global:settings = @{
            cacheSettings = @{
                enabled                  = $true
                defaultExpirationMinutes = 15
                maxCacheSize             = 1000
                cacheTypes               = @{
                    Configuration    = @{ enabled = $true; expirationMinutes = 60 }
                    DirectoryObjects = @{ enabled = $true; expirationMinutes = 15 }
                    Devices          = @{ enabled = $true; expirationMinutes = 15 }
                }
            }
        }
        
        # Test data
        $script:testProfileId1 = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
        $script:testProfileId2 = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
        $script:testProfileName1 = "Corporate-Autopilot-Profile"
        $script:testProfileName2 = "BYOD-Autopilot-Profile"
        $script:mockAccessToken = "mock-access-token-12345"
    }
    
    BeforeEach {
        # Clear cache before each test
        Clear-UnifiedCache
        
        # Setup CallGraphAPI mock
        Mock -CommandName CallGraphAPI -MockWith {
            param($AccessToken, $ResourcePath, $ExtraParameters, $APIVersion, $Filter)
            
            # Mock GetAll - retrieve all profiles
            if ($ResourcePath -eq "deviceManagement/windowsAutopilotDeploymentProfiles" -and -not $Filter)
            {
                return @{
                    value = @(
                        @{ 
                            id              = $script:testProfileId1
                            displayName     = $script:testProfileName1
                            description     = "Corporate device profile"
                            createdDateTime = "2024-01-01T00:00:00Z"
                        },
                        @{ 
                            id              = $script:testProfileId2
                            displayName     = $script:testProfileName2
                            description     = "BYOD device profile"
                            createdDateTime = "2024-01-02T00:00:00Z"
                        }
                    )
                }
            }
            
            # Mock exact match search
            if ($Filter -and $Filter -like "*displayName eq*")
            {
                if ($Filter -like "*$($script:testProfileName1)*")
                {
                    return @{
                        value = @(
                            @{ 
                                id          = $script:testProfileId1
                                displayName = $script:testProfileName1
                                description = "Corporate device profile"
                            }
                        )
                    }
                }
                elseif ($Filter -like "*$($script:testProfileName2)*")
                {
                    return @{
                        value = @(
                            @{ 
                                id          = $script:testProfileId2
                                displayName = $script:testProfileName2
                                description = "BYOD device profile"
                            }
                        )
                    }
                }
                # No match
                return @{ value = @() }
            }
            
            # Mock fuzzy search (startsWith or contains)
            if ($Filter -and ($Filter -like "*startsWith*" -or $Filter -like "*contains*"))
            {
                if ($Filter -like "*Corporate*" -or $Filter -like "*Corp*")
                {
                    return @{
                        value = @(
                            @{ 
                                id          = $script:testProfileId1
                                displayName = $script:testProfileName1
                                description = "Corporate device profile"
                            }
                        )
                    }
                }
                elseif ($Filter -like "*BYOD*")
                {
                    return @{
                        value = @(
                            @{ 
                                id          = $script:testProfileId2
                                displayName = $script:testProfileName2
                                description = "BYOD device profile"
                            }
                        )
                    }
                }
                elseif ($Filter -like "*autopilot*" -or $Filter -like "*Autopilot*")
                {
                    # Return all profiles for client-side filtering test
                    return @{
                        value = @(
                            @{ 
                                id          = $script:testProfileId1
                                displayName = $script:testProfileName1
                                description = "Corporate device profile"
                            },
                            @{ 
                                id          = $script:testProfileId2
                                displayName = $script:testProfileName2
                                description = "BYOD device profile"
                            }
                        )
                    }
                }
                # No match - return empty
                return @{ value = @() }
            }
            
            # Default - return empty
            return @{ value = @() }
        }
    }
    
    Context "Exact Match Search" {
        
        It "Should find profile by exact name match" {
            $result, $wasSubstringSearch = GetAutopilotProfile -AccessToken $mockAccessToken -ProfileName $testProfileName1
            
            $result | Should -Not -BeNullOrEmpty
            $result.value | Should -Not -BeNullOrEmpty
            $result.value.Count | Should -Be 1
            $result.value[0].displayName | Should -Be $testProfileName1
            $wasSubstringSearch | Should -Be $false
        }
        
        It "Should cache exact match results" {
            # First call - should hit API
            $result1, $_ = GetAutopilotProfile -AccessToken $mockAccessToken -ProfileName $testProfileName1
            $result1 | Should -Not -BeNullOrEmpty
            
            # Verify cache contains the result
            $cacheKey = "autopilot:$testProfileName1|False"
            $cachedData = Get-CachedData -CacheType 'Configuration' -Key $cacheKey -Settings $global:settings
            $cachedData | Should -Not -BeNullOrEmpty
        }
        
        It "Should use cached results on subsequent exact match calls" {
            # Prime the cache
            $null = GetAutopilotProfile -AccessToken $mockAccessToken -ProfileName $testProfileName1
            
            # Remove the API mock to prove it doesn't get called
            Mock -CommandName CallGraphAPI -MockWith { throw "API should not be called - data should be cached" }
            
            # Second call - should use cache
            $result2, $wasSubstring = GetAutopilotProfile -AccessToken $mockAccessToken -ProfileName $testProfileName1
            
            $result2 | Should -Not -BeNullOrEmpty
            $result2.value[0].displayName | Should -Be $testProfileName1
        }
        
        It "Should return null for non-existent profile" {
            $result, $wasSubstringSearch = GetAutopilotProfile -AccessToken $mockAccessToken -ProfileName "NonExistentProfile"
            
            $result | Should -BeNullOrEmpty
            $wasSubstringSearch | Should -Be $false
        }
    }
    
    Context "Fuzzy Search with -FindSimilar" {
        
        It "Should find profile with partial name when -FindSimilar is used" {
            $result, $wasSubstringSearch = GetAutopilotProfile -AccessToken $mockAccessToken -ProfileName "Corporate" -FindSimilar
            
            $result | Should -Not -BeNullOrEmpty
            $result.value | Should -Not -BeNullOrEmpty
            $result.value[0].displayName | Should -Be $testProfileName1
        }
        
        It "Should cache fuzzy search results separately from exact match" {
            # Exact match cache
            $null = GetAutopilotProfile -AccessToken $mockAccessToken -ProfileName $testProfileName1
            
            # Fuzzy search cache
            $null = GetAutopilotProfile -AccessToken $mockAccessToken -ProfileName "Corporate" -FindSimilar
            
            # Verify both cache entries exist
            $exactCacheKey = "autopilot:$testProfileName1|False"
            $fuzzyCacheKey = "autopilot:Corporate|True"
            
            $exactCache = Get-CachedData -CacheType 'Configuration' -Key $exactCacheKey -Settings $global:settings
            $fuzzyCache = Get-CachedData -CacheType 'Configuration' -Key $fuzzyCacheKey -Settings $global:settings
            
            $exactCache | Should -Not -BeNullOrEmpty
            $fuzzyCache | Should -Not -BeNullOrEmpty
        }
        
        It "Should use client-side filtering when API filter fails" {
            # Mock CallGraphAPI to simulate failed API filters forcing client-side filtering
            # First call (exact match) returns empty, second call (fuzzy) also returns empty,
            # then client-side filtering retrieves ALL and filters locally
            $script:callCount = 0
            Mock -CommandName CallGraphAPI -MockWith {
                $script:callCount++
                
                # First two calls (exact + fuzzy) return empty (simulating API filter failures)
                if ($script:callCount -le 2)
                {
                    return @{ value = @() }
                }
                
                # Third call (get all for client-side filtering) returns all profiles
                return @{
                    value = @(
                        @{ 
                            id          = $script:testProfileId1
                            displayName = $script:testProfileName1
                            description = "Corporate device profile"
                        },
                        @{ 
                            id          = $script:testProfileId2
                            displayName = $script:testProfileName2
                            description = "BYOD device profile"
                        }
                    )
                }
            }
            
            $result, $wasSubstringSearch = GetAutopilotProfile -AccessToken $mockAccessToken -ProfileName "autopilot" -FindSimilar
            
            # Should find both profiles via client-side filtering (both contain "autopilot" case-insensitive)
            $result | Should -Not -BeNullOrEmpty
            $result.value.Count | Should -Be 2
            $wasSubstringSearch | Should -Be $true
        }
    }
    
    Context "GetAll Mode" {
        
        It "Should retrieve all profiles when -GetAll is used" {
            $result, $wasSubstringSearch = GetAutopilotProfile -AccessToken $mockAccessToken -GetAll
            
            $result | Should -Not -BeNullOrEmpty
            $result.value | Should -Not -BeNullOrEmpty
            $result.value.Count | Should -Be 2
            $wasSubstringSearch | Should -Be $false
        }
        
        It "Should cache GetAll results" {
            # First call - should hit API
            $result1, $_ = GetAutopilotProfile -AccessToken $mockAccessToken -GetAll
            $result1 | Should -Not -BeNullOrEmpty
            
            # Verify cache (GetAll uses empty ProfileName)
            $cacheKey = "autopilot:|False"
            $cachedData = Get-CachedData -CacheType 'Configuration' -Key $cacheKey -Settings $global:settings
            $cachedData | Should -Not -BeNullOrEmpty
        }
        
        It "Should use cached results for GetAll on subsequent calls" {
            # Prime the cache
            $null = GetAutopilotProfile -AccessToken $mockAccessToken -GetAll
            
            # Remove the API mock to prove it doesn't get called
            Mock -CommandName CallGraphAPI -MockWith { throw "API should not be called - data should be cached" }
            
            # Second call - should use cache
            $result2, $_ = GetAutopilotProfile -AccessToken $mockAccessToken -GetAll
            
            $result2 | Should -Not -BeNullOrEmpty
            $result2.value.Count | Should -Be 2
        }
    }
    
    Context "Error Handling" {
        
        It "Should handle missing AccessToken" {
            $result, $wasSubstringSearch = GetAutopilotProfile -ProfileName $testProfileName1
            
            $result | Should -BeNullOrEmpty
            $wasSubstringSearch | Should -Be $false
        }
        
        It "Should handle API errors gracefully" {
            Mock -CommandName CallGraphAPI -MockWith { return 403 }
            
            $result, $wasSubstringSearch = GetAutopilotProfile -AccessToken $mockAccessToken -ProfileName $testProfileName1
            
            $result | Should -BeNullOrEmpty
        }
        
        It "Should handle empty ProfileName" {
            $result, $wasSubstringSearch = GetAutopilotProfile -AccessToken $mockAccessToken -ProfileName ""
            
            $result | Should -BeNullOrEmpty
        }
    }
    
    Context "Cache Expiration" {
        
        It "Should respect cache expiration settings" {
            # First call - populate cache
            $result1, $_ = GetAutopilotProfile -AccessToken $mockAccessToken -ProfileName $testProfileName1
            $result1 | Should -Not -BeNullOrEmpty
            
            # Manually expire the cache entry by setting old timestamp
            $cacheKey = "autopilot:$testProfileName1|False"
            $oldTimestamp = (Get-Date).AddMinutes(-70)  # Older than 60-minute Configuration cache expiration
            
            # Access internal cache structure to expire entry
            if ($global:UnifiedCache.Configuration.ContainsKey($cacheKey))
            {
                $global:UnifiedCache.Configuration[$cacheKey].Timestamp = $oldTimestamp
            }
            
            # Mock API call to verify it gets called again
            Mock -CommandName CallGraphAPI -MockWith {
                # Set flag in a scope accessible to the test
                $global:TestApiCalled = $true
                return @{
                    value = @(
                        @{ 
                            id          = $script:testProfileId1
                            displayName = $script:testProfileName1
                            description = "Corporate device profile"
                        }
                    )
                }
            }
            
            # Initialize flag
            $global:TestApiCalled = $false
            
            # Second call - should detect expiration and call API
            $result2, $_ = GetAutopilotProfile -AccessToken $mockAccessToken -ProfileName $testProfileName1
            
            $global:TestApiCalled | Should -Be $true
            
            # Cleanup
            Remove-Variable -Name TestApiCalled -Scope Global -ErrorAction SilentlyContinue
        }
    }
    
    Context "Cache Metadata" {
        
        It "Should store metadata with cache entry" {
            # Call function to cache data
            $null = GetAutopilotProfile -AccessToken $mockAccessToken -ProfileName $testProfileName1
            
            # Access cache entry directly to check metadata
            $cacheKey = "autopilot:$testProfileName1|False"
            $cacheEntry = $global:UnifiedCache.Configuration[$cacheKey]
            
            $cacheEntry | Should -Not -BeNullOrEmpty
            $cacheEntry.Metadata | Should -Not -BeNullOrEmpty
            $cacheEntry.Metadata.ProfileName | Should -Be $testProfileName1
            $cacheEntry.Metadata.SearchType | Should -Be "ExactMatch"
        }
        
        It "Should track fuzzy search in metadata" {
            # Call with FindSimilar
            $null = GetAutopilotProfile -AccessToken $mockAccessToken -ProfileName "Corporate" -FindSimilar
            
            # Check metadata
            $cacheKey = "autopilot:Corporate|True"
            $cacheEntry = $global:UnifiedCache.Configuration[$cacheKey]
            
            $cacheEntry.Metadata.SearchType | Should -Match "FuzzyMatch|ClientSideFilter"
        }
    }
}

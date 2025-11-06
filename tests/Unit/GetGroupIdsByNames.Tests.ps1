<#
.SYNOPSIS
    Pester tests for GetGroupIdsByNames function

.DESCRIPTION
    Tests the unified cache-enabled group ID/name bidirectional mapping function covering:
    - Name to ID resolution
    - ID to Name resolution
    - Caching behavior (DirectoryObjects cache type)
    - Batch processing
    - Error handling
    
.NOTES
    Test Category: Unit
    Dependencies: GetGroupIdsByNames, AutopilotGraphMocks module, Get-CachedData
    Cache Type: DirectoryObjects
#>

Describe "GetGroupIdsByNames Function" -Tags 'Unit', 'DirectoryObject', 'GraphAPI', 'Cache' {
    
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
        . (Join-Path $script:RepoRoot "functions/UserAndGroupFunctions/GetGroupIdsByNames.ps1")
        
        # Setup test log file
        $tempPath = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
        $global:LogFile = Join-Path $tempPath "test-getgroupidsbynames.log"
        
        # Set maxJsonDepth variable required by the function
        $global:maxJsonDepth = 10
        
        # Initialize cache settings
        $global:cacheSettings = @{
            enabled                  = $true
            defaultExpirationMinutes = 15
            maxCacheSize             = 1000
            cacheTypes               = @{
                Configuration    = @{ enabled = $true; expirationMinutes = 60 }
                DirectoryObjects = @{ enabled = $true; expirationMinutes = 15 }
                Devices          = @{ enabled = $true; expirationMinutes = 15 }
            }
        }
        
        # Test data
        $script:testGroupId1 = "11111111-1111-1111-1111-111111111111"
        $script:testGroupId2 = "22222222-2222-2222-2222-222222222222"
        $script:testGroupName1 = "Test-Group-One"
        $script:testGroupName2 = "Test-Group-Two"
        $script:mockAccessToken = "mock-access-token-12345"
    }
    
    BeforeEach {
        # Clear cache before each test
        Clear-UnifiedCache
        
        # Setup CallGraphAPI mocks
        Mock -CommandName CallGraphAPI -MockWith {
            param($accessToken, $ResourcePath, $Filter, $ExtraParameters, $APIVersion, $method, $consistencyLevel)
            
            # Mock group search by filter
            if ($ResourcePath -eq "groups" -and $Filter)
            {
                $results = @()
                
                # Parse all display names from filter (handles OR conditions)
                $displayNameMatches = [regex]::Matches($Filter, "displayName eq '([^']+)'")
                foreach ($match in $displayNameMatches)
                {
                    $groupName = $match.Groups[1].Value
                    if ($groupName -eq $script:testGroupName1)
                    {
                        $results += @{ id = $script:testGroupId1; displayName = $script:testGroupName1 }
                    }
                    elseif ($groupName -eq $script:testGroupName2)
                    {
                        $results += @{ id = $script:testGroupId2; displayName = $script:testGroupName2 }
                    }
                }
                
                # Parse all IDs from filter (handles OR conditions)
                $idMatches = [regex]::Matches($Filter, "id eq '([0-9a-fA-F-]{36})'")
                foreach ($match in $idMatches)
                {
                    $groupId = $match.Groups[1].Value
                    if ($groupId -eq $script:testGroupId1)
                    {
                        $results += @{ id = $script:testGroupId1; displayName = $script:testGroupName1 }
                    }
                    elseif ($groupId -eq $script:testGroupId2)
                    {
                        $results += @{ id = $script:testGroupId2; displayName = $script:testGroupName2 }
                    }
                }
                
                # Return results (de-duplicate by ID)
                if ($results.Count -gt 0)
                {
                    $uniqueResults = $results | Sort-Object -Property id -Unique
                    return @{ value = $uniqueResults }
                }
                
                return @{ value = @() }
            }
            
            throw "Unmocked CallGraphAPI call: $ResourcePath with Filter: $Filter"
        }
    }
    
    Context "Name to ID Resolution" {
        
        It "Should resolve single group name to ID" {
            $result = GetGroupIdsByNames -AccessToken $mockAccessToken -GroupNames @($testGroupName1)
            
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 1
            $result[0] | Should -Be $testGroupId1
        }
        
        It "Should resolve multiple group names to IDs" {
            # The CallGraphAPI mock handles multiple groups via OR filter
            $result = GetGroupIdsByNames -AccessToken $mockAccessToken -GroupNames @($testGroupName1, $testGroupName2)
            
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
            $result | Should -Contain $testGroupId1
            $result | Should -Contain $testGroupId2
        }
        
        It "Should cache group name to ID mapping" {
            # First call - should hit API
            $result1 = GetGroupIdsByNames -AccessToken $mockAccessToken -GroupNames @($testGroupName1)
            $result1 | Should -Not -BeNullOrEmpty
            
            # Verify cache contains the mapping
            $cachedId = Get-CachedData -CacheType 'DirectoryObjects' -Key "group:name:$testGroupName1" -CacheSettings $global:cacheSettings
            $cachedId | Should -Be $testGroupId1
        }
        
        It "Should use cached group name to ID mapping on subsequent calls" {
            # Prime the cache
            $null = GetGroupIdsByNames -AccessToken $mockAccessToken -GroupNames @($testGroupName1)
            
            # Remove the API mock to prove it doesn't get called
            Mock -CommandName CallGraphAPI -MockWith { throw "API should not be called - data should be cached" }
            
            # Second call - should use cache
            $result2 = GetGroupIdsByNames -AccessToken $mockAccessToken -GroupNames @($testGroupName1)
            $result2 | Should -Be $testGroupId1
        }
    }
    
    Context "ID to Name Resolution" {
        
        It "Should resolve single group ID to name" {
            $result = GetGroupIdsByNames -AccessToken $mockAccessToken -GroupNames @($testGroupId1) -DisplayNames
            
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 1
            $result[0] | Should -Be $testGroupName1
        }
        
        It "Should resolve multiple group IDs to names" {
            # The CallGraphAPI mock handles multiple groups via OR filter
            $result = GetGroupIdsByNames -AccessToken $mockAccessToken -GroupNames @($testGroupId1, $testGroupId2) -DisplayNames
            
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
            $result | Should -Contain $testGroupName1
            $result | Should -Contain $testGroupName2
        }
        
        It "Should cache group ID to name mapping" {
            # First call - should hit API
            $result1 = GetGroupIdsByNames -AccessToken $mockAccessToken -GroupNames @($testGroupId1) -DisplayNames
            $result1 | Should -Not -BeNullOrEmpty
            
            # Verify cache contains the mapping
            $cachedName = Get-CachedData -CacheType 'DirectoryObjects' -Key "group:id:$testGroupId1" -CacheSettings $global:cacheSettings
            $cachedName | Should -Be $testGroupName1
        }
        
        It "Should use cached group ID to name mapping on subsequent calls" {
            # Prime the cache
            $null = GetGroupIdsByNames -AccessToken $mockAccessToken -GroupNames @($testGroupId1) -DisplayNames
            
            # Remove the API mock to prove it doesn't get called
            Mock -CommandName Invoke-RestMethod -MockWith { throw "API should not be called - data should be cached" }
            
            # Second call - should use cache
            $result2 = GetGroupIdsByNames -AccessToken $mockAccessToken -GroupNames @($testGroupId1) -DisplayNames
            $result2 | Should -Be $testGroupName1
        }
    }
    
    Context "Bidirectional Cache Management" {
        
        It "Should store both ID->Name and Name->ID mappings" {
            # Call with name - should cache both directions
            $null = GetGroupIdsByNames -AccessToken $mockAccessToken -GroupNames @($testGroupName1)
            
            # Verify both cache entries exist
            $cachedId = Get-CachedData -CacheType 'DirectoryObjects' -Key "group:name:$testGroupName1" -CacheSettings $global:cacheSettings
            $cachedName = Get-CachedData -CacheType 'DirectoryObjects' -Key "group:id:$testGroupId1" -CacheSettings $global:cacheSettings
            
            $cachedId | Should -Be $testGroupId1
            $cachedName | Should -Be $testGroupName1
        }
        
        It "Should maintain consistency between forward and reverse lookups" {
            # Call with name to get ID
            $idResult = GetGroupIdsByNames -AccessToken $mockAccessToken -GroupNames @($testGroupName1)
            
            # Remove the API mock to prove it doesn't get called
            Mock -CommandName CallGraphAPI -MockWith { throw "API should not be called" }
            
            # Call with ID to get name - should use cache
            $nameResult = GetGroupIdsByNames -AccessToken $mockAccessToken -GroupNames @($idResult[0]) -DisplayNames
            
            $nameResult | Should -Be $testGroupName1
        }
    }
    
    Context "Input Validation" {
        
        It "Should return empty array for null input" {
            $result = GetGroupIdsByNames -AccessToken $mockAccessToken -GroupNames $null
            
            $result | Should -BeNullOrEmpty
        }
        
        It "Should return empty array for empty array input" {
            $result = GetGroupIdsByNames -AccessToken $mockAccessToken -GroupNames @()
            
            $result | Should -BeNullOrEmpty
        }
        
        It "Should filter out empty strings" {
            $result = GetGroupIdsByNames -AccessToken $mockAccessToken -GroupNames @($testGroupName1, "", "  ", $testGroupName2)
            
            # Should only process the two valid names
            $result.Count | Should -Be 2
        }
        
        It "Should return empty array for mixed IDs and names" {
            # This should fail validation - can't mix IDs and names
            $result = GetGroupIdsByNames -AccessToken $mockAccessToken -GroupNames @($testGroupId1, $testGroupName1)
            
            $result | Should -BeNullOrEmpty
        }
    }
    
    Context "Cache Expiration" {
        
        It "Should respect cache expiration settings" {
            # First call - populate cache
            $result1 = GetGroupIdsByNames -AccessToken $mockAccessToken -GroupNames @($testGroupName1)
            $result1 | Should -Not -BeNullOrEmpty
            
            # Manually expire the cache entry by setting old timestamp
            $cacheKey = "group:name:$($testGroupName1.ToLower())"
            $oldTimestamp = (Get-Date).AddMinutes(-20)  # Older than 15-minute default
            
            # Access internal cache structure to expire entry
            if ($global:UnifiedCache.DirectoryObjects.ContainsKey($cacheKey))
            {
                $global:UnifiedCache.DirectoryObjects[$cacheKey].Timestamp = $oldTimestamp
                
                # Also expire the ID->Name mapping
                $idCacheKey = "group:id:$($testGroupId1.ToLower())"
                if ($global:UnifiedCache.DirectoryObjects.ContainsKey($idCacheKey))
                {
                    $global:UnifiedCache.DirectoryObjects[$idCacheKey].Timestamp = $oldTimestamp
                }
            }
            
            # Track API calls using a script variable that the existing mock can check
            $script:apiCallCount = 0
            Mock -CommandName CallGraphAPI -MockWith {
                param($accessToken, $ResourcePath, $Filter, $ExtraParameters, $APIVersion, $method, $consistencyLevel)
                
                $script:apiCallCount++
                
                # Mock group search by filter
                if ($ResourcePath -eq "groups" -and $Filter)
                {
                    $results = @()
                    
                    # Parse all display names from filter (handles OR conditions)
                    $displayNameMatches = [regex]::Matches($Filter, "displayName eq '([^']+)'")
                    foreach ($match in $displayNameMatches)
                    {
                        $groupName = $match.Groups[1].Value
                        if ($groupName -eq $script:testGroupName1)
                        {
                            $results += @{ id = $script:testGroupId1; displayName = $script:testGroupName1 }
                        }
                    }
                    
                    if ($results.Count -gt 0)
                    {
                        return @{ value = $results }
                    }
                }
                
                return @{ value = @() }
            }
            
            # Second call - should detect expiration and call API
            $result2 = GetGroupIdsByNames -AccessToken $mockAccessToken -GroupNames @($testGroupName1)
            
            # Verify API was called (counter should be 1 or more)
            $script:apiCallCount | Should -BeGreaterThan 0
        }
    }
}

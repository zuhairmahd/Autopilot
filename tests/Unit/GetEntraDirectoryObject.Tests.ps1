<#
.SYNOPSIS
    Comprehensive Pester tests for Get-EntraDirectoryObject function

.DESCRIPTION
    Tests the unified directory object retrieval function covering:
    - User search (exact match, fuzzy search)
    - Group search (exact match, fuzzy search)
    - Caching behavior for both entity types
    - Exclusion patterns
    - Error handling
    - Access token validation
    
    Migrated from TestScripts/test-get-entra-directory-object.ps1

.NOTES
    Test Category: Unit
    Dependencies: Get-EntraDirectoryObject, AutopilotGraphMocks module
#>

Describe "Get-EntraDirectoryObject Function" -Tags 'Unit', 'DirectoryObject', 'GraphAPI' {
    
    BeforeAll {
        # Get repository root
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        
        # Import mocking infrastructure
        Import-Module (Join-Path $PSScriptRoot "../Helpers/AutopilotGraphMocks.psm1") -Force
        
        # Load the function being tested
        . (Join-Path $script:RepoRoot "functions/UserAndGroupFunctions/Get-EntraDirectoryObject.ps1")
        
        # Setup test log file
        $tempPath = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
        $global:LogFile = Join-Path $tempPath "test-get-entra-directory-object.log"
        
        # Initialize mock environment
        Initialize-GraphMockEnvironment -ClearCache
        
        # Create mock CallGraphAPI function that uses our infrastructure
        function global:CallGraphAPI
        {
            param(
                [string]$accessToken,
                [string]$ResourcePath,
                [string]$Filter,
                [string]$ExtraParameters,
                [switch]$consistencyLevel
            )
            
            return Invoke-MockGraphAPI -accessToken $accessToken -ResourcePath $ResourcePath `
                -Filter $Filter -ExtraParameters $ExtraParameters -consistencyLevel:$consistencyLevel
        }
    }
    
    AfterAll {
        # Cleanup
        Clear-GraphMockEnvironment
        
        if (Test-Path $global:LogFile)
        {
            Remove-Item $global:LogFile -Force -ErrorAction SilentlyContinue
        }
    }
    
    BeforeEach {
        # Clear cache before each test
        $global:DirectoryObjectCache = @{}
        
        # Reset mock data to defaults
        Reset-MockData -IncludeUsers -IncludeGroups
    }
    
    Context "User exact match" {
        
        It "Should return a result for existing user" {
            $result = Get-EntraDirectoryObject -EntityType User -EntityName "john.doe@contoso.com" -AccessToken "test-token"
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should return a tuple (array with 2 elements)" {
            $result = Get-EntraDirectoryObject -EntityType User -EntityName "john.doe@contoso.com" -AccessToken "test-token"
            
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
        }
        
        It "Should set fuzzy flag to false for exact match" {
            $result = Get-EntraDirectoryObject -EntityType User -EntityName "john.doe@contoso.com" -AccessToken "test-token"
            
            $result[1] | Should -Be $false
        }
        
        It "Should return correct user data" {
            $result = Get-EntraDirectoryObject -EntityType User -EntityName "john.doe@contoso.com" -AccessToken "test-token"
            
            $result[0].value[0].userPrincipalName | Should -Be "john.doe@contoso.com"
            $result[0].value[0].displayName | Should -Be "John Doe"
        }
        
        It "Should return 404-equivalent for non-existent user" {
            $result = Get-EntraDirectoryObject -EntityType User -EntityName "nonexistent@contoso.com" -AccessToken "test-token"
            
            $result | Should -Be $global:returnValues.noUserFoundInDirectoryMessage
        }
    }
    
    Context "Group exact match" {
        
        It "Should return a result for existing group" {
            $result = Get-EntraDirectoryObject -EntityType Group -EntityName "Marketing Team" -AccessToken "test-token"
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should return a tuple (array with 2 elements)" {
            $result = Get-EntraDirectoryObject -EntityType Group -EntityName "Marketing Team" -AccessToken "test-token"
            
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
        }
        
        It "Should set fuzzy flag to false for exact match" {
            $result = Get-EntraDirectoryObject -EntityType Group -EntityName "Marketing Team" -AccessToken "test-token"
            
            $result[1] | Should -Be $false
        }
        
        It "Should return correct group data" {
            $result = Get-EntraDirectoryObject -EntityType Group -EntityName "Marketing Team" -AccessToken "test-token"
            
            $result[0].value[0].displayName | Should -Be "Marketing Team"
            $result[0].value[0].id | Should -Be "group-001"
        }
        
        It "Should return not-found message for non-existent group" {
            $result = Get-EntraDirectoryObject -EntityType Group -EntityName "Nonexistent Group" -AccessToken "test-token"
            
            $result | Should -Be $global:returnValues.noGroupFoundMessage
        }
    }
    
    Context "User fuzzy search" {
        
        It "Should return results when FindSimilar is specified" {
            $result = Get-EntraDirectoryObject -EntityType User -EntityName "john" -AccessToken "test-token" -FindSimilar
            
            $result | Should -Not -BeNullOrEmpty
            $result[0].value.Count | Should -BeGreaterThan 0
        }
        
        It "Should set fuzzy flag to true" {
            $result = Get-EntraDirectoryObject -EntityType User -EntityName "john" -AccessToken "test-token" -FindSimilar
            
            $result[1] | Should -Be $true
        }
        
        It "Should find users matching search term" {
            $result = Get-EntraDirectoryObject -EntityType User -EntityName "john" -AccessToken "test-token" -FindSimilar
            
            $result[0].value.Count | Should -BeGreaterOrEqual 1
            # Should find john.doe@contoso.com and/or john.admin@contoso.com depending on exclusions
        }
        
        It "Should exclude users matching exclusion patterns" {
            $result = Get-EntraDirectoryObject -EntityType User -EntityName "john" -AccessToken "test-token" -FindSimilar
            
            # admin pattern should be excluded
            $adminUsers = $result[0].value | Where-Object { $_.userPrincipalName -like "*admin*" }
            $adminUsers | Should -BeNullOrEmpty
        }
        
        It "Should exclude users matching test pattern" {
            $result = Get-EntraDirectoryObject -EntityType User -EntityName "jane" -AccessToken "test-token" -FindSimilar
            
            # test pattern should be excluded
            $testUsers = $result[0].value | Where-Object { $_.userPrincipalName -like "*test*" }
            $testUsers | Should -BeNullOrEmpty
        }
    }
    
    Context "Group fuzzy search" {
        
        It "Should return results when FindSimilar is specified" {
            $result = Get-EntraDirectoryObject -EntityType Group -EntityName "Team" -AccessToken "test-token" -FindSimilar
            
            $result | Should -Not -BeNullOrEmpty
            $result[0].value.Count | Should -BeGreaterThan 0
        }
        
        It "Should set fuzzy flag to true" {
            $result = Get-EntraDirectoryObject -EntityType Group -EntityName "Team" -AccessToken "test-token" -FindSimilar
            
            $result[1] | Should -Be $true
        }
        
        It "Should find groups matching search term" {
            $result = Get-EntraDirectoryObject -EntityType Group -EntityName "Team" -AccessToken "test-token" -FindSimilar
            
            $result[0].value.Count | Should -BeGreaterOrEqual 2
            # Should find Marketing Team and Sales Team
        }
        
        It "Should exclude groups matching Archive pattern" {
            $result = Get-EntraDirectoryObject -EntityType Group -EntityName "Marketing" -AccessToken "test-token" -FindSimilar
            
            # Archive pattern should be excluded
            $archiveGroups = $result[0].value | Where-Object { $_.displayName -like "*Archive*" }
            $archiveGroups | Should -BeNullOrEmpty
        }
        
        It "Should exclude groups matching Disabled pattern" {
            $result = Get-EntraDirectoryObject -EntityType Group -EntityName "Group" -AccessToken "test-token" -FindSimilar
            
            # Disabled pattern should be excluded
            $disabledGroups = $result[0].value | Where-Object { $_.displayName -like "*Disabled*" }
            $disabledGroups | Should -BeNullOrEmpty
        }
    }
    
    Context "Caching behavior" {
        
        It "Should cache exact match results for users" {
            # First call
            $result1 = Get-EntraDirectoryObject -EntityType User -EntityName "john.doe@contoso.com" -AccessToken "test-token"
            $cacheSize1 = $global:DirectoryObjectCache.Count
            
            # Second call - should use cache
            $result2 = Get-EntraDirectoryObject -EntityType User -EntityName "john.doe@contoso.com" -AccessToken "test-token"
            $cacheSize2 = $global:DirectoryObjectCache.Count
            
            $cacheSize1 | Should -Be 1
            $cacheSize2 | Should -Be 1
            $result1[0].value[0].userPrincipalName | Should -Be $result2[0].value[0].userPrincipalName
        }
        
        It "Should cache exact match results for groups" {
            # First call
            $result1 = Get-EntraDirectoryObject -EntityType Group -EntityName "Marketing Team" -AccessToken "test-token"
            $cacheSize1 = $global:DirectoryObjectCache.Count
            
            # Second call - should use cache
            $result2 = Get-EntraDirectoryObject -EntityType Group -EntityName "Marketing Team" -AccessToken "test-token"
            $cacheSize2 = $global:DirectoryObjectCache.Count
            
            $cacheSize1 | Should -Be 1
            $cacheSize2 | Should -Be 1
            $result1[0].value[0].displayName | Should -Be $result2[0].value[0].displayName
        }
        
        It "Should create separate cache entries for different entity types" {
            # User search
            $result1 = Get-EntraDirectoryObject -EntityType User -EntityName "john.doe@contoso.com" -AccessToken "test-token"
            $cacheSize1 = $global:DirectoryObjectCache.Count
            
            # Group search
            $result2 = Get-EntraDirectoryObject -EntityType Group -EntityName "Marketing Team" -AccessToken "test-token"
            $cacheSize2 = $global:DirectoryObjectCache.Count
            
            $cacheSize1 | Should -Be 1
            $cacheSize2 | Should -Be 2
        }
        
        It "Should create separate cache entries for different entity names" {
            # First user
            Get-EntraDirectoryObject -EntityType User -EntityName "john.doe@contoso.com" -AccessToken "test-token"
            $cacheSize1 = $global:DirectoryObjectCache.Count
            
            # Different user
            Get-EntraDirectoryObject -EntityType User -EntityName "jane.smith@contoso.com" -AccessToken "test-token"
            $cacheSize2 = $global:DirectoryObjectCache.Count
            
            $cacheSize1 | Should -Be 1
            $cacheSize2 | Should -Be 2
        }
    }
    
    Context "Error handling" {
        
        It "Should return error message for empty EntityName" {
            $result = Get-EntraDirectoryObject -EntityType User -EntityName "" -AccessToken "test-token"
            
            # Should return error message (noUserFoundInDirectoryMessage or noAccessTokenMessage)
            $result | Should -BeIn @($global:returnValues.noUserFoundInDirectoryMessage, $global:returnValues.noAccessTokenMessage)
        }
        
        It "Should return error message for empty AccessToken" {
            $result = Get-EntraDirectoryObject -EntityType User -EntityName "john.doe@contoso.com" -AccessToken ""
            
            $result | Should -Be $global:returnValues.noAccessTokenMessage
        }
        
        It "Should return not-found message for non-existent user" {
            $result = Get-EntraDirectoryObject -EntityType User -EntityName "doesnotexist@contoso.com" -AccessToken "test-token"
            
            $result | Should -Be $global:returnValues.noUserFoundInDirectoryMessage
        }
        
        It "Should return not-found message for non-existent group" {
            $result = Get-EntraDirectoryObject -EntityType Group -EntityName "Nonexistent Group" -AccessToken "test-token"
            
            $result | Should -Be $global:returnValues.noGroupFoundMessage
        }
        
        It "Should handle null EntityName gracefully" {
            $result = Get-EntraDirectoryObject -EntityType User -EntityName $null -AccessToken "test-token"
            
            $result | Should -BeIn @($global:returnValues.noUserFoundInDirectoryMessage, $global:returnValues.noAccessTokenMessage)
        }
    }
    
    Context "No fuzzy search without FindSimilar flag" {
        
        It "Should not perform fuzzy search without FindSimilar flag" {
            # Without -FindSimilar, partial match should return not found
            $result = Get-EntraDirectoryObject -EntityType User -EntityName "john" -AccessToken "test-token"
            
            $result | Should -Be $global:returnValues.noUserFoundInDirectoryMessage
        }
        
        It "Should not perform fuzzy search for groups without FindSimilar flag" {
            # Without -FindSimilar, partial match should return not found
            $result = Get-EntraDirectoryObject -EntityType Group -EntityName "Team" -AccessToken "test-token"
            
            $result | Should -Be $global:returnValues.noGroupFoundMessage
        }
    }
    
    Context "Custom mock data extensibility" {
        
        It "Should work with custom added users" {
            # Add custom user
            Add-MockUser -UserPrincipalName "custom@contoso.com" -DisplayName "Custom User" -GivenName "Custom" -Surname "User"
            
            $result = Get-EntraDirectoryObject -EntityType User -EntityName "custom@contoso.com" -AccessToken "test-token"
            
            $result[0].value[0].userPrincipalName | Should -Be "custom@contoso.com"
            $result[0].value[0].displayName | Should -Be "Custom User"
        }
        
        It "Should work with custom added groups" {
            # Add custom group
            Add-MockGroup -DisplayName "Custom Group"
            
            $result = Get-EntraDirectoryObject -EntityType Group -EntityName "Custom Group" -AccessToken "test-token"
            
            $result[0].value[0].displayName | Should -Be "Custom Group"
        }
    }
}

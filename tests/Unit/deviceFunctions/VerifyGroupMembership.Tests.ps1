#Requires -Version 7.0
<#
.SYNOPSIS
    Unit tests for VerifyGroupMembership.ps1 - Verify user group membership against inclusion/exclusion rules

.DESCRIPTION
    Tests group membership verification logic including:
    - Format detection and conversion (string array vs hashtable)
    - Group membership validation (include/exclude rules)
    - User lookup and Graph API integration
    - Group ID resolution and name lookups
    - Missing/forbidden group detection
    - Error handling and validation

.NOTES
    Test Framework: Pester 5.7.1
    PowerShell: 7.0+
    Target Function: VerifyGroupMembership
    Category: Unit
    Dependencies: AutopilotTestHelpers, AutopilotGraphMocks
    Line Coverage Target: ~150 lines (~25%)
    Test Count: 24 tests across 5 contexts
#>

Import-Module "$PSScriptRoot\..\..\Helpers\AutopilotTestHelpers.psm1" -Force
Import-Module "$PSScriptRoot\..\..\Helpers\AutopilotGraphMocks.psm1" -Force

Describe "Function: VerifyGroupMembership" -Tags 'Unit' {
    BeforeAll {
        # Initialize test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment
        $script:RepoRoot = $script:TestContext.RootPath
        $script:LogFile = Join-Path $script:TestContext.LogsFolder "VerifyGroupMembership.log"
        $global:logFile = $script:LogFile
        $global:maxJsonDepth = 10
        
        # Direct dot-sourcing of function and dependencies
        . "$script:RepoRoot/functions/deviceFunctions/VerifyGroupMembership.ps1"
        . "$script:RepoRoot/functions/UserAndGroupFunctions/GetGroupMembership.ps1"
        . "$script:RepoRoot/functions/UserAndGroupFunctions/GetGroupIdsByNames.ps1"
        . "$script:RepoRoot/functions/graphFunctions/CallGraphAPI.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        
        # Mock Write-Log to suppress output
        Mock Write-Log { } -ModuleName $null
        
        # Test data
        $script:TestAccessToken = "test-token-12345"
        $script:TestUserName = "john.doe@contoso.com"
        $script:TestUserId = "user-id-12345"
        $script:TestUserInfo = @{
            displayName = "John Doe"
            mail = $script:TestUserName
            userPrincipalName = $script:TestUserName
            id = $script:TestUserId
        }
        
        # Group test data
        $script:IncludeGroups = @("IT Admins", "Security Group")
        $script:ExcludeGroups = @("Guests", "External Users")
        $script:IncludeGroupIds = @("group-id-1", "group-id-2")
        $script:ExcludeGroupIds = @("group-id-3", "group-id-4")
        
        $script:HashTableIncludeGroups = @(
            @{ name = "IT Admins"; id = "group-id-1" }
            @{ name = "Security Group"; id = "group-id-2" }
        )
        
        $script:HashTableExcludeGroups = @(
            @{ name = "Guests"; id = "group-id-3" }
            @{ name = "External Users"; id = "group-id-4" }
        )
    }
    
    AfterAll {
        Remove-TestEnvironment -TestContext $script:TestContext
    }
    
    Context "Parameter Validation and User Lookup" {
        It "Should successfully retrieve user information with valid token" {
            Mock CallGraphApi {
                return $script:TestUserInfo
            }
            
            $result = VerifyGroupMembership -accessToken $script:TestAccessToken -userName $script:TestUserName
            
            $result | Should -Not -BeNullOrEmpty
            $result.UserInfo | Should -Not -BeNullOrEmpty
            $result.UserInfo.displayName | Should -Be "John Doe"
            $result.UserInfo.id | Should -Be $script:TestUserId
        }
        
        It "Should return error when user is not found" {
            Mock CallGraphApi {
                return "404"  # Error code as string
            }
            
            $result = VerifyGroupMembership -accessToken $script:TestAccessToken -userName "nonexistent@contoso.com"
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $false
            $result.Error | Should -Match "User not found"
            $result.UserInfo | Should -BeNullOrEmpty
        }
        
        It "Should handle Graph API exceptions during user lookup" {
            Mock CallGraphApi {
                throw "Graph API error: Unauthorized"
            }
            
            $result = VerifyGroupMembership -accessToken $script:TestAccessToken -userName $script:TestUserName
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $false
            $result.Error | Should -Match "Error getting user information"
        }
    }
    
    Context "Group Format Detection and Conversion" {
        It "Should detect and process string array format for include groups" {
            Mock CallGraphApi {
                return $script:TestUserInfo
            }
            Mock GetGroupIdsByNames {
                return $script:IncludeGroupIds
            }
            Mock getGroupMembership {
                return $script:IncludeGroupIds
            }
            
            $result = VerifyGroupMembership -accessToken $script:TestAccessToken -userName $script:TestUserName -groupsToInclude $script:IncludeGroups
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.MissingGroups.Count | Should -Be 0
        }
        
        It "Should detect and process hashtable format for include groups" {
            Mock CallGraphApi {
                return $script:TestUserInfo
            }
            Mock getGroupMembership {
                return $script:IncludeGroupIds
            }
            
            $result = VerifyGroupMembership -accessToken $script:TestAccessToken -userName $script:TestUserName -groupsToInclude $script:HashTableIncludeGroups
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.MissingGroups.Count | Should -Be 0
        }
        
        It "Should handle empty group arrays" {
            Mock CallGraphApi {
                return $script:TestUserInfo
            }
            
            $result = VerifyGroupMembership -accessToken $script:TestAccessToken -userName $script:TestUserName -groupsToInclude @() -groupsToExclude @()
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.MissingGroups.Count | Should -Be 0
            $result.ForbiddenGroups.Count | Should -Be 0
        }
        
        It "Should handle null group parameters" {
            Mock CallGraphApi {
                return $script:TestUserInfo
            }
            
            $result = VerifyGroupMembership -accessToken $script:TestAccessToken -userName $script:TestUserName
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }
        
        It "Should resolve group IDs from names for string array format" {
            Mock CallGraphApi {
                return $script:TestUserInfo
            }
            Mock GetGroupIdsByNames {
                param($accessToken, $groupNames)
                if ($groupNames -contains "IT Admins") {
                    return @("group-id-1", "group-id-2")
                }
                return @()
            }
            Mock getGroupMembership {
                return @()
            }
            
            $result = VerifyGroupMembership -accessToken $script:TestAccessToken -userName $script:TestUserName -groupsToInclude $script:IncludeGroups
            
            Should -Invoke GetGroupIdsByNames -Times 1
        }
    }
    
    Context "Group Membership Validation - Include Groups" {
        It "Should succeed when user is member of all required groups" {
            Mock CallGraphApi {
                return $script:TestUserInfo
            }
            Mock getGroupMembership {
                return $script:IncludeGroupIds
            }
            
            $result = VerifyGroupMembership -accessToken $script:TestAccessToken -userName $script:TestUserName -groupsToInclude $script:HashTableIncludeGroups
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.MissingGroups.Count | Should -Be 0
        }
        
        It "Should detect missing required groups" {
            Mock CallGraphApi {
                return $script:TestUserInfo
            }
            Mock getGroupMembership {
                return @("group-id-1")  # Only first group
            }
            
            $result = VerifyGroupMembership -accessToken $script:TestAccessToken -userName $script:TestUserName -groupsToInclude $script:HashTableIncludeGroups
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $false
            $result.MissingGroups.Count | Should -BeGreaterThan 0
            $result.MissingGroups | Should -Contain "Security Group"
        }
        
        It "Should report all missing required groups" {
            Mock CallGraphApi {
                return $script:TestUserInfo
            }
            Mock getGroupMembership {
                return @()  # User is member of no groups
            }
            
            $result = VerifyGroupMembership -accessToken $script:TestAccessToken -userName $script:TestUserName -groupsToInclude $script:HashTableIncludeGroups
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $false
            $result.MissingGroups.Count | Should -Be 2
            $result.MissingGroups | Should -Contain "IT Admins"
            $result.MissingGroups | Should -Contain "Security Group"
        }
        
        It "Should use ID-based comparison when IDs are available" {
            Mock CallGraphApi {
                return $script:TestUserInfo
            }
            Mock getGroupMembership {
                param($accessToken, $userName, $Groups, $returnType)
                # Should be called with IDs when available
                $Groups | Should -Contain "group-id-1"
                return $script:IncludeGroupIds
            }
            
            $result = VerifyGroupMembership -accessToken $script:TestAccessToken -userName $script:TestUserName -groupsToInclude $script:HashTableIncludeGroups
            
            $result.Success | Should -Be $true
        }
    }
    
    Context "Group Membership Validation - Exclude Groups" {
        It "Should succeed when user is not member of any excluded groups" {
            Mock CallGraphApi {
                return $script:TestUserInfo
            }
            Mock getGroupMembership {
                param($accessToken, $userName, $Groups, $returnType)
                if ($Groups -contains "group-id-3") {
                    return @()  # Not a member of excluded groups
                }
                return @()
            }
            
            $result = VerifyGroupMembership -accessToken $script:TestAccessToken -userName $script:TestUserName -groupsToExclude $script:HashTableExcludeGroups
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.ForbiddenGroups.Count | Should -Be 0
        }
        
        It "Should detect forbidden group memberships" {
            Mock CallGraphApi {
                return $script:TestUserInfo
            }
            Mock getGroupMembership {
                param($accessToken, $userName, $Groups, $returnType)
                # Return one of the excluded group IDs to simulate membership
                if ($Groups[0] -eq "group-id-3") {
                    return @("group-id-3")
                }
                return @()
            }
            
            $result = VerifyGroupMembership -accessToken $script:TestAccessToken -userName $script:TestUserName -groupsToExclude $script:HashTableExcludeGroups
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $false
            $result.ForbiddenGroups.Count | Should -BeGreaterThan 0
        }
        
        It "Should report all forbidden group memberships" {
            Mock CallGraphApi {
                return $script:TestUserInfo
            }
            Mock getGroupMembership {
                # Return all excluded group IDs to simulate membership in all
                return $script:ExcludeGroupIds
            }
            
            $result = VerifyGroupMembership -accessToken $script:TestAccessToken -userName $script:TestUserName -groupsToExclude $script:HashTableExcludeGroups
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $false
            $result.ForbiddenGroups.Count | Should -Be 2
        }
    }
    
    Context "Combined Validation and Error Handling" {
        It "Should validate both include and exclude groups together" {
            Mock CallGraphApi {
                return $script:TestUserInfo
            }
            Mock getGroupMembership {
                param($accessToken, $userName, $Groups, $returnType)
                # Return appropriate membership based on which groups are checked
                if ($Groups -contains "group-id-1") {
                    return $script:IncludeGroupIds  # Member of required groups
                }
                if ($Groups -contains "group-id-3") {
                    return @()  # Not member of excluded groups
                }
                return @()
            }
            
            $result = VerifyGroupMembership -accessToken $script:TestAccessToken -userName $script:TestUserName -groupsToInclude $script:HashTableIncludeGroups -groupsToExclude $script:HashTableExcludeGroups
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.MissingGroups.Count | Should -Be 0
            $result.ForbiddenGroups.Count | Should -Be 0
        }
        
        It "Should fail when user is missing required groups and has forbidden groups" {
            Mock CallGraphApi {
                return $script:TestUserInfo
            }
            Mock getGroupMembership {
                param($accessToken, $userName, $Groups, $returnType)
                # For include groups: return only first group (missing second)
                if ($Groups -contains "group-id-1" -and $Groups -contains "group-id-2") {
                    return @("group-id-1")
                }
                # For exclude groups: return one forbidden group
                if ($Groups -contains "group-id-3" -and $Groups -contains "group-id-4") {
                    return @("group-id-3")
                }
                return @()
            }
            
            $result = VerifyGroupMembership -accessToken $script:TestAccessToken -userName $script:TestUserName -groupsToInclude $script:HashTableIncludeGroups -groupsToExclude $script:HashTableExcludeGroups
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $false
            $result.MissingGroups.Count | Should -BeGreaterThan 0
            $result.ForbiddenGroups.Count | Should -BeGreaterThan 0
        }
        
        It "Should handle exceptions during group membership lookup" {
            Mock CallGraphApi {
                return $script:TestUserInfo
            }
            Mock getGroupMembership {
                throw "Graph API error: Service unavailable"
            }
            
            $result = VerifyGroupMembership -accessToken $script:TestAccessToken -userName $script:TestUserName -groupsToInclude $script:HashTableIncludeGroups
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $false
            $result.Error | Should -Match "Error getting group membership"
        }
        
        It "Should handle failure to resolve group IDs for string array format" {
            Mock CallGraphApi {
                return $script:TestUserInfo
            }
            Mock GetGroupIdsByNames {
                throw "Failed to resolve group IDs"
            }
            Mock getGroupMembership {
                return @()
            }
            
            # Should not throw, should handle gracefully
            $result = VerifyGroupMembership -accessToken $script:TestAccessToken -userName $script:TestUserName -groupsToInclude $script:IncludeGroups
            
            $result | Should -Not -BeNullOrEmpty
            # Function should continue with names only
            Should -Invoke GetGroupIdsByNames -Times 1
        }
        
        It "Should return result object with correct structure" {
            Mock CallGraphApi {
                return $script:TestUserInfo
            }
            Mock getGroupMembership {
                return $script:IncludeGroupIds
            }
            
            $result = VerifyGroupMembership -accessToken $script:TestAccessToken -userName $script:TestUserName -groupsToInclude $script:HashTableIncludeGroups
            
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain "Success"
            $result.PSObject.Properties.Name | Should -Contain "UserInfo"
            $result.PSObject.Properties.Name | Should -Contain "MissingGroups"
            $result.PSObject.Properties.Name | Should -Contain "ForbiddenGroups"
            $result.PSObject.Properties.Name | Should -Contain "UserGroups"
            $result.PSObject.Properties.Name | Should -Contain "Error"
        }
    }
}

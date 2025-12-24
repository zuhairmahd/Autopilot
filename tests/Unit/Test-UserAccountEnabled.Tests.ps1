<#
.SYNOPSIS
    Test-UserAccountEnabled function tests
.DESCRIPTION
    Tests the Test-UserAccountEnabled function with various scenarios including
    enabled accounts, disabled accounts, and error conditions.

.NOTES
    Test Category: Unit
    Template Compliance: Full
    Uses: AutopilotTestHelpers (global variables, Write-Log mock)
          AutopilotGraphMocks (Graph API mocking)
    
    Created: 2025-12-24 for disabled account check feature
#>

# Import helper modules
Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force
Import-Module "$PSScriptRoot/../Helpers/AutopilotGraphMocks.psm1" -Force

Describe "Test-UserAccountEnabled Function" -Tags 'Unit', 'User', 'AccountStatus' {
    
    BeforeAll {
        # Get repository root
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        
        # Setup mock global variables using helper
        Initialize-MockGlobalVariables -LogFile "test-user-account-enabled.log"
        
        # Setup Write-Log mock using helper
        New-MockWriteLog
        
        # Initialize Graph mocking environment
        Initialize-GraphMockEnvironment -ClearCache
        
        # Add mock users with different account status
        Add-MockUser -UserPrincipalName "enabled-user@test.com" `
            -DisplayName "Enabled User" `
            -GivenName "Enabled" -Surname "User" `
            -Id "enabled123" `
            -Mail "enabled-user@test.com" `
            -CustomProperties @{
            accountEnabled = $true
        }
        
        Add-MockUser -UserPrincipalName "disabled-user@test.com" `
            -DisplayName "Disabled User" `
            -GivenName "Disabled" -Surname "User" `
            -Id "disabled456" `
            -Mail "disabled-user@test.com" `
            -CustomProperties @{
            accountEnabled = $false
        }
        
        Add-MockUser -UserPrincipalName "null-status-user@test.com" `
            -DisplayName "Null Status User" `
            -GivenName "Null" -Surname "User" `
            -Id "null789" `
            -Mail "null-status-user@test.com" `
            -CustomProperties @{
            accountEnabled = $null
        }
        
        # Mock CallGraphApi to use helper infrastructure
        function global:CallGraphApi
        {
            param($accessToken, $ResourcePath, $ExtraParameters)
            
            Write-Verbose "[CallGraphApi Mock] ResourcePath: $ResourcePath, ExtraParameters: $ExtraParameters"
            
            # Use Invoke-MockGraphAPI directly
            $result = Invoke-MockGraphAPI -accessToken $accessToken `
                -ResourcePath $ResourcePath `
                -ExtraParameters $ExtraParameters
            
            # Return null if 404 (user not found)
            if ($result -eq 404)
            {
                return $null
            }
            
            return $result
        }
        
        # Dot-source the function under test
        . "$script:RepoRoot/functions/UserAndGroupFunctions/Test-UserAccountEnabled.ps1"
    }
    
    Context "When checking an enabled account" {
        It "Should pass the check for an enabled user" {
            $result = Test-UserAccountEnabled -UserName "enabled-user@test.com" -AccessToken "mock-token"
            
            $result | Should -Not -BeNullOrEmpty
            $result.Passed | Should -Be $true
            $result.CheckName | Should -Be "Account Status"
            $result.AccountEnabled | Should -Be $true
            $result.Message | Should -Be "User account is enabled"
            $result.Severity | Should -Be "Information"
        }
        
        It "Should include correct details for enabled account" {
            $result = Test-UserAccountEnabled -UserName "enabled-user@test.com" -AccessToken "mock-token"
            
            $result.Details | Should -Contain "Account status: Enabled"
            $result.Details | Should -Contain "User can be assigned a device"
        }
    }
    
    Context "When checking a disabled account" {
        It "Should fail the check for a disabled user" {
            $result = Test-UserAccountEnabled -UserName "disabled-user@test.com" -AccessToken "mock-token"
            
            $result | Should -Not -BeNullOrEmpty
            $result.Passed | Should -Be $false
            $result.CheckName | Should -Be "Account Status"
            $result.AccountEnabled | Should -Be $false
            $result.Message | Should -Be "User account is disabled"
            $result.Severity | Should -Be "Error"
        }
        
        It "Should include correct details for disabled account" {
            $result = Test-UserAccountEnabled -UserName "disabled-user@test.com" -AccessToken "mock-token"
            
            $result.Details | Should -Contain "Account status: Disabled"
            $result.Details | Should -Contain "Disabled accounts cannot be assigned devices"
        }
        
        It "Should include suggested resolution for disabled account" {
            $result = Test-UserAccountEnabled -UserName "disabled-user@test.com" -AccessToken "mock-token"
            
            $result.SuggestedResolution | Should -BeLike "*Enable the user account in Entra ID*"
            $result.SuggestedResolution | Should -BeLike "*Entra ID administrator*"
        }
    }
    
    Context "When accountEnabled property is null" {
        It "Should treat null accountEnabled as enabled with warning" {
            $result = Test-UserAccountEnabled -UserName "null-status-user@test.com" -AccessToken "mock-token"
            
            $result | Should -Not -BeNullOrEmpty
            $result.Passed | Should -Be $true
            $result.CheckName | Should -Be "Account Status"
            $result.AccountEnabled | Should -Be $true
            $result.Message | Should -BeLike "*could not be determined*"
            $result.Severity | Should -Be "Warning"
        }
        
        It "Should include details about missing property" {
            $result = Test-UserAccountEnabled -UserName "null-status-user@test.com" -AccessToken "mock-token"
            
            $result.Details | Should -Contain "The accountEnabled property was not returned by Graph API"
            $result.Details | Should -Contain "This may indicate insufficient permissions"
        }
    }
    
    Context "When user is not found" {
        It "Should handle non-existent user gracefully" {
            $result = Test-UserAccountEnabled -UserName "nonexistent-user@test.com" -AccessToken "mock-token"
            
            $result | Should -Not -BeNullOrEmpty
            $result.Passed | Should -Be $false
            $result.Message | Should -Be "Unable to retrieve user account information"
        }
        
        It "Should include suggested resolution for missing user" {
            $result = Test-UserAccountEnabled -UserName "nonexistent-user@test.com" -AccessToken "mock-token"
            
            $result.SuggestedResolution | Should -BeLike "*Verify the user principal name is correct*"
            $result.SuggestedResolution | Should -BeLike "*User.Read.All permissions*"
        }
    }
    
    Context "When Graph API call fails" {
        BeforeAll {
            # Override CallGraphApi to simulate error
            function global:CallGraphApi
            {
                param($accessToken, $ResourcePath, $ExtraParameters)
                throw "Network error: Unable to connect to Graph API"
            }
        }
        
        It "Should handle Graph API errors gracefully" {
            $result = Test-UserAccountEnabled -UserName "enabled-user@test.com" -AccessToken "mock-token"
            
            $result | Should -Not -BeNullOrEmpty
            $result.Passed | Should -Be $false
            $result.Message | Should -Be "Error checking account status"
        }
        
        It "Should include exception details in error result" {
            $result = Test-UserAccountEnabled -UserName "enabled-user@test.com" -AccessToken "mock-token"
            
            $result.Details | Should -BeLike "*Network error*"
        }
        
        It "Should include suggested resolution for Graph API errors" {
            $result = Test-UserAccountEnabled -UserName "enabled-user@test.com" -AccessToken "mock-token"
            
            $result.SuggestedResolution | Should -BeLike "*Verify network connectivity*"
            $result.SuggestedResolution | Should -BeLike "*Graph API permissions*"
        }
    }
    
    Context "Return object structure validation" {
        BeforeAll {
            # Restore the normal CallGraphApi mock (undo the error-throwing override from previous context)
            function global:CallGraphApi
            {
                param($accessToken, $ResourcePath, $ExtraParameters)
                
                Write-Verbose "[CallGraphApi Mock] ResourcePath: $ResourcePath, ExtraParameters: $ExtraParameters"
                
                # Use Invoke-MockGraphAPI directly
                $result = Invoke-MockGraphAPI -accessToken $accessToken `
                    -ResourcePath $ResourcePath `
                    -ExtraParameters $ExtraParameters
                
                # Return null if 404 (user not found)
                if ($result -eq 404)
                {
                    return $null
                }
                
                return $result
            }
        }
        
        It "Should return object with all required properties" {
            $result = Test-UserAccountEnabled -UserName "enabled-user@test.com" -AccessToken "mock-token"
            
            $result.PSObject.Properties.Name | Should -Contain "CheckName"
            $result.PSObject.Properties.Name | Should -Contain "Passed"
            $result.PSObject.Properties.Name | Should -Contain "Severity"
            $result.PSObject.Properties.Name | Should -Contain "Message"
            $result.PSObject.Properties.Name | Should -Contain "Details"
            $result.PSObject.Properties.Name | Should -Contain "SuggestedResolution"
            $result.PSObject.Properties.Name | Should -Contain "AccountEnabled"
        }
        
        It "Should have Details properly populated" {
            $result = Test-UserAccountEnabled -UserName "enabled-user@test.com" -AccessToken "mock-token"
            
            # Details should be present and not null
            $result.Details | Should -Not -BeNullOrEmpty
            # When we wrap it in @(), it should have at least 1 element
            $detailsArray = @($result.Details)
            $detailsArray.Count | Should -BeGreaterThan 0
        }
        
        It "Should have Passed as a boolean" {
            $result = Test-UserAccountEnabled -UserName "enabled-user@test.com" -AccessToken "mock-token"
            
            $result.Passed | Should -BeOfType [System.Boolean]
        }
        
        It "Should have AccountEnabled as a boolean" {
            $result = Test-UserAccountEnabled -UserName "enabled-user@test.com" -AccessToken "mock-token"
            
            $result.AccountEnabled | Should -BeOfType [System.Boolean]
        }
    }
}

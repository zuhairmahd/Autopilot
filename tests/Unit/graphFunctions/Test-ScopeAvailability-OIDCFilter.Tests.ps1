BeforeAll {
    # Load the function
    $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
    
    # Mock Write-Log before loading the function
    function Write-Log {
        param($LogFile, $Module, $Message, $LogLevel)
        # Do nothing - suppress logging in tests
    }
    
    # Now load the functions
    . "$script:RepoRoot/functions/graphFunctions/Test-ScopeAvailability.ps1"
    . "$script:RepoRoot/functions/graphFunctions/DecodeJwtToken.ps1"
    . "$script:RepoRoot/functions/graphFunctions/Test-ScopeHierarchy.ps1"
}

Describe "Test-ScopeAvailability: OIDC Scope Filtering" -Tags 'Unit' {
    
    BeforeEach {
        # Create a mock JWT token with delegated scopes (excluding OIDC scopes)
        # Token payload: { "scp": "User.Read.All Device.Read.All openid profile offline_access" }
        # Base64 encoded (simplified for testing)
        $script:mockAccessToken = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzY3AiOiJVc2VyLlJlYWQuQWxsIERldmljZS5SZWFkLkFsbCBvcGVuaWQgcHJvZmlsZSBvZmZsaW5lX2FjY2VzcyJ9.signature"
        
        # Mock DecodeJwtToken to return our test payload
        Mock DecodeJwtToken {
            return @{
                scp = "User.Read.All Device.Read.All openid profile offline_access"
            }
        }
        
        # Mock Test-ScopeHierarchy to do simple string matching
        Mock Test-ScopeHierarchy {
            param($RequiredScope, $AvailableScopes)
            return $AvailableScopes -contains $RequiredScope
        }
        
        # Auth configuration for delegated auth
        $script:authConfig = @{
            Delegated = $true
            scope = @('User.Read.All', 'Device.Read.All', 'openid', 'profile', 'offline_access')
        }
    }
    
    Context "Delegated Authentication - OIDC Scopes in Required List" {
        
        It "Should filter out OIDC scopes from required scopes list" {
            $requiredScopes = @(
                @{ Scope = 'User.Read.All'; Reason = 'Read users'; Endpoints = @() }
                @{ Scope = 'openid'; Reason = 'OpenID Connect'; Endpoints = @() }
                @{ Scope = 'profile'; Reason = 'User profile'; Endpoints = @() }
                @{ Scope = 'offline_access'; Reason = 'Refresh tokens'; Endpoints = @() }
            )
            
            $result = Test-ScopeAvailability -AccessToken $mockAccessToken `
                -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            # OIDC scopes should NOT be in missing scopes
            $missingOIDCScopes = $result.MissingScopes | Where-Object { 
                $_.Scope -in @('openid', 'profile', 'offline_access') 
            }
            
            $missingOIDCScopes.Count | Should -Be 0 -Because "OIDC scopes should be filtered out and never flagged as missing"
        }
        
        It "Should have all required scopes when only Graph API scopes are needed" {
            $requiredScopes = @(
                @{ Scope = 'User.Read.All'; Reason = 'Read users'; Endpoints = @() }
                @{ Scope = 'Device.Read.All'; Reason = 'Read devices'; Endpoints = @() }
            )
            
            $result = Test-ScopeAvailability -AccessToken $mockAccessToken `
                -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            $result.HasAllRequiredScopes | Should -BeTrue -Because "All Graph API scopes are available"
            $result.MissingScopes.Count | Should -Be 0
        }
        
        It "Should only report missing Graph API scopes, not OIDC scopes" {
            $requiredScopes = @(
                @{ Scope = 'User.Read.All'; Reason = 'Read users'; Endpoints = @() }
                @{ Scope = 'Group.Read.All'; Reason = 'Read groups'; Endpoints = @() }  # This one is missing
                @{ Scope = 'openid'; Reason = 'OpenID Connect'; Endpoints = @() }
                @{ Scope = 'profile'; Reason = 'User profile'; Endpoints = @() }
                @{ Scope = 'offline_access'; Reason = 'Refresh tokens'; Endpoints = @() }
            )
            
            $result = Test-ScopeAvailability -AccessToken $mockAccessToken `
                -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            $result.HasAllRequiredScopes | Should -BeFalse -Because "Group.Read.All is missing"
            $result.MissingScopes.Count | Should -Be 1 -Because "Only Group.Read.All should be missing"
            $result.MissingScopes[0].Scope | Should -Be 'Group.Read.All'
            
            # OIDC scopes should NOT be in missing list
            $missingOIDCScopes = $result.MissingScopes | Where-Object { 
                $_.Scope -in @('openid', 'profile', 'offline_access') 
            }
            $missingOIDCScopes.Count | Should -Be 0
        }
        
        It "Should exclude OIDC scopes from available scopes list" {
            $requiredScopes = @(
                @{ Scope = 'User.Read.All'; Reason = 'Read users'; Endpoints = @() }
            )
            
            $result = Test-ScopeAvailability -AccessToken $mockAccessToken `
                -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            # Available scopes should NOT contain OIDC scopes
            $result.AvailableScopes | Should -Not -Contain 'openid'
            $result.AvailableScopes | Should -Not -Contain 'profile'
            $result.AvailableScopes | Should -Not -Contain 'offline_access'
            
            # Available scopes SHOULD contain Graph API scopes
            $result.AvailableScopes | Should -Contain 'User.Read.All'
            $result.AvailableScopes | Should -Contain 'Device.Read.All'
        }
    }
    
    Context "Application Authentication - OIDC Scopes Already Filtered" {
        
        BeforeEach {
            # Application auth configuration
            $script:appAuthConfig = @{
                Delegated = $false
            }
            
            # Mock token with roles claim for application auth
            Mock DecodeJwtToken {
                return @{
                    roles = @('User.Read.All', 'Device.Read.All')
                }
            }
        }
        
        It "Should filter out OIDC scopes from required scopes list for application auth" {
            $requiredScopes = @(
                @{ Scope = 'User.Read.All'; Reason = 'Read users'; Endpoints = @() }
                @{ Scope = 'openid'; Reason = 'OpenID Connect'; Endpoints = @() }
                @{ Scope = 'offline_access'; Reason = 'Refresh tokens'; Endpoints = @() }
            )
            
            $result = Test-ScopeAvailability -AccessToken $mockAccessToken `
                -RequiredScopes $requiredScopes `
                -AuthConfiguration $appAuthConfig
            
            # OIDC scopes should NOT be in missing scopes
            $missingOIDCScopes = $result.MissingScopes | Where-Object { 
                $_.Scope -in @('openid', 'profile', 'offline_access') 
            }
            
            $missingOIDCScopes.Count | Should -Be 0 -Because "OIDC scopes should be filtered for application auth too"
        }
    }
}

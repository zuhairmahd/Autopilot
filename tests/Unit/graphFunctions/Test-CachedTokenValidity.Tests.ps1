Describe "Function: Test-CachedTokenValidity" -Tags 'Unit' {
    BeforeAll {
        # Direct dot-sourcing of the function
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        
        # Source dependencies first
        . "$script:RepoRoot\functions\utilityFunctions\Write-Log.ps1"
        . "$script:RepoRoot\functions\utilityFunctions\FormatDateWithTimeZone.ps1"
        . "$script:RepoRoot\functions\graphFunctions\DecodeJwtToken.ps1"
        . "$script:RepoRoot\functions\graphFunctions\Get-NormalizedExpiryTime.ps1"
        
        # Remove function from scope if it exists (force fresh load)
        if (Get-Command Test-CachedTokenValidity -ErrorAction SilentlyContinue) {
            Remove-Item Function:\Test-CachedTokenValidity -ErrorAction SilentlyContinue
        }
        
        # Source the function under test
        . "$script:RepoRoot\functions\graphFunctions\Test-CachedTokenValidity.ps1"
        
        # Mock global variables
        $global:logFile = Join-Path $TestDrive "test.log"
        $global:maxJSONDepth = 10
        $global:returnValues = @{
            invalidJWTTokenMessage   = "Invalid JWT token"
            invalidJWTPayloadMessage = "Invalid JWT payload"
        }
        
        # Mock Write-Log after it's been loaded (accept all parameters)
        Mock Write-Log {} -ParameterFilter { $true }
        
        # Mock Get-NormalizedExpiryTime to return calculated expiry from token exp claim
        Mock Get-NormalizedExpiryTime {
            param($accessTokenObject)
            if ($accessTokenObject.AbsoluteExpiryTime)
            {
                return $accessTokenObject.AbsoluteExpiryTime
            }
            # Parse token manually to avoid dependencies
            $parts = $accessTokenObject.access_token -split '\.'
            if ($parts.Length -lt 2) { return [datetime]::MinValue }
            
            $payload = $parts[1].Replace('-', '+').Replace('_', '/')
            switch ($payload.Length % 4)
            {
                2 { $payload += '==' }
                3 { $payload += '=' }
            }
            
            try
            {
                $bytes = [System.Convert]::FromBase64String($payload)
                $json = [System.Text.Encoding]::UTF8.GetString($bytes)
                $claims = $json | ConvertFrom-Json
                if ($claims.exp)
                {
                    return [DateTimeOffset]::FromUnixTimeSeconds($claims.exp).LocalDateTime
                }
            }
            catch
            {
                # Ignore decoding errors
            }
            return [datetime]::MinValue
        }
        
        # Helper to create mock JWT tokens
        function New-MockJwtToken
        {
            param(
                [string[]]$Scopes,
                [int]$ExpiresInMinutes = 60,
                [bool]$UseScp = $true  # true for delegated (scp), false for application (roles)
            )
            
            $exp = [DateTimeOffset]::UtcNow.AddMinutes($ExpiresInMinutes).ToUnixTimeSeconds()
            
            $claims = @{
                exp = $exp
                aud = "https://graph.microsoft.com"
                iss = "https://sts.windows.net/test-tenant/"
                iat = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
                nbf = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            }
            
            if ($UseScp)
            {
                # Delegated auth - space-separated string
                $claims.scp = $Scopes -join ' '
            }
            else
            {
                # Application auth - array
                $claims.roles = $Scopes
            }
            
            $payloadJson = $claims | ConvertTo-Json -Compress
            $payloadBytes = [System.Text.Encoding]::UTF8.GetBytes($payloadJson)
            $payloadBase64 = [Convert]::ToBase64String($payloadBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
            
            return "header.$payloadBase64.signature"
        }
    }
    
    BeforeEach {
        # Force reload function before each test to ensure latest code
        if (Get-Command Test-CachedTokenValidity -ErrorAction SilentlyContinue) {
            Remove-Item Function:\Test-CachedTokenValidity -ErrorAction SilentlyContinue
        }
        . "$script:RepoRoot\functions\graphFunctions\Test-CachedTokenValidity.ps1"
    }
    
    Context "Scope comparison with space-separated string (Bug Fix)" {
        It "Should properly compare scopes when requestedScopes is a space-separated string" {
            # Create token with delegated scopes
            $scopes = @('Device.ReadWrite.All', 'DeviceManagementApps.Read.All', 'Mail.Send')
            $token = New-MockJwtToken -Scopes $scopes -UseScp $true
            
            $accessTokenObject = @{
                access_token = $token
                expires_in   = 3600
            }
            
            $timeBuffer = (Get-Date).AddMinutes(-10)
            
            # Pass scopes as space-separated string (simulating flow from BuildAuthSplatTable -> GetGraphAccessToken -> Get-TokenFromCache)
            $requestedScopesString = $scopes -join ' '
            
            $result = Test-CachedTokenValidity -accessTokenObject $accessTokenObject `
                -timeBuffer $timeBuffer -domain "test.com" -cacheType "memory" `
                -requestedScopes $requestedScopesString
            
            $result | Should -Not -BeNullOrEmpty
            $result | Should -Be $token
        }
        
        It "Should detect missing scopes when requestedScopes is a space-separated string" {
            # Create token with only 2 scopes
            $tokenScopes = @('Device.ReadWrite.All', 'Mail.Send')
            $token = New-MockJwtToken -Scopes $tokenScopes -UseScp $true
            
            $accessTokenObject = @{
                access_token = $token
                expires_in   = 3600
            }
            
            $timeBuffer = (Get-Date).AddMinutes(-10)
            
            # Request 3 scopes (one missing)
            $requestedScopes = @('Device.ReadWrite.All', 'DeviceManagementApps.Read.All', 'Mail.Send')
            $requestedScopesString = $requestedScopes -join ' '
            
            $result = Test-CachedTokenValidity -accessTokenObject $accessTokenObject `
                -timeBuffer $timeBuffer -domain "test.com" -cacheType "memory" `
                -requestedScopes $requestedScopesString
            
            $result | Should -BeNullOrEmpty
        }
        
        It "Should handle requestedScopes as array (backward compatibility)" {
            # Create token with delegated scopes
            $scopes = @('Device.ReadWrite.All', 'DeviceManagementApps.Read.All', 'Mail.Send')
            $token = New-MockJwtToken -Scopes $scopes -UseScp $true
            
            $accessTokenObject = @{
                access_token = $token
                expires_in   = 3600
            }
            
            $timeBuffer = (Get-Date).AddMinutes(-10)
            
            # Pass scopes as array (original behavior)
            $result = Test-CachedTokenValidity -accessTokenObject $accessTokenObject `
                -timeBuffer $timeBuffer -domain "test.com" -cacheType "memory" `
                -requestedScopes $scopes
            
            $result | Should -Not -BeNullOrEmpty
            $result | Should -Be $token
        }
        
        It "Should handle empty scope string gracefully" {
            $scopes = @('Device.ReadWrite.All', 'Mail.Send')
            $token = New-MockJwtToken -Scopes $scopes -UseScp $true
            
            $accessTokenObject = @{
                access_token = $token
                expires_in   = 3600
            }
            
            $timeBuffer = (Get-Date).AddMinutes(-10)
            
            # Pass empty string
            $result = Test-CachedTokenValidity -accessTokenObject $accessTokenObject `
                -timeBuffer $timeBuffer -domain "test.com" -cacheType "memory" `
                -requestedScopes ""
            
            # Should succeed (no scopes requested means any token is valid)
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle scope string with extra whitespace" {
            $scopes = @('Device.ReadWrite.All', 'DeviceManagementApps.Read.All', 'Mail.Send')
            $token = New-MockJwtToken -Scopes $scopes -UseScp $true
            
            $accessTokenObject = @{
                access_token = $token
                expires_in   = 3600
            }
            
            $timeBuffer = (Get-Date).AddMinutes(-10)
            
            # Pass scopes with extra whitespace
            $requestedScopesString = "  Device.ReadWrite.All   DeviceManagementApps.Read.All   Mail.Send  "
            
            $result = Test-CachedTokenValidity -accessTokenObject $accessTokenObject `
                -timeBuffer $timeBuffer -domain "test.com" -cacheType "memory" `
                -requestedScopes $requestedScopesString
            
            $result | Should -Not -BeNullOrEmpty
            $result | Should -Be $token
        }
    }
    
    Context "Delegated vs Application scope extraction" {
        It "Should extract scopes from scp claim for delegated auth" {
            $scopes = @('Device.ReadWrite.All', 'Mail.Send', 'User.Read')
            $token = New-MockJwtToken -Scopes $scopes -UseScp $true
            
            $accessTokenObject = @{
                access_token = $token
                expires_in   = 3600
            }
            
            $timeBuffer = (Get-Date).AddMinutes(-10)
            $requestedScopesString = $scopes -join ' '
            
            $result = Test-CachedTokenValidity -accessTokenObject $accessTokenObject `
                -timeBuffer $timeBuffer -domain "test.com" -cacheType "memory" `
                -requestedScopes $requestedScopesString
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should extract scopes from roles claim for application auth" {
            $scopes = @('Device.Read.All', 'User.Read.All', 'Mail.Send')
            $token = New-MockJwtToken -Scopes $scopes -UseScp $false
            
            $accessTokenObject = @{
                access_token = $token
                expires_in   = 3600
            }
            
            $timeBuffer = (Get-Date).AddMinutes(-10)
            $requestedScopesString = $scopes -join ' '
            
            $result = Test-CachedTokenValidity -accessTokenObject $accessTokenObject `
                -timeBuffer $timeBuffer -domain "test.com" -cacheType "memory" `
                -requestedScopes $requestedScopesString
            
            $result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Token expiry validation" {
        It "Should reject expired token regardless of scopes" {
            $scopes = @('Device.ReadWrite.All', 'Mail.Send')
            # Create expired token (expired 10 minutes ago)
            $token = New-MockJwtToken -Scopes $scopes -UseScp $true -ExpiresInMinutes -10
            
            $accessTokenObject = @{
                access_token = $token
                expires_in   = 3600
            }
            
            # Buffer time is in the future
            $timeBuffer = (Get-Date).AddMinutes(5)
            $requestedScopesString = $scopes -join ' '
            
            $result = Test-CachedTokenValidity -accessTokenObject $accessTokenObject `
                -timeBuffer $timeBuffer -domain "test.com" -cacheType "memory" `
                -requestedScopes $requestedScopesString
            
            $result | Should -BeNullOrEmpty
        }
        
        It "Should accept valid token with all required scopes" {
            $scopes = @('Device.ReadWrite.All', 'DeviceManagementApps.Read.All', 'Mail.Send', 'User.Read')
            $token = New-MockJwtToken -Scopes $scopes -UseScp $true -ExpiresInMinutes 60
            
            $accessTokenObject = @{
                access_token = $token
                expires_in   = 3600
            }
            
            # Buffer time is in the past (token not expired)
            $timeBuffer = (Get-Date).AddMinutes(-10)
            $requestedScopes = @('Device.ReadWrite.All', 'Mail.Send')  # Subset of granted scopes
            $requestedScopesString = $requestedScopes -join ' '
            
            $result = Test-CachedTokenValidity -accessTokenObject $accessTokenObject `
                -timeBuffer $timeBuffer -domain "test.com" -cacheType "memory" `
                -requestedScopes $requestedScopesString
            
            $result | Should -Not -BeNullOrEmpty
            $result | Should -Be $token
        }
    }
    
    Context "Edge cases" {
        It "Should handle token with no scopes (neither scp nor roles)" {
            # Create token without scope claims
            $exp = [DateTimeOffset]::UtcNow.AddMinutes(60).ToUnixTimeSeconds()
            $claims = @{
                exp = $exp
                aud = "https://graph.microsoft.com"
            }
            $payloadJson = $claims | ConvertTo-Json -Compress
            $payloadBytes = [System.Text.Encoding]::UTF8.GetBytes($payloadJson)
            $payloadBase64 = [Convert]::ToBase64String($payloadBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
            $token = "header.$payloadBase64.signature"
            
            $accessTokenObject = @{
                access_token = $token
                expires_in   = 3600
            }
            
            $timeBuffer = (Get-Date).AddMinutes(-10)
            $requestedScopes = @('Device.ReadWrite.All')
            $requestedScopesString = $requestedScopes -join ' '
            
            # Should fail validation because token has no scopes but we requested some
            $result = Test-CachedTokenValidity -accessTokenObject $accessTokenObject `
                -timeBuffer $timeBuffer -domain "test.com" -cacheType "memory" `
                -requestedScopes $requestedScopesString
            
            $result | Should -BeNullOrEmpty
        }
        
        It "Should handle null access token object" {
            $timeBuffer = (Get-Date).AddMinutes(5)
            
            $result = Test-CachedTokenValidity -accessTokenObject @{} `
                -timeBuffer $timeBuffer -domain "test.com" -cacheType "memory" `
                -requestedScopes "Device.ReadWrite.All"
            
            $result | Should -BeNullOrEmpty
        }
    }
}

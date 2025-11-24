BeforeAll {
    # Import required modules
    $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
    
    # Import encryption functions
    Get-ChildItem "$script:RepoRoot/functions/encryptionFunctions/*.ps1" | ForEach-Object {
        . $_.FullName
    }
    
    # Import token cache functions
    . "$script:RepoRoot/functions/graphFunctions/Save-TokenToCache.ps1"
    . "$script:RepoRoot/functions/graphFunctions/Get-CachedTokenObject.ps1"
    
    # Mock dependencies
    function Write-Log { }
    function DecodeJwtToken {
        param($Token, [switch]$raw)
        return @{ scp = "User.Read Mail.Read" }
    }
    $global:maxJSONDepth = 10
    $global:LogFile = $null
}

Describe "Token Cache Encryption" -Tags 'Unit' {
    BeforeEach {
        # Create temp directory for testing
        $script:TestFolder = Join-Path $env:TEMP "TokenCacheTest_$(Get-Random)"
        New-Item -Path $script:TestFolder -ItemType Directory -Force | Out-Null
        $script:TestTokenFile = Join-Path $script:TestFolder "accessToken.json"
        $script:TestPassword = "TestPassword123!"
        
        # Set user encryption password (simulating authenticated session)
        $script:UserEncryptionPassword = $script:TestPassword
    }
    
    AfterEach {
        # Cleanup
        if (Test-Path $script:TestFolder) {
            Remove-Item -Path $script:TestFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
        $script:UserEncryptionPassword = $null
        $global:UserEncryptionPassword = $null
    }
    
    Context "Token Encryption" {
        It "Should encrypt token when saving to file cache with user password" {
            $testToken = @{
                access_token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test"
                expires_on = (Get-Date).AddHours(1).ToString("o")
                domain = "test.onmicrosoft.com"
            }
            
            Save-TokenToCache -cachedToken $testToken -cacheType 'file' `
                -cacheTokenFile $script:TestTokenFile -cacheFolder $script:TestFolder
            
            $script:TestTokenFile | Should -Exist
            
            # Read the file content
            $fileContent = Get-Content -Path $script:TestTokenFile -Raw
            
            # Verify it's encrypted (base64 format, not JSON)
            { ConvertFrom-Json $fileContent -ErrorAction Stop } | Should -Throw
            # Base64 can contain newlines/whitespace, so remove them for the test
            $cleanContent = $fileContent -replace '\s', ''
            $cleanContent | Should -Match '^[A-Za-z0-9+/=]+$'
        }
        
        It "Should save unencrypted token when no user password is available" {
            # Clear the user password
            $script:UserEncryptionPassword = $null
            
            $testToken = @{
                access_token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test"
                expires_on = (Get-Date).AddHours(1).ToString("o")
                domain = "test.onmicrosoft.com"
            }
            
            Save-TokenToCache -cachedToken $testToken -cacheType 'file' `
                -cacheTokenFile $script:TestTokenFile -cacheFolder $script:TestFolder
            
            $script:TestTokenFile | Should -Exist
            
            # Read the file content
            $fileContent = Get-Content -Path $script:TestTokenFile -Raw
            
            # Verify it's plain JSON
            { $parsed = ConvertFrom-Json $fileContent -ErrorAction Stop } | Should -Not -Throw
        }
    }
    
    Context "Token Decryption" {
        It "Should decrypt token when reading from file cache with correct password" {
            # First, save an encrypted token
            $testToken = @{
                access_token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test"
                expires_on = (Get-Date).AddHours(1).ToString("o")
                domain = "test.onmicrosoft.com"
            }
            
            Save-TokenToCache -cachedToken $testToken -cacheType 'file' `
                -cacheTokenFile $script:TestTokenFile -cacheFolder $script:TestFolder
            
            # Now read it back
            $retrievedToken = Get-CachedTokenObject -cacheType 'file' `
                -cacheTokenFile $script:TestTokenFile -domain "test.onmicrosoft.com"
            
            $retrievedToken | Should -Not -BeNullOrEmpty
            $retrievedToken.access_token | Should -Be $testToken.access_token
            $retrievedToken.domain | Should -Be $testToken.domain
        }
        
        It "Should return null when trying to decrypt with wrong password" {
            # Save with one password
            $script:UserEncryptionPassword = "CorrectPassword123!"
            
            $testToken = @{
                access_token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test"
                expires_on = (Get-Date).AddHours(1).ToString("o")
                domain = "test.onmicrosoft.com"
            }
            
            Save-TokenToCache -cachedToken $testToken -cacheType 'file' `
                -cacheTokenFile $script:TestTokenFile -cacheFolder $script:TestFolder
            
            # Try to read with wrong password
            $script:UserEncryptionPassword = "WrongPassword456!"
            
            $retrievedToken = Get-CachedTokenObject -cacheType 'file' `
                -cacheTokenFile $script:TestTokenFile -domain "test.onmicrosoft.com"
            
            $retrievedToken | Should -BeNullOrEmpty
        }
        
        It "Should handle unencrypted tokens for backward compatibility" {
            # Manually create an unencrypted token file
            $testToken = @{
                access_token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test"
                expires_on = (Get-Date).AddHours(1).ToString("o")
                domain = "test.onmicrosoft.com"
            }
            
            $testToken | ConvertTo-Json | Set-Content -Path $script:TestTokenFile -Force
            
            # Read it back
            $retrievedToken = Get-CachedTokenObject -cacheType 'file' `
                -cacheTokenFile $script:TestTokenFile -domain "test.onmicrosoft.com"
            
            $retrievedToken | Should -Not -BeNullOrEmpty
            $retrievedToken.access_token | Should -Be $testToken.access_token
            $retrievedToken.domain | Should -Be $testToken.domain
        }
        
        It "Should return null when token is encrypted but no password is available" {
            # Save encrypted token
            $testToken = @{
                access_token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test"
                expires_on = (Get-Date).AddHours(1).ToString("o")
                domain = "test.onmicrosoft.com"
            }
            
            Save-TokenToCache -cachedToken $testToken -cacheType 'file' `
                -cacheTokenFile $script:TestTokenFile -cacheFolder $script:TestFolder
            
            # Clear password and try to read
            $script:UserEncryptionPassword = $null
            $global:UserEncryptionPassword = $null
            
            $retrievedToken = Get-CachedTokenObject -cacheType 'file' `
                -cacheTokenFile $script:TestTokenFile -domain "test.onmicrosoft.com"
            
            $retrievedToken | Should -BeNullOrEmpty
        }
    }
    
    Context "Cross-Session Persistence" {
        It "Should persist encrypted token that can be decrypted in a new session with same password" {
            # Session 1: Save encrypted token
            $script:UserEncryptionPassword = "SessionPassword123!"
            
            $testToken = @{
                access_token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test"
                expires_on = (Get-Date).AddHours(1).ToString("o")
                domain = "test.onmicrosoft.com"
            }
            
            Save-TokenToCache -cachedToken $testToken -cacheType 'file' `
                -cacheTokenFile $script:TestTokenFile -cacheFolder $script:TestFolder
            
            # Simulate new session: Clear password and set it again
            $script:UserEncryptionPassword = $null
            $global:UserEncryptionPassword = $null
            Start-Sleep -Milliseconds 100  # Small delay to simulate session boundary
            
            # Session 2: Set password again and read token
            $script:UserEncryptionPassword = "SessionPassword123!"
            
            $retrievedToken = Get-CachedTokenObject -cacheType 'file' `
                -cacheTokenFile $script:TestTokenFile -domain "test.onmicrosoft.com"
            
            $retrievedToken | Should -Not -BeNullOrEmpty
            $retrievedToken.access_token | Should -Be $testToken.access_token
            $retrievedToken.domain | Should -Be $testToken.domain
        }
    }
}

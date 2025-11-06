BeforeAll {
    # Get repository root
    $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    
    # Load unified cache functions first
    . (Join-Path $script:RepoRoot "functions/utilityFunctions/Get-CachedData.ps1")
    
    # Load the function under test
    . (Join-Path $script:RepoRoot "functions/UserAndGroupFunctions/Resolve-DirectoryObject.ps1")
    . (Join-Path $script:RepoRoot "functions/UserAndGroupFunctions/ConvertFrom-DirectoryObjectSelection.ps1")
    . (Join-Path $script:RepoRoot "functions/UserAndGroupFunctions/Get-EntraDirectoryObject.ps1")
    . (Join-Path $script:RepoRoot "functions/UserAndGroupFunctions/Show-DirectoryObjectList.ps1")
    
    # Import the Graph mocking module
    Import-Module (Join-Path $script:RepoRoot "tests/Helpers/AutopilotGraphMocks.psm1") -Force
    
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
    
    # Initialize mock environment
    Initialize-GraphMockEnvironment -ClearCache
    
    # Mock Write-Log to avoid log file dependencies
    function global:Write-Log
    {
        param($LogFile, $Module, $Message, $LogLevel)
    }
    
    # Mock CallGraphAPI to use our mock infrastructure
    function global:CallGraphAPI
    {
        param(
            $accessToken,
            $ResourcePath,
            $Filter,
            $ExtraParameters,
            [switch]$consistencyLevel
        )
        return Invoke-MockGraphAPI -accessToken $accessToken -ResourcePath $ResourcePath `
            -Filter $Filter -ExtraParameters $ExtraParameters -consistencyLevel:$consistencyLevel
    }
    
    # Mock menu system functions
    $script:MockMenuResponse = $null
    $script:MenuCallCount = 0
    
    function global:NewMenu
    {
        param($Title, $Description, $MenuName)
        return @{
            Title       = $Title
            Description = $Description
            MenuName    = $MenuName
            Items       = @()
        }
    }
    
    function global:AddMenuItem
    {
        param($Menu, $Name, $Display, $ReturnValue, $Action, [switch]$ReturnsValue)
        $Menu.Items += @{
            Name        = if ($Name) { $Name } else { $Display }
            ReturnValue = if ($Action) { $Action } else { $ReturnValue }
        }
        return $Menu
    }
    
    function global:ShowMenu
    {
        param($Menu, $CalledBy, $StackOperation)
        $script:MenuCallCount++
        return $script:MockMenuResponse
    }
    
    # Mock Read-Host to prevent user prompts during tests
    function global:Read-Host
    {
        param([string]$Prompt)
        # Default to "Y" for confirmation prompts
        return "Y"
    }
}

AfterAll {
    Clear-GraphMockEnvironment
}

Describe "Resolve-DirectoryObject" -Tag 'Unit', 'DirectoryObject' {
    
    BeforeEach {
        # Reset for each test
        Reset-MockData
        $script:MockMenuResponse = $null
        $script:MenuCallCount = 0
        
        # Clear unified cache
        Clear-UnifiedCache -CacheType 'DirectoryObjects'
    }
    
    Context "Input Validation" {
        It "Returns noUserFoundInDirectoryMessage when EntityName is empty for User" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{ noUserFoundInDirectoryMessage = "User not found" }
            
            $result = Resolve-DirectoryObject -EntityName "" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result | Should -Be $returnValues.noUserFoundInDirectoryMessage
        }
        
        It "Returns noGroupFoundMessage when EntityName is empty for Group" {
            $settings = @{ maxGroupMatchDisplay = 10 }
            $returnValues = @{ noGroupFoundMessage = "Group not found" }
            
            $result = Resolve-DirectoryObject -EntityName "" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "Group"
            
            $result | Should -Be $returnValues.noGroupFoundMessage
        }
        
        It "Returns noAccessTokenMessage when AccessToken is empty" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{ noAccessTokenMessage = "Access token required" }
            
            $result = Resolve-DirectoryObject -EntityName "test@contoso.com" -AccessToken "" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result | Should -Be $returnValues.noAccessTokenMessage
        }
        
        It "Returns noUserFoundInDirectoryMessage when EntityName is whitespace" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{ noUserFoundInDirectoryMessage = "User not found" }
            
            $result = Resolve-DirectoryObject -EntityName "   " -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result | Should -Be $returnValues.noUserFoundInDirectoryMessage
        }
    }
    
    Context "Exact Match Scenarios" {
        It "Returns correct userPrincipalName for exact user match" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{}
            
            $result = Resolve-DirectoryObject -EntityName "john.doe@contoso.com" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result | Should -Be "john.doe@contoso.com"
        }
        
        It "Returns correct displayName for exact group match" {
            $settings = @{ maxGroupMatchDisplay = 10 }
            $returnValues = @{}
            
            $result = Resolve-DirectoryObject -EntityName "Marketing Team" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "Group"
            
            $result | Should -Be "Marketing Team"
        }
    }
    
    Context "Fuzzy Match with NoPrompt" {
        It "Auto-accepts single user fuzzy match with NoPrompt" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{}
            
            # "smith" should fuzzy match only "jane.smith@contoso.com" (only Smith surname in mock data)
            $result = Resolve-DirectoryObject -EntityName "smith" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User" -NoPrompt
            
            $result | Should -Be "jane.smith@contoso.com"
        }
        
        It "Auto-accepts single group fuzzy match with NoPrompt" {
            $settings = @{ maxGroupMatchDisplay = 10 }
            $returnValues = @{}
            
            # "Sales" should fuzzy match "Sales Team" (only Sales in mock data)
            $result = Resolve-DirectoryObject -EntityName "Sales" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "Group" -NoPrompt
            
            $result | Should -Be "Sales Team"
        }
    }
    
    Context "Multiple Fuzzy Matches with Menu Selection" {
        It "Returns selected user from multiple fuzzy matches" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{}
            $script:MockMenuResponse = "john.doe@contoso.com"
            
            # "john" should match multiple users (john.doe and john.johnson)
            $result = Resolve-DirectoryObject -EntityName "john" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result | Should -Be "john.doe@contoso.com"
        }
        
        It "Calls menu system once for multiple user matches" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{}
            $script:MockMenuResponse = "john.johnson@contoso.com"
            $script:MenuCallCount = 0
            
            $result = Resolve-DirectoryObject -EntityName "john" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $script:MenuCallCount | Should -Be 1
        }
        
        It "Returns selected group from multiple fuzzy matches" {
            $settings = @{ maxGroupMatchDisplay = 10 }
            $returnValues = @{}
            $script:MockMenuResponse = "Marketing Support"
            
            # "Marketing" should match "Marketing Team" and "Marketing Support"
            $result = Resolve-DirectoryObject -EntityName "Marketing" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "Group"
            
            $result | Should -Be "Marketing Support"
        }
        
        It "Calls menu system once for multiple group matches" {
            $settings = @{ maxGroupMatchDisplay = 10 }
            $returnValues = @{}
            $script:MockMenuResponse = "Marketing Team"
            $script:MenuCallCount = 0
            
            $result = Resolve-DirectoryObject -EntityName "Marketing" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "Group"
            
            $script:MenuCallCount | Should -Be 1
        }
        
        It "Respects maxUserMatchDisplay setting" {
            $settings = @{ maxUserMatchDisplay = 2 }
            $returnValues = @{}
            $script:MockMenuResponse = "john.johnson@contoso.com"
            
            $result = Resolve-DirectoryObject -EntityName "jo" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result | Should -Be "john.johnson@contoso.com"
        }
    }
    
    Context "No Match Scenarios" {
        It "Returns noUserFoundInDirectoryMessage when no user matches" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{ noUserFoundInDirectoryMessage = "User not found" }
            
            $result = Resolve-DirectoryObject -EntityName "nonexistent@contoso.com" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result | Should -Be $returnValues.noUserFoundInDirectoryMessage
        }
        
        It "Returns noUserFoundInDirectoryMessage when no fuzzy matches for user" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{ noUserFoundInDirectoryMessage = "User not found" }
            
            $result = Resolve-DirectoryObject -EntityName "xyz123" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result | Should -Be $returnValues.noUserFoundInDirectoryMessage
        }
        
        It "Returns noGroupFoundMessage when no group matches" {
            $settings = @{ maxGroupMatchDisplay = 10 }
            $returnValues = @{ noGroupFoundMessage = "Group not found" }
            
            $result = Resolve-DirectoryObject -EntityName "NonexistentGroup" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "Group"
            
            $result | Should -Be $returnValues.noGroupFoundMessage
        }
    }
    
    Context "Navigation Scenarios" {
        It "Returns backoutText when user navigates Back" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{ backoutText = "BACK_NAVIGATION" }
            $script:MockMenuResponse = "BACK_NAVIGATION"
            
            $result = Resolve-DirectoryObject -EntityName "john" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result | Should -Be $returnValues.backoutText
        }
        
        It "Returns 'Main Menu' when user selects Main Menu" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{}
            $script:MockMenuResponse = "Main Menu"
            
            $result = Resolve-DirectoryObject -EntityName "john" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result | Should -Be "Main Menu"
        }
        
        It "Returns EXIT_APPLICATION when user selects Exit (0)" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{}
            $script:MockMenuResponse = 0
            
            $result = Resolve-DirectoryObject -EntityName "john" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result | Should -Be "EXIT_APPLICATION"
        }
        
        It "Returns EXIT_APPLICATION when selection is null (converted to 0)" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{}
            $script:MockMenuResponse = $null
            
            $result = Resolve-DirectoryObject -EntityName "john" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result | Should -Be "EXIT_APPLICATION"
        }
        
        It "Returns backoutText for group Back navigation" {
            $settings = @{ maxGroupMatchDisplay = 10 }
            $returnValues = @{ backoutText = "BACK_NAVIGATION" }
            $script:MockMenuResponse = "BACK_NAVIGATION"
            
            $result = Resolve-DirectoryObject -EntityName "Marketing" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "Group"
            
            $result | Should -Be $returnValues.backoutText
        }
        
        It "Returns EXIT_APPLICATION for group Exit navigation" {
            $settings = @{ maxGroupMatchDisplay = 10 }
            $returnValues = @{}
            $script:MockMenuResponse = 0
            
            $result = Resolve-DirectoryObject -EntityName "Marketing" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "Group"
            
            $result | Should -Be "EXIT_APPLICATION"
        }
    }
    
    Context "Settings Validation" {
        It "Handles maxUserMatchDisplay = 1 correctly" {
            $settings = @{ maxUserMatchDisplay = 1 }
            $returnValues = @{}
            $script:MockMenuResponse = "john.doe@contoso.com"
            
            $result = Resolve-DirectoryObject -EntityName "john" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result | Should -Be "john.doe@contoso.com"
        }
        
        It "Handles large maxUserMatchDisplay value" {
            $settings = @{ maxUserMatchDisplay = 9999 }
            $returnValues = @{}
            $script:MockMenuResponse = "john.johnson@contoso.com"
            
            $result = Resolve-DirectoryObject -EntityName "john" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result | Should -Be "john.johnson@contoso.com"
        }
        
        It "Handles maxGroupMatchDisplay = 1 correctly" {
            $settings = @{ maxGroupMatchDisplay = 1 }
            $returnValues = @{}
            $script:MockMenuResponse = "Marketing Team"
            
            $result = Resolve-DirectoryObject -EntityName "Marketing" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "Group"
            
            $result | Should -Be "Marketing Team"
        }
    }
    
    Context "Backward Compatibility" {
        It "Defaults to User entity type when not specified" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{}
            
            $result = Resolve-DirectoryObject -EntityName "john.doe@contoso.com" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues
            
            $result | Should -Be "john.doe@contoso.com"
        }
        
        It "Works with explicit User entity type" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{}
            
            $result = Resolve-DirectoryObject -EntityName "jane.smith@contoso.com" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result | Should -Be "jane.smith@contoso.com"
        }
        
        It "Works with explicit Group entity type" {
            $settings = @{ maxGroupMatchDisplay = 10 }
            $returnValues = @{}
            
            $result = Resolve-DirectoryObject -EntityName "Sales Team" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "Group"
            
            $result | Should -Be "Sales Team"
        }
    }
    
    Context "Complex Navigation Scenarios" {
        It "Handles sequential exact match lookups for different users" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{}
            
            # First lookup
            $result1 = Resolve-DirectoryObject -EntityName "john.doe@contoso.com" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            # Second lookup
            $result2 = Resolve-DirectoryObject -EntityName "jane.smith@contoso.com" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result1 | Should -Be "john.doe@contoso.com"
            $result2 | Should -Be "jane.smith@contoso.com"
        }
        
        It "Handles switching between User and Group lookups" {
            $settings = @{ maxUserMatchDisplay = 10; maxGroupMatchDisplay = 10 }
            $returnValues = @{}
            
            # User lookup
            $result1 = Resolve-DirectoryObject -EntityName "john.doe@contoso.com" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            # Group lookup
            $result2 = Resolve-DirectoryObject -EntityName "Marketing Team" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "Group"
            
            # Another user lookup
            $result3 = Resolve-DirectoryObject -EntityName "jane.smith@contoso.com" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result1 | Should -Be "john.doe@contoso.com"
            $result2 | Should -Be "Marketing Team"
            $result3 | Should -Be "jane.smith@contoso.com"
        }
        
        It "Handles Back navigation followed by successful lookup" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{ backoutText = "Back" }
            
            # First call - simulate Back
            $script:MockMenuResponse = $returnValues.backoutText
            $result1 = Resolve-DirectoryObject -EntityName "john" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            # Second call - successful selection
            Reset-MockData
            $script:MockMenuResponse = "john.doe@contoso.com"
            $result2 = Resolve-DirectoryObject -EntityName "john" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result1 | Should -Be "Back"
            $result2 | Should -Be "john.doe@contoso.com"
        }
        
        It "Handles multiple fuzzy searches with menu selections" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{}
            
            # First fuzzy search
            $script:MockMenuResponse = "john.doe@contoso.com"
            $result1 = Resolve-DirectoryObject -EntityName "john" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            # Second fuzzy search
            Reset-MockData
            $script:MockMenuResponse = "jane.smith@contoso.com"
            $result2 = Resolve-DirectoryObject -EntityName "jane" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result1 | Should -Be "john.doe@contoso.com"
            $result2 | Should -Be "jane.smith@contoso.com"
        }
    }
    
    Context "All Return Value Types" {
        It "Returns exact user match (string)" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{}
            
            $result = Resolve-DirectoryObject -EntityName "john.doe@contoso.com" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result | Should -BeOfType [string]
            $result | Should -Be "john.doe@contoso.com"
        }
        
        It "Returns exact group match (string)" {
            $settings = @{ maxGroupMatchDisplay = 10 }
            $returnValues = @{}
            
            $result = Resolve-DirectoryObject -EntityName "Marketing Team" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "Group"
            
            $result | Should -BeOfType [string]
            $result | Should -Be "Marketing Team"
        }
        
        It "Returns noUserFoundInDirectoryMessage (string)" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{ noUserFoundInDirectoryMessage = "User not found" }
            
            $result = Resolve-DirectoryObject -EntityName "nonexistent@contoso.com" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result | Should -BeOfType [string]
            $result | Should -Be "User not found"
        }
        
        It "Returns noGroupFoundMessage (string)" {
            $settings = @{ maxGroupMatchDisplay = 10 }
            $returnValues = @{ noGroupFoundMessage = "Group not found" }
            
            $result = Resolve-DirectoryObject -EntityName "Nonexistent Group" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "Group"
            
            $result | Should -BeOfType [string]
            $result | Should -Be "Group not found"
        }
        
        It "Returns backoutText (string)" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{ backoutText = "Back" }
            $script:MockMenuResponse = "Back"
            
            $result = Resolve-DirectoryObject -EntityName "john" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result | Should -BeOfType [string]
            $result | Should -Be "Back"
        }
        
        It "Returns 'Main Menu' (string)" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{}
            $script:MockMenuResponse = "Main Menu"
            
            $result = Resolve-DirectoryObject -EntityName "john" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result | Should -BeOfType [string]
            $result | Should -Be "Main Menu"
        }
        
        It "Returns EXIT_APPLICATION constant (string)" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{}
            $script:MockMenuResponse = $null  # Converts to EXIT_APPLICATION in ConvertFrom-DirectoryObjectSelection
            
            $result = Resolve-DirectoryObject -EntityName "john" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            # Function returns 'EXIT_APPLICATION' string, not 0
            $result | Should -BeIn @(0, 'EXIT_APPLICATION')
        }
        
        It "Returns user selection from menu (string)" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{}
            $script:MockMenuResponse = "john.johnson@contoso.com"
            
            $result = Resolve-DirectoryObject -EntityName "john" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result | Should -BeOfType [string]
            $result | Should -Be "john.johnson@contoso.com"
        }
        
        It "Returns group selection from menu (string)" {
            $settings = @{ maxGroupMatchDisplay = 10 }
            $returnValues = @{}
            
            # Add the group to mock data
            Add-MockGroup -DisplayName "Development Team"
            $script:MockMenuResponse = "Development Team"
            
            $result = Resolve-DirectoryObject -EntityName "Dev" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "Group"
            
            $result | Should -BeOfType [string]
            $result | Should -Be "Development Team"
        }
    }
    
    Context "Cache Behavior in Resolution Workflow" {
        It "Benefits from caching on repeated exact lookups" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{}
            
            # First call
            $result1 = Resolve-DirectoryObject -EntityName "john.doe@contoso.com" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            # Second call should use cache
            $result2 = Resolve-DirectoryObject -EntityName "john.doe@contoso.com" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            # Both results should be the same
            $result1 | Should -Be $result2
            $result1 | Should -Be "john.doe@contoso.com"
            # Cache should have at least one entry
            $global:UnifiedCache.DirectoryObjects.Count | Should -BeGreaterThan 0
        }
        
        It "Benefits from caching on repeated fuzzy lookups" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{}
            $script:MockMenuResponse = "john.doe@contoso.com"
            
            # First call
            $result1 = Resolve-DirectoryObject -EntityName "john" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            # Reset menu mock for second call
            $script:MockMenuResponse = "john.doe@contoso.com"
            
            # Second call - fuzzy searches may still show menu but data comes from cache
            $result2 = Resolve-DirectoryObject -EntityName "john" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            # Both results should be consistent
            $result1 | Should -Be "john.doe@contoso.com"
            $result2 | Should -Be "john.doe@contoso.com"
            # Cache should have fuzzy search results
            $global:UnifiedCache.DirectoryObjects.Count | Should -BeGreaterThan 0
        }
    }
    
    Context "Error Handling and Edge Cases" {
        It "Handles empty settings hashtable gracefully" {
            $returnValues = @{ noUserFoundInDirectoryMessage = "User not found" }
            
            # Should not throw when settings is empty hashtable
            { Resolve-DirectoryObject -EntityName "john.doe@contoso.com" -AccessToken "test-token" `
                    -Settings @{} -ReturnValues $returnValues -EntityType "User" } | Should -Not -Throw
        }
        
        It "Handles empty returnValues hashtable gracefully" {
            $settings = @{ maxUserMatchDisplay = 10 }
            
            # Should not throw when returnValues is empty hashtable
            { Resolve-DirectoryObject -EntityName "john.doe@contoso.com" -AccessToken "test-token" `
                    -Settings $settings -ReturnValues @{} -EntityType "User" } | Should -Not -Throw
        }
        
        It "Handles special characters in entity names" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{ noUserFoundInDirectoryMessage = "User not found" }
            
            # Should handle apostrophes
            $result = Resolve-DirectoryObject -EntityName "o'brien@contoso.com" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Handles very long entity names without error" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{ noUserFoundInDirectoryMessage = "User not found" }
            $longName = "verylongusername" * 20 + "@contoso.com"
            
            { Resolve-DirectoryObject -EntityName $longName -AccessToken "test-token" `
                    -Settings $settings -ReturnValues $returnValues -EntityType "User" } | Should -Not -Throw
        }
        
        It "Handles NoPrompt with single fuzzy match for User" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{}
            
            # Add a unique user that will be the only fuzzy match
            Add-MockUser -UserPrincipalName "unique@contoso.com" -DisplayName "Unique User" -GivenName "Unique" -Surname "User"
            
            $result = Resolve-DirectoryObject -EntityName "Unique" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User" -NoPrompt
            
            $result | Should -Be "unique@contoso.com"
        }
        
        It "Handles NoPrompt with single fuzzy match for Group" {
            $settings = @{ maxGroupMatchDisplay = 10 }
            $returnValues = @{}
            
            # Add a unique group that will be the only fuzzy match
            Add-MockGroup -DisplayName "Unique Test Group"
            
            $result = Resolve-DirectoryObject -EntityName "Unique Test" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "Group" -NoPrompt
            
            $result | Should -Be "Unique Test Group"
        }
    }
}

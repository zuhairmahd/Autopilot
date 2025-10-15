BeforeAll {
    # Get repository root
    $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    
    # Load the function under test
    . (Join-Path $script:RepoRoot "functions/UserAndGroupFunctions/Resolve-DirectoryObject.ps1")
    . (Join-Path $script:RepoRoot "functions/UserAndGroupFunctions/ConvertFrom-DirectoryObjectSelection.ps1")
    . (Join-Path $script:RepoRoot "functions/UserAndGroupFunctions/Get-EntraDirectoryObject.ps1")
    . (Join-Path $script:RepoRoot "functions/UserAndGroupFunctions/Show-DirectoryObjectList.ps1")
    
    # Import the Graph mocking module
    Import-Module (Join-Path $script:RepoRoot "tests/Helpers/AutopilotGraphMocks.psm1") -Force
    
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
        
        # Clear cache
        if (Get-Variable -Name DirectoryObjectCache -Scope Global -ErrorAction SilentlyContinue)
        {
            $global:DirectoryObjectCache = @{}
        }
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
}

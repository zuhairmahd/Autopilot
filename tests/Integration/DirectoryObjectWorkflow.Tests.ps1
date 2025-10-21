<#
.SYNOPSIS
    Integration tests for complete Directory Object workflows (Users and Groups)

.DESCRIPTION
    Tests end-to-end workflows for user and group lookup, fuzzy matching,
    and selection processes. Validates the integration between:
    - Get-EntraDirectoryObject (search and cache)
    - Show-DirectoryObjectList (display and menu)
    - Resolve-DirectoryObject (complete workflow)
    - ConvertFrom-DirectoryObjectSelection (result processing)

.NOTES
    Test Category: Integration
    Dependencies: All UserAndGroupFunctions, AutopilotGraphMocks, AutopilotMenuMocks
#>

BeforeAll {
    # Get repository root
    $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    
    # Load all directory object functions
    . (Join-Path $script:RepoRoot "functions/UserAndGroupFunctions/Get-EntraDirectoryObject.ps1")
    . (Join-Path $script:RepoRoot "functions/UserAndGroupFunctions/Show-DirectoryObjectList.ps1")
    . (Join-Path $script:RepoRoot "functions/UserAndGroupFunctions/Resolve-DirectoryObject.ps1")
    . (Join-Path $script:RepoRoot "functions/UserAndGroupFunctions/ConvertFrom-DirectoryObjectSelection.ps1")
    
    # Import mocking infrastructure
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
        return $script:MockMenuResponse
    }
    
    # Mock Read-Host for confirmation prompts
    function global:Read-Host
    {
        param([string]$Prompt)
        return "Y"
    }
}

AfterAll {
    Clear-GraphMockEnvironment
}

Describe "Directory Object Workflow Integration" -Tag 'Integration', 'DirectoryObject' {
    
    BeforeEach {
        # Reset for each test
        Reset-MockData -IncludeUsers -IncludeGroups
        $script:MockMenuResponse = $null
        
        # Clear cache
        if (Get-Variable -Name DirectoryObjectCache -Scope Global -ErrorAction SilentlyContinue)
        {
            $global:DirectoryObjectCache = @{}
        }
    }
    
    Context "End-to-end User Lookup Workflows" {
        
        It "Should complete exact user match workflow" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{ noUserFoundInDirectoryMessage = "User not found" }
            
            # Complete workflow: search -> find exact -> return
            $result = Resolve-DirectoryObject -EntityName "john.doe@contoso.com" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result | Should -Be "john.doe@contoso.com"
        }
        
        It "Should complete fuzzy user match workflow with single result" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{}
            
            # Add a unique user for single fuzzy match
            Add-MockUser -UserPrincipalName "alice.unique@contoso.com" -DisplayName "Alice Unique" -GivenName "Alice" -Surname "Unique"
            
            # Complete workflow: search -> fuzzy find single -> auto-accept
            $result = Resolve-DirectoryObject -EntityName "Alice" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User" -NoPrompt
            
            $result | Should -Be "alice.unique@contoso.com"
        }
        
        It "Should complete fuzzy user match workflow with menu selection" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{}
            $script:MockMenuResponse = "john.johnson@contoso.com"
            
            # Complete workflow: search -> fuzzy find multiple -> show menu -> select
            $result = Resolve-DirectoryObject -EntityName "john" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result | Should -Be "john.johnson@contoso.com"
        }
        
        It "Should handle user not found workflow" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{ noUserFoundInDirectoryMessage = "User not found" }
            
            # Complete workflow: search -> not found -> return message
            $result = Resolve-DirectoryObject -EntityName "nonexistent@contoso.com" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result | Should -Be "User not found"
        }
        
        It "Should handle user workflow with Back navigation" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{ backoutText = "Back" }
            $script:MockMenuResponse = "Back"
            
            # Complete workflow: search -> fuzzy find -> show menu -> back
            $result = Resolve-DirectoryObject -EntityName "john" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result | Should -Be "Back"
        }
    }
    
    Context "End-to-end Group Lookup Workflows" {
        
        It "Should complete exact group match workflow" {
            $settings = @{ maxGroupMatchDisplay = 10 }
            $returnValues = @{ noGroupFoundMessage = "Group not found" }
            
            # Complete workflow: search -> find exact -> return
            $result = Resolve-DirectoryObject -EntityName "Marketing Team" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "Group"
            
            $result | Should -Be "Marketing Team"
        }
        
        It "Should complete fuzzy group match workflow with single result" {
            $settings = @{ maxGroupMatchDisplay = 10 }
            $returnValues = @{}
            
            # Add a unique group for single fuzzy match
            Add-MockGroup -DisplayName "Unique Project Team"
            
            # Complete workflow: search -> fuzzy find single -> auto-accept
            $result = Resolve-DirectoryObject -EntityName "Unique Project" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "Group" -NoPrompt
            
            $result | Should -Be "Unique Project Team"
        }
        
        It "Should complete fuzzy group match workflow with menu selection" {
            $settings = @{ maxGroupMatchDisplay = 10 }
            $returnValues = @{}
            
            # Add test group
            Add-MockGroup -DisplayName "Test Group A"
            $script:MockMenuResponse = "Test Group A"
            
            # Complete workflow: search -> fuzzy find multiple -> show menu -> select
            $result = Resolve-DirectoryObject -EntityName "Test" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "Group"
            
            $result | Should -Be "Test Group A"
        }
        
        It "Should handle group not found workflow" {
            $settings = @{ maxGroupMatchDisplay = 10 }
            $returnValues = @{ noGroupFoundMessage = "Group not found" }
            
            # Complete workflow: search -> not found -> return message
            $result = Resolve-DirectoryObject -EntityName "Nonexistent Group" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "Group"
            
            $result | Should -Be "Group not found"
        }
        
        It "Should handle group workflow with Main Menu navigation" {
            $settings = @{ maxGroupMatchDisplay = 10 }
            $returnValues = @{}
            
            # Need multiple groups starting with 'Marketing' for menu to show
            Add-MockGroup -DisplayName "Marketing Operations"
            Add-MockGroup -DisplayName "Marketing Analysis"
            $script:MockMenuResponse = "Main Menu"
            
            # Complete workflow: search -> fuzzy find -> show menu -> main menu
            $result = Resolve-DirectoryObject -EntityName "Marketing" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "Group"
            
            $result | Should -Be "Main Menu"
        }
    }
    
    Context "Fuzzy Matching Integration" {
        
        It "Should perform startswith matching for users" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{}
            
            # Add user with first name starting with 'Al'
            Add-MockUser -UserPrincipalName "albert@contoso.com" -DisplayName "Albert Einstein" -GivenName "Albert" -Surname "Einstein"
            
            $script:MockMenuResponse = "albert@contoso.com"
            
            $result = Resolve-DirectoryObject -EntityName "Al" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result | Should -Be "albert@contoso.com"
        }
        
        It "Should apply exclusion patterns to users" {
            $settings = @{
                maxUserMatchDisplay   = 10
                userPatternsToExclude = @('^admin', 'test')
            }
            $returnValues = @{}
            
            # Add users including ones that should be excluded
            Add-MockUser -UserPrincipalName "admin.user@contoso.com" -DisplayName "Admin User" -GivenName "Admin" -Surname "User"
            Add-MockUser -UserPrincipalName "testuser@contoso.com" -DisplayName "Test User" -GivenName "Test" -Surname "User"
            Add-MockUser -UserPrincipalName "alice@contoso.com" -DisplayName "Alice Smith" -GivenName "Alice" -Surname "Smith"
            
            $script:MockMenuResponse = "alice@contoso.com"
            
            # Search should exclude admin and test users
            $result = Resolve-DirectoryObject -EntityName "a" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result | Should -Be "alice@contoso.com"
        }
        
        It "Should apply exclusion patterns to groups" {
            $settings = @{
                maxGroupMatchDisplay   = 10
                groupPatternsToExclude = @('Archive', 'Disabled')
            }
            $returnValues = @{}
            
            # Add groups including ones that should be excluded
            Add-MockGroup -DisplayName "Archive - Old Team"
            Add-MockGroup -DisplayName "Disabled Users Group"
            Add-MockGroup -DisplayName "Active Project Team"
            
            $script:MockMenuResponse = "Active Project Team"
            
            # Search should exclude archived and disabled groups
            $result = Resolve-DirectoryObject -EntityName "Team" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "Group"
            
            $result | Should -Be "Active Project Team"
        }
    }
    
    Context "Cache Integration Across Workflow" {
        
        It "Should cache user results across workflow steps" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{}
            
            # First lookup
            $result1 = Resolve-DirectoryObject -EntityName "john.doe@contoso.com" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            # Cache should be populated
            $global:DirectoryObjectCache.Count | Should -BeGreaterThan 0
            
            # Second lookup should use cache
            $result2 = Resolve-DirectoryObject -EntityName "john.doe@contoso.com" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result1 | Should -Be $result2
        }
        
        It "Should cache group results across workflow steps" {
            $settings = @{ maxGroupMatchDisplay = 10 }
            $returnValues = @{}
            
            # First lookup
            $result1 = Resolve-DirectoryObject -EntityName "Marketing Team" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "Group"
            
            # Cache should be populated
            $global:DirectoryObjectCache.Count | Should -BeGreaterThan 0
            
            # Second lookup should use cache
            $result2 = Resolve-DirectoryObject -EntityName "Marketing Team" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "Group"
            
            $result1 | Should -Be $result2
        }
        
        It "Should maintain separate cache entries for users and groups" {
            $settings = @{ maxUserMatchDisplay = 10; maxGroupMatchDisplay = 10 }
            $returnValues = @{}
            
            # Lookup user
            Resolve-DirectoryObject -EntityName "john.doe@contoso.com" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            # Lookup group
            Resolve-DirectoryObject -EntityName "Marketing Team" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "Group"
            
            # Cache should have entries for both
            $global:DirectoryObjectCache.Count | Should -BeGreaterOrEqual 2
        }
    }
    
    Context "Error Handling and Recovery" {
        
        It "Should handle API errors gracefully in workflow" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{ noUserFoundInDirectoryMessage = "User not found" }
            
            # Mock API error
            Mock CallGraphAPI {
                return 401
            }
            
            # Workflow should handle error and return message
            $result = Resolve-DirectoryObject -EntityName "test@contoso.com" -AccessToken "invalid-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result | Should -Be "User not found"
        }
        
        It "Should recover from failed lookup and retry" {
            $settings = @{ maxUserMatchDisplay = 10 }
            $returnValues = @{ noUserFoundInDirectoryMessage = "User not found" }
            
            # First lookup fails
            $result1 = Resolve-DirectoryObject -EntityName "nonexistent@contoso.com" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            # Second lookup succeeds
            $result2 = Resolve-DirectoryObject -EntityName "john.doe@contoso.com" -AccessToken "test-token" `
                -Settings $settings -ReturnValues $returnValues -EntityType "User"
            
            $result1 | Should -Be "User not found"
            $result2 | Should -Be "john.doe@contoso.com"
        }
    }
}

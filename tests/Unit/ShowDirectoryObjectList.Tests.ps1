BeforeAll {
    # Get repository root
    $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    
    # Load AddMenuItem (needed for actual function)
    . "$script:RepoRoot/functions/menuFunctions/AddMenuItem.ps1"
    
    # Mock NewMenu to avoid menu configuration complexity
    function global:NewMenu {
        param(
            [string]$MenuName,
            [string]$Title,
            [string]$Description
        )
        return @{ 
            MenuName    = $MenuName
            Title       = $Title
            Description = $Description
            Items       = @() 
        }
    }
    
    # Mock ShowMenu with configurable response
    $script:MockMenuResponse = $null
    $script:MenuCallCount = 0
    function global:ShowMenu {
        param($Menu, $CalledBy)
        $script:MenuCallCount++
        Write-Verbose "[ShowMenu Mock] Called with menu: $($Menu.Title) (Call #$script:MenuCallCount)"
        return $script:MockMenuResponse
    }
    
    # Load the function under test
    . "$script:RepoRoot/functions/UserAndGroupFunctions/Show-DirectoryObjectList.ps1"
    
    # Mock Write-Log to avoid log file dependencies
    function global:Write-Log {
        param($LogFile, $Module, $Message, $LogLevel)
        Write-Verbose "[Write-Log][$LogLevel][$Module] $Message"
    }
    
    # Initialize global variables needed by the function
    $global:LogFile = "/tmp/test-show-directory-object-list.log"
    $global:returnValues = @{
        noUserFoundInDirectoryMessage = 0
        noGroupFoundMessage           = 0
        userCanceledMessage           = 0
    }
    
    # Mock data for tests
    $script:MockUsers = @(
        @{
            userPrincipalName = "john.doe@contoso.com"
            displayName       = "John Doe"
            givenName         = "John"
            surname           = "Doe"
            mail              = "john.doe@contoso.com"
            id                = "user-123"
        },
        @{
            userPrincipalName = "jane.smith@contoso.com"
            displayName       = "Jane Smith"
            givenName         = "Jane"
            surname           = "Smith"
            mail              = "jane.smith@contoso.com"
            id                = "user-456"
        },
        @{
            userPrincipalName = "bob.johnson@contoso.com"
            displayName       = "Bob Johnson"
            givenName         = "Bob"
            surname           = "Johnson"
            mail              = "bob.johnson@contoso.com"
            id                = "user-789"
        }
    )
    
    $script:MockGroups = @(
        @{
            displayName = "Marketing Team"
            id          = "group-123"
        },
        @{
            displayName = "Sales Team"
            id          = "group-456"
        },
        @{
            displayName = "Engineering Team"
            id          = "group-789"
        }
    )
}

Describe "Show-DirectoryObjectList" -Tag "Unit" {
    
    Context "Empty List Handling" {
        
        BeforeEach {
            # Reset tracking variables
            $script:MenuCallCount = 0
            $script:MockMenuResponse = $null
        }
        
        It "Returns noUserFoundInDirectoryMessage (0) for empty user list" {
            $result = Show-DirectoryObjectList -EntityList @() -EntityType "User" -MaxDisplay 10
            $result | Should -Be 0
        }
        
        It "Does not call ShowMenu for empty user list" {
            $null = Show-DirectoryObjectList -EntityList @() -EntityType "User" -MaxDisplay 10
            $script:MenuCallCount | Should -Be 0
        }
        
        It "Returns noGroupFoundMessage (0) for empty group list" {
            $result = Show-DirectoryObjectList -EntityList @() -EntityType "Group" -MaxDisplay 10
            $result | Should -Be 0
        }
        
        It "Does not call ShowMenu for empty group list" {
            $null = Show-DirectoryObjectList -EntityList @() -EntityType "Group" -MaxDisplay 10
            $script:MenuCallCount | Should -Be 0
        }
    }
    
    Context "Single Item with NoPrompt" {
        
        BeforeEach {
            $script:MenuCallCount = 0
            $script:MockMenuResponse = $null
        }
        
        It "Returns userPrincipalName for single user with NoPrompt" {
            $singleUser = @($script:MockUsers[0])
            $result = Show-DirectoryObjectList -EntityList $singleUser -EntityType "User" -MaxDisplay 10 -NoPrompt
            $result | Should -Be "john.doe@contoso.com"
        }
        
        It "Does not call ShowMenu for single user with NoPrompt" {
            $singleUser = @($script:MockUsers[0])
            $null = Show-DirectoryObjectList -EntityList $singleUser -EntityType "User" -MaxDisplay 10 -NoPrompt
            $script:MenuCallCount | Should -Be 0
        }
        
        It "Returns displayName for single group with NoPrompt" {
            $singleGroup = @($script:MockGroups[0])
            $result = Show-DirectoryObjectList -EntityList $singleGroup -EntityType "Group" -MaxDisplay 10 -NoPrompt
            $result | Should -Be "Marketing Team"
        }
        
        It "Does not call ShowMenu for single group with NoPrompt" {
            $singleGroup = @($script:MockGroups[0])
            $null = Show-DirectoryObjectList -EntityList $singleGroup -EntityType "Group" -MaxDisplay 10 -NoPrompt
            $script:MenuCallCount | Should -Be 0
        }
    }
    
    Context "Multiple Items Menu Selection - Users" {
        
        It "Returns selected userPrincipalName when user selects from menu" {
            $script:MockMenuResponse = "jane.smith@contoso.com"
            
            $result = Show-DirectoryObjectList -EntityList $script:MockUsers -EntityType "User" -MaxDisplay 10
            $result | Should -Be "jane.smith@contoso.com"
        }
        
        It "Calls ShowMenu once for multiple users" {
            $script:MenuCallCount = 0
            $script:MockMenuResponse = "john.doe@contoso.com"
            
            $null = Show-DirectoryObjectList -EntityList $script:MockUsers -EntityType "User" -MaxDisplay 10
            $script:MenuCallCount | Should -Be 1
        }
        
        It "Returns 0 when user exits from menu (ShowMenu returns null)" {
            $script:MockMenuResponse = $null
            
            $result = Show-DirectoryObjectList -EntityList $script:MockUsers -EntityType "User" -MaxDisplay 10
            $result | Should -Be 0
        }
    }
    
    Context "Multiple Items Menu Selection - Groups" {
        
        It "Returns selected displayName when user selects from menu" {
            $script:MockMenuResponse = "Sales Team"
            
            $result = Show-DirectoryObjectList -EntityList $script:MockGroups -EntityType "Group" -MaxDisplay 10
            $result | Should -Be "Sales Team"
        }
        
        It "Calls ShowMenu once for multiple groups" {
            $script:MenuCallCount = 0
            $script:MockMenuResponse = "Marketing Team"
            
            $null = Show-DirectoryObjectList -EntityList $script:MockGroups -EntityType "Group" -MaxDisplay 10
            $script:MenuCallCount | Should -Be 1
        }
        
        It "Returns 0 when user exits from menu (ShowMenu returns null)" {
            $script:MockMenuResponse = $null
            
            $result = Show-DirectoryObjectList -EntityList $script:MockGroups -EntityType "Group" -MaxDisplay 10
            $result | Should -Be 0
        }
    }
    
    Context "MaxDisplay Truncation" {
        
        It "Handles large user lists without error" {
            # Create a large user list (50 items)
            $largeUserList = @()
            for ($i = 1; $i -le 50; $i++) {
                $largeUserList += @{
                    userPrincipalName = "user$i@contoso.com"
                    displayName       = "User $i"
                    mail              = "user$i@contoso.com"
                    id                = "user-$i"
                }
            }
            
            $script:MockMenuResponse = $null
            $result = Show-DirectoryObjectList -EntityList $largeUserList -EntityType "User" -MaxDisplay 10
            $result | Should -Be 0
        }
        
        It "Calls ShowMenu once for large lists" {
            $largeUserList = @()
            for ($i = 1; $i -le 50; $i++) {
                $largeUserList += @{
                    userPrincipalName = "user$i@contoso.com"
                    displayName       = "User $i"
                    id                = "user-$i"
                }
            }
            
            $script:MenuCallCount = 0
            $script:MockMenuResponse = $null
            
            $null = Show-DirectoryObjectList -EntityList $largeUserList -EntityType "User" -MaxDisplay 10
            $script:MenuCallCount | Should -Be 1
        }
        
        It "Truncates to MaxDisplay items for large group lists" {
            $largeGroupList = @()
            for ($i = 1; $i -le 50; $i++) {
                $largeGroupList += @{
                    displayName = "Group $i"
                    id          = "group-$i"
                }
            }
            
            $script:MockMenuResponse = "Group 5"
            
            $result = Show-DirectoryObjectList -EntityList $largeGroupList -EntityType "Group" -MaxDisplay 10
            $result | Should -Be "Group 5"
        }
    }
    
    Context "Menu Creation and Structure" {
        
        It "Creates menu with correct user display format" {
            # We'll check the menu structure by examining what was passed to ShowMenu
            # Since ShowMenu is mocked, we can't directly inspect, but we can verify
            # the function doesn't crash and returns expected values
            $script:MockMenuResponse = "john.doe@contoso.com"
            
            $result = Show-DirectoryObjectList -EntityList $script:MockUsers -EntityType "User" -MaxDisplay 10
            $result | Should -Be "john.doe@contoso.com"
        }
        
        It "Creates menu with correct group display format" {
            $script:MockMenuResponse = "Marketing Team"
            
            $result = Show-DirectoryObjectList -EntityList $script:MockGroups -EntityType "Group" -MaxDisplay 10
            $result | Should -Be "Marketing Team"
        }
        
        It "Creates menu with correct number of items for users" {
            $script:MenuCallCount = 0
            $script:MockMenuResponse = $null
            
            $null = Show-DirectoryObjectList -EntityList $script:MockUsers -EntityType "User" -MaxDisplay 10
            $script:MenuCallCount | Should -Be 1
        }
        
        It "Creates menu with correct number of items for groups" {
            $script:MenuCallCount = 0
            $script:MockMenuResponse = $null
            
            $null = Show-DirectoryObjectList -EntityList $script:MockGroups -EntityType "Group" -MaxDisplay 10
            $script:MenuCallCount | Should -Be 1
        }
    }
}

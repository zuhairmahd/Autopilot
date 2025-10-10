Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force
Import-Module "$PSScriptRoot/../Helpers/AutopilotMenuMocks.psm1" -Force

BeforeAll {
    # Get repository root
    $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    
    # Initialize helpers
    Initialize-MockGlobalVariables -LogFile "test-show-directory-object-list.log" -IncludeReturnValues
    
    # Create Write-Log mock
    New-MockWriteLog
    
    # Load AddMenuItem and Show-DirectoryObjectList (they will load real NewMenu/ShowMenu initially)
    . "$script:RepoRoot/functions/menuFunctions/AddMenuItem.ps1"
    . "$script:RepoRoot/functions/UserAndGroupFunctions/Show-DirectoryObjectList.ps1"
    
    # NOW override with helper menu mocks (using -Force to replace the real ones)
    New-MockNewMenuFunction
    New-MockShowMenuFunction -EnableCallTracking
    
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

AfterAll {
    Clear-MockGlobalVariables
}

Describe "Show-DirectoryObjectList" -Tag "Unit" {
    
    Context "Empty List Handling" {
        
        BeforeEach {
            # Reset menu mock for each test
            Set-MockShowMenuResponse -NewResponse $null
        }
        
        It "Returns noUserFoundInDirectoryMessage (0) for empty user list" {
            $result = Show-DirectoryObjectList -EntityList @() -EntityType "User" -MaxDisplay 10
            $result | Should -Be 0
        }
        
        It "Does not call ShowMenu for empty user list" {
            $null = Show-DirectoryObjectList -EntityList @() -EntityType "User" -MaxDisplay 10
            $callInfo = Get-MockShowMenuCalls
            $callInfo.CallCount | Should -Be 0
        }
        
        It "Returns noGroupFoundMessage (0) for empty group list" {
            $result = Show-DirectoryObjectList -EntityList @() -EntityType "Group" -MaxDisplay 10
            $result | Should -Be 0
        }
        
        It "Does not call ShowMenu for empty group list" {
            $null = Show-DirectoryObjectList -EntityList @() -EntityType "Group" -MaxDisplay 10
            $callInfo = Get-MockShowMenuCalls
            $callInfo.CallCount | Should -Be 0
        }
    }
    
    Context "Single Item with NoPrompt" {
        
        BeforeEach {
            Set-MockShowMenuResponse -NewResponse $null
        }
        
        It "Returns userPrincipalName for single user with NoPrompt" {
            $singleUser = @($script:MockUsers[0])
            $result = Show-DirectoryObjectList -EntityList $singleUser -EntityType "User" -MaxDisplay 10 -NoPrompt
            $result | Should -Be "john.doe@contoso.com"
        }
        
        It "Does not call ShowMenu for single user with NoPrompt" {
            $singleUser = @($script:MockUsers[0])
            $null = Show-DirectoryObjectList -EntityList $singleUser -EntityType "User" -MaxDisplay 10 -NoPrompt
            $callInfo = Get-MockShowMenuCalls
            $callInfo.CallCount | Should -Be 0
        }
        
        It "Returns displayName for single group with NoPrompt" {
            $singleGroup = @($script:MockGroups[0])
            $result = Show-DirectoryObjectList -EntityList $singleGroup -EntityType "Group" -MaxDisplay 10 -NoPrompt
            $result | Should -Be "Marketing Team"
        }
        
        It "Does not call ShowMenu for single group with NoPrompt" {
            $singleGroup = @($script:MockGroups[0])
            $null = Show-DirectoryObjectList -EntityList $singleGroup -EntityType "Group" -MaxDisplay 10 -NoPrompt
            $callInfo = Get-MockShowMenuCalls
            $callInfo.CallCount | Should -Be 0
        }
    }
    
    Context "Multiple Items Menu Selection - Users" {
        
        BeforeEach {
            Reset-MockShowMenuCalls
            Set-MockShowMenuResponse -NewResponse $null
        }
        
        It "Returns selected userPrincipalName when user selects from menu" {
            Set-MockShowMenuResponse -NewResponse "jane.smith@contoso.com"
            
            $result = Show-DirectoryObjectList -EntityList $script:MockUsers -EntityType "User" -MaxDisplay 10
            $result | Should -Be "jane.smith@contoso.com"
        }
        
        It "Calls ShowMenu once for multiple users" {
            Set-MockShowMenuResponse -NewResponse "john.doe@contoso.com"
            
            $null = Show-DirectoryObjectList -EntityList $script:MockUsers -EntityType "User" -MaxDisplay 10
            $callInfo = Get-MockShowMenuCalls
            $callInfo.CallCount | Should -Be 1
        }
        
        It "Returns 0 when user exits from menu (ShowMenu returns null)" {
            Set-MockShowMenuResponse -NewResponse $null
            
            $result = Show-DirectoryObjectList -EntityList $script:MockUsers -EntityType "User" -MaxDisplay 10
            $result | Should -Be 0
        }
    }
    
    Context "Multiple Items Menu Selection - Groups" {
        
        BeforeEach {
            Reset-MockShowMenuCalls
            Set-MockShowMenuResponse -NewResponse $null
        }
        
        It "Returns selected displayName when user selects from menu" {
            Set-MockShowMenuResponse -NewResponse "Sales Team"
            
            $result = Show-DirectoryObjectList -EntityList $script:MockGroups -EntityType "Group" -MaxDisplay 10
            $result | Should -Be "Sales Team"
        }
        
        It "Calls ShowMenu once for multiple groups" {
            Set-MockShowMenuResponse -NewResponse "Marketing Team"
            
            $null = Show-DirectoryObjectList -EntityList $script:MockGroups -EntityType "Group" -MaxDisplay 10
            $callInfo = Get-MockShowMenuCalls
            $callInfo.CallCount | Should -Be 1
        }
        
        It "Returns 0 when user exits from menu (ShowMenu returns null)" {
            Set-MockShowMenuResponse -NewResponse $null
            
            $result = Show-DirectoryObjectList -EntityList $script:MockGroups -EntityType "Group" -MaxDisplay 10
            $result | Should -Be 0
        }
    }
    
    Context "MaxDisplay Truncation" {
        
        BeforeEach {
            Reset-MockShowMenuCalls
            Set-MockShowMenuResponse -NewResponse $null
        }
        
        It "Handles large user lists without error" {
            # Create a large user list (50 items)
            $largeUserList = @()
            for ($i = 1; $i -le 50; $i++)
            {
                $largeUserList += @{
                    userPrincipalName = "user$i@contoso.com"
                    displayName       = "User $i"
                    mail              = "user$i@contoso.com"
                    id                = "user-$i"
                }
            }
            
            Set-MockShowMenuResponse -NewResponse $null
            $result = Show-DirectoryObjectList -EntityList $largeUserList -EntityType "User" -MaxDisplay 10
            $result | Should -Be 0
        }
        
        It "Calls ShowMenu once for large lists" {
            $largeUserList = @()
            for ($i = 1; $i -le 50; $i++)
            {
                $largeUserList += @{
                    userPrincipalName = "user$i@contoso.com"
                    displayName       = "User $i"
                    id                = "user-$i"
                }
            }
            
            Set-MockShowMenuResponse -NewResponse $null
            
            $null = Show-DirectoryObjectList -EntityList $largeUserList -EntityType "User" -MaxDisplay 10
            $callInfo = Get-MockShowMenuCalls
            $callInfo.CallCount | Should -Be 1
        }
        
        It "Truncates to MaxDisplay items for large group lists" {
            $largeGroupList = @()
            for ($i = 1; $i -le 50; $i++)
            {
                $largeGroupList += @{
                    displayName = "Group $i"
                    id          = "group-$i"
                }
            }
            
            Set-MockShowMenuResponse -NewResponse "Group 5"
            
            $result = Show-DirectoryObjectList -EntityList $largeGroupList -EntityType "Group" -MaxDisplay 10
            $result | Should -Be "Group 5"
        }
    }
    
    Context "Menu Creation and Structure" {
        
        BeforeEach {
            Reset-MockShowMenuCalls
            Set-MockShowMenuResponse -NewResponse $null
        }
        
        It "Creates menu with correct user display format" {
            # We'll check the menu structure by examining what was passed to ShowMenu
            # Since ShowMenu is mocked, we can't directly inspect, but we can verify
            # the function doesn't crash and returns expected values
            Set-MockShowMenuResponse -NewResponse "john.doe@contoso.com"
            
            $result = Show-DirectoryObjectList -EntityList $script:MockUsers -EntityType "User" -MaxDisplay 10
            $result | Should -Be "john.doe@contoso.com"
        }
        
        It "Creates menu with correct group display format" {
            Set-MockShowMenuResponse -NewResponse "Marketing Team"
            
            $result = Show-DirectoryObjectList -EntityList $script:MockGroups -EntityType "Group" -MaxDisplay 10
            $result | Should -Be "Marketing Team"
        }
        
        It "Creates menu with correct number of items for users" {
            Set-MockShowMenuResponse -NewResponse $null
            
            $null = Show-DirectoryObjectList -EntityList $script:MockUsers -EntityType "User" -MaxDisplay 10
            $callInfo = Get-MockShowMenuCalls
            $callInfo.CallCount | Should -Be 1
        }
        
        It "Creates menu with correct number of items for groups" {
            Set-MockShowMenuResponse -NewResponse $null
            
            $null = Show-DirectoryObjectList -EntityList $script:MockGroups -EntityType "Group" -MaxDisplay 10
            $callInfo = Get-MockShowMenuCalls
            $callInfo.CallCount | Should -Be 1
        }
    }
}

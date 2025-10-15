<#
.SYNOPSIS
    Menu system mocking infrastructure for Autopilot Pester tests

.DESCRIPTION
    Provides comprehensive mocking for menu-related tests including:
    - Mock menu structure generation
    - Menu environment initialization
    - Common menu function mocks
    - Return values and navigation patterns

.NOTES
    Author: Autopilot Test Framework
    Version: 1.0.0
    Compatible with: PowerShell 5.1+, Pester 5.x
#>

#region Menu Structure Mocks

<#
.SYNOPSIS
    Creates a standard mock menu structure for testing

.DESCRIPTION
    Generates a hierarchical menu structure with various display modes,
    nested submenus, and different menu item types for comprehensive testing

.PARAMETER AppModes
    Array of app modes to include in menu items. Defaults to @("helpdesk", "admin")

.PARAMETER IncludeNestedMenus
    Include deeply nested menu structures (2+ levels deep)

.PARAMETER IncludeActions
    Include action-type menu items

.PARAMETER IncludeSubmenus
    Include submenu-type menu items

.EXAMPLE
    $menus = New-MockMenuStructure
    # Creates standard menu structure with all item types

.EXAMPLE
    $menus = New-MockMenuStructure -AppModes @("helpdesk")
    # Creates menu structure filtered for helpdesk mode only
#>
function New-MockMenuStructure
{
    [CmdletBinding()]
    param(
        [string[]]$AppModes = @("helpdesk", "admin"),
        [switch]$IncludeNestedMenus,
        [switch]$IncludeActions,
        [switch]$IncludeSubmenus
    )
    
    # Default switches to true if not explicitly set to false
    if (-not $PSBoundParameters.ContainsKey('IncludeNestedMenus')) { $IncludeNestedMenus = $true }
    if (-not $PSBoundParameters.ContainsKey('IncludeActions')) { $IncludeActions = $true }
    if (-not $PSBoundParameters.ContainsKey('IncludeSubmenus')) { $IncludeSubmenus = $true }
    
    $menus = @()
    
    # Action menu items (if enabled)
    if ($IncludeActions)
    {
        $menus += [PSCustomObject]@{
            name                  = "Give a device to a user"
            description           = "Start the user and device readiness check"
            type                  = "action"
            includeInDisplayModes = @("helpdesk")
        }
        
        $menus += [PSCustomObject]@{
            name                  = "Admin Only Menu"
            description           = "Admin only functionality"
            type                  = "action"
            includeInDisplayModes = @("admin")
        }
    }
    
    # Submenu items (if enabled)
    if ($IncludeSubmenus)
    {
        $submenuItems = @()
        
        if ($IncludeNestedMenus)
        {
            # Nested submenu (2 levels deep)
            $submenuItems += [PSCustomObject]@{
                name                  = "Lookup device by Serial Number"
                description           = "Lookup a device by its serial number"
                type                  = "submenu"
                includeInDisplayModes = @("helpdesk")
                items                 = @(
                    [PSCustomObject]@{
                        name                  = "Enter a serial number"
                        description           = "Lookup a device by its serial number"
                        type                  = "action"
                        includeInDisplayModes = @("helpdesk")
                    }
                )
            }
        }
        
        $menus += [PSCustomObject]@{
            name                  = "Check device status"
            description           = "Troubleshoot a device"
            type                  = "submenu"
            includeInDisplayModes = @("helpdesk", "admin")
            items                 = $submenuItems
        }
    }
    
    return $menus
}

<#
.SYNOPSIS
    Creates a mock return values structure

.DESCRIPTION
    Generates the standard return values hashtable used for navigation
    and status code handling throughout the application

.EXAMPLE
    $returnValues = New-MockReturnValues
#>
function New-MockReturnValues
{
    [CmdletBinding()]
    param()
    
    return @{
        noUserFoundInDirectoryMessage = 0
        noGroupFoundMessage           = 0
        userCanceledMessage           = 0
        mainMenuMessage               = 1
        backMessage                   = 2
        exitMessage                   = 3
        continueMessage               = 4
    }
}

#endregion

#region Menu Environment Initialization

<#
.SYNOPSIS
    Initializes the menu test environment with global variables

.DESCRIPTION
    Sets up all global variables required by menu functions including
    MenuHistory, History, settings, and LogFile

.PARAMETER AppMode
    The application mode to set (e.g., "helpdesk", "admin", "full")

.PARAMETER LogFile
    Optional custom log file path. Defaults to temp location

.PARAMETER Settings
    Optional custom settings hashtable. Merged with defaults

.EXAMPLE
    Initialize-MenuTestEnvironment -AppMode "helpdesk"
    # Sets up globals for helpdesk mode testing

.EXAMPLE
    $customSettings = @{ maxUserMatchDisplay = 20 }
    Initialize-MenuTestEnvironment -AppMode "admin" -Settings $customSettings
#>
function Initialize-MenuTestEnvironment
{
    [CmdletBinding()]
    param(
        [string]$AppMode = "helpdesk",
        [string]$LogFile = $null,
        [hashtable]$Settings = @{}
    )
    
    # Set log file
    if (-not $LogFile)
    {
        $tempPath = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
        $LogFile = Join-Path $tempPath "autopilot-menu-test-$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    }
    $Global:LogFile = $LogFile
    
    # Initialize menu history as ArrayLists to support .RemoveAt() operations
    $Global:MenuHistory = [System.Collections.ArrayList]::new()
    $Global:History = [System.Collections.ArrayList]::new()
    
    # Initialize settings with defaults
    $defaultSettings = @{
        appMode              = $AppMode
        maxUserMatchDisplay  = 10
        maxGroupMatchDisplay = 10
        logLevel             = "Info"
    }
    
    # Merge custom settings
    foreach ($key in $Settings.Keys)
    {
        $defaultSettings[$key] = $Settings[$key]
    }
    
    $Global:settings = $defaultSettings
    
    # Initialize return values
    $Global:returnValues = New-MockReturnValues
    
    Write-Verbose "[Initialize-MenuTestEnvironment] Environment initialized for mode: $AppMode"
}

<#
.SYNOPSIS
    Clears the menu test environment

.DESCRIPTION
    Removes all global variables created by Initialize-MenuTestEnvironment

.EXAMPLE
    Clear-MenuTestEnvironment
#>
function Clear-MenuTestEnvironment
{
    [CmdletBinding()]
    param()
    
    Remove-Variable -Name MenuHistory -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name History -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name settings -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name LogFile -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name returnValues -Scope Global -ErrorAction SilentlyContinue
    
    Write-Verbose "[Clear-MenuTestEnvironment] Environment cleared"
}

#endregion

#region Common Menu Function Mocks

<#
.SYNOPSIS
    Creates a mock NewMenu function

.DESCRIPTION
    Provides a standardized mock of the NewMenu function that returns
    a hashtable with the expected menu structure

.EXAMPLE
    New-MockNewMenuFunction
    # Registers global NewMenu mock
#>
function New-MockNewMenuFunction
{
    [CmdletBinding()]
    param()
    
    $script:MockNewMenuFunction = {
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
    
    # Create global function (use -Force to overwrite if exists)
    New-Item -Path "Function:\global:NewMenu" -Value $script:MockNewMenuFunction -Force | Out-Null
    
    Write-Verbose "[New-MockNewMenuFunction] NewMenu mock registered"
}

<#
.SYNOPSIS
    Creates a mock ShowMenu function with configurable response

.DESCRIPTION
    Provides a standardized mock of the ShowMenu function that can return
    configurable responses for testing different scenarios

.PARAMETER MockResponse
    The response the mock should return when called

.PARAMETER EnableCallTracking
    Enable tracking of how many times the mock is called

.EXAMPLE
    New-MockShowMenuFunction -MockResponse "Main Menu"
    # ShowMenu will return "Main Menu" when called

.EXAMPLE
    New-MockShowMenuFunction -EnableCallTracking
    # Enables call counting, access via $script:ShowMenuCallCount
#>
function New-MockShowMenuFunction
{
    [CmdletBinding()]
    param(
        $MockResponse = $null,
        [switch]$EnableCallTracking
    )
    
    # Store tracking enable flag at script scope
    $script:ShowMenuCallTrackingEnabled = $EnableCallTracking.IsPresent
    
    # Initialize tracking variables if requested
    if ($EnableCallTracking)
    {
        $script:ShowMenuCallCount = 0
        $script:ShowMenuCalls = @()
    }
    
    $script:MockShowMenuResponse = $MockResponse
    
    $script:MockShowMenuFunction = {
        param($Menu, $CalledBy)
        
        if ($script:ShowMenuCallTrackingEnabled)
        {
            $script:ShowMenuCallCount++
            $script:ShowMenuCalls += @{
                Menu      = $Menu
                CalledBy  = $CalledBy
                Timestamp = Get-Date
            }
            Write-Verbose "[ShowMenu Mock] Called with menu: $($Menu.Title) (Call #$script:ShowMenuCallCount)"
        }
        
        return $script:MockShowMenuResponse
    }
    
    # Create global function (use -Force to overwrite if exists)
    New-Item -Path "Function:\global:ShowMenu" -Value $script:MockShowMenuFunction -Force | Out-Null
    
    Write-Verbose "[New-MockShowMenuFunction] ShowMenu mock registered"
}

<#
.SYNOPSIS
    Updates the response returned by the ShowMenu mock

.PARAMETER NewResponse
    The new response to return

.EXAMPLE
    Set-MockShowMenuResponse -NewResponse "Back"
#>
function Set-MockShowMenuResponse
{
    [CmdletBinding()]
    param(
        $NewResponse
    )
    
    $script:MockShowMenuResponse = $NewResponse
    Write-Verbose "[Set-MockShowMenuResponse] Response updated to: $NewResponse"
}

<#
.SYNOPSIS
    Gets the call tracking information for ShowMenu mock

.EXAMPLE
    $callInfo = Get-MockShowMenuCalls
#>
function Get-MockShowMenuCalls
{
    [CmdletBinding()]
    param()
    
    return @{
        CallCount = $script:ShowMenuCallCount
        Calls     = $script:ShowMenuCalls
    }
}

<#
.SYNOPSIS
    Resets the call tracking counters for ShowMenu mock

.DESCRIPTION
    Clears the call count and call history for the ShowMenu mock.
    Useful in BeforeEach blocks to reset state between tests.

.EXAMPLE
    Reset-MockShowMenuCalls
#>
function Reset-MockShowMenuCalls
{
    [CmdletBinding()]
    param()
    
    $script:ShowMenuCallCount = 0
    $script:ShowMenuCalls = @()
    Write-Verbose "[Reset-MockShowMenuCalls] Call tracking reset"
}

#endregion

# Export functions
Export-ModuleMember -Function @(
    'New-MockMenuStructure',
    'New-MockReturnValues',
    'Initialize-MenuTestEnvironment',
    'Clear-MenuTestEnvironment',
    'New-MockNewMenuFunction',
    'New-MockShowMenuFunction',
    'Set-MockShowMenuResponse',
    'Get-MockShowMenuCalls',
    'Reset-MockShowMenuCalls'
)

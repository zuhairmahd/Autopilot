function AddMenuItem()
{
    <#
    .SYNOPSIS
    Adds or updates a menu item in a menu structure.

    .DESCRIPTION
    This function adds a new menu item or updates an existing item with the same name in the
    provided menu hashtable. Menu items must have either an Action (scriptblock to execute)
    or a Submenu (nested menu), but not both. The function supports dynamic menu updates by
    preserving certain properties like includeInDisplayModes and Description when updating existing items.

    .PARAMETER Menu
    The menu hashtable to which the item will be added.

    .PARAMETER Name
    The display name of the menu item.

    .PARAMETER Description
    Optional description for the menu item that will be displayed in supported menu formats.

    .PARAMETER Action
    A scriptblock to execute when the menu item is selected. Mutually exclusive with Submenu.

    .PARAMETER Submenu
    A hashtable representing a nested submenu. Mutually exclusive with Action.

    .PARAMETER ReturnsValue
    When specified, indicates that the Action returns a value that should be processed.

    .OUTPUTS
    System.Collections.Hashtable
    Returns the modified menu hashtable with the added/updated item.

    .EXAMPLE
    $menu = AddMenuItem -Menu $mainMenu -Name "View Logs" -Action { Show-Log }
    $menu = AddMenuItem -Menu $mainMenu -Name "Settings" -Submenu $settingsMenu
    $menu = AddMenuItem -Menu $menu -Name "Get Device" -Action { GetDeviceByUser } -ReturnsValue
    $menu = AddMenuItem -Menu $mainMenu -Name "Export Data" -Description "Export all device data" -Action { Export-Data }

    .NOTES
    Throws an error if both Action and Submenu are provided or if neither is provided.
    Updates existing items with the same name rather than creating duplicates.
    Preserves Description and includeInDisplayModes when updating existing items.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Menu,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $false)]
        [string]$Description,
        [Parameter(Mandatory = $false)]
        [scriptblock]$Action,
        [Parameter(Mandatory = $false)]
        [hashtable]$Submenu,
        [Parameter(Mandatory = $false)]
        [switch]$ReturnsValue
    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Adding/updating menu item: '$Name'" -LogLevel "Debug"
    
    if ($Action -and $Submenu)
    {
Write-Log -LogFile $LogFile -Module $functionName -Message "Error: Menu item '$Name' cannot have both Action and Submenu" -LogLevel "Warning"
        throw "A menu item cannot have both an Action and a Submenu."
    }
    
    if (-not $Action -and -not $Submenu)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error: Menu item '$Name' must have either Action or Submenu" -LogLevel "Error"
        throw "A menu item must have either an Action or a Submenu."
    }
    
    # Check if an item with the same name already exists (for dynamic menu support)
    $existingItemIndex = -1
    for ($i = 0; $i -lt $Menu.Items.Count; $i++)
    {
        if ($Menu.Items[$i].Name -eq $Name)
        {
            $existingItemIndex = $i
            Write-Verbose "[$functionName] Found existing menu item with name: $Name at index $i"
Write-Log -LogFile $LogFile -Module $functionName -Message "Found existing menu item with name: $Name at index $i, will update instead of adding new" -LogLevel "Verbose"
            break
        }
    }
    
    $item = [ordered] @{
        Name         = $Name
        Action       = $Action
        Submenu      = $Submenu
        ReturnsValue = $ReturnsValue
    }
    
    # Add Description if provided, or preserve from existing item if updating
    if ($Description)
    {
        $item.Description = $Description
        Write-Log -LogFile $LogFile -Module $functionName -Message "Adding Description to menu item: '$Description'" -LogLevel "Debug"
    }
    elseif ($existingItemIndex -ge 0 -and $Menu.Items[$existingItemIndex].Description)
    {
        $item.Description = $Menu.Items[$existingItemIndex].Description
        Write-Log -LogFile $LogFile -Module $functionName -Message "Preserving Description from existing item: '$($item.Description)'" -LogLevel "Debug"
    }
    
    # Preserve includeInDisplayModes from existing item if updating
    if ($existingItemIndex -ge 0)
    {
        if ($Menu.Items[$existingItemIndex].includeInDisplayModes)
        {
            $item.includeInDisplayModes = $Menu.Items[$existingItemIndex].includeInDisplayModes
            Write-Log -LogFile $LogFile -Module $functionName -Message "Preserving includeInDisplayModes from existing item: $($item.includeInDisplayModes -join ', ')" -LogLevel "Debug"
        }
    }
    
    Write-Verbose "[$functionName] Adding/updating menu item:"
    Write-Verbose "[$functionName] name: $Name"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Menu item details - Name: '$Name', ReturnsValue: $ReturnsValue" -LogLevel "Debug"
    
    if ($null -ne $action -or $action -eq '')
    {
        Write-Verbose "[$functionName] Type: action"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Menu item '$Name' has action" -LogLevel "Debug"
    }
    if ($null -ne $Submenu -or $Submenu -eq '')
    {
        Write-Verbose "[$functionName] Type: submenu"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Menu item '$Name' has submenu" -LogLevel "Debug"
    }
    Write-Verbose "[$functionName] returns value: $ReturnsValue"
    
    if ($existingItemIndex -ge 0)
    {
        # Update existing item
        Write-Verbose "[$functionName] Updating existing menu item at index $existingItemIndex"
Write-Log -LogFile $LogFile -Module $functionName -Message "Updating existing menu item '$Name' at index $existingItemIndex" -LogLevel "Debug"
        $Menu.Items[$existingItemIndex] = $item
    }
    else
    {
        # Add new item
        Write-Verbose "[$functionName] Adding new menu item"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Adding new menu item '$Name' to menu" -LogLevel "Information"
        $Menu.Items += $item
    }
    
Write-Log -LogFile $LogFile -Module $functionName -Message "Menu item '$Name' successfully added/updated. Total menu items: $($Menu.Items.Count)" -LogLevel "Information"
    
    return $Menu
}


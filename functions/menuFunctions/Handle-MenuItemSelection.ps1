function Handle-MenuItemSelection()
{
    <#
    .SYNOPSIS
    Processes user menu item selection and delegates to appropriate handler.

    .DESCRIPTION
    This function receives the user's menu selection, finds the corresponding menu item from the
    choices array, and delegates processing to either Handle-ActionExecution for items with actions
    or Handle-SubmenuNavigation for items with submenus. If the selection is invalid or the item
    has neither action nor submenu, it redisplays the current menu.

    .PARAMETER SelectedOption
    The user's selected option string. This parameter is mandatory.

    .PARAMETER Choices
    Array of choice strings displayed to the user. This parameter is mandatory.

    .PARAMETER MenuItems
    Array of menu item objects corresponding to choices. This parameter is mandatory.

    .PARAMETER CurrentMenu
    The current menu hashtable being displayed. This parameter is mandatory.

    .OUTPUTS
    System.Object
    Returns the result from Handle-ActionExecution, Handle-SubmenuNavigation, or ShowMenu
    depending on the selected item type.

    .EXAMPLE
    $result = Handle-MenuItemSelection -SelectedOption $choice -Choices $choices -MenuItems $menu.Items -CurrentMenu $menu

    .NOTES
    Maps choice selection to menu item by index matching.
    Validates selection index is within bounds.
    Delegates to:
    - Handle-ActionExecution: For menu items with Action scriptblock
    - Handle-SubmenuNavigation: For menu items with Submenu
    - ShowMenu: For invalid selections or items without action/submenu
    
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SelectedOption,
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [array]$Choices,
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [array]$MenuItems,
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [hashtable]$CurrentMenu
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Find the selected item
    $selectedIndex = -1
    for ($i = 0; $i -lt $Choices.Count; $i++)
    {
        Write-Verbose "[$functionName] Checking choice $($i): $($Choices[$i]) against selected option: $SelectedOption"
        if ($Choices[$i] -eq $SelectedOption)
        {
            Write-Verbose "[$functionName] Match found at index $i"
            $selectedIndex = $i
            break
        }
    }
    
    if ($selectedIndex -eq -1 -or $selectedIndex -ge $MenuItems.Count)
    {
        Write-Verbose "[$functionName] Invalid selection index: $selectedIndex"
        return ShowMenu -Menu $CurrentMenu -CalledBy 'Direct' -StackOperation 'None'
    }
    
    $selectedItem = $MenuItems[$selectedIndex]
    Write-Verbose "[$functionName] Selected item: $($selectedItem.Name)"
    
    if ($selectedItem.Action)
    {
        Write-Verbose "[$functionName] Selected item has an Action"
        Write-Verbose "[$functionName] Action text: $($selectedItem.Action)"
        return Handle-ActionExecution -SelectedItem $selectedItem -CurrentMenu $CurrentMenu
    }
    elseif ($selectedItem.Submenu)
    {
        Write-Verbose "[$functionName] Selected item has a Submenu"
        return Handle-SubmenuNavigation -SelectedItem $selectedItem
    }
    else
    {
        Write-Verbose "[$functionName] Selected item has neither Action nor Submenu"
        return ShowMenu -Menu $CurrentMenu -CalledBy 'Direct' -StackOperation 'None'
    }
}


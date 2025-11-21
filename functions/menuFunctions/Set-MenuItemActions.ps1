function Set-MenuItemActions()
{
    <#
    .SYNOPSIS
    Maps action scriptblocks to menu items using an action map hashtable.

    .DESCRIPTION
    This function assigns action scriptblocks to menu items based on a provided action map.
    It recursively processes submenu items to ensure all menu items at all levels receive
    their corresponding actions. The function modifies menu items in place by setting their
    Action property.

    .PARAMETER Menu
    The menu hashtable containing Items array to process. This parameter is mandatory.

    .PARAMETER ActionMap
    Hashtable mapping menu item names to action scriptblocks. This parameter is mandatory.

    .EXAMPLE
    $actionMap = @{
        "View Logs" = { Show-Log -logFile $LogFile }
        "Exit" = { return 0 }
    }
    Set-MenuItemActions -Menu $mainMenu -ActionMap $actionMap

    .NOTES
    Processes menu items by name matching against ActionMap keys.
    Recursively processes submenu items for complete menu tree coverage.
    Only sets actions for items that have corresponding entries in ActionMap.
    Items without matching ActionMap entries remain unchanged.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Menu,
        [Parameter(Mandatory = $true)]
        [hashtable]$ActionMap
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Setting actions for menu: $($Menu.Title)"
    
    foreach ($item in $Menu.Items)
    {
        if ($ActionMap.ContainsKey($item.Name))
        {
            Write-Verbose "[$functionName] Setting action for menu item: $($item.Name)"
            $item.Action = $ActionMap[$item.Name]
        }
        else
        {
            Write-Verbose "[$functionName] No action mapping found for menu item: $($item.Name)"
        }
        
        # Recursively set actions for submenu items
        if ($item.Submenu)
        {
            Set-MenuItemActions -Menu $item.Submenu -ActionMap $ActionMap
        }
    }
}
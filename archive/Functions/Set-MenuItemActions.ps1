function Set-MenuItemActions()
{
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
function Remove-MenuItem()
{
    <#
    .SYNOPSIS
    Removes a menu item from a menu by name.

    .DESCRIPTION
    This function removes a specific menu item from a menu's Items array by matching the
    item name. It filters the Items collection to exclude the specified item and returns
    the modified menu. The function logs whether the removal was successful.

    .PARAMETER Menu
    The menu hashtable containing the Items array to modify. This parameter is mandatory.

    .PARAMETER ItemName
    The name of the menu item to remove. This parameter is mandatory.

    .OUTPUTS
    System.Collections.Hashtable
    Returns the modified menu hashtable with the item removed (if found).

    .EXAMPLE
    $menu = Remove-MenuItem -Menu $mainMenu -ItemName "Deprecated Feature"

    .NOTES
    Filters Items array using Where-Object for PowerShell 5.1 compatibility.
    Logs success or failure of removal operation.
    Does not throw errors if item is not found, simply logs and returns menu unchanged.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Menu,
        [Parameter(Mandatory = $true)]
        [string]$ItemName
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Removing menu item: $ItemName from menu: $($Menu.Title)" -LogLevel "Debug"
    
    # Find and remove the item from the menu items array
    $originalCount = $Menu.Items.Count
    $Menu.Items = $Menu.Items | Where-Object { $_.Name -ne $ItemName }
    $newCount = $Menu.Items.Count
    
    if ($originalCount -gt $newCount)
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Successfully removed menu item: $ItemName" -LogLevel "Information"
    }
    else
    {
        Write-Verbose "[$functionName] Menu item not found: $ItemName"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Menu item not found for removal: $ItemName" -LogLevel "Verbose"
    }
    
    return $Menu
}
function Handle-SubmenuNavigation()
{
    <#
    .SYNOPSIS
    Navigates to a submenu by displaying it with appropriate stack management.

    .DESCRIPTION
    This function handles navigation from a menu item to its submenu. It calls ShowMenu with
    the submenu hashtable, sets the CalledBy context to 'Submenu', and uses Auto stack operation
    for appropriate menu history management.

    .PARAMETER SelectedItem
    The selected menu item containing the Submenu hashtable. This parameter is mandatory.

    .OUTPUTS
    System.Object
    Returns the result from ShowMenu after displaying the submenu.

    .EXAMPLE
    $result = Handle-SubmenuNavigation -SelectedItem $menuItem

    .NOTES
    Simple delegation function for cleaner code organization.
    Sets CalledBy='Submenu' for proper navigation context.
    Uses StackOperation='Auto' for automatic stack management.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $SelectedItem
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Navigating to submenu: $($SelectedItem.Submenu.Title)"
    
    return ShowMenu -Menu $SelectedItem.Submenu -CalledBy 'Submenu' -StackOperation 'Auto'
}


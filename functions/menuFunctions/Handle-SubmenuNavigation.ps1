function Handle-SubmenuNavigation()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $SelectedItem
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Navigating to submenu: $($SelectedItem.Submenu.Title)"
    
    return ShowMenu -Menu $SelectedItem.Submenu -CalledBy 'Submenu' -StackOperation 'Auto'
}


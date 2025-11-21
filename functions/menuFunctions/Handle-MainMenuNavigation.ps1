function Handle-MainMenuNavigation()
{
    <#
    .SYNOPSIS
    Handles navigation back to the main menu.

    .DESCRIPTION
    This function implements navigation to the main menu from any point in the menu hierarchy.
    It clears the navigation history and menu stack, then displays the main menu (first item
    in MenuHistory). If no main menu exists, it returns null.

    .OUTPUTS
    System.Object
    Returns the result of showing the main menu, or $null if no main menu exists.

    .EXAMPLE
    $result = Handle-MainMenuNavigation

    .NOTES
    Uses global $MenuHistory and $History stacks.
    Clears all navigation history when returning to main menu.
    Called when user selects the "Main Menu" option from any submenu.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param()
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Handling main menu navigation"
    
    if ($Global:MenuHistory.Count -gt 0)
    {
        Write-Verbose "[$functionName] Current MenuHistory Count: $($Global:MenuHistory.Count)"
        $mainMenu = $Global:MenuHistory[0]
        Write-Verbose "[$functionName] Clearing stack and returning to main menu: $($mainMenu.Title)"
        
        # Clear stack and reset to main menu
        $Global:History.Clear()
        $Global:MenuHistory.Clear()
        
        return ShowMenu -Menu $mainMenu -CalledBy 'Navigation' -StackOperation 'Push'
    }
    
    Write-Verbose "[$functionName] Cannot go to main menu - no main menu available"
    return $null
}


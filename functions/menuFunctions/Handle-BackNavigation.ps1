function Handle-BackNavigation()
{
    <#
    .SYNOPSIS
    Handles navigation back to the previous menu.

    .DESCRIPTION
    This function implements backward navigation in the menu system by popping the previous
    menu from the global menu stack and displaying it. If no previous menu exists in the
    history, it returns null indicating the action cannot be performed.

    .OUTPUTS
    System.Object
    Returns the result of showing the previous menu, or $null if no previous menu exists.

    .EXAMPLE
    $result = Handle-BackNavigation

    .NOTES
    Uses the global $MenuHistory stack to track menu navigation.
    Called when user selects the "Back" option in a menu.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param()
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Handling back navigation"
    
    if ($Global:MenuHistory.Count -gt 0)
    {
        Write-Verbose "[$functionName] Current MenuHistory Count: $($Global:MenuHistory.Count)"
        $targetMenu = Pop-MenuFromStack
        
        if ($targetMenu)
        {
            Write-Verbose "[$functionName] Returning to previous menu: $($targetMenu.Title)"
            return ShowMenu -Menu $targetMenu -CalledBy 'Navigation' -StackOperation 'None'
        }
    }
    
    Write-Verbose "[$functionName] Cannot go back - no previous menu available"
    return $null
}


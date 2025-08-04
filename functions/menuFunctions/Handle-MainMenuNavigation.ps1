function Handle-MainMenuNavigation()
{
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


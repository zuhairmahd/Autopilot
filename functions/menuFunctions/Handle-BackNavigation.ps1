function Handle-BackNavigation()
{
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


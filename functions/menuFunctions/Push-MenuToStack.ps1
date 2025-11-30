function Push-MenuToStack()
{
    <#
    .SYNOPSIS
    Adds a menu to the navigation stack.

    .DESCRIPTION
    This function implements the push operation for the menu navigation stack. It adds the
    specified menu to both the History and MenuHistory global stacks, preventing duplicate
    consecutive entries. The function includes PowerShell 5.1 compatibility fallback for
    ArrayList operations.

    .PARAMETER Menu
    The menu hashtable to push onto the stack. Must contain a Title property. This parameter is mandatory.

    .OUTPUTS
    None. Modifies global $History and $MenuHistory stacks.

    .EXAMPLE
    Push-MenuToStack -Menu $mainMenu
    Push-MenuToStack -Menu $settingsMenu

    .NOTES
    Uses global $History and $MenuHistory stacks for navigation tracking.
    Prevents pushing duplicate consecutive menu entries.
    Includes fallback for PowerShell 5.1 ArrayList.Add compatibility.
    Only adds menu if it's different from the current top of stack.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Menu
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    try
    {
        # Only add if it's not already the current menu to prevent duplicates
        if ($Global:MenuHistory.Count -eq 0 -or $Global:MenuHistory[$Global:MenuHistory.Count - 1].Title -ne $Menu.Title)
        {
            Write-Verbose "[$functionName] Pushing menu '$($Menu.Title)' to stack"
            Write-Verbose "[$functionName] Current History Count: $($Global:History.Count)"
            [void]$Global:History.Add($Menu.Title)
            Write-Verbose "[$functionName] New History Count: $($Global:History.Count)"
            Write-Verbose "[$functionName] Current History: $($Global:History -join ', ')"
            Write-Verbose "[$functionName] Current MenuHistory Count: $($Global:MenuHistory.Count)"
            [void]$Global:MenuHistory.Add($Menu)
            Write-Verbose "[$functionName] New MenuHistory Count: $($Global:MenuHistory.Count)"
            Write-Verbose "[$functionName] Pushed menu '$($Menu.Title)' to stack. New depth: $($Global:MenuHistory.Count)"
        }
        else
        {
            Write-Verbose "[$functionName] Menu '$($Menu.Title)' already at top of stack, skipping push"
        }
    }
    catch
    {
        Write-Verbose "[$functionName] Error pushing to stack: $_"
        # Fallback for PowerShell 5.1 compatibility
        Write-Verbose "[$functionName] Using fallback method to push menu '$($Menu.Title)'"
        Write-Verbose "Current history count: $($Global:History.Count)"
        $Global:History += $Menu.Title
        Write-Verbose "New history count: $($Global:History.Count)"
        Write-Verbose "Current menu history count: $($Global:MenuHistory.Count)"
        $Global:MenuHistory += $Menu
        Write-Verbose "New menu history count: $($Global:MenuHistory.Count)"
        Write-Verbose "[$functionName] Used fallback method to push menu '$($Menu.Title)'. New depth: $($Global:MenuHistory.Count)"
    }
}


function Pop-MenuFromStack()
{
    <#
    .SYNOPSIS
    Removes and returns the current menu from the navigation stack.

    .DESCRIPTION
    This function implements the pop operation for the menu navigation stack. It removes the
    current menu from both the History and MenuHistory global stacks and returns the previous
    menu that is now at the top of the stack. The function includes comprehensive error handling
    and detailed verbose logging for debugging navigation issues.

    .OUTPUTS
    System.Collections.Hashtable
    Returns the previous menu hashtable that is now at the top of the stack after popping,
    or $null if the stack is empty or an error occurs.

    .EXAMPLE
    $previousMenu = Pop-MenuFromStack
    if ($previousMenu) {
        Write-Host "Returning to: $($previousMenu.Title)"
    }

    .NOTES
    Uses global $History and $MenuHistory stacks for navigation tracking.
    Removes one entry from each stack during pop operation.
    Returns $null if stack is empty or contains invalid data.
    Includes fallback error handling for stack corruption scenarios.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param()
    
    $functionName = $MyInvocation.MyCommand
    if ($Global:History.Count -gt 0 -and $Global:MenuHistory.Count -gt 0)
    {
        Write-Verbose "[$functionName] Starting pop operation"
        Write-Verbose "[$functionName] Popping menu from stack"
        try
        {
            Write-Verbose "[$functionName] Current History Count: $($Global:History.Count)"
            Write-Verbose "[$functionName] Current History : $($Global:History -join ', ')"
            $Global:History.RemoveAt($Global:History.Count - 1)
            Write-Verbose "[$functionName] New History Count: $($Global:History.Count)"
            Write-Verbose "[$functionName] New history: $($Global:History -join ', ')"
            Write-Verbose "[$functionName] Current MenuHistory Count: $($Global:MenuHistory.Count)"
            # Write-Verbose "[$functionName] Current MenuHistory: $($Global:MenuHistory | ForEach-Object { $_.Title } -join ', ')"
            
            # Get the menu that was just removed for logging
            $poppedMenu = $Global:MenuHistory[$Global:MenuHistory.Count - 1]
            Write-Verbose "[$functionName] Removing menu: $($poppedMenu.Title)"
            # Remove the current menu from the stack
            $Global:MenuHistory.RemoveAt($Global:MenuHistory.Count - 1)
            Write-Verbose "[$functionName] New MenuHistory Count after pop: $($Global:MenuHistory.Count)"
            # Create a simple array of titles for display
            $menuTitles = $Global:MenuHistory | ForEach-Object { $_.Title }
            $menuTitlesString = $menuTitles -join ', '
            Write-Verbose "[$functionName] New MenuHistory: $menuTitlesString"
            # Return the menu that is now at the top of the stack (the previous menu)
            if ($Global:MenuHistory.Count -gt 0)
            {
                Write-Verbose "[$functionName] Latest MenuHistory Count: $($Global:MenuHistory.Count)"
                Write-Verbose "[$functionName] Stack is not empty, returning to previous menu"
                try
                {
                    $targetMenu = $Global:MenuHistory[$Global:MenuHistory.Count - 1]
                    if ($targetMenu -and $targetMenu.Title)
                    {
                        Write-Verbose "[$functionName] Previous menu: $($targetMenu.Title)"
                        Write-Verbose "[$functionName] Returning to previous menu: $($targetMenu.Title)"
                        return $targetMenu
                    }
                    else
                    {
                        Write-Verbose "[$functionName] Error: Target menu is null or missing Title property"
                        return $null
                    }
                }
                catch
                {
                    Write-Verbose "[$functionName] Error accessing target menu: $_"
                    return $null
                }
            }
            else
            {
                Write-Verbose "[$functionName] Latest MenuHistory Count: $($Global:MenuHistory.Count)"
                Write-Verbose "[$functionName] Stack is now empty, cannot return to previous menu"
                return $null
            }        
        }
        catch
        {
            Write-Verbose "[$functionName] Error popping from stack: $_"
            Write-Verbose "[$functionName] Error details: $($_.Exception.Message)"
            Write-Verbose "[$functionName] Stack trace: $($_.ScriptStackTrace)"
            return $null
        }
    }
    else
    {
        Write-Verbose "[$functionName] Cannot pop - stack is empty"
        return $null
    }
}


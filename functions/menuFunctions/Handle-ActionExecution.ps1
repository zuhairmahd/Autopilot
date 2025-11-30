function Handle-ActionExecution()
{
    <#
    .SYNOPSIS
    Executes a menu item action and handles its return value.

    .DESCRIPTION
    This function executes the scriptblock action associated with a selected menu item and
    processes the return value according to the menu system's conventions. It handles special
    return values like "Back", "Main Menu", exit codes, and application signals. For actions
    that don't return values, it displays results and waits for user acknowledgment.

    .PARAMETER SelectedItem
    The selected menu item object containing Name, Action, and ReturnsValue properties.

    .PARAMETER CurrentMenu
    The current menu hashtable, used for returning to the menu after action completion.

    .OUTPUTS
    System.Object
    Returns the action result, navigation command, or menu display result based on the action's behavior.

    .EXAMPLE
    $result = Handle-ActionExecution -SelectedItem $menuItem -CurrentMenu $menu

    .NOTES
    Special return values:
    - "Back": Navigate to previous menu
    - "Main Menu": Navigate to main menu
    - 0: Exit application
    - "EXIT_APPLICATION": Exit application
    - $returnValues.backoutText: Return to current menu
    
    Actions marked with ReturnsValue have their results passed through for processing.
    Non-returning actions display results and pause for user confirmation.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $SelectedItem,
        [Parameter(Mandatory = $true)]
        [hashtable]$CurrentMenu
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Executing action: $($SelectedItem.Name): $($SelectedItem.Action)"
    
    # Execute the action
    $result = & $SelectedItem.Action
    Write-Verbose "[$functionName] Action executed, result: $result"
    
    # Handle different result types
    if ($SelectedItem.ReturnsValue)
    {
        Write-Verbose "[$functionName] Action returns a value, processing result"
        # Handle navigation results from actions
        if ($result -eq "Back")
        {
            Write-Verbose "[$functionName] Action returned 'Back', navigating back"
            return Handle-BackNavigation
        }
        elseif ($result -eq "Main Menu")
        {
            Write-Verbose "[$functionName] Action returned 'Main Menu', navigating to main menu"
            return Handle-MainMenuNavigation
        }
        elseif ($result -eq 0)
        {
            Write-Verbose "[$functionName] Action returned 0, exiting application"
            return [int]$result
        }
        
        Write-Verbose "[$functionName] Action returned value: $result"
        return $result
    }
    
    # Handle special signals
    if ($result -eq "EXIT_APPLICATION")
    {
        Write-Verbose "[$functionName] Action requested application exit because result is $result"
        return $null
    }
    
    if ($result -eq $returnValues.backoutText)
    {
        Write-Verbose "[$functionName] Action returned backout text because result is $result"
        return ShowMenu -Menu $CurrentMenu -CalledBy 'Action' -StackOperation 'None'
    }
    
    # Display result and continue
    if ($null -ne $result)
    {
        Write-Host "`n$result" -ForegroundColor Cyan
    }
    
    Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp")
    
    return ShowMenu -Menu $CurrentMenu -CalledBy 'Action' -StackOperation 'None'
}


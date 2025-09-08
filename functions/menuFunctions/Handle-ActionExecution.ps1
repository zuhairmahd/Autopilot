function Handle-ActionExecution()
{
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


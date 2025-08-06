function Handle-MenuItemSelection()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SelectedOption,
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [array]$Choices,
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [array]$MenuItems,
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [hashtable]$CurrentMenu
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Find the selected item
    $selectedIndex = -1
    for ($i = 0; $i -lt $Choices.Count; $i++)
    {
        Write-Verbose "[$functionName] Checking choice $($i): $($Choices[$i]) against selected option: $SelectedOption"
        if ($Choices[$i] -eq $SelectedOption)
        {
            Write-Verbose "[$functionName] Match found at index $i"
            $selectedIndex = $i
            break
        }
    }
    
    if ($selectedIndex -eq -1 -or $selectedIndex -ge $MenuItems.Count)
    {
        Write-Verbose "[$functionName] Invalid selection index: $selectedIndex"
        return ShowMenu -Menu $CurrentMenu -CalledBy 'Direct' -StackOperation 'None'
    }
    
    $selectedItem = $MenuItems[$selectedIndex]
    Write-Verbose "[$functionName] Selected item: $($selectedItem.Name)"
    
    if ($selectedItem.Action)
    {
        Write-Verbose "[$functionName] Selected item has an Action"
        return Handle-ActionExecution -SelectedItem $selectedItem -CurrentMenu $CurrentMenu
    }
    elseif ($selectedItem.Submenu)
    {
        Write-Verbose "[$functionName] Selected item has a Submenu"
        return Handle-SubmenuNavigation -SelectedItem $selectedItem
    }
    else
    {
        Write-Verbose "[$functionName] Selected item has neither Action nor Submenu"
        return ShowMenu -Menu $CurrentMenu -CalledBy 'Direct' -StackOperation 'None'
    }
}


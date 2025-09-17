function DisplayGroupList()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [array]$groupList,
        [Parameter(Mandatory = $false)]
        [int]$maxDisplay = 10
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Displaying group list"
    if ($groupList.Count -eq 0)
    {
        Write-Host "No groups found." -ForegroundColor Yellow
        return $returnValues.noGroupFoundMessage
    }
    if ($groupList.Count -eq 1)
    {
        Write-Verbose "[$functionName] Only one group found, returning group displayName."
        Write-Host "$($groupList[0].displayName)"
        $choice = Read-Host "(Y/N)"
        while ($choice -notin @('Y', 'N', 'y', 'n'))
        {
            Write-Host "Please enter Y or N." -ForegroundColor Red
            [console]::beep(1000, 500)
            $choice = Read-Host "(Y/N)"
        }
        if ($choice -in @('Y', 'y'))
        {
            Write-Verbose "[$functionName] User confirmed: $($groupList[0].displayName)"
            return $groupList[0].displayName
        }
        else
        {
            Write-Verbose "[$functionName] Group not confirmed, returning $($returnValues.userCanceledMessage)."
            return $returnValues.userCanceledMessage
        }
    }
    if ($groupList.count -gt $maxDisplay)
    {
        Write-Verbose "[$functionName] Group list has more than $maxDisplay groups, truncating to $maxDisplay."
        $groupList = $groupList | Select-Object -First $maxDisplay
    }
    # Create group selection menu from configuration
    $groupMenu = NewMenu -MenuName "groupMenu"
    if (-not $groupMenu) {
        # Fallback to manual creation if config not found
        $groupMenu = NewMenu -Title "Select a group" -Description "Did you mean:"
    }
    $groups = $groupList
    Write-Verbose "[$functionName] Creating group menu with $($groupList.Count) groups."
    # Add each group as a menu item
    foreach ($group in $groups)
    {
        # Create a display name for the menu
        $menuItemName = "$($group.displayName)"
        Write-Verbose "[$functionName] Adding menu item: $menuItemName"
        # Create a scriptblock action that returns This specific group name when selected.
        Write-Verbose "[$functionName] Creating action for group: $group"
        $action = {
            Write-Verbose "[$functionName] Returning group name: $($group.displayName)"
            return $group
        }.GetNewClosure()
        # Add the menu item with the action
        $groupMenu = AddMenuItem -Menu $groupMenu -Name $menuItemName -Action $action -ReturnsValue
    }
    Write-Verbose "[$functionName] Showing group selection menu with $($groupMenu.Items.Count) items"
    Write-Verbose "[$functionName] Current navigation - Depth: $Depth, History count: $($History.Count)"
    Write-Verbose "[$functionName] Current menu title: $($groupMenu.Title)"
    $selectedGroup = ShowMenu -Menu $groupMenu -CalledBy 'Action'
    if ($null -ne $selectedGroup)
    {
        Write-Verbose "[$functionName] Selected group: $($selectedGroup.displayName)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "User selected group: $($selectedGroup.displayName)" -LogLevel "Information"
    }
    else
    {
        Write-Verbose "[$functionName] Selected group is null"
    }
    return $selectedGroup
}

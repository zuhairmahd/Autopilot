function DisplayUserList()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [array]$UserList,
        [Parameter(Mandatory = $false)]
        [int]$maxDisplay = 10
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Displaying user list"
    if ($UserList.Count -eq 0)
    {
        Write-Host "No users found." -ForegroundColor Yellow
        return $returnValues.noUserFoundInDirectoryMessage
    }
    if ($UserList.Count -eq 1)
    {
        Write-Verbose "[$functionName] Only one user found, returning userPrincipalName."
        Write-Host "$($UserList[0].displayName): ($($UserList[0].userPrincipalName))"
        $choice = Read-Host "(Y/N)"
        while ($choice -notin @('Y', 'N', 'y', 'n'))
        {
            Write-Host "Please enter Y or N." -ForegroundColor Red
            [console]::beep(1000, 500)
            $choice = Read-Host "(Y/N)"
        }
        if ($choice -in @('Y', 'y'))
        {
            Write-Verbose "[$functionName] User confirmed: $($UserList[0].userPrincipalName)"
            return $UserList[0].userPrincipalName
        }
        else
        {
            Write-Verbose "[$functionName] User not confirmed, returning $($returnValues.userCanceledMessage)."
            return $returnValues.userCanceledMessage
        }
    }
    if ($userList.count -gt $maxDisplay)
    {
        Write-Verbose "[$functionName] User list has more than $maxDisplay users, truncating to $maxDisplay."
        $UserList = $UserList | Select-Object -First $maxDisplay
    }
    # Create user selection menu from configuration
    $userMenu = NewMenu -MenuName "userMenu"
    if (-not $userMenu)
    {
        # Fallback to manual creation if config not found
        $userMenu = NewMenu -Title "Select a user" -Description "Did you mean:"
    }
    # Store devices in an array to reference later
    $users = $UserList
    Write-Verbose "[$functionName] Creating user menu with $($userList.Count) users."
    # Add each user as a menu item
    foreach ($user in $users)
    {
        # Create a display name for the menu
        $menuItemName = "$($user.displayName): ($($user.userPrincipalName))"
        Write-Verbose "[$functionName] Adding menu item: $menuItemName"
        # Create a scriptblock action that returns This specific user id when selected.
        $UPN = $user.userPrincipalName
        Write-Verbose "[$functionName] Creating action for user: $user"
        $action = {
            Write-Verbose "[$functionName] Returning user name: $($UPN)"
            return $UPN
        }.GetNewClosure()
        # Add the menu item with the action
        $userMenu = AddMenuItem -Menu $userMenu -Name $menuItemName -Action $action -ReturnsValue
    }
    Write-Verbose "[$functionName] Showing user selection menu with $($userMenu.Items.Count) items"
    Write-Verbose "[$functionName] Current navigation - Depth: $Depth, History count: $($History.Count)"
    Write-Verbose "[$functionName] Current menu title: $($userMenu.Title)"
    $selectedUser = ShowMenu -Menu $userMenu -CalledBy 'Action'
    
    # Handle exit selection (ShowMenu returns null when user presses 0 to exit)
    # Check if this is an exit vs a back/cancel by looking at whether it's truly null (exit) vs empty string (back)
    if ($null -eq $selectedUser)
    {
        Write-Verbose "[$functionName] ShowMenu returned null - treating as exit command"
        # Return 0 to signal exit, which ConvertFrom-UserSelection will handle
        return 0
    }
    
    if ($selectedUser -is [string])
    {
        Write-Verbose "[$functionName] Selected user: $selectedUser"
    }
    else
    {
        Write-Verbose "[$functionName] Selected user is not a string: $($selectedUser.GetType().Name)"
    }
    return $selectedUser
}


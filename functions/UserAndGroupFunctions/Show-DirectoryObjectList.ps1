function Show-DirectoryObjectList()
{
    <#
    .SYNOPSIS
        Unified function to display and select from a list of users or groups.
    
    .DESCRIPTION
        This function consolidates the logic from DisplayUserList and DisplayGroupList into a single
        unified implementation. It handles empty lists, single item confirmation, list truncation,
        menu creation, and consistent exit handling for both users and groups.
        
        Returns the appropriate identifier based on EntityType:
        - User: userPrincipalName (string)
        - Group: displayName (string)
    
    .PARAMETER EntityList
        Array of user or group objects from Graph API.
    
    .PARAMETER EntityType
        Specifies whether displaying 'User' or 'Group' entities.
    
    .PARAMETER MaxDisplay
        Maximum number of items to display. Defaults to 10.
    
    .OUTPUTS
        Returns:
        - String identifier (userPrincipalName for users, displayName for groups)
        - Integer 0 for exit
        - Return value message for navigation (back, cancel, etc.)
    
    .EXAMPLE
        # Display user list
        $selection = Show-DirectoryObjectList -EntityList $users -EntityType User -MaxDisplay 10
        if ($selection -eq 0) { exit }
    
    .EXAMPLE
        # Display group list
        $selection = Show-DirectoryObjectList -EntityList $groups -EntityType Group -MaxDisplay 5
        Write-Host "Selected group: $selection"
    
    .NOTES
        Author: Windows Autopilot Management Tool Team
        Version: 1.0.0
        This function replaces DisplayUserList and DisplayGroupList to eliminate code duplication.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$EntityList,
        [Parameter(Mandatory = $true)]
        [ValidateSet("User", "Group")]
        [string]$EntityType,
        [Parameter(Mandatory = $false)]
        [int]$MaxDisplay = 10,
        [Parameter(Mandatory = $false)]
        [switch]$NoPrompt
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Displaying $EntityType list"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Displaying $EntityType list with $($EntityList.Count) items" -LogLevel "Verbose"
    
    # Handle empty list
    if ($EntityList.Count -eq 0)
    {
        Write-Host "No ${EntityType}s found." -ForegroundColor Yellow
        $noEntityMessage = if ($EntityType -eq "User")
        {
            $returnValues.noUserFoundInDirectoryMessage 
        }
        else
        {
            $returnValues.noGroupFoundMessage 
        }
        return $noEntityMessage
    }
    
    # Handle single item - prompt for confirmation unless NoPrompt is specified
    if ($EntityList.Count -eq 1)
    {
        # Return appropriate identifier
        $identifier = if ($EntityType -eq "User")
        {
            $EntityList[0].userPrincipalName 
        }
        else
        {
            $EntityList[0].displayName 
        }
        
        # If NoPrompt is specified, auto-accept the single item
        if ($NoPrompt)
        {
            Write-Verbose "[$functionName] NoPrompt specified - auto-accepting single ${EntityType}: $identifier"
            Write-Log -LogFile $LogFile -Module $functionName -Message "NoPrompt - auto-accepting ${EntityType}: $identifier" -LogLevel "Information"
            return $identifier
        }
        
        Write-Verbose "[$functionName] Only one $EntityType found, prompting for confirmation"
        
        # Display item based on type
        if ($EntityType -eq "User")
        {
            Write-Host "$($EntityList[0].displayName): ($($EntityList[0].userPrincipalName))"
        }
        else
        {
            Write-Host "$($EntityList[0].displayName)"
        }
        
        # Get Y/N confirmation
        $choice = Read-Host "(Y/N)"
        while ($choice -notin @('Y', 'N', 'y', 'n'))
        {
            Write-Host "Please enter Y or N." -ForegroundColor Red
            [console]::beep(1000, 500)
            $choice = Read-Host "(Y/N)"
        }
        
        if ($choice -in @('Y', 'y'))
        {
            Write-Verbose "[$functionName] $EntityType confirmed: $identifier"
            Write-Log -LogFile $LogFile -Module $functionName -Message "$EntityType confirmed: $identifier" -LogLevel "Information"
            return $identifier
        }
        else
        {
            Write-Verbose "[$functionName] $EntityType not confirmed, returning userCanceledMessage"
            return $returnValues.userCanceledMessage
        }
    }
    
    # Handle multiple items - truncate if needed
    if ($EntityList.Count -gt $MaxDisplay)
    {
        Write-Verbose "[$functionName] $EntityType list has more than $MaxDisplay items, truncating to $MaxDisplay"
        $EntityList = $EntityList | Select-Object -First $MaxDisplay
    }
    
    # Create selection menu
    $menuName = if ($EntityType -eq "User")
    {
        "userMenu" 
    }
    else
    {
        "groupMenu" 
    }
    $menu = NewMenu -MenuName $menuName
    
    if (-not $menu)
    {
        # Fallback to manual creation if config not found
        $title = "Select a $($EntityType.ToLower())"
        $description = "Did you mean:"
        $menu = NewMenu -Title $title -Description $description
    }
    
    Write-Verbose "[$functionName] Creating $EntityType menu with $($EntityList.Count) items"
    
    # Add each entity as a menu item
    foreach ($entity in $EntityList)
    {
        # Create display name based on type
        if ($EntityType -eq "User")
        {
            $menuItemName = "$($entity.displayName): ($($entity.userPrincipalName))"
            $identifier = $entity.userPrincipalName
        }
        else
        {
            $menuItemName = "$($entity.displayName)"
            $identifier = $entity.displayName
        }
        
        Write-Verbose "[$functionName] Adding menu item: $menuItemName"
        
        # Create scriptblock that returns the identifier
        $action = {
            Write-Verbose "[$functionName] Returning $EntityType identifier: $identifier"
            return $identifier
        }.GetNewClosure()
        
        # Add menu item
        $menu = AddMenuItem -Menu $menu -Name $menuItemName -Action $action -ReturnsValue
    }
    
    Write-Verbose "[$functionName] Showing $EntityType selection menu with $($menu.Items.Count) items"
    Write-Verbose "[$functionName] Current navigation - Depth: $Depth, History count: $($History.Count)"
    Write-Verbose "[$functionName] Current menu title: $($menu.Title)"
    
    # Show menu and get selection
    $selectedEntity = ShowMenu -Menu $menu -CalledBy 'Action'
    
    # Handle exit selection (ShowMenu returns null when user presses 0 to exit)
    # Convert null to 0 for consistent exit handling
    if ($null -eq $selectedEntity)
    {
        Write-Verbose "[$functionName] ShowMenu returned null - treating as exit command"
        Write-Log -LogFile $LogFile -Module $functionName -Message "User selected exit from $EntityType list" -LogLevel "Information"
        # Return 0 to signal exit, which ConvertFrom-DirectoryObjectSelection will handle
        return 0
    }
    
    # Log and return selection
    if ($selectedEntity -is [string])
    {
        Write-Verbose "[$functionName] Selected $EntityType`: $selectedEntity"
        Write-Log -LogFile $LogFile -Module $functionName -Message "User selected $EntityType`: $selectedEntity" -LogLevel "Information"
    }
    else
    {
        Write-Verbose "[$functionName] Selected $EntityType is not a string: $($selectedEntity.GetType().Name)"
    }
    
    return $selectedEntity
}

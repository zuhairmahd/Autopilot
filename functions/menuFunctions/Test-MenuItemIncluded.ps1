function Test-MenuItemIncluded()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MenuItemName,
        [Parameter(Mandatory = $false)]
        [PSCustomObject[]]$Menus
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Checking if menu item '$MenuItemName' should be included"
    Write-Verbose "[$functionName] App mode: $($settings.appMode)"  
Write-Log -LogFile $LogFile -Module $functionName -Message "Starting menu item inclusion check for '$MenuItemName' with app mode: $($settings.appMode)" -LogLevel "Verbose"

    # If $Menus parameter is null, always assume the menu needs to be displayed
    if ($null -eq $Menus)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Menus parameter is null, allowing menu item '$MenuItemName'" -LogLevel "Debug"
        return $true
    }
    
    # Get app mode hierarchy from menu configuration
    $hierarchyAllowed = Get-AppModeHierarchy -CurrentAppMode $settings.appMode
    Write-Log -LogFile $LogFile -Module $functionName -Message "App mode hierarchy for '$($settings.appMode)': [$($hierarchyAllowed -join ', ')]" -LogLevel "Debug"

    # If the $settings.appMode hierarchy includes '*', assume the menu needs to be displayed (full mode)
    if ($hierarchyAllowed -contains '*')
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "App mode hierarchy includes '*' (full access), allowing menu item '$MenuItemName'" -LogLevel "Debug"
        return $true
    }

    # Helper function to recursively search for menu item
    function Find-MenuItemRecursive()
    {
        param(
            [Parameter(Mandatory = $true)]
            [string]$SearchName,
            [Parameter(Mandatory = $true)]
            [PSCustomObject[]]$MenuItems
        )
        $functionName = $MyInvocation.MyCommand.Name
Write-Log -LogFile $LogFile -Module $functionName -Message "Searching for menu item '$SearchName' in provided menus" -LogLevel "Verbose"
        foreach ($menuItem in $MenuItems)
        {
            # Check if this menu item matches the search name
Write-Log -LogFile $LogFile -Module $functionName -Message "Checking menu item: $($menuItem.name)" -LogLevel "Verbose"
            if ($menuItem.name -eq $SearchName)
            {
Write-Log -LogFile $LogFile -Module $functionName -Message "Found menu item '$SearchName'" -LogLevel "Verbose"
                return $menuItem
            }
            
            # If this menu item has sub-items, search recursively
            if ($menuItem.items -and $menuItem.items.Count -gt 0)
            {
Write-Log -LogFile $LogFile -Module $functionName -Message "Menu item '$($menuItem.name)' has sub-items, searching recursively" -LogLevel "Verbose"
                $found = Find-MenuItemRecursive -SearchName $SearchName -MenuItems $menuItem.items
                if ($found)
                {
Write-Log -LogFile $LogFile -Module $functionName -Message "Found menu item '$SearchName' in sub-items of '$($menuItem.name)'" -LogLevel "Verbose"
                    return $found
                }
            }
        }
Write-Log -LogFile $LogFile -Module $functionName -Message "Menu item '$SearchName' not found in provided menus" -LogLevel "Verbose"
        # If we reach here, the item was not found
        return $null
    }

    # Search for the menu item in the provided menus
    $foundMenuItem = Find-MenuItemRecursive -SearchName $MenuItemName -MenuItems $Menus
    
    # If the menu item is not found, return true (include it by default)
    if ($null -eq $foundMenuItem)
    {
Write-Log -LogFile $LogFile -Module $functionName -Message "Menu item '$MenuItemName' not found in menus configuration, allowing by default" -LogLevel "Verbose"
        return $true
    }

Write-Log -LogFile $LogFile -Module $functionName -Message "Found menu item '$MenuItemName' in menus configuration" -LogLevel "Verbose"

    # Check if the menu item has includeInDisplayModes array
    if ($foundMenuItem.includeInDisplayModes -and $foundMenuItem.includeInDisplayModes.Count -gt 0)
    {
        # Use hierarchical checking instead of direct matching
        $appModeMatches = $false
        foreach ($allowedMode in $foundMenuItem.includeInDisplayModes)
        {
            if ($hierarchyAllowed -contains $allowedMode)
            {
                $appModeMatches = $true
                break
            }
        }
        
Write-Log -LogFile $LogFile -Module $functionName -Message "Menu item '$MenuItemName' hierarchical includeInDisplayModes check: $appModeMatches (checking [$($foundMenuItem.includeInDisplayModes -join ', ')] against hierarchy [$($hierarchyAllowed -join ', ')])" -LogLevel "Verbose"
        return $appModeMatches
    }

    # If no includeInDisplayModes array is found, include by default
Write-Log -LogFile $LogFile -Module $functionName -Message "No includeInDisplayModes found for menu item '$MenuItemName', allowing by default" -LogLevel "Verbose"
    return $true
}


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
    Write-Log -LogFile $LogFile -Module $functionName -Message "App mode: $($settings.appMode)" -LogLevel "Debug"

    # If $Menus parameter is null, always assume the menu needs to be displayed
    if ($null -eq $Menus)
    {
        Write-Verbose "[$functionName] Menus parameter is null, allowing menu item '$MenuItemName'"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Menus parameter is null, allowing menu item '$MenuItemName'" -LogLevel "Debug"
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
        Write-Verbose "[$functionName] Searching for menu item '$SearchName' in provided menus"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Searching for menu item '$SearchName' in provided menus" -LogLevel "Debug"
        foreach ($menuItem in $MenuItems)
        {
            # Check if this menu item matches the search name
            Write-Verbose "[$functionName] Checking menu item: $($menuItem.name)"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Checking menu item: $($menuItem.name)" -LogLevel "Debug"
            if ($menuItem.name -eq $SearchName)
            {
                Write-Verbose "[$functionName] Found menu item '$SearchName'"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Found menu item '$SearchName'" -LogLevel "Debug"
                return $menuItem
            }
            
            # If this menu item has sub-items, search recursively
            if ($menuItem.items -and $menuItem.items.Count -gt 0)
            {
                Write-Verbose "[$functionName] Menu item '$($menuItem.name)' has sub-items, searching recursively"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Menu item '$($menuItem.name)' has sub-items, searching recursively" -LogLevel "Debug"
                $found = Find-MenuItemRecursive -SearchName $SearchName -MenuItems $menuItem.items
                if ($found)
                {
                    Write-Verbose "[$functionName] Found menu item '$SearchName' in sub-items of '$($menuItem.name)'"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Found menu item '$SearchName' in sub-items of '$($menuItem.name)'" -LogLevel "Debug"
                    return $found
                }
            }
        }
        Write-Verbose "[$functionName] Menu item '$SearchName' not found in provided menus"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Menu item '$SearchName' not found in provided menus" -LogLevel "Debug"
        # If we reach here, the item was not found
        return $null
    }

    # Search for the menu item in the provided menus
    $foundMenuItem = Find-MenuItemRecursive -SearchName $MenuItemName -MenuItems $Menus
    
    # If the menu item is not found, return true (include it by default)
    if ($null -eq $foundMenuItem)
    {
        Write-Verbose "[$functionName] Menu item '$MenuItemName' not found in menus configuration, allowing by default"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Menu item '$MenuItemName' not found in menus configuration, allowing by default" -LogLevel "Debug"
        return $true
    }

    Write-Verbose "[$functionName] Found menu item '$MenuItemName' in menus configuration"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Found menu item '$MenuItemName' in menus configuration" -LogLevel "Debug"

    # Check if the menu item has includeInDisplayModes array
    if ($foundMenuItem.includeInDisplayModes -and $foundMenuItem.includeInDisplayModes.Count -gt 0)
    {
        $appModeMatches = $foundMenuItem.includeInDisplayModes -contains $settings.appMode
        Write-Verbose "[$functionName] Menu item '$MenuItemName' includeInDisplayModes check: $appModeMatches (looking for '$($settings.appMode)' in [$($foundMenuItem.includeInDisplayModes -join ', ')])"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Menu item '$MenuItemName' includeInDisplayModes check: $appModeMatches" -LogLevel "Debug"
        return $appModeMatches
    }

    # If no includeInDisplayModes array is found, include by default
    Write-Verbose "[$functionName] No includeInDisplayModes found for menu item '$MenuItemName', allowing by default"
    Write-Log -LogFile $LogFile -Module $functionName -Message "No includeInDisplayModes found for menu item '$MenuItemName', allowing by default" -LogLevel "Debug"
    return $true
}


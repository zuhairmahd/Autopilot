function Get-RequiredMenusRecursive()
{
    <#
    .SYNOPSIS
        Recursively analyzes menu dependencies with extensive logging.

    .DESCRIPTION
        Recursively analyzes a menu's dependencies to find all nested menu references,
        providing comprehensive logging for troubleshooting and performance monitoring.

    .PARAMETER MenuName
        Name of the menu to analyze

    .PARAMETER MenuConfig
        Menu configuration object

    .PARAMETER CurrentAppMode
        Current application mode

    .OUTPUTS
        Array - Names of nested menus required by the specified menu

    .NOTES
        - Extensive logging for troubleshooting recursive dependencies
        - Prevents infinite recursion through dependency tracking
        - Maintains PowerShell 5.1 compatibility
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MenuName,
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$MenuConfig,
        [Parameter(Mandatory = $false)]
        [string]$CurrentAppMode = $settings.appMode
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting recursive dependency analysis for menu: $MenuName" -LogLevel "Debug"
    Write-Verbose "[$functionName] Recursively analyzing menu: $MenuName with app mode: $CurrentAppMode"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Analyzing with app mode: $CurrentAppMode" -LogLevel "Debug"

    $nestedMenus = @()
    $itemsProcessed = 0
    $nestedReferencesFound = 0

    # Check if the specified menu exists in configuration
    if ($MenuConfig.PSObject.Properties.Name -contains $MenuName)
    {
        $menuDef = $MenuConfig.$MenuName
        Write-Log -LogFile $LogFile -Module $functionName -Message "Found menu definition for: $MenuName" -LogLevel "Debug"
        Write-Verbose "[$functionName] Found menu definition for: $MenuName"
        # If this menu has items, check for nested menu references
        if ($menuDef.items)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Menu '$MenuName' has $($menuDef.items.Count) items to analyze" -LogLevel "Debug"
            Write-Verbose "[$functionName] Menu '$MenuName' has $($menuDef.items.Count) items to analyze"
            $filteredItems = FilterMenuItemsByAppMode -MenuItems $menuDef.items -CurrentAppMode $CurrentAppMode
            Write-Log -LogFile $LogFile -Module $functionName -Message "Filtered items for '$MenuName' from $($menuDef.items.Count) to $($filteredItems.Count)" -LogLevel "Debug"
            Write-Verbose "[$functionName] Filtered items for '$MenuName' from $($menuDef.items.Count) to $($filteredItems.Count)"
            foreach ($item in $filteredItems)
            {
                $itemsProcessed++
                $itemName = if ($item.name)
                {
                    $item.name
                }
                else
                {
                    "Unnamed Item $itemsProcessed"
                }
                Write-Verbose "[$functionName] Analyzing menu item: $($item.name)"
                if ($item.menuName -and $item.menuName -notin $nestedMenus)
                {
                    $nestedMenus += $item.menuName
                    $nestedReferencesFound++
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Found nested menu reference in '$MenuName': $($item.menuName) (from item: $itemName)" -LogLevel "Debug"
                    Write-Verbose "[$functionName] Found nested menu reference: $($item.menuName)"
                    # Recursively check this nested menu
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Recursively analyzing nested menu: $($item.menuName)" -LogLevel "Debug"
                    Write-Verbose "[$functionName] Recursively analyzing nested menu: $($item.menuName)"
                    $deeperMenus = Get-RequiredMenusRecursive -MenuName $item.menuName -MenuConfig $MenuConfig -CurrentAppMode $CurrentAppMode
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Found $($deeperMenus.Count) deeper nested menus from: $($item.menuName)" -LogLevel "Debug"
                    Write-Verbose "[$functionName] Found $($deeperMenus.Count) deeper nested menus for submenu: $($item.menuName)"
                    $addedDeeperMenus = 0
                    foreach ($deeperMenu in $deeperMenus)
                    {
                        Write-Verbose "[$functionName] Processing deeper nested menu: $deeperMenu"
                        if ($deeperMenu -notin $nestedMenus)
                        {
                            $nestedMenus += $deeperMenu
                            $addedDeeperMenus++
                            Write-Log -LogFile $LogFile -Module $functionName -Message "Added deeper nested menu from '$($item.menuName)': $deeperMenu" -LogLevel "Debug"
                            Write-Verbose "[$functionName] Added deeper nested menu: $deeperMenu"
                        }
                        else
                        {
                            Write-Log -LogFile $LogFile -Module $functionName -Message "Deeper menu already tracked: $deeperMenu" -LogLevel "Debug"
                            Write-Verbose "[$functionName] Deeper menu already tracked: $deeperMenu"
                        }
                    }
                    if ($addedDeeperMenus -gt 0)
                    {
                        Write-Log -LogFile $LogFile -Module $functionName -Message "Added $addedDeeperMenus deeper nested menus from: $($item.menuName)" -LogLevel "Debug"
                        Write-Verbose "[$functionName] Added $addedDeeperMenus deeper nested menus from: $($item.menuName)"
                    }
                }
                elseif ($item.menuName)
                {
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Menu reference already tracked: $($item.menuName) (from item: $itemName)" -LogLevel "Debug"
                    Write-Verbose "[$functionName] Menu reference already tracked: $($item.menuName)"
                }
            }
        }
        else
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Menu '$MenuName' has no items or items property" -LogLevel "Debug"
            Write-Verbose "[$functionName] Menu '$MenuName' has no items or items property"
        }
    }
    else
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Menu definition not found in configuration: $MenuName" -LogLevel "Warning"
        Write-Verbose "[$functionName] Menu definition not found in configuration: $MenuName"
    }

    # Summary logging
    Write-Log -LogFile $LogFile -Module $functionName -Message "Recursive analysis completed for '$MenuName' - Items: $itemsProcessed, References: $nestedReferencesFound, Total nested: $($nestedMenus.Count)" -LogLevel "Debug"
    if ($nestedMenus.Count -gt 0)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Nested menus found for '$MenuName': [$($nestedMenus -join ', ')]" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Nested menus found for '$MenuName': [$($nestedMenus -join ', ')]"
    }

    return $nestedMenus
}
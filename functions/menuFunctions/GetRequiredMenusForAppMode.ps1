function GetRequiredMenusForAppMode()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$CurrentAppMode = $settings.appMode,
        [Parameter(Mandatory = $false)]
        [string]$MenuConfigFile = "$pwd\menu.json"
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Determining required menus for app mode: $CurrentAppMode"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Determining required menus for app mode: $CurrentAppMode" -LogLevel "Debug"
    
    # Always include the main menu
    $requiredMenus = @("mainMenu")
    
    # If no app mode specified or full mode, return all menus
    if (-not $CurrentAppMode -or $CurrentAppMode -eq "full")
    {
        Write-Verbose "[$functionName] Full access mode, returning all available menus"
        
        try 
        {
            # Get all menu names from cached configuration
            $menuConfig = Get-CachedMenuConfiguration -MenuConfigFile $MenuConfigFile
            $allMenus = $menuConfig.PSObject.Properties.Name | Where-Object { $_ -notlike "appMode*" -and $_ -notin @("name", "description", "version") }
            Write-Verbose "[$functionName] Found $($allMenus.Count) total menus"
            return $allMenus
        }
        catch 
        {
            Write-Verbose "[$functionName] Error reading menu configuration, using minimal set: $_"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Error reading menu configuration: $_" -LogLevel "Warning"
            return $requiredMenus
        }
    }
    
    try
    {
        # Get app mode hierarchy for filtering
        $hierarchyAllowed = Get-AppModeHierarchy -CurrentAppMode $CurrentAppMode
        Write-Verbose "[$functionName] App mode hierarchy: [$($hierarchyAllowed -join ', ')]"
        
        # Load menu configuration to analyze dependencies
        $menuConfig = Get-CachedMenuConfiguration -MenuConfigFile $MenuConfigFile
        
        # Analyze main menu items to find required submenus
        if ($menuConfig.mainMenu -and $menuConfig.mainMenu.items)
        {
            $filteredMainItems = FilterMenuItemsByAppMode -MenuItems $menuConfig.mainMenu.items -CurrentAppMode $CurrentAppMode
            
            foreach ($item in $filteredMainItems)
            {
                # If item references a submenu, add it to required menus
                if ($item.menuName -and $item.menuName -notin $requiredMenus)
                {
                    $requiredMenus += $item.menuName
                    Write-Verbose "[$functionName] Adding required submenu: $($item.menuName)"
                    
                    # Recursively check for nested menu dependencies
                    $nestedMenus = GetRequiredMenusRecursive -MenuName $item.menuName -MenuConfig $menuConfig -CurrentAppMode $CurrentAppMode
                    foreach ($nestedMenu in $nestedMenus)
                    {
                        if ($nestedMenu -notin $requiredMenus)
                        {
                            $requiredMenus += $nestedMenu
                            Write-Verbose "[$functionName] Adding nested required menu: $nestedMenu"
                        }
                    }
                }
            }
        }
        
        Write-Verbose "[$functionName] Required menus for '$CurrentAppMode': [$($requiredMenus -join ', ')]"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Required menus for '$CurrentAppMode': [$($requiredMenus -join ', ')]" -LogLevel "Information"
        
        return $requiredMenus
    }
    catch
    {
        Write-Verbose "[$functionName] Error analyzing menu dependencies: $_"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error analyzing menu dependencies: $_" -LogLevel "Error"
        return $requiredMenus
    }
}

function GetRequiredMenusRecursive()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MenuName,
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$MenuConfig,
        [Parameter(Mandatory = $false)]
        [string]$CurrentAppMode = $settings.appMode
    )
    
    $nestedMenus = @()
    
    # Check if the specified menu exists in configuration
    if ($MenuConfig.PSObject.Properties.Name -contains $MenuName)
    {
        $menuDef = $MenuConfig.$MenuName
        
        # If this menu has items, check for nested menu references
        if ($menuDef.items)
        {
            $filteredItems = FilterMenuItemsByAppMode -MenuItems $menuDef.items -CurrentAppMode $CurrentAppMode
            
            foreach ($item in $filteredItems)
            {
                if ($item.menuName -and $item.menuName -notin $nestedMenus)
                {
                    $nestedMenus += $item.menuName
                    
                    # Recursively check this nested menu
                    $deeperMenus = GetRequiredMenusRecursive -MenuName $item.menuName -MenuConfig $MenuConfig -CurrentAppMode $CurrentAppMode
                    foreach ($deeperMenu in $deeperMenus)
                    {
                        if ($deeperMenu -notin $nestedMenus)
                        {
                            $nestedMenus += $deeperMenu
                        }
                    }
                }
            }
        }
    }
    
    return $nestedMenus
}
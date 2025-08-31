function FilterMenuItemsByAppMode()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$MenuItems,
        [Parameter(Mandatory = $false)]
        [string]$CurrentAppMode = $settings.appMode,
        [Parameter(Mandatory = $false)]
        [string]$MenuConfigFile = "$pwd\menu.json"
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Filtering $($MenuItems.Count) menu items for app mode: $CurrentAppMode"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Filtering $($MenuItems.Count) menu items for app mode: $CurrentAppMode" -LogLevel "Debug"
    
    # If no app mode specified, return all items
    if (-not $CurrentAppMode)
    {
        Write-Verbose "[$functionName] No app mode specified, returning all items"
        return $MenuItems
    }
    
    # Get app mode hierarchy for filtering
    try
    {
        $hierarchyAllowed = Get-AppModeHierarchy -CurrentAppMode $CurrentAppMode
        Write-Verbose "[$functionName] App mode hierarchy for '$CurrentAppMode': [$($hierarchyAllowed -join ', ')]"
        Write-Log -LogFile $LogFile -Module $functionName -Message "App mode hierarchy: [$($hierarchyAllowed -join ', ')]" -LogLevel "Debug"
    }
    catch
    {
        Write-Verbose "[$functionName] Error getting app mode hierarchy, falling back to current mode only: $_"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error getting app mode hierarchy: $_, using current mode only" -LogLevel "Warning"
        $hierarchyAllowed = @($CurrentAppMode)
    }
    
    # If hierarchy includes '*' (full mode), return all items
    if ($hierarchyAllowed -contains '*')
    {
        Write-Verbose "[$functionName] Full access mode detected, returning all items"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Full access mode detected, returning all $($MenuItems.Count) items" -LogLevel "Debug"
        return $MenuItems
    }
    
    # Filter items based on includeInDisplayModes
    $filteredItems = @()
    foreach ($item in $MenuItems)
    {
        $includeItem = $false
        
        # If no includeInDisplayModes specified, include by default (legacy compatibility)
        if (-not $item.includeInDisplayModes -or $item.includeInDisplayModes.Count -eq 0)
        {
            $includeItem = $true
            Write-Verbose "[$functionName] Item '$($item.name)' has no display mode restrictions, including"
        }
        else
        {
            # Check if any of the item's allowed modes match our hierarchy
            foreach ($allowedMode in $item.includeInDisplayModes)
            {
                if ($hierarchyAllowed -contains $allowedMode)
                {
                    $includeItem = $true
                    Write-Verbose "[$functionName] Item '$($item.name)' matches mode '$allowedMode', including"
                    break
                }
            }
        }
        
        if ($includeItem)
        {
            $filteredItems += $item
            Write-Log -LogFile $LogFile -Module $functionName -Message "Including item: $($item.name)" -LogLevel "Debug"
        }
        else
        {
            Write-Verbose "[$functionName] Excluding item '$($item.name)' - allowed modes: [$($item.includeInDisplayModes -join ', ')] vs hierarchy: [$($hierarchyAllowed -join ', ')]"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Excluding item: $($item.name) (not in app mode hierarchy)" -LogLevel "Debug"
        }
    }
    
    Write-Verbose "[$functionName] Filtered from $($MenuItems.Count) to $($filteredItems.Count) items for app mode: $CurrentAppMode"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Filtered from $($MenuItems.Count) to $($filteredItems.Count) items" -LogLevel "Information"
    
    return $filteredItems
}
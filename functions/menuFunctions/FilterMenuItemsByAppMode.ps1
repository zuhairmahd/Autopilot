function FilterMenuItemsByAppMode()
{
    <#
    .SYNOPSIS
        Filters menu items based on current application mode(s) with extensive logging.
    
    .DESCRIPTION
        Filters menu items based on the current application mode hierarchy, supporting both
        single and multiple app modes. Provides comprehensive logging for performance 
        monitoring and troubleshooting.
    
    .PARAMETER MenuItems
        Array of menu items to filter
        
    .PARAMETER CurrentAppMode
        Current application mode (defaults to settings.appMode for backward compatibility)
        
    .PARAMETER CurrentAppModes
        Array of current application modes (takes precedence over CurrentAppMode)
        
    .PARAMETER MenuConfigFile
        Path to menu configuration file
        
    .OUTPUTS
        Array - Filtered menu items appropriate for the current app mode(s)
        
    .NOTES
        - Extensive logging for performance optimization monitoring
        - Supports both single and multiple app modes
        - Maintains full backward compatibility
        - Part of menu loading optimization system
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$MenuItems,
        [Parameter(Mandatory = $false)]
        [string]$CurrentAppMode = $null,
        [Parameter(Mandatory = $false)]
        [array]$CurrentAppModes = $null,
        [Parameter(Mandatory = $false)]
        [string]$MenuConfigFile = "$pwd\menu.psd1"
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Determine effective app modes to use
    $effectiveAppModes = $null
    
    if ($CurrentAppModes -and $CurrentAppModes.Count -gt 0)
    {
        # Use provided multiple modes
        $effectiveAppModes = $CurrentAppModes
        Write-Log -LogFile $LogFile -Module $functionName -Message "Using provided app modes: [$($CurrentAppModes -join ', ')] ($($CurrentAppModes.Count) modes)" -LogLevel "Debug"
    }
    elseif ($CurrentAppMode)
    {
        # Use provided single mode for backward compatibility
        $effectiveAppModes = @($CurrentAppMode)
        Write-Log -LogFile $LogFile -Module $functionName -Message "Using provided single app mode: '$CurrentAppMode' (backward compatibility)" -LogLevel "Debug"
    }
    else
    {
        # Auto-detect from settings
        $effectiveAppModes = Get-EffectiveAppModes -Settings $settings
        Write-Log -LogFile $LogFile -Module $functionName -Message "Auto-detected effective app modes: [$($effectiveAppModes -join ', ')] ($($effectiveAppModes.Count) modes)" -LogLevel "Debug"
    }
    
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting menu item filtering operation" -LogLevel "Debug"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Input parameters - Items: $($MenuItems.Count), AppModes: [$($effectiveAppModes -join ', ')], ConfigFile: '$MenuConfigFile'" -LogLevel "Debug"
    
    # Performance tracking
    $startTime = Get-Date
    
    # If no app modes specified, return all items
    if (-not $effectiveAppModes -or $effectiveAppModes.Count -eq 0)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "No app modes specified, returning all $($MenuItems.Count) items" -LogLevel "Verbose"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Filter operation completed in $((Get-Date) - $startTime) milliseconds" -LogLevel "Debug"
        return $MenuItems
    }
    
    # Get combined app mode hierarchy for filtering
    try
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Retrieving combined app mode hierarchy for: [$($effectiveAppModes -join ', ')]" -LogLevel "Debug"
        $hierarchyAllowed = Get-MultipleAppModeHierarchy -AppModes $effectiveAppModes -ResolutionStrategy 'Additive'
        Write-Log -LogFile $LogFile -Module $functionName -Message "Combined app mode hierarchy resolved: [$($hierarchyAllowed -join ', ')] - $($hierarchyAllowed.Count) modes" -LogLevel "Verbose"
    }
    catch
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error getting combined app mode hierarchy: $_, defaulting to provided modes only" -LogLevel "Warning"
        $hierarchyAllowed = $effectiveAppModes
        Write-Log -LogFile $LogFile -Module $functionName -Message "Using fallback hierarchy: [$($hierarchyAllowed -join ', ')]" -LogLevel "Debug"
    }
    
    # If hierarchy includes '*' (full mode), return all items
    if ($hierarchyAllowed -contains '*')
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Full access mode detected in hierarchy, returning all $($MenuItems.Count) items without filtering" -LogLevel "Verbose"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Filter operation completed in $((Get-Date) - $startTime) milliseconds" -LogLevel "Debug"
        return $MenuItems
    }
    
    # Filter items based on includeInDisplayModes
    $filteredItems = @()
    $includedCount = 0
    $excludedCount = 0
    $noRestrictionsCount = 0
    
    Write-Log -LogFile $LogFile -Module $functionName -Message "Beginning item-by-item filtering process" -LogLevel "Debug"
    
    foreach ($item in $MenuItems)
    {
        $includeItem = $false
        $itemName = if ($item.name) { $item.name } else { "Unnamed Item" }
        
        # If no includeInDisplayModes specified, include by default (legacy compatibility)
        if (-not $item.includeInDisplayModes -or $item.includeInDisplayModes.Count -eq 0)
        {
            $includeItem = $true
            $noRestrictionsCount++
            Write-Log -LogFile $LogFile -Module $functionName -Message "Item '$itemName' has no display mode restrictions, including (legacy compatibility)" -LogLevel "Debug"
        }
        else
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Evaluating item '$itemName' with display modes: [$($item.includeInDisplayModes -join ', ')]" -LogLevel "Debug"
            
            # Check if any of the item's allowed modes match our hierarchy
            foreach ($allowedMode in $item.includeInDisplayModes)
            {
                if ($hierarchyAllowed -contains $allowedMode)
                {
                    $includeItem = $true
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Item '$itemName' matches mode '$allowedMode' in hierarchy, including" -LogLevel "Debug"
                    break
                }
            }
            
            if (-not $includeItem)
            {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Item '$itemName' excluded - allowed modes [$($item.includeInDisplayModes -join ', ')] do not match hierarchy [$($hierarchyAllowed -join ', ')]" -LogLevel "Debug"
            }
        }
        
        if ($includeItem)
        {
            $filteredItems += $item
            $includedCount++
            Write-Log -LogFile $LogFile -Module $functionName -Message "Including item: $itemName" -LogLevel "Debug"
        }
        else
        {
            $excludedCount++
            Write-Log -LogFile $LogFile -Module $functionName -Message "Excluding item: $itemName (not in app mode hierarchy)" -LogLevel "Debug"
        }
    }
    
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalMilliseconds
    
    # Summary logging
    Write-Log -LogFile $LogFile -Module $functionName -Message "Filter operation completed - Original: $($MenuItems.Count), Included: $includedCount, Excluded: $excludedCount, No Restrictions: $noRestrictionsCount" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Performance: Filter operation completed in $duration milliseconds" -LogLevel "Verbose"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Reduction achieved: $(if ($MenuItems.Count -gt 0) { [math]::Round((($MenuItems.Count - $filteredItems.Count) / $MenuItems.Count) * 100, 1) } else { 0 })% of items filtered out" -LogLevel "Verbose"
    
    return $filteredItems
}
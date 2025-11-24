function Get-AppModeHierarchy()
{
    <#
    .SYNOPSIS
    Retrieves the application mode hierarchy for a given app mode.

    .DESCRIPTION
    This function returns the hierarchy of application modes for a specified app mode by querying
    the menu configuration. The hierarchy determines which app modes inherit settings and menus
    from parent modes. If no hierarchy is defined or menu configuration is unavailable, returns
    only the current app mode.

    .PARAMETER CurrentAppMode
    The current application mode to get hierarchy for. This parameter is mandatory.

    .OUTPUTS
    System.Array
    Returns array of app mode strings in hierarchical order, or single-element array with current mode if no hierarchy defined.

    .EXAMPLE
    $hierarchy = Get-AppModeHierarchy -CurrentAppMode "DeviceManagement"

    .NOTES
    Queries menu configuration for appModeHierarchy definition.
    Falls back to current mode only if configuration unavailable or undefined.
    Used for settings and menu inheritance in application mode system.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CurrentAppMode
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Getting app mode hierarchy for: $CurrentAppMode" -LogLevel "Debug"
    
    try
    {
        # Load menu configuration to get hierarchy
        $menuConfig = Get-MenuConfiguration
        
        if ($null -eq $menuConfig)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Menu configuration not available, falling back to current mode only" -LogLevel "Warning"
            return @($CurrentAppMode)
        }
        
        # Check if hierarchy is defined in menu configuration
        if ($menuConfig.PSObject.Properties.Name -contains 'appModeHierarchy')
        {
            $hierarchy = $menuConfig.appModeHierarchy
            
            # Check if current app mode has a defined hierarchy
            if ($hierarchy.PSObject.Properties.Name -contains $CurrentAppMode)
            {
                $allowedModes = $hierarchy.$CurrentAppMode
                Write-Log -LogFile $LogFile -Module $functionName -Message "Found hierarchy for '$CurrentAppMode': [$($allowedModes -join ', ')]" -LogLevel "Verbose"
                return $allowedModes
            }
            else
            {
                Write-Log -LogFile $LogFile -Module $functionName -Message "No hierarchy defined for '$CurrentAppMode', using current mode only" -LogLevel "Warning"
                return @($CurrentAppMode)
            }
        }
        else
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "No appModeHierarchy found in menu configuration, using current mode only" -LogLevel "Verbose"
            return @($CurrentAppMode)
        }
    }
    catch
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error getting app mode hierarchy: $_" -LogLevel "Error"
        # Fallback to current mode only
        return @($CurrentAppMode)
    }
}

function Get-MultipleAppModeHierarchy()
{
    <#
    .SYNOPSIS
        Gets combined app mode hierarchy for multiple modes with conflict resolution.
    
    .DESCRIPTION
        Wrapper function that handles both single and multiple app modes. For multiple modes,
        it uses Get-CombinedAppModeHierarchy to resolve conflicts and combine permissions.
        Maintains backward compatibility with single mode configurations.
    
    .PARAMETER AppModes
        Array of app modes or single app mode string
        
    .PARAMETER ResolutionStrategy
        Strategy for resolving conflicts when multiple modes are provided
        
    .OUTPUTS
        Array - Combined hierarchy of allowed modes
        
    .EXAMPLE
        $hierarchy = Get-MultipleAppModeHierarchy -AppModes @('helpDesk', 'registration')
        
    .EXAMPLE  
        $hierarchy = Get-MultipleAppModeHierarchy -AppModes 'admin' -ResolutionStrategy 'Precedence'
        
    .NOTES
        - Maintains full backward compatibility with single mode usage
        - Automatically determines if multiple modes are being used
        - Uses additive strategy by default for multiple modes
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        $AppModes = (Get-EffectiveAppModes -Settings $settings),
        [Parameter(Mandatory = $false)]
        [ValidateSet('Additive', 'Precedence')]
        [string]$ResolutionStrategy = 'Additive'
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Normalize input to array
    if ($AppModes -is [string])
    {
        $AppModes = @($AppModes)
    }
    elseif ($null -eq $AppModes -or $AppModes.Count -eq 0)
    {
        $AppModes = @('full')  # Default fallback
    }
    
    Write-Log -LogFile $LogFile -Module $functionName -Message "Getting hierarchy for modes: [$($AppModes -join ', ')] using $ResolutionStrategy strategy" -LogLevel "Debug"
    
    # For single mode, use existing function
    if ($AppModes.Count -eq 1)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Single mode detected, using standard hierarchy function" -LogLevel "Debug"
        return Get-AppModeHierarchy -CurrentAppMode $AppModes[0]
    }
    
    # For multiple modes, use combined hierarchy function
    try
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Multiple modes detected, using combined hierarchy resolution" -LogLevel "Information"
        $combinedResult = Get-CombinedAppModeHierarchy -AppModes $AppModes -ResolutionStrategy $ResolutionStrategy
        
        if ($combinedResult.Conflicts.Count -gt 0)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Conflicts detected and resolved: $($combinedResult.Resolution)" -LogLevel "Information"
        }
        
        return $combinedResult.AllowedModes
    }
    catch
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error getting combined hierarchy: $($_.Exception.Message) - falling back to union" -LogLevel "Warning"
        
        # Fallback: simple union of individual hierarchies
        $allModes = @()
        foreach ($mode in $AppModes)
        {
            try
            {
                $hierarchy = Get-AppModeHierarchy -CurrentAppMode $mode
                $allModes += $hierarchy
            }
            catch
            {
                $allModes += $mode
            }
        }
        
        return ($allModes | Select-Object -Unique)
    }
}
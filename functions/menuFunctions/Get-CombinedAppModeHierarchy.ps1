function Get-CombinedAppModeHierarchy()
{
    <#
    .SYNOPSIS
        Combines multiple app mode hierarchies into a unified permission set with conflict resolution.
    
    .DESCRIPTION
        Takes multiple app modes and combines their hierarchies to create a unified set of allowed modes.
        Handles conflicts by applying precedence rules and provides detailed logging of resolution decisions.
        Supports both additive permissions (union) and precedence-based resolution.
    
    .PARAMETER AppModes
        Array of app modes to combine
        
    .PARAMETER ResolutionStrategy
        Strategy for resolving conflicts: 'Additive' (default) combines permissions, 'Precedence' uses hierarchy order
        
    .OUTPUTS
        Hashtable containing:
        - AllowedModes: Combined array of allowed modes
        - Conflicts: Array of detected conflicts
        - Resolution: Description of how conflicts were resolved
        - PrecedenceOrder: Order of precedence used for resolution
        
    .EXAMPLE
        $combined = Get-CombinedAppModeHierarchy -AppModes @('helpDesk', 'registration')
        
    .EXAMPLE
        $combined = Get-CombinedAppModeHierarchy -AppModes @('admin', 'helpDesk') -ResolutionStrategy 'Precedence'
        
    .NOTES
        - Uses menu.psd1 appModeHierarchy for conflict detection
        - Additive strategy provides union of all permissions (more permissive)
        - Precedence strategy respects hierarchy order (more restrictive)
        - Full mode ('*') always takes precedence in any combination
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$AppModes,
        [Parameter(Mandatory = $false)]
        [ValidateSet('Additive', 'Precedence')]
        [string]$ResolutionStrategy = 'Additive'
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Combining app mode hierarchies for modes: [$($AppModes -join ', ')] using $ResolutionStrategy strategy" -LogLevel "Debug"
    
    $result = @{
        AllowedModes = @()
        Conflicts = @()
        Resolution = ""
        PrecedenceOrder = @()
        EffectiveModes = $AppModes
    }
    
    try
    {
        # If only one mode, use existing hierarchy function
        if ($AppModes.Count -eq 1)
        {
            $hierarchy = Get-AppModeHierarchy -CurrentAppMode $AppModes[0]
            $result.AllowedModes = $hierarchy
            $result.Resolution = "Single mode - no conflicts to resolve"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Single mode hierarchy: [$($hierarchy -join ', ')]" -LogLevel "Verbose"
            return $result
        }
        
        # Check for 'full' mode - it takes precedence over everything
        if ($AppModes -contains 'full')
        {
            $result.AllowedModes = @('*')
            $result.Resolution = "Full mode detected - grants access to all features"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Full mode detected in combination - granting all permissions" -LogLevel "Information"
            return $result
        }
        
        # Get hierarchy for each mode
        $modeHierarchies = @{}
        $allPermissions = @()
        
        foreach ($mode in $AppModes)
        {
            try
            {
                $hierarchy = Get-AppModeHierarchy -CurrentAppMode $mode
                $modeHierarchies[$mode] = $hierarchy
                $allPermissions += $hierarchy
                Write-Log -LogFile $LogFile -Module $functionName -Message "Mode '$mode' hierarchy: [$($hierarchy -join ', ')]" -LogLevel "Debug"
            }
            catch
            {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Error getting hierarchy for mode '$mode': $($_.Exception.Message)" -LogLevel "Warning"
                $modeHierarchies[$mode] = @($mode)  # Fallback to just the mode itself
                $allPermissions += $mode
            }
        }
        
        # Detect conflicts and establish precedence order
        $precedenceOrder = Get-AppModePrecedenceOrder -AppModes $AppModes
        $result.PrecedenceOrder = $precedenceOrder
        
        $conflicts = Get-AppModeConflicts -ModeHierarchies $modeHierarchies -AppModes $AppModes
        $result.Conflicts = $conflicts
        
        # Apply resolution strategy
        switch ($ResolutionStrategy)
        {
            'Additive'
            {
                # Additive: Union of all permissions (more permissive)
                $uniquePermissions = $allPermissions | Select-Object -Unique | Sort-Object
                $result.AllowedModes = $uniquePermissions
                $result.Resolution = "Additive strategy applied: Combined all permissions from $($AppModes.Count) modes"
                
                if ($conflicts.Count -gt 0)
                {
                    $result.Resolution += ". Conflicts resolved by combining all permissions."
                }
                
                Write-Log -LogFile $LogFile -Module $functionName -Message "Additive resolution: [$($uniquePermissions -join ', ')] from modes [$($AppModes -join ', ')]" -LogLevel "Information"
            }
            
            'Precedence'
            {
                # Precedence: Use highest precedence mode's permissions
                $highestPrecedenceMode = $precedenceOrder[0]
                $result.AllowedModes = $modeHierarchies[$highestPrecedenceMode]
                $result.Resolution = "Precedence strategy applied: Using permissions from highest precedence mode '$highestPrecedenceMode'"
                
                if ($conflicts.Count -gt 0)
                {
                    $conflictingModes = $conflicts | ForEach-Object { $_.Modes } | Select-Object -Unique
                    $result.Resolution += ". Conflicts between [$($conflictingModes -join ', ')] resolved by precedence order."
                }
                
                Write-Log -LogFile $LogFile -Module $functionName -Message "Precedence resolution: Using '$highestPrecedenceMode' permissions: [$($result.AllowedModes -join ', ')]" -LogLevel "Information"
            }
        }
        
        Write-Log -LogFile $LogFile -Module $functionName -Message "Mode combination completed: $($result.Resolution)" -LogLevel "Information"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Final allowed modes: [$($result.AllowedModes -join ', ')] ($($result.AllowedModes.Count) unique permissions)" -LogLevel "Verbose"
        
        return $result
    }
    catch
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error combining app mode hierarchies: $($_.Exception.Message)" -LogLevel "Error"
        
        # Fallback: use simple union of provided modes
        $result.AllowedModes = $AppModes | Select-Object -Unique
        $result.Resolution = "Error occurred - using simple union of provided modes as fallback"
        return $result
    }
}

function Get-AppModePrecedenceOrder()
{
    <#
    .SYNOPSIS
        Determines precedence order for app modes based on hierarchy definitions.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$AppModes
    )
    
    # Define precedence order (highest to lowest)
    $predefinedOrder = @('full', 'admin', 'advanced', 'advancedRegistration', 'helpDesk', 'registration', 'custom')
    
    # Sort the provided modes by predefined precedence
    $orderedModes = @()
    foreach ($precedenceMode in $predefinedOrder)
    {
        if ($AppModes -contains $precedenceMode)
        {
            $orderedModes += $precedenceMode
        }
    }
    
    # Add any modes not in predefined order at the end
    foreach ($mode in $AppModes)
    {
        if ($mode -notin $orderedModes)
        {
            $orderedModes += $mode
        }
    }
    
    return $orderedModes
}

function Get-AppModeConflicts()
{
    <#
    .SYNOPSIS
        Detects conflicts between app modes based on their hierarchies.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ModeHierarchies,
        [Parameter(Mandatory = $true)]
        [array]$AppModes
    )
    
    $conflicts = @()
    
    # For now, we'll define conflicts as modes where one includes the other in its hierarchy
    # This indicates a redundant or potentially conflicting combination
    for ($i = 0; $i -lt $AppModes.Count; $i++)
    {
        for ($j = $i + 1; $j -lt $AppModes.Count; $j++)
        {
            $mode1 = $AppModes[$i]
            $mode2 = $AppModes[$j]
            
            $hierarchy1 = $ModeHierarchies[$mode1]
            $hierarchy2 = $ModeHierarchies[$mode2]
            
            # Check if one mode's hierarchy includes the other mode
            if ($hierarchy1 -contains $mode2 -or $hierarchy2 -contains $mode1)
            {
                $conflicts += @{
                    Modes = @($mode1, $mode2)
                    Type = "Hierarchical"
                    Description = "Mode '$mode1' and '$mode2' have overlapping hierarchies"
                }
            }
        }
    }
    
    return $conflicts
}
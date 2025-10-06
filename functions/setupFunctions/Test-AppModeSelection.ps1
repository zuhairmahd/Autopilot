function Test-AppModeSelection()
{
    <#
    .SYNOPSIS
        Validates app mode selection and detects conflicts/redundancies.
    #>
    [CmdletBinding()]
    param(
        [array]$SelectedModes
    )
    
    $result = @{
        IsValid              = $true
        ErrorMessage         = ""
        HasConflicts         = $false
        HasRedundancy        = $false
        Conflicts            = @()
        Redundancies         = @()
        EffectivePermissions = @()
        Resolution           = ""
    }
    
    try
    {
        # Get combined hierarchy and check for conflicts
        $combinedResult = Get-CombinedAppModeHierarchy -AppModes $SelectedModes -ResolutionStrategy 'Additive'
        
        $result.EffectivePermissions = $combinedResult.AllowedModes
        $result.Resolution = $combinedResult.Resolution
        
        if ($combinedResult.Conflicts.Count -gt 0)
        {
            $result.HasConflicts = $true
            $result.Conflicts = $combinedResult.Conflicts
        }
        
        # Check for redundancies (when higher precedence modes include lower ones)
        $precedenceOrder = @('full', 'admin', 'advanced', 'advancedRegistration', 'helpDesk', 'registration', 'custom')
        
        foreach ($mode in $SelectedModes)
        {
            $modeHierarchy = Get-AppModeHierarchy -CurrentAppMode $mode
            
            foreach ($otherMode in $SelectedModes)
            {
                if ($mode -ne $otherMode -and $modeHierarchy -contains $otherMode)
                {
                    $result.HasRedundancy = $true
                    $result.Redundancies += "'$mode' already includes '$otherMode' permissions"
                }
            }
        }
        
        # Special case: full mode with any other mode
        if ($SelectedModes -contains 'full' -and $SelectedModes.Count -gt 1)
        {
            $result.HasRedundancy = $true
            $result.Redundancies += "Full mode grants all permissions - other modes are redundant"
        }
    }
    catch
    {
        $result.IsValid = $false
        $result.ErrorMessage = "Error validating mode selection: $($_.Exception.Message)"
    }
    
    return $result
}

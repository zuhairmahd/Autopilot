function Get-AppModeHierarchy()
{
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
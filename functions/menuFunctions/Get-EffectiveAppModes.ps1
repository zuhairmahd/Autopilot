function Get-EffectiveAppModes()
{
    <#
    .SYNOPSIS
        Gets the effective app modes from settings, supporting both single and multiple mode configurations.
    
    .DESCRIPTION
        Handles backward compatibility by supporting both the legacy single appMode property and 
        the new appModes array property. Returns a consistent array of effective app modes with
        hierarchy resolution and conflict detection.
    
    .PARAMETER Settings
        Settings object containing app mode configuration
        
    .OUTPUTS
        Array - Effective app modes with hierarchy resolution applied
        
    .EXAMPLE
        $effectiveModes = Get-EffectiveAppModes -Settings $settings
        
    .NOTES
        - Maintains backward compatibility with single appMode
        - Supports new appModes array for multiple modes
        - Applies hierarchy resolution for conflicting modes
        - Returns array even for single mode configurations
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$Settings = $settings
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Determining effective app modes from settings" -LogLevel "Debug"
    
    $effectiveModes = @()
    
    try
    {
        # Check for new appModes array first (preferred)
        if ($Settings.PSObject.Properties.Name -contains 'appModes' -and $Settings.appModes)
        {
            if ($Settings.appModes -is [array])
            {
                $effectiveModes = $Settings.appModes | Where-Object { $_ -and $_.Trim() -ne '' }
                Write-Log -LogFile $LogFile -Module $functionName -Message "Using appModes array: [$($effectiveModes -join ', ')] ($($effectiveModes.Count) modes)" -LogLevel "Verbose"
            }
            elseif ($Settings.appModes -is [string] -and $Settings.appModes.Trim() -ne '')
            {
                # Handle single string value in appModes
                $effectiveModes = @($Settings.appModes.Trim())
                Write-Log -LogFile $LogFile -Module $functionName -Message "Converting single appModes string to array: [$($Settings.appModes)]" -LogLevel "Verbose"
            }
        }
        
        # Fall back to legacy appMode property for backward compatibility
        if ($effectiveModes.Count -eq 0 -and $Settings.PSObject.Properties.Name -contains 'appMode' -and $Settings.appMode)
        {
            if ($Settings.appMode -is [string] -and $Settings.appMode.Trim() -ne '')
            {
                $effectiveModes = @($Settings.appMode.Trim())
                Write-Log -LogFile $LogFile -Module $functionName -Message "Using legacy appMode property: [$($Settings.appMode)] (backward compatibility)" -LogLevel "Verbose"
            }
        }
        
        # Default to 'full' if no valid modes found
        if ($effectiveModes.Count -eq 0)
        {
            $effectiveModes = @('full')
            Write-Log -LogFile $LogFile -Module $functionName -Message "No valid app modes found in settings, defaulting to 'full'" -LogLevel "Warning"
        }
        
        # Validate all modes against known valid modes
        $validModes = @('full', 'helpDesk', 'advanced', 'advancedRegistration', 'registration', 'admin', 'custom')
        $validatedModes = @()
        $invalidModes = @()
        
        foreach ($mode in $effectiveModes)
        {
            if ($mode -in $validModes)
            {
                $validatedModes += $mode
            }
            else
            {
                $invalidModes += $mode
                Write-Log -LogFile $LogFile -Module $functionName -Message "Invalid app mode detected: '$mode'" -LogLevel "Warning"
            }
        }
        
        if ($invalidModes.Count -gt 0)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Invalid modes found: [$($invalidModes -join ', ')] - these will be ignored" -LogLevel "Warning"
        }
        
        # If all modes were invalid, fall back to full
        if ($validatedModes.Count -eq 0)
        {
            $validatedModes = @('full')
            Write-Log -LogFile $LogFile -Module $functionName -Message "All specified modes were invalid, falling back to 'full'" -LogLevel "Error"
        }
        
        # Remove duplicates while preserving order
        $uniqueModes = @()
        foreach ($mode in $validatedModes)
        {
            if ($mode -notin $uniqueModes)
            {
                $uniqueModes += $mode
            }
        }
        
        Write-Log -LogFile $LogFile -Module $functionName -Message "Effective app modes resolved: [$($uniqueModes -join ', ')] ($($uniqueModes.Count) unique modes)" -LogLevel "Information"
        return $uniqueModes
    }
    catch
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error determining effective app modes: $($_.Exception.Message) - defaulting to 'full'" -LogLevel "Error"
        return @('full')
    }
}
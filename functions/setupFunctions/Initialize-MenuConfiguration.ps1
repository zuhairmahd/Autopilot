function Initialize-MenuConfiguration()
{
    <#
    .SYNOPSIS
        Processes menu configuration from menu.psd1 file with defaults merging.
    
    .DESCRIPTION
        Loads and processes the menu.psd1 file, merging in any missing keys from defaults.
        Returns the complete menu hashtable with all menu structures and definitions.
        
    .PARAMETER MenuFilePath
        Path to the menu.psd1 file to load.
    
    .OUTPUTS
        Hashtable containing:
        - Menu: Hashtable with all menu definitions
        - Changed: Boolean indicating if missing keys were merged
    
    .EXAMPLE
        $result = Initialize-MenuConfiguration -MenuFilePath "C:\config\menu.psd1"
        if ($result.Changed) {
            # Menu was updated with missing keys
        }
        $menu = $result.Menu
    
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Uses Merge-ConfigurationDefaults to add missing keys
        - Preserves existing menu configurations
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MenuFilePath
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -logFile $logFile -Message "Initializing menu configuration" -module $functionName -logLevel "Information"
    Write-Verbose "[$functionName] Loading menu from: $MenuFilePath"
    
    $menu = @{}
    $changesMade = $false
    
    # Check if menu file exists
    if (-not (Test-Path -Path $MenuFilePath))
    {
        Write-Log -logFile $logFile -Message "Menu file not found: $MenuFilePath" -module $functionName -LogLevel "Warning"
        Write-Verbose "[$functionName] Menu file not found, returning empty menu"
        return @{ Menu = $menu; Changed = $false }
    }
    
    try
    {
        # Load menu file
        Write-Verbose "[$functionName] Loading menu configuration file"
        $menuData = Import-PowerShellDataFile -Path $MenuFilePath
        Write-Log -logFile $logFile -Message "Successfully loaded menu file" -module $functionName -LogLevel "Verbose"
        
        # Copy loaded menu
        foreach ($key in $menuData.Keys)
        {
            $menu[$key] = $menuData[$key]
        }
        
        Write-Verbose "[$functionName] Loaded $($menu.Keys.Count) menu keys"
        Write-Log -logFile $logFile -Message "Loaded $($menu.Keys.Count) menu keys" -module $functionName -LogLevel "Verbose"
        
        # Check against defaults and merge missing keys
        Write-Log -logFile $logFile -Message "Checking menu against defaults and merging missing keys" -module $functionName -logLevel "Information"
        
        try
        {
            # Get menu defaults
            $defaultMenu = Get-ApplicationDefaults -DefaultType "Menus"
            
            if ($defaultMenu)
            {
                Write-Verbose "[$functionName] Checking $($defaultMenu.Keys.Count) default menu keys"
                Write-Log -logFile $logFile -Message "Checking $($defaultMenu.Keys.Count) default menu keys" -module $functionName -logLevel "Verbose"
                
                # Use Merge-ConfigurationDefaults directly
                $mergedMenu = Merge-ConfigurationDefaults -ExistingConfig $menu -DefaultConfig $defaultMenu -PreserveExisting $true
                
                if ($mergedMenu)
                {
                    Write-Log -logFile $logFile -Message "Merged missing keys into menu configuration" -module $functionName -logLevel "Information"
                    Write-Verbose "[$functionName] Merged missing keys into menu configuration"
                    $menu = $mergedMenu
                    $changesMade = $true
                }
                else
                {
                    Write-Verbose "[$functionName] No missing keys to merge into menu"
                    Write-Log -logFile $logFile -Message "No missing keys to merge into menu" -module $functionName -logLevel "Verbose"
                }
            }
        }
        catch
        {
            Write-Warning "[$functionName] Error during menu merge: $($_.Exception.Message)"
            Write-Log -logFile $logFile -Message "Error during menu merge: $($_.Exception.Message)" -module $functionName -logLevel "Warning"
        }
    }
    catch
    {
        Write-Warning "[$functionName] Error loading menu file: $($_.Exception.Message)"
        Write-Log -logFile $logFile -Message "Error loading menu file: $($_.Exception.Message)" -module $functionName -logLevel "Warning"
        # Return empty menu on error
        return @{ Menu = @{}; Changed = $false }
    }
    
    Write-Log -logFile $logFile -Message "Menu configuration initialization completed (Changed: $changesMade)" -module $functionName -logLevel "Information"
    Write-Verbose "[$functionName] Menu configuration initialization completed (Changed: $changesMade)"
    
    return @{ Menu = $menu; Changed = $changesMade }
}

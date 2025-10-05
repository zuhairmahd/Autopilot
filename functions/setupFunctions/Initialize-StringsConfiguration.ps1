function Initialize-StringsConfiguration()
{
    <#
    .SYNOPSIS
        Processes strings configuration from strings.psd1 file with defaults merging.
    
    .DESCRIPTION
        Loads and processes the strings.psd1 file, merging in any missing keys from defaults.
        Returns the complete strings hashtable with all UI text and localization strings.
        
    .PARAMETER StringsFilePath
        Path to the strings.psd1 file to load.
    
    .OUTPUTS
        Hashtable containing:
        - Strings: Hashtable with all string resources
        - Changed: Boolean indicating if missing keys were merged
    
    .EXAMPLE
        $result = Initialize-StringsConfiguration -StringsFilePath "C:\config\strings.psd1"
        if ($result.Changed) {
            # Strings were updated with missing keys
        }
        $strings = $result.Strings
    
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Uses Merge-ConfigurationDefaults to add missing keys
        - Preserves existing string values
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StringsFilePath
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -logFile $logFile -Message "Initializing strings configuration" -module $functionName -logLevel "Information"
    Write-Verbose "[$functionName] Loading strings from: $StringsFilePath"
    
    $strings = @{}
    $changesMade = $false
    
    # Check if strings file exists
    if (-not (Test-Path -Path $StringsFilePath))
    {
        Write-Log -logFile $logFile -Message "Strings file not found: $StringsFilePath" -module $functionName -LogLevel "Warning"
        Write-Verbose "[$functionName] Strings file not found, returning empty strings"
        return @{ Strings = $strings; Changed = $false }
    }
    
    try
    {
        # Load strings file
        Write-Verbose "[$functionName] Loading strings configuration file"
        $stringsData = Import-PowerShellDataFile -Path $StringsFilePath
        Write-Log -logFile $logFile -Message "Successfully loaded strings file" -module $functionName -LogLevel "Verbose"
        
        # Copy loaded strings
        foreach ($key in $stringsData.Keys)
        {
            $strings[$key] = $stringsData[$key]
        }
        
        Write-Verbose "[$functionName] Loaded $($strings.Keys.Count) string keys"
        Write-Log -logFile $logFile -Message "Loaded $($strings.Keys.Count) string keys" -module $functionName -LogLevel "Verbose"
        
        # Check against defaults and merge missing keys
        Write-Log -logFile $logFile -Message "Checking strings against defaults and merging missing keys" -module $functionName -logLevel "Information"
        
        try
        {
            # Get strings defaults
            $defaultStrings = Get-ApplicationDefaults -DefaultType "Strings"
            
            if ($defaultStrings)
            {
                Write-Verbose "[$functionName] Checking $($defaultStrings.Keys.Count) default string keys"
                Write-Log -logFile $logFile -Message "Checking $($defaultStrings.Keys.Count) default string keys" -module $functionName -logLevel "Verbose"
                
                # Use Merge-ConfigurationDefaults directly
                $mergedStrings = Merge-ConfigurationDefaults -ExistingConfig $strings -DefaultConfig $defaultStrings -PreserveExisting $true
                
                if ($mergedStrings)
                {
                    Write-Log -logFile $logFile -Message "Merged missing keys into strings configuration" -module $functionName -logLevel "Information"
                    Write-Verbose "[$functionName] Merged missing keys into strings configuration"
                    $strings = $mergedStrings
                    $changesMade = $true
                }
                else
                {
                    Write-Verbose "[$functionName] No missing keys to merge into strings"
                    Write-Log -logFile $logFile -Message "No missing keys to merge into strings" -module $functionName -logLevel "Verbose"
                }
            }
        }
        catch
        {
            Write-Warning "[$functionName] Error during strings merge: $($_.Exception.Message)"
            Write-Log -logFile $logFile -Message "Error during strings merge: $($_.Exception.Message)" -module $functionName -logLevel "Warning"
        }
    }
    catch
    {
        Write-Warning "[$functionName] Error loading strings file: $($_.Exception.Message)"
        Write-Log -logFile $logFile -Message "Error loading strings file: $($_.Exception.Message)" -module $functionName -logLevel "Warning"
        # Return empty strings on error
        return @{ Strings = @{}; Changed = $false }
    }
    
    Write-Log -logFile $logFile -Message "Strings configuration initialization completed (Changed: $changesMade)" -module $functionName -logLevel "Information"
    Write-Verbose "[$functionName] Strings configuration initialization completed (Changed: $changesMade)"
    
    return @{ Strings = $strings; Changed = $changesMade }
}

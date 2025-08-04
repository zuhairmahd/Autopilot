function ConvertFrom-JsonToHashtable()
{
    <#
    .SYNOPSIS
        Converts a PSCustomObject (from ConvertFrom-Json) to a hashtable recursively.
    
    .DESCRIPTION
        This function recursively converts PSCustomObject instances to hashtables,
        which is necessary for proper merging operations. Arrays and other types
        are preserved as-is.
    
    .PARAMETER JsonObject
        The PSCustomObject to convert to a hashtable.
    
    .OUTPUTS
        System.Collections.Hashtable or original object type
        Returns a hashtable if input is PSCustomObject, otherwise returns the original object.
    
    .EXAMPLE
        $hashtable = ConvertFrom-JsonToHashtable -JsonObject $jsonObject
        
        Converts a JSON object to a hashtable for merging operations.
    
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Handles nested objects recursively
        - Preserves arrays and primitive types
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $JsonObject
    )
    
    if ($JsonObject -is [PSCustomObject])
    {
        $hashtable = @{}
        $JsonObject.PSObject.Properties | ForEach-Object {
            if ($_.Value -is [PSCustomObject])
            {
                $hashtable[$_.Name] = ConvertFrom-JsonToHashtable -JsonObject $_.Value
            }
            elseif ($_.Value -is [System.Array])
            {
                # Handle arrays - check if they contain PSCustomObjects
                $convertedArray = @()
                foreach ($item in $_.Value)
                {
                    if ($item -is [PSCustomObject])
                    {
                        $convertedArray += ConvertFrom-JsonToHashtable -JsonObject $item
                    }
                    else
                    {
                        $convertedArray += $item
                    }
                }
                $hashtable[$_.Name] = $convertedArray
            }
            else
            {
                $hashtable[$_.Name] = $_.Value
            }
        }
        return $hashtable
    }
    else
    {
        return $JsonObject
    }
}

function Merge-ConfigurationDefaults()
{
    <#
    .SYNOPSIS
        Merges default configuration values into an existing configuration object.
    
    .DESCRIPTION
        This function performs a deep merge of default configuration values into an existing 
        configuration object. It preserves existing values while adding any missing keys 
        from the defaults. This is used to ensure configuration files stay up-to-date
        with new default settings when the application is updated.
    
    .PARAMETER ExistingConfig
        The existing configuration hashtable to merge defaults into.
    
    .PARAMETER DefaultConfig
        The default configuration hashtable containing all current default values.
    
    .PARAMETER PreserveExisting
        If $true (default), existing values in ExistingConfig are preserved.
        If $false, default values will overwrite existing values.
    
    .OUTPUTS
        System.Collections.Hashtable
        Returns the merged configuration hashtable.
    
    .EXAMPLE
        $merged = Merge-ConfigurationDefaults -ExistingConfig $currentSettings -DefaultConfig $defaultSettings
        
        Merges default settings into current settings, preserving existing values.
    
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Handles nested hashtables recursively
        - Preserves array values from existing configuration
        - Uses regular hashtables for broader compatibility
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]$ExistingConfig,
        
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]$DefaultConfig,
        
        [bool]$PreserveExisting = $true
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting configuration merge"
    
    try
    {
        # Create a copy of the existing config to avoid modifying the original
        $mergedConfig = @{}
        
        # First, copy all existing values
        foreach ($key in $ExistingConfig.Keys)
        {
            $mergedConfig[$key] = $ExistingConfig[$key]
        }
        
        # Then, add any missing keys from defaults
        foreach ($key in $DefaultConfig.Keys)
        {
            if (-not $mergedConfig.ContainsKey($key))
            {
                Write-Verbose "[$functionName] Adding missing key: $key"
                $mergedConfig[$key] = $DefaultConfig[$key]
            }
            elseif ($mergedConfig[$key] -is [System.Collections.Hashtable] -and $DefaultConfig[$key] -is [System.Collections.Hashtable])
            {
                # Recursively merge nested hashtables
                Write-Verbose "[$functionName] Merging nested hashtable: $key"
                $mergedConfig[$key] = Merge-ConfigurationDefaults -ExistingConfig $mergedConfig[$key] -DefaultConfig $DefaultConfig[$key] -PreserveExisting $PreserveExisting
            }
            elseif (-not $PreserveExisting)
            {
                # Overwrite existing value with default if PreserveExisting is false
                Write-Verbose "[$functionName] Overwriting existing key: $key"
                $mergedConfig[$key] = $DefaultConfig[$key]
            }
            # If PreserveExisting is true and key exists, keep the existing value
        }
        
        Write-Verbose "[$functionName] Configuration merge completed successfully"
        return $mergedConfig
    }
    catch
    {
        Write-Verbose "[$functionName] Error during configuration merge: $($_.Exception.Message)"
        throw
    }
}
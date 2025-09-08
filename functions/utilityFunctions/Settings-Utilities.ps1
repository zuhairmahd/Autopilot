function Get-NestedValue()
{
    <#
    .SYNOPSIS
        Gets a value from a nested object using dot notation path.
        
    .DESCRIPTION
        Retrieves values from nested hashtables or PSCustomObjects using dot notation.
        Since PSD1 files return hashtables natively, this is optimized for hashtable access
        but maintains backward compatibility with PSCustomObjects.
    
    .PARAMETER Object
        The object to search in (hashtable or PSCustomObject).
        
    .PARAMETER Path
        Dot notation path to the desired value (e.g., "parent.child.property").
        
    .EXAMPLE
        Get-NestedValue -Object $settings -Path "globalSettings.appMode"
        
    .EXAMPLE
        Get-NestedValue -Object $domainConfig -Path "repoInfo.repoPath"
    #>
    [CmdletBinding()]
    param(
        $Object,
        [string]$Path
    )
    
    if (-not $Object -or [string]::IsNullOrWhiteSpace($Path))
    {
        return $null
    }
    
    $pathParts = $Path.Split('.')
    $current = $Object
    
    foreach ($part in $pathParts)
    {
        if ($current -is [hashtable])
        {
            if ($current.ContainsKey($part))
            {
                $current = $current[$part]
            }
            else
            {
                return $null
            }
        }
        elseif ($current -is [PSCustomObject])
        {
            if ($current.PSObject.Properties.Name -contains $part)
            {
                $current = $current.$part
            }
            else
            {
                return $null
            }
        }
        else
        {
            return $null
        }
    }
    
    return $current
}

function Get-FlattenedSettingsForProcessing()
{
    <#
    .SYNOPSIS
        Flattens settings structure for processing while preserving nested object information.
        
    .DESCRIPTION
        Consolidates the functionality of Get-FlattenedSettingsForEditing and Get-FlattenedSettingsForViewing
        into a single optimized function. Processes both template and current values to create a flat list 
        of settings with proper path information for nested values. Handles hashtables and PSCustomObjects.
        
    .PARAMETER SettingsTemplate
        The template settings structure containing default values and structure.
        
    .PARAMETER CurrentValues
        The current values from the configuration file.
        
    .PARAMETER ExcludeSettings
        Array of setting names to exclude from the flattened list.
        
    .EXAMPLE
        $flattened = Get-FlattenedSettingsForProcessing -SettingsTemplate $template -CurrentValues $current
        
    .EXAMPLE
        # Exclude groups settings
        $flattened = Get-FlattenedSettingsForProcessing -SettingsTemplate $template -CurrentValues $current -ExcludeSettings @('groupsToInclude', 'groupsToExclude')
    #>
    [CmdletBinding()]
    param(
        $SettingsTemplate,
        $CurrentValues,
        [string[]]$ExcludeSettings = @()
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Flattening settings for processing with $($ExcludeSettings.Count) exclusions"
    
    $flattenedSettings = @()
    
    if ($SettingsTemplate -is [hashtable] -or $SettingsTemplate -is [System.Collections.Specialized.OrderedDictionary])
    {
        # Handle hashtable and OrderedDictionary (auth settings and PSD1 native format)
        # Filter out system properties that aren't actual settings
        $systemProperties = @('Count', 'Keys', 'Values', 'IsReadOnly', 'IsFixedSize', 'SyncRoot', 'IsSynchronized')
        $settingsKeys = $SettingsTemplate.Keys | Where-Object { $_ -notin $systemProperties }
        
        foreach ($key in $settingsKeys)
        {
            # Skip excluded settings
            if ($ExcludeSettings -contains $key)
            {
                Write-Verbose "[$functionName] Excluding setting: $key"
                continue
            }
            
            $defaultValue = $SettingsTemplate[$key]
            $currentValue = Get-NestedValue -Object $CurrentValues -Path $key
            if ($null -eq $currentValue)
            {
                $currentValue = $defaultValue 
            }
            
            if ($defaultValue -is [hashtable] -or $defaultValue -is [PSCustomObject])
            {
                # Process nested object recursively
                $nestedSettings = Get-FlattenedSettingsForProcessing -SettingsTemplate $defaultValue -CurrentValues $currentValue -ExcludeSettings $ExcludeSettings
                foreach ($nestedSetting in $nestedSettings)
                {
                    $nestedSetting.Path = "$key.$($nestedSetting.Path)"
                    $nestedSetting.IsNested = $true
                }
                $flattenedSettings += $nestedSettings
            }
            else
            {
                # Simple value
                $flattenedSettings += @{
                    Name         = $key
                    Path         = $key
                    DefaultValue = $defaultValue
                    CurrentValue = $currentValue
                    IsNested     = $false
                }
            }
        }
    }
    else
    {
        # Handle PSCustomObject (legacy compatibility)
        foreach ($property in $SettingsTemplate.PSObject.Properties)
        {
            $key = $property.Name
            
            # Skip excluded settings
            if ($ExcludeSettings -contains $key)
            {
                Write-Verbose "[$functionName] Excluding setting: $key"
                continue
            }
            
            $defaultValue = $property.Value
            $currentValue = Get-NestedValue -Object $CurrentValues -Path $key
            if ($null -eq $currentValue)
            {
                $currentValue = $defaultValue 
            }
            
            if ($defaultValue -is [hashtable] -or $defaultValue -is [PSCustomObject])
            {
                # Process nested object recursively
                $nestedSettings = Get-FlattenedSettingsForProcessing -SettingsTemplate $defaultValue -CurrentValues $currentValue -ExcludeSettings $ExcludeSettings
                foreach ($nestedSetting in $nestedSettings)
                {
                    $nestedSetting.Path = "$key.$($nestedSetting.Path)"
                    $nestedSetting.IsNested = $true
                }
                $flattenedSettings += $nestedSettings
            }
            else
            {
                # Simple value
                $flattenedSettings += @{
                    Name         = $key
                    Path         = $key
                    DefaultValue = $defaultValue
                    CurrentValue = $currentValue
                    IsNested     = $false
                }
            }
        }
    }
    
    Write-Verbose "[$functionName] Flattened $($flattenedSettings.Count) settings for processing"
    return $flattenedSettings
}

function ConvertTo-HashtableOptimized()
{
    <#
    .SYNOPSIS
        Optimized conversion function for PSCustomObject to hashtable.
        
    .DESCRIPTION
        Simplified version of ConvertTo-HashtableFromPSObject that leverages the fact that
        PSD1 files primarily return hashtables. This function is only needed for edge cases
        where PSCustomObjects are encountered.
        
    .PARAMETER InputObject
        The object to convert (PSCustomObject, hashtable, or other).
        
    .PARAMETER Context
        Context description for logging purposes.
        
    .EXAMPLE
        $hashtable = ConvertTo-HashtableOptimized -InputObject $psObject -Context "settings conversion"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $InputObject,
        [string]$Context = "object"
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Converting $Context to hashtable"
    
    # If it's already a hashtable, return it as-is
    if ($InputObject -is [hashtable])
    {
        Write-Verbose "[$functionName] Input is already a hashtable, returning as-is"
        return $InputObject
    }
    
    # If it's a PSCustomObject, convert it
    if ($InputObject -is [PSCustomObject])
    {
        try
        {
            $hashtable = @{}
            foreach ($property in $InputObject.PSObject.Properties)
            {
                # Only include NoteProperty types to exclude system properties
                if ($property.MemberType -eq 'NoteProperty')
                {
                    $hashtable[$property.Name] = $property.Value
                    Write-Verbose "[$functionName] Converted property '$($property.Name)' to hashtable"
                }
            }
            Write-Verbose "[$functionName] Successfully converted $Context to hashtable with $($hashtable.Count) properties"
            return $hashtable
        }
        catch
        {
            Write-Warning "[$functionName] Failed to convert $Context to hashtable: $($_.Exception.Message)"
            throw
        }
    }
    
    # For other types, try to return as-is
    Write-Verbose "[$functionName] Input type $($InputObject.GetType().Name) returned as-is"
    return $InputObject
}

function Test-IsHashtableOrConvert()
{
    <#
    .SYNOPSIS
        Tests if an object is a hashtable and converts if necessary.
        
    .DESCRIPTION
        Optimized helper function that checks if an object is a hashtable and converts
        PSCustomObjects to hashtables if needed. This replaces the need for complex
        type checking logic throughout the codebase.
        
    .PARAMETER InputObject
        The object to test and potentially convert.
        
    .OUTPUTS
        System.Collections.Hashtable
        Returns a hashtable either from the original object or converted from PSCustomObject.
    #>
    [CmdletBinding()]
    param(
        $InputObject
    )
    
    if ($null -eq $InputObject)
    {
        return @{}
    }
    
    if ($InputObject -is [hashtable])
    {
        return $InputObject
    }
    
    # Convert PSCustomObject to hashtable
    return ConvertTo-HashtableOptimized -InputObject $InputObject -Context "type conversion"
}
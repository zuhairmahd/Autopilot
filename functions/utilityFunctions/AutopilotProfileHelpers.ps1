function Convert-AutopilotProfilesToStandardFormat()
{
    <#
    .SYNOPSIS
        Converts Autopilot profiles from various formats to standardized name and ID arrays.
    
    .DESCRIPTION
        Handles conversion of Autopilot profiles from different formats (string arrays, hashtable arrays)
        to standardized format with separate name and ID arrays for consistent processing.
        
    .PARAMETER Profiles
        The Autopilot profiles array to convert. Can be string array or hashtable array.
        
    .OUTPUTS
        Returns a tuple: (String[] ProfileNames, String[] ProfileIds)
        
    .EXAMPLE
        $names, $ids = Convert-AutopilotProfilesToStandardFormat -profiles $profileArray
        
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Handles both legacy string format and new hashtable format
        - Returns empty arrays if input is null or empty
    #>
    [CmdletBinding()]
    param(
        [array]$Profiles
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Converting Autopilot profiles to standard format"
    
    # Initialize return arrays
    $profileNames = @()
    $profileIds = @()
    
    if (-not $Profiles -or $Profiles.Count -eq 0)
    {
        Write-Verbose "[$functionName] Profiles array is null or empty"
        return $profileNames, $profileIds
    }
    
    # Detect format based on first element
    $firstElement = $Profiles[0]
    Write-Verbose "[$functionName] First element type: $($firstElement.GetType().Name)"
    
    if ($firstElement -is [string])
    {
        # String array format (legacy)
        Write-Verbose "[$functionName] Detected string array format (legacy)"
        $profileNames = @($Profiles)
        $profileIds = @()  # No IDs available in string format
    }
    elseif ($firstElement -is [hashtable] -or $firstElement -is [PSCustomObject])
    {
        # Hashtable/PSCustomObject format (new)
        Write-Verbose "[$functionName] Detected hashtable/PSCustomObject format (new)"
        
        foreach ($profile in $Profiles)
        {
            if ($profile -is [hashtable])
            {
                if ($profile.ContainsKey('name'))
                {
                    $profileNames += $profile['name']
                }
                if ($profile.ContainsKey('id') -and $profile['id'])
                {
                    $profileIds += $profile['id']
                }
            }
            elseif ($profile -is [PSCustomObject])
            {
                if ($profile.PSObject.Properties.Name -contains 'name')
                {
                    $profileNames += $profile.name
                }
                if ($profile.PSObject.Properties.Name -contains 'id' -and $profile.id)
                {
                    $profileIds += $profile.id
                }
            }
        }
    }
    else
    {
        Write-Warning "[$functionName] Unknown Autopilot profiles format: $($firstElement.GetType().Name)"
        # Fallback: try to convert to string
        $profileNames = @($Profiles | ForEach-Object { $_.ToString() })
        $profileIds = @()
    }
    
    Write-Verbose "[$functionName] Converted to $($profileNames.Count) profile names and $($profileIds.Count) profile IDs"
    return $profileNames, $profileIds
}

function Test-AutopilotProfileFormat()
{
    <#
    .SYNOPSIS
        Tests the format of an Autopilot profiles array.
    
    .DESCRIPTION
        Determines whether an Autopilot profiles array is in string format, hashtable format, or unknown format.
        
    .PARAMETER Profiles
        The Autopilot profiles array to test.
        
    .OUTPUTS
        Returns "Empty", "StringArray", "HashTableArray", or "Unknown"
        
    .EXAMPLE
        $format = Test-AutopilotProfileFormat -profiles $profileArray
        
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Used for format detection before conversion
    #>
    [CmdletBinding()]
    param(
        [array]$Profiles
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Testing Autopilot profile format"
    
    if (-not $Profiles -or $Profiles.Count -eq 0)
    {
        return "Empty"
    }
    
    # Check first element to determine format
    $firstElement = $Profiles[0]
    Write-Verbose "[$functionName] First element type: $($firstElement.GetType().Name)"
    
    if ($firstElement -is [string])
    {
        Write-Verbose "[$functionName] Detected StringArray format"
        return "StringArray"
    }
    elseif ($firstElement -is [hashtable] -or $firstElement -is [PSCustomObject])
    {
        # Check for required properties
        $hasNameProperty = (($firstElement.PSObject -and $firstElement.PSObject.Properties.Name -contains "name") -or $firstElement.ContainsKey("name"))
        $hasIdProperty = (($firstElement.PSObject -and $firstElement.PSObject.Properties.Name -contains "id") -or $firstElement.ContainsKey("id"))
        
        if ($hasNameProperty -and $hasIdProperty)
        {
            Write-Verbose "[$functionName] Both 'name' and 'id' properties found - HashTableArray format"
            return "HashTableArray"
        }
        elseif ($hasNameProperty)
        {
            Write-Verbose "[$functionName] Only 'name' property found - Partial HashTableArray format"
            return "HashTableArray"  # Still consider it hashtable format
        }
        else
        {
            Write-Verbose "[$functionName] Neither 'name' nor 'id' properties found"
            return "Unknown"
        }
    }
    else
    {
        Write-Verbose "[$functionName] Unknown format"
        return "Unknown"
    }
}

function New-HashTableAutopilotProfileFormat()
{
    <#
    .SYNOPSIS
        Creates new hashtable format Autopilot profile objects.
    
    .DESCRIPTION
        Creates hashtable objects with name and id properties for Autopilot profiles.
        Used when converting from string format or creating new profile objects.
        
    .PARAMETER ProfileNames
        Array of profile display names.
        
    .PARAMETER ProfileIds
        Array of profile IDs (optional, can be null/empty).
        
    .OUTPUTS
        Returns array of hashtable objects with name and id properties.
        
    .EXAMPLE
        $profiles = New-HashTableAutopilotProfileFormat -profileNames @("Profile1", "Profile2") -profileIds @("id1", "id2")
        
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Ensures consistent hashtable structure
        - Handles mismatched array lengths gracefully
    #>
    [CmdletBinding()]
    param(
        [string[]]$ProfileNames,
        [string[]]$ProfileIds = @()
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Creating hashtable format for $($ProfileNames.Count) profiles"
    
    $result = @()
    
    for ($i = 0; $i -lt $ProfileNames.Count; $i++)
    {
        $profileId = if ($i -lt $ProfileIds.Count) { $ProfileIds[$i] } else { $null }
        
        $profile = @{
            name = $ProfileNames[$i]
            id   = $profileId
        }
        
        $result += $profile
        Write-Verbose "[$functionName] Created profile: name='$($ProfileNames[$i])', id='$profileId'"
    }
    
    Write-Verbose "[$functionName] Created $($result.Count) hashtable profile objects"
    return $result
}
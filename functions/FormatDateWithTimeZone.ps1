# Function to get the three-letter time zone abbreviation
function GetTimeZoneAbbreviation()
{
    param (
        [Parameter(Mandatory = $true)]
        [DateTime]$DateTime
    )
    
    # Get the current time zone
    $timeZone = [System.TimeZoneInfo]::Local
    
    # Check if it's daylight saving time
    $isDaylightSavingTime = $timeZone.IsDaylightSavingTime($DateTime)
    
    # Get the display name
    $displayName = if ($isDaylightSavingTime)
    {
        $timeZone.DaylightName 
    }
    else
    {
        $timeZone.StandardName 
    }
    
    # Try to extract abbreviation from display name (usually in parentheses)
    if ($displayName -match '\(([A-Z]{3})\)')
    {
        return $matches[1]
    }
    
    # If no abbreviation in parentheses, create one from the time zone id
    $abbreviation = switch -Regex ($timeZone.Id)
    {
        'Eastern'
        {
            if ($isDaylightSavingTime)
            {
                'EDT' 
            }
            else
            {
                'EST' 
            } 
        }
        'Central'
        {
            if ($isDaylightSavingTime)
            {
                'CDT' 
            }
            else
            {
                'CST' 
            } 
        }
        'Mountain'
        {
            if ($isDaylightSavingTime)
            {
                'MDT' 
            }
            else
            {
                'MST' 
            } 
        }
        'Pacific'
        {
            if ($isDaylightSavingTime)
            {
                'PDT' 
            }
            else
            {
                'PST' 
            } 
        }
        'Alaska'
        {
            if ($isDaylightSavingTime)
            {
                'ADT' 
            }
            else
            {
                'AST' 
            } 
        }
        'Hawaii'
        {
            'HST' 
        }
        default
        { 
            # Create abbreviation from offset
            $offset = $timeZone.GetUtcOffset($DateTime)
            $prefix = if ($offset.TotalHours -ge 0)
            {
                '+' 
            }
            else
            {
                '-' 
            }
            "UTC$prefix$([Math]::Abs($offset.TotalHours))"
        }
    }
    
    return $abbreviation
}

# Function to format date with full day/month names and timezone abbreviation
function FormatDateWithTimeZone()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0, ValueFromPipelineByPropertyName = $true)][DateTime]$DateTime
    )
    #Print verbose log of parameters
    Write-Verbose "Received parameters: $($DateTime | Out-String)"
    #Verify the passed datetime is a valid date.
    Write-Verbose "Verifying DateTime: $($DateTime | Out-String)"
    if ($DateTime -eq $null -or $DateTime -eq [System.DateTime]::MinValue)
    {
        Write-Verbose "Invalid DateTime provided."
        return $null
    }
    Write-Verbose "DateTime is valid."
    Write-Verbose "Formatting DateTime: $($DateTime | Out-String)"
    $formattedDate = $DateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K" 
    Write-Verbose "Formatted DateTime: $($formattedDate | Out-String)"
    return $formattedDate
}
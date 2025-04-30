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
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        $DateTime
    )
    #Print verbose log of parameters
    Write-Verbose "Received parameters $DateTime"
    #Verify the passed datetime is a valid date.
    Write-Verbose "Verifying DateTime: $($DateTime | Out-String)"
    #If the datetime is passed as a string, convert it to a datetime object.
    if ($DateTime -is [string])
    {
        Write-Verbose "Converting string to DateTime."
        $DateTime = [System.DateTime]::Parse($DateTime)
    }
    if ($null -eq $DateTime -or $DateTime -eq [System.DateTime]::MinValue)
    {
        Write-Verbose "Invalid DateTime provided."
        return $null
    }
    Write-Verbose "DateTime is valid."
    
    # Convert from UTC to local time if the datetime is in UTC
    if ($DateTime.Kind -eq [System.DateTimeKind]::Utc)
    {
        Write-Verbose "Converting UTC DateTime to local time."
        $DateTime = $DateTime.ToLocalTime()
    }
    
    Write-Verbose "Formatting DateTime: $($DateTime | Out-String)"
    # Get the timezone abbreviation
    $tzAbbreviation = GetTimeZoneAbbreviation -DateTime $DateTime
    Write-Verbose "Time zone abbreviation: $tzAbbreviation"
    
    # Format the date without timezone, then append our custom abbreviation
    $formattedDate = $DateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt"
    $formattedWithTz = "$formattedDate $tzAbbreviation"
    
    Write-Verbose "Formatted DateTime: $formattedWithTz"
    return $formattedWithTz
}
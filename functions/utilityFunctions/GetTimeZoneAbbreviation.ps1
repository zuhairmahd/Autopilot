function GetTimeZoneAbbreviation()
{
    param (
        [Parameter(Mandatory = $true)]
        [DateTime]$DateTime
    )
    $functionName = $MyInvocation.MyCommand.Name    
    # Get the current time zone
    Write-Verbose "[$functionName] Getting current time zone."
    $timeZone = [System.TimeZoneInfo]::Local
    Write-Verbose "[$functionName] Current time zone: $($timeZone.DisplayName)"
    
    # Check if it's daylight saving time
    Write-Verbose "[$functionName] Checking if it's daylight saving time."
    $isDaylightSavingTime = $timeZone.IsDaylightSavingTime($DateTime)
    Write-Verbose "[$functionName] Is daylight saving time: $isDaylightSavingTime"
    
    # Get the display name
    Write-Verbose "[$functionName] Getting display name."
    $displayName = if ($isDaylightSavingTime)
    {
        Write-Verbose "[$functionName] Getting daylight name."
        $timeZone.DaylightName 
        Write-Verbose "[$functionName] Daylight name: $($timeZone.DaylightName)"
    }
    else
    {
        Write-Verbose "[$functionName] Getting standard name."
        $timeZone.StandardName 
        Write-Verbose "[$functionName] Standard name: $($timeZone.StandardName)"
    }
    
    # Try to extract abbreviation from display name (usually in parentheses)
    Write-Verbose "[$functionName] Extracting abbreviation from display name."
    if ($displayName -match '\(([A-Z]{3})\)')
    {
        Write-Verbose "[$functionName] Found abbreviation in display name."
        return $matches[1]
    }
    
    # If no abbreviation in parentheses, create one from the time zone id
    Write-Verbose "[$functionName] No abbreviation found in display name. Creating one from time zone ID."
    $abbreviation = switch -Regex ($timeZone.Id)
    {
        'Eastern'
        {
            Write-Verbose "[$functionName] Time zone ID is Eastern."
            if ($isDaylightSavingTime)
            {
                Write-Verbose "[$functionName] Daylight saving time is true."
                'EDT' 
                Write-Verbose "[$functionName] Daylight saving time abbreviation: EDT"
            }
            else
            {
                Write-Verbose "[$functionName] Daylight saving time is false."
                'EST' 
                Write-Verbose "[$functionName] Standard time abbreviation: EST"
            } 
        }
        'Central'
        {
            Write-Verbose "[$functionName] Time zone ID is Central."
            if ($isDaylightSavingTime)
            {
                Write-Verbose "[$functionName] Daylight saving time is true."
                'CDT' 
                Write-Verbose "[$functionName] Daylight saving time abbreviation: CDT"
            }
            else
            {
                Write-Verbose "[$functionName] Daylight saving time is false."
                'CST' 
                Write-Verbose "[$functionName] Standard time abbreviation: CST"
            } 
        }
        'Mountain'
        {
            Write-Verbose "[$functionName] Time zone ID is Mountain."
            if ($isDaylightSavingTime)
            {
                Write-Verbose "[$functionName] Daylight saving time is true."
                'MDT' 
                Write-Verbose "[$functionName] Daylight saving time abbreviation: MDT"
            }
            else
            {
                Write-Verbose "[$functionName] Daylight saving time is false."
                'MST' 
                Write-Verbose "[$functionName] Standard time abbreviation: MST"
            } 
        }
        'Pacific'
        {
            Write-Verbose "[$functionName] Time zone ID is Pacific."
            if ($isDaylightSavingTime)
            {
                Write-Verbose "[$functionName] Daylight saving time is true."
                'PDT' 
                Write-Verbose "[$functionName] Daylight saving time abbreviation: PDT"
            }
            else
            {
                Write-Verbose "[$functionName] Daylight saving time is false."
                'PST' 
                Write-Verbose "[$functionName] Standard time abbreviation: PST"
            } 
        }
        'Alaska'
        {
            Write-Verbose "[$functionName] Time zone ID is Alaska."
            if ($isDaylightSavingTime)
            {
                Write-Verbose "[$functionName] Daylight saving time is true."
                'ADT' 
                Write-Verbose "[$functionName] Daylight saving time abbreviation: ADT"
            }
            else
            {
                Write-Verbose "[$functionName] Daylight saving time is false."
                'AST' 
                Write-Verbose "[$functionName] Standard time abbreviation: AST"
            } 
        }
        'Hawaii'
        {
            Write-Verbose "[$functionName] Time zone ID is Hawaii."
            'HST' 
            Write-Verbose "[$functionName] Standard time abbreviation: HST"
        }
        default
        { 
            Write-Verbose "[$functionName] Time zone ID is not recognized. Creating abbreviation from offset."
            # Create abbreviation from offset
            $offset = $timeZone.GetUtcOffset($DateTime)
            Write-Verbose "[$functionName] Offset: $offset"
            Write-Verbose "[$functionName] Total hours: $($offset.TotalHours)"
            $prefix = if ($offset.TotalHours -ge 0)
            {
                Write-Verbose "[$functionName] Offset is positive."
                '+' 
            }
            else
            {
                Write-Verbose "[$functionName] Offset is negative."
                '-' 
            }
            Write-Verbose "[$functionName] Prefix: $prefix"
            "UTC$prefix$([Math]::Abs($offset.TotalHours))"
            Write-Verbose "[$functionName] Abbreviation: UTC$prefix$([Math]::Abs($offset.TotalHours))"
        }
    }
    Write-Verbose "[$functionName] Final abbreviation: $abbreviation"
    return $abbreviation
}


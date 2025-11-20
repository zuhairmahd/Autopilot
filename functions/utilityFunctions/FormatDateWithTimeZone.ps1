function FormatDateWithTimeZone()
{
    <#
    .SYNOPSIS
    Formats a DateTime object with timezone abbreviation for display.

    .DESCRIPTION
    This function converts a DateTime value to a formatted string that includes the timezone
    abbreviation. It handles UTC to local time conversion, validates input, and produces a
    human-readable date format. The function accepts DateTime objects or strings that can be
    parsed to DateTime.

    .PARAMETER DateTime
    The DateTime value to format. Can be a DateTime object or a parseable string.
    Accepts pipeline input.

    .OUTPUTS
    System.String
    Returns a formatted date string with timezone abbreviation (e.g., "Monday, January 1, 2024 3:45:00 PM PST"),
    or $null if the DateTime is invalid.

    .EXAMPLE
    $formattedDate = FormatDateWithTimeZone -DateTime (Get-Date)
    Get-Date | FormatDateWithTimeZone

    .NOTES
    Automatically converts UTC times to local time.
    Format: "dddd, MMMM d, yyyy h:mm:ss tt [TZ]"
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        $DateTime
    )
    $functionName = $MyInvocation.MyCommand.Name    
    #Print verbose log of parameters
    Write-Verbose "[$functionName] Received parameters $DateTime"
    #Verify the passed datetime is a valid date.
    Write-Verbose "[$functionName] Verifying DateTime: $($DateTime | Out-String)"
    #If the datetime is passed as a string, convert it to a datetime object.
    if ($DateTime -is [string])
    {
        Write-Verbose "[$functionName] Converting string to DateTime."
        $DateTime = [System.DateTime]::Parse($DateTime)
    }
    if ($null -eq $DateTime -or $DateTime -eq [System.DateTime]::MinValue)
    {
        Write-Verbose "[$functionName] Invalid DateTime provided."
        return $null
    }
    Write-Verbose "[$functionName] DateTime is valid."
    
    # Convert from UTC to local time if the datetime is in UTC
    if ($DateTime.Kind -eq [System.DateTimeKind]::Utc)
    {
        Write-Verbose "[$functionName] Converting UTC DateTime to local time."
        $DateTime = $DateTime.ToLocalTime()
    }
    
    Write-Verbose "[$functionName] Formatting DateTime: $($DateTime | Out-String)"
    # Get the timezone abbreviation
    $tzAbbreviation = GetTimeZoneAbbreviation -DateTime $DateTime
    Write-Verbose "[$functionName] Time zone abbreviation: $tzAbbreviation"
    
    # Format the date without timezone, then append our custom abbreviation
    $formattedDate = $DateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt"
    $formattedWithTz = "$formattedDate $tzAbbreviation"
    
    Write-Verbose "[$functionName] Formatted DateTime: $formattedWithTz"
    return $formattedWithTz
}


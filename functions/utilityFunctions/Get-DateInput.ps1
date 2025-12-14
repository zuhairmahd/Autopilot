function Get-DateInput()
{
    <#
    .SYNOPSIS
        Prompts user for and validates a last contact date for device filtering.

    .DESCRIPTION
        Displays prompts to the user requesting an optional date input for filtering devices
        by their last contact time with Intune. Validates the date format and returns a
        DateTime object or $null if no date is provided.

    .PARAMETER logFile
        Path to the log file for recording the date filtering selection.

    .PARAMETER module
        Module name to use in log entries (typically the calling script name).

    .OUTPUTS
        [System.DateTime] or $null
        Returns the parsed DateTime object if a valid date was entered, or $null if left blank.

    .EXAMPLE
        $lastContactDateTime = Get-LastContactDateInput -logFile $logFile -module $scriptName
        if ($lastContactDateTime) {
            Write-Host "Filtering by date: $lastContactDateTime"
        }

    .NOTES
        Compatible with PowerShell 5.1 and later.
    #>
    [CmdletBinding()]
    param(
        [string]$message = "Enter a date to restrict the report to devices that last contacted Intune on or before that date."
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting function execution.                 "
    Write-Host $message
    Write-Host "Leave blank to include all assigned devices."

    $lastContactDateTime = $null
    $parsedDate = $null
    $lastContactDateTimeInput = Read-Host "Enter date (YYYY-MM-DD) or leave blank"
    Write-Verbose "[$functionName] User input received: '$lastContactDateTimeInput'"
    write-log -logFile $logFile -module $functionName -message "User input for last contact date: '$lastContactDateTimeInput'" -LogLevel "Verbose"
    while (-not [string]::IsNullOrWhiteSpace($lastContactDateTimeInput) -and -not [datetime]::TryParse($lastContactDateTimeInput, [ref]$parsedDate))
    {
        Write-Host "Invalid date format. Please enter a valid date in YYYY-MM-DD format or leave blank." -ForegroundColor Red
        write-log -logFile $logFile -module $functionName -message "Invalid date format entered: '$lastContactDateTimeInput'" -LogLevel "Warning"
        [console]::beep()
        $lastContactDateTimeInput = Read-Host "Enter date (YYYY-MM-DD) or leave blank"
    }

    if (-not [string]::IsNullOrWhiteSpace($lastContactDateTimeInput))
    {
        $lastContactDateTime = $parsedDate
        write-log -logFile $logFile -module $functionName -message "Valid last contact date entered: '$lastContactDateTimeInput'" -LogLevel "Information"
    }

    return $lastContactDateTime
}

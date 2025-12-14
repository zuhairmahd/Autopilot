function Get-DateInput()
{
    <#
    .SYNOPSIS
        Prompts user for and validates date input with support for relative and absolute date formats.

    .DESCRIPTION
        Interactively prompts the user for date input and validates the format.
        Continuously loops until a valid date is entered or the user presses Enter
        to skip. Supports multiple input formats including absolute dates and relative
        date offsets.

        Supported input formats:
        - Absolute dates: YYYY-MM-DD, MM/DD/YYYY, or other standard date formats
        - Relative days: Integer (e.g., 30) or number+d (e.g., 30d) = X days ago
        - Relative months: number+m (e.g., 3m) = X months ago
        - Relative years: number+y (e.g., 1y) = X years ago

        The function performs the following:
        - Displays customizable prompt message
        - Accepts date input in multiple formats
        - Calculates relative dates from today when using offset syntax
        - Validates date format using regex patterns
        - Provides error feedback for invalid input
        - Logs all user interactions for audit purposes
        - Returns DateTime object or $null for blank input

    .PARAMETER message
        Custom message to display to the user before prompting for date input.
        Default: "Enter a date to restrict the report to devices that last contacted Intune on or before that date."

    .OUTPUTS
        [System.DateTime] or $null
        Returns the parsed DateTime object if a valid date was entered.
        Returns $null if the user pressed Enter without entering a value.

    .EXAMPLE
        $lastContactDate = Get-DateInput
        if ($lastContactDate) {
            Write-Host "Filtering by date: $($lastContactDate.ToString('yyyy-MM-dd'))"
        } else {
            Write-Host "No date filter applied"
        }

    .EXAMPLE
        # Using relative date - 30 days ago
        $filterDate = Get-DateInput
        # User enters: 30d
        # Result: DateTime object for 30 days prior to today

    .EXAMPLE
        # Using relative date - 3 months ago
        $filterDate = Get-DateInput -message "Enter cutoff date for aging devices report"
        # User enters: 3m
        # Result: DateTime object for 3 months prior to today

    .EXAMPLE
        # Using absolute date
        $filterDate = Get-DateInput
        # User enters: 2025-01-01
        # Result: DateTime object for January 1, 2025

    .NOTES
        Compatible with PowerShell 5.1 and later.
        Uses regex validation for reliable pattern matching without exceptions.
        Supports relative date calculations (days, months, years).
        Loops until valid date is entered or user presses Enter (blank input).
        Logs all attempts and results using write-log function.
    #>
    [CmdletBinding()]
    param(
        [string]$message = "Enter a date to restrict the report to devices that last contacted Intune on or before that date."
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting function execution"
    write-log -logFile $logFile -module $functionName -message "Function execution started" -LogLevel "Debug"

    # Display instructions to user
    Write-Host $message
    Write-Host "Leave blank to include all assigned devices."
    Write-Host "Supported formats: YYYY-MM-DD, 30d (days ago), 3m (months ago), 1y (years ago)"
    write-log -logFile $logFile -module $functionName -message "Displayed date input prompt to user with format examples" -LogLevel "Debug"

    # Initialize variables
    $lastContactDateTime = $null
    $parsedDate = $null
    $attemptCount = 0

    # Get initial input
    $lastContactDateTimeInput = Read-Host "Enter date (YYYY-MM-DD, 30d, 3m, 1y) or leave blank"
    $attemptCount++
    Write-Verbose "[$functionName] User input received (attempt $attemptCount): '$lastContactDateTimeInput'"
    write-log -logFile $logFile -module $functionName -message "User input received (attempt $attemptCount): '$lastContactDateTimeInput'" -LogLevel "Information"

    # Check if user pressed Enter without input - exit immediately
    if ([string]::IsNullOrWhiteSpace($lastContactDateTimeInput))
    {
        Write-Verbose "[$functionName] User provided blank input, skipping date filter"
        write-log -logFile $logFile -module $functionName -message "User provided blank input on first attempt, returning null (no date filter)" -LogLevel "Information"
        return $null
    }

    # Validate date input - loop until valid or blank
    while (-not [string]::IsNullOrWhiteSpace($lastContactDateTimeInput))
    {
        Write-Verbose "[$functionName] Attempting to parse date input: '$lastContactDateTimeInput'"
        write-log -logFile $logFile -module $functionName -message "Attempting to parse date: '$lastContactDateTimeInput'" -LogLevel "Debug"

        $success = $false
        $parsedDate = $null

        # Try to parse relative date format: number + optional letter (d/m/y)
        # Matches: 30, 30d, 3m, 1y
        if ($lastContactDateTimeInput -match '^\s*(\d+)\s*([dmy])?\s*$')
        {
            $number = [int]$matches[1]
            $unit = if ($matches[2])
            {
                $matches[2].ToLower() 
            }
            else
            {
                'd' 
            }  # Default to days

            Write-Verbose "[$functionName] Detected relative date format: $number $unit"
            write-log -logFile $logFile -module $functionName -message "Detected relative date format: $number unit(s) of type '$unit'" -LogLevel "Debug"

            try
            {
                $today = Get-Date
                switch ($unit)
                {
                    'd'
                    {
                        $parsedDate = $today.AddDays(-$number)
                        Write-Verbose "[$functionName] Calculated date: $number days ago = $($parsedDate.ToString('yyyy-MM-dd'))"
                        write-log -logFile $logFile -module $functionName -message "Calculated date: $number days ago = $($parsedDate.ToString('yyyy-MM-dd HH:mm:ss'))" -LogLevel "Information"
                    }
                    'm'
                    {
                        $parsedDate = $today.AddMonths(-$number)
                        Write-Verbose "[$functionName] Calculated date: $number months ago = $($parsedDate.ToString('yyyy-MM-dd'))"
                        write-log -logFile $logFile -module $functionName -message "Calculated date: $number months ago = $($parsedDate.ToString('yyyy-MM-dd HH:mm:ss'))" -LogLevel "Information"
                    }
                    'y'
                    {
                        $parsedDate = $today.AddYears(-$number)
                        Write-Verbose "[$functionName] Calculated date: $number years ago = $($parsedDate.ToString('yyyy-MM-dd'))"
                        write-log -logFile $logFile -module $functionName -message "Calculated date: $number years ago = $($parsedDate.ToString('yyyy-MM-dd HH:mm:ss'))" -LogLevel "Information"
                    }
                }
                $success = $true
            }
            catch
            {
                Write-Verbose "[$functionName] Error calculating relative date: $_"
                write-log -logFile $logFile -module $functionName -message "Error calculating relative date: $_" -LogLevel "Error"
                $success = $false
            }
        }
        # Try to parse absolute date format using regex patterns
        # Supports: YYYY-MM-DD, YYYY/MM/DD, MM-DD-YYYY, MM/DD/YYYY
        elseif ($lastContactDateTimeInput -match '^\s*(\d{4})[-/](\d{1,2})[-/](\d{1,2})\s*$')
        {
            # Format: YYYY-MM-DD or YYYY/MM/DD
            $year = [int]$matches[1]
            $month = [int]$matches[2]
            $day = [int]$matches[3]

            Write-Verbose "[$functionName] Detected absolute date format (YYYY-MM-DD): Year=$year, Month=$month, Day=$day"
            write-log -logFile $logFile -module $functionName -message "Detected absolute date format (YYYY-MM-DD): Year=$year, Month=$month, Day=$day" -LogLevel "Debug"

            # Validate date components
            if ($year -ge 1900 -and $year -le 9999 -and $month -ge 1 -and $month -le 12 -and $day -ge 1 -and $day -le 31)
            {
                try
                {
                    $parsedDate = Get-Date -Year $year -Month $month -Day $day -Hour 0 -Minute 0 -Second 0
                    $success = $true
                    Write-Verbose "[$functionName] Successfully parsed absolute date: $($parsedDate.ToString('yyyy-MM-dd'))"
                    write-log -logFile $logFile -module $functionName -message "Successfully parsed absolute date: $($parsedDate.ToString('yyyy-MM-dd HH:mm:ss'))" -LogLevel "Information"
                }
                catch
                {
                    Write-Verbose "[$functionName] Invalid date components: $_"
                    write-log -logFile $logFile -module $functionName -message "Invalid date components (out of range): $_" -LogLevel "Warning"
                    $success = $false
                }
            }
            else
            {
                Write-Verbose "[$functionName] Date components out of valid range"
                write-log -logFile $logFile -module $functionName -message "Date components out of valid range: Year=$year, Month=$month, Day=$day" -LogLevel "Warning"
                $success = $false
            }
        }
        elseif ($lastContactDateTimeInput -match '^\s*(\d{1,2})[-/](\d{1,2})[-/](\d{4})\s*$')
        {
            # Format: MM-DD-YYYY or MM/DD/YYYY
            $month = [int]$matches[1]
            $day = [int]$matches[2]
            $year = [int]$matches[3]

            Write-Verbose "[$functionName] Detected absolute date format (MM-DD-YYYY): Month=$month, Day=$day, Year=$year"
            write-log -logFile $logFile -module $functionName -message "Detected absolute date format (MM-DD-YYYY): Month=$month, Day=$day, Year=$year" -LogLevel "Debug"

            # Validate date components
            if ($year -ge 1900 -and $year -le 9999 -and $month -ge 1 -and $month -le 12 -and $day -ge 1 -and $day -le 31)
            {
                try
                {
                    $parsedDate = Get-Date -Year $year -Month $month -Day $day -Hour 0 -Minute 0 -Second 0
                    $success = $true
                    Write-Verbose "[$functionName] Successfully parsed absolute date: $($parsedDate.ToString('yyyy-MM-dd'))"
                    write-log -logFile $logFile -module $functionName -message "Successfully parsed absolute date: $($parsedDate.ToString('yyyy-MM-dd HH:mm:ss'))" -LogLevel "Information"
                }
                catch
                {
                    Write-Verbose "[$functionName] Invalid date components: $_"
                    write-log -logFile $logFile -module $functionName -message "Invalid date components (out of range): $_" -LogLevel "Warning"
                    $success = $false
                }
            }
            else
            {
                Write-Verbose "[$functionName] Date components out of valid range"
                write-log -logFile $logFile -module $functionName -message "Date components out of valid range: Month=$month, Day=$day, Year=$year" -LogLevel "Warning"
                $success = $false
            }
        }
        else
        {
            Write-Verbose "[$functionName] Input does not match any supported format"
            write-log -logFile $logFile -module $functionName -message "Input does not match any supported format: '$lastContactDateTimeInput'" -LogLevel "Warning"
            $success = $false
        }

        if ($success -and $parsedDate)
        {
            Write-Verbose "[$functionName] Date validation successful"
            write-log -logFile $logFile -module $functionName -message "Date validation successful for input: '$lastContactDateTimeInput'" -LogLevel "Information"
            break
        }

        # Invalid date format - provide feedback and retry
        Write-Host "Invalid date format. Examples: 2025-01-15, 30d (30 days ago), 3m (3 months ago), 1y (1 year ago)" -ForegroundColor Red
        write-log -logFile $logFile -module $functionName -message "Invalid date format entered: '$lastContactDateTimeInput' (attempt $attemptCount)" -LogLevel "Warning"
        [console]::beep()

        # Prompt for retry
        $lastContactDateTimeInput = Read-Host "Enter date (YYYY-MM-DD, 30d, 3m, 1y) or leave blank"
        $attemptCount++
        Write-Verbose "[$functionName] Retry input received (attempt $attemptCount): '$lastContactDateTimeInput'"
        write-log -logFile $logFile -module $functionName -message "Retry input received (attempt $attemptCount): '$lastContactDateTimeInput'" -LogLevel "Information"

        # Check if user pressed Enter to exit loop
        if ([string]::IsNullOrWhiteSpace($lastContactDateTimeInput))
        {
            Write-Verbose "[$functionName] User provided blank input on retry, exiting validation loop"
            write-log -logFile $logFile -module $functionName -message "User provided blank input on retry (attempt $attemptCount), exiting loop without date filter" -LogLevel "Information"
            break
        }
    }

    # Set return value if valid date was parsed
    if (-not [string]::IsNullOrWhiteSpace($lastContactDateTimeInput) -and $parsedDate)
    {
        $lastContactDateTime = $parsedDate
        Write-Verbose "[$functionName] Returning valid date: $($lastContactDateTime.ToString('yyyy-MM-dd'))"
        write-log -logFile $logFile -module $functionName -message "Valid date accepted: $($lastContactDateTime.ToString('yyyy-MM-dd HH:mm:ss')) (after $attemptCount attempt(s))" -LogLevel "Information"
    }
    else
    {
        Write-Verbose "[$functionName] No valid date provided, returning null"
        write-log -logFile $logFile -module $functionName -message "No valid date provided, returning null (total attempts: $attemptCount)" -LogLevel "Information"
    }

    write-log -logFile $logFile -module $functionName -message "Function execution completed" -LogLevel "Debug"
    return $lastContactDateTime
}

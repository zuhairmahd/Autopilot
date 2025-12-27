function HandleCustomImportSettings()
{
    <#
    .SYNOPSIS
    Handles user customization of Autopilot import wait settings interactively.

    .DESCRIPTION
    This function prompts the user to customize how long to wait for profile assignment after
    device import. It modifies wait time and retry count parameters by reference, validates
    user input, and allows skipping the wait entirely. Used during interactive import workflows.

    .PARAMETER functionName
    The calling function name for logging. This parameter is mandatory.

    .PARAMETER maxWaitTimeRef
    Reference to maximum wait time variable (modified by this function). This parameter is mandatory.

    .PARAMETER timeInSecondsRef
    Reference to time between checks variable (modified by this function). This parameter is mandatory.

    .PARAMETER returnValues
    Return values object containing deviceImportSuccessMessage. This parameter is mandatory.

    .OUTPUTS
    System.String
    Returns deviceImportSuccessMessage if user chooses to skip wait, otherwise returns $null to continue.

    .EXAMPLE
    $result = HandleCustomImportSettings -functionName $fn -maxWaitTimeRef ([ref]$maxWait) -timeInSecondsRef ([ref]$interval) -returnValues $rv

    .NOTES
    Modifies parameters by reference to update calling function's variables.
    Validates user input (0-60 range for retry count).
    Allows immediate return (skip wait) by entering 0.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$functionName,
        [Parameter(Mandatory = $true)]
        [ref]$maxWaitTimeRef,
        [Parameter(Mandatory = $true)]
        [ref]$timeInSecondsRef,
        [Parameter(Mandatory = $true)]
        $returnValues
    )

    Write-Verbose "[$functionName] Handling custom import settings"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Entering HandleCustomImportSettings (current maxWait=$($maxWaitTimeRef.Value) timeInSeconds=$($timeInSecondsRef.Value))" -LogLevel "Information"
    $maxWaitTime = $maxWaitTimeRef.Value
    $timeInSeconds = $timeInSecondsRef.Value

    Write-Host "Enter how many times you would like to check for a profile assignment."
    Write-Host "Press enter to keep the default value of $maxWaitTime."
    Write-Host "Press 0 to skip the wait."
    $customMaxWaitTime = Read-Host 'Enter the number of retries or press enter to skip'

    if ($customMaxWaitTime -eq '0')
    {
        Write-Host "Skipping the wait for profile assignment."
        Write-Log -LogFile $LogFile -Module $functionName -Message "User chose to skip profile assignment wait (maxWait=0)" -LogLevel "Information"
        return $returnValues.deviceImportSuccessMessage
    }
    elseif ($customMaxWaitTime -as [int] -and [int]$customMaxWaitTime -ge 0 -and [int]$customMaxWaitTime -le 60)
    {
        $maxWaitTimeRef.Value = [int]$customMaxWaitTime
        Write-Host "Will check $($maxWaitTimeRef.Value) times for proper profile assignment."
        Write-Log -LogFile $LogFile -Module $functionName -Message "Updated maxWaitTime to $($maxWaitTimeRef.Value)" -LogLevel "Verbose"
    }
    else
    {
        do
        {
            Write-Host "Invalid input. Please enter a number between 0 and 60." -ForegroundColor Yellow
            $customMaxWaitTime = Read-Host 'Enter the number of retries or press enter to skip'
        } while (($customMaxWaitTime -as [int]) -and ([int]$customMaxWaitTime -lt 0 -or [int]$customMaxWaitTime -gt 60))
    }

    Write-Host "Enter how many seconds to wait between each check."
    Write-Host "Press enter to keep the default value of $timeInSeconds."
    Write-Host "Press 0 to skip the wait."
    $customTimeInSeconds = Read-Host 'Enter the number of seconds or press enter to skip'

    if ($customTimeInSeconds -eq '0')
    {
        Write-Host "Skipping the wait for profile assignment."
        Write-Log -LogFile $LogFile -Module $functionName -Message "User chose to skip wait between checks (timeInSeconds=0)" -LogLevel "Information"
        return $returnValues.deviceImportSuccessMessage
    }
    elseif ($customTimeInSeconds -as [int] -and [int]$customTimeInSeconds -ge 0 -and [int]$customTimeInSeconds -le 60)
    {
        $timeInSecondsRef.Value = [int]$customTimeInSeconds
        Write-Host "Will check every $($timeInSecondsRef.Value) seconds for proper profile assignment."
        Write-Log -LogFile $LogFile -Module $functionName -Message "Updated timeInSeconds to $($timeInSecondsRef.Value)" -LogLevel "Verbose"
    }
    else
    {
        do
        {
            Write-Host "Invalid input. Please enter a number between 0 and 60." -ForegroundColor Yellow
            $customTimeInSeconds = Read-Host 'Enter the number of seconds or press enter to skip'
        } while (($customTimeInSeconds -as [int]) -and ([int]$customTimeInSeconds -lt 0 -or [int]$customTimeInSeconds -gt 60))
    }

    Write-Host "The device will be checked $($maxWaitTimeRef.Value) times with a wait of $($timeInSecondsRef.Value) seconds between each check."
    Write-Log -LogFile $LogFile -Module $functionName -Message "Final settings: maxWait=$($maxWaitTimeRef.Value) waitSeconds=$($timeInSecondsRef.Value)" -LogLevel "Information"
    return $null
}


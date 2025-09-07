function HandleCustomImportSettings()
{
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


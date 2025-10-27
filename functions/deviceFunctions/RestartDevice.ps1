function RestartDevice()
{
    [CmdletBinding()]
    param (
        [ValidateSet('restart', 'shutdown')]
        $action = 'restart',
        [string]$question,
        [string]$bootMessage = 'Rebooting the device...',
        [string]$reminderMessage = 'Remember to reboot the device to start the device enrollment.'
    )
    if (-not $question)
    {
        if ($action -eq 'shutdown')
        {
            $question = 'Do you want to shutdown the device now? (Y/N)'
        }
        else
        {
            $question = 'Do you want to reboot the device now? (Y/N)'
        }
    }
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Action: $action"
    Write-Verbose "[$functionName] Question: $question"
    Write-Verbose "[$functionName] Boot message: $bootMessage"
    write-log -logFile $logFile -module $functionName -message "Action: $action" -LogLevel "Information"
    write-log -logFile $logFile -module $functionName -message "Question: $question" -LogLevel "Information"                    
    write-log -logFile $logFile -module $functionName -message "Boot message: $bootMessage" -LogLevel "Information"
    $reboot = Read-Host -Prompt $question
    Write-Verbose "[$functionName] User input: $reboot"
    write-log -logFile $logFile -module $functionName -message "User input: $reboot" -LogLevel "Information"
    while ($reboot -notin ('Y', 'N'))
    {
        $reboot = Read-Host -Prompt $question
        Write-Verbose "[$functionName] User input: $reboot"
        write-log -logFile $logFile -module $functionName -message "User input: $reboot" -LogLevel "Information"
        Write-Host "Invalid input. Please enter 'Y' for Yes or 'N' for No." -ForegroundColor Red
        [console]::beep(1000, 500)
    }
    if ($reboot -eq 'Y')
    {
        Write-Host $bootMessage -ForegroundColor Green
        write-log -logFile $logFile -module $functionName -message $bootMessage -LogLevel "Information"
        if ($action -eq 'shutdown')
        {
            Write-Verbose "[$functionName] User chose to shutdown the device."
            write-log -logFile $logFile -module $functionName -message "User chose to shutdown the device." -LogLevel "Information"                 
            Stop-Computer -Force
        }
        else
        {
            Write-Verbose "[$functionName] User chose to reboot the device."
            write-log -logFile $logFile -module $functionName -message "User chose to reboot the device." -LogLevel "Information"
            Restart-Computer -Force
        }
    }
    else
    {
        Write-Verbose "[$functionName] User chose not to $action the device."
        write-log -logFile $logFile -module $functionName -message "User chose not to reboot the device." -LogLevel "Information"
        Write-Host $reminderMessage -ForegroundColor Yellow
        write-log -logFile $logFile -module $functionName -message $reminderMessage -LogLevel "Information"
        return $false
    }
}


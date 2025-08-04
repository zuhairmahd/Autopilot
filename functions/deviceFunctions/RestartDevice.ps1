function RestartDevice()
{
    [CmdletBinding()]
    param (
        [string]$question = 'Do you want to reboot the device now? (Y/N)',
        [string]$bootMessage = 'Rebooting the device...',
        [string]$reminderMessage = 'Remember to reboot the device to start the device enrollment.'
    )
    $functionName = $MyInvocation.MyCommand.Name
    $reboot = Read-Host -Prompt $question
    while ($reboot -notin ('Y', 'N'))
    {
        $reboot = Read-Host -Prompt $question
        Write-Verbose "[$functionName] User input: $reboot"
        if ($reboot -notin ('Y', 'N'))
        {
            Write-Host "Invalid input. Please enter 'Y' for Yes or 'N' for No." -ForegroundColor Red
            [console]::beep(1000, 500)
        }
    }
    if ($reboot -eq 'Y')
    {
        Write-Verbose "[$functionName] User chose to reboot the device."
        Write-Host $bootMessage -ForegroundColor Green
        Restart-Computer -Force
    }
    else
    {
        Write-Verbose "[$functionName] User chose not to reboot the device."
        Write-Host $reminderMessage -ForegroundColor Red
        return $false
    }
}


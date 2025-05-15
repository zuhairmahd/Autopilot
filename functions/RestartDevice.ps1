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
        Write-Host "Invalid input. Please enter 'Y' or 'N'."
        [console]::beep(1000, 500)
        $reboot = Read-Host -Prompt $question
    }
    if ($reboot -eq 'Y')
    {
        Write-Host $bootMessage -ForegroundColor Green
        Restart-Computer -Force
    }
    else
    {
        Write-Host $reminderMessage -ForegroundColor Red
        return $false
    }
}

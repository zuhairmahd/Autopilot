function Restart-Device()
{
    [CmdletBinding()]
    param (
        [string]$question = 'Do you want to reboot the device now? (Y/N)',
        [string]$bootMessage = 'Rebooting the device...',
        [string]$reminderMessage = 'Remember to reboot the device to start the device enrollment.'
    )
    $reboot = Read-Host -Prompt $question
    if ($reboot -eq 'Y')
    {
        Write-Host $bootMessage -ForegroundColor Green
        Restart-Computer -Force
    }
    else
    {
        Write-Host $reminderMessage -ForegroundColor Red
    }
}


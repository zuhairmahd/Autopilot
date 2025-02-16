function Get-USBDriveLetter()
{
    [CmdletBinding()]
    param
    (
        [string]$Label = 'WINPE'
    )
    # Get the volume(s) with a matching FileSystemLabel.
    $volumes = Get-Volume | Where-Object { $_.FileSystemLabel -eq $Label } -ErrorAction SilentlyContinue
    # Write-Verbose $volumes
    Write-Verbose "Found $($volumes.Count) volume(s) with the label '$Label'."
    if ($volumes)
    {
        foreach ($vol in $volumes)
        {
            Write-Verbose "Volume $vol has label '$($vol.FileSystemLabel)' and drive letter '$($vol.DriveLetter)'."
            $driveLetter = $vol.DriveLetter
            Write-Host "The windows installation is at $($driveLetter):\" -ForegroundColor Green
        }
    }
    else
    {
        Write-Host 'Cannot find the Windows installation drive' -ForegroundColor Red
        Write-Verbose "Cannot find a volume with the label '$Label'."
        $driveLetter = $null
    }
    return "$($driveLetter):"
}

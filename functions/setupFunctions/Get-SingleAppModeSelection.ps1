function Get-SingleAppModeSelection()
{
    <#
    .SYNOPSIS
        Handles single app mode selection with simplified interface.
    #>
    [CmdletBinding()]
    param(
        [array]$AvailableModes,
        [array]$CurrentModes
    )
    
    Write-Host ""
    Write-Host "=== Single App Mode Selection ===" -ForegroundColor Cyan
    Write-Host "Select one app mode for this installation:" -ForegroundColor White
    
    for ($i = 0; $i -lt $AvailableModes.Count; $i++)
    {
        $mode = $AvailableModes[$i]
        $isCurrent = $CurrentModes.Count -eq 1 -and $CurrentModes[0] -eq $mode.Mode
        $marker = if ($isCurrent)
        {
            " (Current)" 
        }
        else
        {
            "" 
        }
        $color = if ($isCurrent)
        {
            'Green' 
        }
        else
        {
            'White' 
        }
        
        Write-Host "$($i + 1). $($mode.Name)$marker" -ForegroundColor $color
        Write-Host "   $($mode.Description)" -ForegroundColor Gray
    }
    
    do
    {
        $choice = Read-Host "Select mode (1-$($AvailableModes.Count)) or Enter to cancel"
        
        if ([string]::IsNullOrWhiteSpace($choice))
        {
            return $null
        }
        
        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $AvailableModes.Count)
        {
            $selectedMode = $AvailableModes[[int]$choice - 1].Mode
            Write-Host "Selected: $selectedMode" -ForegroundColor Green
            return $selectedMode
        }
        
        Write-Host "Invalid choice. Please enter a number between 1 and $($AvailableModes.Count)." -ForegroundColor Red
    } while ($true)
}

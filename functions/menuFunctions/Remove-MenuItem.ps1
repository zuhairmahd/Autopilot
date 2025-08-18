function Remove-MenuItem()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Menu,
        [Parameter(Mandatory = $true)]
        [string]$ItemName
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Removing menu item: $ItemName from menu: $($Menu.Title)"
    
    # Only log if LogFile is available
    if ($LogFile -and (Test-Path (Split-Path $LogFile -Parent) -PathType Container))
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Removing menu item: $ItemName from menu: $($Menu.Title)" -LogLevel "Debug"
    }
    
    # Find and remove the item from the menu items array
    $originalCount = $Menu.Items.Count
    $Menu.Items = $Menu.Items | Where-Object { $_.Name -ne $ItemName }
    $newCount = $Menu.Items.Count
    
    if ($originalCount -gt $newCount)
    {
        Write-Verbose "[$functionName] Successfully removed menu item: $ItemName"
        if ($LogFile -and (Test-Path (Split-Path $LogFile -Parent) -PathType Container))
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Successfully removed menu item: $ItemName" -LogLevel "Information"
        }
    }
    else
    {
        Write-Verbose "[$functionName] Menu item not found: $ItemName"
        if ($LogFile -and (Test-Path (Split-Path $LogFile -Parent) -PathType Container))
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Menu item not found for removal: $ItemName" -LogLevel "Warning"
        }
    }
    
    return $Menu
}
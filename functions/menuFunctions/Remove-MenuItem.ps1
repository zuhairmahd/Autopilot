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
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Removing menu item: $ItemName from menu: $($Menu.Title)" -LogLevel "Debug"
    
    # Find and remove the item from the menu items array
    $originalCount = $Menu.Items.Count
    $Menu.Items = $Menu.Items | Where-Object { $_.Name -ne $ItemName }
    $newCount = $Menu.Items.Count
    
    if ($originalCount -gt $newCount)
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Successfully removed menu item: $ItemName" -LogLevel "Information"
    }
    else
    {
        Write-Verbose "[$functionName] Menu item not found: $ItemName"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Menu item not found for removal: $ItemName" -LogLevel "Verbose"
    }
    
    return $Menu
}
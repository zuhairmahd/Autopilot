function Test-MenuItemIncluded()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MenuItemName
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Checking if menu item '$MenuItemName' should be included"

    # Check if the global settings variable exists and has menuItemsToInclude
    Write-Verbose "[$functionName] App mode: $($settings.appMode)"  
    Write-Log -LogFile $LogFile -Module $functionName -Message "App mode: $($settings.appMode)" -LogLevel "Debug"
    Write-Verbose "[$functionName] Menu items to include count: $($Global:settings.menuItemsToInclude.Count)"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Menu items to include count: $($Global:settings.menuItemsToInclude.Count)" -LogLevel "Debug"
    if ($Global:settings -and $Global:settings.menuItemsToInclude -and $global:settings.appMode -ne 'full')
    {
        $included = $Global:settings.menuItemsToInclude -icontains $MenuItemName
        Write-Verbose "[$functionName] Menu item '$MenuItemName' inclusion check: $included"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Menu item '$MenuItemName' inclusion check: $included" -LogLevel "Debug"
        if ($included)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Menu item '$MenuItemName' was included" -LogLevel "Debug"
        }
        return $included
    }

    # If no inclusion list is found, include everything by default
    Write-Verbose "[$functionName] No inclusion list found, allowing menu item '$MenuItemName'"
    Write-Log -LogFile $LogFile -Module $functionName -Message "No inclusion list found, allowing menu item '$MenuItemName'" -LogLevel "Debug"
    return $true
}


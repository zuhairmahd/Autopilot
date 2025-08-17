function AddMenuItem()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Menu,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $false)]
        [scriptblock]$Action,
        [Parameter(Mandatory = $false)]
        [hashtable]$Submenu,
        [Parameter(Mandatory = $false)]
        [switch]$ReturnsValue
    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Adding/updating menu item: '$Name'" -LogLevel "Debug"
    
    if ($Action -and $Submenu)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error: Menu item '$Name' cannot have both Action and Submenu" -LogLevel "Error"
        throw "A menu item cannot have both an Action and a Submenu."
    }
    
    if (-not $Action -and -not $Submenu)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error: Menu item '$Name' must have either Action or Submenu" -LogLevel "Error"
        throw "A menu item must have either an Action or a Submenu."
    }
    
    # Check if an item with the same name already exists (for dynamic menu support)
    $existingItemIndex = -1
    for ($i = 0; $i -lt $Menu.Items.Count; $i++)
    {
        if ($Menu.Items[$i].Name -eq $Name)
        {
            $existingItemIndex = $i
            Write-Verbose "[$functionName] Found existing menu item with name: $Name at index $i"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Found existing menu item with name: $Name at index $i, will update instead of adding new" -LogLevel "Debug"
            break
        }
    }
    
    $item = [ordered] @{
        Name         = $Name
        Action       = $Action
        Submenu      = $Submenu
        ReturnsValue = $ReturnsValue
    }
    
    # Preserve includeInDisplayModes from existing item if updating
    if ($existingItemIndex -ge 0 -and $Menu.Items[$existingItemIndex].includeInDisplayModes)
    {
        $item.includeInDisplayModes = $Menu.Items[$existingItemIndex].includeInDisplayModes
        Write-Verbose "[$functionName] Preserving includeInDisplayModes from existing item: $($item.includeInDisplayModes -join ', ')"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Preserving includeInDisplayModes from existing item: $($item.includeInDisplayModes -join ', ')" -LogLevel "Debug"
    }
    
    Write-Verbose "[$functionName] Adding/updating menu item:"
    Write-Verbose "[$functionName] name: $Name"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Menu item details - Name: '$Name', ReturnsValue: $ReturnsValue" -LogLevel "Debug"
    
    if ($null -ne $action -or $action -eq '')
    {
        Write-Verbose "[$functionName] Type: action"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Menu item '$Name' has action" -LogLevel "Debug"
    }
    if ($null -ne $Submenu -or $Submenu -eq '')
    {
        Write-Verbose "[$functionName] Type: submenu"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Menu item '$Name' has submenu" -LogLevel "Debug"
    }
    Write-Verbose "[$functionName] returns value: $ReturnsValue"
    
    if ($existingItemIndex -ge 0)
    {
        # Update existing item
        Write-Verbose "[$functionName] Updating existing menu item at index $existingItemIndex"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Updating existing menu item '$Name' at index $existingItemIndex" -LogLevel "Information"
        $Menu.Items[$existingItemIndex] = $item
    }
    else
    {
        # Add new item
        Write-Verbose "[$functionName] Adding new menu item"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Adding new menu item '$Name' to menu" -LogLevel "Information"
        $Menu.Items += $item
    }
    
    Write-Log -LogFile $LogFile -Module $functionName -Message "Menu item '$Name' successfully added/updated. Total menu items: $($Menu.Items.Count)" -LogLevel "Debug"
    
    return $Menu
}


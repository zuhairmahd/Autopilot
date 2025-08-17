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
    if ($Action -and $Submenu)
    {
        throw "A menu item cannot have both an Action and a Submenu."
    }
    
    if (-not $Action -and -not $Submenu)
    {
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
    }
    
    Write-Verbose "[$functionName] Adding/updating menu item:"
    Write-Verbose "[$functionName] name: $Name"
    if ($null -ne $action -or $action -eq '')
    {
        Write-Verbose "[$functionName] Type: action"
    }
    if ($null -ne $Submenu -or $Submenu -eq '')
    {
        Write-Verbose "[$functionName] Type: submenu"
    }
    Write-Verbose "[$functionName] returns value: $ReturnsValue"
    
    if ($existingItemIndex -ge 0)
    {
        # Update existing item
        Write-Verbose "[$functionName] Updating existing menu item at index $existingItemIndex"
        $Menu.Items[$existingItemIndex] = $item
    }
    else
    {
        # Add new item
        Write-Verbose "[$functionName] Adding new menu item"
        $Menu.Items += $item
    }
    
    return $Menu
}


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
    
    $item = [ordered] @{
        Name         = $Name
        Action       = $Action
        Submenu      = $Submenu
        ReturnsValue = $ReturnsValue
    }
    Write-Verbose "[$functionName] Adding the following menu item:"
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
    $Menu.Items += $item
    return $Menu
}


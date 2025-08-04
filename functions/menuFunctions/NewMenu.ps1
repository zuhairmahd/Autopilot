function NewMenu()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [Parameter(Mandatory = $false)]
        [string]$Description
    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Creating new menu with title: $Title and description: $Description"    
    $menu = [ordered]@{
        Title       = $Title
        Description = $Description
        Items       = @()
    }
    
    return $menu
}


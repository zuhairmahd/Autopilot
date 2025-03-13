    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$versionNumber
    )


$version = Get-Content -Raw -Path version.json | ConvertFrom-Json

# Iterate over the properties of the object.
foreach ($entry in $version.PSObject.Properties)
{
    Write-Host "Key: $($entry.Name) Value: $($entry.Value)"
}

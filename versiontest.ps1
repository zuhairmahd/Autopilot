# Read the JSON file
$jsonContent = Get-Content -Path 'version.json' -Raw | ConvertFrom-Json

# Display the variables one per line
foreach ($key in $scriptVersionRemote.versions.PSObject.Properties.Name)
{
    Write-Host $key
    $value = $jsonContent.versions.$key
    Write-Output "${key}: ${value}"
}
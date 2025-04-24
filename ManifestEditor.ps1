[CmdletBinding()]
param (
    [string]$InputFile = "$pwd\manifest.json",
    [string]$OutputFile = "$pwd\manifest-output.json"
)
    
#Read the input json file.
$inputJson = Get-Content -Path $InputFile -Raw | ConvertFrom-Json
foreach ($item in $inputJson.PSObject.Properties)
{
    # Process each item in the JSON object
    # For demonstration, we will just print the name of each property
    # You can replace this with your actual processing logic
    Write-Host "Processing item: $($item.Name)"
    foreach ($subitem in $item.Value.PSObject.Properties)
    {
        # Process each subitem in the JSON object
        # For demonstration, we will just print the name of each property
        # You can replace this with your actual processing logic
        Write-Host "Processing subitem: $($subitem.Name)"
        #We now have an array of hashtables we need to treverse.
        for ($i - 0; $i -lt $subitem.Count; $i++)
        {
            # Process each subitem in the JSON object
            # For demonstration, we will just print the name of each property
            # You can replace this with your actual processing logic
            Write-Host "Processing subitem: $($subitem[$i].Name)"
        }
        {
            # Process each subsubitem in the JSON object
            # For demonstration, we will just print the name of each property
            # You can replace this with your actual processing logic
            Write-Host "Processing subsubitem: $($subsubitem.Name)"
        }
    }
}

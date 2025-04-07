[CmdletBinding()]
param (
    [string]$Endpoint,
    [string]$Version = 'beta',
    [string]$Method = 'Get',
    [switch]$Connect
)

# Define the Graph API endpoint
# $graphApiUrl = "https://graph.microsoft.com/$Version/$endpoint"
# Write-Host "Calling Graph API at $graphApiUrl with method $Method"

$secretsFile = "$pwd\.secrets\config.json"
$functionsFolder = "$pwd\functions"
#import functions.
if (Test-Path $functionsFolder)
{
    Write-Verbose "Importing functions from $functionsFolder"
    $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -ErrorAction Stop
    foreach ($function in $functions)
    {
        Write-Verbose "Importing function $function"
        . $function.FullName
    }
}
else
{
    Write-Host 'Cannot find the functions folder. Exiting script.' -ForegroundColor Red
    exit 1
}

if ($Connect)
{
    Write-Verbose 'Connecting to tenant'
    ConnectToTenant -configFile $secretsFile
    Write-Verbose 'Connected to Microsoft graph with the following scopes:'
    $scopes = Get-MgContext | Select-Object -ExpandProperty Scopes
    Write-Verbose "$scopes"
}

function get-deviceidentifierinfo
{
    [cmdletbinding()]
    param
    (
        $export,
        $outputfile
    )
    # Capture the output from WMI objects
    $computerSystem = Get-WmiObject -Class Win32_ComputerSystem
    $bios = Get-WmiObject -Class Win32_BIOS
    $manufacturer = $computerSystem.Manufacturer
    $model = $computerSystem.Model
    $serial = $bios.SerialNumber
    if ($export -eq $true)
    {
        # Combine the results into a single string
        $data = "$($computerSystem.Manufacturer),$($computerSystem.Model),$($bios.SerialNumber)"
        # Write the data to a CSV file without headers
        Set-Content -Path $outputfile -Value $data
    }
    else
    {
        ##Create a custom object
        $deviceinfo = New-Object PSObject
        $deviceinfo | Add-Member -MemberType NoteProperty -Name "Manufacturer" -Value $manufacturer
        $deviceinfo | Add-Member -MemberType NoteProperty -Name "Model" -Value $model
        $deviceinfo | Add-Member -MemberType NoteProperty -Name "Serial" -Value $serial
        return $deviceinfo
    }
}

function check-importeddevice
{
    [cmdletbinding()]
    param
    (
        $manufacturer,
        $model,
        $serial
    )

    #write a verbose log of the parameters
    Write-Verbose "Manufacturer: $manufacturer"
    Write-Verbose "Model: $model"
    Write-Verbose "Serial: $serial"
    ##Check it exists
    $uri = "https://graph.microsoft.com/beta/deviceManagement/importedDeviceIdentities/searchExistingIdentities"
    $json = @"
{
"importedDeviceIdentities": [
    {
        "importedDeviceIdentifier": "$manufacturer,$model,$serial",
        "importedDeviceIdentityType": "manufacturerModelSerial"
    }
]
}
"@

    Write-Host "calling the API at $uri using Post with the body $json"
    $response = Invoke-MgGraphRequest -Uri $uri -Method Post -Body $json -OutputType PSObject
    Write-Host $response
    if (!$response)
    {
        Write-Host "No device found with the specified manufacturer, model, and serial number." -ForegroundColor Red
        return $false
    }
    else
    {
        return $response
    }
}


Function Get-IntuneApplicationbyName()
{
    <#
    .SYNOPSIS
    This function is used to get applications from the Graph API REST interface by name
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any applications added
    .EXAMPLE
    Get-IntuneApplicationbyName
    Returns any applications configured in Intune
    .NOTES
    NAME: Get-IntuneApplicationbyName
    #>
    [cmdletbinding()]
    param
    (
        $name
    )
    $graphApiVersion = "Beta"
    $Resource = "deviceAppManagement/mobileApps"
    try
    {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=displayname eq '$name'"
        $app = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value | Where-Object { ($_.'@odata.type').Contains("#microsoft.graph.winGetApp") }
    }
    catch
    {
    }
    $myid = $app.id
    if ($null -ne $myid)
    {
        $fulluri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$myid"
        $type = "Winget Application"
    }
    else
    {
        $fulluri = ""
        $type = ""
    }
    $output = "" | Select-Object -Property id, fulluri, type    
    $output.id = $myid
    $output.fulluri = $fulluri
    $output.type = $type
    return $output
}


exit 0
# Call the Graph API
$global:response = Invoke-MgGraphRequest -Method $Method -Uri $graphApiUrl
foreach ($item in $response.value)
{
    Write-Host $item.displayname
    foreach ($subitem in $item)
    {
        Write-Host $subitem
    }
}

# Function to get the enrollment status of a device using its serial number
function GetDeviceBySerial()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SerialNumber,
        [Parameter(Mandatory = $true)]
        [string]$ACCESS_TOKEN
    )
    #Write verbose log of received parameters
    Write-Verbose "Serial Number: $SerialNumber"
    # Query the device enrollment status using Microsoft Graph API
    try
    {
        $graphApiUrl = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices"
        $graphApiUrl += "?`$filter=serialNumber eq '$SerialNumber'"
        Write-Verbose "Graph API URL: $graphApiUrl"

        # Fetch the device details using the serial number
        $response = Invoke-RestMethod -Uri $graphApiUrl -Method Get -Headers @{ Authorization = "Bearer $($ACCESS_TOKEN)" } -ErrorAction Stop
        if ($response)
        {
            $device = $response.value
            Write-Verbose "Device found: $($device)"
        }
        else
        {
            Write-Verbose "Device with serial number $SerialNumber not found."
        }
    }
    catch
    {
        Write-Error "Error retrieving device enrollment status: $_"
    }
    return $device
}
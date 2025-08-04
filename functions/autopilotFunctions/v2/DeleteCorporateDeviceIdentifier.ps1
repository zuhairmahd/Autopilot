function DeleteCorporateDeviceIdentifier()
{
    <#
    .SYNOPSIS
    Deletes a device identifier from Windows Corporate Device Identifiers in Intune.
    
    .DESCRIPTION
    This function removes a device identifier from the corporate device identifiers list in Microsoft Intune. 
    This is useful when devices are no longer corporate-owned or need to be removed from the managed device list.
    
    Supports three types of identifiers:
    - SerialNumber: Just the device serial number
    - IMEI: Device IMEI number (for mobile devices)
    - manufacturerModelSerial: Comma-separated string "Manufacturer,Model,SerialNumber" (Windows-specific)
    
    .PARAMETER AccessToken
    Valid Microsoft Graph API access token with deviceManagement permissions.
    
    .PARAMETER DeviceIdentifier
    The device identifier to delete. Format depends on IdentifierType:
    - For SerialNumber: Just the serial number (e.g., "ABC123456789")
    - For IMEI: Just the IMEI number (e.g., "123456789012345")
    - For manufacturerModelSerial: "Manufacturer,Model,SerialNumber" (e.g., "Microsoft Corporation,Virtual Machine,ABC123456789")
    
    .PARAMETER IdentifierType
    Type of identifier being provided. Valid values are:
    - 'SerialNumber': Device serial number only
    - 'IMEI': Device IMEI number only  
    - 'manufacturerModelSerial': Windows-specific format with manufacturer, model, and serial
    Default is 'manufacturerModelSerial'.
    
    .PARAMETER MaxRetries
    Maximum number of retries to verify the deletion was successful. Default is 10.
    
    .PARAMETER RetryDelaySeconds
    Number of seconds to wait between verification attempts. Default is 5.
    
    .EXAMPLE
    DeleteCorporateDeviceIdentifier -AccessToken $token -DeviceIdentifier "ABC123456789" -IdentifierType "SerialNumber"
    
    .EXAMPLE
    DeleteCorporateDeviceIdentifier -AccessToken $token -DeviceIdentifier "123456789012345" -IdentifierType "IMEI"
    
    .EXAMPLE
    DeleteCorporateDeviceIdentifier -AccessToken $token -DeviceIdentifier "Microsoft Corporation,Virtual Machine,ABC123456789" -IdentifierType "manufacturerModelSerial"
    
    .NOTES
    This function was created to provide cleanup capabilities for corporate device identifiers
    that are no longer needed or were added incorrectly.
    
    Requires Microsoft Graph API permissions:
    - DeviceManagementManagedDevices.ReadWrite.All
    - DeviceManagementConfiguration.ReadWrite.All
    
    API Endpoint: https://graph.microsoft.com/beta/deviceManagement/importedDeviceIdentities
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$DeviceInfo, # Output from GetCorpDeviceIdentifier
        [Parameter(Mandatory = $false)]
        [ValidateSet('SerialNumber', 'IMEI', 'manufacturerModelSerial')]
        [string]$IdentifierType = 'manufacturerModelSerial',
        [int]$MaxRetries = 10,
        [int]$RetryDelaySeconds = 5
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Entered function. Parameters: AccessToken='$(if ($AccessToken) {'***'} else {'<null>'})', DeviceInfo='$($DeviceInfo | ConvertTo-Json -Compress)', IdentifierType='$IdentifierType'"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting DeleteCorporateDeviceIdentifier. DeviceInfo='$($DeviceInfo | ConvertTo-Json -Compress)', IdentifierType='$IdentifierType'" -LogLevel "Information"

    if ($AccessToken -eq '' -or $null -eq $AccessToken)
    {
        Write-Verbose "[$functionName] No AccessToken provided. Aborting."
        Write-Log -LogFile $LogFile -Module $functionName -Message "No AccessToken provided. Aborting." -LogLevel "Error"
        return $false
    }
    else
    {
        Write-Verbose "[$functionName] AccessToken provided."
        Write-Log -LogFile $LogFile -Module $functionName -Message "AccessToken provided." -LogLevel "Debug"
    }

    # Microsoft Graph API endpoint for Windows Corporate Device Identifiers
    $uri = "deviceManagement/importedDeviceIdentities"
    Write-Verbose "[$functionName] Using Graph API endpoint: $uri"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Using Graph API endpoint: $uri" -LogLevel "Debug"

    # Handle different identifier types with proper formatting for filtering
    $formattedType = $IdentifierType.ToLower()
    if ($IdentifierType -eq 'manufacturerModelSerial')
    {
        Write-Verbose "[$functionName] IdentifierType is manufacturerModelSerial. Building identifier from DeviceInfo object."
        $manufacturerEscaped = $DeviceInfo.Manufacturer -replace ',', '\,'
        $modelEscaped = $DeviceInfo.Model -replace ',', '\,'
        $serialEscaped = $DeviceInfo.SerialNumber -replace ',', '\,'
        $formattedIdentifier = ("$manufacturerEscaped,$modelEscaped,$serialEscaped" -replace '[^\w,]', '')
        Write-Verbose "[$functionName] manufacturerModelSerial built: Manufacturer='$manufacturerEscaped', Model='$modelEscaped', Serial='$serialEscaped' (commas escaped)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "manufacturerModelSerial built: Manufacturer='$manufacturerEscaped', Model='$modelEscaped', Serial='$serialEscaped' (commas escaped)" -LogLevel "Debug"
    }
    elseif ($IdentifierType -eq 'SerialNumber')
    {
        $formattedIdentifier = $DeviceInfo.SerialNumber
        $formattedType = "serialNumber"
        Write-Verbose "[$functionName] IdentifierType is SerialNumber. formattedType set to 'serialNumber'."
        Write-Log -LogFile $LogFile -Module $functionName -Message "IdentifierType is SerialNumber. formattedType set to 'serialNumber'." -LogLevel "Debug"
    }
    elseif ($IdentifierType -eq 'IMEI')
    {
        $formattedIdentifier = $DeviceInfo.IMEI
        $formattedType = "imei"
        Write-Verbose "[$functionName] IdentifierType is IMEI. formattedType set to 'imei'."
        Write-Log -LogFile $LogFile -Module $functionName -Message "IdentifierType is IMEI. formattedType set to 'imei'." -LogLevel "Debug"
    }

    try
    {
        # First, find the device identifier in the imported device identities
        Write-Host "Searching for device identifier in corporate identifiers..." -ForegroundColor Yellow
        Write-Verbose "[$functionName] Searching for device identifier with type '$formattedType' and value '$formattedIdentifier'"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Searching for device identifier with type '$formattedType' and value '$formattedIdentifier'" -LogLevel "Information"
        
        # Based on Microsoft documentation, filters on importedDeviceIdentities may not work properly
        # Get all devices and filter client-side as recommended when API filters fail
        Write-Verbose "[$functionName] Getting all imported device identities to filter client-side"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Getting all imported device identities to filter client-side" -LogLevel "Debug"
        
        $allDevices = (CallGraphAPI -AccessToken $AccessToken -ResourcePath $uri).value
        Write-Verbose "[$functionName] Retrieved $($allDevices.Count) total imported device identities"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Retrieved $($allDevices.Count) total imported device identities" -LogLevel "Debug"
        
        # Filter client-side based on identifier type and value
        $existingDevices = @()
        foreach ($device in $allDevices)
        {
            # Check if this device matches our search criteria
            $deviceMatches = $false
            
            if ($IdentifierType -eq 'SerialNumber')
            {
                # For serial number, check if the importedDeviceIdentifier matches the device serial
                if ($device.importedDeviceIdentifier -eq $formattedIdentifier)
                {
                    $deviceMatches = $true
                }
            }
            elseif ($IdentifierType -eq 'IMEI')
            {
                # For IMEI, check if the importedDeviceIdentifier matches the IMEI
                if ($device.importedDeviceIdentifier -eq $formattedIdentifier)
                {
                    $deviceMatches = $true
                }
            }
            elseif ($IdentifierType -eq 'manufacturerModelSerial')
            {
                # For manufacturerModelSerial, check if the importedDeviceIdentifier matches the formatted string
                if ($device.importedDeviceIdentifier -eq $formattedIdentifier)
                {
                    $deviceMatches = $true
                }
            }
            
            if ($deviceMatches)
            {
                $existingDevices += $device
                Write-Verbose "[$functionName] Found matching device: ID=$($device.id), Identifier=$($device.importedDeviceIdentifier), Type=$($device.importedDeviceIdentityType)"
            }
        }
        
        Write-Verbose "[$functionName] Found $($existingDevices.Count) matching device(s) after client-side filtering"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Found $($existingDevices.Count) matching device(s) after client-side filtering" -LogLevel "Debug"
        
        if ($existingDevices -and $existingDevices.Count -gt 0)
        {
            # Get the first matching device (there should typically only be one)
            $deviceToDelete = $existingDevices[0]
            $deviceId = $deviceToDelete.id
            Write-Host "Found device identifier with ID: $deviceId" -ForegroundColor Green
            Write-Verbose "[$functionName] Device to delete: $($deviceToDelete | ConvertTo-Json -Depth 3)"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Found device identifier to delete with ID: $deviceId" -LogLevel "Information"
            
            # Delete the device identifier
            $deleteUri = "$uri/$deviceId"
            Write-Verbose "[$functionName] Delete URI: $deleteUri"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Delete URI: $deleteUri" -LogLevel "Debug"
            
            Write-Host "Deleting corporate device identifier..." -ForegroundColor Yellow
            Write-Verbose "[$functionName] Calling CallGraphAPI with DELETE to $deleteUri"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Calling CallGraphAPI with DELETE to $deleteUri" -LogLevel "Information"
            
            $deleteResponse = CallGraphAPI -AccessToken $AccessToken -ResourcePath $deleteUri -Method DELETE
            Write-Verbose "[$functionName] Delete response: $($deleteResponse | Out-String)"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Delete response: $($deleteResponse | Out-String)" -LogLevel "Debug"
            
            # Verify deletion (Graph API DELETE typically returns null/empty on success)
            if ($null -eq $deleteResponse -or $deleteResponse -eq '')
            {
                Write-Verbose "[$functionName] Delete request initiated successfully."
                Write-Log -LogFile $LogFile -Module $functionName -Message "Delete request initiated successfully." -LogLevel "Information"
                return $returnValues.deviceDeleteSuccessMessage
            }
            else
            {
                Write-Host "Failed to delete corporate device identifier." -ForegroundColor Red
                Write-Verbose "[$functionName] API call returned unexpected result: $($deleteResponse | ConvertTo-Json -Depth 3)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to delete corporate device identifier - unexpected API response: $($deleteResponse | ConvertTo-Json -Depth 5)" -LogLevel "Error"
                return $returnValues.deviceDeleteFailedMessage
            }
        }
        else
        {
            Write-Host "No corporate device identifier found matching the specified criteria." -ForegroundColor Yellow
            Write-Verbose "[$functionName] No device found with identifier '$formattedIdentifier' and type '$formattedType'"
            Write-Log -LogFile $LogFile -Module $functionName -Message "No device found with identifier '$formattedIdentifier' and type '$formattedType'" -LogLevel "Warning"
            return $returnValues.noDeviceFound
        }
    }
    catch
    {
        Write-Host "Error deleting corporate device identifier: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose "[$functionName] Error details: $($_.Exception | Format-List * | Out-String)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error deleting corporate device identifier: $($_.Exception.Message)" -LogLevel "Error"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Exception details: $($_.Exception | Format-List * | Out-String)" -LogLevel "Debug"
        return $returnValues.deviceDeleteFailedMessage
    }
}

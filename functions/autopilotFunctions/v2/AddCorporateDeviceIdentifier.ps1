function AddCorporateDeviceIdentifier()
{
    <#
    .SYNOPSIS
    Adds a device identifier to Windows Corporate Device Identifiers in Intune.
    
    .DESCRIPTION
    This function adds a device identifier to the corporate device identifiers list in Microsoft Intune. 
    This helps identify corporate-owned devices for enrollment and management purposes.
    
    Supports three types of identifiers:
    - SerialNumber: Just the device serial number
    - IMEI: Device IMEI number (for mobile devices)
    - manufacturerModelSerial: Comma-separated string "Manufacturer,Model,SerialNumber" (Windows-specific)
    
    .PARAMETER AccessToken
    Valid Microsoft Graph API access token with deviceManagement permissions.
    
    .PARAMETER DeviceIdentifier
    The device identifier to add. Format depends on IdentifierType:
    - For SerialNumber: Just the serial number (e.g., "ABC123456789")
    - For IMEI: Just the IMEI number (e.g., "123456789012345")
    - For manufacturerModelSerial: "Manufacturer,Model,SerialNumber" (e.g., "Microsoft Corporation,Virtual Machine,ABC123456789")
    
    .PARAMETER IdentifierType
    Type of identifier being provided. Valid values are:
    - 'SerialNumber': Device serial number only
    - 'IMEI': Device IMEI number only  
    - 'manufacturerModelSerial': Windows-specific format with manufacturer, model, and serial
    Default is 'manufacturerModelSerial'.
    
    .PARAMETER OverwriteImportedDeviceIdentities
    Switch to enable overwriting existing device identities if they already exist.
    
    .EXAMPLE
    AddCorporateDeviceIdentifier -AccessToken $token -DeviceIdentifier "ABC123456789" -IdentifierType "SerialNumber"
    
    .EXAMPLE
    AddCorporateDeviceIdentifier -AccessToken $token -DeviceIdentifier "123456789012345" -IdentifierType "IMEI"
    
    .EXAMPLE
    AddCorporateDeviceIdentifier -AccessToken $token -DeviceIdentifier "Microsoft Corporation,Virtual Machine,ABC123456789" -IdentifierType "manufacturerModelSerial"
    
    .EXAMPLE
    AddCorporateDeviceIdentifier -AccessToken $token -DeviceIdentifier "Dell Inc.,OptiPlex 7090,DEL123456" -IdentifierType "manufacturerModelSerial" -OverwriteImportedDeviceIdentities
    
    .NOTES
    This function was created to resolve Autopilot V2 device import issues where devices
    need to be marked as corporate-owned before enrollment.
    
    Requires Microsoft Graph API permissions:
    - DeviceManagementManagedDevices.ReadWrite.All
    - DeviceManagementConfiguration.ReadWrite.All
    
    API Endpoint: https://graph.microsoft.com/beta/deviceManagement/importedDeviceIdentities/importDeviceIdentityList
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
        [switch]$OverwriteImportedDeviceIdentities
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Entered function. Parameters: AccessToken='$(if ($AccessToken) {'***'} else {'<null>'})', DeviceIdentifier='$DeviceIdentifier', IdentifierType='$IdentifierType', OverwriteImportedDeviceIdentities='$OverwriteImportedDeviceIdentities'"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting AddCorporateDeviceIdentifier. DeviceIdentifier='$DeviceIdentifier', IdentifierType='$IdentifierType', OverwriteImportedDeviceIdentities='$OverwriteImportedDeviceIdentities'" -LogLevel "Information"
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Entered function. Parameters: AccessToken='$(if ($AccessToken) {'***'} else {'<null>'})', DeviceInfo='$DeviceInfo', IdentifierType='$IdentifierType', OverwriteImportedDeviceIdentities='$OverwriteImportedDeviceIdentities'"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting AddCorporateDeviceIdentifier. DeviceInfo='$DeviceInfo', IdentifierType='$IdentifierType', OverwriteImportedDeviceIdentities='$OverwriteImportedDeviceIdentities'" -LogLevel "Information"
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

    if ($OverwriteImportedDeviceIdentities)
    {
        $deviceOverwrite = $true
        Write-Verbose "[$functionName] OverwriteImportedDeviceIdentities switch is set. Will overwrite existing device identities."
        Write-Log -LogFile $LogFile -Module $functionName -Message "OverwriteImportedDeviceIdentities is set to true." -LogLevel "Debug"
    }
    else
    {
        $deviceOverwrite = $false
        Write-Verbose "[$functionName] OverwriteImportedDeviceIdentities switch is NOT set. Will NOT overwrite existing device identities."
        Write-Log -LogFile $LogFile -Module $functionName -Message "OverwriteImportedDeviceIdentities is set to false." -LogLevel "Debug"
    }

    # Microsoft Graph API endpoint for Windows Corporate Device Identifiers
    $uri = "deviceManagement/importedDeviceIdentities/importDeviceIdentityList"
    Write-Verbose "[$functionName] Using Graph API endpoint: $uri"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Using Graph API endpoint: $uri" -LogLevel "Debug"

    # Handle different identifier types with proper formatting
    $formattedType = $IdentifierType.ToLower()
    if ($IdentifierType -eq 'manufacturerModelSerial')
    {
        Write-Verbose "[$functionName] IdentifierType is manufacturerModelSerial. Building identifier from DeviceInfo object."
        $manufacturerEscaped = $DeviceInfo.Manufacturer -replace ',', '\,'
        $modelEscaped = $DeviceInfo.Model -replace ',', '\,'
        $serialEscaped = $DeviceInfo.SerialNumber -replace ',', '\,'
        $formattedIdentifier = ("$manufacturerEscaped,$modelEscaped,$serialEscaped" -replace '[^\w,]', '').ToUpper()
        Write-Verbose "[$functionName] manufacturerModelSerial built: Manufacturer='$manufacturerEscaped', Model='$manufacturerEscaped', Serial='$serialEscaped' (commas escaped)"
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

    $body = @{
        overwriteImportedDeviceIdentities = $deviceOverwrite 
        importedDeviceIdentities          = @(
            @{ 
                "@odata.type"              = "#microsoft.graph.importedDeviceIdentity"
                importedDeviceIdentifier   = $formattedIdentifier
                importedDeviceIdentityType = $formattedType
                description                = "Added via PowerShell Autopilot Tool"
            }
        )
    } | ConvertTo-Json -Depth 100
    Write-Verbose "[$functionName] Request body: $body"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Request body prepared for API call: $body" -LogLevel "Debug"

    try
    {
        Write-Host "Adding device identifier to corporate identifiers..." -ForegroundColor Yellow
        Write-Verbose "[$functionName] Calling CallGraphAPI with POST to $uri."
        Write-Log -LogFile $LogFile -Module $functionName -Message "Calling CallGraphAPI with POST to $uri." -LogLevel "Information"
        $result = (CallGraphAPI -AccessToken $AccessToken -ResourcePath $uri -Method POST -Body $body).value
        Write-Verbose "[$functionName] CallGraphAPI returned: $($result | ConvertTo-Json -Depth 100)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "CallGraphAPI returned: $($result | ConvertTo-Json -Depth 100)" -LogLevel "Debug"
        Start-Sleep -Seconds 5 # Allow time for the API to process
        if ($result -and $result.id)
        {
            Write-Host "Successfully added device identifier to corporate identifiers." -ForegroundColor Green
            Write-Verbose "[$functionName] Successfully added corporate device identifiers. Response: $($result | ConvertTo-Json -Depth 5)"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully added corporate device identifiers. Response: $($result | ConvertTo-Json -Depth 5)" -LogLevel "Information"
            return $result
        }
        else
        {
            Write-Host "Failed to add device identifier to corporate identifiers." -ForegroundColor Red
            Write-Verbose "[$functionName] API call returned unexpected result: $($result | ConvertTo-Json -Depth 3)"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to add corporate device identifier - unexpected API response: $($result | ConvertTo-Json -Depth 5)" -LogLevel "Error"
            return $null
        }
    }
    catch
    {
        Write-Host "Error adding device identifier to corporate identifiers: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose "[$functionName] Error details: $($_.Exception | Format-List * | Out-String)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error adding corporate device identifier: $($_.Exception.Message)" -LogLevel "Error"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Exception details: $($_.Exception | Format-List * | Out-String)" -LogLevel "Debug"
        return $null
    }
}


function DeleteAutopilotDevice()
{
    <#
    .SYNOPSIS
    Deletes an Autopilot device registration from Microsoft Intune.

    .DESCRIPTION
    This function removes an Autopilot device from Intune by serial number or device ID. It includes
    retry logic with configurable attempts and delays to handle transient errors, validates device
    exists before deletion, and provides comprehensive logging of the deletion process.

    .PARAMETER DeviceIdentifyer
    The device identifier (serial number or device ID). This parameter is mandatory and accepts pipeline input.

    .PARAMETER IdentifyerType
    Type of identifier: 'SerialNumber' (default) or 'DeviceId'.

    .PARAMETER accessToken
    The Microsoft Graph API access token.

    .PARAMETER MaxRetries
    Maximum number of deletion retry attempts. Default is 10.

    .PARAMETER RetryDelaySeconds
    Seconds to wait between retry attempts. Default is 20.

    .OUTPUTS
    System.Boolean
    Returns $true if deletion succeeds, $false if deletion fails after all retries.

    .EXAMPLE
    DeleteAutopilotDevice -DeviceIdentifyer "ABC123" -accessToken $token
    "ABC123" | DeleteAutopilotDevice -accessToken $token -MaxRetries 5

    .NOTES
    Looks up device by serial number or uses device ID directly.
    Implements retry logic for reliability.
    Validates device exists before attempting deletion.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$DeviceIdentifyer,
        [ValidateSet('SerialNumber', 'DeviceId')]
        [string]$IdentifyerType = 'SerialNumber',
        [string]$accessToken = $accessToken,
        [int]$MaxRetries = 10,
        [int]$RetryDelaySeconds = 20
    )
    $functionName = $MyInvocation.MyCommand.Name
    
    #region variables and logs.
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Starting DeleteAutopilotDevice: Identifier=$DeviceIdentifyer Type=$IdentifyerType MaxRetries=$MaxRetries RetryDelaySeconds=$RetryDelaySeconds" -LogLevel "Information"
    Write-Verbose "[$functionName] Received parameters:" 
    if ($accessToken)
    {
        Write-Verbose "[$functionName]     AccessToken provided."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Access token provided" -LogLevel "Verbose"
    }
    else
    {
        Write-Verbose "[$functionName]     No AccessToken provided."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No access token provided - aborting" -LogLevel "Error"
        return $null
    }
    Write-Verbose "[$functionName] Device identifier: $DeviceIdentifyer."
    Write-Verbose "[$functionName] Identifyer type: $IdentifyerType."
    $success = $false
    $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
    #endregion variables and logs.

    switch ($IdentifyerType)
    {
        'SerialNumber'
        {
            $autopilotDeviceFilter = "contains(serialNumber,'$DeviceIdentifyer')"
            Write-Verbose "[$functionName] Identifyer Type is $IdentifyerType."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Identifier type SerialNumber. Filtering for $DeviceIdentifyer" -LogLevel "Verbose"
            if ($DeviceIdentifyer -match 'vmware')
            {
                Write-Verbose "[$functionName] VMware device detected."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "VMware serial detected $DeviceIdentifyer" -LogLevel "Information"
                $autoPilotDeviceId = GetVMAutopilotDeviceIdBySerialNumber -AccessToken $AccessToken -serialNumber $DeviceIdentifyer
                Write-Verbose "[$functionName] Autopilot device Id for serial number $deviceIdentifyer is $autoPilotDeviceId"
                if ($autoPilotDeviceId)
                {
                    Write-Verbose "[$functionName] Device with Id $autoPilotDeviceId found in Autopilot."
                    Write-Verbose "[$functionName] Returning device id: $autoPilotDeviceId"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found VMware device id $autoPilotDeviceId" -LogLevel "Information"
                }
                else
                {
                    Write-Verbose "[$functionName] No match for device with serial number $serialNumber found in Autopilot."
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "No VMware device found for serial $DeviceIdentifyer" -LogLevel "Warning"
                }
            }
            else
            {
                Write-Verbose "[$functionName] Not a VMWare device. Continuing"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Not a VMware serial. Querying Autopilot for $DeviceIdentifyer" -LogLevel "Verbose"
                $autopilotDevice = (CallGraphAPI -AccessToken $accessToken -ResourcePath $autoPilotDeviceURI -filter $autopilotDeviceFilter).value
                Write-Verbose "[$functionName] Found $($autopilotDevice.count) Autopilot devices."
                Write-Verbose "[$functionName] Autopilot Device serial number: $($autopilotDevice.serialNumber)"
                $autoPilotDeviceId = $autopilotDevice.id
                Write-Verbose "[$functionName] Autopilot Device Id: $($autoPilotDeviceId)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Standard query returned id $autoPilotDeviceId (count=$($autopilotDevice.count))" -LogLevel "Information"
            }
        }
        'DeviceId'
        {
            Write-Verbose "[$functionName] Parameter type is DeviceId."
            Write-Verbose "[$functionName] $IdentifyerType is $deviceIdentifyer."
            $autoPilotDeviceId = $deviceIdentifyer
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Using provided DeviceId $autoPilotDeviceId" -LogLevel "Verbose"
        }
    }
    
    if ($autoPilotDeviceId)
    {
        Write-Verbose "[$functionName] Found device with id $autoPilotDeviceId in Autopilot."
        Write-Verbose "[$functionName] Defining variables:"
        $deleteUri = "$autopilotDeviceURI/$autoPilotDeviceId"
        Write-Verbose "[$functionName] Delete URI: $deleteUri"
        Write-Host "Deleting autopilot device..."
        Write-Verbose "[$functionName] Calling Graph API to delete autopilot device with serial number $($autopilotDevice.serialNumber)"
        Write-Verbose "[$functionName] Passing the uri $deleteUri"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Issuing DELETE $deleteUri" -LogLevel "Information"
        $deleteResponse = CallGraphAPI -AccessToken $accessToken -ResourcePath $deleteUri -Method DELETE
        Write-Verbose "[$functionName] Delete response: $($deleteResponse | Out-String)"
        if ($null -eq $deleteResponse -or $deleteResponse -eq '')
        {
            Write-Verbose "[$functionName] Delete request initiated successfully. Beginning monitoring of device deletion..."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Delete request accepted for $autoPilotDeviceId. Monitoring..." -LogLevel "Information"
            Write-Host "Delete request accepted..." -ForegroundColor Green        
            $response = Read-Host "Would you like to monitor the deletion process? (Y/N)"
            while ($response -notmatch '^(Y|N)$')
            {
                [console]::beep(1000, 300)
                $response = Read-Host "Please enter Y or N. Monitor the deletion process? (Y/N)"
            }
            if ($response -eq 'N')
            {
                Write-Host "Skipping monitoring of deletion process." -ForegroundColor Yellow
                Write-Host "It may take some time for the device to be fully deleted from Autopilot." -ForegroundColor Yellow
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "User opted out of monitoring deletion process for $autoPilotDeviceId" -LogLevel "Information"
                return $true
            }
            #region Monitor the deletion process
            $retryCount = 0
            $isDeleted = $false
            $deviceInfo = $null
            
            while (-not $isDeleted -and $retryCount -lt $MaxRetries)
            {
                $retryCount++
                Write-Host "Verifying device deletion, attempt $retryCount of $MaxRetries..." -ForegroundColor Yellow
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Verify attempt $retryCount/$MaxRetries for $autoPilotDeviceId" -LogLevel "Verbose"
                Write-Verbose "[$functionName] Checking if device is still present after delete request (Attempt $retryCount of $MaxRetries)"
                
                # Sleep before checking
                Start-Sleep -Seconds $RetryDelaySeconds
                
                # Check if the device still exists
                if ($IdentifyerType -eq 'SerialNumber')
                {
                    $autopilotDeviceFilter = "contains(serialNumber,'$DeviceIdentifyer')"
                    $deviceInfo = (CallGraphAPI -AccessToken $accessToken -ResourcePath $autoPilotDeviceURI -filter $autopilotDeviceFilter).value
                }
                else # DeviceId
                {
                    $checkUri = "$autoPilotDeviceURI/$autoPilotDeviceId"
                    try
                    {
                        $deviceInfo = CallGraphAPI -AccessToken $accessToken -ResourcePath $checkUri -Method GET
                        Write-Verbose "[$functionName] Device check response: $($deviceInfo | Out-String)"
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device still present on GET $checkUri" -LogLevel "Debug"
                    } 
                    catch
                    {
                        # If the call fails with 404 (not found), the device is deleted
                        Write-Verbose "[$functionName] Error checking device: $_"
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error on GET $checkUri : $($_.Exception.Message)" -LogLevel "Warning"
                        if ($_.Exception.Response.StatusCode -eq 404)
                        {
                            $deviceInfo = $null
                            Write-Log -LogFile $LogFile -Module "$functionName" -Message "GET returned 404 - treating as deleted" -LogLevel "Information"
                        }
                    }
                }
                
                if ($null -eq $deviceInfo -or ($deviceInfo.Count -eq 0) -or ($deviceInfo -eq ''))
                {
                    $isDeleted = $true
                    Write-Host "Device deletion confirmed!" -ForegroundColor Green
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device $autoPilotDeviceId deletion confirmed at attempt $retryCount" -LogLevel "Information"
                    Write-Verbose "[$functionName] Device deletion confirmed at attempt $retryCount."
                }
                else
                {
                    Write-Verbose "[$functionName] Device still exists after attempt $retryCount. Waiting for $RetryDelaySeconds seconds before next check."
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Still exists after attempt $retryCount" -LogLevel "Verbose"
                }
            }
            
            if ($isDeleted)
            {
                Write-Verbose "[$functionName] Autopilot device with serial number $($autopilotDevice.serialNumber) deleted successfully."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Delete operation succeeded for $autoPilotDeviceId" -LogLevel "Information"
                $success = $true
            }
            else
            {
                Write-Host "Device deletion verification timed out after $MaxRetries attempts." -ForegroundColor Red
                Write-Verbose "[$functionName] Delete operation may have been queued but not completed within the monitoring period."
                Write-Warning "Device may still be in the process of being deleted. Please check again later."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Timeout waiting for deletion of $autoPilotDeviceId after $MaxRetries attempts" -LogLevel "Warning"
                $success = $false
            }
        }
        else
        {
            Write-Verbose "[$functionName] Failed to delete autopilot device with serial number $($autopilotDevice.serialNumber)."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Delete response not empty (failure) for $autoPilotDeviceId" -LogLevel "Error"
        }
    }
    else
    {
        Write-Host "No autopilot device found with $IdentifyerType $DeviceIdentifyer."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No device found to delete ($IdentifyerType=$DeviceIdentifyer)" -LogLevel "Warning"
    }
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning success=$success for delete operation ($DeviceIdentifyer)" -LogLevel "Information"
    return $success
}


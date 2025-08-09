function ExportDeviceStorage()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [string]$OutputFile,
        [Parameter(Mandatory = $false)]
        [string]$Filter = $null,
        [Parameter(Mandatory = $false)]
        [int]$BatchSize = 20,
        [Parameter(Mandatory = $false)]
        [switch]$IncludeStorageInfo
    )
    $functionName = $MyInvocation.MyCommand.Name
    $managedDeviceUri = "deviceManagement/managedDevices"
    $managedDeviceFilter = "operatingSystem eq 'Windows'"
    $success = $false
    if ($filter)
    {
        Write-Verbose "[$functionName] - Using filter: $filter"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Using filter: $filter" -LogLevel "Information"
        $managedDeviceFilter = $Filter
    }
    else 
    {
        Write-Verbose "[$functionName] - No filter provided, using default filter: $managedDeviceFilter"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "- No filter provided, using default filter: $managedDeviceFilter" -LogLevel "Information"
    }
    Write-Verbose "[$functionName] - Starting device memory export process"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Starting device memory export process" -LogLevel "Information"
    Write-Verbose "[$functionName] - Using batch size of $BatchSize for API requests"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Using batch size of $BatchSize for API requests" -LogLevel "Information"
    
    # Store all devices in an array
    $allDevices = [System.Collections.ArrayList]@()
    
    try
    {
        Write-Verbose "[$functionName] - Getting device list from Graph API"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Getting device list from Graph API" -LogLevel "Information"
        $deviceListResponse = CallGraphApi -ResourcePath $managedDeviceUri -accessToken $AccessToken -Filter $managedDeviceFilter -consistencyLevel -extraParameters "top=999"
        
        if ($null -eq $deviceListResponse -or $null -eq $deviceListResponse.value -or $deviceListResponse.value.count -eq 0)
        {
            Write-Host "No devices found." -ForegroundColor Red
            return $false
        }
        
        # Add all devices to our collection (pagination already handled by CallGraphApi)
        $deviceListResponse.value | ForEach-Object { $null = $allDevices.Add($_) }
        
        Write-Verbose "[$functionName] - Retrieved a total of $($allDevices.Count) devices"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Retrieved a total of $($allDevices.Count) devices" -LogLevel "Information"
        
        # Create CSV object to store the results
        $CSVObject = [System.Collections.ArrayList]@()
        
        # Process devices in batches to reduce API calls
        for ($batchIndex = 0; $batchIndex -lt $allDevices.Count; $batchIndex += $BatchSize)
        {
            $batch = $allDevices | Select-Object -Skip $batchIndex -First $BatchSize
            
            # Create batch request
            $batchRequestBody = @{
                requests = @()
            }
            
            foreach ($device in $batch)
            {
                $deviceId = $device.id
                if ($null -eq $deviceId)
                {
                    continue 
                }
                
                $batchRequestBody.requests += @{
                    id     = $deviceId
                    method = "GET"
                    url    = "/deviceManagement/managedDevices/$deviceId`?`$select=id,hardwareInformation,physicalMemoryInBytes,totalStorageSpaceInBytes,freeStorageSpaceInBytes"
                }
            }
            
            Write-Verbose "[$functionName] - Sending batch request for devices $batchIndex to $($batchIndex + $batch.Count)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Sending batch request for devices $batchIndex to $($batchIndex + $batch.Count)" -LogLevel "Information"
            $batchResponse = CallGraphApi -ResourcePath "`$batch" -accessToken $AccessToken -Method "POST" -Body ($batchRequestBody | ConvertTo-Json -Depth $maxJSONDepth)
            
            # Process batch responses
            if ($null -ne $batchResponse -and $null -ne $batchResponse.responses)
            {
                foreach ($response in $batchResponse.responses)
                {
                    if ($response.status -eq 200)
                    {
                        $deviceDetail = $response.body
                        $deviceBasic = $batch | Where-Object { $_.id -eq $response.id } | Select-Object -First 1
                        
                        if ($null -ne $deviceBasic)
                        {
                            $memoryGB = if ($deviceDetail.physicalMemoryInBytes)
                            {
                                [math]::Round($deviceDetail.physicalMemoryInBytes / 1GB, 2)
                            }
                            else
                            {
                                0 
                            }
                            
                            $totalStorageGB = if ($deviceDetail.totalStorageSpaceInBytes)
                            {
                                [math]::Round($deviceDetail.totalStorageSpaceInBytes / 1GB, 2)
                            }
                            else
                            {
                                0 
                            }
                            
                            $freeStorageGB = if ($deviceDetail.freeStorageSpaceInBytes)
                            {
                                [math]::Round($deviceDetail.freeStorageSpaceInBytes / 1GB, 2)
                            }
                            else
                            {
                                0 
                            }
                            
                            $usedStorageGB = if ($totalStorageGB -gt 0 -and $freeStorageGB -gt 0)
                            {
                                [math]::Round($totalStorageGB - $freeStorageGB, 2)
                            }
                            else
                            {
                                0 
                            }
                            
                            $usedStoragePercent = if ($totalStorageGB -gt 0)
                            {
                                [math]::Round(($usedStorageGB / $totalStorageGB) * 100, 2)
                            }
                            else
                            {
                                0 
                            }
                            
                            $osVersion = if ($deviceBasic.operatingSystem -match "Windows")
                            {
                                "$($deviceBasic.operatingSystem) $($deviceBasic.osVersion)"
                            }
                            else
                            {
                                $deviceBasic.operatingSystem 
                            }
                            
                            # Create export object with expanded properties
                            $exportObject = [PSCustomObject]@{
                                DeviceId              = $deviceBasic.id
                                SerialNumber          = $deviceBasic.serialNumber
                                DeviceName            = $deviceBasic.deviceName
                                Manufacturer          = $deviceBasic.manufacturer
                                Model                 = $deviceBasic.model
                                SystemFamily          = $deviceBasic.systemFamily
                                UserPrincipalName     = $deviceBasic.userPrincipalName
                                UserDisplayName       = $deviceBasic.userDisplayName
                                OperatingSystem       = $osVersion
                                LastSyncDateTime      = $deviceBasic.lastSyncDateTime
                                MemoryGB              = $memoryGB
                                TotalStorageGB        = $totalStorageGB
                                FreeStorageGB         = $freeStorageGB
                                UsedStorageGB         = $usedStorageGB
                                UsedStoragePercent    = $usedStoragePercent
                                EnrollmentProfileName = $deviceBasic.enrollmentProfileName
                                JoinType              = $deviceBasic.joinType
                                ComplianceState       = $deviceBasic.complianceState
                            }
                            
                            Write-Verbose "[$functionName] - Processed device: $($deviceBasic.deviceName) (Memory: $memoryGB GB, Storage: $totalStorageGB GB)"
                            Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Processed device: $($deviceBasic.deviceName) (Memory: $memoryGB GB, Storage: $totalStorageGB GB)" -LogLevel "Information"
                            $null = $CSVObject.Add($exportObject)
                        }
                    }
                    else
                    {
                        Write-Verbose "[$functionName] - Failed to get details for device ID $($response.id). Status: $($response.status)"
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Failed to get details for device ID $($response.id). Status: $($response.status)" -LogLevel "Error"
                    }
                }
            }
            
            # Add a slight delay to prevent throttling
            Start-Sleep -Milliseconds 900
        }
        
        # Export results to CSV
        if ($CSVObject.Count -gt 0)
        {
            Write-Verbose "[$functionName] - Exporting data for $($CSVObject.Count) devices to file $OutputFile"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Exporting data for $($CSVObject.Count) devices to file $OutputFile" -LogLevel "Information"
            $CSVObject | Export-Csv -Path $OutputFile -NoTypeInformation -Force
            Write-Host "Successfully exported device information to $OutputFile" -ForegroundColor Green
            Write-Host "Exported $($CSVObject.Count) devices with memory and storage information" -ForegroundColor Green
            $success = $true
        }
        else
        {
            Write-Host "No device information was collected to export" -ForegroundColor Yellow
            $success = $false
        }
    }
    catch
    {
        Write-Host "Error processing device information: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose "Exception detail: $($_.Exception | Format-List -Force | Out-String)"
        $success = $false
    }
    return $success
}

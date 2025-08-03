function ExportDeviceReport()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$formattedOutput,
        [Parameter(Mandatory = $false)]
        [string]$outputFile,
        [Parameter(Mandatory = $false)]
        [ValidateSet("HTML", "CSV")]
        [string]$ExportFormat = "HTML"
    )

    $functionName = "ExportDeviceReport"
    Write-Verbose "[$functionName] Starting export with parameters: output file='$outputFile', ExportFormat='$ExportFormat'"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Starting export with parameters: output file='$outputFile', ExportFormat='$ExportFormat'" -LogLevel "Information"
    # Validate ExportFormat
    if ($ExportFormat -notin @("HTML", "CSV"))
    {
        Write-Error "[$functionName] Invalid ExportFormat specified: $ExportFormat. Valid options are 'HTML' or 'CSV'."
        return $false
    }
    
    # Determine device name for file naming
    if (-not $outputFile -or $null -eq $outputFile)
    {
        if (-not $DeviceName)
        {
            $DeviceName = "Device"
            Write-Verbose "[$functionName] Using default device name for export"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Using default device name for export" -LogLevel "Information"
        }
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $fileName = "$DeviceName`_Report_$timestamp"
        Write-Verbose "[$functionName] Generated filename: $fileName"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Generated filename: $fileName" -LogLevel "Information"
    }
    else
    {
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($outputFile)
        Write-Verbose "[$functionName] Using provided output file name: $fileName"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Using provided output file name: $fileName" -LogLevel "Information"
    }
    
    # Determine final export format
    $finalExportFormat = $ExportFormat.ToUpper()
    if ($finalExportFormat -eq "HTML")
    {
        $htmlPath = "$pwd\$fileName.html"
        Write-Verbose "[$functionName] Exporting to HTML: $htmlPath"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Exporting to HTML: $htmlPath" -LogLevel "Information"
        $htmlHeader = @"
<!DOCTYPE html>
<html>
<head>
    <title>Device Report: $DeviceName</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { text-align: left; padding: 8px; border-bottom: 1px solid #ddd; }
        th { background-color: #f2f2f2; }
        tr:hover { background-color: #f5f5f5; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        h1 { color: #333; }
        .meta { color: #666; font-style: italic; margin-bottom: 20px; }
    </style>
</head>
<body>
    <h1>Device Report: $DeviceName</h1>
    <div class="meta">Generated on $(Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K")</div>
    <table>
        <thead>
            <tr>
                <th>Property</th>
                <th>Value</th>
            </tr>
        </thead>
        <tbody>
"@
        $htmlRows = ""
        foreach ($key in $formattedOutput.Keys)
        {
            $value = [System.Web.HttpUtility]::HtmlEncode($formattedOutput[$key])
            $htmlRows += "            <tr><td>$([System.Web.HttpUtility]::HtmlEncode($key))</td><td>$value</td></tr>`n"
        }
        $htmlFooter = @"
        </tbody>
    </table>
</body>
</html>
"@
        try
        {
            $htmlContent = $htmlHeader + $htmlRows + $htmlFooter
            $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8
            Write-Host "HTML report exported to: $htmlPath" -ForegroundColor Green
            Write-Verbose "[$functionName] Successfully exported HTML report to $htmlPath"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Successfully exported HTML report to $htmlPath" -LogLevel "Information"
        }
        catch
        {
            Write-Error "[$functionName] Failed to export HTML report: $($_.Exception.Message)"
            Write-Verbose "[$functionName] HTML export error details: $($_.Exception)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "HTML export error details: $($_.Exception)" -LogLevel "Error"
            return $false
        }
    }
    elseif ($finalExportFormat -eq "CSV")
    {
        $csvPath = "$pwd\$fileName.csv"
        Write-Verbose "[$functionName] Exporting to CSV: $csvPath"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Exporting to CSV: $csvPath" -LogLevel "Information"
        try
        {
            $csvData = foreach ($key in $formattedOutput.Keys)
            {
                [PSCustomObject]@{
                    Property = $key
                    Value    = $formattedOutput[$key]
                }
            }
            $csvData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
            Write-Host "CSV report exported to: $csvPath" -ForegroundColor Green
            Write-Verbose "[$functionName] Successfully exported CSV report to $csvPath"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Successfully exported CSV report to $csvPath" -LogLevel "Information"
        }
        catch
        {
            Write-Error "[$functionName] Failed to export CSV report: $($_.Exception.Message)"
            Write-Verbose "[$functionName] CSV export error details: $($_.Exception)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "CSV export error details: $($_.Exception)" -LogLevel "Error"
            return $false
        }
    }
    else
    {
        Write-Error "[$functionName] Unsupported export format: $finalExportFormat"
        return $false
    }
    Write-Verbose "[$functionName] Export completed successfully."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Export completed successfully." -LogLevel "Information"
    return $true
}

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
            $batchResponse = CallGraphApi -ResourcePath "`$batch" -accessToken $AccessToken -Method "POST" -Body ($batchRequestBody | ConvertTo-Json -Depth 10)
            
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

function ExportDeviceList()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [string]$outputPath,
        [Parameter(Mandatory = $true)]
        [ValidateSet('autopilot', 'imported', 'unmanaged', 'managed')]
        [string]$deviceType,
        [ValidateSet('Append', 'Overwrite')]
        [string]$fileMode = 'overwrite'
    )

    #region Define variables.
    $functionName = $MyInvocation.MyCommand
    $currentDateTime = (Get-Date -Format "yyyyMMdd-HHmmss")
    $outputFile = "$outputPath\$deviceType-DeviceList-$currentDateTime.csv"
    $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
    # $autopilotExtraParameters = "select=serialNumber,groupTag,manufacturer,model,systemFamily,enrollmentState,deploymentProfileAssignmentStatus"
    $importedAutopilotDeviceURI = "deviceManagement/importedWindowsAutopilotDeviceIdentities"
    $importedAutopilotExtraParameters = "select=serialNumber,importId,groupTag,state"
    $unmanagedDeviceUri = "devices"
    $unmanagedDeviceFilter = "operatingSystem eq 'Windows'"
    $unmanagedDeviceExtraParameters = "select=id,displayName,manufacturer,model,operatingSystemVersion,profileType,createdDateTime,registrationDateTime,accountEnabled,approximateLastSignInDateTime,enrollmentProfileName,enrollmentType,isCompliant"
    $managedDeviceUri = "deviceManagement/managedDevices"
    $managedDeviceFilter = "operatingSystem eq Windows"
    $managedDeviceExtraParameters = "select=serialNumber,deviceName,manufacturer,model,osVersion,autopilotEnrolled,enrolledDateTime,lastSyncDateTime,complianceState,userPrincipalName,userDisplayName,usersLoggedOn"
    $CSVObject = [System.Collections.ArrayList]@()
    $success = $false
    #endregion

    #region Prepare export object
    switch ($deviceType )
    {
        'autopilot'
        {
            Write-Verbose "[$functionName] fetching Autopilot devices."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "fetching Autopilot devices." -LogLevel "Information"
            $devices = CallGraphApi -ResourcePath $autoPilotDeviceURI -accessToken $accessToken
            Write-Verbose "[$functionName] Fetched $($devices.value.Count) Autopilot devices."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Fetched $($devices.value.Count) Autopilot devices." -LogLevel "Information"
        }
        'imported'
        {
            Write-Verbose "[$functionName] fetching Imported Autopilot devices."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "fetching Imported Autopilot devices." -LogLevel "Information"
            $devices = CallGraphApi -ResourcePath $importedAutopilotDeviceURI -accessToken $accessToken -extraParameters $importedAutopilotExtraParameters
            Write-Verbose "[$functionName] Fetched $($devices.value.Count) imported Autopilot devices."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Fetched $($devices.value.Count) imported Autopilot devices." -LogLevel "Information"
        }
        'unmanaged'
        {
            Write-Verbose "[$functionName] fetching Unmanaged devices."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "fetching Unmanaged devices." -LogLevel "Information"
            $devices = CallGraphApi -ResourcePath $unmanagedDeviceUri -accessToken $accessToken -filter $unmanagedDeviceFilter -extraParameters $unmanagedDeviceExtraParameters
            Write-Verbose "[$functionName] Fetched $($devices.value.Count) unmanaged devices."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Fetched $($devices.value.Count) unmanaged devices." -LogLevel "Information"
        }
        'managed'
        {
            Write-Verbose "[$functionName] fetching Managed devices."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "fetching Managed devices." -LogLevel "Information"
            $devices = CallGraphApi -ResourcePath $managedDeviceUri -accessToken $accessToken -filter $managedDeviceFilter -extraParameters $managedDeviceExtraParameters
            Write-Verbose "[$functionName] Fetched $($devices.value.Count) managed devices."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Fetched $($devices.value.Count) managed devices." -LogLevel "Information"
        }
    }
    
    Write-Verbose "[$functionName] Processing $($devices.value.Count) $deviceType devices for export."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Processing $($devices.value.Count) $deviceType devices for export." -LogLevel "Verbose"
    for ($i = 0; $i -lt $devices.value.count; $i++)
    {
        $device = $devices.value[$i]
        if (-not $device)
        {
            Write-Verbose "[$functionName] Skipping null or invalid $deviceType device at index $i."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Skipping null or invalid $deviceType device at index $i." -LogLevel "Error"
            continue
        }
        switch ($deviceType)
        {
            'autopilot'
            {
                Write-Verbose "[$functionName] Preparing $deviceType device with serial number $($device.serialNumber) for export."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Preparing $deviceType device with serial number $($device.serialNumber) for export." -LogLevel "Information"
                if ($null -ne $device.lastContactedDateTime)
                {
                    $lastContactedDateTime = $device.lastContactedDateTime | FormatDateWithTimeZone
                }
                $exportObject = [PSCustomObject] @{
                    serialNumber                      = $device.serialNumber
                    groupTag                          = $device.groupTag
                    manufacturer                      = $device.manufacturer
                    model                             = $device.model
                    systemFamily                      = $device.systemFamily
                    enrollmentState                   = $device.enrollmentState
                    deploymentProfileAssignmentStatus = $device.deploymentProfileAssignmentStatus
                    lastContactedDateTime             = $lastContactedDateTime
                }
            }
            'imported'
            {
                Write-Verbose "[$functionName] Preparing $deviceType device with serial number $($device.serialNumber) for export."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Preparing $deviceType device with serial number $($device.serialNumber) for export." -LogLevel "Information"
                $exportObject = [PSCustomObject] @{
                    serialNumber         = $device.serialNumber
                    importId             = $device.importId
                    groupTag             = $device.groupTag
                    importStatus         = $device.state.deviceImportStatus
                    deviceRegistrationId = $device.state.deviceRegistrationId
                    deviceErrorCode      = $device.state.deviceErrorCode
                    deviceErrorName      = $device.state.deviceErrorName
                }
            }
            'unmanaged'
            {
                Write-Verbose "[$functionName] Preparing $devicetype device with display name $($device.displayName) for export."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Preparing $devicetype device with display name $($device.displayName) for export." -LogLevel "Information"
                $createdDateTime = $device.createdDateTime
                $registrationDateTime = $device.registrationDateTime
                $approximateLastSignInDateTime = $device.approximateLastSignInDateTime
                if ($null -ne $device.createdDateTime)
                {
                    $createdDateTime = $device.createdDateTime | FormatDateWithTimeZone
                }
                if ($null -ne $device.registrationDateTime)
                {
                    $registrationDateTime = $device.registrationDateTime | FormatDateWithTimeZone
                }
                if ($null -ne $device.approximateLastSignInDateTime)
                {
                    $approximateLastSignInDateTime = $device.approximateLastSignInDateTime | FormatDateWithTimeZone
                }
                $exportObject = [PSCustomObject] @{
                    id                            = $device.id
                    displayName                   = $device.displayName
                    manufacturer                  = $device.manufacturer
                    model                         = $device.model
                    operatingSystemVersion        = $device.operatingSystemVersion
                    profileType                   = $device.profileType
                    createdDateTime               = $createdDateTime
                    registrationDateTime          = $registrationDateTime
                    accountEnabled                = $device.accountEnabled
                    approximateLastSignInDateTime = $approximateLastSignInDateTime
                    enrollmentProfileName         = $device.enrollmentProfileName
                    enrollmentType                = $device.enrollmentType
                    isCompliant                   = $device.isCompliant
                }
            }
            'managed'
            {
                Write-Verbose "[$functionName] Preparing $devicetype device object for export."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Preparing $devicetype device object for export." -LogLevel "Information"
                $enrollmentDate = $device.enrolledDateTime
                $LastSync = $device.lastSyncDateTime
                $lastLoggedOn = $device.usersLoggedOn.lastLogOnDateTime
                if ($null -ne $device.enrolledDateTime)
                {
                    $enrollmentDate = $device.enrolledDateTime | FormatDateWithTimeZone
                }
                if ($null -ne $device.lastSyncDateTime)
                {
                    $LastSync = $device.lastSyncDateTime | FormatDateWithTimeZone
                }
                if ($null -ne $device.usersLoggedOn.lastLogOnDateTime)
                {
                    $lastLoggedOn = $device.usersLoggedOn.lastLogOnDateTime | FormatDateWithTimeZone
                }
                $exportObject = [PSCustomObject] @{
                    serialNumber      = $device.serialNumber
                    deviceName        = $device.deviceName
                    manufacturer      = $device.manufacturer
                    model             = $device.model
                    WindowsVersion    = $device.osVersion
                    autopilotEnrolled = $device.autopilotEnrolled
                    enrollmentDate    = $enrollmentDate
                    LastSync          = $LastSync
                    complianceState   = $device.complianceState
                    userPrincipalName = $device.userPrincipalName
                    userDisplayName   = $device.userDisplayName
                    lastLoggedOn      = $lastLoggedOn
                }
            }
        }
        $CSVObject.Add($exportObject) | Out-Null
    }
    #endregion    

    if ($CSVObject.Count -gt 0)
    {
        Write-Verbose "[$functionName] exporting $($CSVObject.Count) $deviceType devices to $outputFile."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "exporting $($CSVObject.Count) $deviceType devices to $outputFile." -LogLevel "Information"
        #Check if the file exists and ask if the user wants to overwrite.
        if (Test-Path $outputFile)
        {
            if ($fileMode -eq 'Append')
            {
                Write-Verbose "[$functionName] Appending to existing file $outputFile."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Appending to existing file $outputFile." -LogLevel "Information"
                $CSVObject | Export-Csv -Path $outputFile -NoTypeInformation -Append -Encoding UTF8 -Delimiter ','
            }
            else
            {
                Write-Verbose "[$functionName] Overwriting existing file $outputFile."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Overwriting existing file $outputFile." -LogLevel "Information"
                $CSVObject | Export-Csv -Path $outputFile -NoTypeInformation -Force -Encoding UTF8 -Delimiter ','
            }
        }
        else
        {
            Write-Verbose "[$functionName] Creating new file $outputFile."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Creating new file $outputFile." -LogLevel "Information"
        }
        $CSVObject | Export-Csv -Path $outputFile -NoTypeInformation -Force -Encoding UTF8 -Delimiter ','
    }
    else
    {
        Write-Verbose "[$functionName] No devices found for export."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No devices found for export." -LogLevel "Information"
    }
    #check if the csv file exists.
    if (Test-Path $outputFile)
    {
        Write-Verbose "[$functionName] CSV file $outputFile created successfully."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "CSV file $outputFile created successfully." -LogLevel "Information"
        $success = $true
    }
    else
    {
        Write-Verbose "[$functionName] Failed to create CSV file $outputFile."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Failed to create CSV file $outputFile." -LogLevel "Error"
        $success = $false
    }
    return $success, $outputFile
}

function ConvertUserDisplayName()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserDisplayName
    )
    $functionName = $MyInvocation.MyCommand.Name
    $processedUser = [ordered] @{}
    # Convert "Lastname, Firstname Middle (nickname)" to "Firstname Middle Lastname (nickname)" if nickname exists,
    # otherwise to "Firstname Middle Lastname"
    # Also handles "Lastname, Firstname M." format where M. is a middle initial
    Write-Verbose "[$functionName] Converting user display name: $UserDisplayName"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Converting user display name: $UserDisplayName" -LogLevel "Verbose"
    if ($UserDisplayName -match '^(.*), (.*?)(?:\s([A-Z]\.?))?(?: \((.*?)\))?$')
    {
        Write-Verbose "[$functionName] Extracting first name, last name, middle initial and nickname."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Extracting first name, last name, middle initial and nickname." -LogLevel "Information"
        $lastName = $matches[1].Trim()
        Write-Verbose "[$functionName] Last name: $lastName"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Last name: $lastName" -LogLevel "Information"
        $firstName = $matches[2].Trim()
        Write-Verbose "[$functionName] First name: $firstName"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "First name: $firstName" -LogLevel "Information"
        $middleInitial = if ($matches[3])
        {
            $matches[3].Trim() 
            Write-Verbose "[$functionName] Middle initial: $middleInitial"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Middle initial: $middleInitial" -LogLevel "Information"
        }
        else
        {
            $null 
            Write-Verbose "[$functionName] No middle initial found."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No middle initial found." -LogLevel "Information"
        }
        $nickname = $matches[4]
        Write-Verbose "[$functionName] Nickname: $nickname"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Nickname: $nickname" -LogLevel "Information"
        $fullName = if ($middleInitial)
        {
            "$firstName $middleInitial $lastName"
            Write-Verbose "[$functionName] Full name with middle initial: $fullName"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Full name with middle initial: $fullName" -LogLevel "Information"
        }
        else
        {
            "$firstName $lastName"
            Write-Verbose "[$functionName] Full name without middle initial: $fullName"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Full name without middle initial: $fullName" -LogLevel "Information"
        }
        if ($nickname)
        {
            Write-Verbose "[$functionName] Nickname found: $nickname"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Nickname found: $nickname" -LogLevel "Information"
            $currentUser = "$fullName ($nickname)"
            Write-Verbose "[$functionName] Current user with nickname: $currentUser"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Current user with nickname: $currentUser" -LogLevel "Information"
        }
        else
        {
            Write-Verbose "[$functionName] No nickname found."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No nickname found." -LogLevel "Information"
            $currentUser = $fullName
            Write-Verbose "[$functionName] Current user without nickname: $currentUser"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Current user without nickname: $currentUser" -LogLevel "Information"
        }
    }
    else
    {
        Write-Verbose "[$functionName] No match found for user display name format."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No match found for user display name format." -LogLevel "Information"
        Write-Verbose "[$functionName] Returning original display name."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning original display name." -LogLevel "Information"
        $currentUser = $UserDisplayName
    }
    #Add what we got the the processedUser hashtable
    $processedUser.Add('FullName', $currentUser)
    $processedUser.Add('FirstName', $firstName)
    $processedUser.Add('LastName', $lastName)
    $processedUser.Add('MiddleInitial', $middleInitial)
    $processedUser.Add('Nickname', $nickname)
    return $processedUser
}

function GetManagedDeviceRelevantProperties()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $enrollmentState,
        $settings = $settings
    )
    $functionName = $MyInvocation.MyCommand.Name
    $managedDeviceProperties = [ordered] @{}
    if ($null -eq $settings.MinimumDevicePhysicalMemoryInGB -or $settings.MinimumDevicePhysicalMemoryInGB -eq 0)
    {
        Write-Verbose "[$functionName] No minimum device physical memory specified in settings."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No minimum device physical memory specified in settings." -LogLevel "Information"
        Write-Verbose "[$functionName] Setting default value to 16GB."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Setting default value to 16GB." -LogLevel "Information"
        $MinimumDevicePhysicalMemoryInGB = 16
    }
    else
    {
        $MinimumDevicePhysicalMemoryInGB = $settings.MinimumDevicePhysicalMemoryInGB
        Write-Verbose "[$functionName] Minimum device physical memory specified in settings: $MinimumDevicePhysicalMemoryInGB"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Minimum device physical memory specified in settings: $MinimumDevicePhysicalMemoryInGB" -LogLevel "Information"
    }
    Write-Host "Checking managed device..."
    Write-Verbose "[$functionName] Managed device: $($enrollmentState.managed)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Managed device: $($enrollmentState.managed)" -LogLevel "Information"
    if ($enrollmentState.managed)
    {
        Write-Verbose "[$functionName] Found a managed device."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found a managed device." -LogLevel "Information"
        Write-Verbose "[$functionName] Checking whether this is an orphan device..."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking whether this is an orphan device..." -LogLevel "Verbose"
        Write-Verbose "[$functionName] Autopilot managed device id: $($enrollmentState.autopilot.device.managedDeviceId)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Autopilot managed device id: $($enrollmentState.autopilot.device.managedDeviceId)" -LogLevel "Information"
        Write-Verbose "[$functionName] Managed device id: $($enrollmentState.managedDevice.device.id)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Managed device id: $($enrollmentState.managedDevice.device.id)" -LogLevel "Information"
        Write-Verbose "[$functionName] Checking if they are the same..."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking if they are the same..." -LogLevel "Verbose"
        if ($enrollmentState.managedDevice.device.id -eq $enrollmentState.autopilot.device.managedDeviceId)
        {
            Write-Verbose "[$functionName] Device Id's match."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device Id's match." -LogLevel "Information"
            Write-Host "The device is not an orphan device."
            $orphanDevice = $false
            Write-Host "Checking whether the device has enough RAM..."
            if ($enrollmentState.managedDevice.memory -ge $MinimumDevicePhysicalMemoryInGB)
            {
                Write-Host "The device has $($enrollmentState.managedDevice.memory)GB of ram, which meets the $($settings.MinimumDevicePhysicalMemoryInGB)GB desired requirement."
                $correctRam = $true
            }
            else
            {
                Write-Host "The device has only $($enrollmentState.managedDevice.memory)GB of RAM, which is below the $($settings.MinimumDevicePhysicalMemoryInGB)GB desired requirement."
                Write-Host "Contact Hardware and Logistics."
                $correctRam = $false
            }   
            Write-Host "Checking for a user association on the manage device..."
            if ($enrollmentState.managedDevice.device.userId -ne '' -and $null -ne $enrollmentState.managedDevice.device.userId)
            {
                Write-Verbose "[$functionName] Found a user..."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found a user..." -LogLevel "Information"
                Write-Verbose "[$functionName] User display name: $($enrollmentState.managedDevice.users.userDisplayName)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "User display name: $($enrollmentState.managedDevice.users.userDisplayName)" -LogLevel "Information"
                Write-Verbose "[$functionName] User id: $($enrollmentState.managedDevice.device.userId)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "User id: $($enrollmentState.managedDevice.device.userId)" -LogLevel "Information"
                Write-Verbose "[$functionName] User principal name: $($enrollmentState.managedDevice.users.userPrincipalName)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "User principal name: $($enrollmentState.managedDevice.users.userPrincipalName)" -LogLevel "Information"
                $hasUser = $true
                if ($enrollmentState.managedDevice.users.azureUser)
                {
                    $validUser = $true
                    $normalizedUsername = ConvertUserDisplayName -UserDisplayName $enrollmentState.managedDevice.users.userDisplayName
                    Write-Host "This device is registered to $($normalizedUsername.FullName) ($($enrollmentState.managedDevice.users.userPrincipalName))"
                    if ($null -ne $enrollmentState.managedDevice.users.lastLogOnDateTime)
                    {
                        $lastLogonDate = $enrollmentState.managedDevice.users.lastLogonDateTime | FormatDateWithTimeZone
                        Write-Host "$($enrollmentState.managedDevice.users.user.givenName) last logged on on $lastLogonDate."
                    }
                    else
                    {
                        $lastLogonDate = $null
                        Write-Host "Cannot determine the last time $($normalizedUsername.FirstName) logged on..."
                    }
                }
                else 
                {
                    Write-Host "The device appears to be associated with an SPN or a user that no longer exists in Azure AD."
                    Write-Host "It is advisable to remove the managed device from Intune prior to having the user enroll the device."
                    $validUser = $false
                }
            }
            else
            {
                Write-Verbose "[$functionName] The managed device is not associated with a user."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "The managed device is not associated with a user." -LogLevel "Information"
                Write-Host "The device is not associated with a user."
                $hasUser = $false
            }
        }
        else
        {
            $orphanDevice = $true
            Write-Verbose "[$functionName] Device Id's do not match."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device Id's do not match." -LogLevel "Information"
            Write-Verbose "[$functionName] The device is an orphan device."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device is an orphan device." -LogLevel "Information"
        }
    }

    if ($OrphanDevice -eq $false -and $CorrectRam -and -not ($HasUser -and $ValidUser))
    {
        $readyForNextUser = $true
        Write-Verbose "[$functionName] Device is ready for the next user"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device is ready for the next user" -LogLevel "Information"
    }
    else
    {
        $readyForNextUser = $false
        Write-Verbose "[$functionName] Device is not ready for the next user"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device is not ready for the next user" -LogLevel "Information"
    }
    $managedDeviceProperties.Add('OrphanDevice', $orphanDevice)
    $managedDeviceProperties.Add('CorrectRam', $correctRam)
    $managedDeviceProperties.Add('HasUser', $hasUser)
    $managedDeviceProperties.Add('ValidUser', $validUser)
    $managedDeviceProperties.Add('LastLogonDate', $lastLogonDate)
    $managedDeviceProperties.Add('ReadyForNextUser', $readyForNextUser)
    return $managedDeviceProperties
}

function GetAutopilotDeviceRelevantProperties()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $enrollmentState,
        $settings = $settings
    )
    $functionName = $MyInvocation.MyCommand.Name
    $autopilotDeviceProperties = [ordered] @{}
    if ($null -eq $settings.DesiredAutopilotProfiles -or $settings.DesiredAutopilotProfiles.Count -eq 0)
    {
        Write-Verbose "[$functionName] No desired autopilot profiles specified in settings."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No desired autopilot profiles specified in settings." -LogLevel "Information"
        Write-Verbose "[$functionName] Setting default value to 'None'."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Setting default value to 'None'." -LogLevel "Information"
        $desiredAutopilotProfiles = $null
    }
    else
    {
        $desiredAutopilotProfiles = $settings.DesiredAutopilotProfiles
        Write-Verbose "[$functionName] Desired autopilot profiles specified in settings: $desiredAutopilotProfiles"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Desired autopilot profiles specified in settings: $desiredAutopilotProfiles" -LogLevel "Information"
    }
    if ($null -ne $enrollmentState.autopilot.device.deploymentProfileAssignmentStatus -and $enrollmentState.autopilot.device.deploymentProfileAssignmentStatus -in @('assignedUnkownSyncState', 'assignedInSync'))
    {
        Write-Verbose "[$functionName] The device profile assignment state is valid: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device profile assignment state is valid: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)." -LogLevel "Information"
        $profileAssigned = $true
    }
    else
    {
        Write-Verbose "[$functionName] The device profile assignment state is not valid: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device profile assignment state is not valid: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)." -LogLevel "Information"
        $profileAssigned = $false
    }
    if ($null -ne $desiredAutopilotProfiles -and $enrollmentState.autopilot.device.deploymentProfile.displayName -in $desiredAutopilotProfiles -and $profileAssigned -eq $true)
    {
        Write-Host "The device is assigned to the correct autopilot profile."
        $correctProfile = $true
    }
    else
    {
        Write-Verbose "[$functionName] The device is not assigned to the correct autopilot profile."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device is not assigned to the correct autopilot profile." -LogLevel "Information"
        $correctProfile = $false
    }
    Write-Host "Autopilot profile Deployment status: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)."
    Write-Host "Assigned profile name: $($enrollmentState.autopilot.device.deploymentProfile.displayname)"
    Write-Host "Assignment date: $($enrollmentState.autopilot.device.deploymentProfileAssignedDateTime |FormatDateWithTimeZone)"
    #Check remediation state.
    $lastRemediationDate = $enrollmentState.autopilot.device.remediationStateLastModifiedDateTime | FormatDateWithTimeZone
    if ($null -ne $enrollmentState.autopilot.device.remediationState -and $enrollmentState.autopilot.device.remediationState -in @('noRemediationRequired', 'unknownFutureValue'))
    {
        Write-Verbose "[$functionName] The device profile remediation state is valid: $($enrollmentState.autopilot.device.remediationState)."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device profile remediation state is valid: $($enrollmentState.autopilot.device.remediationState)." -LogLevel "Information"
        $remediationStateGood = $true
        Write-Verbose "[$functionName] Remediation state last modified date: $lastRemediationDate"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Remediation state last modified date: $lastRemediationDate" -LogLevel "Information"
    }
    else
    {
        Write-Verbose "[$functionName] The device profile remediation state is not valid: $($enrollmentState.autopilot.device.remediationState)."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device profile remediation state is not valid: $($enrollmentState.autopilot.device.remediationState)." -LogLevel "Information"
        $remediationStateGood = $false
    }
    Write-Host "Remediation state: $($enrollmentState.autopilot.device.remediationState)"
    Write-Host "Remediation state last modified date: $lastRemediationDate"
    #Now check enrollment status.
    if ($null -ne $enrollmentState.autopilot.device.enrollmentState -and $enrollmentState.autopilot.device.enrollmentState -in @('enrolled', 'notContacted'))
    {
        Write-Verbose "[$functionName] The device enrollment state is valid: $($enrollmentState.autopilot.device.enrollmentState)."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device enrollment state is valid: $($enrollmentState.autopilot.device.enrollmentState)." -LogLevel "Information"
        #Check the last enrollment status.
        if ($enrollmentState.autopilot.events.count -gt 0)
        {
            $lastEnrollmentEvent = $enrollmentState.autopilot.events[-1]
            Write-Host "Checking the last autopilot event..."
            if ($lastEnrollmentEvent.deploymentState -ne 'success' -or $lastEnrollmentEvent.deviceSetupStatus -ne 'success')
            {
                Write-Host "There are issues with the device's enrollment:"
                Write-Host "Deployment start date: $($lastEnrollmentEvent.deploymentStartDateTime | FormatDateWithTimeZone)"
                Write-Host "Deployment end date: $($lastEnrollmentEvent.deploymentEndDateTime | FormatDateWithTimeZone)"
                Write-Host "Deployment state: $($lastEnrollmentEvent.deploymentState)"
                Write-Host "Device setup status: $($lastEnrollmentEvent.deviceSetupStatus)"
                Write-Host "Enrollment failure details: $($lastEnrollmentEvent.enrollmentFailureDetails)"
                $enrollmentStateGood = $false
            }
            else
            {
                Write-Host "The device enrollment state is good."
                Write-Host "Deployment start date: $($lastEnrollmentEvent.deploymentStartDateTime | FormatDateWithTimeZone)"
                Write-Host "Deployment end date: $($lastEnrollmentEvent.deploymentEndDateTime | FormatDateWithTimeZone)"
                Write-Host "Deployment state: $($lastEnrollmentEvent.deploymentState)"
                Write-Host "Device setup status: $($lastEnrollmentEvent.deviceSetupStatus)"
                $enrollmentStateGood = $true
            }
        }
        else
        {
            Write-Host "No enrollment events found for this device."
            Write-Host "The device enrollment state is good."
            $enrollmentStateGood = $true
        }
    }
    else
    {
        Write-Verbose "[$functionName] The device enrollment state is not valid: $($enrollmentState.autopilot.device.enrollmentState)."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device enrollment state is not valid: $($enrollmentState.autopilot.device.enrollmentState)." -LogLevel "Information"
        $enrollmentStateGood = $false
    }
    Write-Host "Enrollment state: $($enrollmentState.autopilot.device.enrollmentState)"
    if ($CorrectProfile -and $ProfileAssigned -and $RemediationStateGood -and $EnrollmentStateGood)
    {
        Write-Verbose "[$functionName] Autopilot assignment is good..."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Autopilot assignment is good..." -LogLevel "Information"
        $AutopilotAssignmentGood = $true
    }
    else
    {
        Write-Verbose "[$functionName] There are issues with this device's autopilot assignment."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "There are issues with this device's autopilot assignment." -LogLevel "Information"
        $AutopilotAssignmentGood = $false
        
    }
    Write-Verbose "[$functionName] Autopilot assignment good: $AutopilotAssignmentGood"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Autopilot assignment good: $AutopilotAssignmentGood" -LogLevel "Information"
    #Add what we got the the autopilotDeviceProperties hashtable
    $autopilotDeviceProperties.Add('CorrectProfile', $correctProfile)
    $autopilotDeviceProperties.Add('ProfileAssigned', $profileAssigned)
    $autopilotDeviceProperties.Add('RemediationStateGood', $remediationStateGood)
    $autopilotDeviceProperties.Add('EnrollmentStateGood', $enrollmentStateGood)
    $autopilotDeviceProperties.Add('AutopilotAssignmentGood', $AutopilotAssignmentGood)
    return $autopilotDeviceProperties
}

function AssessDeviceState() 
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $enrollmentState,
        $settings = $settings,
        [Parameter(Mandatory = $true)]
        [ValidateSet('PropperEnrollmentVerification', 'NextUserReadiness', 'TroubleShooting')]
        [string]$AssessmentType
    )
    $functionName = $MyInvocation.MyCommand.Name
    #region Write verbose log of received parameters.
    Write-Verbose "[$functionName] Received parameters:"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Received parameters:" -LogLevel "Information"
    Write-Verbose "[$functionName] Enrollment state: $($enrollmentState | ConvertTo-Json -Depth 10)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Enrollment state: $($enrollmentState | ConvertTo-Json -Depth 10)" -LogLevel "Information"
    Write-Verbose "[$functionName] Assessment type: $AssessmentType"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Assessment type: $AssessmentType" -LogLevel "Information"
    Write-Verbose "[$functionName] Settings: $($settings | ConvertTo-Json -Depth 10)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Settings: $($settings | ConvertTo-Json -Depth 10)" -LogLevel "Information"
    $returnValue = [ordered] @{}
    $readinessState = $null
    $action = $null
    $device = $null
    #endregion

    Write-Verbose "[$functionName] Type of assessment: $AssessmentType"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Type of assessment: $AssessmentType" -LogLevel "Information"
    switch ($AssessmentType)
    {
        'PropperEnrollmentVerification'
        {
            Write-Host "Place holder text..."
            Write-Host "Checking if the device is properly enrolled..."
        }
        'NextUserReadiness'
        {
            Write-Host "Checking if the device is ready for the next user..."
            Write-Verbose "[$functionName] Checking if the device is registered in Autopilot..."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking if the device is registered in Autopilot..." -LogLevel "Verbose"
            Write-Verbose "[$functionName] In Autopilot: $($enrollmentState.inAutopilot)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "In Autopilot: $($enrollmentState.inAutopilot)" -LogLevel "Information"
            if ($enrollmentState.inAutopilot)
            {
                $autopilotReadiness = GetAutopilotDeviceRelevantProperties -enrollmentState $enrollmentState
                if (-not ($enrollmentState.autopilot.device.enrollmentState -eq 'notContacted'))
                {   
                    Write-Verbose "[$functionName] Getting managed device properties."
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Getting managed device properties." -LogLevel "Information"
                    $managedDeviceReadiness = GetManagedDeviceRelevantProperties -enrollmentState $enrollmentState
                    $memoryMessage = "`n"
                }
                else 
                {
                    Write-Verbose "[$functionName] Device enrollment state is 'notContacted', skipping managed device readiness check."
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device enrollment state is 'notContacted', skipping managed device readiness check." -LogLevel "Information"
                    $memoryMessage = "We could not determine whether the device has the required $($settings.MinimumDevicePhysicalMemoryInGB ) GB of RAM. `n Please manually verify that the device has $($settings.MinimumDevicePhysicalMemoryInGB ) GB of RAM before proceeding."
                }
                $deviceLastContactDate = GetLastDeviceContactDate -accessToken $accessToken -enrollmentState $enrollmentState
                if ($deviceLastContactDate.withinThreshold)
                {
                    Write-Host "The device last contacted Intune on $($deviceLastContactDate.latestContactDate | FormatDateWithTimeZone), $($deviceLastContactDate.numberOfDaysSinceLastContact) days ago."
                    Write-Verbose "[$functionName] Device last contact date: $($deviceLastContactDate.latestContactDate | FormatDateWithTimeZone)"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device last contact date: $($deviceLastContactDate.latestContactDate | FormatDateWithTimeZone)" -LogLevel "Information"
                }
                else
                {
                    Write-Host "The device has not contacted Intune in $($deviceLastContactDate.numberOfDaysSinceLastContact) days. Last contact date: $($deviceLastContactDate.lastContactDate | FormatDateWithTimeZone)."
                    Write-Host "Please check the device's network connectivity and ensure it can reach Intune."
                }
                Write-Verbose "Autopilot assignment good: $($autopilotReadiness.AutopilotAssignmentGood)"
                Write-Verbose "Managed device readiness good: $($managedDeviceReadiness.ReadyForNextUser)"
                Write-Host "Within threshhold: $($deviceLastContactDate.withinThreshhold)"
                Write-Host "Within threshold: $($deviceLastContactDate.withinThreshold)"
                if (($autopilotReadiness.AutopilotAssignmentGood -and $managedDeviceReadiness.ReadyForNextUser) -or ($autopilotReadiness.AutopilotAssignmentGood -and $enrollmentState.autopilot.device.enrollmentState -eq 'notContacted' -and $enrollmentState.managed -eq $false) -and $deviceLastContactDate.withinThreshold)
                {
                    Write-Host "The device is ready for the next user."
                    Write-Host $memoryMessage
                    $readinessState = $deviceStates.ready 
                    $action = $deviceActions.none
                    $device = $enrollmentState.managedDevice.device.id
                }
                else
                {
                    Write-Host "The device is not ready for the next user."
                    Write-Host "See below for more information."
                    #let us explain to the user what the problem is.
                    if ($autopilotReadiness.CorrectProfile -eq $false)
                    {
                        Write-Host "The device is not assigned to the correct autopilot profile."
                        $readinessState = $deviceStates.notReady
                        $action = $deviceActions.contactAdmin
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    if ($autopilotReadiness.ProfileAssigned -eq $false)
                    {
                        Write-Host "The device is not assigned to an autopilot profile."
                        $readinessState = $deviceStates.notReady
                        $action = $deviceActions.contactAdmin
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    if ($autopilotReadiness.RemediationStateGood -eq $false)
                    {
                        Write-Host "The device has a remediation state that is not valid."
                        $readinessState = $deviceStates.notReady
                        $action = $deviceActions.contactAdmin
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    if ($autopilotReadiness.EnrollmentStateGood -eq $false)
                    {
                        Write-Host "The device failed enrollment."
                        $readinessState = $deviceStates.notReady
                        $action = $deviceActions.contactAdmin
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    if ($managedDeviceReadiness.OrphanDevice -eq $true)
                    {
                        Write-Host "The device is an orphan device."
                        $readinessState = $deviceStates.notReady
                        $action = $deviceActions.contactAdmin
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    if ($managedDeviceReadiness.CorrectRam -eq $false)
                    {
                        Write-Host "The device has only $($enrollmentState.managedDevice.memory)GB of RAM, which is below the $($settings.MinimumDevicePhysicalMemoryInGB)GB desired requirement."
                        Write-Host "Contact Hardware and Logistics."
                        $readinessState = $deviceStates.notReady
                        $action = $deviceActions.contactAdmin
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    if ($managedDeviceReadiness.HasUser)
                    {
                        Write-Host "The managed device is associated with a user."
                        Write-Host "It is advisable to remove the managed device from Intune prior to having the user enroll the device."
                        $readinessState = $deviceStates.notReady
                        $action = $deviceActions.WipeOrClean
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    if ($managedDeviceReadiness.ValidUser -eq $false)
                    {
                        Write-Host "The device appears to be associated with an SPN or a user that no longer exists in Azure AD."
                        Write-Host "It is advisable to remove the managed device from Intune prior to having the user enroll the device."
                        $readinessState = $deviceStates.notReady
                        $action = $deviceActions.WipeOrClean
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    if ($deviceLastContactDate.withinThreshold -eq $false)
                    {
                        Write-Host "The device has not contacted Intune in $($deviceLastContactDate.numberOfDaysSinceLastContact) days."
                        Write-Host "Please check the device's network connectivity and ensure it can reach Intune."
                        $readinessState = $deviceStates.notReady
                        $action = $deviceActions.connectToNetwork
                        $device = $enrollmentState.managedDevice.device.id
                    }
                }
            }
            else
            {
                Write-Host "The device is not registered in Autopilot."
                Write-Host "You may want to contact an Intune admin."
                $readinessState = $deviceStates.notReady
                $action = $deviceActions.contactAdmin
                $device = $enrollmentState.managedDevice.device.id
            }
        }
        'TroubleShooting'
        {
            Write-Host "Place holder text..."
            Write-Host "Troubleshooting the device..."
        }
    }        
    $returnValue.Add('ReadinessState', $readinessState)
    $returnValue.Add('Action', $action)
    $returnValue.Add('Device', $device)
    Write-Verbose "[$functionName] Returning readiness state: $readinessState"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning readiness state: $readinessState" -LogLevel "Information"
    Write-Verbose "[$functionName] Returning action: $action"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning action: $action" -LogLevel "Information"
    Write-Verbose "[$functionName] Returning device: $device"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning device: $device" -LogLevel "Information"
    return $returnValue
}

function ShowDeviceReport()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'EnrollmentState')]
        $enrollmentState,
        [Parameter(Mandatory = $true, ParameterSetName = 'HashTable')]
        [hashtable]$report,
        [Parameter(Mandatory = $false)]
        [string[]]$PrefixList = @('Intune', 'Autopilot'),
        [string]$DeviceName,
        [Parameter(Mandatory = $false)]
        [string]$SerialNumber
    )
    #region usage info
    # Use with enrollment state (original ShowDeviceReport functionality)
    #ShowDeviceReport -enrollmentState $enrollmentState -SerialNumber $serialNumber
    # Use with hashtable (original DisplayReport functionality)
    #Show-DeviceReport -report $myHashtable -PrefixList @('Custom', 'Prefix')
    # Direct export without prompting
    #Show-DeviceReport -enrollmentState $state -Export -ExportFormat "CSV"   
    #endregion usage info
    $functionName = $MyInvocation.MyCommand.Name
    #region write verbose log of received parameters
    Write-Verbose "[$functionName] Starting device report generation"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Starting device report generation" -LogLevel "Information"
    Write-Verbose "[$functionName] Parameter Set: $($PSCmdlet.ParameterSetName)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Parameter Set: $($PSCmdlet.ParameterSetName)" -LogLevel "Information"
    Write-Verbose "[$functionName] Export: $Export"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Export: $Export" -LogLevel "Information"
    Write-Verbose "[$functionName] ExportFormat: $ExportFormat"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "ExportFormat: $ExportFormat" -LogLevel "Information"
    Write-Verbose "[$functionName] OutputFile: $OutputFile"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "OutputFile: $OutputFile" -LogLevel "Information"
    Write-Verbose "[$functionName] PrefixList: $($PrefixList -join ', ')"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "PrefixList: $($PrefixList -join ', ')" -LogLevel "Information"
    if ($PSCmdlet.ParameterSetName -eq 'EnrollmentState')
    {
        Write-Verbose "[$functionName] Enrollment state provided"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Enrollment state provided" -LogLevel "Information"
    }
    else
    {
        Write-Verbose "[$functionName] Report hashtable provided with $($report.Keys.Count) properties"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Report hashtable provided with $($report.Keys.Count) properties" -LogLevel "Information"
    }
    Write-Verbose "[$functionName] DeviceName: $DeviceName"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "DeviceName: $DeviceName" -LogLevel "Information"
    Write-Verbose "[$functionName] SerialNumber: $SerialNumber"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "SerialNumber: $SerialNumber" -LogLevel "Information"
    #endregion write verbose log of received parameters
    #region Build report data
    $output = [ordered]@{}
    
    if ($PSCmdlet.ParameterSetName -eq 'EnrollmentState')
    {
        Write-Verbose "[$functionName] Building report from enrollment state"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Building report from enrollment state" -LogLevel "Information"
        
        # Get latest autopilot event
        if ($enrollmentState.autopilot.events -and $enrollmentState.autopilot.events.Count -gt 0)
        {
            $latestAutopilotEvent = $enrollmentState.autopilot.events | Select-Object -First 1
            Write-Verbose "[$functionName] Found $($enrollmentState.autopilot.events.Count) autopilot events"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found $($enrollmentState.autopilot.events.Count) autopilot events" -LogLevel "Information"
        }
        else
        {
            $latestAutopilotEvent = $null
            Write-Verbose "[$functionName] No autopilot events found"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No autopilot events found" -LogLevel "Information"
        }
        
        $output = [ordered] @{
            InputIdentifier               = $SerialNumber
            IntuneDeviceName              = $enrollmentState.managedDevice.device.deviceName
            IntuneSerialNumber            = $enrollmentState.managedDevice.device.serialNumber
            IntuneDeviceMemory            = "$($enrollmentState.managedDevice.memory) GB"
            IntuneManagedDeviceId         = $enrollmentState.managedDevice.device.Id
            IntuneEnrollmentDate          = if ($enrollmentState.managedDevice.device.enrolledDateTime)
            {
                $enrollmentState.managedDevice.device.enrolledDateTime | FormatDateWithTimeZone 
            }
            else
            {
                $null 
            }
            IntuneLastSync                = if ($enrollmentState.managedDevice.device.lastSyncDateTime)
            {
                $enrollmentState.managedDevice.device.lastSyncDateTime | FormatDateWithTimeZone 
            }
            else
            {
                $null 
            }
            IntuneEnrollmentProfile       = $enrollmentState.managedDevice.device.enrollmentProfileName
            IntunePrimaryUPN              = $enrollmentState.managedDevice.device.userPrincipalName
            IntuneAzureUser               = $enrollmentState.managedDevice.users.AzureUser
            IntuneUserDisplayName         = $enrollmentState.managedDevice.users.userDisplayName
            IntuneReportedUserDisplayName = $enrollmentState.managedDevice.device.userDisplayName
            IntuneLastLogon               = if ($enrollmentState.managedDevice.users.lastLogOnDateTime)
            {
                $enrollmentState.managedDevice.users.lastLogOnDateTime | FormatDateWithTimeZone 
            }
            else
            {
                $null 
            }
            IntuneActionResults           = $enrollmentState.managedDevice.device.deviceActionResults
            IntuneCertExpiration          = if ($enrollmentState.managedDevice.device.managementCertificateExpirationDate)
            {
                $enrollmentState.managedDevice.device.managementCertificateExpirationDate | FormatDateWithTimeZone 
            }
            else
            {
                $null 
            }
            IntuneComplianceExpiry        = if ($enrollmentState.managedDevice.device.complianceGracePeriodExpirationDateTime)
            {
                $enrollmentState.managedDevice.device.complianceGracePeriodExpirationDateTime | FormatDateWithTimeZone 
            }
            else
            {
                $null 
            }
            IntuneAutopilotEnrolled       = $enrollmentState.managedDevice.device.autopilotEnrolled
            IntuneRegistrationState       = $enrollmentState.managedDevice.device.deviceRegistrationState
            IntuneIsEncrypted             = $enrollmentState.managedDevice.device.isEncrypted
            IntuneEnrollmentType          = $enrollmentState.managedDevice.device.deviceEnrollmentType
            IntunesVersion                = $enrollmentState.managedDevice.device.sVersion
            IntuneComplianceState         = $enrollmentState.managedDevice.device.complianceState
            IntuneManagementState         = $enrollmentState.managedDevice.device.managementState
            IntuneOwnerType               = $enrollmentState.managedDevice.device.managedDeviceOwnerType
            AutopilotDeviceId             = $enrollmentState.autopilot.device.id
            AutopilotState                = $enrollmentState.autopilot.device.enrollmentState
            AutopilotProfileAssigned      = $enrollmentState.autopilot.device.deploymentProfileAssignmentStatus
            AutopilotProfileAssignedDate  = if ($enrollmentState.autopilot.device.deploymentProfileAssignedDateTime)
            {
                $enrollmentState.autopilot.device.deploymentProfileAssignedDateTime | FormatDateWithTimeZone 
            }
            else
            {
                $null 
            }
            AutopilotProfileName          = $enrollmentState.autopilot.device.deploymentProfile.displayName
            AutopilotAssignedUser         = $enrollmentState.autopilot.device.userPrincipalName
            AutopilotLastContacted        = if ($enrollmentState.autopilot.device.lastContactedDateTime)
            {
                $enrollmentState.autopilot.device.lastContactedDateTime | FormatDateWithTimeZone 
            }
            else
            {
                $null 
            }
            AutopilotLatestEventTime      = if ($latestAutopilotEvent -and $latestAutopilotEvent.eventDateTime)
            {
                $latestAutopilotEvent.eventDateTime | FormatDateWithTimeZone 
            }
            else
            {
                $null 
            }
            AutopilotLatestProfile        = $latestAutopilotEvent.windowsAutopilotDeploymentProfileDisplayName
            AutopilotLatestStatus         = $latestAutopilotEvent.deploymentState
            AutopilotLatestError          = $latestAutopilotEvent.enrollmentFailureDetails
        }
        
        # Set device name for export if not provided
        if (-not $DeviceName)
        {
            $DeviceName = $enrollmentState.managedDevice.device.deviceName
        }
    }
    else
    {
        Write-Verbose "[$functionName] Using provided report hashtable"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Using provided report hashtable" -LogLevel "Information"
        $output = $report
    }
    #endregion Build report data
    
    #region Format property names and display report
    Write-Verbose "[$functionName] Formatting output for display"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Formatting output for display" -LogLevel "Information"
    $formattedOutput = [System.Collections.Specialized.OrderedDictionary]::new()
    
    foreach ($key in $output.Keys)
    {
        Write-Verbose "[$functionName] Processing property: $key"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Processing property: $key" -LogLevel "Verbose"
        
        # Format the property name to be more readable
        $readableKey = $key
        $matchedPrefix = $null
        
        # Check for prefix matches
        foreach ($prefix in $PrefixList)
        {
            if ($key -match "^($prefix)(.+)$")
            {
                $matchedPrefix = $prefix
                Write-Verbose "[$functionName] Found prefix '$prefix' for key '$key'"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found prefix '$prefix' for key '$key'" -LogLevel "Information"
                break
            }
        }
        
        if ($matchedPrefix)
        {
            $prefix = $matches[1]
            $remainder = $matches[2]
            # Insert spaces before capital letters in the remainder
            $formattedRemainder = [regex]::Replace($remainder, '(?<=[a-z])(?=[A-Z])', ' ')
            $readableKey = "$prefix $formattedRemainder"
        }
        else
        {
            # Insert spaces before capital letters
            $readableKey = [regex]::Replace($key, '(?<=[a-z])(?=[A-Z])', ' ')
        }
        
        # Format the value based on type
        $formattedValue = $output[$key]
        if ($output[$key] -is [DateTime])
        {
            Write-Verbose "[$functionName] Formatting DateTime value for key '$key'"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Formatting DateTime value for key '$key'" -LogLevel "Information"
            $formattedValue = FormatDateWithTimeZone -DateTime $output[$key]
        }
        elseif ($null -eq $output[$key])
        {
            $formattedValue = "N/A"
        }
        
        $formattedOutput[$readableKey] = $formattedValue
        
        # Display each property and value
        Write-Host "$readableKey`: $formattedValue"
    }
    Write-Verbose "[$functionName] Formatted $($formattedOutput.Keys.Count) properties for display"    #endregion Format property names and display report
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Formatted $($formattedOutput.Keys.Count) properties for display"    #endregion Format property names and display report" -LogLevel "Information"
    #endregion Display report
    
    #region Handle export decision
    $HTMLAction = {
        Write-Verbose "[$functionName] User selected HTML export"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "User selected HTML export" -LogLevel "Information"
        $exportResult = ExportDeviceReport -formattedOutput $formattedOutput -ExportFormat "HTML"
        if ($exportResult)
        {
            Write-Host "Report exported to HTML successfully."
        }
        else
        {
            Write-Host "Failed to export report to HTML."
        }
        return $exportResult 
    } 
    $CSVAction = {
        Write-Verbose "[$functionName] User selected CSV export"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "User selected CSV export" -LogLevel "Information"
        $exportResult = ExportDeviceReport -formattedOutput $formattedOutput -ExportFormat "CSV"
        if ($exportResult)
        {
            Write-Host "Report exported to CSV successfully."
        }
        else
        {
            Write-Host "Failed to export report to CSV."
        }
        return $exportResult 
    } 
    Write-Verbose "[$functionName] Prompting user for export decision"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Prompting user for export decision" -LogLevel "Information"
    $exportMenu = NewMenu -Title "Export report" -Description "Select the format to which you would like to export the report"
    $exportMenu = AddMenuItem -Menu $exportMenu -Name "Export to HTML" -Action $HTMLAction -ReturnsValue
    $exportMenu = AddMenuItem -Menu $exportMenu -Name "Export to CSV" -Action $CSVAction -ReturnsValue
    $selection = ShowMenu -Menu $exportMenu -CalledBy 'Action'

    if ($null -ne $selection )
    {
        Write-Verbose "[$functionName] ShowMenu returned: '$selection' (Type: $($selection.GetType().Name))"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "ShowMenu returned: '$selection' (Type: $($selection.GetType().Name))" -LogLevel "Information"
        # Validate that we got a proper selection, not a navigation option
        if ($selection -eq "Back" -or $selection -eq "Main Menu" -or $selection -eq 0 -or $selection -eq "0")
        {
            Write-Verbose "[$functionName] ShowMenu returned navigation option: '$selection', treating as navigation"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "ShowMenu returned navigation option: '$selection', treating as navigation" -LogLevel "Information"
            return $selection
        }
    }
    else
    {
        Write-Verbose "[$functionName] No export selected. Exiting."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No export selected. Exiting." -LogLevel "Information"
        return $null
    }
    #endregion Handle export decision
    Write-Verbose "[$functionName] Device report generation completed"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device report generation completed" -LogLevel "Information"
    return $true
}

function GetNextUserReadinessReport()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $enrollmentState
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Host "`nChecking next user readiness state for: $deviceName ($SerialNumber)" -ForegroundColor Yellow
    $DeviceAssessmentState = AssessDeviceState -enrollmentState $enrollmentState -AssessmentType 'NextUserReadiness'
    Write-Verbose "[$functionName] Device assessment state: $DeviceAssessmentState"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device assessment state: $DeviceAssessmentState" -LogLevel "Information"
    if ($DeviceAssessmentState.ReadinessState -eq $deviceStates.ready)
    {
        Write-Host $DeviceAssessmentState.ready
        Write-Host $DeviceAssessmentState.action
        return $DeviceAssessmentState
    }
    elseif ($DeviceAssessmentState.ReadinessState -eq $deviceStates.notReady)
    {
        Write-Host $deviceStates.notReady
        Write-Host $DeviceAssessmentState.action
        switch ($DeviceAssessmentState.Action)
        {
            $deviceActions.contactAdmin
            {
                Write-Host "Please contact your Intune administrator for assistance." -ForegroundColor Red
            }
            $deviceActions.WipeOrClean
            {
                Write-Host "You may need to wipe or clean the device before it can be used by the next user." -ForegroundColor Red
            }
            $deviceActions.none
            {
                Write-Host "No action required at this time." -ForegroundColor Green
            }
        }
        return $DeviceAssessmentState
    }
    else
    {
        Write-Host "An unexpected readiness state was encountered: $($DeviceAssessmentState.ReadinessState)" -ForegroundColor Red
        return $null
    }
}

function getDevicePendingActions()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $enrollmentState
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    $returnObject = @{}
    $deviceActions = @('wipePending')
    $pendingActions = [PSCustomObject]@{}
    $isPendingAction = $false
    Write-Verbose "[$functionName] Checking for pending actions on the device..."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking for pending actions on the device..." -LogLevel "Verbose"
    Write-Verbose "[$functionName] Device management state: $($enrollmentState.managedDevice.device.managementState)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device management state: $($enrollmentState.managedDevice.device.managementState)" -LogLevel "Information"
    if ($enrollmentState.managedDevice.device.managementState -in $deviceActions)
    {
        Write-Verbose "[$functionName] The device has pending actions."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device has pending actions." -LogLevel "Information"
        $isPendingAction = $true
        Write-Verbose "Action name $($enrollmentState.managedDevice.device.managementState)"
        Write-Verbose "Action status $($enrollmentState.managedDevice.device.managementState)"
        $pendingActions = [PSCustomObject]@{
            ActionName   = $enrollmentState.managedDevice.device.managementState
            ActionStatus = $enrollmentState.managedDevice.device.managementState
        }
    }
    else
    {
        Write-Verbose "[$functionName] The device has no pending actions."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device has no pending actions." -LogLevel "Information"
        Write-Verbose "[$functionName] Device management state: $($enrollmentState.managedDevice.device.managementState)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device management state: $($enrollmentState.managedDevice.device.managementState)" -LogLevel "Information"
        $isPendingAction = $false
    }

    if ($enrollmentState.managedDevice.device.deviceActionResults -and $enrollmentState.managedDevice.device.deviceActionResults.Count -gt 0)
    {
        Write-Host "$($enrollmentState.managedDevice.device.deviceActionResults.Count ) Pending actions found for the device:"
        foreach ($action in $enrollmentState.managedDevice.device.deviceActionResults)
        {
            Write-Host "- $($action.actionName): $($action.status)"
            $isPendingAction = $true
            $pendingActions += [PSCustomObject]@{
                ActionName   = $action.actionName
                ActionStatus = $action.status
            }
        }
    }        
    Write-Verbose "[$functionName] Is pending action: $isPendingAction"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Is pending action: $isPendingAction" -LogLevel "Information"
    if ($isPendingAction -eq $true)
    {
        Write-Verbose "[$functionName] There are pending actions for the device."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "There are pending actions for the device." -LogLevel "Information"
        $returnObject.Add('PendingActions', $pendingActions)
        $returnObject.Add('IsPendingAction', $isPendingAction)
        return $returnObject
    }
    else
    {
        Write-Verbose "[$functionName] No pending actions found for the device."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No pending actions found for the device." -LogLevel "Information"
        $returnObject.Add('PendingActions', $null)
        $returnObject.Add('IsPendingAction', $isPendingAction)
        return $returnObject
    }
}

function GetLastDeviceContactDate()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$accessToken,
        [Parameter(Mandatory = $true)]
        $enrollmentState
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    $goodContactThreshhold = $settings.deviceContactThreshholdInDays
    $goodContactThreshold = $settings.deviceContactThresholdInDays
    $withinThreshold = $false
    Write-Verbose "[$functionName] Getting last device contact date."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Getting last device contact date." -LogLevel "Verbose"
    $contactDates = @{}
    if ($enrollmentState.managed)
    {
        Write-Verbose "[$functionName] Device is managed, retrieving contact dates."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device is managed, retrieving contact dates." -LogLevel "Information"
        $contactDates.add('managedDeviceLastSyncDateTime', $enrollmentState.managedDevice.lastSyncDateTime)
        $contactDates.add('managedDeviceUsersLastLogOnDateTime', $enrollmentState.managedDevice.Users.lastLogOnDateTime)
    }
    if ($enrollmentState.inAutopilot)
    {
        Write-Verbose "[$functionName] Device is in Autopilot, retrieving contact dates."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device is in Autopilot, retrieving contact dates." -LogLevel "Information"
        $contactDates.add('autopilotDeviceDeploymentProfileAssignedDateTime', $enrollmentState.autopilot.device.deploymentProfileAssignedDateTime)
        $contactDates.add('autopilotDeviceLastContactedDateTime', $enrollmentState.autopilot.device.lastContactedDateTime)
        $contactDates.add('autopilotDeviceRemediationStateLastModifiedDateTime', $enrollmentState.autopilot.device.remediationStateLastModifiedDateTime)
    }
    if ($enrollmentState.hasDeviceObject)
    {
        Write-Verbose "[$functionName] Device has device object, retrieving additional contact dates."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device has device object, retrieving additional contact dates." -LogLevel "Information"
        $contactDates.add('deviceApproximateLastSignInDateTime', $enrollmentState.device.approximateLastSignInDateTime)
        $contactDates.add('deviceCreatedDateTime', $enrollmentState.device.createdDateTime)
        $contactDates.add('deviceRegistrationDateTime', $enrollmentState.device.registrationDateTime)
    }
    #Figure out the latest contact date
    
    $latestContactDate = $contactDates.Values | Sort-Object -Descending | Select-Object -First 1
    Write-Verbose "[$functionName] Latest contact date: $latestContactDate"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Latest contact date: $latestContactDate" -LogLevel "Information"
    $contactDates.add('latestContactDate', $latestContactDate)
    $numberOfDaysSinceLastContact = (New-TimeSpan -Start $latestContactDate -End (Get-Date)).Days
    Write-Verbose "[$functionName] Number of days since last contact: $numberOfDaysSinceLastContact"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Number of days since last contact: $numberOfDaysSinceLastContact" -LogLevel "Information"
    $contactDates.add('numberOfDaysSinceLastContact', $numberOfDaysSinceLastContact)
    if ($numberOfDaysSinceLastContact -lt $goodContactThreshhold)
    {
        Write-Verbose "[$functionName] Device contact date is within the threshold of $goodContactThreshhold days."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device contact date is within the threshold of $goodContactThreshhold days." -LogLevel "Information"
        $withinThreshhold = $true
    }
    else
    {
        Write-Verbose "[$functionName] Device contact date is outside the threshold of $goodContactThreshhold days."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device contact date is outside the threshold of $goodContactThreshhold days." -LogLevel "Information"
    }
    if ($numberOfDaysSinceLastContact -lt $goodContactThreshold)
    {
        Write-Verbose "[$functionName] Device contact date is within the threshold of $goodContactThreshold days."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device contact date is within the threshold of $goodContactThreshold days." -LogLevel "Information"
        $withinThreshold = $true
    }
    else
    {
        Write-Verbose "[$functionName] Device contact date is outside the threshold of $goodContactThreshold days."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device contact date is outside the threshold of $goodContactThreshold days." -LogLevel "Information"
    }
    $contactDates.add('withinThreshold', $withinThreshold)
    Write-Verbose "[$functionName] Contact dates retrieved successfully."
    return $contactDates
}


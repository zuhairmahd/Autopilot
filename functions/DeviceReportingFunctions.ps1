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
        }
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $fileName = "$DeviceName`_Report_$timestamp"
        Write-Verbose "[$functionName] Generated filename: $fileName"
    }
    else
    {
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($outputFile)
        Write-Verbose "[$functionName] Using provided output file name: $fileName"
    }
    
    # Determine final export format
    $finalExportFormat = $ExportFormat.ToUpper()
    if ($finalExportFormat -eq "HTML")
    {
        $htmlPath = "$pwd\$fileName.html"
        Write-Verbose "[$functionName] Exporting to HTML: $htmlPath"
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
        }
        catch
        {
            Write-Error "[$functionName] Failed to export HTML report: $($_.Exception.Message)"
            Write-Verbose "[$functionName] HTML export error details: $($_.Exception)"
            return $false
        }
    }
    elseif ($finalExportFormat -eq "CSV")
    {
        $csvPath = "$pwd\$fileName.csv"
        Write-Verbose "[$functionName] Exporting to CSV: $csvPath"
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
        }
        catch
        {
            Write-Error "[$functionName] Failed to export CSV report: $($_.Exception.Message)"
            Write-Verbose "[$functionName] CSV export error details: $($_.Exception)"
            return $false
        }
    }
    else
    {
        Write-Error "[$functionName] Unsupported export format: $finalExportFormat"
        return $false
    }
    Write-Verbose "[$functionName] Export completed successfully."
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
        $managedDeviceFilter = $Filter
    }
    else 
    {
        Write-Verbose "[$functionName] - No filter provided, using default filter: $managedDeviceFilter"
    }
    Write-Verbose "[$functionName] - Starting device memory export process"
    Write-Verbose "[$functionName] - Using batch size of $BatchSize for API requests"
    
    # Store all devices in an array
    $allDevices = [System.Collections.ArrayList]@()
    
    try
    {
        Write-Verbose "[$functionName] - Getting device list from Graph API"
        $deviceListResponse = CallGraphApi -ResourcePath $managedDeviceUri -accessToken $AccessToken -Filter $managedDeviceFilter -consistencyLevel -extraParameters "top=999"
        
        if ($null -eq $deviceListResponse -or $null -eq $deviceListResponse.value -or $deviceListResponse.value.count -eq 0)
        {
            Write-Host "[$functionName] - No devices found. Exiting script." -ForegroundColor Red
            return $false
        }
        
        # Add all devices to our collection (pagination already handled by CallGraphApi)
        $deviceListResponse.value | ForEach-Object { $null = $allDevices.Add($_) }
        
        Write-Verbose "[$functionName] - Retrieved a total of $($allDevices.Count) devices"
        
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
                            $null = $CSVObject.Add($exportObject)
                        }
                    }
                    else
                    {
                        Write-Verbose "[$functionName] - Failed to get details for device ID $($response.id). Status: $($response.status)"
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
            $CSVObject | Export-Csv -Path $OutputFile -NoTypeInformation -Force
            Write-Host "[$functionName] - Successfully exported device information to $OutputFile" -ForegroundColor Green
            Write-Host "[$functionName] - Exported $($CSVObject.Count) devices with memory and storage information" -ForegroundColor Green
            $success = $true
        }
        else
        {
            Write-Host "[$functionName] - No device information was collected to export" -ForegroundColor Yellow
            $success = $false
        }
    }
    catch
    {
        Write-Host "[$functionName] - Error processing device information: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose "[$functionName] - Exception detail: $($_.Exception | Format-List -Force | Out-String)"
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
            $devices = CallGraphApi -ResourcePath $autoPilotDeviceURI -accessToken $accessToken
            Write-Verbose "[$functionName] Fetched $($devices.value.Count) Autopilot devices."
        }
        'imported'
        {
            Write-Verbose "[$functionName] fetching Imported Autopilot devices."
            $devices = CallGraphApi -ResourcePath $importedAutopilotDeviceURI -accessToken $accessToken -extraParameters $importedAutopilotExtraParameters
            Write-Verbose "[$functionName] Fetched $($devices.value.Count) imported Autopilot devices."
        }
        'unmanaged'
        {
            Write-Verbose "[$functionName] fetching Unmanaged devices."
            $devices = CallGraphApi -ResourcePath $unmanagedDeviceUri -accessToken $accessToken -filter $unmanagedDeviceFilter -extraParameters $unmanagedDeviceExtraParameters
            Write-Verbose "[$functionName] Fetched $($devices.value.Count) unmanaged devices."
        }
        'managed'
        {
            Write-Verbose "[$functionName] fetching Managed devices."
            $devices = CallGraphApi -ResourcePath $managedDeviceUri -accessToken $accessToken -filter $managedDeviceFilter -extraParameters $managedDeviceExtraParameters
            Write-Verbose "[$functionName] Fetched $($devices.value.Count) managed devices."
        }
    }
    
    Write-Verbose "[$functionName] Processing $($devices.value.Count) $deviceType devices for export."
    for ($i = 0; $i -lt $devices.value.count; $i++)
    {
        $device = $devices.value[$i]
        if (-not $device)
        {
            Write-Verbose "[$functionName] Skipping null or invalid $deviceType device at index $i."
            continue
        }
        switch ($deviceType)
        {
            'autopilot'
            {
                Write-Verbose "[$functionName] Preparing $deviceType device with serial number $($device.serialNumber) for export."
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
        #Check if the file exists and ask if the user wants to overwrite.
        if (Test-Path $outputFile)
        {
            if ($fileMode -eq 'Append')
            {
                Write-Verbose "[$functionName] Appending to existing file $outputFile."
                $CSVObject | Export-Csv -Path $outputFile -NoTypeInformation -Append -Encoding UTF8 -Delimiter ','
            }
            else
            {
                Write-Verbose "[$functionName] Overwriting existing file $outputFile."
                $CSVObject | Export-Csv -Path $outputFile -NoTypeInformation -Force -Encoding UTF8 -Delimiter ','
            }
        }
        else
        {
            Write-Verbose "[$functionName] Creating new file $outputFile."
        }
        $CSVObject | Export-Csv -Path $outputFile -NoTypeInformation -Force -Encoding UTF8 -Delimiter ','
    }
    else
    {
        Write-Verbose "[$functionName] No devices found for export."
    }
    #check if the csv file exists.
    if (Test-Path $outputFile)
    {
        Write-Verbose "[$functionName] CSV file $outputFile created successfully."
        $success = $true
    }
    else
    {
        Write-Verbose "[$functionName] Failed to create CSV file $outputFile."
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
    if ($UserDisplayName -match '^(.*), (.*?)(?:\s([A-Z]\.?))?(?: \((.*?)\))?$')
    {
        Write-Verbose "[$functionName] Extracting first name, last name, middle initial and nickname."
        $lastName = $matches[1].Trim()
        Write-Verbose "[$functionName] Last name: $lastName"
        $firstName = $matches[2].Trim()
        Write-Verbose "[$functionName] First name: $firstName"
        $middleInitial = if ($matches[3])
        {
            $matches[3].Trim() 
            Write-Verbose "[$functionName] Middle initial: $middleInitial"
        }
        else
        {
            $null 
            Write-Verbose "[$functionName] No middle initial found."
        }
        $nickname = $matches[4]
        Write-Verbose "[$functionName] Nickname: $nickname"
        $fullName = if ($middleInitial)
        {
            "$firstName $middleInitial $lastName"
            Write-Verbose "[$functionName] Full name with middle initial: $fullName"
        }
        else
        {
            "$firstName $lastName"
            Write-Verbose "[$functionName] Full name without middle initial: $fullName"
        }
        if ($nickname)
        {
            Write-Verbose "[$functionName] Nickname found: $nickname"
            $currentUser = "$fullName ($nickname)"
            Write-Verbose "[$functionName] Current user with nickname: $currentUser"
        }
        else
        {
            Write-Verbose "[$functionName] No nickname found."
            $currentUser = $fullName
            Write-Verbose "[$functionName] Current user without nickname: $currentUser"
        }
    }
    else
    {
        Write-Verbose "[$functionName] No match found for user display name format."
        Write-Verbose "[$functionName] Returning original display name."
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
        Write-Verbose "[$functionName] Setting default value to 16GB."
        $MinimumDevicePhysicalMemoryInGB = 16
    }
    else
    {
        $MinimumDevicePhysicalMemoryInGB = $settings.MinimumDevicePhysicalMemoryInGB
        Write-Verbose "[$functionName] Minimum device physical memory specified in settings: $MinimumDevicePhysicalMemoryInGB"
    }
    Write-Host "Checking managed device..."
    Write-Verbose "[$functionName] Managed device: $($enrollmentState.managed)"
    if ($enrollmentState.managed)
    {
        Write-Verbose "[$functionName] Found a managed device."
        Write-Verbose "[$functionName] Checking whether this is an orphan device..."
        Write-Verbose "[$functionName] Autopilot managed device id: $($enrollmentState.autopilot.device.managedDeviceId)"
        Write-Verbose "[$functionName] Managed device id: $($enrollmentState.managedDevice.device.id)"
        Write-Verbose "[$functionName] Checking if they are the same..."
        if ($enrollmentState.managedDevice.device.id -eq $enrollmentState.autopilot.device.managedDeviceId)
        {
            Write-Verbose "[$functionName] Device Id's match."
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
                Write-Verbose "[$functionName] User display name: $($enrollmentState.managedDevice.users.userDisplayName)"
                Write-Verbose "[$functionName] User id: $($enrollmentState.managedDevice.device.userId)"
                Write-Verbose "[$functionName] User principal name: $($enrollmentState.managedDevice.users.userPrincipalName)"
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
                $hasUser = $false
            }
        }
        else
        {
            $orphanDevice = $true
            Write-Verbose "[$functionName] Device Id's do not match."
            Write-Verbose "[$functionName] The device is an orphan device."
        }
    }

    if ($OrphanDevice -eq $false -and $CorrectRam -and -not ($HasUser -and $ValidUser))
    {
        $readyForNextUser = $true
        Write-Verbose "[$functionName] Device is ready for the next user"
    }
    else
    {
        $readyForNextUser = $false
        Write-Verbose "[$functionName] Device is not ready for the next user"
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
        Write-Verbose "[$functionName] Setting default value to 'None'."
        $desiredAutopilotProfiles = $null
    }
    else
    {
        $desiredAutopilotProfiles = $settings.DesiredAutopilotProfiles
        Write-Verbose "[$functionName] Desired autopilot profiles specified in settings: $desiredAutopilotProfiles"
    }
    if ($null -ne $enrollmentState.autopilot.device.deploymentProfileAssignmentStatus -and $enrollmentState.autopilot.device.deploymentProfileAssignmentStatus -in @('assignedUnkownSyncState', 'assignedInSync'))
    {
        Write-Verbose "[$functionName] The device profile assignment state is valid: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)."
        $profileAssigned = $true
    }
    else
    {
        Write-Verbose "[$functionName] The device profile assignment state is not valid: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)."
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
        $remediationStateGood = $true
        Write-Verbose "[$functionName] Remediation state last modified date: $lastRemediationDate"
    }
    else
    {
        Write-Verbose "[$functionName] The device profile remediation state is not valid: $($enrollmentState.autopilot.device.remediationState)."
        $remediationStateGood = $false
    }
    Write-Host "Remediation state: $($enrollmentState.autopilot.device.remediationState)"
    Write-Host "Remediation state last modified date: $lastRemediationDate"
    #Now check enrollment status.
    if ($null -ne $enrollmentState.autopilot.device.enrollmentState -and $enrollmentState.autopilot.device.enrollmentState -in @('enrolled', 'notContacted'))
    {
        Write-Verbose "[$functionName] The device enrollment state is valid: $($enrollmentState.autopilot.device.enrollmentState)."
        $enrollmentStateGood = $true
    }
    else
    {
        Write-Verbose "[$functionName] The device enrollment state is not valid: $($enrollmentState.autopilot.device.enrollmentState)."
        $enrollmentStateGood = $false
    }
    Write-Host "Enrollment state: $($enrollmentState.autopilot.device.enrollmentState)"
    if ($CorrectProfile -and $ProfileAssigned -and $RemediationStateGood -and $EnrollmentStateGood)
    {
        Write-Verbose "[$functionName] Autopilot assignment is good..."
        $AutopilotAssignmentGood = $true
    }
    else
    {
        Write-Verbose "[$functionName] There are issues with this device's autopilot assignment."
        $AutopilotAssignmentGood = $false
        
    }
    Write-Verbose "[$functionName] Autopilot assignment good: $AutopilotAssignmentGood"
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
    Write-Verbose "[$functionName] Enrollment state: $($enrollmentState | ConvertTo-Json -Depth 10)"
    Write-Verbose "[$functionName] Assessment type: $AssessmentType"
    Write-Verbose "[$functionName] Settings: $($settings | ConvertTo-Json -Depth 10)"
    $returnValue = [ordered] @{}
    $readinessState = $null
    $action = $null
    $device = $null
    #endregion

    Write-Verbose "[$functionName] Type of assessment: $AssessmentType"
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
            Write-Verbose "[$functionName] In Autopilot: $($enrollmentState.inAutopilot)"
            if ($enrollmentState.inAutopilot)
            {
                $autopilotReadiness = GetAutopilotDeviceRelevantProperties -enrollmentState $enrollmentState
                $managedDeviceReadiness = GetManagedDeviceRelevantProperties -enrollmentState $enrollmentState
                Write-Verbose "Autopilot assignment good: $($autopilotReadiness.AutopilotAssignmentGood)"
                Write-Verbose "Managed device readiness good: $($managedDeviceReadiness.ReadyForNextUser)"
                if ($autopilotReadiness.AutopilotAssignmentGood -and $managedDeviceReadiness.ReadyForNextUser)
                {
                    Write-Host "The device has $($enrollmentState.managedDevice.memory)GB of RAM, which meets the $($settings.MinimumDevicePhysicalMemoryInGB)GB desired requirement."
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
                    elseif ($autopilotReadiness.ProfileAssigned -eq $false)
                    {
                        Write-Host "The device is not assigned to an autopilot profile."
                        $readinessState = $deviceStates.notReady
                        $action = $deviceActions.contactAdmin
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    elseif ($autopilotReadiness.RemediationStateGood -eq $false)
                    {
                        Write-Host "The device has a remediation state that is not valid."
                        $readinessState = $deviceStates.notReady
                        $action = $deviceActions.contactAdmin
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    elseif ($autopilotReadiness.EnrollmentStateGood -eq $false)
                    {
                        Write-Host "The device has an enrollment state that is not valid."
                        $readinessState = $deviceStates.notReady
                        $action = $deviceActions.contactAdmin
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    elseif ($managedDeviceReadiness.OrphanDevice -eq $true)
                    {
                        Write-Host "The device is an orphan device."
                        $readinessState = $deviceStates.notReady
                        $action = $deviceActions.contactAdmin
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    elseif ($managedDeviceReadiness.CorrectRam -eq $false)
                    {
                        Write-Host "The device has only $($enrollmentState.managedDevice.memory)GB of RAM, which is below the $($settings.MinimumDevicePhysicalMemoryInGB)GB desired requirement."
                        Write-Host "Contact Hardware and Logistics."
                        $readinessState = $deviceStates.notReady
                        $action = $deviceActions.contactAdmin
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    elseif ($managedDeviceReadiness.HasUser)
                    {
                        Write-Host "The managed device is associated with a user."
                        Write-Host "It is advisable to remove the managed device from Intune prior to having the user enroll the device."
                        $readinessState = $deviceStates.notReady
                        $action = $deviceActions.WipeOrClean
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    elseif ($managedDeviceReadiness.ValidUser -eq $false)
                    {
                        Write-Host "The device appears to be associated with an SPN or a user that no longer exists in Azure AD."
                        Write-Host "It is advisable to remove the managed device from Intune prior to having the user enroll the device."
                        $readinessState = $deviceStates.notReady
                        $action = $deviceActions.WipeOrClean
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    else
                    {
                        Write-Host "The device is not ready for the next user."
                        $readinessState = $deviceStates.notReady
                        $action = $deviceActions.contactAdmin
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
    Write-Verbose "[$functionName] Returning action: $action"
    Write-Verbose "[$functionName] Returning device: $device"
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
    Write-Verbose "[$functionName] Parameter Set: $($PSCmdlet.ParameterSetName)"
    Write-Verbose "[$functionName] Export: $Export"
    Write-Verbose "[$functionName] ExportFormat: $ExportFormat"
    Write-Verbose "[$functionName] OutputFile: $OutputFile"
    Write-Verbose "[$functionName] PrefixList: $($PrefixList -join ', ')"
    if ($PSCmdlet.ParameterSetName -eq 'EnrollmentState')
    {
        Write-Verbose "[$functionName] Enrollment state provided"
    }
    else
    {
        Write-Verbose "[$functionName] Report hashtable provided with $($report.Keys.Count) properties"
    }
    Write-Verbose "[$functionName] DeviceName: $DeviceName"
    Write-Verbose "[$functionName] SerialNumber: $SerialNumber"
    #endregion write verbose log of received parameters
    #region Build report data
    $output = [ordered]@{}
    
    if ($PSCmdlet.ParameterSetName -eq 'EnrollmentState')
    {
        Write-Verbose "[$functionName] Building report from enrollment state"
        
        # Get latest autopilot event
        if ($enrollmentState.autopilot.events -and $enrollmentState.autopilot.events.Count -gt 0)
        {
            $latestAutopilotEvent = $enrollmentState.autopilot.events | Select-Object -First 1
            Write-Verbose "[$functionName] Found $($enrollmentState.autopilot.events.Count) autopilot events"
        }
        else
        {
            $latestAutopilotEvent = $null
            Write-Verbose "[$functionName] No autopilot events found"
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
        $output = $report
    }
    #endregion Build report data
    
    #region Format property names and display report
    Write-Verbose "[$functionName] Formatting output for display"
    $formattedOutput = [System.Collections.Specialized.OrderedDictionary]::new()
    
    foreach ($key in $output.Keys)
    {
        Write-Verbose "[$functionName] Processing property: $key"
        
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
    #endregion Display report
    
    #region Handle export decision
    $HTMLAction = {
        Write-Verbose "[$functionName] User selected HTML export"
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
    $exportMenu = NewMenu -Title "Export report" -Description "Select the format to which you would like to export the report"
    $exportMenu = AddMenuItem -Menu $exportMenu -Name "Export to HTML" -Action $HTMLAction -ReturnsValue
    $exportMenu = AddMenuItem -Menu $exportMenu -Name "Export to CSV" -Action $CSVAction -ReturnsValue
    $selection = ShowMenu -Menu $exportMenu -CalledBy 'Action'

    if ($null -ne $selection )
    {
        Write-Verbose "[$functionName] ShowMenu returned: '$selection' (Type: $($selection.GetType().Name))"
        # Validate that we got a proper selection, not a navigation option
        if ($selection -eq "Back" -or $selection -eq "Main Menu" -or $selection -eq 0 -or $selection -eq "0")
        {
            Write-Verbose "[$functionName] ShowMenu returned navigation option: '$selection', treating as navigation"
            return $selection
        }
    }
    else
    {
        Write-Verbose "[$functionName] No export selected. Exiting."
        return $null
    }
    #endregion Handle export decision
    Write-Verbose "[$functionName] Device report generation completed"
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
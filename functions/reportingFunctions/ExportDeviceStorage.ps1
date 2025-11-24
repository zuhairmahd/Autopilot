function ExportDeviceStorage()
{
    <#
    .SYNOPSIS
    Exports device storage information to CSV file.

    .DESCRIPTION
    This function retrieves storage details for managed devices and exports them to CSV format.
    Includes disk capacity, free space, and storage health metrics.

    .PARAMETER accessToken
    Microsoft Graph API access token. This parameter is mandatory.

    .PARAMETER outputPath
    Directory path for CSV export. This parameter is mandatory.

    .OUTPUTS
    System.String
    Returns path to exported storage report file.

    .EXAMPLE
    ExportDeviceStorage -accessToken $token -outputPath "C:\Reports"

    .NOTES
    Retrieves hardware storage information via Graph API.
    Exports disk capacity and availability metrics.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [string]$OutputFile,
        [Parameter(Mandatory = $false)]
        [string]$Filter = $null
    )
    $functionName = $MyInvocation.MyCommand.Name
    $managedDeviceUri = "deviceManagement/managedDevices"
    if ([string]::IsNullOrWhiteSpace($settings.deviceNamePrefix))
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "- No device name prefix set in settings, proceeding without prefix filter" -LogLevel "Information"            
        $managedDeviceFilter = "operatingSystem eq 'Windows'"
    }
    else 
    {
        write-Log -LogFile $LogFile -Module "$functionName" -Message "- Using device name prefix '$($settings.deviceNamePrefix)' from settings for filtering" -LogLevel "Information"
        # Escape single quotes in prefix for OData filter
        $escapedPrefix = $settings.deviceNamePrefix -replace "'", "''"
        $managedDeviceFilter = "operatingSystem eq 'Windows' and startswith(deviceName,'$escapedPrefix')"
    }
    
    $success = $false
    if ($filter)
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Using filter: $filter" -LogLevel "Information"
        $managedDeviceFilter = $Filter
    }
    else 
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "- No filter provided, using default filter: $managedDeviceFilter" -LogLevel "Information"
    }
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Starting device storage export process" -LogLevel "Verbose"
    
    # Store all devices in an array
    $allDevices = [System.Collections.ArrayList]@()
    
    try
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Getting device list from Graph API" -LogLevel "Information"
        $deviceListResponse = CallGraphApi -ResourcePath $managedDeviceUri -accessToken $AccessToken -Filter $managedDeviceFilter -consistencyLevel -extraParameters "top=999"
        if ($null -eq $deviceListResponse -or $null -eq $deviceListResponse.value -or $deviceListResponse.value.count -eq 0)
        {
            Write-Host "No devices found." -ForegroundColor Red
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "- No devices found with the specified filter." -LogLevel "Warning"                            
            return $false
        }
        
        # Add all devices to our collection (pagination already handled by CallGraphApi)
        $deviceListResponse.value | ForEach-Object { $null = $allDevices.Add($_) }
        
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Retrieved a total of $($allDevices.Count) devices" -LogLevel "Information"
        
        # Create CSV object to store the results
        $CSVObject = [System.Collections.ArrayList]@()
        
        # Build array of resource paths for batch processing
        $resourcePaths = @()
        foreach ($device in $allDevices)
        {
            if ($null -ne $device.id)
            {
                $resourcePaths += "deviceManagement/managedDevices/$($device.id)?`$select=id,serialNumber,deviceName,manufacturer,model,userPrincipalName,userDisplayName,operatingSystem,osVersion,lastSyncDateTime,physicalMemoryInBytes,totalStorageSpaceInBytes,freeStorageSpaceInBytes,joinType,complianceState"
            }   
        }
        
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Fetching detailed information for $($resourcePaths.Count) devices using native batching" -LogLevel "Information"
        
        # Use CallGraphAPI's native batching (handles up to 20 requests per batch automatically)
        $batchResponse = CallGraphApi -ResourcePath $resourcePaths -accessToken $AccessToken -Method "GET"
        
        # Process batch responses
        if ($null -ne $batchResponse -and $batchResponse.batchProcessed -eq $true)
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Successfully retrieved details for $($batchResponse.successCount) devices, failed: $($batchResponse.failureCount)" -LogLevel "Information"
            
            foreach ($deviceDetail in $batchResponse.value)
            {
                if ($null -ne $deviceDetail)
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
                    
                    $osVersion = if ($deviceDetail.operatingSystem -match "Windows")
                    {
                        "$($deviceDetail.operatingSystem) $($deviceDetail.osVersion)"
                    }
                    else
                    {
                        $deviceDetail.operatingSystem 
                    }
                    $userPrincipalName = if ($deviceDetail.userPrincipalName)
                    {
                        $deviceDetail.userPrincipalName
                    }
                    else
                    {
                        "Not assigned"
                    }               
                    
                    # Create export object with expanded properties
                    $exportObject = [PSCustomObject]@{
                        SerialNumber       = $deviceDetail.serialNumber
                        DeviceName         = $deviceDetail.deviceName
                        Manufacturer       = $deviceDetail.manufacturer
                        Model              = $deviceDetail.model
                        UserPrincipalName  = $userPrincipalName
                        UserDisplayName    = $deviceDetail.userDisplayName
                        OperatingSystem    = $osVersion
                        LastSyncDateTime   = $deviceDetail.lastSyncDateTime
                        MemoryGB           = $memoryGB
                        TotalStorageGB     = $totalStorageGB
                        FreeStorageGB      = $freeStorageGB
                        UsedStorageGB      = $usedStorageGB
                        UsedStoragePercent = "$usedStoragePercent%"
                        JoinType           = $deviceDetail.joinType
                        ComplianceState    = $deviceDetail.complianceState
                    }
                    
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Processed device: $($deviceDetail.deviceName) (Memory: $memoryGB GB, Storage: $totalStorageGB GB)" -LogLevel "Verbose"
                    $null = $CSVObject.Add($exportObject)
                }
            }
        }
        else
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Batch processing did not complete successfully" -LogLevel "Warning"
        }
        
        # Export results to CSV
        if ($CSVObject.Count -gt 0)
        {
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

function Get-RegisteredDevicesByUser()
{
    <#
    .SYNOPSIS
    Retrieves registered devices for specified users with optional filtering.

    .DESCRIPTION
    Queries Microsoft Graph API to get registered devices for a list of users.
    Supports filtering by operating system and device name pattern.

    .PARAMETER usersList
    Array of user principal names or user IDs to query.

    .PARAMETER accessToken
    Microsoft Graph API access token for authentication.

    .PARAMETER operatingSystem
    Operating system filter (e.g., 'Windows', 'iOS', 'Android'). Default is 'Windows'.

    .PARAMETER deviceNameFilter
    Device name pattern to filter results (e.g., 'w11-' to match devices starting with 'w11-').

    .OUTPUTS
    Array of custom objects containing user and device information.

    .EXAMPLE
    $devices = Get-RegisteredDevicesByUser -usersList @('user1@domain.com', 'user2@domain.com') -accessToken $token

    .NOTES
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string[]]$usersList,
        [Parameter(Mandatory = $true)]
        [string]$accessToken
    )

    # Private helper function to process and filter devices
    function ConvertTo-FilteredDeviceObject()
    {
        param(
            [Parameter(Mandatory = $true)]
            [object[]]$Devices,
            [Parameter(Mandatory = $true)]
            [string]$UserName,
            [string]$OperatingSystemFilter,
            [string]$DeviceNameFilter
        )

        $filteredResults = @()
        
        foreach ($device in $Devices)
        {
            # Skip if device is null or empty
            if ($null -eq $device -or $device -is [int]) { continue }
            
            # Apply client-side filtering (since registeredDevices endpoint doesn't support $filter)
            $includeDevice = $true
            
            # Filter by operating system if specified
            if (-not [string]::IsNullOrEmpty($OperatingSystemFilter))
            {
                if ($device.operatingSystem -ne $OperatingSystemFilter)
                {
                    $includeDevice = $false
                }
            }
            
            # Filter by device name pattern if specified
            if ($includeDevice -and -not [string]::IsNullOrEmpty($DeviceNameFilter))
            {
                if ($device.displayName -notlike "$DeviceNameFilter*")
                {
                    $includeDevice = $false
                }
            }
            
            # Only add device if it passes all filters
            if ($includeDevice)
            {
                $filteredResults += [PSCustomObject]@{
                    UserName                      = $UserName
                    DeviceId                      = $device.id
                    DisplayName                   = $device.displayName
                    Manufacturer                  = $device.manufacturer
                    Model                         = $device.model
                    OperatingSystem               = $device.operatingSystem
                    OperatingSystemVersion        = $device.operatingSystemVersion
                    AccountEnabled                = $device.accountEnabled
                    ApproximateLastSignInDateTime = $device.approximateLastSignInDateTime
                    DeviceTrustType               = $device.trustType
                    IsCompliant                   = $device.isCompliant
                    IsManaged                     = $device.isManaged
                    DeviceOwnership               = $device.deviceOwnership
                    EnrollmentType                = $device.enrollmentType
                    RegistrationDateTime          = $device.registrationDateTime
                }
            }
        }
        
        return $filteredResults
    }

    $functionName = $MyInvocation.MyCommand.Name
    $operatingSystem = $settings.operatingSystem
    $deviceNameFilter = $settings.deviceNamePrefix
    Write-Verbose "[$functionName] Starting device query for $($usersList.Count) user(s)"
    Write-Log -LogFile $logFile -Module $functionName -Message "Starting device query for $($usersList.Count) user(s)" -LogLevel "Information"

    # Build resource paths for batch processing
    $resourcePaths = @()
    foreach ($user in $usersList)
    {
        $userTrimmed = $user.Trim()
        if (-not [string]::IsNullOrEmpty($userTrimmed))
        {
            $resourcePaths += "users/$userTrimmed/registeredDevices"
            Write-Verbose "[$functionName] Added resource path for user: $userTrimmed"
        }
    }

    if ($resourcePaths.Count -eq 0)
    {
        Write-Warning "[$functionName] No valid users provided"
        Write-Log -LogFile $logFile -Module $functionName -Message "No valid users provided" -LogLevel "Warning"
        return @()
    }

    # Note: The /registeredDevices endpoint does NOT support OData $filter queries
    # We must retrieve all devices and filter client-side
    Write-Verbose "[$functionName] Operating system filter: $operatingSystem"
    Write-Verbose "[$functionName] Device name filter: $deviceNameFilter"
    Write-Log -LogFile $logFile -Module $functionName -Message "OS filter: $operatingSystem, Device name filter: $deviceNameFilter (client-side filtering will be applied)" -LogLevel "Information"

    # Call Graph API with batch processing (NO filter parameter - not supported by registeredDevices endpoint)
    Write-Verbose "[$functionName] Calling Graph API for $($resourcePaths.Count) resource path(s)"
    $response = CallGraphAPI -accessToken $accessToken -ResourcePath $resourcePaths

    if ($null -eq $response)
    {
        Write-Warning "[$functionName] No response received from Graph API"
        Write-Log -LogFile $logFile -Module $functionName -Message "No response received from Graph API" -LogLevel "Warning"
        return @()
    }

    # Process the response
    $results = @()
    
    # Handle batch response
    if ($response.batchProcessed -eq $true)
    {
        Write-Verbose "[$functionName] Processing batch response: $($response.successCount) successful, $($response.failureCount) failed"
        Write-Log -LogFile $logFile -Module $functionName -Message "Batch response: $($response.successCount) successful, $($response.failureCount) failed" -LogLevel "Information"
        
        foreach ($batchItem in $response.value)
        {
            # Extract user from the request id (maps to original resource path)
            $requestId = $batchItem.id
            $userPath = if ($requestId -and $requestId -le $resourcePaths.Count) 
            { 
                $resourcePaths[$requestId - 1] 
            } 
            else 
            { 
                "Unknown" 
            }
            
            $userName = if ($userPath -match 'users/([^/]+)/') { $Matches[1] } else { "Unknown" }
            
            # Check if the batch item was successful
            if ($batchItem.status -ge 200 -and $batchItem.status -lt 300)
            {
                # Extract devices from the batch response body
                $devices = if ($batchItem.body.value) { $batchItem.body.value } else { @() }
                
                # Process devices using helper function
                $filteredDevices = ConvertTo-FilteredDeviceObject -Devices $devices -UserName $userName -OperatingSystemFilter $operatingSystem -DeviceNameFilter $deviceNameFilter
                $results += $filteredDevices
                
                Write-Verbose "[$functionName] Processed $($devices.Count) device(s) for user: $userName (after filtering: $($filteredDevices.Count) matching)"
            }
            else
            {
                Write-Warning "[$functionName] Failed to retrieve devices for user: $userName (Status: $($batchItem.status))"
                Write-Log -LogFile $logFile -Module $functionName -Message "Failed to retrieve devices for user: $userName (Status: $($batchItem.status))" -LogLevel "Warning"
            }
        }
    }
    # Handle single response
    else
    {
        Write-Verbose "[$functionName] Processing single response"
        
        # Extract user from the original request (single user scenario)
        $userName = if ($usersList.Count -eq 1) { $usersList[0] } else { "Unknown" }
        
        $devices = if ($response.value) { $response.value } else { @($response) }
        
        # Process devices using helper function
        $filteredDevices = ConvertTo-FilteredDeviceObject -Devices $devices -UserName $userName -OperatingSystemFilter $operatingSystem -DeviceNameFilter $deviceNameFilter
        $results += $filteredDevices
        
        Write-Verbose "[$functionName] Processed $($devices.Count) device(s) for single user query (after filtering: $($filteredDevices.Count) matching)"
    }

    Write-Verbose "[$functionName] Total devices retrieved: $($results.Count)"
    Write-Log -LogFile $logFile -Module $functionName -Message "Total devices retrieved: $($results.Count)" -LogLevel "Information"

    return $results
}
function Get-DeviceData()
{
    <#
    .SYNOPSIS
        Fetches device data from Microsoft Graph API with caching support.
    
    .DESCRIPTION
        Retrieves device information from various Microsoft Graph endpoints with intelligent caching.
        Supports autopilot, managed, imported, and unmanaged device types. Cached data is stored
        in script scope and can be refreshed on demand.
    
    .PARAMETER AccessToken
        The access token for Microsoft Graph API authentication.
    
    .PARAMETER DeviceType
        The type of devices to fetch: 'autopilot', 'managed', 'imported', or 'unmanaged'.
    
    .PARAMETER RefreshCache
        Forces a refresh of the cached data for the specified device type.
    
    .PARAMETER CacheExpirationMinutes
        Number of minutes before cached data expires. Default is 15 minutes.
    
    .PARAMETER DeviceNamePrefix
        Optional device name prefix for filtering managed devices. If not provided, uses settings.deviceNamePrefix.
    
    .EXAMPLE
        $autopilotDevices = Get-DeviceData -AccessToken $token -DeviceType 'autopilot'
    
    .EXAMPLE
        $managedDevices = Get-DeviceData -AccessToken $token -DeviceType 'managed' -RefreshCache
    
    .NOTES
        Author: Autopilot Team
        Version: 1.0.0
        This function maintains separate caches for each device type.
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [ValidateSet('autopilot', 'managed', 'imported', 'unmanaged')]
        [string]$DeviceType,
        [switch]$RefreshCache,
        [int]$CacheExpirationMinutes = 15,
        [string]$DeviceNamePrefix
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Initialize script-scope cache if it doesn't exist
    if ($null -eq $script:DeviceDataCache)
    {
        $script:DeviceDataCache = @{
            autopilot = @{ Data = $null; Timestamp = $null; Filter = $null }
            managed   = @{ Data = $null; Timestamp = $null; Filter = $null }
            imported  = @{ Data = $null; Timestamp = $null; Filter = $null }
            unmanaged = @{ Data = $null; Timestamp = $null; Filter = $null }
        }
    }
    
    # Determine if we should use cached data
    $cacheValid = $false
    $currentCache = $script:DeviceDataCache[$DeviceType]
    
    if (-not $RefreshCache -and $null -ne $currentCache.Timestamp)
    {
        $cacheAge = (Get-Date) - $currentCache.Timestamp
        
        # For managed devices, also check if filter has changed
        if ($DeviceType -eq 'managed')
        {
            $currentFilter = Get-ManagedDeviceFilter -DeviceNamePrefix $DeviceNamePrefix
            $filterMatch = $currentCache.Filter -eq $currentFilter
        }
        else
        {
            $filterMatch = $true
        }
        
        if ($cacheAge.TotalMinutes -lt $CacheExpirationMinutes -and $filterMatch)
        {
            $cacheValid = $true
            Write-Log -LogFile $LogFile -Module $functionName -Message "Using cached $DeviceType device data (age: $([math]::Round($cacheAge.TotalMinutes, 1)) minutes)" -LogLevel "Information"
            Write-Verbose "[$functionName] Using cached $DeviceType device data (age: $([math]::Round($cacheAge.TotalMinutes, 1)) minutes)"
        }
    }
    
    if ($cacheValid)
    {
        # Return cached data
        Write-Log -LogFile $LogFile -Module $functionName -Message "Retrieved $($currentCache.Data.value.Count) $DeviceType devices from cache." -LogLevel "Information"
        Write-Verbose "[$functionName] Retrieved $($currentCache.Data.value.Count) $DeviceType devices from cache."
        return $currentCache.Data
    }
    else
    {
        # Fetch fresh data based on device type
        Write-Log -LogFile $LogFile -Module $functionName -Message "Fetching $DeviceType devices from Graph API." -LogLevel "Information"
        Write-Verbose "[$functionName] Fetching $DeviceType devices from Graph API."
        
        switch ($DeviceType)
        {
            'autopilot'
            {
                $resourcePath = "deviceManagement/windowsAutopilotDeviceIdentities"
                # Note: No extraParameters for autopilot endpoint - using defaults to get all available properties
                $devices = CallGraphApi -ResourcePath $resourcePath -accessToken $AccessToken
            }
            'imported'
            {
                $resourcePath = "deviceManagement/importedWindowsAutopilotDeviceIdentities"
                $extraParameters = "select=serialNumber,importId,groupTag,state"
                $devices = CallGraphApi -ResourcePath $resourcePath -accessToken $AccessToken -extraParameters $extraParameters
            }
            'unmanaged'
            {
                $resourcePath = "devices"
                $filter = "operatingSystem eq 'Windows'"
                $extraParameters = "select=id,displayName,manufacturer,model,operatingSystemVersion,profileType,createdDateTime,registrationDateTime,accountEnabled,approximateLastSignInDateTime,enrollmentProfileName,enrollmentType,isCompliant"
                $devices = CallGraphApi -ResourcePath $resourcePath -accessToken $AccessToken -filter $filter -extraParameters $extraParameters
            }
            'managed'
            {
                $resourcePath = "deviceManagement/managedDevices"
                $filter = Get-ManagedDeviceFilter -DeviceNamePrefix $DeviceNamePrefix
                $extraParameters = "select=id,serialNumber,deviceName,manufacturer,model,osVersion,deviceEnrollmentType,enrolledDateTime,lastSyncDateTime,complianceState,userPrincipalName,userDisplayName,userId,managedDeviceOwnerType,azureADRegistered,autopilotEnrolled,usersLoggedOn"
                $devices = CallGraphApi -ResourcePath $resourcePath -accessToken $AccessToken -filter $filter -extraParameters $extraParameters
                
                # Store filter for cache validation
                $currentCache.Filter = $filter
            }
        }
        
        # Validate response
        if ($null -eq $devices -or $null -eq $devices.value)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "WARNING: No $DeviceType devices retrieved from API!" -LogLevel "Warning"
            Write-Verbose "[$functionName] WARNING: No $DeviceType devices retrieved!"
            $devices = @{ value = @() }
        }
        
        Write-Log -LogFile $LogFile -Module $functionName -Message "Fetched $($devices.value.Count) $DeviceType devices." -LogLevel "Information"
        Write-Verbose "[$functionName] Fetched $($devices.value.Count) $DeviceType devices."
        
        # Update cache
        $currentCache.Data = $devices
        $currentCache.Timestamp = Get-Date
        Write-Log -LogFile $LogFile -Module $functionName -Message "$DeviceType device data cached for $CacheExpirationMinutes minutes." -LogLevel "Verbose"
        
        return $devices
    }
}

function Get-ManagedDeviceFilter
{
    <#
    .SYNOPSIS
        Generates OData filter string for managed devices based on device name prefix.
    
    .PARAMETER DeviceNamePrefix
        Optional device name prefix. If not provided, uses $global:settings.deviceNamePrefix.
    #>
    param(
        [string]$DeviceNamePrefix
    )
    
    # Determine prefix source
    if ([string]::IsNullOrWhiteSpace($DeviceNamePrefix))
    {
        if ($null -ne $global:settings -and -not [string]::IsNullOrWhiteSpace($global:settings.deviceNamePrefix))
        {
            $DeviceNamePrefix = $global:settings.deviceNamePrefix
        }
    }
    
    # Build filter
    if ([string]::IsNullOrWhiteSpace($DeviceNamePrefix))
    {
        return "operatingSystem eq 'Windows'"
    }
    else
    {
        $escapedPrefix = $DeviceNamePrefix -replace "'", "''"
        return "operatingSystem eq 'Windows' and startswith(deviceName,'$escapedPrefix')"
    }
}

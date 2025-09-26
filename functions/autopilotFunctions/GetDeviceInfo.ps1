function GetDeviceInfo()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false)]
        [string]$GroupTag,
        [Parameter(Mandatory = $false)]
        [string]$AssignedUser = '',
        [string]$Name,
        [switch]$NoHash,
        # Optional override useful for testing vendor filtering without relying on local CIM data
        [Parameter(Mandatory = $false)]
        [string]$ManufacturerOverride
    )
    $functionName = $MyInvocation.MyCommand.Name    
    #Print verbose logs of the received parameters.
    Write-Verbose "[$functionName] GroupTag: $GroupTag"
    
    Write-Verbose "[$functionName] AssignedUser: $AssignedUser"
    Write-Verbose "[$functionName] NoHash: $NoHash"
    write-log -logFile $logFile -module $functionName -message "GroupTag: $GroupTag, AssignedUser: $AssignedUser, NoHash: $NoHash" 
    $device = @{}
    $session = New-CimSession
    $serial = (Get-CimInstance -CimSession $session -Class Win32_BIOS).SerialNumber
    #Add the serial number to the hash table.
    $device.Add('SerialNumber', $serial)
    Write-Verbose "[$functionName] The serial number is $serial."
    if ($ManufacturerOverride)
    {
        Write-Verbose "[$functionName] Using provided ManufacturerOverride: $ManufacturerOverride"
        $make = $ManufacturerOverride.Trim()
    }
    else
    {
        $cs = Get-CimInstance -CimSession $session -Class Win32_ComputerSystem
        $make = $cs.Manufacturer.Trim()
    }
    $device.Add('Manufacturer', $make)
    Write-Verbose "[$functionName] The manufacturer is $make."
    $model = $cs.Model.Trim()
    $device.Add('Model', $model)
    Write-Verbose "[$functionName] The model is $model."
    $product = ''
    $device.add('Product', $product)
    Write-Verbose "[$functionName] The group tag is $GroupTag"
    $device.add('GroupTag', $GroupTag)
    Write-Verbose "[$functionName] The assigned user is $AssignedUser"
    $device.add('AssignedUser', $AssignedUser)
    write-log -logFile $logFile -module $functionName -message "Device info collected: $($device | ConvertTo-Json -Depth $maxJSONDepth)"
    if (-not $NoHash)
    {
        Write-Verbose "[$functionName] Checking for hardware hash."
        $devDetail = (Get-CimInstance -CimSession $session -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'")
        Write-Verbose "[$functionName] The device details are: $($devDetail | ConvertTo-Json -Depth $maxJSONDepth)"
        if ($devDetail)
        {
            $hash = $devDetail.DeviceHardwareData
            $device.Add('HardwareHash', $hash)
            Write-Verbose "[$functionName] The hardware hash is $hash."
        }
        else
        {
            Write-Error 'No hardware hash was found.'
            return $null
        }
    }
    else
    {
        Write-Verbose "[$functionName] No hardware hash was requested."
    }
    Remove-CimSession $session
    # Default to not evaluated yet
    $device['deviceAllowed'] = $true
    Write-Verbose "[$functionName] Checking whether the device manufacturer is allowed from a list of $($settings.autopilotDeviceAllowedVendors.count) vendors."
    write-log -logFile $logFile -module $functionName -message "Checking whether the device manufacturer '$make' is in the allowed vendors list: $($settings.autopilotDeviceAllowedVendors -join ', ')."
    if ($make -and $settings.autopilotDeviceAllowedVendors -and $settings.autopilotDeviceAllowedVendors.count -gt 0)
    {
        # Normalization helper: remove common suffixes & punctuation for broader matching
        $normalize = { param($s) if (-not $s)
            {
                return '' 
            } ($s -replace '(?i)\b(corporation|corp\.?|inc\.?|co\.?|limited|ltd\.?|llc)\b', '').Trim().ToLower() }
        $normalizedMake = & $normalize $make
        $allowed = $false
        for ($i = 0; $i -lt $settings.autopilotDeviceAllowedVendors.count; $i ++)
        {
            $candidate = $settings.autopilotDeviceAllowedVendors[$i]
            $normalizedCandidate = & $normalize $candidate
            Write-Verbose "[$functionName] Comparing raw: '$make' vs '$candidate' | normalized: '$normalizedMake' vs '$normalizedCandidate'"
            write-log -logFile $logFile -module $functionName -message "Comparing manufacturer '$make' (normalized '$normalizedMake') with allowed vendor '$candidate' (normalized '$normalizedCandidate')."
            if ($normalizedMake -eq $normalizedCandidate -or $normalizedMake -match [regex]::Escape($normalizedCandidate) -or $make -match [regex]::Escape($candidate))
            {
                $allowed = $true
                Write-Verbose "[$functionName] Match found: '$make' allowed by list entry '$candidate'."
                write-log -logFile $logFile -module $functionName -message "Match found: Manufacturer '$make' allowed by list entry '$candidate'."
                break
            }
        }
        if ($allowed)
        {
            $device['deviceAllowed'] = $true
        }
        else
        {
            $device['deviceAllowed'] = $false
            Write-Verbose "[$functionName] Manufacturer '$make' NOT found in allowed vendors list after evaluation."
            write-log -logFile $logFile -module $functionName -message "Manufacturer '$make' NOT found in allowed vendors list after evaluation. Allowed list: $($settings.autopilotDeviceAllowedVendors -join ', ')."
        }
    }
    else
    {
        Write-Verbose "[$functionName] No allowed vendors are specified, all manufacturers are implicitly allowed."
        write-log -logFile $logFile -module $functionName -message "No allowed vendors specified; manufacturer '$make' accepted by default."  
    }
    return $device
}


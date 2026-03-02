function GetDeviceInfo()
{
    <#
    .SYNOPSIS
    Retrieves local device hardware information for Autopilot enrollment.

    .DESCRIPTION
    This function collects device information from the local system including serial number,
    manufacturer, model, and optionally the hardware hash. It uses CIM to query BIOS and
    system information, and validates the manufacturer against an allowed vendors list from
    settings. The function supports manufacturer override for testing scenarios.

    .PARAMETER GroupTag
    Optional group tag to assign to the device for Autopilot profile assignment.

    .PARAMETER AssignedUser
    Optional user principal name to pre-assign to the device.

    .PARAMETER Name
    Optional device name (currently not used in implementation).

    .PARAMETER NoHash
    When specified, skips hardware hash collection. Useful for quick device info retrieval.

    .PARAMETER ManufacturerOverride
    Optional manufacturer name override for testing vendor filtering without local CIM data.

    .OUTPUTS
    System.Collections.Hashtable
    Returns a hashtable with device properties: SerialNumber, Manufacturer, Model, Product,
    GroupTag, AssignedUser, HardwareHash (if not NoHash), and deviceAllowed (boolean).
    Returns $null if hardware hash is requested but not found.

    .EXAMPLE
    $deviceInfo = GetDeviceInfo -GroupTag "IT-Dept" -AssignedUser "john.doe@contoso.com"
    $quickInfo = GetDeviceInfo -NoHash

    .NOTES
    Requires administrator privileges to access MDM_DevDetail_Ext01 namespace for hardware hash.
    Hardware hash is required for Autopilot device registration.
    Vendor validation uses normalized manufacturer names (removes common suffixes/punctuation).
    Compatible with PowerShell 5.1.
    #>
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
    Write-Log -logFile $logFile -module $functionName -message "GroupTag: $GroupTag, AssignedUser: $AssignedUser, NoHash: $NoHash"
    $device = @{}
    $session = New-CimSession
    $serial = (Get-CimInstance -CimSession $session -Class Win32_BIOS).SerialNumber
    #Add the serial number to the hash table.
    $device.Add('SerialNumber', $serial)
    Write-Verbose "[$functionName] The serial number is $serial."
    $cs = Get-CimInstance -CimSession $session -Class Win32_ComputerSystem
    if ($ManufacturerOverride)
    {
        Write-Verbose "[$functionName] Using provided ManufacturerOverride: $ManufacturerOverride"
        $make = $ManufacturerOverride.Trim()
    }
    else
    {
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
    Write-Log -logFile $logFile -module $functionName -message "Device info collected: $($device | ConvertTo-Json -Depth $maxJSONDepth)"
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
    Write-Log -logFile $logFile -module $functionName -message "Checking whether the device manufacturer '$make' is in the allowed vendors list: $($settings.autopilotDeviceAllowedVendors -join ', ')."
    if ($make -and $settings.autopilotDeviceAllowedVendors -and $settings.autopilotDeviceAllowedVendors.count -gt 0)
    {
        # Normalization helper: remove common suffixes & punctuation for broader matching
        $normalize = { param($s) if (-not $s)
            {
                return ''
            } ($s -replace '(?i)\b(corporation|corp\.?|inc\.?|co\.?|limited|ltd\.?|llc)\b', '').Trim().ToLower() }
        $normalizedMake = & $normalize $make
        $allowed = $false
        foreach ($candidate in $settings.autopilotDeviceAllowedVendors)
        {
            $normalizedCandidate = & $normalize $candidate
            Write-Verbose "[$functionName] Comparing raw: '$make' vs '$candidate' | normalized: '$normalizedMake' vs '$normalizedCandidate'"
            Write-Log -logFile $logFile -module $functionName -message "Comparing manufacturer '$make' (normalized '$normalizedMake') with allowed vendor '$candidate' (normalized '$normalizedCandidate')."
            if ($normalizedMake -eq $normalizedCandidate -or $normalizedMake.StartsWith($normalizedCandidate) -or $normalizedCandidate.StartsWith($normalizedMake))
            {
                $allowed = $true
                Write-Verbose "[$functionName] Match found: '$make' allowed by list entry '$candidate'."
                Write-Log -logFile $logFile -module $functionName -message "Match found: Manufacturer '$make' allowed by list entry '$candidate'."
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
            Write-Log -logFile $logFile -module $functionName -message "Manufacturer '$make' NOT found in allowed vendors list after evaluation. Allowed list: $($settings.autopilotDeviceAllowedVendors -join ', ')."
        }
    }
    else
    {
        Write-Verbose "[$functionName] No allowed vendors are specified, all manufacturers are implicitly allowed."
        Write-Log -logFile $logFile -module $functionName -message "No allowed vendors specified; manufacturer '$make' accepted by default."
    }
    return $device
}


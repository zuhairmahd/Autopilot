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
        [switch]$NoHash
    )
    $functionName = $MyInvocation.MyCommand.Name    
    #Print verbose logs of the received parameters.
    Write-Verbose "[$functionName] GroupTag: $GroupTag"
    Write-Verbose "[$functionName] AssignedUser: $AssignedUser"
    Write-Verbose "[$functionName] NoHash: $NoHash"

    $device = @{}
    $session = New-CimSession
    $serial = (Get-CimInstance -CimSession $session -Class Win32_BIOS).SerialNumber
    #Add the serial number to the hash table.
    $device.Add('SerialNumber', $serial)
    Write-Verbose "[$functionName] The serial number is $serial."
    $cs = Get-CimInstance -CimSession $session -Class Win32_ComputerSystem
    $make = $cs.Manufacturer.Trim()
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
    if (-not $NoHash)
    {
        Write-Verbose "[$functionName] Checking for hardware hash."
        $devDetail = (Get-CimInstance -CimSession $session -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'")
        Write-Verbose "[$functionName] The device details are: $($devDetail | ConvertTo-Json -Depth 5)"
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
    return $device
}

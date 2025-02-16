function Get-DeviceInfo()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$name,
        [Parameter(Mandatory = $true)]
        [string]$GroupTag,
        [Parameter(Mandatory = $false)]
        [string]$AssignedUser = ''
    )
    $device = @{}
    $session = New-CimSession
    Write-Verbose "Checking $name for hardware hash."
    $serial = (Get-CimInstance -CimSession $session -Class Win32_BIOS).SerialNumber
    #Add the serial number to the hash table.
    $device.Add('SerialNumber', $serial)
    Write-Verbose "The serial number is $serial."
    $devDetail = (Get-CimInstance -CimSession $session -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'")
    Write-Verbose "The device details are: $($devDetail | ConvertTo-Json)"
    if ($devDetail)
    {
        $hash = $devDetail.DeviceHardwareData
        $device.Add('HardwareHash', $hash)
        Write-Verbose "The hardware hash is $hash."
    }
    else
    {
        Write-Error 'No hardware hash was found.'
        exit 1
    }
    #Get other -NoTypeInformation
    $cs = Get-CimInstance -CimSession $session -Class Win32_ComputerSystem
    $make = $cs.Manufacturer.Trim()
    $device.Add('Manufacturer', $make)
    Write-Verbose "The manufacturer is $make."
    $model = $cs.Model.Trim()
    $device.Add('Model', $model)
    Write-Verbose "The model is $model."
    $product = ''
    $device.add('Product', $product)
    Write-Verbose "The group tag is $GroupTag"
    $device.add('GroupTag', $GroupTag)
    Write-Verbose "The assigned user is $AssignedUser"
    $device.add('AssignedUser', $AssignedUser)

    Remove-CimSession $session
    Write-Verbose $device
    return $device
}
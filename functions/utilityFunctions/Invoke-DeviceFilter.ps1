function Invoke-DeviceFilter
{
    <#
    .SYNOPSIS
        High-performance device filtering using C# LINQ when available.
    
    .DESCRIPTION
        Filters device collections using compiled C# DeviceFilter class when available,
        falling back to PowerShell Where-Object for compatibility. Provides 3-6x
        performance improvement for large device collections (>100 devices).
    
    .PARAMETER Devices
        Array of device objects to filter. Each device should have properties like
        manufacturer, model, serialNumber, deviceName, etc.
    
    .PARAMETER FilterType
        Type of filter to apply:
        - ByVendor: Filter devices by manufacturer name
        - BySerial: Find device by serial number
        - GroupByManufacturer: Group devices by manufacturer
    
    .PARAMETER FilterValue
        Value to filter by (e.g., manufacturer name, serial number).
    
    .OUTPUTS
        Filtered device collection or grouped results.
    
    .EXAMPLE
        # Filter devices by manufacturer
        $hpDevices = Invoke-DeviceFilter -Devices $allDevices -FilterType ByVendor -FilterValue "HP"
    
    .EXAMPLE
        # Find device by serial number
        $device = Invoke-DeviceFilter -Devices $allDevices -FilterType BySerial -FilterValue "ABC123456"
    
    .EXAMPLE
        # Group devices by manufacturer
        $grouped = Invoke-DeviceFilter -Devices $allDevices -FilterType GroupByManufacturer
    
    .NOTES
        Author: Windows Autopilot Management Tool Team
        Version: 1.0.0
        Automatically uses C# DeviceFilter when available for 3-6x performance improvement.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$Devices,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("ByVendor", "BySerial", "GroupByManufacturer")]
        [string]$FilterType,
        
        [Parameter(Mandatory = $false)]
        [string]$FilterValue
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Filtering $($Devices.Count) devices using FilterType: $FilterType"
    
    # Return early if no devices
    if ($Devices.Count -eq 0)
    {
        Write-Verbose "[$functionName] No devices to filter"
        return @()
    }
    
    # Use C# DeviceFilter if available
    $useCSharpFilter = $global:AutopilotDllStatus -and $global:AutopilotDllStatus.DeviceCoreLoaded
    
    if ($useCSharpFilter)
    {
        Write-Verbose "[$functionName] Using C# DeviceFilter for enhanced performance"
        
        try
        {
            # Convert PowerShell objects to format compatible with C# (PSObject[] works with dynamic)
            $deviceFilter = [Autopilot.DeviceCore.DeviceFilter]::new()
            
            switch ($FilterType)
            {
                "ByVendor"
                {
                    if ([string]::IsNullOrWhiteSpace($FilterValue))
                    {
                        Write-Warning "[$functionName] FilterValue required for ByVendor filter"
                        return @()
                    }
                    
                    $result = $deviceFilter.FilterByVendor($Devices, $FilterValue)
                    Write-Verbose "[$functionName] C# filter found $($result.Count) devices for vendor: $FilterValue"
                    return $result
                }
                
                "BySerial"
                {
                    if ([string]::IsNullOrWhiteSpace($FilterValue))
                    {
                        Write-Warning "[$functionName] FilterValue required for BySerial filter"
                        return $null
                    }
                    
                    $result = $deviceFilter.FindBySerial($Devices, $FilterValue)
                    if ($result)
                    {
                        Write-Verbose "[$functionName] C# filter found device with serial: $FilterValue"
                    }
                    else
                    {
                        Write-Verbose "[$functionName] C# filter did not find device with serial: $FilterValue"
                    }
                    return $result
                }
                
                "GroupByManufacturer"
                {
                    $result = $deviceFilter.GroupByManufacturer($Devices)
                    Write-Verbose "[$functionName] C# filter grouped devices into $($result.Count) manufacturers"
                    return $result
                }
            }
        }
        catch
        {
            Write-Warning "[$functionName] C# DeviceFilter failed, falling back to PowerShell: $($_.Exception.Message)"
            Write-Log -LogFile $LogFile -Module $functionName `
                -Message "C# DeviceFilter error: $($_.Exception.Message), using PowerShell fallback" -LogLevel "Warning"
            # Fall through to PowerShell implementation
        }
    }
    
    # PowerShell fallback implementation
    Write-Verbose "[$functionName] Using PowerShell device filtering"
    
    switch ($FilterType)
    {
        "ByVendor"
        {
            if ([string]::IsNullOrWhiteSpace($FilterValue))
            {
                Write-Warning "[$functionName] FilterValue required for ByVendor filter"
                return @()
            }
            
            $result = @($Devices | Where-Object { 
                    $_.manufacturer -like "*$FilterValue*" -or 
                    $_.manufacturer -eq $FilterValue 
                })
            
            Write-Verbose "[$functionName] PowerShell filter found $($result.Count) devices for vendor: $FilterValue"
            return $result
        }
        
        "BySerial"
        {
            if ([string]::IsNullOrWhiteSpace($FilterValue))
            {
                Write-Warning "[$functionName] FilterValue required for BySerial filter"
                return $null
            }
            
            $result = $Devices | Where-Object { 
                $_.serialNumber -eq $FilterValue 
            } | Select-Object -First 1
            
            if ($result)
            {
                Write-Verbose "[$functionName] PowerShell filter found device with serial: $FilterValue"
            }
            else
            {
                Write-Verbose "[$functionName] PowerShell filter did not find device with serial: $FilterValue"
            }
            return $result
        }
        
        "GroupByManufacturer"
        {
            $result = $Devices | Group-Object -Property manufacturer -AsHashTable -AsString
            Write-Verbose "[$functionName] PowerShell filter grouped devices into $($result.Count) manufacturers"
            return $result
        }
    }
}

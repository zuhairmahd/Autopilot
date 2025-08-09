function GetCorpDeviceIdentifier()
{
    [CmdletBinding()]
    param (
        [string]$OutputPath = "$pwd\corp_device_info.csv"
    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Entered function. OutputPath: $OutputPath"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting GetCorpDeviceIdentifier. OutputPath: $OutputPath" -LogLevel "Information"

    # Get computer system information
    try
    {
        Write-Verbose "[$functionName] Attempting to retrieve computer system information via Win32_ComputerSystem."
        Write-Log -LogFile $LogFile -Module $functionName -Message "Retrieving Win32_ComputerSystem info..." -LogLevel "Debug"
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem 
        Write-Verbose "[$functionName] Computer system information retrieved: $($computerSystem | ConvertTo-Json -Depth $maxJSONDepth)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Win32_ComputerSystem info: $($computerSystem | ConvertTo-Json -Depth $maxJSONDepth)" -LogLevel "Debug"

        Write-Verbose "[$functionName] Attempting to retrieve BIOS information via Win32_BIOS."
        Write-Log -LogFile $LogFile -Module $functionName -Message "Retrieving Win32_BIOS info..." -LogLevel "Debug"
        $bios = Get-CimInstance -ClassName Win32_BIOS
        Write-Verbose "[$functionName] BIOS information retrieved: $($bios | ConvertTo-Json -Depth $maxJSONDepth)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Win32_BIOS info: $($bios | ConvertTo-Json -Depth $maxJSONDepth)" -LogLevel "Debug"
    }
    catch
    {
        Write-Error "Failed to retrieve computer system information: $_"
        Write-Verbose "[$functionName] Exception occurred: $($_.Exception | Format-List * | Out-String)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error retrieving system info: $($_.Exception.Message)" -LogLevel "Error"
        return $false
    }

    # Extract the desired properties
    Write-Verbose "[$functionName] Extracting Manufacturer, Model, and SerialNumber."
    $make = $computerSystem.Manufacturer
    $model = $computerSystem.Model
    $serialNumber = $bios.SerialNumber
    Write-Verbose "[$functionName] Extracted values: Manufacturer='$make', Model='$model', SerialNumber='$serialNumber'"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Extracted device info: Manufacturer='$make', Model='$model', SerialNumber='$serialNumber'" -LogLevel "Information"

    # Output the information
    Write-Host "Device Manufacturer: $make"
    Write-Host "Device Model: $model"
    Write-Host "Device Serial Number: $serialNumber"
    Write-Verbose "[$functionName] Outputting device info to host."
    Write-Log -LogFile $LogFile -Module $functionName -Message "Outputting device info to host." -LogLevel "Debug"

    $deviceInfo = [PSCustomObject]@{
        Manufacturer = $make
        Model        = $model
        SerialNumber = $serialNumber
    }
    Write-Verbose "[$functionName] Returning device info object."
    Write-Log -LogFile $LogFile -Module $functionName -Message "Returning device info object: $($deviceInfo | ConvertTo-Json -Depth $maxJSONDepth)" -LogLevel "Debug"
    return $deviceInfo
}


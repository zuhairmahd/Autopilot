function Test-MinimumSpecs()
{
    <#
    .SYNOPSIS
        Validates whether the device meets minimum specifications.
    .DESCRIPTION
        Checks operating system, OS version, OS service release, memory, and PIV reader availability using provided settings and
        system probes. Logs results and can optionally emit color-coded console output. When strict mode is
        enabled, the function throws if requirements are not met instead of returning $false.
    .PARAMETER settings
        Hashtable containing minimumDevicePhysicalMemoryInGB, operatingSystem, operatingSystemVersion, and minimumOSServiceRelease values used
        for validation. Defaults to the global $settings variable when not provided.
    .PARAMETER writeToConsole
        Writes validation results and system information to the console when specified, using color-coded
        boolean values for readability.
    .PARAMETER strictMode
        Throws an exception when requirements are not met instead of returning $false.
    .OUTPUTS
        [pscustomobject]
    #>
    [CmdletBinding()]
    param(
        [hashtable]$settings = $settings,
        [switch]$writeToConsole,
        [switch]$runPIVTest,
        [switch]$strictMode
    )

    $functionName = $MyInvocation.MyCommand.Name
    function Write-BooleanStatus()
    {
        param(
            [string]$Label,
            $Value
        )

        $color = if ($Value -eq $true)
        {
            "Green"
        }
        elseif ($Value -eq $false)
        {
            "Red"
        }
        else
        {
            "Yellow"
        }
        $displayValue = if ($null -eq $Value)
        {
            "Unknown"
        }
        else
        {
            $Value
        }
        Write-Host "$($Label): $displayValue" -ForegroundColor $color
    }

    Write-Verbose "[$functionName] Strict mode: $strictMode"
    Write-Verbose "[$functionName] Write to console: $writeToConsole"
    Write-Log -logFile $logFile -module $functionName -message "Strict mode: $strictMode, Write to console: $writeToConsole" -logLevel "Information"
    Write-Verbose "[$functionName] Required minimum device memory: $($settings.minimumDevicePhysicalMemoryInGB) GB"
    Write-Verbose "[$functionName] Required operating system: $($settings.operatingSystem)"
    Write-Verbose "[$functionName] Required minimum OS version: $($settings.operatingSystemVersion)"
    Write-Verbose "[$functionName] Required minimum OS service release: $($settings.minimumOSServiceRelease)"
    Write-Log -logFile $logFile -module $functionName -message "Required minimum device memory: $($settings.minimumDevicePhysicalMemoryInGB) GB" -logLevel "Information"
    Write-Log -logFile $logFile -module $functionName -message "Required operating system: $($settings.operatingSystem)" -logLevel "Information"
    Write-Log -logFile $logFile -module $functionName -message "Required minimum OS version: $($settings.operatingSystemVersion)" -logLevel "Information"
    Write-Log -logFile $logFile -module $functionName -message "Required minimum OS service release: $($settings.minimumOSServiceRelease)" -logLevel "Information"

    # Determine whether to run the PIV test: explicit parameter overrides settings.runPIVTest
    $runPIVRequested = if ($PSBoundParameters.ContainsKey('runPIVTest'))
    {
        [bool]$runPIVTest
    }
    elseif ($settings -is [hashtable] -and $settings.ContainsKey('runPIVTest'))
    {
        [bool]$settings['runPIVTest']
    }
    else
    {
        [bool]$settings.runPIVTest
    }

    $returnObject = @{
        Success           = $false
        Message           = ''
        Checks            = @()
        SystemInformation = $null
        PIVTestRequested  = $runPIVRequested
    }
    $systemInformation = Get-SystemInformation
    $returnObject.SystemInformation = $systemInformation
    Write-Log -logFile $logFile -module $functionName -message "System information retrieved: $($systemInformation | Out-String)" -logLevel "Information"

    $PIVReaderStatus = @{ Success = $false; Status = "Not started" }
    if ($runPIVRequested)
    {
        Write-Verbose "[$functionName] Running PIV reader test as requested."
        Write-Log -logFile $logFile -module $functionName -message "Running PIV reader test as requested." -logLevel "Information"
        Write-Host "Please insert your PIV card, then press Enter to continue." -ForegroundColor Yellow
        Read-Host "Press Enter after inserting your PIV"
        $PIVReaderStatus = Test-PIVReader
    }
    else
    {
        Write-Verbose "[$functionName] Skipping PIV reader test as not requested."
        Write-Log -logFile $logFile -module $functionName -message "Skipping PIV reader test as not requested." -logLevel "Information"
        $PIVReaderStatus = @{ Success = $true; Status = "Not requested" }
    }
    Write-Log -logFile $logFile -module $functionName -message "PIV Reader status: $($PIVReaderStatus | Out-String)" -logLevel "Information"

    $hasCorrectMemory = if ($null -ne $settings.minimumDevicePhysicalMemoryInGB -and $null -ne $systemInformation.TotalMemoryGB)
    {
        $systemInformation.TotalMemoryGB -ge $settings.minimumDevicePhysicalMemoryInGB
    }
    else
    {
        $null
    }
    Write-Verbose "[$functionName] Has correct memory: $hasCorrectMemory"
    Write-Log -logFile $logFile -module $functionName -message "Has correct memory: $hasCorrectMemory" -logLevel "Information"

    $hasCorrectOS = if ($null -ne $systemInformation.OSName -and $null -ne $settings.operatingSystem)
    {
        ($systemInformation.OSName -like "*$($settings.operatingSystem)*")
    }
    else
    {
        $null
    }
    Write-Verbose "[$functionName] Has correct OS: $hasCorrectOS"
    Write-Log -logFile $logFile -module $functionName -message "Has correct OS: $hasCorrectOS" -logLevel "Information"

    $hasMinimumOSVersion = if ($null -ne $systemInformation.OSMajorVersion -and $null -ne $settings.operatingSystemVersion)
    {
        $systemInformation.OSMajorVersion -ge $settings.operatingSystemVersion
    }
    else
    {
        $null
    }
    Write-Verbose "[$functionName] Has minimum OS major version: $hasMinimumOSVersion"
    Write-Log -logFile $logFile -module $functionName -message "Has minimum OS major version: $hasMinimumOSVersion" -logLevel "Information"

    $hasMinimumServiceRelease = if ($null -ne $systemInformation.OSServiceRelease -and $null -ne $settings.minimumOSServiceRelease)
    {
        # Service releases are compared as strings (e.g., '22h2', '23h2')
        # For now, we'll just check if they match or if actual is >= required
        # This is a simple string comparison; more sophisticated version comparison could be added
        $systemInformation.OSServiceRelease -ge $settings.minimumOSServiceRelease
    }
    else
    {
        $null
    }
    Write-Verbose "[$functionName] Has minimum OS service release: $hasMinimumServiceRelease"
    Write-Log -logFile $logFile -module $functionName -message "Has minimum OS service release: $hasMinimumServiceRelease" -logLevel "Information"
    $PIVReaderOK = if ($runPIVRequested)
    {
        $PIVReaderStatus.Success -eq $true
    }
    else
    {
        $true
    }
    Write-Verbose "[$functionName] PIV reader status OK: $PIVReaderOK"
    Write-Log -logFile $logFile -module $functionName -message "PIV reader status OK: $PIVReaderOK" -logLevel "Information"

    if ($writeToConsole)
    {
        Write-BooleanStatus -Label "Has correct OS" -Value $hasCorrectOS
        Write-BooleanStatus -Label "Has minimum OS version" -Value $hasMinimumOSVersion
        Write-BooleanStatus -Label "Has minimum OS service release" -Value $hasMinimumServiceRelease
        Write-BooleanStatus -Label "Has correct memory" -Value $hasCorrectMemory
        $pivDisplayValue = if ($runPIVRequested)
        {
            $PIVReaderStatus.Success
        }
        else
        {
            $null
        }
        Write-BooleanStatus -Label "PIV reader status OK" -Value $pivDisplayValue
        # Iterate over the system information and display its properties and values.
        foreach ($property in $systemInformation.PSObject.Properties)
        {
            Write-Host "$($property.Name): $($property.Value)" -ForegroundColor Yellow
        }
    }

    $checks = @()
    $checks += [pscustomobject]@{
        Name     = "OperatingSystem"
        Passed   = $hasCorrectOS -eq $true
        Expected = $settings.operatingSystem
        Actual   = $systemInformation.OSName
        Message  = if ($hasCorrectOS -eq $true)
        {
            "Operating system meets requirement."
        }
        else
        {
            "Expected operating system containing '$($settings.operatingSystem)', actual '$($systemInformation.OSName)'"
        }
    }
    $checks += [pscustomobject]@{
        Name     = "OSVersion"
        Passed   = $hasMinimumOSVersion -eq $true
        Expected = "Windows $($settings.operatingSystemVersion) or higher"
        Actual   = "Windows $($systemInformation.OSMajorVersion)"
        Message  = if ($hasMinimumOSVersion -eq $true)
        {
            "OS version meets requirement."
        }
        else
        {
            "Expected Windows $($settings.operatingSystemVersion) or higher, actual Windows $($systemInformation.OSMajorVersion)"
        }
    }
    $checks += [pscustomobject]@{
        Name     = "OSServiceRelease"
        Passed   = $hasMinimumServiceRelease -eq $true
        Expected = "Service release $($settings.minimumOSServiceRelease) or higher"
        Actual   = $systemInformation.OSServiceRelease
        Message  = if ($hasMinimumServiceRelease -eq $true)
        {
            "OS service release meets requirement."
        }
        else
        {
            "Expected service release $($settings.minimumOSServiceRelease) or higher, actual $($systemInformation.OSServiceRelease)"
        }
    }
    $checks += [pscustomobject]@{
        Name     = "Memory"
        Passed   = $hasCorrectMemory -eq $true
        Expected = "Memory >= $($settings.minimumDevicePhysicalMemoryInGB) GB"
        Actual   = $systemInformation.TotalMemoryGB
        Message  = if ($hasCorrectMemory -eq $true)
        {
            "Memory meets requirement."
        }
        else
        {
            "Expected memory >= $($settings.minimumDevicePhysicalMemoryInGB) GB, actual $($systemInformation.TotalMemoryGB) GB"
        }
    }
    if ($runPIVRequested)
    {
        $checks += [pscustomobject]@{
            Name     = "PIVReader"
            Passed   = $PIVReaderOK -eq $true
            Expected = "PIV reader present and responsive"
            Actual   = if ($null -ne $PIVReaderStatus -and $null -ne $PIVReaderStatus.Success)
            {
                $PIVReaderStatus.Success
            }
            else
            {
                "Unknown"
            }
            Message  = if ($PIVReaderOK -eq $true)
            {
                "PIV reader meets requirement."
            }
            else
            {
                "Expected PIV reader present and responsive, actual status $($PIVReaderStatus.Success)"
            }
        }
    }

    $failedChecks = $checks | Where-Object { $_.Passed -ne $true }
    $returnObject.Checks = $checks
    $returnObject.Success = -not $failedChecks
    $returnObject.Message = if ($returnObject.Success)
    {
        "Device meets minimum specifications."
    }
    else
    {
        ($failedChecks | Select-Object -ExpandProperty Message) -join '; '
    }

    if ($returnObject.Success)
    {
        Write-Verbose "[$functionName] Device meets minimum specifications."
        Write-Log -logFile $logFile -module $functionName -message "Device meets minimum specifications." -logLevel "Information"
        return $returnObject
    }
    else
    {
        Write-Verbose "[$functionName] Device does not meet minimum specifications."
        Write-Log -logFile $logFile -module $functionName -message "Device does not meet minimum specifications. $($returnObject.Message)" -logLevel "Warning"
        if ($strictMode)
        {
            throw $returnObject.Message
        }
        return $returnObject
    }
}
function Test-MinimumSpecs()
{
    <#
    .SYNOPSIS
        Validates whether the device meets minimum specifications.
    .DESCRIPTION
        Checks operating system, OS build, memory, and PIV reader availability using provided settings and
        system probes. Logs results and can optionally emit color-coded console output. When strict mode is
        enabled, the function throws if requirements are not met instead of returning $false.
    .PARAMETER settings
        Hashtable containing minimumDevicePhysicalMemoryInGB, operatingSystem, and minimumOSBuild values used
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
    Write-Verbose "[$functionName] Required minimum OS build: $($settings.minimumOSBuild)"
    Write-Log -logFile $logFile -module $functionName -message "Required minimum device memory: $($settings.minimumDevicePhysicalMemoryInGB) GB" -logLevel "Information"
    Write-Log -logFile $logFile -module $functionName -message "Required operating system: $($settings.operatingSystem)" -logLevel "Information"
    Write-Log -logFile $logFile -module $functionName -message "Required minimum OS build: $($settings.minimumOSBuild)" -logLevel "Information"

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

    $hasCorrectOS = if ($null -ne $systemInformation.OSName)
    {
        $systemInformation.OSName -like "*Windows 11*"
    }
    else
    {
        $null
    }
    Write-Verbose "[$functionName] Has correct OS: $hasCorrectOS"
    Write-Log -logFile $logFile -module $functionName -message "Has correct OS: $hasCorrectOS" -logLevel "Information"

    $hasMinimumOS = if ($null -ne $systemInformation.OSBuild -and $null -ne $settings.minimumOSBuild)
    {
        $systemInformation.OSBuild -ge $settings.minimumOSBuild
    }
    else
    {
        $null
    }
    Write-Verbose "[$functionName] Has minimum OS build: $hasMinimumOS"
    Write-Log -logFile $logFile -module $functionName -message "Has minimum OS build: $hasMinimumOS" -logLevel "Information"
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
        Write-BooleanStatus -Label "Has minimum OS build" -Value $hasMinimumOS
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
        Name     = "OSBuild"
        Passed   = $hasMinimumOS -eq $true
        Expected = "Build >= $($settings.minimumOSBuild)"
        Actual   = $systemInformation.OSBuild
        Message  = if ($hasMinimumOS -eq $true)
        {
            "OS build meets requirement."
        }
        else
        {
            "Expected OS build >= $($settings.minimumOSBuild), actual $($systemInformation.OSBuild)"
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
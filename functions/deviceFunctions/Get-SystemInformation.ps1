function Get-SystemInformation()
{
    <#
    .SYNOPSIS
        Retrieves system information.
    .DESCRIPTION
        This function gathers various system information such as OS version and hardware details including total memory, CPU info, BIOS version, disk space and other related data.
    .PARAMETER WriteToConsole
        When specified, displays the system information to the console. Otherwise, returns data silently.
    .EXAMPLE
        Get-SystemInformation
        Returns system information as a PSCustomObject without console output.
    .EXAMPLE
        Get-SystemInformation -WriteToConsole
        Displays system information to console and returns the data object.
    .OUTPUTS
        PSCustomObject
        Returns a PSCustomObject with the following properties:

        Computer Information:
        - ComputerName: The name of the computer
        - Domain: The domain the computer belongs to
        - Manufacturer: The computer manufacturer
        - Model: The computer model

        Operating System:
        - OSName: The operating system name (Caption)
        - OSVersion: The operating system version number
        - OSBuild: The operating system build number
        - OSArchitecture: The OS architecture (e.g., 64-bit)
        - InstallDate: The date the OS was installed
        - LastBootUpTime: The last time the system was booted

        Processor:
        - ProcessorName: The processor model name
        - ProcessorManufacturer: The processor manufacturer
        - ProcessorCores: The number of physical cores
        - ProcessorLogicalProcessors: The number of logical processors
        - ProcessorMaxClockSpeed: The maximum clock speed in MHz

        Memory:
        - TotalMemoryGB: Total physical memory in GB (rounded to 2 decimals)
        - FreeMemoryGB: Free physical memory in GB (rounded to 2 decimals)
        - UsedMemoryGB: Used physical memory in GB (rounded to 2 decimals)

        BIOS:
        - BIOSManufacturer: The BIOS manufacturer
        - BIOSVersion: The SMBIOS BIOS version
        - BIOSReleaseDate: The BIOS release date
        - SerialNumber: The system serial number

        Disks:
        - Disks: Array of disk objects, each containing:
          * DeviceID: The drive letter (e.g., C:)
          * SizeGB: Total disk size in GB (rounded to 2 decimals)
          * FreeSpaceGB: Free disk space in GB (rounded to 2 decimals)
          * UsedSpaceGB: Used disk space in GB (rounded to 2 decimals)
          * PercentFree: Percentage of free space (rounded to 2 decimals)

        Network:
        - NetworkAdapters: Array of network adapter objects, each containing:
          * Description: The adapter description
          * MACAddress: The MAC address
          * IPAddress: The IP address(es)
          * IPSubnet: The subnet mask(s)
          * DefaultIPGateway: The default gateway(s)
          * DNSServerSearchOrder: The DNS server(s)

        Metadata:
        - CollectionTime: The timestamp when the information was collected
    #>
    [CmdletBinding()]
    param(
        [switch]$WriteToConsole
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $logFile -Module $functionName -Message "Starting system information collection" -LogLevel "Information"
    Write-Verbose "[$functionName] Starting system information collection"

    try
    {
        # Gather OS Information
        Write-Log -LogFile $logFile -Module $functionName -Message "Retrieving operating system information" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Retrieving operating system information"

        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $computerInfo = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop

        Write-Log -LogFile $logFile -Module $functionName -Message "OS: $($osInfo.Caption), Version: $($osInfo.Version), Build: $($osInfo.BuildNumber)" -LogLevel "Information"

        # Gather CPU Information
        Write-Log -LogFile $logFile -Module $functionName -Message "Retrieving CPU information" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Retrieving CPU information"

        $processorInfo = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1

        Write-Log -LogFile $logFile -Module $functionName -Message "CPU: $($processorInfo.Name), Cores: $($processorInfo.NumberOfCores), Logical Processors: $($processorInfo.NumberOfLogicalProcessors)" -LogLevel "Information"

        # Gather Memory Information
        Write-Log -LogFile $logFile -Module $functionName -Message "Retrieving memory information" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Retrieving memory information"

        $totalMemoryGB = [math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 0)
        $freeMemoryGB = [math]::Round($osInfo.FreePhysicalMemory / 1MB, 0)

        Write-Log -LogFile $logFile -Module $logFile -Module $functionName -Message "Total Memory: $totalMemoryGB GB, Free Memory: $freeMemoryGB GB" -LogLevel "Information"

        # Gather BIOS Information
        Write-Log -LogFile $logFile -Module $functionName -Message "Retrieving BIOS information" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Retrieving BIOS information"

        $biosInfo = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop

        Write-Log -LogFile $logFile -Module $functionName -Message "BIOS: $($biosInfo.Manufacturer), Version: $($biosInfo.SMBIOSBIOSVersion), Serial: $($biosInfo.SerialNumber)" -LogLevel "Information"

        # Gather Disk Information
        Write-Log -LogFile $logFile -Module $functionName -Message "Retrieving disk information" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Retrieving disk information"

        $diskInfo = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop |
            Select-Object DeviceID,
            @{Name = "SizeGB"; Expression = {[math]::Round($_.Size / 1GB, 2)}},
            @{Name = "FreeSpaceGB"; Expression = {[math]::Round($_.FreeSpace / 1GB, 2)}},
            @{Name = "UsedSpaceGB"; Expression = {[math]::Round(($_.Size - $_.FreeSpace) / 1GB, 2)}},
            @{Name = "PercentFree"; Expression = {[math]::Round(($_.FreeSpace / $_.Size) * 100, 2)}}

        foreach ($disk in $diskInfo)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Disk $($disk.DeviceID): Size: $($disk.SizeGB) GB, Free: $($disk.FreeSpaceGB) GB ($($disk.PercentFree)%)" -LogLevel "Information"
        }

        # Gather Network Adapter Information
        Write-Log -LogFile $logFile -Module $functionName -Message "Retrieving network adapter information" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Retrieving network adapter information"

        $networkAdapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" -ErrorAction Stop |
            Select-Object Description, MACAddress, IPAddress, IPSubnet, DefaultIPGateway, DNSServerSearchOrder

        Write-Log -LogFile $logFile -Module $functionName -Message "Found $($networkAdapters.Count) active network adapter(s)" -LogLevel "Information"

        # Create system information object
        Write-Log -LogFile $logFile -Module $functionName -Message "Building system information object" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Building system information object"

        $systemInfo = [PSCustomObject]@{
            ComputerName               = $computerInfo.Name
            Domain                     = $computerInfo.Domain
            Manufacturer               = $computerInfo.Manufacturer
            Model                      = $computerInfo.Model

            # Operating System
            OSName                     = $osInfo.Caption
            OSVersion                  = $osInfo.Version
            OSBuild                    = $osInfo.BuildNumber
            OSArchitecture             = $osInfo.OSArchitecture
            InstallDate                = $osInfo.InstallDate
            LastBootUpTime             = $osInfo.LastBootUpTime

            # CPU
            ProcessorName              = $processorInfo.Name
            ProcessorManufacturer      = $processorInfo.Manufacturer
            ProcessorCores             = $processorInfo.NumberOfCores
            ProcessorLogicalProcessors = $processorInfo.NumberOfLogicalProcessors
            ProcessorMaxClockSpeed     = $processorInfo.MaxClockSpeed

            # Memory
            TotalMemoryGB              = $totalMemoryGB
            FreeMemoryGB               = $freeMemoryGB
            UsedMemoryGB               = [math]::Round($totalMemoryGB - $freeMemoryGB, 2)

            # BIOS
            BIOSManufacturer           = $biosInfo.Manufacturer
            BIOSVersion                = $biosInfo.SMBIOSBIOSVersion
            BIOSReleaseDate            = $biosInfo.ReleaseDate
            SerialNumber               = $biosInfo.SerialNumber

            # Disks
            Disks                      = $diskInfo

            # Network
            NetworkAdapters            = $networkAdapters

            # Timestamp
            CollectionTime             = Get-Date
        }

        Write-Log -LogFile $logFile -Module $functionName -Message "Successfully collected system information for $($systemInfo.ComputerName)" -LogLevel "Information"
        Write-Verbose "[$functionName] Successfully collected system information for $($systemInfo.ComputerName)"

        # Display to console if requested
        if ($WriteToConsole)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Displaying system information to console" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Displaying system information to console"

            Write-Host ""
            Write-Host "=" * 80 -ForegroundColor Cyan
            Write-Host "SYSTEM INFORMATION" -ForegroundColor Cyan
            Write-Host "=" * 80 -ForegroundColor Cyan
            Write-Host ""

            Write-Host "[COMPUTER]" -ForegroundColor Yellow
            Write-Host "  Name:         $($systemInfo.ComputerName)"
            Write-Host "  Domain:       $($systemInfo.Domain)"
            Write-Host "  Manufacturer: $($systemInfo.Manufacturer)"
            Write-Host "  Model:        $($systemInfo.Model)"
            Write-Host "  Serial:       $($systemInfo.SerialNumber)"
            Write-Host ""

            Write-Host "[OPERATING SYSTEM]" -ForegroundColor Yellow
            Write-Host "  OS:           $($systemInfo.OSName)"
            Write-Host "  Version:      $($systemInfo.OSVersion)"
            Write-Host "  Build:        $($systemInfo.OSBuild)"
            Write-Host "  Architecture: $($systemInfo.OSArchitecture)"
            Write-Host "  Install Date: $($systemInfo.InstallDate)"
            Write-Host "  Last Boot:    $($systemInfo.LastBootUpTime)"
            Write-Host ""

            Write-Host "[PROCESSOR]" -ForegroundColor Yellow
            Write-Host "  Name:         $($systemInfo.ProcessorName)"
            Write-Host "  Manufacturer: $($systemInfo.ProcessorManufacturer)"
            Write-Host "  Cores:        $($systemInfo.ProcessorCores)"
            Write-Host "  Logical CPUs: $($systemInfo.ProcessorLogicalProcessors)"
            Write-Host "  Max Speed:    $($systemInfo.ProcessorMaxClockSpeed) MHz"
            Write-Host ""

            Write-Host "[MEMORY]" -ForegroundColor Yellow
            Write-Host "  Total:        $($systemInfo.TotalMemoryGB) GB"
            Write-Host "  Used:         $($systemInfo.UsedMemoryGB) GB"
            Write-Host "  Free:         $($systemInfo.FreeMemoryGB) GB"
            Write-Host ""

            Write-Host "[BIOS]" -ForegroundColor Yellow
            Write-Host "  Manufacturer: $($systemInfo.BIOSManufacturer)"
            Write-Host "  Version:      $($systemInfo.BIOSVersion)"
            Write-Host "  Release Date: $($systemInfo.BIOSReleaseDate)"
            Write-Host ""

            Write-Host "[DISKS]" -ForegroundColor Yellow
            foreach ($disk in $systemInfo.Disks)
            {
                Write-Host "  Drive $($disk.DeviceID)"
                Write-Host "    Size:       $($disk.SizeGB) GB"
                Write-Host "    Used:       $($disk.UsedSpaceGB) GB"
                Write-Host "    Free:       $($disk.FreeSpaceGB) GB ($($disk.PercentFree)%)"
            }
            Write-Host ""

            Write-Host "[NETWORK ADAPTERS]" -ForegroundColor Yellow
            foreach ($adapter in $systemInfo.NetworkAdapters)
            {
                Write-Host "  $($adapter.Description)"
                Write-Host "    MAC:        $($adapter.MACAddress)"
                Write-Host "    IP:         $($adapter.IPAddress -join ', ')"
                Write-Host "    Gateway:    $($adapter.DefaultIPGateway -join ', ')"
                Write-Host "    DNS:        $($adapter.DNSServerSearchOrder -join ', ')"
                Write-Host ""
            }

            Write-Host "=" * 80 -ForegroundColor Cyan
            Write-Host ""
        }

        Write-Log -LogFile $logFile -Module $functionName -Message "System information collection completed successfully" -LogLevel "Information"
        Write-Verbose "[$functionName] System information collection completed successfully"

        return $systemInfo
    }
    catch
    {
        $errorMessage = "Failed to collect system information: $_"
        Write-Log -LogFile $logFile -Module $functionName -Message $errorMessage -LogLevel "Error"
        Write-Error "[$functionName] $errorMessage"

        Write-Log -LogFile $logFile -Module $functionName -Message "Exception details: $($_.Exception.Message)" -LogLevel "Error"
        Write-Verbose "[$functionName] Exception details: $($_.Exception.Message)"

        throw
    }
}
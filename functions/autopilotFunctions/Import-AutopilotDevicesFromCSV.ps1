function Import-AutopilotDevicesFromCSV()
{
    <#
    .SYNOPSIS
    Parses CSV files containing Autopilot device information and returns structured objects for Graph API import.

    .DESCRIPTION
    This function reads one or more CSV files containing Windows Autopilot device hardware information
    and returns an array of structured device objects ready for Microsoft Graph API consumption.

    Each returned object contains:
    - serialNumber: Device serial number
    - hardwareIdentifier: Hardware hash for device identification
    - groupTag: Deployment group tag
    - assignedUserPrincipalName: Optional user assignment
    - productKey: Product key (typically empty)
    - importId: Import identifier (typically empty)
    - manufacturer: Device manufacturer (if available in CSV)
    - model: Device model (if available in CSV)

    The function includes extensive logging and validation:
    - Validates input files and CSV structure
    - Validates required fields (Serial Number, Hardware Hash)
    - Removes invalid or duplicate entries
    - Batches large imports using splitValue parameter
    - Provides detailed statistics on processing

    .PARAMETER InputFiles
    Array of paths to CSV files containing Autopilot device data.
    CSV must contain at minimum: "Device Serial Number" and "Hardware Hash" columns.
    Optional columns: "Manufacturer", "Model Name", "Group Tag", "Assigned User"

    .PARAMETER GroupTag
    Default group tag to apply to all devices if not specified in CSV.
    Default value: 'MSB01'

    .PARAMETER SplitValue
    Maximum number of devices to return per batch.
    Useful for processing large imports in chunks to avoid API throttling.
    Default value: 500 (Microsoft Graph API recommended batch size)

    .PARAMETER ValidateOnly
    If specified, only validates the CSV structure and content without returning device objects.
    Useful for pre-import validation.

    .PARAMETER ShowSummary
    Display detailed processing statistics after completion.

    .OUTPUTS
    System.Collections.Hashtable
    Returns a hashtable with the following structure:
    @{
        Success = $true/$false
        DeviceObjects = @(array of device objects ready for Graph API)
        Statistics = @{
            TotalInputFiles = Count of input files processed
            SuccessfulFiles = Count of files successfully processed
            FailedFiles = Count of files that failed processing
            TotalEntriesProcessed = Total entries found in all files
            ValidEntries = Count of valid device entries
            InvalidEntries = Count of invalid entries (missing required fields)
            DuplicateEntries = Count of duplicate serial numbers removed
            BatchCount = Number of batches created (if splitValue specified)
        }
        Errors = @(array of error objects with details)
    }

    .EXAMPLE
    $result = Import-AutopilotDevicesFromCSV -InputFiles "C:\Imports\devices.csv" -GroupTag "CORP-WIN11"
    if ($result.Success) {
        foreach ($device in $result.DeviceObjects) {
            # Call Graph API import function
            Import-AutopilotDevice -DeviceObject $device -AccessToken $token
        }
    }

    .EXAMPLE
    # Process multiple files with validation
    $files = Get-ChildItem "C:\Imports\*.csv"
    $result = Import-AutopilotDevicesFromCSV -InputFiles $files.FullName -ShowSummary -SplitValue 100

    .EXAMPLE
    # Validate CSV before processing
    $validation = Import-AutopilotDevicesFromCSV -InputFiles "C:\Import\devices.csv" -ValidateOnly

    .NOTES
    - Compatible with PowerShell 5.1
    - Requires access to $LogFile global variable for logging
    - Uses streaming approach for memory efficiency with large files
    - Removes 'OrderNumber' property if present (legacy field)
    - Normalizes column names to handle CSV variations
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$InputFiles,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$GroupTag = 'MSB01',
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 1000)]
        [int]$SplitValue = 500,
        [Parameter(Mandatory = $false)]
        [switch]$ValidateOnly,
        [Parameter(Mandatory = $false)]
        [switch]$ShowSummary
    )

    #region Initialization and Parameter Logging
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting function with parameters:"
    Write-Verbose "[$functionName]   InputFiles: $($InputFiles -join ', ')"
    Write-Verbose "[$functionName]   GroupTag: $GroupTag"
    Write-Verbose "[$functionName]   SplitValue: $SplitValue"
    Write-Verbose "[$functionName]   ValidateOnly: $ValidateOnly"
    Write-Verbose "[$functionName]   ShowSummary: $ShowSummary"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting CSV import processing with parameters: `n$(($PSBoundParameters | Out-String).Trim())" -LogLevel "Information"
    #endregion initialization and Parameter Logging

    # Initialize result object
    $result = @{
        Success       = $false
        DeviceObjects = @()
        Statistics    = @{
            TotalInputFiles       = 0
            SuccessfulFiles       = 0
            FailedFiles           = 0
            TotalEntriesProcessed = 0
            ValidEntries          = 0
            InvalidEntries        = 0
            DuplicateEntries      = 0
            BatchCount            = 0
        }
        Errors        = @()
    }

    #region Validate parameters
    if ($SplitValue -lt 1)
    {
        $errorMsg = "Split value must be a positive integer greater than zero. Provided: $SplitValue"
        Write-Verbose "[$functionName] $errorMsg"
        Write-Log -LogFile $LogFile -Module $functionName -Message $errorMsg -LogLevel "Error"
        $result.Errors += @{
            Type    = "ParameterValidation"
            Message = $errorMsg
        }
        return $result
    }

    if ($InputFiles.Count -lt 1)
    {
        $errorMsg = "At least one input CSV file path is required."
        Write-Verbose "[$functionName] $errorMsg"
        Write-Log -LogFile $LogFile -Module $functionName -Message $errorMsg -LogLevel "Error"
        $result.Errors += @{
            Type    = "ParameterValidation"
            Message = $errorMsg
        }
        return $result
    }
    #endregion Validate parameters

    $result.Statistics.TotalInputFiles = $InputFiles.Count
    Write-Log -LogFile $LogFile -Module $functionName -Message "Processing $($InputFiles.Count) input file(s)" -LogLevel "Information"

    # Track unique serial numbers to prevent duplicates
    $serialNumberTracker = @{}
    $allDeviceObjects = New-Object System.Collections.Generic.List[object]

    # Process each input file
    foreach ($inputFile in $InputFiles)
    {
        Write-Verbose "[$functionName] Processing file: $inputFile"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Processing input file: $inputFile" -LogLevel "Information"
        [string]$resolvedInput = $null
        try
        {
            $resolvedInput = (Resolve-Path -Path $inputFile -ErrorAction Stop).Path
            Write-Verbose "[$functionName] Resolved file path: $resolvedInput"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Resolved input file path: $resolvedInput" -LogLevel "Debug"
        }
        catch
        {
            $errorMsg = "Input file '$inputFile' could not be resolved or was not found. Error: $($_.Exception.Message)"
            Write-Verbose "[$functionName] $errorMsg"
            Write-Log -LogFile $LogFile -Module $functionName -Message $errorMsg -LogLevel "Error"
            $result.Errors += @{
                Type    = "FileNotFound"
                File    = $inputFile
                Message = $errorMsg
            }
            $result.Statistics.FailedFiles++
            continue
        }
        if (-not (Test-Path -Path $resolvedInput -PathType Leaf))
        {
            $errorMsg = "Input file '$inputFile' does not exist or is not a file."
            Write-Verbose "[$functionName] $errorMsg"
            Write-Log -LogFile $LogFile -Module $functionName -Message $errorMsg -LogLevel "Error"
            $result.Errors += @{
                Type    = "InvalidFile"
                File    = $inputFile
                Message = $errorMsg
            }
            $result.Statistics.FailedFiles++
            continue
        }

        # Validate file extension
        $extension = [System.IO.Path]::GetExtension($resolvedInput)
        if ($extension -ne '.csv')
        {
            $errorMsg = "File '$inputFile' is not a CSV file. Extension: $extension"
            Write-Verbose "[$functionName] $errorMsg"
            Write-Log -LogFile $LogFile -Module $functionName -Message $errorMsg -LogLevel "Warning"
        }

        $fileEntryCount = 0
        $fileValidCount = 0
        $fileInvalidCount = 0

        try
        {
            Write-Verbose "[$functionName] Importing CSV file: $resolvedInput"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Importing CSV data from: $resolvedInput" -LogLevel "Information"

            # Import CSV and process each row
            $csvData = Import-Csv -Path $resolvedInput -ErrorAction Stop
            if ($null -eq $csvData -or $csvData.Count -eq 0)
            {
                $errorMsg = "CSV file '$resolvedInput' is empty or contains no data rows."
                Write-Verbose "[$functionName] $errorMsg"
                Write-Log -LogFile $LogFile -Module $functionName -Message $errorMsg -LogLevel "Warning"
                $result.Errors += @{
                    Type    = "EmptyFile"
                    File    = $resolvedInput
                    Message = $errorMsg
                }
                $result.Statistics.FailedFiles++
                continue
            }

            Write-Verbose "[$functionName] CSV contains $($csvData.Count) rows"
            Write-Log -LogFile $LogFile -Module $functionName -Message "CSV file contains $($csvData.Count) data rows" -LogLevel "Information"

            # Get CSV headers for validation
            $csvHeaders = $csvData[0].PSObject.Properties.Name
            Write-Verbose "[$functionName] CSV headers: $($csvHeaders -join ', ')"
            Write-Log -LogFile $LogFile -Module $functionName -Message "CSV headers detected: $($csvHeaders -join ', ')" -LogLevel "Debug"

            # Process each CSV row
            foreach ($row in $csvData)
            {
                $fileEntryCount++
                $result.Statistics.TotalEntriesProcessed++
                Write-Verbose "[$functionName] Processing entry $fileEntryCount"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Processing CSV entry $fileEntryCount of $($csvData.Count)" -LogLevel "Debug"
                try
                {
                    # Extract and normalize field names (CSV column names can vary)
                    $serialNumber = $null
                    $hardwareHash = $null
                    $manufacturer = $null
                    $model = $null
                    $csvGroupTag = $null
                    $assignedUser = $null

                    # Map CSV columns to expected fields (handle common variations)
                    foreach ($prop in $row.PSObject.Properties)
                    {
                        $propName = $prop.Name.Trim()
                        $propValue = if ($prop.Value)
                        {
                            $prop.Value.Trim()
                        }
                        else
                        {
                            $null
                        }

                        switch -Regex ($propName)
                        {
                            '^(Device Serial Number|Serial Number|SerialNumber|Serial)$'
                            {
                                $serialNumber = $propValue
                                Write-Verbose "[$functionName]   Found Serial Number: $serialNumber"
                            }
                            '^(Hardware Hash|HardwareHash|Hardware Identifier|HardwareIdentifier)$'
                            {
                                $hardwareHash = $propValue
                                Write-Verbose "[$functionName]   Found Hardware Hash: $($hardwareHash.Substring(0, [Math]::Min(50, $hardwareHash.Length)))..."
                            }
                            '^(Manufacturer|Make|OEM Manufacturer)$'
                            {
                                $manufacturer = $propValue
                                Write-Verbose "[$functionName]   Found Manufacturer: $manufacturer"
                            }
                            '^(Model Name|Model|Device Model)$'
                            {
                                $model = $propValue
                                Write-Verbose "[$functionName]   Found Model: $model"
                            }
                            '^(Group Tag|GroupTag|Deployment Group)$'
                            {
                                $csvGroupTag = $propValue
                                Write-Verbose "[$functionName]   Found Group Tag: $csvGroupTag"
                            }
                            '^(Assigned User|AssignedUser|User Principal Name|AssignedUserPrincipalName)$'
                            {
                                $assignedUser = $propValue
                                Write-Verbose "[$functionName]   Found Assigned User: $assignedUser"
                            }
                        }
                    }

                    # Validate required fields
                    if ([string]::IsNullOrWhiteSpace($serialNumber))
                    {
                        $errorMsg = "Entry $($fileEntryCount): Missing required field 'Serial Number'"
                        Write-Verbose "[$functionName] $errorMsg"
                        Write-Log -LogFile $LogFile -Module $functionName -Message $errorMsg -LogLevel "Warning"
                        $result.Errors += @{
                            Type    = "MissingRequiredField"
                            File    = $resolvedInput
                            Entry   = $fileEntryCount
                            Field   = "Serial Number"
                            Message = $errorMsg
                        }
                        $fileInvalidCount++
                        $result.Statistics.InvalidEntries++
                        continue
                    }

                    if ([string]::IsNullOrWhiteSpace($hardwareHash))
                    {
                        $errorMsg = "Entry $fileEntryCount (Serial: $serialNumber): Missing required field 'Hardware Hash'"
                        Write-Verbose "[$functionName] $errorMsg"
                        Write-Log -LogFile $LogFile -Module $functionName -Message $errorMsg -LogLevel "Warning"
                        $result.Errors += @{
                            Type         = "MissingRequiredField"
                            File         = $resolvedInput
                            Entry        = $fileEntryCount
                            SerialNumber = $serialNumber
                            Field        = "Hardware Hash"
                            Message      = $errorMsg
                        }
                        $fileInvalidCount++
                        $result.Statistics.InvalidEntries++
                        continue
                    }

                    # Check for duplicate serial numbers
                    if ($serialNumberTracker.ContainsKey($serialNumber))
                    {
                        $errorMsg = "Entry $($fileEntryCount): Duplicate serial number detected: $serialNumber (already processed from file: $($serialNumberTracker[$serialNumber]))"
                        Write-Verbose "[$functionName] $errorMsg"
                        Write-Log -LogFile $LogFile -Module $functionName -Message $errorMsg -LogLevel "Warning"
                        $result.Errors += @{
                            Type         = "DuplicateEntry"
                            File         = $resolvedInput
                            Entry        = $fileEntryCount
                            SerialNumber = $serialNumber
                            Message      = $errorMsg
                        }
                        $result.Statistics.DuplicateEntries++
                        continue
                    }

                    # Use CSV group tag if provided, otherwise use parameter default
                    $effectiveGroupTag = if (-not [string]::IsNullOrWhiteSpace($csvGroupTag))
                    {
                        $csvGroupTag
                    }
                    else
                    {
                        $GroupTag
                    }

                    # Create device object structured for Microsoft Graph API
                    $deviceObject = [PSCustomObject]@{
                        '@odata.type'             = '#microsoft.graph.importedWindowsAutopilotDeviceIdentity'
                        serialNumber              = $serialNumber
                        hardwareIdentifier        = $hardwareHash
                        groupTag                  = $effectiveGroupTag
                        assignedUserPrincipalName = if ([string]::IsNullOrWhiteSpace($assignedUser))
                        {
                            ''
                        }
                        else
                        {
                            $assignedUser
                        }
                        productKey                = ''
                        importId                  = ''
                        manufacturer              = if ([string]::IsNullOrWhiteSpace($manufacturer))
                        {
                            ''
                        }
                        else
                        {
                            $manufacturer
                        }
                        model                     = if ([string]::IsNullOrWhiteSpace($model))
                        {
                            ''
                        }
                        else
                        {
                            $model
                        }
                        state                     = @{
                            '@odata.type'        = 'microsoft.graph.importedWindowsAutopilotDeviceIdentityState'
                            deviceImportStatus   = 'pending'
                            deviceRegistrationId = ''
                            deviceErrorCode      = 0
                            deviceErrorName      = ''
                        }
                    }

                    # Track this serial number
                    $serialNumberTracker[$serialNumber] = $resolvedInput

                    # Add to collection if not in ValidateOnly mode
                    if (-not $ValidateOnly)
                    {
                        $allDeviceObjects.Add($deviceObject)
                    }

                    $fileValidCount++
                    $result.Statistics.ValidEntries++

                    Write-Verbose "[$functionName] Successfully processed device: Serial=$serialNumber, GroupTag=$effectiveGroupTag, User=$assignedUser"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Valid device entry: Serial=$serialNumber, Manufacturer=$manufacturer, Model=$model, GroupTag=$effectiveGroupTag, User=$assignedUser" -LogLevel "Debug"
                }
                catch
                {
                    $errorMsg = "Entry $($fileEntryCount): Failed to process CSV row. Error: $($_.Exception.Message)"
                    Write-Verbose "[$functionName] $errorMsg"
                    Write-Log -LogFile $LogFile -Module $functionName -Message $errorMsg -LogLevel "Error"
                    $result.Errors += @{
                        Type      = "ProcessingError"
                        File      = $resolvedInput
                        Entry     = $fileEntryCount
                        Message   = $errorMsg
                        Exception = $_.Exception.Message
                    }
                    $fileInvalidCount++
                    $result.Statistics.InvalidEntries++
                }
            }

            # File processing summary
            Write-Verbose "[$functionName] File processing complete: Total=$fileEntryCount, Valid=$fileValidCount, Invalid=$fileInvalidCount"
            Write-Log -LogFile $LogFile -Module $functionName -Message "File '$resolvedInput' processing complete: Total=$fileEntryCount, Valid=$fileValidCount, Invalid=$fileInvalidCount" -LogLevel "Information"

            if ($fileValidCount -gt 0)
            {
                $result.Statistics.SuccessfulFiles++
            }
            else
            {
                $result.Statistics.FailedFiles++
                $errorMsg = "No valid entries found in file: $resolvedInput"
                Write-Log -LogFile $LogFile -Module $functionName -Message $errorMsg -LogLevel "Warning"
                $result.Errors += @{
                    Type    = "NoValidEntries"
                    File    = $resolvedInput
                    Message = $errorMsg
                }
            }
        }
        catch
        {
            $errorMsg = "Failed to process file '$resolvedInput'. Error: $($_.Exception.Message)"
            Write-Verbose "[$functionName] $errorMsg"
            Write-Log -LogFile $LogFile -Module $functionName -Message $errorMsg -LogLevel "Error"
            $result.Errors += @{
                Type      = "FileProcessingError"
                File      = $resolvedInput
                Message   = $errorMsg
                Exception = $_.Exception.Message
            }
            $result.Statistics.FailedFiles++
        }
    }

    # Batch device objects if needed
    if (-not $ValidateOnly -and $allDeviceObjects.Count -gt 0)
    {
        if ($SplitValue -lt $allDeviceObjects.Count)
        {
            Write-Verbose "[$functionName] Splitting $($allDeviceObjects.Count) devices into batches of $SplitValue"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Splitting $($allDeviceObjects.Count) devices into batches of $SplitValue" -LogLevel "Information"

            $result.Statistics.BatchCount = [Math]::Ceiling($allDeviceObjects.Count / $SplitValue)
            Write-Log -LogFile $LogFile -Module $functionName -Message "Created $($result.Statistics.BatchCount) batch(es) for processing" -LogLevel "Information"
        }
        else
        {
            $result.Statistics.BatchCount = 1
        }

        $result.DeviceObjects = $allDeviceObjects.ToArray()
        Write-Verbose "[$functionName] Prepared $($result.DeviceObjects.Count) device objects for Graph API import"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Prepared $($result.DeviceObjects.Count) device objects for Graph API import" -LogLevel "Information"
    }

    # Set success flag
    $result.Success = ($result.Statistics.ValidEntries -gt 0)

    Write-Verbose "[$functionName] Processing complete. Success: $($result.Success), Valid entries: $($result.Statistics.ValidEntries)"
    Write-Log -LogFile $LogFile -Module $functionName -Message "CSV import processing complete. Success=$($result.Success), ValidEntries=$($result.Statistics.ValidEntries), InvalidEntries=$($result.Statistics.InvalidEntries)" -LogLevel "Information"

    # Display summary if requested
    if ($ShowSummary)
    {
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "    AUTOPILOT CSV PROCESSING SUMMARY" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "Input Files:" -ForegroundColor Yellow
        Write-Host "  Total Input Files:        $($result.Statistics.TotalInputFiles)" -ForegroundColor White
        Write-Host "  Successfully Processed:   $($result.Statistics.SuccessfulFiles)" -ForegroundColor Green
        Write-Host "  Failed to Process:        $($result.Statistics.FailedFiles)" -ForegroundColor Red
        Write-Host "`nEntries:" -ForegroundColor Yellow
        Write-Host "  Total Entries:            $($result.Statistics.TotalEntriesProcessed)" -ForegroundColor White
        Write-Host "  Valid Entries:            $($result.Statistics.ValidEntries)" -ForegroundColor Green
        Write-Host "  Invalid Entries:          $($result.Statistics.InvalidEntries)" -ForegroundColor Red
        Write-Host "  Duplicate Entries:        $($result.Statistics.DuplicateEntries)" -ForegroundColor Yellow
        Write-Host "`nOutput:" -ForegroundColor Yellow
        Write-Host "  Device Objects Created:   $($result.DeviceObjects.Count)" -ForegroundColor White
        Write-Host "  Batch Count:              $($result.Statistics.BatchCount)" -ForegroundColor White
        Write-Host "`nStatus:" -ForegroundColor Yellow
        Write-Host "  Overall Success:          $($result.Success)" -ForegroundColor $(if ($result.Success)
            {
                'Green'
            }
            else
            {
                'Red'
            })
        Write-Host "  Errors:                   $($result.Errors.Count)" -ForegroundColor $(if ($result.Errors.Count -gt 0)
            {
                'Yellow'
            }
            else
            {
                'Green'
            })
        Write-Host "========================================`n" -ForegroundColor Cyan

        if ($result.Errors.Count -gt 0 -and $result.Errors.Count -le 10)
        {
            Write-Host "Error Details:" -ForegroundColor Yellow
            foreach ($errorMessage in $result.Errors)
            {
                Write-Host "  [$($errorMessage.Type)] $($errorMessage.Message)" -ForegroundColor Red
            }
            Write-Host ""
        }
        elseif ($result.Errors.Count -gt 10)
        {
            Write-Host "Error Details: ($($result.Errors.Count) errors - showing first 10)" -ForegroundColor Yellow
            foreach ($errorMessage in $result.Errors[0..9])
            {
                Write-Host "  [$($errorMessage.Type)] $($errorMessage.Message)" -ForegroundColor Red
            }
            Write-Host "  ... and $($result.Errors.Count - 10) more errors" -ForegroundColor Red
            Write-Host ""
        }
    }

    Write-Log -LogFile $LogFile -Module $functionName -Message "Function completed successfully. Returning result object with $($result.DeviceObjects.Count) device objects." -LogLevel "Information"
    return $result
}
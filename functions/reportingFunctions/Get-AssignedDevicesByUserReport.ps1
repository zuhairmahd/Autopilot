function Get-AssignedDevicesByUserReport()
{
    <#
    .SYNOPSIS
        Generates a report of assigned devices for specified users.

    .DESCRIPTION
        Prompts user to enter a list of usernames or read from a file, retrieves registered
        devices for those users, and displays or exports the results. Provides structured
        return values for proper integration with menu systems.

    .PARAMETER accessToken
        Access token for Microsoft Graph API authentication.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Returns structured object with:
        - Success: Boolean indicating operation success
        - Action: String describing the action taken ('UserCancelled', 'Displayed', 'Exported', 'NoDevices', 'Error')
        - DeviceCount: Number of devices found
        - UserCount: Number of users queried
        - ExportPath: Path to exported file (if applicable)
        - Message: Human-readable message describing the result
        - ErrorDetails: Additional error information (if applicable)

    .EXAMPLE
        $result = Get-AssignedDevicesByUserReport -accessToken $token
        if ($result.Success) {
            Write-Host "Successfully processed $($result.DeviceCount) devices for $($result.UserCount) users"
        }

    .NOTES
        Compatible with PowerShell 5.1
        Supports manual entry (E), file input (F), or quit (Q)
        Output options: View (V), Export (E), or Quit (Q)
    #>
    [CmdletBinding()]
    param(
        [string]$accessToken
    )

    $functionName = $MyInvocation.MyCommand.Name

    # Helper function to create return object
    function New-ReportResult
    {
        param(
            [bool]$Success,
            [string]$Action,
            [int]$DeviceCount = 0,
            [int]$UserCount = 0,
            [string]$ExportPath = '',
            [string]$Message = '',
            [string]$ErrorDetails = ''
        )
        return [PSCustomObject]@{
            Success      = $Success
            Action       = $Action
            DeviceCount  = $DeviceCount
            UserCount    = $UserCount
            ExportPath   = $ExportPath
            Message      = $Message
            ErrorDetails = $ErrorDetails
        }
    }

    Write-Host "How would you like to enter the user names?"
    $choice = Read-Host -Prompt "E to enter a list of users, F to read from file, Q to quit"
    Write-Verbose "[$functionName] User choice received: '$choice'"
    Write-Log -logFile $logFile -Module $functionName -Message "User choice received: '$choice'"
    while ($choice -notin @('E', 'F', 'Q'))
    {
        Write-Host "Invalid choice. Please enter E, F, or Q."
        [console]::beep()
        $choice = Read-Host -Prompt "E to enter a list of users, F to read from file, Q to quit"
        Write-Verbose "[$functionName] User choice received: '$choice'"
        Write-Log -logFile $logFile -Module $functionName -Message "User choice received: '$choice'"
    }
    [array]$userList = @()
    switch ($choice)
    {
        'E'
        {
            Write-Log -logFile $logFile -Module $functionName -Message "User chose to enter user names manually" -LogLevel "Information"
            do
            {
                $userInput = GetUserInput -Message "Enter a user name or an email address. Enter a blank line to continue" -Prompt "User name" -InputType "userName"
                Write-Verbose "[$functionName] User input received: '$userInput'"
                Write-Log -logFile $logFile -Module $functionName -Message "User input received: '$userInput'" -LogLevel "Verbose"
                if (-not ([string]::IsNullOrWhiteSpace($userInput)))
                {
                    Write-Log -logFile $logFile -Module $functionName -Message "Validated user input: '$userInput'"
                    [array]$userList += @($userInput)
                    Write-Log -LogFile $logFile -Module $functionName -Message "Added array value: '$userInput'" -LogLevel "Verbose"
                    Write-Verbose "[$functionName] Added array value: '$userInput'"
                }
            } until ([string]::IsNullOrWhiteSpace($userInput))
        }
        'F'
        {
            Write-Log -logFile $logFile -Module $functionName -Message "User chose to read user names from file" -LogLevel "Information"
            $filePath = Read-Host "Enter the full path to the file containing user principal names (one per line)"
            if (Test-Path $filePath)
            {
                $userInput = Get-Content -Path $filePath | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
                foreach ($user in $userInput)
                {
                    $validUserInput = validateInput -userInput $user -Type 'username'
                    if ($validUserInput.valid)
                    {
                        Write-Log -logFile $logFile -Module $functionName -Message "Validated user input from file: '$user'"
                        $userList += $validUserInput.value
                        Write-Log -LogFile $logFile -Module $functionName -Message "Added array value from file: '$user'" -LogLevel "Verbose"
                        Write-Verbose "[$functionName] Added array value from file: '$user'"
                    }
                    else
                    {
                        Write-Host "Invalid user name or email address in file: '$user'. Skipping." -ForegroundColor Red
                        Write-Log -logFile $logFile -Module $functionName -Message "Invalid user input from file: '$user'" -LogLevel "Warning"
                        continue
                    }
                }
            }
            else
            {
                Write-Host "File not found: $filePath" -ForegroundColor Red
                Write-Log -logFile $logFile -Module $functionName -Message "File not found: $filePath" -LogLevel "Error"
                return New-ReportResult -Success $false -Action 'Error' -Message "File not found: $filePath" -ErrorDetails "The specified file path does not exist"
            }
        }
        'Q'
        {
            Write-Log -logFile $logFile -Module $functionName -Message "User chose to quit assigned devices by user report." -LogLevel "Information"
            Write-Host "Exiting assigned devices by user report." -ForegroundColor Yellow
            return New-ReportResult -Success $true -Action 'UserCancelled' -Message "User cancelled the operation"
        }
    }
    Write-Host "Getting devices for $($userList.count) users:`n $($userList -join ', ')" -ForegroundColor Cyan

    # Validate we have users to query
    if ($null -eq $userList -or $userList.count -eq 0)
    {
        Write-Host "No valid users were entered." -ForegroundColor Yellow
        Write-Log -logFile $logFile -Module $functionName -Message "No valid users were entered." -LogLevel "Warning"
        return New-ReportResult -Success $false -Action 'Error' -Message "No valid users were entered" -ErrorDetails "User list was empty or null"
    }

    $deviceList = Get-RegisteredDevicesByUser -usersList $userList -accessToken $accessToken
    Write-Verbose "[$functionName] Retrieved $($deviceList.count) devices for $($userList.count) users."
    Write-Log -logFile $logFile -Module $functionName -Message "Retrieved $($deviceList.count) devices for $($userList.count) users." -LogLevel "Information"
    if ($deviceList.count -gt 0)
    {
        Write-Host "Press V to view the report on screen, E to export to CSV, or Q to quit."
        $outputChoice = Read-Host -Prompt "V/E/Q"
        Write-Verbose "[$functionName] User output choice received: '$outputChoice'"
        Write-Log -logFile $logFile -Module $functionName -Message "User output choice received: '$outputChoice'" -LogLevel "Information"
        while ($outputChoice -notin @('V', 'E', 'Q'))
        {
            Write-Host "Invalid choice. Please enter V, E, or Q."
            [console]::beep()
            $outputChoice = Read-Host -Prompt "V to view the report on screen, E to export to CSV, or Q to quit."
            Write-Log -logFile $logFile -Module $functionName -Message "User output choice received: '$outputChoice'" -LogLevel "Information"
        }

        switch ($outputChoice)
        {
            'V'
            {
                # Define display scriptblock for device objects
                Write-Verbose "[$functionName] Preparing to display device list on screen."
                Write-Log -logFile $logFile -Module $functionName -Message "Preparing to display device list on screen." -LogLevel "Information"
                $deviceDisplayScript = {
                    param($device)
                    Write-Host "----------------------------------------" -ForegroundColor DarkGray
                    Write-Host "User:           " -NoNewline -ForegroundColor Cyan
                    Write-Host $device.UserName -ForegroundColor White
                    Write-Host "Device Name:    " -NoNewline -ForegroundColor Cyan
                    Write-Host $device.DisplayName -ForegroundColor White
                    Write-Host "Device ID:      " -NoNewline -ForegroundColor Cyan
                    Write-Host $device.DeviceId -ForegroundColor Gray
                    Write-Host "Manufacturer:   " -NoNewline -ForegroundColor Cyan
                    Write-Host "$($device.Manufacturer) $($device.Model)" -ForegroundColor White
                    Write-Host "OS:             " -NoNewline -ForegroundColor Cyan
                    Write-Host "$($device.OperatingSystem) $($device.OperatingSystemVersion)" -ForegroundColor White
                    Write-Host "Status:         " -NoNewline -ForegroundColor Cyan
                    $statusColor = if ($device.AccountEnabled) { "Green" } else { "Red" }
                    $statusText = if ($device.AccountEnabled) { "Enabled" } else { "Disabled" }
                    Write-Host $statusText -ForegroundColor $statusColor
                    Write-Host "Compliance:     " -NoNewline -ForegroundColor Cyan
                    $complianceColor = if ($device.IsCompliant) { "Green" } else { "Yellow" }
                    $complianceText = if ($device.IsCompliant) { "Compliant" } else { "Non-Compliant" }
                    Write-Host $complianceText -ForegroundColor $complianceColor
                    Write-Host "Managed:        " -NoNewline -ForegroundColor Cyan
                    Write-Host $(if ($device.IsManaged) { "Yes" } else { "No" }) -ForegroundColor White
                    Write-Host "Trust Type:     " -NoNewline -ForegroundColor Cyan
                    Write-Host $device.DeviceTrustType -ForegroundColor White
                    Write-Host "Ownership:      " -NoNewline -ForegroundColor Cyan
                    Write-Host $device.DeviceOwnership -ForegroundColor White
                    Write-Host "Enrollment:     " -NoNewline -ForegroundColor Cyan
                    Write-Host $device.EnrollmentType -ForegroundColor White
                    Write-Host "Registered:     " -NoNewline -ForegroundColor Cyan
                    Write-Host $device.RegistrationDateTime -ForegroundColor White
                    Write-Host "Last Sign-in:   " -NoNewline -ForegroundColor Cyan
                    Write-Host $device.ApproximateLastSignInDateTime -ForegroundColor White
                    Write-Host ""
                }
                # Display 1 device per page since devices take up 16 lines per device
                $pageChoice = Show-PagedContent -Content $deviceList -PageSize 1 -DisplayScriptBlock $deviceDisplayScript -Title "Device list by user"
                Write-Verbose "[$functionName] User page choice received: '$pageChoice'"
                Write-Log -logFile $logFile -Module $functionName -Message "User page choice received: '$pageChoice'" -LogLevel "Information"
                if ($pageChoice -notin @('completed', 'quit') )
                {
                    Write-Host "An error occurred while displaying the report: $pageChoice" -ForegroundColor Red
                    Write-Log -logFile $logFile -Module $functionName -Message "An error occurred while displaying the report: $pageChoice" -LogLevel "Error"
                    return New-ReportResult -Success $false -Action 'Error' -DeviceCount $deviceList.count -UserCount $userList.count -Message "Error displaying report" -ErrorDetails $pageChoice
                }
                else
                {
                    Write-Verbose "[$functionName] User completed viewing the report display."
                    Write-Log -logFile $logFile -Module $functionName -Message "User completed viewing the report display." -LogLevel "Information"
                    return New-ReportResult -Success $true -Action 'Displayed' -DeviceCount $deviceList.count -UserCount $userList.count -Message "Successfully displayed $($deviceList.count) devices for $($userList.count) users"
                }
            }
            'E'
            {
                $dateTime = Get-Date -Format "yyyyMMdd_HHmm"
                $outputFileName = "AssignedDevicesByUserReport-$dateTime.csv"
                Write-Log -logFile $logFile -Module $functionName -Message "Exporting report to CSV file: $outputFileName" -LogLevel "Information"
                Write-Verbose "[$functionName] Exporting report to CSV file: $outputFileName"
                $deviceList | Export-Csv -Path $outputFileName -NoTypeInformation -Force
                Write-Host "Report exported successfully to $outputFileName" -ForegroundColor Green
                Write-Log -logFile $logFile -Module $functionName -Message "Report exported successfully to $outputFileName" -LogLevel "Information"
                return New-ReportResult -Success $true -Action 'Exported' -DeviceCount $deviceList.count -UserCount $userList.count -ExportPath $outputFileName -Message "Successfully exported $($deviceList.count) devices to $outputFileName"
            }
            'Q'
            {
                Write-Host "Exiting assigned devices by user report." -ForegroundColor Yellow
                Write-Log -logFile $logFile -Module $functionName -Message "User chose to quit assigned devices by user report." -LogLevel "Information"
                Write-Verbose "[$functionName] User chose to quit assigned devices by user report."
                return New-ReportResult -Success $true -Action 'UserCancelled' -DeviceCount $deviceList.count -UserCount $userList.count -Message "User cancelled after retrieving devices"
            }
        }
    }
    else
    {
        Write-Host "No devices found for the specified users." -ForegroundColor Yellow
        Write-Log -logFile $logFile -Module $functionName -Message "No devices found for the specified users." -LogLevel "Information"
        Write-Verbose "[$functionName] No devices found for the specified users."
        return New-ReportResult -Success $true -Action 'NoDevices' -DeviceCount 0 -UserCount $userList.count -Message "No devices found for $($userList.count) users"
    }
    Write-Verbose "[$functionName] Completed Get-AssignedDevicesByUserReport function."
    Write-Log -logFile $logFile -Module $functionName -Message "Completed Get-AssignedDevicesByUserReport function." -LogLevel "Information"

    # Should not reach here, but return a generic success if we do
    return New-ReportResult -Success $true -Action 'Completed' -Message "Report generation completed"
}
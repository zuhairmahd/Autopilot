BeforeAll {
    # Import test helpers
    Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force
    Import-Module "$PSScriptRoot/../Helpers/AutopilotGraphMocks.psm1" -Force

    # Get repository root
    $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
    
    # Dot-source required functions
    . "$script:RepoRoot/functions/reportingFunctions/Get-RegisteredDevicesByUser.ps1"
    . "$script:RepoRoot/functions/utilityFunctions/Show-PagedContent.ps1"
    . "$script:RepoRoot/functions/graphFunctions/CallGraphAPI.ps1"
    . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
    . "$script:RepoRoot/functions/utilityFunctions/FormatDateWithTimeZone.ps1"
    . "$script:RepoRoot/functions/utilityFunctions/GetTimeZoneAbbreviation.ps1"
    . "$script:RepoRoot/functions/utilityFunctions/Get-CachedData.ps1"
    
    # Set up global variables
    $global:logFile = "TestDrive:\test.log"
    $global:settings = @{
        operatingSystem  = "Windows"
        deviceNamePrefix = "CORP-"
    }
}

Describe "Assigned Devices by User - Display Integration" -Tags 'Integration', 'DeviceDisplay' {
    
    Context "Complete Flow: Get-RegisteredDevicesByUser to Show-PagedContent" {
        BeforeAll {
            # Mock Graph API response with realistic device data
            Mock CallGraphAPI {
                param($accessToken, $ResourcePath)
                
                # Determine which users are being queried
                $batchItems = @()
                $requestId = 1
                
                # Check if this is a batch request (array) or single request
                if ($ResourcePath -is [array])
                {
                    foreach ($path in $ResourcePath)
                    {
                        if ($path -like '*user1@domain.com*')
                        {
                            $batchItems += @{
                                id     = $requestId
                                status = 200
                                body   = @{
                                    value = @(
                                        @{
                                            id                            = '12345678-1234-1234-1234-123456789012'
                                            displayName                   = 'CORP-LAPTOP-001'
                                            manufacturer                  = 'Dell Inc.'
                                            model                         = 'Latitude 7490'
                                            operatingSystem               = 'Windows'
                                            operatingSystemVersion        = '10.0.19045.3570'
                                            accountEnabled                = $true
                                            approximateLastSignInDateTime = '2025-11-20T10:30:00Z'
                                            trustType                     = 'AzureAd'
                                            isCompliant                   = $true
                                            isManaged                     = $true
                                            deviceOwnership               = 'Company'
                                            enrollmentType                = 'AzureADJoined'
                                            registrationDateTime          = '2025-01-15T09:00:00Z'
                                        },
                                        @{
                                            id                            = '87654321-4321-4321-4321-210987654321'
                                            displayName                   = 'CORP-DESKTOP-002'
                                            manufacturer                  = 'HP'
                                            model                         = 'EliteDesk 800'
                                            operatingSystem               = 'Windows'
                                            operatingSystemVersion        = '10.0.22631.2506'
                                            accountEnabled                = $false
                                            approximateLastSignInDateTime = '2025-11-15T14:20:00Z'
                                            trustType                     = 'Hybrid'
                                            isCompliant                   = $false
                                            isManaged                     = $true
                                            deviceOwnership               = 'Personal'
                                            enrollmentType                = 'WindowsAutoEnrollment'
                                            registrationDateTime          = '2025-03-10T11:30:00Z'
                                        }
                                    )
                                }
                            }
                        }
                        elseif ($path -like '*user2@domain.com*')
                        {
                            $batchItems += @{
                                id     = $requestId
                                status = 200
                                body   = @{
                                    value = @(
                                        @{
                                            id                            = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
                                            displayName                   = 'CORP-SURFACE-003'
                                            manufacturer                  = 'Microsoft'
                                            model                         = 'Surface Pro 9'
                                            operatingSystem               = 'Windows'
                                            operatingSystemVersion        = '11.0.22631.2506'
                                            accountEnabled                = $true
                                            approximateLastSignInDateTime = '2025-11-28T08:15:00Z'
                                            trustType                     = 'AzureAd'
                                            isCompliant                   = $true
                                            isManaged                     = $true
                                            deviceOwnership               = 'Company'
                                            enrollmentType                = 'AzureADJoined'
                                            registrationDateTime          = '2025-02-01T10:00:00Z'
                                        }
                                    )
                                }
                            }
                        }
                        $requestId++
                    }
                    
                    return @{
                        batchProcessed = $true
                        successCount   = $batchItems.Count
                        failureCount   = 0
                        value          = $batchItems
                    }
                }
                else
                {
                    # Single request - return based on path
                    if ($ResourcePath -like '*user1@domain.com*')
                    {
                        return @{
                            value = @(
                                @{
                                    id                            = '12345678-1234-1234-1234-123456789012'
                                    displayName                   = 'CORP-LAPTOP-001'
                                    manufacturer                  = 'Dell Inc.'
                                    model                         = 'Latitude 7490'
                                    operatingSystem               = 'Windows'
                                    operatingSystemVersion        = '10.0.19045.3570'
                                    accountEnabled                = $true
                                    approximateLastSignInDateTime = '2025-11-20T10:30:00Z'
                                    trustType                     = 'AzureAd'
                                    isCompliant                   = $true
                                    isManaged                     = $true
                                    deviceOwnership               = 'Company'
                                    enrollmentType                = 'AzureADJoined'
                                    registrationDateTime          = '2025-01-15T09:00:00Z'
                                },
                                @{
                                    id                            = '87654321-4321-4321-4321-210987654321'
                                    displayName                   = 'CORP-DESKTOP-002'
                                    manufacturer                  = 'HP'
                                    model                         = 'EliteDesk 800'
                                    operatingSystem               = 'Windows'
                                    operatingSystemVersion        = '10.0.22631.2506'
                                    accountEnabled                = $false
                                    approximateLastSignInDateTime = '2025-11-15T14:20:00Z'
                                    trustType                     = 'Hybrid'
                                    isCompliant                   = $false
                                    isManaged                     = $true
                                    deviceOwnership               = 'Personal'
                                    enrollmentType                = 'WindowsAutoEnrollment'
                                    registrationDateTime          = '2025-03-10T11:30:00Z'
                                }
                            )
                        }
                    }
                    elseif ($ResourcePath -like '*user2@domain.com*')
                    {
                        return @{
                            value = @(
                                @{
                                    id                            = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
                                    displayName                   = 'CORP-SURFACE-003'
                                    manufacturer                  = 'Microsoft'
                                    model                         = 'Surface Pro 9'
                                    operatingSystem               = 'Windows'
                                    operatingSystemVersion        = '11.0.22631.2506'
                                    accountEnabled                = $true
                                    approximateLastSignInDateTime = '2025-11-28T08:15:00Z'
                                    trustType                     = 'AzureAd'
                                    isCompliant                   = $true
                                    isManaged                     = $true
                                    deviceOwnership               = 'Company'
                                    enrollmentType                = 'AzureADJoined'
                                    registrationDateTime          = '2025-02-01T10:00:00Z'
                                }
                            )
                        }
                    }
                }
            }
            
            # Define the display scriptblock (matching main.ps1)
            $script:deviceDisplayScript = {
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
        }
        
        BeforeEach {
            # Clear cache before each test
            if ($global:UnifiedCache)
            {
                $global:UnifiedCache.DirectoryObjects.Clear()
            }
        }
        
        It "Should retrieve and display devices for multiple users" {
            Mock Write-Host {}
            
            # Get devices for users
            $userList = @('user1@domain.com', 'user2@domain.com')
            $deviceList = Get-RegisteredDevicesByUser -usersList $userList -accessToken "test-token"
            
            # Verify devices were retrieved
            $deviceList | Should -Not -BeNullOrEmpty
            $deviceList.Count | Should -Be 3
            
            # Display devices - use PageSize of 1 to test paging
            $result = Show-PagedContent -Content $deviceList -PageSize 1 -DisplayScriptBlock $deviceDisplayScript -Title "Device list by user" -Silent
            
            $result | Should -Be "completed"
        }
        
        It "Should properly format device properties in display" {
            Mock Write-Host {}
            
            # Get devices
            $userList = @('user1@domain.com')
            $deviceList = Get-RegisteredDevicesByUser -usersList $userList -accessToken "test-token"
            
            # Display first device
            Show-PagedContent -Content $deviceList[0] -DisplayScriptBlock $deviceDisplayScript -NoPaging
            
            # Verify key information is displayed
            Should -Invoke Write-Host -ParameterFilter { $Object -eq 'user1@domain.com' }
            Should -Invoke Write-Host -ParameterFilter { $Object -eq 'CORP-LAPTOP-001' }
            Should -Invoke Write-Host -ParameterFilter { $Object -eq 'Dell Inc. Latitude 7490' }
            Should -Invoke Write-Host -ParameterFilter { $Object -eq 'Windows 10.0.19045.3570' }
            Should -Invoke Write-Host -ParameterFilter { $Object -eq 'Enabled' -and $ForegroundColor -eq 'Green' }
            Should -Invoke Write-Host -ParameterFilter { $Object -eq 'Compliant' -and $ForegroundColor -eq 'Green' }
        }
        
        It "Should display multiple devices with different statuses correctly" {
            Mock Write-Host {}
            
            # Get devices - note that filtering is applied (Windows OS, CORP- prefix)
            $userList = @('user1@domain.com')
            $deviceList = Get-RegisteredDevicesByUser -usersList $userList -accessToken "test-token"
            
            # Display all devices
            Show-PagedContent -Content $deviceList -DisplayScriptBlock $deviceDisplayScript -NoPaging
            
            # After filtering by Windows and CORP- prefix, we should have 2 devices:
            # - CORP-LAPTOP-001 (enabled, compliant)
            # - CORP-DESKTOP-002 (disabled, non-compliant)
            $deviceList.Count | Should -Be 2
            
            # Verify enabled device (1 time)
            Should -Invoke Write-Host -Times 1 -ParameterFilter { $Object -eq 'Enabled' -and $ForegroundColor -eq 'Green' }
            
            # Verify disabled device (1 time)
            Should -Invoke Write-Host -Times 1 -ParameterFilter { $Object -eq 'Disabled' -and $ForegroundColor -eq 'Red' }
            
            # Verify compliant devices (1 time)
            Should -Invoke Write-Host -Times 1 -ParameterFilter { $Object -eq 'Compliant' -and $ForegroundColor -eq 'Green' }
            
            # Verify non-compliant device (1 time)
            Should -Invoke Write-Host -Times 1 -ParameterFilter { $Object -eq 'Non-Compliant' -and $ForegroundColor -eq 'Yellow' }
        }
        
        It "Should filter devices by operating system" {
            Mock Write-Host {}
            
            # Update settings to filter by Windows
            $global:settings.operatingSystem = "Windows"
            
            # Get devices
            $userList = @('user1@domain.com')
            $deviceList = Get-RegisteredDevicesByUser -usersList $userList -accessToken "test-token"
            
            # Verify all devices are Windows
            $deviceList | Should -Not -BeNullOrEmpty
            $deviceList | ForEach-Object { $_.OperatingSystem | Should -Be "Windows" }
        }
        
        It "Should filter devices by device name prefix" {
            Mock Write-Host {}
            
            # Settings already has CORP- prefix
            $userList = @('user1@domain.com')
            $deviceList = Get-RegisteredDevicesByUser -usersList $userList -accessToken "test-token"
            
            # Verify all devices start with prefix
            $deviceList | Should -Not -BeNullOrEmpty
            $deviceList | ForEach-Object { $_.DisplayName | Should -BeLike "CORP-*" }
        }
        
        It "Should handle empty device results gracefully" {
            Mock Write-Host {}
            Mock CallGraphAPI {
                return @{
                    batchProcessed = $true
                    successCount   = 1
                    failureCount   = 0
                    value          = @(
                        @{
                            id     = 1
                            status = 200
                            body   = @{
                                value = @()
                            }
                        }
                    )
                }
            }
            
            $userList = @('user3@domain.com')
            $deviceList = Get-RegisteredDevicesByUser -usersList $userList -accessToken "test-token"
            
            $deviceList.Count | Should -Be 0
            
            # Display should handle empty list
            $result = Show-PagedContent -Content $deviceList -DisplayScriptBlock $deviceDisplayScript -Silent
            $result | Should -Be "completed"
        }
    }
    
    Context "Error Scenarios" {
        BeforeEach {
            # Clear cache before each test to ensure clean state
            if ($global:UnifiedCache)
            {
                $global:UnifiedCache.DirectoryObjects.Clear()
            }
        }
        
        It "Should handle Graph API failures gracefully" {
            Mock Write-Host {}
            Mock Write-Warning {}
            Mock CallGraphAPI {
                return $null
            }
            
            $userList = @('user1@domain.com')
            $deviceList = Get-RegisteredDevicesByUser -usersList $userList -accessToken "test-token"
            
            $deviceList | Should -BeNullOrEmpty
        }
        
        It "Should handle partial batch failures" {
            Mock Write-Host {}
            Mock Write-Warning {}
            Mock CallGraphAPI {
                return @{
                    batchProcessed = $true
                    successCount   = 1
                    failureCount   = 1
                    value          = @(
                        @{
                            id     = 1
                            status = 200
                            body   = @{
                                value = @(
                                    @{
                                        id                            = '12345678-1234-1234-1234-123456789012'
                                        displayName                   = 'CORP-LAPTOP-001'
                                        manufacturer                  = 'Dell Inc.'
                                        model                         = 'Latitude 7490'
                                        operatingSystem               = 'Windows'
                                        operatingSystemVersion        = '10.0.19045.3570'
                                        accountEnabled                = $true
                                        approximateLastSignInDateTime = '2025-11-20T10:30:00Z'
                                        trustType                     = 'AzureAd'
                                        isCompliant                   = $true
                                        isManaged                     = $true
                                        deviceOwnership               = 'Company'
                                        enrollmentType                = 'AzureADJoined'
                                        registrationDateTime          = '2025-01-15T09:00:00Z'
                                    }
                                )
                            }
                        },
                        @{
                            id     = 2
                            status = 404
                            body   = @{
                                error = @{
                                    message = "User not found"
                                }
                            }
                        }
                    )
                }
            }
            
            $userList = @('user1@domain.com', 'nonexistent@domain.com')
            $deviceList = Get-RegisteredDevicesByUser -usersList $userList -accessToken "test-token"
            
            # Should return devices from successful request
            $deviceList.Count | Should -Be 1
            $deviceList[0].DisplayName | Should -Be 'CORP-LAPTOP-001'
        }
    }
    
    Context "Large Dataset Performance" {
        BeforeEach {
            # Clear cache before test
            if ($global:UnifiedCache)
            {
                $global:UnifiedCache.DirectoryObjects.Clear()
            }
        }
        
        It "Should handle large number of devices efficiently" {
            Mock Write-Host {}
            
            # Mock large dataset
            $largeDeviceArray = @()
            for ($i = 1; $i -le 50; $i++)
            {
                # Generate valid day (1-28) with leading zero
                $day = ($i % 28) + 1
                $dayString = "{0:D2}" -f $day
                $largeDeviceArray += @{
                    id                            = "device-$i"
                    displayName                   = "CORP-DEVICE-$i"
                    manufacturer                  = "Manufacturer $i"
                    model                         = "Model $i"
                    operatingSystem               = "Windows"
                    operatingSystemVersion        = "10.0.$i"
                    accountEnabled                = ($i % 2 -eq 0)
                    approximateLastSignInDateTime = "2025-11-${dayString}T10:00:00Z"
                    trustType                     = "AzureAd"
                    isCompliant                   = ($i % 3 -eq 0)
                    isManaged                     = $true
                    deviceOwnership               = "Company"
                    enrollmentType                = "AzureADJoined"
                    registrationDateTime          = "2025-01-01T09:00:00Z"
                }
            }
            
            Mock CallGraphAPI {
                return @{
                    batchProcessed = $true
                    successCount   = 1
                    failureCount   = 0
                    value          = @(
                        @{
                            id     = 1
                            status = 200
                            body   = @{
                                value = $largeDeviceArray
                            }
                        }
                    )
                }
            }
            
            $userList = @('user1@domain.com')
            $deviceList = Get-RegisteredDevicesByUser -usersList $userList -accessToken "test-token"
            
            $deviceList.Count | Should -Be 50
            
            # Display should handle large list with paging - use PageSize of 1 to test paging
            $result = Show-PagedContent -Content $deviceList -PageSize 1 -DisplayScriptBlock $deviceDisplayScript -Silent
            $result | Should -Be "completed"
        }
    }
}

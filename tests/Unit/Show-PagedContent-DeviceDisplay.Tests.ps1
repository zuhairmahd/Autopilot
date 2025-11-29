BeforeAll {
    # Import test helpers
    Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

    # Get repository root
    $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
    
    # Dot-source required functions
    . "$script:RepoRoot/functions/utilityFunctions/Show-PagedContent.ps1"
    . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
    
    # Set up test log file variable
    $global:logFile = "TestDrive:\test.log"
}

Describe "Show-PagedContent with Device Objects" -Tags 'Unit', 'Show-PagedContent' {
    
    Context "Device Display ScriptBlock" {
        BeforeAll {
            # Create sample device objects matching Get-RegisteredDevicesByUser output
            $script:sampleDevice1 = [PSCustomObject]@{
                UserName                      = 'user1@domain.com'
                DeviceId                      = '12345678-1234-1234-1234-123456789012'
                DisplayName                   = 'LAPTOP-001'
                Manufacturer                  = 'Dell Inc.'
                Model                         = 'Latitude 7490'
                OperatingSystem               = 'Windows'
                OperatingSystemVersion        = '10.0.19045.3570'
                AccountEnabled                = $true
                ApproximateLastSignInDateTime = '2025-11-20T10:30:00Z'
                DeviceTrustType               = 'AzureAd'
                IsCompliant                   = $true
                IsManaged                     = $true
                DeviceOwnership               = 'Company'
                EnrollmentType                = 'AzureADJoined'
                RegistrationDateTime          = '2025-01-15T09:00:00Z'
            }
            
            $script:sampleDevice2 = [PSCustomObject]@{
                UserName                      = 'user2@domain.com'
                DeviceId                      = '87654321-4321-4321-4321-210987654321'
                DisplayName                   = 'DESKTOP-002'
                Manufacturer                  = 'HP'
                Model                         = 'EliteDesk 800'
                OperatingSystem               = 'Windows'
                OperatingSystemVersion        = '10.0.22631.2506'
                AccountEnabled                = $false
                ApproximateLastSignInDateTime = '2025-11-15T14:20:00Z'
                DeviceTrustType               = 'Hybrid'
                IsCompliant                   = $false
                IsManaged                     = $true
                DeviceOwnership               = 'Personal'
                EnrollmentType                = 'WindowsAutoEnrollment'
                RegistrationDateTime          = '2025-03-10T11:30:00Z'
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
        
        It "Should display single device without paging" {
            Mock Write-Host {}
            
            $result = Show-PagedContent -Content $sampleDevice1 -DisplayScriptBlock $deviceDisplayScript -Silent
            
            $result | Should -Be "completed"
        }
        
        It "Should display multiple devices without paging when count is less than PageSize" {
            Mock Write-Host {}
            
            $devices = @($sampleDevice1, $sampleDevice2)
            $result = Show-PagedContent -Content $devices -PageSize 10 -DisplayScriptBlock $deviceDisplayScript -Silent
            
            $result | Should -Be "completed"
        }
        
        It "Should handle device with enabled status correctly" {
            Mock Write-Host {}
            
            Show-PagedContent -Content $sampleDevice1 -DisplayScriptBlock $deviceDisplayScript -NoPaging
            
            Should -Invoke Write-Host -ParameterFilter {
                $Object -eq 'Enabled' -and $ForegroundColor -eq 'Green'
            }
        }
        
        It "Should handle device with disabled status correctly" {
            Mock Write-Host {}
            
            Show-PagedContent -Content $sampleDevice2 -DisplayScriptBlock $deviceDisplayScript -NoPaging
            
            Should -Invoke Write-Host -ParameterFilter {
                $Object -eq 'Disabled' -and $ForegroundColor -eq 'Red'
            }
        }
        
        It "Should handle compliant device correctly" {
            Mock Write-Host {}
            
            Show-PagedContent -Content $sampleDevice1 -DisplayScriptBlock $deviceDisplayScript -NoPaging
            
            Should -Invoke Write-Host -ParameterFilter {
                $Object -eq 'Compliant' -and $ForegroundColor -eq 'Green'
            }
        }
        
        It "Should handle non-compliant device correctly" {
            Mock Write-Host {}
            
            Show-PagedContent -Content $sampleDevice2 -DisplayScriptBlock $deviceDisplayScript -NoPaging
            
            Should -Invoke Write-Host -ParameterFilter {
                $Object -eq 'Non-Compliant' -and $ForegroundColor -eq 'Yellow'
            }
        }
        
        It "Should display all device properties" {
            Mock Write-Host {}
            
            Show-PagedContent -Content $sampleDevice1 -DisplayScriptBlock $deviceDisplayScript -NoPaging
            
            # Verify key properties are displayed
            Should -Invoke Write-Host -ParameterFilter { $Object -eq 'user1@domain.com' }
            Should -Invoke Write-Host -ParameterFilter { $Object -eq 'LAPTOP-001' }
            Should -Invoke Write-Host -ParameterFilter { $Object -eq '12345678-1234-1234-1234-123456789012' }
            Should -Invoke Write-Host -ParameterFilter { $Object -eq 'Dell Inc. Latitude 7490' }
            Should -Invoke Write-Host -ParameterFilter { $Object -eq 'Windows 10.0.19045.3570' }
            Should -Invoke Write-Host -ParameterFilter { $Object -eq 'AzureAd' }
            Should -Invoke Write-Host -ParameterFilter { $Object -eq 'Company' }
            Should -Invoke Write-Host -ParameterFilter { $Object -eq 'AzureADJoined' }
        }
        
        It "Should handle null or missing device properties gracefully" {
            Mock Write-Host {}
            
            $incompleteDevice = [PSCustomObject]@{
                UserName        = 'user3@domain.com'
                DeviceId        = '00000000-0000-0000-0000-000000000000'
                DisplayName     = 'INCOMPLETE-DEVICE'
                Manufacturer    = $null
                Model           = $null
                OperatingSystem = $null
            }
            
            { Show-PagedContent -Content $incompleteDevice -DisplayScriptBlock $deviceDisplayScript -Silent } | Should -Not -Throw
        }
    }
    
    Context "Device List Display with Paging" {
        BeforeAll {
            # Create multiple devices for paging tests
            $script:deviceList = @()
            for ($i = 1; $i -le 25; $i++) {
                $script:deviceList += [PSCustomObject]@{
                    UserName                      = "user$i@domain.com"
                    DeviceId                      = "device-id-$i"
                    DisplayName                   = "DEVICE-$i"
                    Manufacturer                  = "Manufacturer $i"
                    Model                         = "Model $i"
                    OperatingSystem               = "Windows"
                    OperatingSystemVersion        = "10.0.$i"
                    AccountEnabled                = ($i % 2 -eq 0)
                    ApproximateLastSignInDateTime = "2025-11-$i`T10:00:00Z"
                    DeviceTrustType               = "AzureAd"
                    IsCompliant                   = ($i % 3 -eq 0)
                    IsManaged                     = $true
                    DeviceOwnership               = "Company"
                    EnrollmentType                = "AzureADJoined"
                    RegistrationDateTime          = "2025-01-$i`T09:00:00Z"
                }
            }
        }
        
        It "Should handle large device lists in silent mode" {
            Mock Write-Host {}
            
            $result = Show-PagedContent -Content $deviceList -PageSize 3 -DisplayScriptBlock $deviceDisplayScript -Silent -Title "Device list by user"
            
            $result | Should -Be "completed"
        }
        
        It "Should display correct page size" {
            Mock Write-Host {}
            
            Show-PagedContent -Content $deviceList -PageSize 10 -DisplayScriptBlock $deviceDisplayScript -NoPaging
            
            # Verify invocations count - should be called for all 25 devices when NoPaging is used
            Should -Invoke Write-Host -Times 25 -ParameterFilter { $Object -match '^DEVICE-\d+$' }
        }
        
        It "Should handle empty device list" {
            Mock Write-Host {}
            
            $emptyList = @()
            $result = Show-PagedContent -Content $emptyList -DisplayScriptBlock $deviceDisplayScript
            
            $result | Should -Be "completed"
            Should -Invoke Write-Host -ParameterFilter { $Object -eq 'No content to display.' }
        }
        
        It "Should handle null device list" {
            Mock Write-Host {}
            
            $result = Show-PagedContent -Content $null -DisplayScriptBlock $deviceDisplayScript
            
            $result | Should -Be "completed"
            Should -Invoke Write-Host -ParameterFilter { $Object -eq 'No content to display.' }
        }
    }
    
    Context "Error Handling" {
        It "Should return error message when DisplayScriptBlock is missing for device objects" {
            Mock Write-Host {}
            Mock Write-Warning {}
            
            $result = Show-PagedContent -Content $sampleDevice1
            
            $result | Should -BeLike "error:*"
        }
        
        It "Should handle exceptions in DisplayScriptBlock gracefully" {
            Mock Write-Host {}
            Mock Write-Warning {}
            
            $faultyScript = {
                param($device)
                throw "Intentional error"
            }
            
            { Show-PagedContent -Content $sampleDevice1 -DisplayScriptBlock $faultyScript -Silent } | Should -Not -Throw
        }
    }
    
    Context "Integration with PageSize Settings" {
        It "Should respect custom PageSize parameter" {
            Mock Write-Host {}
            
            $result = Show-PagedContent -Content $deviceList -PageSize 5 -DisplayScriptBlock $deviceDisplayScript -Silent
            
            $result | Should -Be "completed"
        }
        
        It "Should handle PageSize larger than device count" {
            Mock Write-Host {}
            
            $devices = @($sampleDevice1, $sampleDevice2)
            $result = Show-PagedContent -Content $devices -PageSize 100 -DisplayScriptBlock $deviceDisplayScript -Silent
            
            $result | Should -Be "completed"
        }
    }
}

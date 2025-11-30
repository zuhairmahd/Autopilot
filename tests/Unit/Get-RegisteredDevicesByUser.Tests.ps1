BeforeAll {
    # Import test helpers
    Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

    # Get repository root
    $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
    
    # Dot-source required functions
    . "$script:RepoRoot/functions/reportingFunctions/Get-RegisteredDevicesByUser.ps1"
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
    $global:cacheSettings = @{
        enabled                  = $true
        defaultExpirationMinutes = 15
        maxCacheSize             = 1000
        cacheTypes               = @{
            DirectoryObjects = @{
                enabled           = $true
                expirationMinutes = 15
            }
        }
    }
    
    # Initialize unified cache
    if (-not $global:UnifiedCache)
    {
        $global:UnifiedCache = @{
            Configuration    = @{}
            DirectoryObjects = @{}
            Devices          = @{}
        }
    }
}

Describe "Get-RegisteredDevicesByUser" -Tags 'Unit', 'Reporting' {
    
    BeforeEach {
        # Clear cache before each test
        if ($global:UnifiedCache)
        {
            $global:UnifiedCache.DirectoryObjects.Clear()
        }
        
        # Reset settings
        $global:settings.operatingSystem = "Windows"
        $global:settings.deviceNamePrefix = "CORP-"
    }
    
    Context "Basic Functionality" {
        It "Should retrieve devices for a single user" {
            Mock CallGraphAPI {
                return @{
                    value = @(
                        @{
                            id                            = 'device-1'
                            displayName                   = 'CORP-LAPTOP-001'
                            manufacturer                  = 'Dell'
                            model                         = 'Latitude'
                            operatingSystem               = 'Windows'
                            operatingSystemVersion        = '10.0'
                            accountEnabled                = $true
                            approximateLastSignInDateTime = '2025-11-28T10:00:00Z'
                            trustType                     = 'AzureAd'
                            isCompliant                   = $true
                            isManaged                     = $true
                            deviceOwnership               = 'Company'
                            enrollmentType                = 'AzureADJoined'
                            registrationDateTime          = '2025-01-01T09:00:00Z'
                        }
                    )
                }
            }
            
            $result = Get-RegisteredDevicesByUser -usersList @('user1@domain.com') -accessToken 'test-token'
            
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 1
            $result[0].DisplayName | Should -Be 'CORP-LAPTOP-001'
            $result[0].UserName | Should -Be 'user1@domain.com'
        }
        
        It "Should retrieve devices for multiple users using batch API" {
            Mock CallGraphAPI {
                return @{
                    batchProcessed = $true
                    successCount   = 2
                    failureCount   = 0
                    value          = @(
                        @{
                            id     = 1
                            status = 200
                            body   = @{
                                value = @(
                                    @{
                                        id                            = 'device-1'
                                        displayName                   = 'CORP-LAPTOP-001'
                                        manufacturer                  = 'Dell'
                                        model                         = 'Latitude'
                                        operatingSystem               = 'Windows'
                                        operatingSystemVersion        = '10.0'
                                        accountEnabled                = $true
                                        approximateLastSignInDateTime = '2025-11-28T10:00:00Z'
                                        trustType                     = 'AzureAd'
                                        isCompliant                   = $true
                                        isManaged                     = $true
                                        deviceOwnership               = 'Company'
                                        enrollmentType                = 'AzureADJoined'
                                        registrationDateTime          = '2025-01-01T09:00:00Z'
                                    }
                                )
                            }
                        },
                        @{
                            id     = 2
                            status = 200
                            body   = @{
                                value = @(
                                    @{
                                        id                            = 'device-2'
                                        displayName                   = 'CORP-LAPTOP-002'
                                        manufacturer                  = 'HP'
                                        model                         = 'EliteBook'
                                        operatingSystem               = 'Windows'
                                        operatingSystemVersion        = '11.0'
                                        accountEnabled                = $true
                                        approximateLastSignInDateTime = '2025-11-28T11:00:00Z'
                                        trustType                     = 'AzureAd'
                                        isCompliant                   = $true
                                        isManaged                     = $true
                                        deviceOwnership               = 'Company'
                                        enrollmentType                = 'AzureADJoined'
                                        registrationDateTime          = '2025-02-01T09:00:00Z'
                                    }
                                )
                            }
                        }
                    )
                }
            }
            
            $result = Get-RegisteredDevicesByUser -usersList @('user1@domain.com', 'user2@domain.com') -accessToken 'test-token'
            
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
            $result[0].UserName | Should -Be 'user1@domain.com'
            $result[1].UserName | Should -Be 'user2@domain.com'
        }
        
        It "Should return empty array when user has no devices" {
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
            
            $result = Get-RegisteredDevicesByUser -usersList @('user1@domain.com') -accessToken 'test-token'
            
            $result.Count | Should -Be 0
        }
    }
    
    Context "Filtering Functionality" {
        BeforeEach {
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
                                value = @(
                                    @{
                                        id                            = 'device-1'
                                        displayName                   = 'CORP-LAPTOP-001'
                                        manufacturer                  = 'Dell'
                                        model                         = 'Latitude'
                                        operatingSystem               = 'Windows'
                                        operatingSystemVersion        = '10.0'
                                        accountEnabled                = $true
                                        approximateLastSignInDateTime = '2025-11-28T10:00:00Z'
                                        trustType                     = 'AzureAd'
                                        isCompliant                   = $true
                                        isManaged                     = $true
                                        deviceOwnership               = 'Company'
                                        enrollmentType                = 'AzureADJoined'
                                        registrationDateTime          = '2025-01-01T09:00:00Z'
                                    },
                                    @{
                                        id                            = 'device-2'
                                        displayName                   = 'PROD-LAPTOP-002'
                                        manufacturer                  = 'HP'
                                        model                         = 'EliteBook'
                                        operatingSystem               = 'Windows'
                                        operatingSystemVersion        = '11.0'
                                        accountEnabled                = $true
                                        approximateLastSignInDateTime = '2025-11-28T11:00:00Z'
                                        trustType                     = 'AzureAd'
                                        isCompliant                   = $true
                                        isManaged                     = $true
                                        deviceOwnership               = 'Company'
                                        enrollmentType                = 'AzureADJoined'
                                        registrationDateTime          = '2025-02-01T09:00:00Z'
                                    },
                                    @{
                                        id                            = 'device-3'
                                        displayName                   = 'CORP-MAC-001'
                                        manufacturer                  = 'Apple'
                                        model                         = 'MacBook Pro'
                                        operatingSystem               = 'macOS'
                                        operatingSystemVersion        = '14.0'
                                        accountEnabled                = $true
                                        approximateLastSignInDateTime = '2025-11-28T12:00:00Z'
                                        trustType                     = 'AzureAd'
                                        isCompliant                   = $true
                                        isManaged                     = $true
                                        deviceOwnership               = 'Company'
                                        enrollmentType                = 'AppleUserEnrollment'
                                        registrationDateTime          = '2025-03-01T09:00:00Z'
                                    }
                                )
                            }
                        }
                    )
                }
            }
        }
        
        It "Should filter devices by operating system" {
            $global:settings.operatingSystem = "Windows"
            $global:settings.deviceNamePrefix = ""  # Clear prefix filter
            
            $result = Get-RegisteredDevicesByUser -usersList @('user1@domain.com') -accessToken 'test-token'
            
            # Should filter out macOS device, leaving 2 Windows devices
            $result.Count | Should -Be 2
            $result | ForEach-Object { $_.OperatingSystem | Should -Be 'Windows' }
        }
        
        It "Should filter devices by device name prefix" {
            $global:settings.deviceNamePrefix = "CORP-"
            $global:settings.operatingSystem = ""  # Clear OS filter
            
            $result = Get-RegisteredDevicesByUser -usersList @('user1@domain.com') -accessToken 'test-token'
            
            # Should filter out PROD- device, leaving 2 CORP- devices
            $result.Count | Should -Be 2
            $result | ForEach-Object { $_.DisplayName | Should -BeLike 'CORP-*' }
        }
        
        It "Should apply both OS and prefix filters" {
            $global:settings.operatingSystem = "Windows"
            $global:settings.deviceNamePrefix = "CORP-"
            
            $result = Get-RegisteredDevicesByUser -usersList @('user1@domain.com') -accessToken 'test-token'
            
            $result.Count | Should -Be 1
            $result[0].DisplayName | Should -Be 'CORP-LAPTOP-001'
            $result[0].OperatingSystem | Should -Be 'Windows'
        }
        
        It "Should not filter when settings are empty" {
            $global:settings.operatingSystem = ""
            $global:settings.deviceNamePrefix = ""
            
            $result = Get-RegisteredDevicesByUser -usersList @('user1@domain.com') -accessToken 'test-token'
            
            $result.Count | Should -Be 3
        }
    }
    
    Context "Caching Functionality" {
        It "Should cache device results after API call" {
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
                                value = @(
                                    @{
                                        id                            = 'device-1'
                                        displayName                   = 'CORP-LAPTOP-001'
                                        manufacturer                  = 'Dell'
                                        model                         = 'Latitude'
                                        operatingSystem               = 'Windows'
                                        operatingSystemVersion        = '10.0'
                                        accountEnabled                = $true
                                        approximateLastSignInDateTime = '2025-11-28T10:00:00Z'
                                        trustType                     = 'AzureAd'
                                        isCompliant                   = $true
                                        isManaged                     = $true
                                        deviceOwnership               = 'Company'
                                        enrollmentType                = 'AzureADJoined'
                                        registrationDateTime          = '2025-01-01T09:00:00Z'
                                    }
                                )
                            }
                        }
                    )
                }
            }
            
            # First call should query API
            $result1 = Get-RegisteredDevicesByUser -usersList @('user1@domain.com') -accessToken 'test-token'
            
            # Verify cache was populated - check that a key exists for user1
            $cacheKeys = @($global:UnifiedCache.DirectoryObjects.Keys)
            $userCacheKey = $cacheKeys | Where-Object { $_ -like "*user1@domain.com*" }
            $userCacheKey | Should -Not -BeNullOrEmpty
            
            # Second call should use cache
            $result2 = Get-RegisteredDevicesByUser -usersList @('user1@domain.com') -accessToken 'test-token'
            
            # Should only call API once
            Should -Invoke CallGraphAPI -Times 1 -Exactly
            
            # Results should be identical
            $result1.Count | Should -Be $result2.Count
            $result1[0].DisplayName | Should -Be $result2[0].DisplayName
        }
        
        It "Should use cache for all users when all are cached" {
            Mock CallGraphAPI {
                return @{
                    batchProcessed = $true
                    successCount   = 2
                    failureCount   = 0
                    value          = @(
                        @{
                            id     = 1
                            status = 200
                            body   = @{
                                value = @(
                                    @{
                                        id                            = 'device-1'
                                        displayName                   = 'CORP-LAPTOP-001'
                                        manufacturer                  = 'Dell'
                                        model                         = 'Latitude'
                                        operatingSystem               = 'Windows'
                                        operatingSystemVersion        = '10.0'
                                        accountEnabled                = $true
                                        approximateLastSignInDateTime = '2025-11-28T10:00:00Z'
                                        trustType                     = 'AzureAd'
                                        isCompliant                   = $true
                                        isManaged                     = $true
                                        deviceOwnership               = 'Company'
                                        enrollmentType                = 'AzureADJoined'
                                        registrationDateTime          = '2025-01-01T09:00:00Z'
                                    }
                                )
                            }
                        },
                        @{
                            id     = 2
                            status = 200
                            body   = @{
                                value = @(
                                    @{
                                        id                            = 'device-2'
                                        displayName                   = 'CORP-LAPTOP-002'
                                        manufacturer                  = 'HP'
                                        model                         = 'EliteBook'
                                        operatingSystem               = 'Windows'
                                        operatingSystemVersion        = '11.0'
                                        accountEnabled                = $true
                                        approximateLastSignInDateTime = '2025-11-28T11:00:00Z'
                                        trustType                     = 'AzureAd'
                                        isCompliant                   = $true
                                        isManaged                     = $true
                                        deviceOwnership               = 'Company'
                                        enrollmentType                = 'AzureADJoined'
                                        registrationDateTime          = '2025-02-01T09:00:00Z'
                                    }
                                )
                            }
                        }
                    )
                }
            }
            
            # First call caches data
            $result1 = Get-RegisteredDevicesByUser -usersList @('user1@domain.com', 'user2@domain.com') -accessToken 'test-token'
            
            # Second call should use cache and not call API
            $result2 = Get-RegisteredDevicesByUser -usersList @('user1@domain.com', 'user2@domain.com') -accessToken 'test-token'
            
            # Should only call API once
            Should -Invoke CallGraphAPI -Times 1 -Exactly
            
            $result2.Count | Should -Be 2
        }
        
        It "Should handle mixed cache hits and misses" {
            # Clear filters FIRST before setting up cache
            $global:settings.operatingSystem = ""
            $global:settings.deviceNamePrefix = ""
            
            Mock CallGraphAPI {
                param($accessToken, $ResourcePath)
                
                # Return data only for user2 (user1 is in cache)
                return @{
                    batchProcessed = $true
                    successCount   = 1
                    failureCount   = 0
                    value          = @(
                        @{
                            id     = 1
                            status = 200
                            body   = @{
                                value = @(
                                    @{
                                        id                            = 'device-2'
                                        displayName                   = 'CORP-LAPTOP-002'
                                        manufacturer                  = 'HP'
                                        model                         = 'EliteBook'
                                        operatingSystem               = 'Windows'
                                        operatingSystemVersion        = '11.0'
                                        accountEnabled                = $true
                                        approximateLastSignInDateTime = '2025-11-28T11:00:00Z'
                                        trustType                     = 'AzureAd'
                                        isCompliant                   = $true
                                        isManaged                     = $true
                                        deviceOwnership               = 'Company'
                                        enrollmentType                = 'AzureADJoined'
                                        registrationDateTime          = '2025-02-01T09:00:00Z'
                                    }
                                )
                            }
                        }
                    )
                }
            }
            
            # Manually populate cache for user1 with empty filters
            $cacheKey = "registeredDevices:user1@domain.com:OS=:Prefix="
            $cachedDevice = [PSCustomObject]@{
                UserName                      = 'user1@domain.com'
                DeviceId                      = 'device-1'
                DisplayName                   = 'CORP-LAPTOP-001'
                Manufacturer                  = 'Dell'
                Model                         = 'Latitude'
                OperatingSystem               = 'Windows'
                OperatingSystemVersion        = '10.0'
                AccountEnabled                = $true
                ApproximateLastSignInDateTime = 'N/A'
                DeviceTrustType               = 'AzureAd'
                IsCompliant                   = $true
                IsManaged                     = $true
                DeviceOwnership               = 'Company'
                EnrollmentType                = 'AzureADJoined'
                RegistrationDateTime          = 'N/A'
            }
            $global:UnifiedCache.DirectoryObjects[$cacheKey] = @{
                Data      = @($cachedDevice)
                Timestamp = Get-Date
                Metadata  = @{ UserName = 'user1@domain.com' }
            }
            
            # Query for both users
            $result = Get-RegisteredDevicesByUser -usersList @('user1@domain.com', 'user2@domain.com') -accessToken 'test-token'
            
            # Should call API only once (for user2)
            Should -Invoke CallGraphAPI -Times 1 -Exactly
            
            # Should have both devices (order not guaranteed)
            $result.Count | Should -Be 2
            $userNames = $result | ForEach-Object { $_.UserName }
            $userNames | Should -Contain 'user1@domain.com'
            $userNames | Should -Contain 'user2@domain.com'
        }
        
        It "Should cache empty results to avoid repeated queries" {
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
            
            # First call
            $result1 = Get-RegisteredDevicesByUser -usersList @('user1@domain.com') -accessToken 'test-token'
            
            # Verify cache was populated (use pattern matching since cache key format may vary)
            $cacheKeys = @($global:UnifiedCache.DirectoryObjects.Keys)
            $userCacheKey = $cacheKeys | Where-Object { $_ -like "*user1@domain.com*" }
            $userCacheKey | Should -Not -BeNullOrEmpty
            
            # Second call should use cache
            $result2 = Get-RegisteredDevicesByUser -usersList @('user1@domain.com') -accessToken 'test-token'
            
            # Should only call API once
            Should -Invoke CallGraphAPI -Times 1 -Exactly
            
            $result1.Count | Should -Be 0
            $result2.Count | Should -Be 0
        }
        
        It "Should include filter criteria in cache key" {
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
                                value = @(
                                    @{
                                        id                            = 'device-1'
                                        displayName                   = 'CORP-LAPTOP-001'
                                        manufacturer                  = 'Dell'
                                        model                         = 'Latitude'
                                        operatingSystem               = 'Windows'
                                        operatingSystemVersion        = '10.0'
                                        accountEnabled                = $true
                                        approximateLastSignInDateTime = '2025-11-28T10:00:00Z'
                                        trustType                     = 'AzureAd'
                                        isCompliant                   = $true
                                        isManaged                     = $true
                                        deviceOwnership               = 'Company'
                                        enrollmentType                = 'AzureADJoined'
                                        registrationDateTime          = '2025-01-01T09:00:00Z'
                                    }
                                )
                            }
                        }
                    )
                }
            }
            
            # Call with Windows filter
            $global:settings.operatingSystem = "Windows"
            $result1 = Get-RegisteredDevicesByUser -usersList @('user1@domain.com') -accessToken 'test-token'
            
            # Change filter and call again
            $global:settings.operatingSystem = "macOS"
            $result2 = Get-RegisteredDevicesByUser -usersList @('user1@domain.com') -accessToken 'test-token'
            
            # Should call API twice (different cache keys)
            Should -Invoke CallGraphAPI -Times 2 -Exactly
            
            # Verify different cache keys exist for different filter settings
            $cacheKeys = @($global:UnifiedCache.DirectoryObjects.Keys)
            $windowsKey = $cacheKeys | Where-Object { $_ -like "*user1@domain.com*OS=Windows*" }
            $macOSKey = $cacheKeys | Where-Object { $_ -like "*user1@domain.com*OS=macOS*" }
            $windowsKey | Should -Not -BeNullOrEmpty
            $macOSKey | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Error Handling" {
        It "Should handle null API response gracefully" {
            Mock CallGraphAPI {
                return $null
            }
            
            $result = Get-RegisteredDevicesByUser -usersList @('user1@domain.com') -accessToken 'test-token'
            
            $result | Should -BeNullOrEmpty
        }
        
        It "Should return cached data when API fails" {
            # First, make a successful call to populate cache
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
                                value = @(
                                    @{
                                        id                            = 'device-1'
                                        displayName                   = 'CORP-LAPTOP-001'
                                        manufacturer                  = 'Dell'
                                        model                         = 'Latitude'
                                        operatingSystem               = 'Windows'
                                        operatingSystemVersion        = '10.0'
                                        accountEnabled                = $true
                                        approximateLastSignInDateTime = '2025-11-28T10:00:00Z'
                                        trustType                     = 'AzureAd'
                                        isCompliant                   = $true
                                        isManaged                     = $true
                                        deviceOwnership               = 'Company'
                                        enrollmentType                = 'AzureADJoined'
                                        registrationDateTime          = '2025-01-01T09:00:00Z'
                                    }
                                )
                            }
                        }
                    )
                }
            }
            
            # First call to populate cache
            $result1 = Get-RegisteredDevicesByUser -usersList @('user1@domain.com') -accessToken 'test-token'
            $result1.Count | Should -Be 1
            
            # Now mock API to fail
            Mock CallGraphAPI {
                return $null
            }
            
            # Second call should use cache even though API fails
            $result = Get-RegisteredDevicesByUser -usersList @('user1@domain.com') -accessToken 'test-token'
            
            # Should return cached data
            $result.Count | Should -Be 1
            $result[0].DisplayName | Should -Be 'CORP-LAPTOP-001'
        }
        
        It "Should handle partial batch failures" {
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
                                        id                            = 'device-1'
                                        displayName                   = 'CORP-LAPTOP-001'
                                        manufacturer                  = 'Dell'
                                        model                         = 'Latitude'
                                        operatingSystem               = 'Windows'
                                        operatingSystemVersion        = '10.0'
                                        accountEnabled                = $true
                                        approximateLastSignInDateTime = '2025-11-28T10:00:00Z'
                                        trustType                     = 'AzureAd'
                                        isCompliant                   = $true
                                        isManaged                     = $true
                                        deviceOwnership               = 'Company'
                                        enrollmentType                = 'AzureADJoined'
                                        registrationDateTime          = '2025-01-01T09:00:00Z'
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
            
            $result = Get-RegisteredDevicesByUser -usersList @('user1@domain.com', 'invalid@domain.com') -accessToken 'test-token'
            
            # Should return devices from successful request only
            $result.Count | Should -Be 1
            $result[0].DisplayName | Should -Be 'CORP-LAPTOP-001'
        }
        
        It "Should handle empty or whitespace user list" {
            Mock CallGraphAPI {}
            
            # Use whitespace-only strings (parameter binding rejects truly empty strings)
            $result = Get-RegisteredDevicesByUser -usersList @('  ', '   ') -accessToken 'test-token'
            
            # Should not call API with invalid users
            Should -Invoke CallGraphAPI -Times 0
            $result.Count | Should -Be 0
        }
        
        It "Should skip unmanaged devices" {
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
                                value = @(
                                    @{
                                        id                            = 'device-1'
                                        displayName                   = 'CORP-LAPTOP-001'
                                        manufacturer                  = 'Dell'
                                        model                         = 'Latitude'
                                        operatingSystem               = 'Windows'
                                        operatingSystemVersion        = '10.0'
                                        accountEnabled                = $true
                                        approximateLastSignInDateTime = '2025-11-28T10:00:00Z'
                                        trustType                     = 'AzureAd'
                                        isCompliant                   = $true
                                        isManaged                     = $false  # Unmanaged
                                        deviceOwnership               = 'Personal'
                                        enrollmentType                = 'Unknown'
                                        registrationDateTime          = '2025-01-01T09:00:00Z'
                                    },
                                    @{
                                        id                            = 'device-2'
                                        displayName                   = 'CORP-LAPTOP-002'
                                        manufacturer                  = 'HP'
                                        model                         = 'EliteBook'
                                        operatingSystem               = 'Windows'
                                        operatingSystemVersion        = '11.0'
                                        accountEnabled                = $true
                                        approximateLastSignInDateTime = '2025-11-28T11:00:00Z'
                                        trustType                     = 'AzureAd'
                                        isCompliant                   = $true
                                        isManaged                     = $true  # Managed
                                        deviceOwnership               = 'Company'
                                        enrollmentType                = 'AzureADJoined'
                                        registrationDateTime          = '2025-02-01T09:00:00Z'
                                    }
                                )
                            }
                        }
                    )
                }
            }
            
            $result = Get-RegisteredDevicesByUser -usersList @('user1@domain.com') -accessToken 'test-token'
            
            # Should only return managed device
            $result.Count | Should -Be 1
            $result[0].DisplayName | Should -Be 'CORP-LAPTOP-002'
        }
    }
    
    Context "Data Formatting" {
        It "Should format dates using FormatDateWithTimeZone" {
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
                                value = @(
                                    @{
                                        id                            = 'device-1'
                                        displayName                   = 'CORP-LAPTOP-001'
                                        manufacturer                  = 'Dell'
                                        model                         = 'Latitude'
                                        operatingSystem               = 'Windows'
                                        operatingSystemVersion        = '10.0'
                                        accountEnabled                = $true
                                        approximateLastSignInDateTime = '2025-11-28T10:00:00Z'
                                        trustType                     = 'AzureAd'
                                        isCompliant                   = $true
                                        isManaged                     = $true
                                        deviceOwnership               = 'Company'
                                        enrollmentType                = 'AzureADJoined'
                                        registrationDateTime          = '2025-01-01T09:00:00Z'
                                    }
                                )
                            }
                        }
                    )
                }
            }
            
            Mock FormatDateWithTimeZone {
                param($DateTime)
                return "2025-01-01 09:00:00 EST"
            }
            
            $result = Get-RegisteredDevicesByUser -usersList @('user1@domain.com') -accessToken 'test-token'
            
            $result[0].RegistrationDateTime | Should -Be "2025-01-01 09:00:00 EST"
            Should -Invoke FormatDateWithTimeZone -Times 2  # Called for both registration and last sign-in
        }
        
        It "Should handle null dates gracefully" {
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
                                value = @(
                                    @{
                                        id                            = 'device-1'
                                        displayName                   = 'CORP-LAPTOP-001'
                                        manufacturer                  = 'Dell'
                                        model                         = 'Latitude'
                                        operatingSystem               = 'Windows'
                                        operatingSystemVersion        = '10.0'
                                        accountEnabled                = $true
                                        approximateLastSignInDateTime = $null
                                        trustType                     = 'AzureAd'
                                        isCompliant                   = $true
                                        isManaged                     = $true
                                        deviceOwnership               = 'Company'
                                        enrollmentType                = 'AzureADJoined'
                                        registrationDateTime          = $null
                                    }
                                )
                            }
                        }
                    )
                }
            }
            
            $result = Get-RegisteredDevicesByUser -usersList @('user1@domain.com') -accessToken 'test-token'
            
            $result[0].RegistrationDateTime | Should -Be "N/A"
            $result[0].ApproximateLastSignInDateTime | Should -Be "N/A"
        }
        
        It "Should create proper PSCustomObject with all properties" {
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
                                value = @(
                                    @{
                                        id                            = 'device-1'
                                        displayName                   = 'CORP-LAPTOP-001'
                                        manufacturer                  = 'Dell'
                                        model                         = 'Latitude'
                                        operatingSystem               = 'Windows'
                                        operatingSystemVersion        = '10.0'
                                        accountEnabled                = $true
                                        approximateLastSignInDateTime = '2025-11-28T10:00:00Z'
                                        trustType                     = 'AzureAd'
                                        isCompliant                   = $true
                                        isManaged                     = $true
                                        deviceOwnership               = 'Company'
                                        enrollmentType                = 'AzureADJoined'
                                        registrationDateTime          = '2025-01-01T09:00:00Z'
                                    }
                                )
                            }
                        }
                    )
                }
            }
            
            $result = Get-RegisteredDevicesByUser -usersList @('user1@domain.com') -accessToken 'test-token'
            
            $device = $result[0]
            $device.UserName | Should -Not -BeNullOrEmpty
            $device.DeviceId | Should -Be 'device-1'
            $device.DisplayName | Should -Be 'CORP-LAPTOP-001'
            $device.Manufacturer | Should -Be 'Dell'
            $device.Model | Should -Be 'Latitude'
            $device.OperatingSystem | Should -Be 'Windows'
            $device.OperatingSystemVersion | Should -Be '10.0'
            $device.AccountEnabled | Should -Be $true
            $device.DeviceTrustType | Should -Be 'AzureAd'
            $device.IsCompliant | Should -Be $true
            $device.IsManaged | Should -Be $true
            $device.DeviceOwnership | Should -Be 'Company'
            $device.EnrollmentType | Should -Be 'AzureADJoined'
        }
    }
}

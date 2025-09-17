@{
    description = 'Build targets configuration for CreateRelease.ps1 - defines different build configurations with parameters and settings'
    version     = '1.0.0'
    
    # Build targets - each target defines build parameters and settings to apply
    targets     = @{
        # Development build target
        dev        = @{
            # Build parameters that are passed to CreateRelease.ps1
            buildParameters = @{
                inputFile       = 'main.ps1'
                OutputPath      = 'bin'
                NoVersionUpdate = $false
                Overwrite       = $true
                noCleanup       = $false
            }
            
            # Settings to apply to global settings.psd1
            globalSettings  = @{
                autoUpdate        = $false
                showLicenseBanner = $false
                validateScopes    = $false
            }
            
            # Settings to apply to auth section
            authSettings    = @{
                changePwOnNextStart = $false
                delegated           = $false
                forceNewToken       = $false
            }
            
            # Domain to use for domain-specific settings (optional)
            domain          = 'arabictutor.com'
            
            # Settings to apply to domain configuration (when domain is specified)
            domainSettings  = @{
                privateSession                  = $false
                groupsToExclude                 = @(
                    @{
                        id   = 'a0138743-e4fe-45db-a231-737b10a2615d'
                        name = 'autoPilot-device-preparation-user'
                    }
                )
                companyName                     = 'ZM Consulting'
                maxUserMatchDisplay             = 10
                appMode                         = 'full'
                assignedUser                    = ''
                minimumDevicePhysicalMemoryInGB = 8
                maxNumberOfDevicesAllowed       = 15
                maxGroupMatchDisplay            = 10
                autopilotProfilesToInclude      = @(
                    @{
                        id   = 'edaca6f4-58e4-4a55-a985-52c8f74fb6c4'
                        name = 'windowsCloudConfig Autopilot profile'
                    },
                    @{
                        id   = '78a4c8b8-c7fb-4fbb-9db6-7c91eb1db7d1'
                        name = 'Hybrid join profile'
                    }
                )
                autoUpdate                      = $false
                preferredBrowser                = 'Chrome'
                minUsernameLength               = 3
                version                         = '4.0.0.30055'
                operatingSystem                 = 'Windows'
                minSerialNumberLength           = 7
                maxUserNameLength               = 50
                validateScopes                  = $false
                showLicenseBanner               = $false
                timeInSeconds                   = 60
                groupsToInclude                 = @(
                    @{
                        id   = 'f1752bdb-7abd-438c-a54e-7faca7cecf61'
                        name = 'Cloud Managed PC User 3.26.2023_18:43:44'
                    }
                )
                groupTag                        = 'ENTRA'
                groupPatternsToExclude          = @()
                repoInfo                        = @{
                    repoPath      = 'zuhairmahd'
                    baseURL       = 'https://www.github.com'
                    baseSourceURL = 'https://raw.githubusercontent.com'
                    repoName      = 'Autopilot'
                }
                release                         = 'master'
                deviceContactThresholdInDays    = 30
                additionalScopes                = @()
                userPatternsToExclude           = @(
                    '-test',
                    'onmicrosoft.com'
                )
                maxSerialNumberLength           = 50
                maxWaitTime                     = 30
                domain                          = 'arabictutor.com'
                deviceNamePrefix                = 'vmware'
            }
            
            description     = 'Development build with test mode enabled and signing disabled'
        }
        
        # Production build target
        production = @{
            buildParameters = @{
                OutputPath      = 'bin'
                NoVersionUpdate = $false
                Overwrite       = $true
                noCleanup       = $false
            }
            
            globalSettings  = @{
                autoUpdate        = $true
                showLicenseBanner = $false
                validateScopes    = $true
            }
            
            authSettings    = @{
                changePwOnNextStart = $true
                forceNewToken       = $false
            }
            
            domain          = $null
            domainSettings  = @{}
            
            description     = 'Production build with signing enabled and test mode disabled'
        }
        
        # Government build (example for gao.gov)
        government = @{
            buildParameters = @{
                OutputPath      = 'lhm'
                NoVersionUpdate = $false
                Overwrite       = $true
            }
            
            globalSettings  = @{
                testMode       = $false
                autoUpdate     = $true
                validateScopes = $false
            }
            
            authSettings    = @{
                changePwOnNextStart = $true
                validateScopes      = $false
                authType            = 'PublicAuthFlow'
                noSaveRefreshToken  = $false
                forceNewToken       = $false
                scope               = @(
                    'offline_access',
                    'openid',
                    'Device.ReadWrite.All',
                    'DeviceManagementApps.Read.All',
                    'DeviceManagementConfiguration.ReadWrite.All',
                    'DeviceManagementManagedDevices.PrivilegedOperations.All',
                    'DeviceManagementManagedDevices.ReadWrite.All',
                    'DeviceManagementServiceConfig.ReadWrite.All'
                )
                delegated           = $false
                cacheType           = 'Memory'
                secureString        = $false
                renewalLeadTime     = 5
            }
            
            domain          = 'gao.gov'
            
            domainSettings  = @{
                privateSession                  = $true
                groupsToExclude                 = @()
                desiredAutopilotProfiles        = @(
                    'msb'
                )
                maxUserMatchDisplay             = 10
                appMode                         = 'registration'
                userPatternsToExclude           = @(
                    '-test',
                    'onmicrosoft.com',
                    '-cma',
                    '-a',
                    '-rsa',
                    '-sup'
                )
                assignedUser                    = ''
                minimumDevicePhysicalMemoryInGB = 16
                maxGroupMatchDisplay            = 10
                maxWaitTime                     = 30
                autoUpdate                      = $true
                checkStrongMapping              = $true
                strongMappingOptional           = $false
                preferredBrowser                = 'Chrome'
                maxSerialNumberLength           = 11
                minUsernameLength               = 3
                version                         = '1.3.0.0'
                operatingSystem                 = 'Windows'
                minSerialNumberLength           = 7
                maxUserNameLength               = 50
                validateScopes                  = $false
                groupsToInclude                 = @(
                    @{
                        id   = '74d8cfe5-7934-4bd7-bcf3-593dcc6639ed'
                        name = 'sg_Office_365_License_G5_wth_windows_pilot'
                    },
                    @{
                        id   = 'be87a9ef-3e44-4e6b-8a9e-d1696e2f7db5'
                        name = 'sg_passwrd_hash_stage'
                    },
                    @{
                        id   = '27d943bc-77cc-44eb-9f81-13c76841129b'
                        name = 'ITN-USR-CON-WIN-ENROLLMENT-PROD-ALLMSB'
                    }
                )
                groupTag                        = 'MSB01'
                groupPatternsToExclude          = @()
                repoInfo                        = @{
                    repoPath      = 'zuhairmahd'
                    baseURL       = 'https://www.github.com'
                    baseSourceURL = 'https://raw.githubusercontent.com'
                    repoName      = 'Autopilot'
                }
                companyName                     = 'Government Accountability Office'
                release                         = 'lhm'
                deviceContactThresholdInDays    = 30
                additionalScopes                = @()
                maxNumberOfDevicesAllowed       = 20
                timeInSeconds                   = 60
                showLicenseBanner               = $false
                domain                          = 'gao.gov'
                deviceNamePrefix                = 'w11-'
            }
            
            description     = 'Government build for gao.gov with enhanced security and compliance settings'
        }
        
        # Testing target for CI/CD validation
        ci_test    = @{
            buildParameters = @{
                Version         = 'test.0.0.1'
                OutputPath      = './build/ci_test'
                SkipSigning     = $true
                NoVersionUpdate = $true
                Overwrite       = $true
                noCleanup       = $false
            }
            
            globalSettings  = @{
                testMode       = $true
                autoUpdate     = $false
                validateScopes = $false
            }
            
            authSettings    = @{
                changePwOnNextStart = $false
            }
            
            domain          = $null
            domainSettings  = @{}
            
            description     = 'CI/CD testing target with minimal settings for pipeline validation'
        }
    }
}
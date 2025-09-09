@{
    description = 'Build targets configuration for CreateRelease.ps1 - defines different build configurations with parameters and settings'
    version     = '1.0.0'
    
    # Build targets - each target defines build parameters and settings to apply
    targets     = @{
        
        # Development build target
        development = @{
            # Build parameters that are passed to CreateRelease.ps1
            buildParameters = @{
                OutputPath      = 'bin'
                SkipSigning     = $true
                NoVersionUpdate = $false
                Overwrite       = $true
                noCleanup       = $false
            }
            
            # Settings to apply to global settings.psd1
            globalSettings  = @{
                testMode          = $true
                autoUpdate        = $false
                showLicenseBanner = $true
                validateScopes    = $false
            }
            
            # Settings to apply to auth section
            authSettings    = @{
                changePwOnNextStart = $false
                forceNewToken       = $false
                validateScopes      = $false
            }
            
            # Domain to use for domain-specific settings (optional)
            domain          = $null
            
            # Settings to apply to domain configuration (when domain is specified)
            domainSettings  = @{
                # These would be applied to the domain-specific configuration file
            }
            
            description     = 'Development build with test mode enabled and signing disabled'
        }
        
        # Production build target
        production  = @{
            buildParameters = @{
                Version         = '1.3.1.0'
                OutputPath      = 'bin'
                SkipSigning     = $true
                NoVersionUpdate = $false
                Overwrite       = $true
                noCleanup       = $true
            }
            
            globalSettings  = @{
                testMode          = $false
                autoUpdate        = $true
                showLicenseBanner = $false
                validateScopes    = $true
            }
            
            authSettings    = @{
                changePwOnNextStart = $true
                forceNewToken       = $false
                validateScopes      = $true
            }
            
            domain          = $null
            domainSettings  = @{}
            
            description     = 'Production build with signing enabled and test mode disabled'
        }
        
        # Customer-specific build (example for arabictutor.com)
        arabictutor = @{
            buildParameters = @{
                Version         = '1.3.0.0-arabictutor'
                OutputPath      = './build/arabictutor'
                SkipSigning     = $true
                NoVersionUpdate = $false
                Overwrite       = $true
            }
            
            globalSettings  = @{
                testMode             = $false
                autoUpdate           = $true
                maxGroupMatchDisplay = 20
                maxUserMatchDisplay  = 20
            }
            
            authSettings    = @{
                changePwOnNextStart = $false
                validateScopes      = $false
            }
            
            # Use arabictutor.com domain configuration
            domain          = 'arabictutor.com'
            
            # Settings specific to arabictutor.com domain
            domainSettings  = @{
                companyName          = 'ZM Consulting'
                appMode              = 'full'
                maxGroupMatchDisplay = 20
                maxUserMatchDisplay  = 20
                groupTag             = 'ENTRA'
                deviceNamePrefix     = 'vmware'
                showLicenseBanner    = $false
                validateScopes       = $false
            }
            
            description     = 'Customer build for arabictutor.com with specific branding and settings'
        }
        
        # Government build (example for gao.gov)
        government  = @{
            buildParameters = @{
                Version         = '1.3.0.0-gov'
                OutputPath      = 'lhm'
                SkipSigning     = $true
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
            }
            
            domain          = 'gao.gov'
            
            domainSettings  = @{
                groupsToInclude                 = @(
                    'sg_Office_365_License_G5_wth_windows_pilot',
                    'sg_passwrd_hash_stage',
                    'ITN-USR-CON-WIN-ENROLLMENT-PROD-ALLMSB',
                    'ITN-USR-CON-WIN-ENROLLMENT-PROD-AUTOENROLLMENTENABLED'
                )
                groupsToExclude                 = @{}
                companyName                     = 'Government Accountability Office'
                maxGroupMatchDisplay            = 20
                maxUserMatchDisplay             = 20
                minimumDevicePhysicalMemoryInGB = 16
                maxSerialNumberLength           = 11
                maxNumberOfDevicesAllowed       = 20
                deviceNamePrefix                = 'w11-'
                privateSession                  = $true
                groupTag                        = 'MSB01'
                showLicenseBanner               = $false
                validateScopes                  = $false
                userPatternsToExclude           = @(
                    '-test'
                    'onmicrosoft.com'
                    '-rsa'
                    '-cma'
                    '-a'
                    '-sup'
                )
                desiredAutopilotProfiles        = @('msb')
            }
            
            description     = 'Government build for gao.gov with enhanced security and compliance settings'
        }
        
        # Testing target for CI/CD validation
        ci_test     = @{
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
                validateScopes      = $false
            }
            
            domain          = $null
            domainSettings  = @{}
            
            description     = 'CI/CD testing target with minimal settings for pipeline validation'
        }
    }
}
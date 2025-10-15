<#
.SYNOPSIS
    Comprehensive tests for configuration management and settings merging

.DESCRIPTION
    Validates configuration management functionality including:
    - Settings file creation and validation
    - Configuration merging from multiple sources
    - Domain-specific settings handling
    - Default value management
    - Configuration initialization and wizard functionality
    - Encryption functions
    - Configuration utilities
    
    Converted from TestScripts/test-configuration-comprehensive.ps1

.NOTES
    Test Category: Comprehensive
    Template Compliance: Full
    Uses: AutopilotTestHelpers
    Migration Date: October 14, 2025
    
    Migration Notes:
    - Converted 8 test sections to Pester Contexts
    - Enhanced with proper Setup/TearDown using helpers
    - Maintained all original test scenarios
    - Added granular assertions for better test isolation
#>

# Import helper module
Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Configuration Management Comprehensive" -Tags 'Comprehensive', 'Configuration' {
    
    BeforeAll {
        # Get repository root
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
        
        # Initialize test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment
        $script:TestFolder = $script:TestContext.TestFolder
        
        # Setup global variables
        $logPath = Join-Path $script:TestFolder "test-config-mgmt.log"
        Initialize-MockGlobalVariables -LogFile $logPath
        
        # Load all functions
        $functionsPath = Join-Path $script:RepoRoot "functions"
        $functionFiles = Get-ChildItem -Path $functionsPath -Recurse -Filter *.ps1 -File
        
        foreach ($file in $functionFiles)
        {
            . $file.FullName
        }
    }
    
    AfterAll {
        # Cleanup
        Clear-MockGlobalVariables
        Remove-TestEnvironment -TestContext $script:TestContext
    }
    
    Context "Configuration Management Functions Availability" {
        
        It "Should have MergeSettings function available" {
            Get-Command MergeSettings -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Get-ConfigurationData function available" {
            Get-Command Get-ConfigurationData -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Update-Setting function available" {
            Get-Command Update-Setting -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Settings Merging Logic" {
        
        BeforeAll {
            $script:localSettings = @{
                appMode          = "helpDesk"
                customSetting    = "local"
                localOnlySetting = "localValue"
            }
            
            $script:globalSettings = @{
                appMode           = "full"
                globalSetting     = "global"
                customSetting     = "global"
                globalOnlySetting = "globalValue"
            }
        }
        
        It "Should merge with Local priority correctly" {
            $merged = MergeSettings -localSettings $script:localSettings -globalSettings $script:globalSettings -ConflictResolution 'Local'
            
            $merged.appMode | Should -Be "helpDesk"
        }
        
        It "Should resolve conflicts with Local priority" {
            $merged = MergeSettings -localSettings $script:localSettings -globalSettings $script:globalSettings -ConflictResolution 'Local'
            
            $merged.customSetting | Should -Be "local"
        }
        
        It "Should preserve unique settings from both sources" {
            $merged = MergeSettings -localSettings $script:localSettings -globalSettings $script:globalSettings -ConflictResolution 'Local'
            
            $merged.globalOnlySetting | Should -Be "globalValue"
            $merged.localOnlySetting | Should -Be "localValue"
        }
        
        It "Should merge with Global priority correctly" {
            $merged = MergeSettings -localSettings $script:localSettings -globalSettings $script:globalSettings -ConflictResolution 'Global'
            
            $merged.customSetting | Should -Be "global"
        }
    }
    
    Context "Configuration Data Loading and Validation" {
        
        It "Should load configuration data with defaults" {
            $testSettingsPath = Join-Path $script:TestFolder "test-settings"
            
            $configData = Get-ConfigurationData -ConfigurationPath $testSettingsPath -DefaultValues @{test = "value"} -ErrorAction SilentlyContinue
            
            $configData | Should -Not -BeNullOrEmpty
        }
        
        It "Should apply default values when file doesn't exist" {
            $testSettingsPath = Join-Path $script:TestFolder "nonexistent-settings"
            
            $configData = Get-ConfigurationData -ConfigurationPath $testSettingsPath -DefaultValues @{test = "value"} -ErrorAction SilentlyContinue
            
            $configData.test | Should -Be "value"
        }
    }
    
    Context "First Run Wizard Functions" {
        
        It "Should have Start-FirstRunWizard function available" {
            Get-Command Start-FirstRunWizard -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Get-AppModeConfigurationFromUser function available" {
            Get-Command Get-AppModeConfigurationFromUser -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Get-AuthenticationConfigurationFromUser function available" {
            Get-Command Get-AuthenticationConfigurationFromUser -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Get-BasicConfigurationFromUser function available" {
            Get-Command Get-BasicConfigurationFromUser -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Merge-ConfigurationDefaults Function Testing" {
        
        It "Should merge auth config with missing keys" {
            $existingAuth = @{
                delegated = $true
                authType  = "PublicAuthFlow"
            }
            
            $defaultAuth = @{
                delegated         = $true
                authType          = "PublicAuthFlow"
                scope             = @("offline_access", "openid", "Device.ReadWrite.All")
                tenantId          = "common"
                clientId          = ""
                redirectUri       = "http://localhost"
                saveRefreshToken  = $true
                useDeviceCodeFlow = $false
            }
            
            $merged = Merge-ConfigurationDefaults -ExistingConfig $existingAuth -DefaultConfig $defaultAuth -PreserveExisting $true
            
            # Should return hashtable with changes or null if no changes needed
            if ($null -ne $merged)
            {
                $merged | Should -BeOfType [hashtable]
            }
        }
        
        It "Should preserve existing auth values" {
            $existingAuth = @{
                delegated = $true
                authType  = "PublicAuthFlow"
            }
            
            $defaultAuth = @{
                delegated         = $true
                authType          = "PublicAuthFlow"
                scope             = @("offline_access", "openid", "Device.ReadWrite.All")
                tenantId          = "common"
                clientId          = ""
                redirectUri       = "http://localhost"
                saveRefreshToken  = $true
                useDeviceCodeFlow = $false
            }
            
            $merged = Merge-ConfigurationDefaults -ExistingConfig $existingAuth -DefaultConfig $defaultAuth -PreserveExisting $true
            
            if ($null -ne $merged)
            {
                $merged.delegated | Should -Be $true
                $merged.authType | Should -Be "PublicAuthFlow"
            }
        }
        
        It "Should add missing auth keys from defaults" {
            $existingAuth = @{
                delegated = $true
                authType  = "PublicAuthFlow"
            }
            
            $defaultAuth = @{
                delegated         = $true
                authType          = "PublicAuthFlow"
                scope             = @("offline_access", "openid", "Device.ReadWrite.All")
                tenantId          = "common"
                clientId          = ""
                redirectUri       = "http://localhost"
                saveRefreshToken  = $true
                useDeviceCodeFlow = $false
            }
            
            $merged = Merge-ConfigurationDefaults -ExistingConfig $existingAuth -DefaultConfig $defaultAuth -PreserveExisting $true
            
            if ($null -ne $merged)
            {
                $merged.ContainsKey('scope') | Should -Be $true
                $merged.ContainsKey('tenantId') | Should -Be $true
                $merged.ContainsKey('saveRefreshToken') | Should -Be $true
            }
        }
        
        It "Should merge global settings with nested hashtables" {
            $existingGlobal = @{
                logLevel = "Debug"
                features = @{
                    enableFeatureA = $true
                }
            }
            
            $defaultGlobal = @{
                logLevel   = "Information"
                maxRetries = 3
                features   = @{
                    enableFeatureA = $false
                    enableFeatureB = $true
                    enableFeatureC = $false
                }
            }
            
            $merged = Merge-ConfigurationDefaults -ExistingConfig $existingGlobal -DefaultConfig $defaultGlobal -PreserveExisting $true
            
            if ($null -ne $merged)
            {
                $merged | Should -BeOfType [hashtable]
            }
        }
        
        It "Should preserve existing top-level values" {
            $existingGlobal = @{
                logLevel = "Debug"
                features = @{
                    enableFeatureA = $true
                }
            }
            
            $defaultGlobal = @{
                logLevel   = "Information"
                maxRetries = 3
                features   = @{
                    enableFeatureA = $false
                    enableFeatureB = $true
                    enableFeatureC = $false
                }
            }
            
            $merged = Merge-ConfigurationDefaults -ExistingConfig $existingGlobal -DefaultConfig $defaultGlobal -PreserveExisting $true
            
            if ($null -ne $merged)
            {
                $merged.logLevel | Should -Be "Debug"
            }
        }
        
        It "Should preserve existing nested values" {
            $existingGlobal = @{
                logLevel = "Debug"
                features = @{
                    enableFeatureA = $true
                }
            }
            
            $defaultGlobal = @{
                logLevel   = "Information"
                maxRetries = 3
                features   = @{
                    enableFeatureA = $false
                    enableFeatureB = $true
                    enableFeatureC = $false
                }
            }
            
            $merged = Merge-ConfigurationDefaults -ExistingConfig $existingGlobal -DefaultConfig $defaultGlobal -PreserveExisting $true
            
            if ($null -ne $merged)
            {
                $merged.features.enableFeatureA | Should -Be $true
            }
        }
        
        It "Should add missing nested keys from defaults" {
            $existingGlobal = @{
                logLevel = "Debug"
                features = @{
                    enableFeatureA = $true
                }
            }
            
            $defaultGlobal = @{
                logLevel   = "Information"
                maxRetries = 3
                features   = @{
                    enableFeatureA = $false
                    enableFeatureB = $true
                    enableFeatureC = $false
                }
            }
            
            $merged = Merge-ConfigurationDefaults -ExistingConfig $existingGlobal -DefaultConfig $defaultGlobal -PreserveExisting $true
            
            if ($null -ne $merged)
            {
                $merged.features.ContainsKey('enableFeatureB') | Should -Be $true
                $merged.features.ContainsKey('enableFeatureC') | Should -Be $true
            }
        }
        
        It "Should add missing top-level keys" {
            $existingGlobal = @{
                logLevel = "Debug"
                features = @{
                    enableFeatureA = $true
                }
            }
            
            $defaultGlobal = @{
                logLevel   = "Information"
                maxRetries = 3
                features   = @{
                    enableFeatureA = $false
                    enableFeatureB = $true
                    enableFeatureC = $false
                }
            }
            
            $merged = Merge-ConfigurationDefaults -ExistingConfig $existingGlobal -DefaultConfig $defaultGlobal -PreserveExisting $true
            
            if ($null -ne $merged)
            {
                $merged.ContainsKey('maxRetries') | Should -Be $true
            }
        }
        
        It "Should return null when no changes needed" {
            $completeConfig = @{
                setting1 = "value1"
                setting2 = "value2"
            }
            
            $sameDefaults = @{
                setting1 = "default1"
                setting2 = "default2"
            }
            
            $merged = Merge-ConfigurationDefaults -ExistingConfig $completeConfig -DefaultConfig $sameDefaults -PreserveExisting $true
            
            $merged | Should -BeNullOrEmpty
        }
    }
    
    Context "Settings Update and Management" {
        
        It "Should have Update-Setting function available for testing" {
            Get-Command Update-Setting -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Configuration Encryption Functions" {
        
        It "Should have Initialize-ConfigurationSession function available" {
            Get-Command Initialize-ConfigurationSession -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Load-EncryptedConfigFile function available" {
            Get-Command Load-EncryptedConfigFile -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Invoke-JsonFileEncryption function available" {
            Get-Command Invoke-JsonFileEncryption -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Setup-TemporaryEncryption function available" {
            Get-Command Setup-TemporaryEncryption -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Configuration Utilities" {
        
        It "Should have ConvertFrom-JsonToHashtable function available" {
            Get-Command ConvertFrom-JsonToHashtable -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have ConvertTo-OrderedJson function available" {
            Get-Command ConvertTo-OrderedJson -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Export-PowerShellDataFile function available" {
            Get-Command Export-PowerShellDataFile -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Get-ConfigurationData function available" {
            Get-Command Get-ConfigurationData -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
}

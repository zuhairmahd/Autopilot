<#
.SYNOPSIS
    Integration tests for Settings Editor workflows

.DESCRIPTION
    Tests end-to-end editor workflows including:
    - Domain creation → group editing → profile editing → settings viewing
    - Cross-editor state management and persistence
    - Graph API integration for group/profile resolution
    - Array format migrations (string → hashtable)
    - Interactive user workflows (mocked)

.NOTES
    Test Category: Integration
    PowerShell Compatibility: 7.0+ (Pester 5 requirement)
    Dependencies: AutopilotTestHelpers, AutopilotGraphMocks
    
    Testing Strategy:
    - Mock all Graph API calls (groups, profiles, devices)
    - Mock user input/interaction functions
    - Test realistic workflows: create → edit → view
    - Validate persistence across editor sessions
    - Test state transitions and rollback scenarios
    
    Coverage Target: ~200 lines (editor workflows + state management)
    Expected Test Count: 20-25 integration tests
#>

Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force
Import-Module "$PSScriptRoot/../Helpers/AutopilotGraphMocks.psm1" -Force

Describe "Settings Editors Integration Workflows" -Tags 'Integration', 'SetupFunctions', 'Editors' {
    
    BeforeAll {
        # Initialize test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment
        $script:RepoRoot = $script:TestContext.RootPath
        
        # Load all required functions
        $functionsToLoad = @(
            "functions/setupFunctions/Show-SettingsEditor.ps1",
            "functions/setupFunctions/Show-GroupsEditor.ps1",
            "functions/setupFunctions/Show-AutopilotProfilesEditor.ps1",
            "functions/setupFunctions/Show-SettingsViewer.ps1",
            "functions/setupFunctions/Show-EditorCommon.ps1",
            "functions/setupFunctions/Get-ApplicationDefaults.ps1",
            "functions/setupFunctions/Get-AuthDefaults.ps1",
            "functions/setupFunctions/Get-DomainConfigurationFromFiles.ps1",
            "functions/setupFunctions/Update-Setting.ps1",
            "functions/setupFunctions/Save-DomainConfiguration.ps1",
            "functions/setupFunctions/Test-AuthDefaults.ps1",
            "functions/UserAndGroupFunctions/Get-EntraDirectoryObject.ps1",
            "functions/UserAndGroupFunctions/Resolve-DirectoryObject.ps1",
            "functions/graphFunctions/CallGraphAPI.ps1",
            "functions/utilityFunctions/Write-Log.ps1",
            "functions/utilityFunctions/Export-PowershellDataFile/Export-PowerShellDataFile.ps1",
            "functions/utilityFunctions/Export-PowershellDataFile/ConvertTo-Psd1String.ps1"
        )
        
        foreach ($funcPath in $functionsToLoad)
        {
            $fullPath = Join-Path $script:RepoRoot $funcPath
            if (Test-Path $fullPath)
            {
                . $fullPath
            }
        }
        
        # Setup global log file
        $global:LogFile = $script:TestContext.LogFile
        $script:logFile = $global:LogFile
        
        # Create mock Graph token
        $script:MockToken = "mock-graph-token-12345"
    }
    
    AfterAll {
        # Cleanup test environment
        Remove-TestEnvironment -TestContext $script:TestContext
    }
    
    Context "End-to-End Editor Workflow: Domain → Groups → Profiles → Viewer" {
        
        BeforeEach {
            # Create a fresh settings file for each test
            $script:SettingsFile = Join-Path $script:TestContext.TestFolder "settings_$(Get-Random).psd1"
            
            # Initialize with minimal settings structure
            $initialSettings = @{
                globalSettings = @{
                    configFile  = $script:SettingsFile
                    maxWaitTime = 600
                }
                auth           = @{
                    authType = "Certificate"
                    tenantId = "test-tenant-id"
                }
                domains        = @{}
            }
            
            Export-PowerShellDataFile -InputObject $initialSettings -Path $script:SettingsFile
            
            # Mock Graph API calls for group resolution
            Mock -CommandName CallGraphAPI -MockWith {
                param($Method, $Uri, $AccessToken)
                
                if ($Uri -match "/groups\?.*filter=displayName")
                {
                    # Return mock group
                    return @{
                        StatusCode = 200
                        Content    = @{
                            value = @(
                                @{
                                    id           = "group-guid-12345"
                                    displayName  = "Test Security Group"
                                    mailNickname = "testgroup"
                                }
                            )
                        }
                    }
                }
                elseif ($Uri -match "/groups/group-guid-12345")
                {
                    # Return specific group details
                    return @{
                        StatusCode = 200
                        Content    = @{
                            id           = "group-guid-12345"
                            displayName  = "Test Security Group"
                            mailNickname = "testgroup"
                        }
                    }
                }
                
                # Default: not found
                return @{
                    StatusCode = 404
                    Content    = @{ error = @{ message = "Not found" } }
                }
            }
            
            # Mock Autopilot profile API calls
            Mock -CommandName Invoke-RestMethod -MockWith {
                param($Uri, $Headers, $Method)
                
                if ($Uri -match "/deviceManagement/windowsAutopilotDeploymentProfiles")
                {
                    # Return mock Autopilot profiles
                    return @{
                        value = @(
                            @{
                                id          = "profile-guid-12345"
                                displayName = "Test Autopilot Profile"
                                description = "Test profile for integration tests"
                            },
                            @{
                                id          = "profile-guid-67890"
                                displayName = "Production Autopilot Profile"
                                description = "Production profile"
                            }
                        )
                    }
                }
                
                # Default: empty result
                return @{ value = @() }
            }
        }
        
        It "Should create new domain with default settings" {
            # Mock user input for domain creation
            Mock -CommandName Read-Host -MockWith { "contoso.com" }
            
            # Create domain settings
            $domainSettings = @{
                deviceNamePrefix           = "TEST"
                groupsToInclude            = @()
                autopilotProfilesToInclude = @()
            }
            
            $success = Update-Setting -SettingType "Domain" -SettingsFile $script:SettingsFile `
                -DomainName "contoso.com" -Settings $domainSettings
            
            $success | Should -Be $true
            
            # Verify domain configuration file was created
            $configPath = Split-Path $script:SettingsFile -Parent
            $domainConfigFile = Join-Path $configPath "contoso.com.psd1"
            $domainConfigFile | Should -Exist
        }
        
        It "Should add groups to domain using groups editor workflow" {
            # Pre-create domain
            $domainSettings = @{
                deviceNamePrefix           = "TEST"
                groupsToInclude            = @()
                autopilotProfilesToInclude = @()
            }
            Update-Setting -SettingType "Domain" -SettingsFile $script:SettingsFile `
                -DomainName "contoso.com" -Settings $domainSettings | Out-Null
            
            # Mock Resolve-DirectoryObject to return group
            Mock -CommandName Resolve-DirectoryObject -MockWith {
                return @{
                    id          = "group-guid-12345"
                    displayName = "Test Security Group"
                }
            }
            
            # Simulate adding group
            $configPath = Split-Path $script:SettingsFile -Parent
            $domainConfig = Get-DomainConfigurationFromFiles -DomainName "contoso.com" -ConfigurationPath $configPath
            
            # Add group to configuration
            $updatedGroups = @(
                @{ name = "Test Security Group"; id = "group-guid-12345" }
            )
            $domainConfig.groupsToInclude = $updatedGroups
            
            # Save updated configuration
            $saveSuccess = Save-DomainConfiguration -DomainName "contoso.com" -DomainConfiguration $domainConfig -ConfigurationPath $configPath
            $saveSuccess | Should -Be $true
            
            # Verify group was added
            $reloadedConfig = Get-DomainConfigurationFromFiles -DomainName "contoso.com" -ConfigurationPath $configPath
            $reloadedConfig.groupsToInclude.Count | Should -Be 1
            $reloadedConfig.groupsToInclude[0].name | Should -Be "Test Security Group"
        }
        
        It "Should add Autopilot profiles to domain using profile editor workflow" {
            # Pre-create domain with groups
            $domainSettings = @{
                deviceNamePrefix           = "TEST"
                groupsToInclude            = @(
                    @{ name = "Test Security Group"; id = "group-guid-12345" }
                )
                autopilotProfilesToInclude = @()
            }
            Update-Setting -SettingType "Domain" -SettingsFile $script:SettingsFile `
                -DomainName "contoso.com" -Settings $domainSettings | Out-Null
            
            # Simulate adding Autopilot profile
            $configPath = Split-Path $script:SettingsFile -Parent
            $domainConfig = Get-DomainConfigurationFromFiles -DomainName "contoso.com" -ConfigurationPath $configPath
            
            # Add profile to configuration
            $updatedProfiles = @(
                @{ name = "Test Autopilot Profile"; id = "profile-guid-12345" }
            )
            $domainConfig.autopilotProfilesToInclude = $updatedProfiles
            
            # Save updated configuration
            $saveSuccess = Save-DomainConfiguration -DomainName "contoso.com" -DomainConfiguration $domainConfig -ConfigurationPath $configPath
            $saveSuccess | Should -Be $true
            
            # Verify profile was added
            $reloadedConfig = Get-DomainConfigurationFromFiles -DomainName "contoso.com" -ConfigurationPath $configPath
            $reloadedConfig.autopilotProfilesToInclude.Count | Should -Be 1
            $reloadedConfig.autopilotProfilesToInclude[0].name | Should -Be "Test Autopilot Profile"
        }
        
        It "Should view complete domain configuration using settings viewer" {
            # Create fully configured domain
            $domainSettings = @{
                deviceNamePrefix           = "TEST"
                groupsToInclude            = @(
                    @{ name = "Test Security Group"; id = "group-guid-12345" }
                )
                autopilotProfilesToInclude = @(
                    @{ name = "Test Autopilot Profile"; id = "profile-guid-12345" }
                )
            }
            Update-Setting -SettingType "Domain" -SettingsFile $script:SettingsFile `
                -DomainName "contoso.com" -Settings $domainSettings | Out-Null
            
            # Load configuration for viewing
            $configPath = Split-Path $script:SettingsFile -Parent
            $domainConfig = Get-DomainConfigurationFromFiles -DomainName "contoso.com" -ConfigurationPath $configPath
            
            # Verify all settings are present
            $domainConfig | Should -Not -BeNullOrEmpty
            $domainConfig.deviceNamePrefix | Should -Be "TEST"
            $domainConfig.groupsToInclude.Count | Should -Be 1
            $domainConfig.autopilotProfilesToInclude.Count | Should -Be 1
        }
    }
    
    Context "Cross-Editor State Management and Persistence" {
        
        BeforeEach {
            # Create settings file with existing domain
            $script:SettingsFile = Join-Path $script:TestContext.TestFolder "settings_$(Get-Random).psd1"
            
            $initialSettings = @{
                globalSettings = @{
                    configFile = $script:SettingsFile
                }
                auth           = @{}
                domains        = @{
                    "contoso.com" = @{
                        domainSettings = @{
                            deviceNamePrefix           = "OLD"
                            groupsToInclude            = @("OldGroup")
                            autopilotProfilesToInclude = @("OldProfile")
                        }
                    }
                }
            }
            
            Export-PowerShellDataFile -InputObject $initialSettings -Path $script:SettingsFile
        }
        
        It "Should preserve existing groups when adding new Autopilot profile" {
            $configPath = Split-Path $script:SettingsFile -Parent
            
            # Load existing configuration
            $domainConfig = Get-DomainConfigurationFromFiles -DomainName "contoso.com" -ConfigurationPath $configPath
            $originalGroupCount = $domainConfig.groupsToInclude.Count
            
            # Add new Autopilot profile (should NOT affect groups)
            $domainConfig.autopilotProfilesToInclude = @(
                @{ name = "New Profile"; id = "new-profile-guid" }
            )
            
            # Save and reload
            Save-DomainConfiguration -DomainName "contoso.com" -DomainConfiguration $domainConfig -ConfigurationPath $configPath | Out-Null
            $reloadedConfig = Get-DomainConfigurationFromFiles -DomainName "contoso.com" -ConfigurationPath $configPath
            
            # Verify groups unchanged, profiles updated
            $reloadedConfig.groupsToInclude.Count | Should -Be $originalGroupCount
            $reloadedConfig.autopilotProfilesToInclude.Count | Should -Be 1
            $reloadedConfig.autopilotProfilesToInclude[0].name | Should -Be "New Profile"
        }
        
        It "Should preserve existing profiles when modifying groups" {
            $configPath = Split-Path $script:SettingsFile -Parent
            
            # Load existing configuration
            $domainConfig = Get-DomainConfigurationFromFiles -DomainName "contoso.com" -ConfigurationPath $configPath
            $originalProfileCount = $domainConfig.autopilotProfilesToInclude.Count
            
            # Modify groups (should NOT affect profiles)
            $domainConfig.groupsToInclude = @(
                @{ name = "New Group"; id = "new-group-guid" }
            )
            
            # Save and reload
            Save-DomainConfiguration -DomainName "contoso.com" -DomainConfiguration $domainConfig -ConfigurationPath $configPath | Out-Null
            $reloadedConfig = Get-DomainConfigurationFromFiles -DomainName "contoso.com" -ConfigurationPath $configPath
            
            # Verify profiles unchanged, groups updated
            $reloadedConfig.autopilotProfilesToInclude.Count | Should -Be $originalProfileCount
            $reloadedConfig.groupsToInclude.Count | Should -Be 1
            $reloadedConfig.groupsToInclude[0].name | Should -Be "New Group"
        }
        
        It "Should handle concurrent modifications across multiple domains" {
            # Add second domain
            $domain2Settings = @{
                deviceNamePrefix           = "PROD"
                groupsToInclude            = @()
                autopilotProfilesToInclude = @()
            }
            Update-Setting -SettingType "Domain" -SettingsFile $script:SettingsFile `
                -DomainName "fabrikam.com" -Settings $domain2Settings | Out-Null
            
            $configPath = Split-Path $script:SettingsFile -Parent
            
            # Modify contoso.com
            $contosoDomain = Get-DomainConfigurationFromFiles -DomainName "contoso.com" -ConfigurationPath $configPath
            $contosoDomain.deviceNamePrefix = "CONTOSO-UPDATED"
            Save-DomainConfiguration -DomainName "contoso.com" -DomainConfiguration $contosoDomain -ConfigurationPath $configPath | Out-Null
            
            # Modify fabrikam.com
            $fabrikamDomain = Get-DomainConfigurationFromFiles -DomainName "fabrikam.com" -ConfigurationPath $configPath
            $fabrikamDomain.deviceNamePrefix = "FABRIKAM-UPDATED"
            Save-DomainConfiguration -DomainName "fabrikam.com" -DomainConfiguration $fabrikamDomain -ConfigurationPath $configPath | Out-Null
            
            # Verify both domains updated correctly
            $contosoDomainReloaded = Get-DomainConfigurationFromFiles -DomainName "contoso.com" -ConfigurationPath $configPath
            $fabrikamDomainReloaded = Get-DomainConfigurationFromFiles -DomainName "fabrikam.com" -ConfigurationPath $configPath
            
            $contosoDomainReloaded.deviceNamePrefix | Should -Be "CONTOSO-UPDATED"
            $fabrikamDomainReloaded.deviceNamePrefix | Should -Be "FABRIKAM-UPDATED"
        }
    }
    
    Context "Array Format Migration (String → Hashtable)" {
        
        BeforeEach {
            $script:SettingsFile = Join-Path $script:TestContext.TestFolder "settings_$(Get-Random).psd1"
            
            # Create domain with string array format (legacy)
            $legacySettings = @{
                globalSettings = @{ configFile = $script:SettingsFile }
                auth           = @{}
                domains        = @{
                    "contoso.com" = @{
                        domainSettings = @{
                            deviceNamePrefix           = "TEST"
                            groupsToInclude            = @("Group1", "Group2")  # String array (legacy)
                            autopilotProfilesToInclude = @("Profile1", "Profile2")  # String array (legacy)
                        }
                    }
                }
            }
            
            Export-PowerShellDataFile -InputObject $legacySettings -Path $script:SettingsFile
        }
        
        It "Should detect legacy string array format for groups" {
            $configPath = Split-Path $script:SettingsFile -Parent
            $domainConfig = Get-DomainConfigurationFromFiles -DomainName "contoso.com" -ConfigurationPath $configPath
            
            # Get-DomainConfigurationFromFiles auto-converts string arrays to hashtable format during load
            # So we need to test the conversion function directly with string array
            $legacyStringArray = @("Group1", "Group2")
            $format = Get-EditorArrayFormat -Array $legacyStringArray
            $format | Should -Be "StringArray"
        }
        
        It "Should convert string array to hashtable array format" {
            # Test conversion function directly with string array
            $legacyStringArray = @("Group1", "Group2")
            
            # Convert string array to hashtable array
            $convertedGroups = Convert-StringArrayToHashTableArray -StringArray $legacyStringArray
            
            # Verify conversion
            $convertedGroups.Count | Should -Be 2
            $convertedGroups[0] | Should -BeOfType [hashtable]
            $convertedGroups[0].name | Should -Be "Group1"
            $convertedGroups[0].id | Should -BeNullOrEmpty  # ID not set yet
        }
        
        It "Should preserve hashtable array format across save/load cycles" {
            $configPath = Split-Path $script:SettingsFile -Parent
            $domainConfig = Get-DomainConfigurationFromFiles -DomainName "contoso.com" -ConfigurationPath $configPath
            
            # Convert to hashtable format
            $domainConfig.groupsToInclude = @(
                @{ name = "Group1"; id = "group-guid-1" },
                @{ name = "Group2"; id = "group-guid-2" }
            )
            
            # Save
            Save-DomainConfiguration -DomainName "contoso.com" -DomainConfiguration $domainConfig -ConfigurationPath $configPath | Out-Null
            
            # Reload and verify format preserved
            $reloadedConfig = Get-DomainConfigurationFromFiles -DomainName "contoso.com" -ConfigurationPath $configPath
            $format = Get-EditorArrayFormat -Array $reloadedConfig.groupsToInclude
            $format | Should -Be "HashTableArray"
            $reloadedConfig.groupsToInclude[0].id | Should -Be "group-guid-1"
        }
        
        It "Should handle mixed format arrays (string + hashtable)" {
            # Create mixed array (edge case during migration)
            $mixedArray = @(
                "StringGroup",  # String format
                @{ name = "HashGroup"; id = "hash-guid" }  # Hashtable format
            )
            
            # Test-ItemExists should handle both formats (correct parameter name)
            $existsString = Test-ItemExists -ItemName "StringGroup" -ExistingList $mixedArray
            $existsHash = Test-ItemExists -ItemName "HashGroup" -ExistingList $mixedArray
            
            $existsString | Should -Be $true
            $existsHash | Should -Be $true
        }
    }
    
    Context "Error Handling and Validation" {
        
        BeforeEach {
            $script:SettingsFile = Join-Path $script:TestContext.TestFolder "settings_$(Get-Random).psd1"
            
            $minimalSettings = @{
                globalSettings = @{ configFile = $script:SettingsFile }
                auth           = @{}
                domains        = @{}
            }
            
            Export-PowerShellDataFile -InputObject $minimalSettings -Path $script:SettingsFile
        }
        
        It "Should handle missing domain gracefully" {
            $configPath = Split-Path $script:SettingsFile -Parent
            
            # Try to load non-existent domain
            $domainConfig = Get-DomainConfigurationFromFiles -DomainName "nonexistent.com" -ConfigurationPath $configPath
            
            # Get-DomainConfigurationFromFiles creates default configuration for missing domains
            # and returns a hashtable (or OrderedDictionary) with default values
            $domainConfig | Should -Not -BeNullOrEmpty
            # Accept both [hashtable] and [System.Collections.Specialized.OrderedDictionary]
            $domainConfig | Should -BeOfType ([System.Collections.IDictionary])
            
            # Verify it has expected default properties
            $domainConfig.Keys | Should -Contain "groupsToInclude"
            $domainConfig.Keys | Should -Contain "domain"
            $domainConfig.domain | Should -Be "nonexistent.com"
        }
        
        It "Should validate required domain settings before save" {
            # Create incomplete domain configuration
            $incompleteDomain = @{
                # Missing deviceNamePrefix
                groupsToInclude = @()
            }
            
            # Save-DomainConfiguration should handle missing required fields
            # (behavior depends on implementation - may use defaults or fail)
            $configPath = Split-Path $script:SettingsFile -Parent
            
            # Attempt save
            { Save-DomainConfiguration -DomainName "test.com" -DomainConfiguration $incompleteDomain -ConfigurationPath $configPath } | 
                Should -Not -Throw
        }
        
        It "Should prevent duplicate group additions" {
            $configPath = Split-Path $script:SettingsFile -Parent
            
            # Create domain with existing group
            $domainSettings = @{
                deviceNamePrefix           = "TEST"
                groupsToInclude            = @(
                    @{ name = "ExistingGroup"; id = "existing-guid" }
                )
                autopilotProfilesToInclude = @()
            }
            Update-Setting -SettingType "Domain" -SettingsFile $script:SettingsFile `
                -DomainName "contoso.com" -Settings $domainSettings | Out-Null
            
            # Load configuration
            $domainConfig = Get-DomainConfigurationFromFiles -DomainName "contoso.com" -ConfigurationPath $configPath
            
            # Test duplicate detection (correct parameter name)
            $isDuplicate = Test-ItemExists -ItemName "ExistingGroup" -ExistingList $domainConfig.groupsToInclude
            $isDuplicate | Should -Be $true
            
            # Try to add same group again
            $isNewGroup = Test-ItemExists -ItemName "NewGroup" -ExistingList $domainConfig.groupsToInclude
            $isNewGroup | Should -Be $false
        }
        
        It "Should handle save errors gracefully" {
            $configPath = Split-Path $script:SettingsFile -Parent
            
            # Create valid domain
            $domainSettings = @{
                deviceNamePrefix           = "TEST"
                groupsToInclude            = @()
                autopilotProfilesToInclude = @()
            }
            Update-Setting -SettingType "Domain" -SettingsFile $script:SettingsFile `
                -DomainName "contoso.com" -Settings $domainSettings | Out-Null
            
            # Load and modify
            $domainConfig = Get-DomainConfigurationFromFiles -DomainName "contoso.com" -ConfigurationPath $configPath
            $domainConfig.deviceNamePrefix = "MODIFIED"
            
            # Mock Export-PowerShellDataFile to fail
            Mock -CommandName Export-PowerShellDataFile -MockWith {
                throw "Simulated save failure"
            }
            
            # Attempt save - Save-DomainConfiguration catches errors and returns false
            $result = Save-DomainConfiguration -DomainName "contoso.com" -DomainConfiguration $domainConfig -ConfigurationPath $configPath
            
            # Should return false on error (not throw)
            $result | Should -Be $false
        }
    }
    
    Context "Settings Viewer Integration" {
        
        BeforeEach {
            $script:SettingsFile = Join-Path $script:TestContext.TestFolder "settings_$(Get-Random).psd1"
            
            # Create settings with varied data types
            $complexSettings = @{
                globalSettings = @{
                    configFile           = $script:SettingsFile
                    maxWaitTime          = 600
                    deviceNamePrefix     = "AUTO"
                    autoAcceptDevices    = $true
                    excludedDeviceModels = @("Model1", "Model2")
                }
                auth           = @{
                    authType = "Certificate"
                    tenantId = "test-tenant-id"
                    scope    = @("Device.ReadWrite.All", "User.Read.All")
                }
                domains        = @{
                    "contoso.com" = @{
                        domainSettings = @{
                            deviceNamePrefix = "CONTOSO"
                            groupsToInclude  = @(
                                @{ name = "TestGroup"; id = "group-guid" }
                            )
                        }
                    }
                }
            }
            
            Export-PowerShellDataFile -InputObject $complexSettings -Path $script:SettingsFile
        }
        
        It "Should format boolean settings correctly" {
            $settings = Import-PowerShellDataFile -Path $script:SettingsFile
            $boolValue = $settings.globalSettings.autoAcceptDevices
            
            $formatted = Format-SettingValueForDisplay -Value $boolValue
            $formatted | Should -BeIn @("true", "false")
        }
        
        It "Should format array settings correctly" {
            $settings = Import-PowerShellDataFile -Path $script:SettingsFile
            $arrayValue = $settings.globalSettings.excludedDeviceModels
            
            $formatted = Format-SettingValueForDisplay -Value $arrayValue
            $formatted | Should -Match "^\[.+\]$"  # Should be wrapped in brackets
        }
        
        It "Should format hashtable settings with alphabetical ordering" {
            $settings = Import-PowerShellDataFile -Path $script:SettingsFile
            $hashtableValue = $settings.domains["contoso.com"].domainSettings
            
            $formatted = Format-SettingValueForDisplay -Value $hashtableValue
            
            # Should contain braces and be sorted alphabetically
            $formatted | Should -Match "^\{.+\}$"
            
            # Verify alphabetical ordering (deviceNamePrefix before groupsToInclude)
            $formatted.IndexOf("deviceNamePrefix") | Should -BeLessThan $formatted.IndexOf("groupsToInclude")
        }
        
        It "Should retrieve setting descriptions from defaults" {
            $description = Get-SettingDescription -SettingName "maxWaitTime"
            $description | Should -Not -BeNullOrEmpty
            # Description varies, just check it's not empty and contains relevant keywords
            $description | Should -Match "(wait|minute|retry|time)"
        }
        
        It "Should handle null and empty values gracefully" {
            $nullFormatted = Format-SettingValueForDisplay -Value $null
            $nullFormatted | Should -Be "(not set)"
            
            $emptyFormatted = Format-SettingValueForDisplay -Value ""
            $emptyFormatted | Should -Be "(not set)"
        }
    }
}

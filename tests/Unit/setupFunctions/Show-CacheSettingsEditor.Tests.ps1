<#
.SYNOPSIS
    Pester tests for Show-CacheSettingsEditor.ps1

.DESCRIPTION
    Unit tests for cache settings editor.
    Tests cache configuration editing functionality.

.NOTES
    Test Category: Unit
    Dependencies: Show-CacheSettingsEditor.ps1, AutopilotTestHelpers
    Template Compliance: Full
    PowerShell: 5.1+ compatible
    
    Functions Tested:
    - Show-CacheSettingsEditor
#>

# Import test helpers
Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: Show-CacheSettingsEditor" -Tags 'Unit', 'CacheSettingsEditor', 'SettingsEditor' {
    
    BeforeAll {
        # Initialize test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment
        $script:RootPath = $script:TestContext.RootPath
        
        # Dot-source the function under test and dependencies
        . "$script:RootPath/functions/setupFunctions/Show-CacheSettingsEditor.ps1"
        . "$script:RootPath/functions/setupFunctions/Show-EditorCommon.ps1"
        . "$script:RootPath/functions/setupFunctions/Get-ConfigurationData.ps1"
        . "$script:RootPath/functions/setupFunctions/Update-Setting.ps1"
        . "$script:RootPath/functions/setupFunctions/Get-ApplicationDefaults.ps1"
        . "$script:RootPath/functions/utilityFunctions/Write-Log.ps1"
        . "$script:RootPath/functions/utilityFunctions/Settings-Utilities.ps1"
        . "$script:RootPath/functions/utilityFunctions/Export-PowershellDataFile/Export-PowerShellDataFile.ps1"
        
        # Setup global log file
        $global:LogFile = $script:TestContext.LogFile
        
        # Create test settings file with cacheSettings
        $script:TestSettingsFile = Join-Path $script:TestContext.TempDir "test-settings.psd1"
        $testSettings = @{
            description    = 'Test settings for CacheSettingsEditor'
            version        = '1.3.0.0'
            auth           = @{
                authType = 'PublicAuthFlow'
                scope    = @('Device.ReadWrite.All')
            }
            globalSettings = @{
                configFile     = '.\.secrets\config.json'
                maxWaitTime    = 30
                appModes       = @('full')
                cacheSettings  = @{
                    enabled                  = $true
                    defaultExpirationMinutes = 15
                    maxCacheSize             = 1000
                    cacheTypes               = @{
                        Configuration    = @{
                            enabled           = $true
                            expirationMinutes = 60
                        }
                        DirectoryObjects = @{
                            enabled           = $true
                            expirationMinutes = 15
                        }
                        Devices          = @{
                            enabled           = $true
                            expirationMinutes = 15
                        }
                    }
                }
                autoUpdate     = $true
            }
        }
        
        Export-PowerShellDataFile -Path $script:TestSettingsFile -Data $testSettings
    }
    
    AfterAll {
        # Cleanup
        Remove-TestEnvironment -TestContext $script:TestContext
    }
    
    Context "Basic Functionality" {
        
        It "Should fail if settings file does not exist" {
            $nonExistentFile = Join-Path $script:TestContext.TempDir "nonexistent.psd1"
            $result = Show-CacheSettingsEditor -SettingsFile $nonExistentFile -Silent
            $result | Should -Be $false
        }
        
        It "Should load existing cacheSettings successfully" {
            Mock ShowMenu { return "Back" } -ModuleName $null
            Mock NewMenu { return @{ Title = "Test"; items = @() } } -ModuleName $null
            Mock AddMenuItem { param($Menu) return $Menu } -ModuleName $null
            
            # The function should be able to load the file without errors
            { Show-CacheSettingsEditor -SettingsFile $script:TestSettingsFile -Silent } | Should -Not -Throw
        }
    }
    
    Context "Settings File Validation" {
        
        It "Should handle missing globalSettings section gracefully" {
            $testFile = Join-Path $script:TestContext.TempDir "no-global.psd1"
            $testData = @{
                description = 'Test'
                version     = '1.0.0'
            }
            Export-PowerShellDataFile -Path $testFile -Data $testData
            
            $result = Show-CacheSettingsEditor -SettingsFile $testFile -Silent
            $result | Should -Be $false
        }
        
        It "Should use defaults when cacheSettings section is missing" {
            $testFile = Join-Path $script:TestContext.TempDir "no-cache.psd1"
            $testData = @{
                description    = 'Test'
                version        = '1.0.0'
                globalSettings = @{
                    configFile = '.\.secrets\config.json'
                }
            }
            Export-PowerShellDataFile -Path $testFile -Data $testData
            
            Mock ShowMenu { return "Back" } -ModuleName $null
            Mock NewMenu { return @{ Title = "Test"; items = @() } } -ModuleName $null
            Mock AddMenuItem { param($Menu) return $Menu } -ModuleName $null
            
            # Should not throw even without cacheSettings section
            { Show-CacheSettingsEditor -SettingsFile $testFile -Silent } | Should -Not -Throw
        }
    }
    
    Context "Parameter Validation" {
        
        It "Should accept SettingsFile parameter" {
            $params = (Get-Command Show-CacheSettingsEditor).Parameters
            $params.ContainsKey('SettingsFile') | Should -Be $true
        }
        
        It "Should accept Silent parameter" {
            $params = (Get-Command Show-CacheSettingsEditor).Parameters
            $params.ContainsKey('Silent') | Should -Be $true
        }
        
        It "Should have default value for SettingsFile" {
            $params = (Get-Command Show-CacheSettingsEditor).Parameters
            $params['SettingsFile'].Attributes.DefaultValue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Return Values" {
        
        It "Should return false on error" {
            $nonExistentFile = Join-Path $script:TestContext.TempDir "error.psd1"
            $result = Show-CacheSettingsEditor -SettingsFile $nonExistentFile -Silent
            $result | Should -Be $false
        }
        
        It "Should return navigation command when user selects Back" {
            Mock ShowMenu { return "Back" } -ModuleName $null
            Mock NewMenu { return @{ Title = "Test"; items = @() } } -ModuleName $null
            Mock AddMenuItem { param($Menu) return $Menu } -ModuleName $null
            
            $result = Show-CacheSettingsEditor -SettingsFile $script:TestSettingsFile
            $result | Should -Be "Back"
        }
    }
    
    Context "Nested Structure Handling" {
        
        It "Should handle nested cacheTypes structure" {
            # Load the test settings and verify structure is preserved
            $config = Get-ConfigurationData -ConfigurationFile $script:TestSettingsFile
            
            $config.globalSettings.cacheSettings | Should -Not -BeNullOrEmpty
            $config.globalSettings.cacheSettings.cacheTypes | Should -Not -BeNullOrEmpty
            $config.globalSettings.cacheSettings.cacheTypes.Configuration | Should -Not -BeNullOrEmpty
            $config.globalSettings.cacheSettings.cacheTypes.DirectoryObjects | Should -Not -BeNullOrEmpty
            $config.globalSettings.cacheSettings.cacheTypes.Devices | Should -Not -BeNullOrEmpty
        }
    }
}

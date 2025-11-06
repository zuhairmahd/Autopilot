<#
.SYNOPSIS
    Pester tests for Show-RepoInfoEditor.ps1

.DESCRIPTION
    Unit tests for repository information settings editor.
    Tests repository configuration editing functionality.

.NOTES
    Test Category: Unit
    Dependencies: Show-RepoInfoEditor.ps1, AutopilotTestHelpers
    Template Compliance: Full
    PowerShell: 5.1+ compatible
    
    Functions Tested:
    - Show-RepoInfoEditor
#>

# Import test helpers
Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: Show-RepoInfoEditor" -Tags 'Unit', 'RepoInfoEditor', 'SettingsEditor' {
    
    BeforeAll {
        # Initialize test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment
        $script:RootPath = $script:TestContext.RootPath
        
        # Dot-source the function under test and dependencies
        . "$script:RootPath/functions/setupFunctions/Show-RepoInfoEditor.ps1"
        . "$script:RootPath/functions/setupFunctions/Show-EditorCommon.ps1"
        . "$script:RootPath/functions/setupFunctions/Get-ConfigurationData.ps1"
        . "$script:RootPath/functions/setupFunctions/Update-Setting.ps1"
        . "$script:RootPath/functions/setupFunctions/Get-ApplicationDefaults.ps1"
        . "$script:RootPath/functions/utilityFunctions/Write-Log.ps1"
        . "$script:RootPath/functions/utilityFunctions/Settings-Utilities.ps1"
        . "$script:RootPath/functions/utilityFunctions/Export-PowershellDataFile/Export-PowerShellDataFile.ps1"
        
        # Setup global log file
        $global:LogFile = $script:TestContext.LogFile
        
        # Create test settings file with repoInfo
        $script:TestSettingsFile = Join-Path $script:TestContext.TempDir "test-settings.psd1"
        $testSettings = @{
            description    = 'Test settings for RepoInfoEditor'
            version        = '1.3.0.0'
            auth           = @{
                authType = 'PublicAuthFlow'
                scope    = @('Device.ReadWrite.All')
            }
            globalSettings = @{
                configFile    = '.\.secrets\config.json'
                maxWaitTime   = 30
                appModes      = @('full')
                repoInfo      = @{
                    repoName      = 'TestRepo'
                    baseSourceURL = 'https://test.githubusercontent.com'
                    baseURL       = 'https://test.github.com'
                    repoPath      = 'testuser'
                }
                autoUpdate    = $true
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
            $result = Show-RepoInfoEditor -SettingsFile $nonExistentFile -Silent
            $result | Should -Be $false
        }
        
        It "Should load existing repoInfo settings successfully" {
            # This test validates the function can read the settings file
            # We use Silent mode to avoid interactive prompts
            # Since we can't interact with the menu in tests, we expect it to return false
            # when no navigation choice is made
            Mock ShowMenu { return "Back" } -ModuleName $null
            Mock NewMenu { return @{ Title = "Test"; items = @() } } -ModuleName $null
            Mock AddMenuItem { param($Menu) return $Menu } -ModuleName $null
            
            # The function should be able to load the file without errors
            { Show-RepoInfoEditor -SettingsFile $script:TestSettingsFile -Silent } | Should -Not -Throw
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
            
            $result = Show-RepoInfoEditor -SettingsFile $testFile -Silent
            $result | Should -Be $false
        }
        
        It "Should use defaults when repoInfo section is missing" {
            $testFile = Join-Path $script:TestContext.TempDir "no-repoinfo.psd1"
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
            
            # Should not throw even without repoInfo section
            { Show-RepoInfoEditor -SettingsFile $testFile -Silent } | Should -Not -Throw
        }
    }
    
    Context "Parameter Validation" {
        
        It "Should accept SettingsFile parameter" {
            $params = (Get-Command Show-RepoInfoEditor).Parameters
            $params.ContainsKey('SettingsFile') | Should -Be $true
        }
        
        It "Should accept Silent parameter" {
            $params = (Get-Command Show-RepoInfoEditor).Parameters
            $params.ContainsKey('Silent') | Should -Be $true
        }
        
        It "Should have default value for SettingsFile" {
            $params = (Get-Command Show-RepoInfoEditor).Parameters
            $params['SettingsFile'].Attributes.DefaultValue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Return Values" {
        
        It "Should return false on error" {
            $nonExistentFile = Join-Path $script:TestContext.TempDir "error.psd1"
            $result = Show-RepoInfoEditor -SettingsFile $nonExistentFile -Silent
            $result | Should -Be $false
        }
        
        It "Should return navigation command when user selects Back" {
            Mock ShowMenu { return "Back" } -ModuleName $null
            Mock NewMenu { return @{ Title = "Test"; items = @() } } -ModuleName $null
            Mock AddMenuItem { param($Menu) return $Menu } -ModuleName $null
            
            $result = Show-RepoInfoEditor -SettingsFile $script:TestSettingsFile
            $result | Should -Be "Back"
        }
    }
}

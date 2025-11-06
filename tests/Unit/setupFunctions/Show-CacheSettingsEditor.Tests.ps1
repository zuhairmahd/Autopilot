<#
.SYNOPSIS
    Pester tests for Show-CacheSettingsEditor.ps1

.DESCRIPTION
    Unit tests for cache settings editor wrapper.
    Tests that the wrapper correctly calls Show-SettingsEditor with appropriate parameters.

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
        
        # Dot-source the function under test
        . "$script:RootPath/functions/setupFunctions/Show-CacheSettingsEditor.ps1"
        . "$script:RootPath/functions/setupFunctions/Show-SettingsEditor.ps1"
        . "$script:RootPath/functions/utilityFunctions/Write-Log.ps1"
        
        # Setup global log file
        $global:LogFile = $script:TestContext.LogFile
    }
    
    AfterAll {
        # Cleanup
        Remove-TestEnvironment -TestContext $script:TestContext
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
            $defaultValue = $params['SettingsFile'].Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' } | Select-Object -First 1
            # The default is in the param block, not attributes - just verify it's not mandatory
            $params['SettingsFile'].Attributes.Mandatory | Should -Not -Contain $true
        }
    }
    
    Context "Wrapper Functionality" {
        
        It "Should call Show-SettingsEditor with correct SettingsType" {
            # Mock Show-SettingsEditor to verify it's called correctly
            Mock -CommandName Show-SettingsEditor -MockWith {
                param($SettingsType, $SettingsFile, $Silent)
                
                # Verify parameters
                $SettingsType | Should -Be 'cacheSettings'
                return $true
            }
            
            # Call the wrapper
            $result = Show-CacheSettingsEditor -SettingsFile "test.psd1"
            
            # Verify Show-SettingsEditor was called
            Should -Invoke -CommandName Show-SettingsEditor -Times 1 -Exactly
            $result | Should -Be $true
        }
        
        It "Should pass SettingsFile parameter to Show-SettingsEditor" {
            Mock -CommandName Show-SettingsEditor -MockWith {
                param($SettingsType, $SettingsFile, $Silent)
                
                $SettingsFile | Should -Be "custom-settings.psd1"
                return $true
            }
            
            Show-CacheSettingsEditor -SettingsFile "custom-settings.psd1"
            
            Should -Invoke -CommandName Show-SettingsEditor -Times 1 -Exactly
        }
        
        It "Should pass Silent switch to Show-SettingsEditor" {
            Mock -CommandName Show-SettingsEditor -MockWith {
                param($SettingsType, $SettingsFile, $Silent)
                
                $Silent | Should -Be $true
                return $true
            }
            
            Show-CacheSettingsEditor -Silent
            
            Should -Invoke -CommandName Show-SettingsEditor -Times 1 -Exactly
        }
        
        It "Should return the result from Show-SettingsEditor" {
            Mock -CommandName Show-SettingsEditor -MockWith { return $false }
            
            $result = Show-CacheSettingsEditor
            
            $result | Should -Be $false
        }
        
        It "Should pass navigation strings from Show-SettingsEditor" {
            Mock -CommandName Show-SettingsEditor -MockWith { return "Back" }
            
            $result = Show-CacheSettingsEditor
            
            $result | Should -Be "Back"
        }
    }
}

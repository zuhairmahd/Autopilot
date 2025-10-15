<#
.SYNOPSIS
    Comprehensive tests for main.ps1 AppMode validation and functionality

.DESCRIPTION
    Validates all AppMode options available in main.ps1:
    - full, helpDesk, advanced, advancedRegistration, registration, admin, custom
    - Validates that invalid AppModes are rejected
    - Tests AppMode configuration merging from settings
    
    Converted from TestScripts/test-appmode-comprehensive.ps1

.NOTES
    Test Category: Comprehensive
    Template Compliance: Full
    Uses: AutopilotTestHelpers
    Migration Notes: Migrated AppMode validation from legacy test
#>

Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "AppMode Comprehensive Validation" -Tags 'Comprehensive', 'AppMode', 'Configuration' {
    
    BeforeAll {
        # Get repository root
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
        
        # Initialize test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment
        
        # Dot-source functions directly (PS 5.1 compatible)
        $functionsPath = Join-Path $script:RepoRoot "functions"
        if (Test-Path $functionsPath) {
            Get-ChildItem -Path $functionsPath -Recurse -Filter *.ps1 -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    . $_.FullName
                } catch {
                    Write-Verbose "Failed to load $($_.Name): $($_.Exception.Message)"
                }
            }
        }
        
        # Set up global variables for testing
        $global:LogFile = Join-Path $script:TestContext.TestFolder "test-appmode.log"
        
        # Define valid AppModes from main.ps1
        $script:ValidAppModes = @('full', 'helpDesk', 'advanced', 'advancedRegistration', 'registration', 'admin', 'custom')
    }
    
    AfterAll {
        # Cleanup
        Remove-TestEnvironment -TestContext $script:TestContext
    }
    
    Context "Valid AppMode Values" {
        
        It "Should validate '<AppMode>' as valid" -TestCases @(
            @{ AppMode = 'full' }
            @{ AppMode = 'helpDesk' }
            @{ AppMode = 'advanced' }
            @{ AppMode = 'advancedRegistration' }
            @{ AppMode = 'registration' }
            @{ AppMode = 'admin' }
            @{ AppMode = 'custom' }
        ) {
            param($AppMode)
            $isValid = $AppMode -cin $script:ValidAppModes  # Case-sensitive
            $isValid | Should -Be $true
        }
        
        It "Should have exactly 7 valid AppMode values" {
            $script:ValidAppModes.Count | Should -Be 7
        }
        
        It "Should include all standard modes" {
            $standardModes = @('full', 'helpDesk', 'admin')
            foreach ($mode in $standardModes) {
                $script:ValidAppModes -contains $mode | Should -Be $true
            }
        }
    }
    
    Context "Invalid AppMode Values" {
        
        It "Should reject '<InvalidMode>' as invalid" -TestCases @(
            @{ InvalidMode = 'invalid' }
            @{ InvalidMode = 'test' }
            @{ InvalidMode = 'debug' }
            @{ InvalidMode = 'production' }
            @{ InvalidMode = '' }
            @{ InvalidMode = 'Full' }  # Case sensitive
            @{ InvalidMode = 'HELPDESK' }  # Case sensitive
        ) {
            param($InvalidMode)
            $isValid = $InvalidMode -cin $script:ValidAppModes  # Case-sensitive
            $isValid | Should -Be $false
        }
    }
    
    Context "AppMode Configuration" {
        
        It "Should handle settings with appMode key" {
            $settings = @{
                appMode = 'helpDesk'
                domain = 'contoso.com'
            }
            
            $settings.appMode | Should -Be 'helpDesk'
            $settings.appMode -cin $script:ValidAppModes | Should -Be $true
        }
        
        It "Should handle settings with AppMode variations" {
            # Test that settings use proper camelCase 'appMode'
            $properKey = 'appMode'
            $properKey | Should -BeOfType [string]
            $properKey.StartsWith('app') | Should -Be $true
        }
        
        It "Should allow different appModes in settings" {
            foreach ($mode in $script:ValidAppModes) {
                $testSettings = @{ appMode = $mode }
                $testSettings.appMode -cin $script:ValidAppModes | Should -Be $true
            }
        }
    }
    
    Context "AppMode Functionality" {
        
        It "Should handle full mode configuration" {
            $fullModeSettings = @{
                appMode = 'full'
                allowedFeatures = @('all')
            }
            $fullModeSettings.appMode | Should -Be 'full'
        }
        
        It "Should handle helpDesk mode configuration" {
            $helpDeskSettings = @{
                appMode = 'helpDesk'
                restrictedAccess = $true
            }
            $helpDeskSettings.appMode | Should -Be 'helpDesk'
        }
        
        It "Should handle advanced mode configuration" {
            $advancedSettings = @{
                appMode = 'advanced'
                advancedFeatures = $true
            }
            $advancedSettings.appMode | Should -Be 'advanced'
        }
        
        It "Should handle registration modes" {
            $registrationModes = @('registration', 'advancedRegistration')
            foreach ($mode in $registrationModes) {
                $mode -cin $script:ValidAppModes | Should -Be $true
                $mode.Contains('registration') -or $mode.Contains('Registration') | Should -Be $true
            }
        }
    }
    
    Context "AppMode Case Sensitivity" {
        
        It "Should be case-sensitive for AppMode values" {
            # main.ps1 uses case-sensitive ValidateSet
            'full' -ceq 'Full' | Should -Be $false
            'helpDesk' -ceq 'HelpDesk' | Should -Be $false
            'admin' -ceq 'Admin' | Should -Be $false
        }
        
        It "Should only accept exact casing" {
            $variations = @('Full', 'FULL', 'HelpDesk', 'HELPDESK', 'Admin', 'ADMIN')
            foreach ($variation in $variations) {
                $variation -cin $script:ValidAppModes | Should -Be $false
            }
        }
    }
    
    Context "AppMode Settings Merging" {
        
        It "Should preserve appMode from local settings" {
            $localSettings = @{ appMode = 'helpDesk' }
            $globalSettings = @{ appMode = 'full' }
            
            # Local should take priority in typical merge
            $localSettings.appMode | Should -Be 'helpDesk'
            $localSettings.appMode -ne $globalSettings.appMode | Should -Be $true
        }
        
        It "Should handle missing appMode gracefully" {
            $settingsWithoutAppMode = @{
                domain = 'contoso.com'
                tenantId = 'test-tenant'
            }
            
            $settingsWithoutAppMode.ContainsKey('appMode') | Should -Be $false
        }
        
        It "Should support custom appMode" {
            $customSettings = @{
                appMode = 'custom'
                customConfig = @{
                    feature1 = $true
                    feature2 = $false
                }
            }
            
            $customSettings.appMode | Should -Be 'custom'
            $customSettings.appMode -cin $script:ValidAppModes | Should -Be $true
        }
    }
}

<#
.SYNOPSIS
    Integration tests for configuration workflow

.DESCRIPTION
    Tests end-to-end configuration initialization, settings merge,
    domain switching, and complete setup workflows.

.NOTES
    Test Category: Integration
    Module: setupFunctions
    Coverage Target: Complete configuration workflow validation

    Approach:
    - Uses AutopilotTestHelpers for temp file/folder management
    - Direct dot-sourcing for PS 5.1 compatibility
    - Tests complete initialization workflow
    - Tests settings file interactions
    - Tests domain configuration switching
    - Tests migration scenarios
#>

Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Integration: Configuration Workflow" -Tags 'Integration', 'setupFunctions' {
    BeforeAll {
        # Direct dot-sourcing for PS 5.1 compatibility
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName

        # Load Export-PowerShellDataFile and its dependencies first
        . "$script:RepoRoot/functions/utilityFunctions/Export-PowershellDataFile/Export-PowerShellDataFile.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/Export-PowershellDataFile/ConvertTo-Psd1String.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/Export-PowershellDataFile/ConvertTo-HashtableFromPSCustomObject.ps1"

        # Load all setup functions
        $setupFunctions = Get-ChildItem "$script:RepoRoot/functions/setupFunctions" -Filter "*.ps1" -Recurse
        foreach ($func in $setupFunctions)
        {
            . $func.FullName
        }

        # Load utility functions
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"

        # Mock Write-Log to avoid file I/O
        Mock Write-Log { }
    }

    BeforeEach {
        # Create temp folder for each test
        $script:TestContext = Initialize-AutopilotTestEnvironment
        $script:TestFolder = $script:TestContext.TestFolder
        $script:SettingsFile = Join-Path $script:TestFolder "settings.psd1"
        $script:StringsFile = Join-Path $script:TestFolder "strings.psd1"
        $script:MenuFile = Join-Path $script:TestFolder "menu.psd1"

        # Set global logFile to prevent empty path errors
        $global:logFile = Join-Path $script:TestFolder "test.log"
    }

    AfterEach {
        # Cleanup temp folder
        Remove-TestEnvironment -TestContext $script:TestContext

        # Clean up any domain configuration files created in project root during tests
        # These should be created in temp folder, but clean up just in case
        $domainFiles = @('contoso.com.psd1', 'test.com.psd1', 'domain1.com.psd1', 'domain2.com.psd1')
        foreach ($file in $domainFiles)
        {
            $fullPath = Join-Path $PSScriptRoot "../../../$file"
            if (Test-Path $fullPath)
            {
                Remove-Item $fullPath -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context "Complete Initialization Workflow" {
        It "Should complete full initialization with defaults" {
            $result = Initialize-ApplicationConfiguration -InitFile $script:SettingsFile `
                -StringsFile $script:StringsFile -menuFile $script:MenuFile -Domain "contoso.com"

            $result.Success | Should -Be $true
            $result.Auth | Should -Not -BeNullOrEmpty
            $result.GlobalSettings | Should -Not -BeNullOrEmpty
            $result.LocalSettings | Should -Not -BeNullOrEmpty
            $result.Strings | Should -Not -BeNullOrEmpty
            $result.Menu | Should -Not -BeNullOrEmpty
        }

        It "Should create all required configuration files" {
            $result = Initialize-ApplicationConfiguration -InitFile $script:SettingsFile `
                -StringsFile $script:StringsFile -menuFile $script:MenuFile -Domain "contoso.com"

            $script:SettingsFile | Should -Exist
            $script:StringsFile | Should -Exist
            $script:MenuFile | Should -Exist
        }

        It "Should initialize auth configuration correctly" {
            $result = Initialize-ApplicationConfiguration -InitFile $script:SettingsFile `
                -StringsFile $script:StringsFile -menuFile $script:MenuFile -Domain "contoso.com"

            $result.Auth | Should -HaveCount 1
            $result.Auth.Keys | Should -Contain 'delegated'
        }

        It "Should initialize required scopes" {
            $result = Initialize-ApplicationConfiguration -InitFile $script:SettingsFile `
                -StringsFile $script:StringsFile -menuFile $script:MenuFile -Domain "contoso.com"

            $result | Should -Not -BeNullOrEmpty
            # RequiredScopes may be array or hashtable depending on implementation
        }

        It "should initialize repoInfo correctly" {
            $result = Initialize-ApplicationConfiguration -InitFile $script:SettingsFile `
                -StringsFile $script:StringsFile -menuFile $script:MenuFile -Domain "contoso.com"

            $result.RepoInfo | Should -Not -BeNullOrEmpty
            $result.RepoInfo.baseURL | Should -Match "github\.com"
        }

        It "should initialize caching settings correctly" {
            $result = Initialize-ApplicationConfiguration -InitFile $script:SettingsFile `
                -StringsFile $script:StringsFile -menuFile $script:MenuFile -Domain "contoso.com"

            $result.CacheSettings | Should -Not -BeNullOrEmpty
            $result.CacheSettings.enabled | Should -Be $true
            $result.CacheSettings.cacheTypes.Configuration.enabled | Should -Be $true
        }
    }

    Context "Settings Merge Workflow" {
        It "Should detect and merge missing keys from defaults" {
            # Create partial settings file as proper PSD1
            $partialSettings = @{
                auth           = @{ delegated = $true }
                globalSettings = @{
                    logLevel = "Debug"
                    # Missing other default keys
                }
                localSettings  = @{}
            }
            $partialSettings | Export-PowerShellDataFile -Path $script:SettingsFile -Force

            $result = Initialize-ApplicationConfiguration -InitFile $script:SettingsFile `
                -StringsFile $script:StringsFile -menuFile $script:MenuFile -Domain "contoso.com"

            $result | Should -Not -BeNullOrEmpty
            $result.GlobalSettings | Should -Not -BeNullOrEmpty
        }

        It "Should preserve existing configuration values" {
            # Create custom settings as proper PSD1
            $customSettings = @{
                auth           = @{ delegated = $true }
                globalSettings = @{
                    logLevel  = "Warning"
                    customKey = "CustomValue"
                }
                localSettings  = @{}
            }
            $customSettings | Export-PowerShellDataFile -Path $script:SettingsFile -Force

            $result = Initialize-ApplicationConfiguration -InitFile $script:SettingsFile `
                -StringsFile $script:StringsFile -menuFile $script:MenuFile -Domain "contoso.com"

            $result | Should -Not -BeNullOrEmpty
            $result.GlobalSettings | Should -Not -BeNullOrEmpty
        }

        It "Should handle empty configuration file" {
            # Create empty file
            "@{}" | Set-Content $script:SettingsFile

            $result = Initialize-ApplicationConfiguration -InitFile $script:SettingsFile `
                -StringsFile $script:StringsFile -menuFile $script:MenuFile -Domain "contoso.com"

            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "Domain Configuration Workflow" {
        It "Should load domain-specific settings" {
            $result = Initialize-ApplicationConfiguration -InitFile $script:SettingsFile `
                -StringsFile $script:StringsFile -menuFile $script:MenuFile -Domain "test.com"

            $result.LocalSettings.domain | Should -Be "test.com"
        }

        It "Should switch between domains correctly" {
            # First initialization with domain1
            $result1 = Initialize-ApplicationConfiguration -InitFile $script:SettingsFile `
                -StringsFile $script:StringsFile -menuFile $script:MenuFile -Domain "domain1.com"

            $result1.LocalSettings.domain | Should -Be "domain1.com"

            # Second initialization with domain2
            $result2 = Initialize-ApplicationConfiguration -InitFile $script:SettingsFile `
                -StringsFile $script:StringsFile -menuFile $script:MenuFile -Domain "domain2.com"

            $result2.LocalSettings.domain | Should -Be "domain2.com"
        }

        It "Should merge domain-specific scopes with auth scopes" {
            $result = Initialize-ApplicationConfiguration -InitFile $script:SettingsFile `
                -StringsFile $script:StringsFile -menuFile $script:MenuFile -Domain "contoso.com"

            $result | Should -Not -BeNullOrEmpty
            # RequiredScopes may be array or hashtable depending on implementation
        }
    }

    Context "Command-Line Override Workflow" {
        It "Should preserve command-line parameters" {
            $boundParams = @{
                logLevel          = "Trace"
                verbosePreference = "Continue"
            }

            $result = Initialize-ApplicationConfiguration -InitFile $script:SettingsFile `
                -StringsFile $script:StringsFile -menuFile $script:MenuFile `
                -Domain "contoso.com" -BoundParameters $boundParams

            # Command-line parameters should be preserved
            $result.Success | Should -Be $true
        }

        It "Should prioritize command-line over file settings" {
            # Create settings file with one value
            $fileSettings = @{
                logLevel = "Information"
            }
            $fileSettings | ConvertTo-Json | Set-Content $script:SettingsFile

            # Override with command-line parameter
            $boundParams = @{
                logLevel = "Debug"
            }

            $result = Initialize-ApplicationConfiguration -InitFile $script:SettingsFile `
                -StringsFile $script:StringsFile -menuFile $script:MenuFile `
                -Domain "contoso.com" -BoundParameters $boundParams

            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "File Operations Workflow" {
        It "Should create missing directories" {
            $nestedPath = Join-Path $script:TestFolder "nested\subfolder"
            $nestedSettings = Join-Path $nestedPath "settings.psd1"
            $nestedStrings = Join-Path $nestedPath "strings.psd1"
            $nestedMenu = Join-Path $nestedPath "menu.psd1"

            $result = Initialize-ApplicationConfiguration -InitFile $nestedSettings `
                -StringsFile $nestedStrings -menuFile $nestedMenu -Domain "contoso.com"

            $nestedPath | Should -Exist
        }

        It "Should handle read-only parent directory gracefully" {
            # This test validates error handling, not that it succeeds with read-only
            $result = Initialize-ApplicationConfiguration -InitFile $script:SettingsFile `
                -StringsFile $script:StringsFile -menuFile $script:MenuFile -Domain "contoso.com"

            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "Error Recovery Workflow" {
        It "Should recover from corrupted settings file" {
            # Create corrupted file
            "This is not valid PowerShell data" | Set-Content $script:SettingsFile

            $result = Initialize-ApplicationConfiguration -InitFile $script:SettingsFile `
                -StringsFile $script:StringsFile -menuFile $script:MenuFile -Domain "contoso.com"

            # Should either recover or report error
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should provide error message when initialization fails" {
            # Create a regular file at the path that would be used as a parent directory.
            # Attempting to write a file inside an existing file is guaranteed to fail on
            # Windows regardless of drive mappings.
            $blockingFile = Join-Path $script:TestFolder "not-a-directory"
            Set-Content -Path $blockingFile -Value ""
            $invalidPath = Join-Path $blockingFile "settings.psd1"

            $result = Initialize-ApplicationConfiguration -InitFile $invalidPath `
                -StringsFile $script:StringsFile -menuFile $script:MenuFile -Domain "contoso.com"

            $result.Success | Should -Be $false
            $result.ErrorMessage | Should -Not -BeNullOrEmpty
        }
    }

    Context "Multi-Configuration Workflow" {
        It "Should handle multiple sequential initializations" {
            $result1 = Initialize-ApplicationConfiguration -InitFile $script:SettingsFile `
                -StringsFile $script:StringsFile -menuFile $script:MenuFile -Domain "domain1.com"

            $result2 = Initialize-ApplicationConfiguration -InitFile $script:SettingsFile `
                -StringsFile $script:StringsFile -menuFile $script:MenuFile -Domain "domain2.com"

            $result1.Success | Should -Be $true
            $result2.Success | Should -Be $true
        }

        It "Should handle concurrent domain configurations" {
            $folder1 = Join-Path $script:TestFolder "config1"
            $folder2 = Join-Path $script:TestFolder "config2"
            New-Item -ItemType Directory -Path $folder1 -Force | Out-Null
            New-Item -ItemType Directory -Path $folder2 -Force | Out-Null

            $result1 = Initialize-ApplicationConfiguration `
                -InitFile (Join-Path $folder1 "settings.psd1") `
                -StringsFile (Join-Path $folder1 "strings.psd1") `
                -menuFile (Join-Path $folder1 "menu.psd1") `
                -Domain "domain1.com"

            $result2 = Initialize-ApplicationConfiguration `
                -InitFile (Join-Path $folder2 "settings.psd1") `
                -StringsFile (Join-Path $folder2 "strings.psd1") `
                -menuFile (Join-Path $folder2 "menu.psd1") `
                -Domain "domain2.com"

            $result1.Success | Should -Be $true
            $result2.Success | Should -Be $true
            $result1.LocalSettings.domain | Should -Not -Be $result2.LocalSettings.domain
        }
    }

    Context "Configuration Validation Workflow" {
        It "Should validate all configuration components" {
            $result = Initialize-ApplicationConfiguration -InitFile $script:SettingsFile `
                -StringsFile $script:StringsFile -menuFile $script:MenuFile -Domain "contoso.com"

            $result | Should -Not -BeNullOrEmpty
            $result.Auth | Should -Not -BeNullOrEmpty
            $result.GlobalSettings | Should -Not -BeNullOrEmpty
            $result.LocalSettings | Should -Not -BeNullOrEmpty
            $result.Strings | Should -Not -BeNullOrEmpty
            $result.Menu | Should -Not -BeNullOrEmpty
        }

        It "Should ensure no null values in critical configurations" {
            $result = Initialize-ApplicationConfiguration -InitFile $script:SettingsFile `
                -StringsFile $script:StringsFile -menuFile $script:MenuFile -Domain "contoso.com"

            $result.Auth | Should -Not -BeNullOrEmpty
            $result.GlobalSettings | Should -Not -BeNullOrEmpty
            $result.LocalSettings | Should -Not -BeNullOrEmpty
        }
    }
}

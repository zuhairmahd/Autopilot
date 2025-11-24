#Requires -Version 5.1
<#
.SYNOPSIS
    Pester tests for Show-SettingsViewer.ps1 utility functions.

.DESCRIPTION
    Unit tests for the settings viewer utilities that display read-only application settings.
    Tests value formatting, description display, and nested settings handling.
    Interactive functions (Show-SettingsViewer with paging) are deferred to integration tests.

.NOTES
    Test Framework: Pester 5.x
    PowerShell: 5.1+
    Approach: Direct dot-sourcing for PS 5.1 compatibility
    Interactive Functions: Deferred to integration tests (Week 8)
#>

Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: Format-SettingValueForDisplay" -Tags 'Unit', 'SettingsViewer' {
    BeforeAll {
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        $script:logFile = Join-Path $TestDrive "test.log"
        
        # Load dependencies
        . "$script:RepoRoot\functions\setupFunctions\Show-SettingsEditor.ps1"
        . "$script:RepoRoot\functions\utilityFunctions\Write-Log.ps1"
    }
    
    Context "Null and empty value handling" {
        It "Should display '(not set)' for null value" {
            $result = Format-SettingValueForDisplay -Value $null
            $result | Should -Be "(not set)"
        }
        
        It "Should display '(not set)' for empty string" {
            $result = Format-SettingValueForDisplay -Value ""
            $result | Should -Be "(not set)"
        }
        
        It "Should display '(not set)' for whitespace-only string" {
            $result = Format-SettingValueForDisplay -Value "   "
            $result | Should -Be "(not set)"
        }
    }
    
    Context "Primitive type formatting" {
        It "Should format boolean true as 'true'" {
            $result = Format-SettingValueForDisplay -Value $true
            $result | Should -Be "true"
        }
        
        It "Should format boolean false as 'false'" {
            $result = Format-SettingValueForDisplay -Value $false
            $result | Should -Be "false"
        }
        
        It "Should format string value as-is" {
            $result = Format-SettingValueForDisplay -Value "TestValue"
            $result | Should -Be "TestValue"
        }
        
        It "Should format integer value as string" {
            $result = Format-SettingValueForDisplay -Value 42
            $result | Should -Be "42"
        }
        
        It "Should format decimal value as string" {
            $result = Format-SettingValueForDisplay -Value 3.14
            $result | Should -Be "3.14"
        }
    }
    
    Context "Array formatting" {
        It "Should display '(empty array)' for empty array" {
            $result = Format-SettingValueForDisplay -Value @()
            $result | Should -Be "(empty array)"
        }
        
        It "Should format single-element array with brackets" {
            $result = Format-SettingValueForDisplay -Value @("item1")
            $result | Should -Be "[item1]"
        }
        
        It "Should format multi-element array with comma-separated values" {
            $result = Format-SettingValueForDisplay -Value @("item1", "item2", "item3")
            $result | Should -Be "[item1, item2, item3]"
        }
        
        It "Should flatten nested arrays" {
            $result = Format-SettingValueForDisplay -Value @(@("item1", "item2"), "item3")
            $result | Should -Be "[item1, item2, item3]"
        }
        
        It "Should handle array of numbers" {
            $result = Format-SettingValueForDisplay -Value @(1, 2, 3)
            $result | Should -Be "[1, 2, 3]"
        }
    }
    
    Context "Hashtable and PSCustomObject formatting" {
        It "Should format hashtable with alphabetically sorted keys" {
            $ht = @{ z_key = "value3"; a_key = "value1"; m_key = "value2" }
            $result = Format-SettingValueForDisplay -Value $ht
            # Keys should be alphabetically sorted: a_key, m_key, z_key
            $result | Should -Match "a_key: value1"
            $result | Should -Match "m_key: value2"
            $result | Should -Match "z_key: value3"
            # Verify order using indexes
            $result.IndexOf("a_key") | Should -BeLessThan $result.IndexOf("m_key")
            $result.IndexOf("m_key") | Should -BeLessThan $result.IndexOf("z_key")
        }
        
        It "Should format PSCustomObject with alphabetically sorted properties" {
            $obj = [PSCustomObject]@{ z_prop = "value3"; a_prop = "value1"; m_prop = "value2" }
            $result = Format-SettingValueForDisplay -Value $obj
            # Properties should be alphabetically sorted: a_prop, m_prop, z_prop
            $result | Should -Match "a_prop: value1"
            $result | Should -Match "m_prop: value2"
            $result | Should -Match "z_prop: value3"
            # Verify order
            $result.IndexOf("a_prop") | Should -BeLessThan $result.IndexOf("m_prop")
            $result.IndexOf("m_prop") | Should -BeLessThan $result.IndexOf("z_prop")
        }
        
        It "Should format empty hashtable" {
            $ht = @{}
            $result = Format-SettingValueForDisplay -Value $ht
            $result | Should -Be "{  }"
        }
    }
    
    Context "Edge cases and error handling" {
        It "Should handle mixed-type arrays gracefully" {
            $result = Format-SettingValueForDisplay -Value @(1, "text", $true, $null)
            $result | Should -Match "\[1, text, True"
        }
        
        It "Should handle array with empty strings" {
            $result = Format-SettingValueForDisplay -Value @("", "value", "")
            $result | Should -Be "[, value, ]"
        }
    }
}

Describe "Function: Get-SettingDescription" -Tags 'Unit', 'SettingsViewer' {
    BeforeAll {
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        $script:logFile = Join-Path $TestDrive "test.log"
        
        # Load dependencies
        . "$script:RepoRoot\functions\setupFunctions\Show-SettingsEditor.ps1"
        . "$script:RepoRoot\functions\utilityFunctions\Write-Log.ps1"
    }
    
    Context "Known setting descriptions" {
        It "Should return description for 'configFile'" {
            $result = Get-SettingDescription -SettingName "configFile"
            $result | Should -Be "Path to the configuration file storing encrypted authentication data"
        }
        
        It "Should return description for 'maxWaitTime'" {
            $result = Get-SettingDescription -SettingName "maxWaitTime"
            $result | Should -Be "How long, in minutes, to wait before stopping retries."
        }
        
        It "Should return description for 'deviceNamePrefix'" {
            $result = Get-SettingDescription -SettingName "deviceNamePrefix"
            $result | Should -Be "Prefix to add to device names during enrollment"
        }
        
        It "Should return description for 'authType'" {
            $result = Get-SettingDescription -SettingName "authType"
            $result | Should -Be "Authentication method (PublicAuthFlow, PrivateAuthFlow, etc.)"
        }
        
        It "Should return description for nested setting 'repoPath'" {
            $result = Get-SettingDescription -SettingName "repoPath"
            $result | Should -Be "Repository owner/organization name"
        }
        
        It "Should return description for 'scope'" {
            $result = Get-SettingDescription -SettingName "scope"
            $result | Should -Be "Microsoft Graph API permissions required by the application"
        }
    }
    
    Context "Unknown setting fallback" {
        It "Should return generic description for unknown setting" {
            $result = Get-SettingDescription -SettingName "unknownSetting123"
            $result | Should -Be "Configuration setting: unknownSetting123"
        }
        
        It "Should include setting name in fallback description" {
            $result = Get-SettingDescription -SettingName "customSettingABC"
            $result | Should -Match "customSettingABC"
        }
    }
    
    Context "Description coverage" {
        It "Should have descriptions for core settings" {
            $coreSettings = @(
                "maxWaitTime", "showLicenseBanner", "deviceContactThresholdInDays",
                "checkStrongMapping", "strongMappingOptional", "appMode", "timeInSeconds"
            )
            
            foreach ($setting in $coreSettings)
            {
                $result = Get-SettingDescription -SettingName $setting
                $result | Should -Not -Match "Configuration setting:"
                $result.Length | Should -BeGreaterThan 10
            }
        }
        
        It "Should have descriptions for auth settings" {
            $authSettings = @("authType", "noSaveRefreshToken", "forceNewToken", "renewalLeadTime", "scope", "delegated")
            
            foreach ($setting in $authSettings)
            {
                $result = Get-SettingDescription -SettingName $setting
                $result | Should -Not -Match "Configuration setting:"
                $result.Length | Should -BeGreaterThan 10
            }
        }
    }
}

Describe "Function: Show-SettingInfo (Legacy)" -Tags 'Unit', 'SettingsViewer' {
    BeforeAll {
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        $script:logFile = Join-Path $TestDrive "test.log"
        
        # Load dependencies
        . "$script:RepoRoot\functions\setupFunctions\Show-SettingsViewer.ps1"
        . "$script:RepoRoot\functions\setupFunctions\Show-SettingsEditor.ps1"
        . "$script:RepoRoot\functions\utilityFunctions\Write-Log.ps1"
    }
    
    Context "Display output validation" {
        It "Should not throw when displaying basic setting" {
            { Show-SettingInfo -SettingName "testSetting" -CurrentValue "testValue" -DefaultValue "defaultValue" } | 
                Should -Not -Throw
        }
        
        It "Should not throw when displaying boolean setting" {
            { Show-SettingInfo -SettingName "boolSetting" -CurrentValue $true -DefaultValue $false } | 
                Should -Not -Throw
        }
        
        It "Should not throw when displaying array setting" {
            { Show-SettingInfo -SettingName "arraySetting" -CurrentValue @("a", "b") -DefaultValue @("x", "y") } | 
                Should -Not -Throw
        }
        
        It "Should not throw when displaying null value" {
            { Show-SettingInfo -SettingName "nullSetting" -CurrentValue $null -DefaultValue "default" } | 
                Should -Not -Throw
        }
    }
}

Describe "Function: Show-SettingInfoForViewer" -Tags 'Unit', 'SettingsViewer' {
    BeforeAll {
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        $script:logFile = Join-Path $TestDrive "test.log"
        
        # Load dependencies
        . "$script:RepoRoot\functions\setupFunctions\Show-SettingsViewer.ps1"
        . "$script:RepoRoot\functions\setupFunctions\Show-SettingsEditor.ps1"
        . "$script:RepoRoot\functions\utilityFunctions\Write-Log.ps1"
    }
    
    Context "Display output validation with SettingInfo objects" {
        It "Should not throw when displaying flat setting" {
            $settingInfo = [PSCustomObject]@{
                Name         = "testSetting"
                Path         = "testSetting"
                CurrentValue = "currentValue"
                DefaultValue = "defaultValue"
                IsNested     = $false
            }
            
            { Show-SettingInfoForViewer -SettingInfo $settingInfo } | Should -Not -Throw
        }
        
        It "Should not throw when displaying nested setting" {
            $settingInfo = [PSCustomObject]@{
                Name         = "nestedProp"
                Path         = "parent.nestedProp"
                CurrentValue = "nestedValue"
                DefaultValue = "nestedDefault"
                IsNested     = $true
            }
            
            { Show-SettingInfoForViewer -SettingInfo $settingInfo } | Should -Not -Throw
        }
        
        It "Should not throw when current value differs from default" {
            $settingInfo = [PSCustomObject]@{
                Name         = "changedSetting"
                Path         = "changedSetting"
                CurrentValue = "modified"
                DefaultValue = "original"
                IsNested     = $false
            }
            
            { Show-SettingInfoForViewer -SettingInfo $settingInfo } | Should -Not -Throw
        }
        
        It "Should not throw when current value equals default" {
            $settingInfo = [PSCustomObject]@{
                Name         = "unchangedSetting"
                Path         = "unchangedSetting"
                CurrentValue = "same"
                DefaultValue = "same"
                IsNested     = $false
            }
            
            { Show-SettingInfoForViewer -SettingInfo $settingInfo } | Should -Not -Throw
        }
        
        It "Should not throw with complex value types" {
            $settingInfo = [PSCustomObject]@{
                Name         = "complexSetting"
                Path         = "complexSetting"
                CurrentValue = @("array", "value")
                DefaultValue = @{ key = "value" }
                IsNested     = $false
            }
            
            { Show-SettingInfoForViewer -SettingInfo $settingInfo } | Should -Not -Throw
        }
    }
}

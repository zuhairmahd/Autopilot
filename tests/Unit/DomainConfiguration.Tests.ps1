<#
.SYNOPSIS
    Domain configuration functionality tests
.DESCRIPTION
    Tests PSD1-based domain configuration load, save, and creation functionality
    Converted from TestScripts/test-domain-config-simple.ps1
#>

Describe "Domain Configuration" -Tags 'Unit', 'Configuration', 'Domain' {
    
    BeforeAll {
        # Get repository root
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        
        # Setup test folder
        $tempPath = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
        $script:TestFolder = Join-Path $tempPath "DomainConfigTest_$(Get-Date -Format 'yyyyMMddHHmmss')"
        New-Item -Path $script:TestFolder -ItemType Directory -Force | Out-Null
        
        # Setup global variables
        $global:LogFile = Join-Path $script:TestFolder "test.log"
        
        # Load essential functions
        . (Join-Path $script:RepoRoot "functions/setupFunctions/Get-DomainConfigurationFromFiles.ps1")
        . (Join-Path $script:RepoRoot "functions/setupFunctions/Save-DomainConfiguration.ps1")
        . (Join-Path $script:RepoRoot "functions/setupFunctions/Get-ApplicationDefaults.ps1")
        . (Join-Path $script:RepoRoot "functions/setupFunctions/Get-ConfigurationData.ps1")
        . (Join-Path $script:RepoRoot "functions/utilityFunctions/Export-PowershellDataFile/Export-PowerShellDataFile.ps1")
        . (Join-Path $script:RepoRoot "functions/utilityFunctions/Export-PowershellDataFile/ConvertTo-HashtableFromPSCustomObject.ps1")
        . (Join-Path $script:RepoRoot "functions/utilityFunctions/Export-PowershellDataFile/ConvertTo-Psd1String.ps1")
        . (Join-Path $script:RepoRoot "functions/utilityFunctions/Write-Log.ps1")
    }
    
    AfterAll {
        # Cleanup test folder
        if (Test-Path $script:TestFolder) {
            Remove-Item -Path $script:TestFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context "Domain PSD1 file creation" {
        
        It "Should create domain PSD1 file with defaults" {
            # Get defaults
            $testDefaults = Get-ApplicationDefaults -DefaultType "Domain" -DomainName "testdomain.com"
            $domainPsd1File = Join-Path $script:TestFolder "testdomain.com.psd1"
            
            # Export to PSD1
            Export-PowerShellDataFile -InputObject $testDefaults -Path $domainPsd1File
            
            # Verify file exists
            Test-Path $domainPsd1File | Should -Be $true
        }
        
        It "Should load domain PSD1 file with correct data" {
            $domainPsd1File = Join-Path $script:TestFolder "testdomain.com.psd1"
            
            # Load configuration
            $loadedDomainConfig = Get-ConfigurationData -ConfigurationPath $domainPsd1File -DefaultValues @{}
            
            $loadedDomainConfig | Should -Not -BeNullOrEmpty
            $loadedDomainConfig.domain | Should -Be "testdomain.com"
        }
    }
    
    Context "Domain configuration load and save" {
        
        BeforeAll {
            $script:DomainPsd1File = Join-Path $script:TestFolder "testdomain2.com.psd1"
            $testDefaults = Get-ApplicationDefaults -DefaultType "Domain" -DomainName "testdomain2.com"
            Export-PowerShellDataFile -InputObject $testDefaults -Path $script:DomainPsd1File
        }
        
        It "Should successfully load domain configuration" {
            $loadedConfig = Get-ConfigurationData -ConfigurationPath $script:DomainPsd1File -DefaultValues @{}
            
            $loadedConfig | Should -Not -BeNullOrEmpty
            $loadedConfig.domain | Should -Be "testdomain2.com"
        }
        
        It "Should save updated configuration" {
            # Load and modify
            $loadedConfig = Get-ConfigurationData -ConfigurationPath $script:DomainPsd1File -DefaultValues @{}
            $loadedConfig.minUsernameLength = 5
            $loadedConfig.groupsToExclude += "New-Exclude-Group"
            
            # Save
            $saveResult = Export-PowerShellDataFile -InputObject $loadedConfig -Path $script:DomainPsd1File -Force
            
            $saveResult | Should -Not -BeNullOrEmpty
        }
        
        It "Should verify saved changes" {
            $verifyConfig = Get-ConfigurationData -ConfigurationPath $script:DomainPsd1File -DefaultValues @{}
            
            $verifyConfig.minUsernameLength | Should -Be 5
            $verifyConfig.groupsToExclude | Should -Contain "New-Exclude-Group"
        }
    }
    
    Context "New domain creation from defaults" {
        
        It "Should create new domain PSD1 file from application defaults" {
            $newDomainDefaults = Get-ApplicationDefaults -DefaultType "Domain" -DomainName "newdomain.com"
            $newDomainFile = Join-Path $script:TestFolder "newdomain.com.psd1"
            
            Export-PowerShellDataFile -InputObject $newDomainDefaults -Path $newDomainFile
            
            Test-Path $newDomainFile | Should -Be $true
        }
        
        It "Should load new domain configuration with correct domain name" {
            $newDomainFile = Join-Path $script:TestFolder "newdomain.com.psd1"
            $newDomainConfig = Get-ConfigurationData -ConfigurationPath $newDomainFile -DefaultValues @{}
            
            $newDomainConfig | Should -Not -BeNullOrEmpty
            $newDomainConfig.domain | Should -Be "newdomain.com"
        }
    }
}

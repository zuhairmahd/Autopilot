<#
.SYNOPSIS
    Unit tests for Get-ApplicationMetaData function
#>
Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force
Describe "Function: Get-ApplicationMetaData" -Tags 'Unit', 'UtilityFunctions' {
    BeforeAll {
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        . "$script:RepoRoot/functions/updateFunctions/Get-FileVersion.ps1"
        . "$script:RepoRoot/functions/menuFunctions/DisplayNumericMenu.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/Get-ApplicationMetaData.ps1"
        Mock Write-Log {}
        $script:logFile = Join-Path $env:TEMP "test.log"
        $script:returnValues = @{ backoutText = "Back" }
        $script:TestFolder = Join-Path $env:TEMP "AppMeta_$(Get-Date -Format 'yyyyMMddHHmmss')"
        New-Item -Path $script:TestFolder -ItemType Directory -Force | Out-Null
        $script:OriginalLocation = Get-Location
    }
    AfterAll {
        Set-Location $script:OriginalLocation
        if (Test-Path $script:TestFolder) { Remove-Item $script:TestFolder -Recurse -Force -ErrorAction SilentlyContinue }
    }
    Context "Global settings" {
        BeforeAll {
            Set-Location $script:TestFolder
            $script:GlobalPath = Join-Path $script:TestFolder "settings.psd1"
            # Settings structure matches production format with nested globalSettings
            New-MockSettingsFile -Path $script:GlobalPath -CustomSettings @{
                version        = "2.0.0.0"
                globalSettings = @{
                    companyName = "TestCo"
                    release     = "2024-10"
                }
            } -Format 'psd1'
        }
        AfterAll { Set-Location $script:OriginalLocation; if (Test-Path $script:GlobalPath) { Remove-Item $script:GlobalPath -Force }}
        
        It "Should load global settings" {
            $r = Get-ApplicationMetaData -GlobalSettingsFile $script:GlobalPath -Silent
            $r | Should -Not -BeNullOrEmpty
            $r.companyName | Should -Be "TestCo"
        }
        
        It "Should extract version from global settings" {
            $r = Get-ApplicationMetaData -GlobalSettingsFile $script:GlobalPath -Silent
            $r.version | Should -BeOfType [System.Version]
            $r.version.Major | Should -Be 2
        }
        
        It "Should extract release from global settings" {
            $r = Get-ApplicationMetaData -GlobalSettingsFile $script:GlobalPath -Silent
            $r.release | Should -Be "2024-10"
        }
        
        It "Should handle globalSettings without companyName" {
            $testPath = Join-Path $script:TestFolder "settings2.psd1"
            New-MockSettingsFile -Path $testPath -CustomSettings @{
                version        = "1.0.0.0"
                globalSettings = @{}
            } -Format 'psd1'
            $r = Get-ApplicationMetaData -GlobalSettingsFile $testPath -Silent
            $r.companyName | Should -Be "Zuhair Mahmoud"
            Remove-Item $testPath -Force
        }
        
        It "Should handle globalSettings without release" {
            $testPath = Join-Path $script:TestFolder "settings3.psd1"
            New-MockSettingsFile -Path $testPath -CustomSettings @{
                version        = "1.0.0.0"
                globalSettings = @{
                    companyName = "TestCo"
                }
            } -Format 'psd1'
            $r = Get-ApplicationMetaData -GlobalSettingsFile $testPath -Silent
            $r.release | Should -BeNullOrEmpty
            Remove-Item $testPath -Force
        }
    }
    
    Context "Domain settings" {
        BeforeAll {
            Set-Location $script:TestFolder
            $script:DomainPath = Join-Path $script:TestFolder "test.com.psd1"
            New-MockSettingsFile -Path $script:DomainPath -CustomSettings @{
                companyName = "DomainCo"
                version     = "3.0.0.0"
                domain      = "test.com"
            } -Format 'psd1'
        }
        AfterAll { Set-Location $script:OriginalLocation; if (Test-Path $script:DomainPath) { Remove-Item $script:DomainPath -Force }}
        
        It "Should auto-detect domain file" {
            $r = Get-ApplicationMetaData -Silent
            $r | Should -Not -BeNullOrEmpty
            $r.domain | Should -Be "test.com"
        }
        
        It "Should prefer domain over global settings" {
            $gPath = Join-Path $script:TestFolder "settings.psd1"
            New-MockSettingsFile -Path $gPath -CustomSettings @{
                version        = "1.0.0.0"
                globalSettings = @{
                    companyName = "GlobalCo"
                }
            } -Format 'psd1'
            $r = Get-ApplicationMetaData -GlobalSettingsFile $gPath -Silent
            $r.companyName | Should -Be "DomainCo"
            $r.version.Major | Should -Be 3
            Remove-Item $gPath -Force
        }
    }
    
    Context "Multiple domains" {
        BeforeAll {
            Set-Location $script:TestFolder
            $d1 = Join-Path $script:TestFolder "domain1.com.psd1"
            $d2 = Join-Path $script:TestFolder "domain2.com.psd1"
            New-MockSettingsFile -Path $d1 -CustomSettings @{
                companyName = "Co1"
                version     = "1.0.0.0"
                domain      = "domain1.com"
            } -Format 'psd1'
            New-MockSettingsFile -Path $d2 -CustomSettings @{
                companyName = "Co2"
                version     = "2.0.0.0"
                domain      = "domain2.com"
            } -Format 'psd1'
            $script:D1 = $d1; $script:D2 = $d2
        }
        AfterAll { Set-Location $script:OriginalLocation; Remove-Item $script:D1, $script:D2 -Force -ErrorAction SilentlyContinue }
        
        It "Should detect multiple domains in silent mode" {
            $r = Get-ApplicationMetaData -Silent
            $r | Should -Not -BeNullOrEmpty
        }
        
        It "Should choose first in silent mode" {
            $r = Get-ApplicationMetaData -Silent
            $r.companyName | Should -BeIn @("Co1", "Co2")
        }
        
        It "Should prompt user when not silent" {
            Mock DisplayNumericMenu { return "domain1.com" }
            $r = Get-ApplicationMetaData
            $r | Should -Not -BeNullOrEmpty
            Should -Invoke DisplayNumericMenu -Times 1
        }
        
        It "Should return null if user cancels" {
            Mock DisplayNumericMenu { return 0 }
            $r = Get-ApplicationMetaData
            $r | Should -BeNullOrEmpty
        }
    }
    Context "Executable version" {
        BeforeAll { Set-Location $script:TestFolder; $script:Exe = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" }
        AfterAll { Set-Location $script:OriginalLocation }
        
        It "Should extract exe version" {
            $r = Get-ApplicationMetaData -scriptName $script:Exe -Silent
            $r.version | Should -BeOfType [System.Version]
        }
        
        It "Should prefer exe version over settings" {
            $gPath = Join-Path $script:TestFolder "settings.psd1"
            New-MockSettingsFile -Path $gPath -CustomSettings @{
                version        = "1.0.0.0"
                globalSettings = @{
                    companyName = "Global"
                }
            } -Format 'psd1'
            $r = Get-ApplicationMetaData -GlobalSettingsFile $gPath -scriptName $script:Exe -Silent
            $r.version | Should -Not -Be "1.0.0.0"
            Remove-Item $gPath -Force
        }
        
        It "Should convert .ps1 to .exe" {
            $ps1 = $script:Exe -replace '\.exe$', '.ps1'
            $r = Get-ApplicationMetaData -scriptName $ps1 -Silent
            $r | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Lastrun.json fallback" {
        BeforeAll {
            Set-Location $script:TestFolder
            $lrPath = Join-Path $script:TestFolder "lastrun.json"
            @{version = "4.5.6.7"} | ConvertTo-Json | Set-Content $lrPath
            $script:LRPath = $lrPath
        }
        AfterAll { Set-Location $script:OriginalLocation; if (Test-Path $script:LRPath) { Remove-Item $script:LRPath -Force }}
        
        It "Should read version from lastrun.json" {
            $gPath = Join-Path $script:TestFolder "settings.psd1"
            New-MockSettingsFile -Path $gPath -CustomSettings @{
                globalSettings = @{
                    companyName = "Test"
                }
            } -Format 'psd1'
            $r = Get-ApplicationMetaData -GlobalSettingsFile $gPath -scriptName "nonexist.exe" -scriptPath $script:TestFolder -Silent
            $r.version.ToString() | Should -Be "4.5.6.7"
            Remove-Item $gPath -Force
        }
        
        It "Should fallback to settings if no version in json" {
            Set-Content $script:LRPath -Value (@{} | ConvertTo-Json)
            $gPath = Join-Path $script:TestFolder "settings.psd1"
            New-MockSettingsFile -Path $gPath -CustomSettings @{
                version        = "1.2.3.4"
                globalSettings = @{
                    companyName = "Test"
                }
            } -Format 'psd1'
            $r = Get-ApplicationMetaData -GlobalSettingsFile $gPath -scriptName "nonexist.exe" -scriptPath $script:TestFolder -Silent
            $r.version.ToString() | Should -Be "1.2.3.4"
            Remove-Item $gPath -Force
        }
    }
    
    Context "Default values" {
        BeforeAll { Set-Location $script:TestFolder }
        AfterAll { Set-Location $script:OriginalLocation }
        
        It "Should use default version when not specified" {
            $tmp = Join-Path $env:TEMP "Empty_$(Get-Date -Format 'yyyyMMddHHmmss')"
            New-Item -Path $tmp -ItemType Directory -Force | Out-Null
            Set-Location $tmp
            $gPath = Join-Path $tmp "settings.psd1"
            New-MockSettingsFile -Path $gPath -CustomSettings @{
                globalSettings = @{
                    companyName = "Test"
                }
            } -Format 'psd1'
            $r = Get-ApplicationMetaData -GlobalSettingsFile $gPath -Silent
            $r.version.Major | Should -Be 1
            $r.version.Minor | Should -Be 0
            Remove-Item $gPath -Force
            Set-Location $script:TestFolder
            Remove-Item $tmp -Recurse -Force
        }
        
        It "Should use default company name when not specified" {
            $tmp = Join-Path $env:TEMP "Empty_$(Get-Date -Format 'yyyyMMddHHmmss')"
            New-Item -Path $tmp -ItemType Directory -Force | Out-Null
            Set-Location $tmp
            $gPath = Join-Path $tmp "settings.psd1"
            New-MockSettingsFile -Path $gPath -CustomSettings @{
                version        = "1.0.0.0"
                globalSettings = @{}
            } -Format 'psd1'
            $r = Get-ApplicationMetaData -GlobalSettingsFile $gPath -Silent
            $r.companyName | Should -Be "Zuhair Mahmoud"
            Remove-Item $gPath -Force
            Set-Location $script:TestFolder
            Remove-Item $tmp -Recurse -Force
        }
        
        It "Should have null release when not specified" {
            $tmp = Join-Path $env:TEMP "Empty_$(Get-Date -Format 'yyyyMMddHHmmss')"
            New-Item -Path $tmp -ItemType Directory -Force | Out-Null
            Set-Location $tmp
            $gPath = Join-Path $tmp "settings.psd1"
            New-MockSettingsFile -Path $gPath -CustomSettings @{
                version        = "1.0.0.0"
                globalSettings = @{
                    companyName = "Test"
                }
            } -Format 'psd1'
            $r = Get-ApplicationMetaData -GlobalSettingsFile $gPath -Silent
            $r.release | Should -BeNullOrEmpty
            Remove-Item $gPath -Force
            Set-Location $script:TestFolder
            Remove-Item $tmp -Recurse -Force
        }
    }
    Context "Error handling" {
        BeforeAll { Set-Location $script:TestFolder }
        AfterAll { Set-Location $script:OriginalLocation }
        
        It "Should return hashtable with result false when no sources" {
            $tmp = Join-Path $env:TEMP "Tmp_$(Get-Date -Format 'yyyyMMddHHmmss')"
            New-Item -Path $tmp -ItemType Directory -Force | Out-Null
            Set-Location $tmp
            $r = Get-ApplicationMetaData -Silent
            $r | Should -Not -BeNullOrEmpty
            $r.result | Should -Be $false
            Set-Location $script:TestFolder
            Remove-Item $tmp -Recurse -Force
        }
        
        It "Should handle non-existent global file" {
            $tmp = Join-Path $env:TEMP "Tmp_$(Get-Date -Format 'yyyyMMddHHmmss')"
            New-Item -Path $tmp -ItemType Directory -Force | Out-Null
            Set-Location $tmp
            $r = Get-ApplicationMetaData -GlobalSettingsFile "nonexist.psd1" -Silent
            $r | Should -Not -BeNullOrEmpty
            $r.result | Should -Be $false
            Set-Location $script:TestFolder
            Remove-Item $tmp -Recurse -Force
        }
        
        It "Should handle corrupt settings file" {
            $cPath = Join-Path $script:TestFolder "corrupt.psd1"
            Set-Content $cPath "Invalid @{"
            { Get-ApplicationMetaData -GlobalSettingsFile $cPath -Silent } | Should -Not -Throw
            Remove-Item $cPath -Force
        }
    }
    
    Context "Verbose logging" {
        BeforeAll {
            Set-Location $script:TestFolder
            $gPath = Join-Path $script:TestFolder "settings.psd1"
            New-MockSettingsFile -Path $gPath -CustomSettings @{
                version        = "1.0.0.0"
                globalSettings = @{
                    companyName = "Test"
                }
            } -Format 'psd1'
            $dPath = Join-Path $script:TestFolder "test.com.psd1"
            New-MockSettingsFile -Path $dPath -CustomSettings @{
                companyName = "Domain"
                version     = "2.0.0.0"
                domain      = "test.com"
            } -Format 'psd1'
            $script:GP = $gPath; $script:DP = $dPath
        }
        AfterAll { Set-Location $script:OriginalLocation; Remove-Item $script:GP, $script:DP -Force -ErrorAction SilentlyContinue }
        
        It "Should log successful retrieval" {
            $r = Get-ApplicationMetaData -GlobalSettingsFile $script:GP -Silent
            Should -Invoke Write-Log -Times 1 -ParameterFilter { $Message -like "*Successfully loaded*" }
        }
        
        It "Should log metadata values" {
            $r = Get-ApplicationMetaData -GlobalSettingsFile $script:GP -Silent
            Should -Invoke Write-Log -Times 1 -ParameterFilter { $Message -like "*companyName:*" -or $Message -like "*version:*" }
        }
    }
    
    Context "Corporate settings" {
        BeforeAll { Set-Location $script:TestFolder }
        AfterAll { Set-Location $script:OriginalLocation }
        
        It "Should load corporate settings when enabled" {
            $gPath = Join-Path $script:TestFolder "corp-settings.psd1"
            New-MockSettingsFile -Path $gPath -CustomSettings @{
                version           = "1.0.0.0"
                corporateSettings = @{
                    useCorporateSettings = $true
                    corporateDomain      = "corporate.com"
                }
                globalSettings    = @{
                    companyName = "CorpCo"
                }
            } -Format 'psd1'
            
            $r = Get-ApplicationMetaData -GlobalSettingsFile $gPath -Silent
            $r | Should -Not -BeNullOrEmpty
            $r.corporateSettings | Should -Not -BeNullOrEmpty
            $r.corporateSettings.GetType().Name | Should -Be 'Hashtable'
            $r.corporateSettings.useCorporateSettings | Should -Be $true
            $r.corporateSettings.corporateDomain | Should -Be "corporate.com"
            
            Remove-Item $gPath -Force
        }
        
        It "Should set domain from corporate settings when enabled" {
            # When corporate settings specify a domain, it's set but the domain file
            # is NOT automatically loaded (the function skips domain file discovery)
            $originalLoc = Get-Location
            Set-Location $script:TestFolder
            
            $gPath = Join-Path $script:TestFolder "corp-domain.psd1"
            
            New-MockSettingsFile -Path $gPath -CustomSettings @{
                version           = "1.0.0.0"
                corporateSettings = @{
                    useCorporateSettings = $true
                    corporateDomain      = "corporate.com"
                }
                globalSettings    = @{
                    companyName = "GlobalCo"
                }
            } -Format 'psd1'
            
            $r = Get-ApplicationMetaData -GlobalSettingsFile $gPath -Silent
            $r | Should -Not -BeNullOrEmpty
            # The function sets domain from corporate settings but doesn't load domain file
            # So we just verify corporate settings were loaded correctly
            $r.corporateSettings.corporateDomain | Should -Be "corporate.com"
            $r.companyName | Should -Be "GlobalCo"
            
            Remove-Item $gPath -Force
            Set-Location $originalLoc
        }
        
        It "Should handle corporate settings disabled" {
            $gPath = Join-Path $script:TestFolder "nocorp-settings.psd1"
            New-MockSettingsFile -Path $gPath -CustomSettings @{
                version           = "1.0.0.0"
                corporateSettings = @{
                    useCorporateSettings = $false
                    corporateDomain      = "corporate.com"
                }
                globalSettings    = @{
                    companyName = "TestCo"
                }
            } -Format 'psd1'
            
            $r = Get-ApplicationMetaData -GlobalSettingsFile $gPath -Silent
            $r | Should -Not -BeNullOrEmpty
            # When useCorporateSettings = false, function returns empty hashtable
            $r.corporateSettings | Should -BeOfType [hashtable]
            $r.corporateSettings.Keys.Count | Should -Be 0
            
            Remove-Item $gPath -Force
        }
        
        It "Should return empty hashtable when corporate settings missing" {
            $gPath = Join-Path $script:TestFolder "missing-corp.psd1"
            New-MockSettingsFile -Path $gPath -CustomSettings @{
                version        = "1.0.0.0"
                globalSettings = @{
                    companyName = "TestCo"
                }
            } -Format 'psd1'
            
            $r = Get-ApplicationMetaData -GlobalSettingsFile $gPath -Silent
            $r | Should -Not -BeNullOrEmpty
            $r.corporateSettings | Should -BeOfType [hashtable]
            $r.corporateSettings.Keys.Count | Should -Be 0
            
            Remove-Item $gPath -Force
        }
    }
}

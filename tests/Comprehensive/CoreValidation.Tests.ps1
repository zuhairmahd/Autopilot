Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Core Validation - Comprehensive Authentication and Settings Tests" -Tags 'Comprehensive', 'Auth', 'Settings' {
    
    BeforeAll {
        # Get repository root
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
        
        # Initialize test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment
        
        # Load all functions
        $functionsPath = Join-Path $script:RepoRoot "functions"
        $functionFiles = Get-ChildItem -Path $functionsPath -Recurse -Filter *.ps1 -File
        
        Write-Verbose "Loading functions from $functionsPath..."
        foreach ($file in $functionFiles)
        {
            try
            {
                . $file.FullName
            }
            catch
            {
                Write-Warning "Failed to load $($file.Name): $_"
            }
        }
        
        # Setup global variables that functions may need
        $global:LogFile = Join-Path $script:TestContext.TestFolder "test.log"
        
        # Create test settings file (use PSD1 format, not JSON)
        $script:TestSettingsFile = Join-Path $script:TestContext.TestFolder "test-settings.psd1"
    }
    
    AfterAll {
        # Cleanup test environment
        if ($script:TestContext -and $script:TestContext.TestFolder)
        {
            Remove-Item -Path $script:TestContext.TestFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context "Array Storage Validation" {
        
        It "Should preserve single-item arrays in PSD1 roundtrip" {
            $testData = @{ singleItem = @('one'); multiItem = @('a', 'b') }
            $tempFile = Join-Path $script:TestContext.TestFolder "array-test.psd1"
            Export-PowerShellDataFile -InputObject $testData -Path $tempFile -Force | Out-Null
            $parsed = Import-PowerShellDataFile -Path $tempFile
            
            $parsed.singleItem -is [array] | Should -Be $true
            $parsed.singleItem.Count | Should -Be 1
        }
        
        It "Should preserve multi-item arrays in PSD1 roundtrip" {
            $testData = @{ multiItem = @('a', 'b', 'c') }
            $tempFile = Join-Path $script:TestContext.TestFolder "array-test2.psd1"
            Export-PowerShellDataFile -InputObject $testData -Path $tempFile -Force | Out-Null
            $parsed = Import-PowerShellDataFile -Path $tempFile
            
            $parsed.multiItem -is [array] | Should -Be $true
            $parsed.multiItem.Count | Should -Be 3
        }
    }
    
    Context "Core Function Availability" {
        
        It "Should have Write-Log function available" {
            Get-Command -Name Write-Log -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Test-AuthDefaults function available" {
            Get-Command -Name Test-AuthDefaults -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Update-Setting function available" {
            Get-Command -Name Update-Setting -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Auth Defaults Functionality" {
        
        BeforeEach {
            # Create fresh settings file for each test (PSD1 format)
            $initialSettings = @{ testData = "initial"; version = "1.0" }
            Export-PowerShellDataFile -InputObject $initialSettings -Path $script:TestSettingsFile -Force | Out-Null
        }
        
        It "Should create test settings file successfully" {
            Test-Path $script:TestSettingsFile | Should -Be $true
        }
        
        It "Should execute Test-AuthDefaults and create auth section" {
            $result = Test-AuthDefaults -SettingsFile $script:TestSettingsFile -Silent
            $result | Should -Be $true
            
            $content = Import-PowerShellDataFile -Path $script:TestSettingsFile
            $content.auth | Should -Not -BeNullOrEmpty -Because "Test-AuthDefaults should create auth section in settings file"
        }
        
        It "Should configure scope array in auth defaults" {
            Test-AuthDefaults -SettingsFile $script:TestSettingsFile -Silent | Out-Null
            
            $content = Import-PowerShellDataFile -Path $script:TestSettingsFile
            $content.auth.scope -is [array] | Should -Be $true -Because "Scope should be stored as array"
            $content.auth.scope.Count | Should -BeGreaterThan 0 -Because "Scope array should have at least one element"
        }
        
        It "Should set authType correctly to PublicAuthFlow" {
            Test-AuthDefaults -SettingsFile $script:TestSettingsFile -Silent | Out-Null
            
            $content = Import-PowerShellDataFile -Path $script:TestSettingsFile
            $content.auth.authType | Should -Be 'PublicAuthFlow' -Because "Default auth type should be PublicAuthFlow"
        }
    }
    
    Context "Auth Setting Updates" {
        
        BeforeEach {
            # Create and initialize settings file (PSD1 format)
            $initialSettings = @{ testData = "initial"; version = "1.0" }
            Export-PowerShellDataFile -InputObject $initialSettings -Path $script:TestSettingsFile -Force | Out-Null
            Test-AuthDefaults -SettingsFile $script:TestSettingsFile -Silent | Out-Null
        }
        
        It "Should execute Update-Setting for Auth settings" {
            $result = Update-Setting -SettingType "Auth" -SettingsFile $script:TestSettingsFile -SettingName "renewalLeadTime" -SettingValue 15
            $result | Should -Be $true -Because "Update-Setting should return true on successful update"
        }
        
        It "Should persist updated setting value correctly" {
            Update-Setting -SettingType "Auth" -SettingsFile $script:TestSettingsFile -SettingName "renewalLeadTime" -SettingValue 15 | Out-Null
            
            $content = Import-PowerShellDataFile -Path $script:TestSettingsFile
            $content.auth.renewalLeadTime | Should -Be 15 -Because "Updated value should be persisted to file"
        }
    }
    
    Context "Menu Integration Check" {
        
        It "Should have auth menu item in main.ps1" {
            $mainPath = Join-Path $script:RepoRoot "main.ps1"
            Test-Path $mainPath | Should -Be $true -Because "main.ps1 should exist in repository root"
            
            $mainContent = Get-Content -Path $mainPath -Raw
            $mainContent | Should -Match "Change authentication settings" -Because "Main menu should include auth settings option"
        }
        
        It "Should have auth editor integration in main.ps1" {
            $mainPath = Join-Path $script:RepoRoot "main.ps1"
            $mainContent = Get-Content -Path $mainPath -Raw
            $mainContent | Should -Match "Show-SettingsEditor.*Auth" -Because "Auth settings editor should be integrated in main.ps1"
        }
    }
    
    Context "Get-AuthDefaults Function" {
        
        It "Should have Get-AuthDefaults function available" {
            Get-Command -Name Get-AuthDefaults -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because "Get-AuthDefaults function should be loaded"
        }
        
        It "Should return data from Get-AuthDefaults" -Skip:(-not (Get-Command -Name Get-AuthDefaults -ErrorAction SilentlyContinue)) {
            $defaults = Get-AuthDefaults
            $defaults | Should -Not -BeNullOrEmpty -Because "Get-AuthDefaults should return default configuration"
        }
        
        It "Should return required keys (authType and scope)" -Skip:(-not (Get-Command -Name Get-AuthDefaults -ErrorAction SilentlyContinue)) {
            $defaults = Get-AuthDefaults
            $defaults.Contains('authType') | Should -Be $true -Because "Auth defaults should include authType"
            $defaults.Contains('scope') | Should -Be $true -Because "Auth defaults should include scope"
        }
        
        It "Should return scope as array" -Skip:(-not (Get-Command -Name Get-AuthDefaults -ErrorAction SilentlyContinue)) {
            $defaults = Get-AuthDefaults
            $defaults.scope -is [array] | Should -Be $true -Because "Scope should be an array"
        }
        
        It "Should have default authType value" -Skip:(-not (Get-Command -Name Get-AuthDefaults -ErrorAction SilentlyContinue)) {
            $defaults = Get-AuthDefaults
            $defaults.authType | Should -Not -BeNullOrEmpty -Because "Default authType should be set"
        }
    }
}

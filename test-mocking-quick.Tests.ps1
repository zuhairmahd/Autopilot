# Simple Pester test to verify mocking works correctly
Import-Module Pester -Force

Describe "Quick Test: Restore-ApplicationDefaults Mocking" -Tags 'QuickTest' {
    BeforeAll {
        # Import function and dependencies
        . "$PSScriptRoot/functions/setupFunctions/Restore-ApplicationDefaults.ps1"
        . "$PSScriptRoot/functions/utilityFunctions/Write-Log.ps1"
        
        # Set up global log file variable
        $global:logFile = Join-Path $env:TEMP "test-autopilot-quick.log"
        
        # Create test environment
        $script:TestFolder = Join-Path $env:TEMP "AutopilotQuickPesterTest"
        New-Item $script:TestFolder -ItemType Directory -Force | Out-Null
        
        $script:TestFiles = @(
            (Join-Path $script:TestFolder "settings.psd1"),
            (Join-Path $script:TestFolder "strings.psd1"),
            (Join-Path $script:TestFolder "menu.psd1")
        )
        
        $script:TestDomain = "test.local"
    }
    
    AfterAll {
        if (Test-Path $script:TestFolder) {
            Remove-Item $script:TestFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    It "Should work with proper Read-Host mocking (user confirms)" {
        # Create test files
        $script:TestFiles | ForEach-Object {
            New-Item $_ -ItemType File -Force | Out-Null
        }
        
        # Mock Read-Host with exact prompt match
        Mock Read-Host { return "Y" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
        
        $result = Restore-ApplicationDefaults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestFolder
        
        $result.Success | Should -Be $true
        $result.UserCancelled | Should -Be $false
        $result.RemovedFileCount | Should -BeGreaterThan 0
    }
    
    It "Should work with proper Read-Host mocking (user cancels)" {
        # Mock Read-Host to cancel
        Mock Read-Host { return "N" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
        
        $result = Restore-ApplicationDefaults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestFolder
        
        $result.Success | Should -Be $false
        $result.UserCancelled | Should -Be $true
        $result.Message | Should -Match "cancelled by user"
    }
    
    It "Should handle empty array parameter validation" {
        { Restore-ApplicationDefaults -FilesToDelete @() -Domain $script:TestDomain -ScriptPath $script:TestFolder } | Should -Throw "*empty array*"
    }
}
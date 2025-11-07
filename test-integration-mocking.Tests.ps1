# Quick test of the integration test mocking approach
Import-Module Pester -Force

Describe "Quick Integration Test Mocking" -Tags 'QuickTest' {
    BeforeAll {
        # Import function and dependencies
        . "$PSScriptRoot/functions/setupFunctions/Restore-ApplicationDefaults.ps1"
        . "$PSScriptRoot/functions/utilityFunctions/Write-Log.ps1"
        
        # Set up global log file variable
        $global:logFile = Join-Path $env:TEMP "test-integration-quick.log"
        
        # Create test environment
        $script:TestFolder = Join-Path $env:TEMP "AutopilotIntegrationQuickTest"
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
    
    It "Should handle complete failure scenario with mocked Remove-Item" {
        # Create test files
        $script:TestFiles | ForEach-Object {
            New-Item $_ -ItemType File -Force | Out-Null
        }
        
        # Mock user confirmation and Remove-Item failure
        Mock Read-Host { return "Y" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
        Mock Remove-Item { throw "Mocked deletion failure" }
        
        $result = Restore-ApplicationDefaults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestFolder
        
        $result.Success | Should -Be $false
        $result.RemovedFileCount | Should -Be 0
        $result.UndeletedFileCount | Should -BeGreaterThan 0
        $result.ErrorMessages.Count | Should -BeGreaterThan 0
        $result.ErrorMessages[0] | Should -Match "Mocked deletion failure"
    }
    
    It "Should handle partial success scenario with selective mocking" {
        # Create test files
        $script:TestFiles | ForEach-Object {
            New-Item $_ -ItemType File -Force | Out-Null
        }
        
        # Mock user confirmation
        Mock Read-Host { return "Y" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
        
        # Mock Remove-Item to fail for one specific file
        Mock Remove-Item {
            param($Path, $Force, $ErrorAction)
            if ($Path -eq $script:TestFiles[2]) {  # menu.psd1
                throw "Access denied"
            }
            # For other files, just return (simulate successful deletion)
        }
        
        # Mock Test-Path to simulate post-deletion state
        Mock Test-Path {
            param($Path)
            if ($Path -eq $script:TestFiles[2]) {
                return $true  # File still exists (deletion failed)
            }
            return $false  # Other files were "deleted"
        } -ParameterFilter { $Path -in $script:TestFiles }
        
        $result = Restore-ApplicationDefaults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestFolder
        
        $result.Success | Should -Be $false
        $result.RemovedFileCount | Should -Be 2  # 2 successful
        $result.UndeletedFileCount | Should -Be 1  # 1 failed
        $result.ErrorMessages.Count | Should -Be 1
    }
}
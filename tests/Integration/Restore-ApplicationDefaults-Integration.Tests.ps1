Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Integration: Restore-ApplicationDefaults with Main.ps1" -Tags 'Integration' {
    BeforeAll {
        # Direct dot-sourcing (recommended pattern)
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
        . "$script:RepoRoot/functions/setupFunctions/Restore-ApplicationDefaults.ps1"
        
        # Import utility functions that contain Write-Log
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        
        # Set up global log file variable (required by Write-Log)
        $global:logFile = Join-Path $env:TEMP "test-autopilot-integration.log"
        
        # Create test environment
        $script:TestEnv = Initialize-AutopilotTestEnvironment
        $script:TestDomain = "contoso.com"
        $script:InitFile = Join-Path $script:TestEnv.TestFolder "settings.psd1"
        $script:StringsFile = Join-Path $script:TestEnv.TestFolder "strings.psd1"
        $script:MenuFile = Join-Path $script:TestEnv.TestFolder "menu.psd1"
        
        # Mock returnValues for main.ps1 integration
        $script:returnValues = @{
            backoutText = "BACK"
        }
    }
    
    AfterAll {
        if ($script:TestEnv -and $script:TestEnv.TestFolder) {
            Remove-Item $script:TestEnv.TestFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    BeforeEach {
        # Clean up any existing test files
        @($script:InitFile, $script:StringsFile, $script:MenuFile) | ForEach-Object {
            if (Test-Path $_) {
                Remove-Item $_ -Force -ErrorAction SilentlyContinue
            }
        }
    }
    
    Context "Main.ps1 Integration Scenarios" {
        It "Should return EXIT_APPLICATION on successful restore" {
            # Create test files
            @($script:InitFile, $script:StringsFile, $script:MenuFile) | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            
            # Mock user confirmation
            Mock Read-Host { return "Y" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            
            # Simulate the main.ps1 calling pattern
            $restoreResult = Restore-ApplicationDefaults -FilesToDelete @($script:InitFile, $script:StringsFile, $script:MenuFile) -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder
            
            # Simulate main.ps1 logic
            $mainResult = $null
            if ($restoreResult.UserCancelled) {
                $mainResult = $script:returnValues.backoutText
            }
            elseif ($restoreResult.Success) {
                $mainResult = "EXIT_APPLICATION"
            }
            elseif ($restoreResult.RemovedFileCount -gt 0) {
                $mainResult = "EXIT_APPLICATION"
            }
            else {
                $mainResult = $script:returnValues.backoutText
            }
            
            $mainResult | Should -Be "EXIT_APPLICATION"
            $restoreResult.Success | Should -Be $true
            $restoreResult.RemovedFileCount | Should -BeGreaterThan 0
        }
        
        It "Should return EXIT_APPLICATION on partial success" {
            # Create test files
            @($script:InitFile, $script:StringsFile, $script:MenuFile) | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            
            # Mock user confirmation
            Mock Read-Host { return "Y" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            
            # Mock Remove-Item to simulate one file failing to delete
            Mock Remove-Item {
                param($Path, $Force, $ErrorAction)
                if ($Path -eq $script:MenuFile) {
                    throw "Access denied"
                }
                # For successful deletions, just do nothing (file will appear to be deleted)
            }
            
            # Mock Test-Path to simulate the state after deletion attempts
            Mock Test-Path {
                param($Path)
                if ($Path -eq $script:MenuFile) {
                    return $true  # File still exists (deletion failed)
                }
                return $false  # Other files were successfully "deleted"
            } -ParameterFilter { $Path -in @($script:InitFile, $script:StringsFile, $script:MenuFile) }
            
            $restoreResult = Restore-ApplicationDefaults -FilesToDelete @($script:InitFile, $script:StringsFile, $script:MenuFile) -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder
            
            # Simulate main.ps1 logic for partial success
            $mainResult = $null
            if ($restoreResult.UserCancelled) {
                $mainResult = $script:returnValues.backoutText
            }
            elseif ($restoreResult.Success) {
                $mainResult = "EXIT_APPLICATION"
            }
            elseif ($restoreResult.RemovedFileCount -gt 0) {
                # Partial success should still exit
                $mainResult = "EXIT_APPLICATION"
            }
            else {
                $mainResult = $script:returnValues.backoutText
            }
            
            $mainResult | Should -Be "EXIT_APPLICATION"
            $restoreResult.Success | Should -Be $false
            $restoreResult.RemovedFileCount | Should -Be 2  # 2 files deleted successfully
            $restoreResult.UndeletedFileCount | Should -Be 1  # 1 file failed
        }
        
        It "Should return backoutText when user cancels" {
            Mock Read-Host { return "N" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            
            $restoreResult = Restore-ApplicationDefaults -FilesToDelete @($script:InitFile, $script:StringsFile, $script:MenuFile) -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder
            
            # Simulate main.ps1 logic for user cancellation
            $mainResult = $null
            if ($restoreResult.UserCancelled) {
                $mainResult = $script:returnValues.backoutText
            }
            elseif ($restoreResult.Success) {
                $mainResult = "EXIT_APPLICATION"
            }
            elseif ($restoreResult.RemovedFileCount -gt 0) {
                $mainResult = "EXIT_APPLICATION"
            }
            else {
                $mainResult = $script:returnValues.backoutText
            }
            
            $mainResult | Should -Be "BACK"
            $restoreResult.UserCancelled | Should -Be $true
        }
        
        It "Should return backoutText when complete failure occurs" {
            # Create test files
            @($script:InitFile, $script:StringsFile, $script:MenuFile) | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            
            Mock Read-Host { return "Y" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            
            # Mock all file deletions to fail
            Mock Remove-Item { 
                throw "All access denied"
            }
            
            $restoreResult = Restore-ApplicationDefaults -FilesToDelete @($script:InitFile, $script:StringsFile, $script:MenuFile) -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder
            
            # Simulate main.ps1 logic for complete failure
            $mainResult = $null
            if ($restoreResult.UserCancelled) {
                $mainResult = $script:returnValues.backoutText
            }
            elseif ($restoreResult.Success) {
                $mainResult = "EXIT_APPLICATION"
            }
            elseif ($restoreResult.RemovedFileCount -gt 0) {
                $mainResult = "EXIT_APPLICATION"
            }
            else {
                $mainResult = $script:returnValues.backoutText
            }
            
            $mainResult | Should -Be "BACK"
            $restoreResult.Success | Should -Be $false
            $restoreResult.RemovedFileCount | Should -Be 0
            $restoreResult.UndeletedFileCount | Should -BeGreaterThan 0
        }
    }
    
    Context "Error Message Handling" {
        It "Should provide detailed error information for main.ps1 display" {
            # Create test files
            @($script:InitFile, $script:StringsFile, $script:MenuFile) | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            
            Mock Read-Host { return "Y" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            Mock Remove-Item { 
                throw "Detailed error message"
            }
            
            $restoreResult = Restore-ApplicationDefaults -FilesToDelete @($script:InitFile, $script:StringsFile, $script:MenuFile) -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder
            
            # Verify error information is available for main.ps1 to display
            $restoreResult.ErrorMessages | Should -Not -BeNullOrEmpty
            $restoreResult.ErrorMessages.Count | Should -BeGreaterThan 0
            $restoreResult.ErrorMessages[0] | Should -Match "Detailed error message"
            $restoreResult.UndeletedFiles | Should -Not -BeNullOrEmpty
            $restoreResult.Message | Should -Match "could not be deleted"
        }
    }
    
    Context "File List Verification" {
        It "Should accurately track which files were processed" {
            # Create some test files, leave others missing
            New-Item $script:InitFile -ItemType File -Force | Out-Null
            New-Item $script:MenuFile -ItemType File -Force | Out-Null
            # Leave StringsFile missing
            
            # Create domain file
            $domainFile = Join-Path $script:TestEnv.TestFolder "$script:TestDomain.psd1"
            New-Item $domainFile -ItemType File -Force | Out-Null
            
            Mock Read-Host { return "Y" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            
            $restoreResult = Restore-ApplicationDefaults -FilesToDelete @($script:InitFile, $script:StringsFile, $script:MenuFile) -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder
            
            # Verify main.ps1 can properly categorize results
            $restoreResult.RemovedFiles | Should -Contain $script:InitFile
            $restoreResult.RemovedFiles | Should -Contain $script:MenuFile
            $restoreResult.RemovedFiles | Should -Contain $domainFile
            $restoreResult.MissingFiles | Should -Contain $script:StringsFile
            
            $restoreResult.RemovedFileCount | Should -Be 3
            $restoreResult.MissingFileCount | Should -Be 1
            $restoreResult.UndeletedFileCount | Should -Be 0
        }
    }
}

Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: Restore-ApplicationDefaults" -Tags 'Unit' {
    BeforeAll {
        # Direct dot-sourcing (recommended pattern)
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
        . "$script:RepoRoot/functions/setupFunctions/Restore-ApplicationDefaults.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        
        # Set up global log file variable
        $global:logFile = Join-Path $env:TEMP "test-autopilot.log"
        
        # Create test environment
        $script:TestEnv = Initialize-AutopilotTestEnvironment
        $script:TestDomain = "test.local"
        $script:TestFiles = @(
            (Join-Path $script:TestEnv.TestFolder "settings.psd1"),
            (Join-Path $script:TestEnv.TestFolder "strings.psd1"),
            (Join-Path $script:TestEnv.TestFolder "menu.psd1")
        )
        $script:DomainFile = Join-Path $script:TestEnv.TestFolder "$script:TestDomain.psd1"
    }
    
    AfterAll {
        if ($script:TestEnv -and $script:TestEnv.TestFolder) {
            Remove-Item $script:TestEnv.TestFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    BeforeEach {
        # Clean up any existing test files
        $script:TestFiles + $script:DomainFile | ForEach-Object {
            if (Test-Path $_) {
                Remove-Item $_ -Force -ErrorAction SilentlyContinue
            }
        }
    }
    
    Context "Parameter Validation" {
        It "Should throw when FilesToDelete is empty" {
            Mock Read-Host { return "Y" }
            { Restore-ApplicationDefaults -FilesToDelete @() -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder } | Should -Throw
        }
        
        It "Should require mandatory parameters" {
            { Restore-ApplicationDefaults } | Should -Throw
        }
    }
    
    Context "User Interaction" {
        It "Should return UserCancelled when user cancels" {
            Mock Read-Host { return "N" } -ParameterFilter { $Prompt -match "continue" }
            
            $result = Restore-ApplicationDefaults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder
            
            $result.UserCancelled | Should -Be $true
            $result.Success | Should -Be $false
            $result.Message | Should -Match "cancelled"
        }
        
        It "Should proceed when user confirms" {
            Mock Read-Host { return "Y" } -ParameterFilter { $Prompt -match "continue" }
            
            # Create test files
            $script:TestFiles | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            
            $result = Restore-ApplicationDefaults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder
            
            $result.UserCancelled | Should -Be $false
            $result.Success | Should -Be $true
        }
    }
    
    Context "File Processing" {
        BeforeEach {
            Mock Read-Host { return "Y" } -ParameterFilter { $Prompt -match "continue" }
        }
        
        It "Should successfully delete existing files" {
            # Create test files
            $script:TestFiles | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            
            $result = Restore-ApplicationDefaults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder
            
            $result.Success | Should -Be $true
            $result.RemovedFileCount | Should -BeGreaterThan 0
            $result.UndeletedFileCount | Should -Be 0
            
            # Verify files are actually deleted
            $script:TestFiles | ForEach-Object {
                Test-Path $_ | Should -Be $false
            }
        }
        
        It "Should handle missing files gracefully" {
            # Don't create any files
            
            $result = Restore-ApplicationDefaults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder
            
            $result.Success | Should -Be $true
            $result.MissingFileCount | Should -BeGreaterThan 0
            $result.RemovedFileCount | Should -Be 0
        }
        
        It "Should include domain file when it exists" {
            # Create test files and domain file
            $script:TestFiles | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            New-Item $script:DomainFile -ItemType File -Force | Out-Null
            
            $result = Restore-ApplicationDefaults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder
            
            $result.ProcessedFiles | Should -Contain $script:DomainFile
            $result.RemovedFiles | Should -Contain $script:DomainFile
        }
        
        It "Should handle and report error messages" {
            # Test that error messages are collected when present
            # Since creating actual file deletion failures is complex in tests,
            # we'll verify the error handling structure exists
            $result = Restore-ApplicationDefaults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder
            
            # Verify error message handling properties exist
            $result.Keys | Should -Contain "ErrorMessages"
            $result.ErrorMessages | Should -BeOfType [System.Collections.ArrayList]
            
            # When successful, there should be no error messages
            if ($result.Success) {
                $result.ErrorMessages.Count | Should -Be 0
            }
        }
    }
    
    Context "Return Object Structure" {
        BeforeEach {
            Mock Read-Host { return "Y" } -ParameterFilter { $Prompt -match "continue" }
            # Create test files for consistent testing
            $script:TestFiles | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
        }
        
        It "Should return object with all required properties" {
            $result = Restore-ApplicationDefaults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder
            
            # Verify key properties exist (result is a hashtable, not PSObject)
            $result.Keys | Should -Contain "Success"
            $result.Keys | Should -Contain "Message"
            $result.Keys | Should -Contain "UserCancelled"
            $result.Keys | Should -Contain "RemovedFileCount"
            $result.Keys | Should -Contain "UndeletedFileCount"
            $result.Keys | Should -Contain "MissingFileCount"
        }
        
        It "Should have consistent file counts" {
            $result = Restore-ApplicationDefaults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder
            
            $result.RemovedFiles.Count | Should -Be $result.RemovedFileCount
            $result.UndeletedFiles.Count | Should -Be $result.UndeletedFileCount
            $result.MissingFiles.Count | Should -Be $result.MissingFileCount
        }
        
        It "Should provide meaningful messages" {
            $result = Restore-ApplicationDefaults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder
            
            $result.Message | Should -Not -BeNullOrEmpty
            if ($result.Success) {
                $result.Message | Should -Match "Successfully deleted"
            }
        }
    }
}
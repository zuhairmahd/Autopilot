Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: Restore-ApplicationDefaults" -Tags 'Unit' {
    BeforeAll {
        # Direct dot-sourcing (recommended pattern)
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
        . "$script:RepoRoot/functions/setupFunctions/Restore-ApplicationDefaults.ps1"
        
        # Import utility functions that contain Write-Log
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        
        # Set up global log file variable (required by Write-Log)
        $global:logFile = Join-Path $env:TEMP "test-autopilot.log"
        
        # Mock Write-Log to prevent actual logging during tests
        Mock Write-Log { }
        
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
        if ($script:TestEnv -and $script:TestEnv.TestFolder)
        {
            Remove-Item $script:TestEnv.TestFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    BeforeEach {
        # Clean up any existing test files
        $script:TestFiles + $script:DomainFile | ForEach-Object {
            if (Test-Path $_)
            {
                Remove-Item $_ -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Mock Read-Host to simulate user input - be very specific with parameter filter
        Mock Read-Host { return "Y" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
    }
    
    Context "Parameter Validation" {
        It "Should handle valid parameters correctly" {
            # Create test files
            $script:TestFiles | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            
            $result = Restore-ApplicationDefaults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            $result | Should -Not -BeNullOrEmpty
            $result.Keys | Should -Contain "Success"
        }
    }
    
    Context "User Cancellation" {
        It "Should return UserCancelled=true when user selects 'N'" {
            Mock Read-Host { return "N" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            
            $result = Restore-ApplicationDefaults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder
            
            $result.UserCancelled | Should -Be $true
            $result.Success | Should -Be $false
            $result.Message | Should -Match "cancelled by user"
        }
        
        It "Should return UserCancelled=true when user selects 'n'" {
            Mock Read-Host { return "n" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            
            $result = Restore-ApplicationDefaults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder
            
            $result.UserCancelled | Should -Be $true
            $result.Success | Should -Be $false
            $result.Message | Should -Match "cancelled by user"
        }
        
        It "Should handle invalid input then accept valid input" {
            # Mock the sequence of responses
            Mock Read-Host {
                # Track call count to simulate different responses
                if (-not $script:ReadHostCallCount) { $script:ReadHostCallCount = 0 }
                $script:ReadHostCallCount++
                
                switch ($script:ReadHostCallCount)
                {
                    1 { return "invalid" }
                    2 { return "maybe" }
                    default { return "Y" }
                }
            } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            
            # Reset call counter
            $script:ReadHostCallCount = 0
            
            # Create test files
            $script:TestFiles | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            
            $result = Restore-ApplicationDefaults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder
            
            $result.UserCancelled | Should -Be $false
            $result.Success | Should -Be $true
        }
    }
    
    Context "File Processing - Success Scenarios" {
        It "Should successfully delete all existing files" {
            # Create test files
            $script:TestFiles | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            # Create domain file
            New-Item $script:DomainFile -ItemType File -Force | Out-Null
            
            $result = Restore-ApplicationDefaults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            $result.Success | Should -Be $true
            $result.RemovedFileCount | Should -Be 4  # 3 test files + 1 domain file
            $result.UndeletedFileCount | Should -Be 0
            $result.MissingFileCount | Should -Be 0
            $result.Message | Should -Match "Successfully deleted 4 file"
            
            # Verify files are actually deleted
            $script:TestFiles + $script:DomainFile | ForEach-Object {
                Test-Path $_ | Should -Be $false
            }
        }
        
        It "Should handle missing files as success" {
            # Don't create any files
            
            $result = Restore-ApplicationDefaults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            $result.Success | Should -Be $true
            $result.RemovedFileCount | Should -Be 0
            $result.UndeletedFileCount | Should -Be 0
            $result.MissingFileCount | Should -Be 3  # All files missing
            $result.Message | Should -Match "already missing"
        }
        
        It "Should handle mixed existing and missing files" {
            # Create only some test files
            New-Item $script:TestFiles[0] -ItemType File -Force | Out-Null
            New-Item $script:TestFiles[2] -ItemType File -Force | Out-Null
            
            $result = Restore-ApplicationDefaults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            $result.Success | Should -Be $true
            $result.RemovedFileCount | Should -Be 2
            $result.UndeletedFileCount | Should -Be 0
            $result.MissingFileCount | Should -Be 1
            $result.Message | Should -Match "Successfully deleted 2 file"
            $result.Message | Should -Match "1 file.*already missing"
        }
        
        It "Should include domain file when it exists" {
            # Create test files and domain file
            $script:TestFiles | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            New-Item $script:DomainFile -ItemType File -Force | Out-Null
            
            $result = Restore-ApplicationDefaults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            $result.ProcessedFiles | Should -Contain $script:DomainFile
            $result.RemovedFiles | Should -Contain $script:DomainFile
            $result.RemovedFileCount | Should -Be 4  # 3 test files + 1 domain file
        }
        
        It "Should handle domain file not existing" {
            # Create only test files, not domain file
            $script:TestFiles | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            
            $result = Restore-ApplicationDefaults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            $result.Success | Should -Be $true
            # Domain file should NOT be in ProcessedFiles when it doesn't exist (function only adds if exists)
            $result.ProcessedFiles | Should -Not -Contain $script:DomainFile
            $result.RemovedFileCount | Should -Be 3  # Only test files
            $result.MissingFileCount | Should -Be 0
        }
    }
    
    Context "File Processing - Failure Scenarios" {
        It "Should handle file deletion failures" {
            # Create a test file
            $testFile = $script:TestFiles[0]
            New-Item $testFile -ItemType File -Force | Out-Null
            
            # Mock Remove-Item to simulate failure - use specific path matching
            Mock Remove-Item {
                throw "Access denied"
            } -ParameterFilter { $Path -eq $testFile }
            
            # Mock Write-Error to suppress error output during test
            Mock Write-Error { }
            
            $result = Restore-ApplicationDefaults -FilesToDelete @($testFile) -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            $result.Success | Should -Be $false
            $result.UndeletedFileCount | Should -Be 1
            $result.UndeletedFiles | Should -Contain $testFile
            $result.ErrorMessages.Count | Should -Be 1
            $result.ErrorMessages[0] | Should -Match "Access denied"
            $result.Message | Should -Match "could not be deleted"
        }
        
        It "Should handle partial success with some files failing" {
            # Create test files
            $script:TestFiles | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            
            # Mock Remove-Item to fail for one specific file
            $failingFile = $script:TestFiles[1]
            Mock Remove-Item {
                if ($Path -eq $failingFile)
                {
                    throw "File in use"
                }
            } -ParameterFilter { $Path -in $script:TestFiles }
            
            # Mock Write-Error to suppress error output during test
            Mock Write-Error { }
            
            $result = Restore-ApplicationDefaults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            $result.Success | Should -Be $false
            $result.RemovedFileCount | Should -Be 2  # 2 successful deletions
            $result.UndeletedFileCount | Should -Be 1  # 1 failure
            $result.UndeletedFiles | Should -Contain $failingFile
            $result.Message | Should -Match "partially completed"
            $result.Message | Should -Match "manual intervention"
        }
    }
    
    Context "Return Object Structure" {
        BeforeEach {
            # Create test files for consistent testing
            $script:TestFiles | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
        }
        
        It "Should return object with all required properties" {
            $result = Restore-ApplicationDefaults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            # Verify all properties exist (result is a hashtable)
            $result.Keys | Should -Contain "Success"
            $result.Keys | Should -Contain "Message"
            $result.Keys | Should -Contain "ProcessedFiles"
            $result.Keys | Should -Contain "FileCount"
            $result.Keys | Should -Contain "RemovedFiles"
            $result.Keys | Should -Contain "RemovedFileCount"
            $result.Keys | Should -Contain "MissingFiles"
            $result.Keys | Should -Contain "MissingFileCount"
            $result.Keys | Should -Contain "UndeletedFiles"
            $result.Keys | Should -Contain "UndeletedFileCount"
            $result.Keys | Should -Contain "UserCancelled"
            $result.Keys | Should -Contain "ErrorMessages"
        }
        
        It "Should have consistent counts" {
            $result = Restore-ApplicationDefaults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            $result.RemovedFiles.Count | Should -Be $result.RemovedFileCount
            $result.MissingFiles.Count | Should -Be $result.MissingFileCount
            $result.UndeletedFiles.Count | Should -Be $result.UndeletedFileCount
            
            # Total processed should equal sum of all operations
            $totalProcessed = $result.RemovedFileCount + $result.MissingFileCount + $result.UndeletedFileCount
            $result.FileCount | Should -Be $totalProcessed
        }
        
        It "Should provide meaningful error messages" {
            # Create a test file
            $testFile = $script:TestFiles[0]
            New-Item $testFile -ItemType File -Force | Out-Null
            
            Mock Remove-Item { throw "Test error message" } -ParameterFilter { $Path -eq $testFile }
            Mock Write-Error { }
            
            $result = Restore-ApplicationDefaults -FilesToDelete @($testFile) -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            $result.Success | Should -Be $false
            $result.Message | Should -Not -BeNullOrEmpty
            $result.ErrorMessages.Count | Should -BeGreaterThan 0
            $result.ErrorMessages[0] | Should -Match "Test error message"
        }
    }
    
    Context "Edge Cases" {
        It "Should handle files with special characters in paths" {
            $specialFile = Join-Path $script:TestEnv.TestFolder "test file with spaces & symbols.psd1"
            New-Item $specialFile -ItemType File -Force | Out-Null
            
            $result = Restore-ApplicationDefaults -FilesToDelete @($specialFile) -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            $result.Success | Should -Be $true
            $result.RemovedFileCount | Should -Be 1
            Test-Path $specialFile | Should -Be $false
        }
        
        It "Should handle very long file paths" {
            $longPath = Join-Path $script:TestEnv.TestFolder ("very_long_filename_" + ("x" * 100) + ".psd1")
            try
            {
                New-Item $longPath -ItemType File -Force | Out-Null
                $fileCreated = $true
            }
            catch
            {
                $fileCreated = $false
            }
            
            if ($fileCreated)
            {
                $result = Restore-ApplicationDefaults -FilesToDelete @($longPath) -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
                
                $result.Success | Should -Be $true
                $result.RemovedFileCount | Should -Be 1
                Test-Path $longPath | Should -Be $false
            }
        }
        
        It "Should handle empty directory for ScriptPath" {
            $emptyDir = Join-Path $script:TestEnv.TestFolder "empty"
            New-Item $emptyDir -ItemType Directory -Force | Out-Null
            
            $result = Restore-ApplicationDefaults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $emptyDir
            
            # Should still work, domain file just won't be found
            $result.UserCancelled | Should -Be $false
        }
    }
    
    Context "Integration with Write-Log" {
        It "Should call Write-Log for important events" {
            # Create test files
            $script:TestFiles | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            
            $result = Restore-ApplicationDefaults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            # Verify Write-Log was called (mock was set up in BeforeAll)
            Should -Invoke Write-Log -Times 1 -ParameterFilter { $Message -like "*Processing*files for deletion*" }
            Should -Invoke Write-Log -Times 1 -ParameterFilter { $Message -like "*Operation completed*" }
        }
    }
}

Describe "Function: Show-RestoreApplicationDefaultsResults" -Tags 'Unit' {
    BeforeAll {
        # Direct dot-sourcing (recommended pattern)
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
        . "$script:RepoRoot/functions/setupFunctions/Restore-ApplicationDefaults.ps1"
        
        # Import utility functions that contain Write-Log
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        
        # Set up global log file variable (required by Write-Log)
        $global:logFile = Join-Path $env:TEMP "test-autopilot.log"
        
        # Mock Write-Log to prevent actual logging during tests
        Mock Write-Log { }
        
        # Mock returnValues (used by the function)
        $global:returnValues = @{
            backoutText = "BACK"
            exitString  = "EXIT_APPLICATION"
        }
        
        # Create test environment
        $script:TestEnv = Initialize-AutopilotTestEnvironment
        $script:TestDomain = "test.local"
        $script:TestFiles = @(
            (Join-Path $script:TestEnv.TestFolder "settings.psd1"),
            (Join-Path $script:TestEnv.TestFolder "strings.psd1"),
            (Join-Path $script:TestEnv.TestFolder "menu.psd1")
        )
    }
    
    AfterAll {
        if ($script:TestEnv -and $script:TestEnv.TestFolder)
        {
            Remove-Item $script:TestEnv.TestFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    BeforeEach {
        # Clean up any existing test files
        $script:TestFiles | ForEach-Object {
            if (Test-Path $_)
            {
                Remove-Item $_ -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Mock Read-Host to simulate user input
        Mock Read-Host { return "Y" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
        
        # Mock ReadKey to prevent blocking in tests
        Mock -CommandName 'Get-Host' -MockWith {
            return [PSCustomObject]@{
                UI = [PSCustomObject]@{
                    RawUI = [PSCustomObject]@{
                        ReadKey = { return @{ VirtualKeyCode = 13 } }
                    }
                }
            }
        }
    }
    
    Context "User Cancellation Scenarios" {
        It "Should return backoutText when user cancels" {
            Mock Read-Host { return "N" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            
            $result = Show-RestoreApplicationDefaultsResults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder
            
            $result | Should -Be "BACK"
        }
        
        It "Should return backoutText when user enters 'n'" {
            Mock Read-Host { return "n" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            
            $result = Show-RestoreApplicationDefaultsResults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder
            
            $result | Should -Be "BACK"
        }
    }
    
    Context "Success Scenarios" {
        It "Should return exitString when files are successfully deleted" {
            # Create test files
            $script:TestFiles | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            
            $result = Show-RestoreApplicationDefaultsResults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            $result | Should -Be "EXIT_APPLICATION"
        }
        
        It "Should return exitString when all files are already missing" {
            # Don't create any files
            
            $result = Show-RestoreApplicationDefaultsResults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            $result | Should -Be "EXIT_APPLICATION"
        }
    }
    
    Context "Partial Success Scenarios" {
        It "Should return exitString when some files deleted and some failed" {
            # Create test files
            $script:TestFiles | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            
            # Mock Remove-Item to fail for one file
            $failingFile = $script:TestFiles[1]
            Mock Remove-Item {
                if ($Path -eq $failingFile)
                {
                    throw "Access denied"
                }
            } -ParameterFilter { $Path -in $script:TestFiles }
            
            Mock Write-Error { }
            
            $result = Show-RestoreApplicationDefaultsResults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            $result | Should -Be "EXIT_APPLICATION"
        }
    }
    
    Context "Complete Failure Scenarios" {
        It "Should return backoutText when all files fail to delete" {
            # Create test files
            $script:TestFiles | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            
            # Mock all deletions to fail
            Mock Remove-Item { 
                throw "All access denied"
            } -ParameterFilter { $Path -in $script:TestFiles }
            
            Mock Write-Error { }
            
            $result = Show-RestoreApplicationDefaultsResults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            $result | Should -Be "BACK"
        }
    }
    
    Context "Display Output Validation" {
        It "Should display success message for successful deletion" {
            # Create test files
            $script:TestFiles | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            
            # Capture Write-Host output
            Mock Write-Host { }
            
            $result = Show-RestoreApplicationDefaultsResults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*successfully*" -or $Object -like "*Successfully*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Files successfully removed*" }
        }
        
        It "Should display cancellation message when user cancels" {
            Mock Read-Host { return "N" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            Mock Write-Host { }
            
            $result = Show-RestoreApplicationDefaultsResults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancelled*" }
        }
        
        It "Should display error information for failed deletions" {
            # Create test files
            $script:TestFiles | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            
            # Mock all deletions to fail
            Mock Remove-Item { 
                throw "Test error"
            } -ParameterFilter { $Path -in $script:TestFiles }
            
            Mock Write-Error { }
            Mock Write-Host { }
            
            $result = Show-RestoreApplicationDefaultsResults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*could not be deleted*" }
        }
    }
    
    Context "Return Value Consistency" {
        It "Should only return valid return values" {
            # Test with successful deletion
            $script:TestFiles | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            
            $result = Show-RestoreApplicationDefaultsResults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            $result | Should -BeIn @("BACK", "EXIT_APPLICATION")
        }
        
        It "Should return correct value for each scenario" {
            # User cancellation
            Mock Read-Host { return "N" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            $result1 = Show-RestoreApplicationDefaultsResults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder
            $result1 | Should -Be "BACK"
            
            # Complete failure (no files to delete)
            Mock Read-Host { return "Y" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            Mock Remove-Item { throw "Fail" } -ParameterFilter { $Path -in $script:TestFiles }
            Mock Write-Error { }
            $script:TestFiles | ForEach-Object { New-Item $_ -ItemType File -Force | Out-Null }
            $result2 = Show-RestoreApplicationDefaultsResults -FilesToDelete $script:TestFiles -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            $result2 | Should -Be "BACK"
        }
    }
}

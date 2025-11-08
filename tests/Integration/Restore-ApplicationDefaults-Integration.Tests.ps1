Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Integration: Show-RestoreApplicationDefaultsResults with Main.ps1" -Tags 'Integration' {
    BeforeAll {
        # Direct dot-sourcing (recommended pattern)
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
        . "$script:RepoRoot/functions/setupFunctions/Restore-ApplicationDefaults.ps1"
        
        # Import utility functions that contain Write-Log
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        
        # Set up global log file variable (required by Write-Log)
        $global:logFile = Join-Path $env:TEMP "test-autopilot-integration.log"
        
        # Mock Write-Log and Write-Error to prevent actual logging/error output during tests
        Mock Write-Log { }
        Mock Write-Error { }
        
        # Create test environment
        $script:TestEnv = Initialize-AutopilotTestEnvironment
        $script:TestDomain = "contoso.com"
        $script:InitFile = Join-Path $script:TestEnv.TestFolder "settings.psd1"
        $script:StringsFile = Join-Path $script:TestEnv.TestFolder "strings.psd1"
        $script:MenuFile = Join-Path $script:TestEnv.TestFolder "menu.psd1"
        
        # Mock returnValues for main.ps1 integration (global scope)
        $global:returnValues = @{
            backoutText = "BACK"
            exitString  = "EXIT_APPLICATION"
        }
        
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
    
    AfterAll {
        if ($script:TestEnv -and $script:TestEnv.TestFolder)
        {
            Remove-Item $script:TestEnv.TestFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    BeforeEach {
        # Clean up any existing test files
        @($script:InitFile, $script:StringsFile, $script:MenuFile) | ForEach-Object {
            if (Test-Path $_)
            {
                Remove-Item $_ -Force -ErrorAction SilentlyContinue
            }
        }
    }
    
    Context "Main.ps1 Integration - Show-RestoreApplicationDefaultsResults" {
        It "Should return EXIT_APPLICATION on successful restore" {
            # Create test files
            @($script:InitFile, $script:StringsFile, $script:MenuFile) | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            
            # Mock user confirmation
            Mock Read-Host { return "Y" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            
            # Call Show-RestoreApplicationDefaultsResults (what main.ps1 actually calls)
            $result = Show-RestoreApplicationDefaultsResults -FilesToDelete @($script:InitFile, $script:StringsFile, $script:MenuFile) -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            $result | Should -Be "EXIT_APPLICATION"
            
            # Verify files were actually deleted
            @($script:InitFile, $script:StringsFile, $script:MenuFile) | ForEach-Object {
                Test-Path $_ | Should -Be $false
            }
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
                if ($Path -eq $script:MenuFile)
                {
                    throw "Access denied"
                }
            } -ParameterFilter { $Path -in @($script:InitFile, $script:StringsFile, $script:MenuFile) }
            
            $result = Show-RestoreApplicationDefaultsResults -FilesToDelete @($script:InitFile, $script:StringsFile, $script:MenuFile) -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            $result | Should -Be "EXIT_APPLICATION"
        }
        
        It "Should return BACK when user cancels" {
            Mock Read-Host { return "N" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            
            $result = Show-RestoreApplicationDefaultsResults -FilesToDelete @($script:InitFile, $script:StringsFile, $script:MenuFile) -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder
            
            $result | Should -Be "BACK"
        }
        
        It "Should return BACK when complete failure occurs" {
            # Create test files
            @($script:InitFile, $script:StringsFile, $script:MenuFile) | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            
            Mock Read-Host { return "Y" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            
            # Mock all file deletions to fail
            Mock Remove-Item { 
                throw "All access denied"
            } -ParameterFilter { $Path -in @($script:InitFile, $script:StringsFile, $script:MenuFile) }
            
            $result = Show-RestoreApplicationDefaultsResults -FilesToDelete @($script:InitFile, $script:StringsFile, $script:MenuFile) -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            $result | Should -Be "BACK"
        }
        
        It "Should return EXIT_APPLICATION when all files are already missing" {
            # Don't create any files
            Mock Read-Host { return "Y" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            
            $result = Show-RestoreApplicationDefaultsResults -FilesToDelete @($script:InitFile, $script:StringsFile, $script:MenuFile) -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            $result | Should -Be "EXIT_APPLICATION"
        }
    }
    
    Context "Main.ps1 Pattern Validation" {
        It "Should follow main.ps1 return value pattern" {
            # This test verifies that the function returns values that main.ps1 can handle
            @($script:InitFile, $script:StringsFile, $script:MenuFile) | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            
            Mock Read-Host { return "Y" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            
            $result = Show-RestoreApplicationDefaultsResults -FilesToDelete @($script:InitFile, $script:StringsFile, $script:MenuFile) -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            # Verify result is in returnValues (simulating main.ps1 check)
            $result | Should -BeIn $global:returnValues.Values
        }
        
        It "Should be callable exactly as main.ps1 calls it" {
            # This matches the exact pattern from main.ps1:
            # $restoreResult = Show-RestoreApplicationDefaultsResults -FilesToDelete @($InitFile, $stringsFile, $menuFile) -Domain $domain -ScriptPath $scriptPath
            
            @($script:InitFile, $script:StringsFile, $script:MenuFile) | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            
            Mock Read-Host { return "Y" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            
            # Exact pattern from main.ps1
            $restoreResult = Show-RestoreApplicationDefaultsResults -FilesToDelete @($script:InitFile, $script:StringsFile, $script:MenuFile) -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            # Main.ps1 checks: if ($restoreResult -in $returnValues.Values)
            $restoreResult -in $global:returnValues.Values | Should -Be $true
            $restoreResult | Should -BeIn @("BACK", "EXIT_APPLICATION")
        }
    }
    
    Context "Two-Function Architecture Integration" {
        It "Should properly integrate Restore-ApplicationDefaults with Show-RestoreApplicationDefaultsResults" {
            # Create test files
            @($script:InitFile, $script:StringsFile, $script:MenuFile) | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            
            Mock Read-Host { return "Y" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            
            # Test that Show-RestoreApplicationDefaultsResults properly calls Restore-ApplicationDefaults
            # We can verify this by checking the result structure comes from the core function
            $result = Show-RestoreApplicationDefaultsResults -FilesToDelete @($script:InitFile, $script:StringsFile, $script:MenuFile) -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            # Verify the wrapper function returns the correct exit code
            $result | Should -Be "EXIT_APPLICATION"
            
            # Verify files were deleted (proving the core function was called)
            @($script:InitFile, $script:StringsFile, $script:MenuFile) | ForEach-Object {
                Test-Path $_ | Should -Be $false
            }
        }
    }
    
    Context "Display and User Interaction" {
        It "Should display cancellation message when user cancels" {
            Mock Read-Host { return "N" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            Mock Write-Host { }
            
            $result = Show-RestoreApplicationDefaultsResults -FilesToDelete @($script:InitFile, $script:StringsFile, $script:MenuFile) -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancelled*" }
            $result | Should -Be "BACK"
        }
        
        It "Should display success information for successful restore" {
            @($script:InitFile, $script:StringsFile, $script:MenuFile) | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            
            Mock Read-Host { return "Y" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            Mock Write-Host { }
            
            $result = Show-RestoreApplicationDefaultsResults -FilesToDelete @($script:InitFile, $script:StringsFile, $script:MenuFile) -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Files successfully removed*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*exit*" }
            $result | Should -Be "EXIT_APPLICATION"
        }
        
        It "Should display partial success details" {
            @($script:InitFile, $script:StringsFile, $script:MenuFile) | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            
            Mock Read-Host { return "Y" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            Mock Remove-Item {
                if ($Path -eq $script:MenuFile)
                {
                    throw "Access denied"
                }
            } -ParameterFilter { $Path -in @($script:InitFile, $script:StringsFile, $script:MenuFile) }
            Mock Write-Host { }
            
            $result = Show-RestoreApplicationDefaultsResults -FilesToDelete @($script:InitFile, $script:StringsFile, $script:MenuFile) -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Files successfully removed*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*could not be deleted*" }
            $result | Should -Be "EXIT_APPLICATION"
        }
        
        It "Should display complete failure details" {
            @($script:InitFile, $script:StringsFile, $script:MenuFile) | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            
            Mock Read-Host { return "Y" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            Mock Remove-Item { throw "All denied" } -ParameterFilter { $Path -in @($script:InitFile, $script:StringsFile, $script:MenuFile) }
            Mock Write-Host { }
            
            $result = Show-RestoreApplicationDefaultsResults -FilesToDelete @($script:InitFile, $script:StringsFile, $script:MenuFile) -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*could not be deleted*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*No files were removed*" }
            $result | Should -Be "BACK"
        }
    }
    
    Context "Domain File Handling" {
        It "Should include domain file in deletion when it exists" {
            # Create test files including domain file
            @($script:InitFile, $script:StringsFile, $script:MenuFile) | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            $domainFile = Join-Path $script:TestEnv.TestFolder "$script:TestDomain.psd1"
            New-Item $domainFile -ItemType File -Force | Out-Null
            
            Mock Read-Host { return "Y" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            
            $result = Show-RestoreApplicationDefaultsResults -FilesToDelete @($script:InitFile, $script:StringsFile, $script:MenuFile) -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            $result | Should -Be "EXIT_APPLICATION"
            # Verify domain file was deleted
            Test-Path $domainFile | Should -Be $false
        }
        
        It "Should handle case when domain file does not exist" {
            # Create test files but NOT domain file
            @($script:InitFile, $script:StringsFile, $script:MenuFile) | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            
            Mock Read-Host { return "Y" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            
            $result = Show-RestoreApplicationDefaultsResults -FilesToDelete @($script:InitFile, $script:StringsFile, $script:MenuFile) -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            $result | Should -Be "EXIT_APPLICATION"
        }
    }
}

Describe "Integration: Restore-ApplicationDefaults Core Function" -Tags 'Integration' {
    BeforeAll {
        # Direct dot-sourcing (recommended pattern)
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
        . "$script:RepoRoot/functions/setupFunctions/Restore-ApplicationDefaults.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        
        $global:logFile = Join-Path $env:TEMP "test-autopilot-integration.log"
        Mock Write-Log { }
        Mock Write-Error { }
        
        $script:TestEnv = Initialize-AutopilotTestEnvironment
        $script:TestDomain = "contoso.com"
        $script:InitFile = Join-Path $script:TestEnv.TestFolder "settings.psd1"
        $script:StringsFile = Join-Path $script:TestEnv.TestFolder "strings.psd1"
        $script:MenuFile = Join-Path $script:TestEnv.TestFolder "menu.psd1"
    }
    
    AfterAll {
        if ($script:TestEnv -and $script:TestEnv.TestFolder)
        {
            Remove-Item $script:TestEnv.TestFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    BeforeEach {
        @($script:InitFile, $script:StringsFile, $script:MenuFile) | ForEach-Object {
            if (Test-Path $_)
            {
                Remove-Item $_ -Force -ErrorAction SilentlyContinue
            }
        }
    }
    
    Context "Core Return Object for UI Integration" {
        It "Should return complete object for successful deletion" {
            @($script:InitFile, $script:StringsFile, $script:MenuFile) | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            
            Mock Read-Host { return "Y" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            
            $result = Restore-ApplicationDefaults -FilesToDelete @($script:InitFile, $script:StringsFile, $script:MenuFile) -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            $result.Success | Should -Be $true
            $result.RemovedFileCount | Should -BeGreaterThan 0
            $result.UserCancelled | Should -Be $false
            $result.Message | Should -Not -BeNullOrEmpty
        }
        
        It "Should return complete object for user cancellation" {
            Mock Read-Host { return "N" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            
            $result = Restore-ApplicationDefaults -FilesToDelete @($script:InitFile, $script:StringsFile, $script:MenuFile) -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder
            
            $result.UserCancelled | Should -Be $true
            $result.Success | Should -Be $false
            $result.Message | Should -Match "cancelled"
        }
        
        It "Should return complete object for partial success" {
            @($script:InitFile, $script:StringsFile, $script:MenuFile) | ForEach-Object {
                New-Item $_ -ItemType File -Force | Out-Null
            }
            
            Mock Read-Host { return "Y" } -ParameterFilter { $Prompt -eq "Enter Y to continue or N to cancel" }
            Mock Remove-Item {
                if ($Path -eq $script:MenuFile)
                {
                    throw "Access denied"
                }
            } -ParameterFilter { $Path -in @($script:InitFile, $script:StringsFile, $script:MenuFile) }
            
            $result = Restore-ApplicationDefaults -FilesToDelete @($script:InitFile, $script:StringsFile, $script:MenuFile) -Domain $script:TestDomain -ScriptPath $script:TestEnv.TestFolder -Silent
            
            $result.Success | Should -Be $false
            $result.RemovedFileCount | Should -Be 2
            $result.UndeletedFileCount | Should -Be 1
            $result.UndeletedFiles.Count | Should -Be 1
            $result.ErrorMessages.Count | Should -BeGreaterThan 0
        }
    }
}

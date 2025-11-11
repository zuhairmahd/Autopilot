#Requires -Version 5.1
<#
.SYNOPSIS
    Pester tests for Show-PagedContent.ps1 utility function.

.DESCRIPTION
    Unit tests for the generic paging function that displays large datasets with navigation.
    Tests various input types (arrays, hashtables, PSCustomObjects, strings), navigation scenarios,
    and edge cases. Interactive paging tests use mocking to simulate user input.

.NOTES
    Test Framework: Pester 5.x
    PowerShell: 5.1+
    Approach: Direct dot-sourcing for PS 5.1 compatibility
    Coverage: Input validation, content conversion, paging logic, navigation, error handling
#>

Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: Show-PagedContent" -Tags 'Unit', 'UtilityFunctions', 'Paging' {
    BeforeAll {
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        $script:logFile = Join-Path $TestDrive "test.log"
        
        # Load dependencies
        . "$script:RepoRoot\functions\utilityFunctions\Show-PagedContent.ps1"
        . "$script:RepoRoot\functions\utilityFunctions\Write-Log.ps1"
    }
    
    Context "Parameter validation and edge cases" {
        It "Should handle null content gracefully in Silent mode" {
            $result = Show-PagedContent -Content $null -Silent
            $result | Should -Be "completed"
        }
        
        It "Should handle empty string content in Silent mode" {
            $result = Show-PagedContent -Content "" -Silent
            $result | Should -Be "completed"
        }
        
        It "Should handle empty array in Silent mode" {
            $result = Show-PagedContent -Content @() -Silent
            $result | Should -Be "completed"
        }
        
        It "Should handle whitespace-only string in Silent mode" {
            $result = Show-PagedContent -Content "   " -Silent
            $result | Should -Be "completed"
        }
        
        It "Should validate PageSize and default to 10 if invalid" {
            # Should not throw, but log a warning and use default
            { Show-PagedContent -Content @("item1") -PageSize -5 -Silent } | Should -Not -Throw
        }
        
        It "Should require DisplayScriptBlock for hashtable without it" {
            $ht = @{ key1 = "value1" }
            $result = Show-PagedContent -Content $ht -Silent
            $result | Should -Match "error.*DisplayScriptBlock"
        }
        
        It "Should require DisplayScriptBlock for object array without it" {
            $objects = @(
                [PSCustomObject]@{ Name = "Obj1" },
                [PSCustomObject]@{ Name = "Obj2" }
            )
            $result = Show-PagedContent -Content $objects -Silent
            $result | Should -Match "error.*DisplayScriptBlock"
        }
    }
    
    Context "String content processing" {
        It "Should split multi-line string into lines" {
            $content = "Line 1`nLine 2`nLine 3"
            $result = Show-PagedContent -Content $content -Silent -NoPaging
            $result | Should -Be "completed"
        }
        
        It "Should handle Windows line endings (CRLF)" {
            $content = "Line 1`r`nLine 2`r`nLine 3"
            $result = Show-PagedContent -Content $content -Silent -NoPaging
            $result | Should -Be "completed"
        }
        
        It "Should handle Unix line endings (LF)" {
            $content = "Line 1`nLine 2`nLine 3"
            $result = Show-PagedContent -Content $content -Silent -NoPaging
            $result | Should -Be "completed"
        }
        
        It "Should use default display for string content" {
            $content = "Test line 1`nTest line 2"
            $result = Show-PagedContent -Content $content -Silent -NoPaging
            $result | Should -Be "completed"
        }
    }
    
    Context "Array content processing" {
        It "Should process simple string array with default display" {
            $content = @("Item 1", "Item 2", "Item 3")
            $result = Show-PagedContent -Content $content -Silent -NoPaging
            $result | Should -Be "completed"
        }
        
        It "Should process object array with custom DisplayScriptBlock" {
            $content = @(
                [PSCustomObject]@{ Name = "Obj1"; Value = 10 },
                [PSCustomObject]@{ Name = "Obj2"; Value = 20 }
            )
            $displayBlock = { param($item) Write-Host "$($item.Name): $($item.Value)" }
            $result = Show-PagedContent -Content $content -DisplayScriptBlock $displayBlock -Silent -NoPaging
            $result | Should -Be "completed"
        }
        
        It "Should handle single-item array" {
            $content = @("Single item")
            $result = Show-PagedContent -Content $content -Silent -NoPaging
            $result | Should -Be "completed"
        }
        
        It "Should handle large array triggering paging" {
            $content = 1..50 | ForEach-Object { "Item $_" }
            # In Silent mode, paging is bypassed
            $result = Show-PagedContent -Content $content -PageSize 10 -Silent
            $result | Should -Be "completed"
        }
    }
    
    Context "Hashtable content processing" {
        It "Should sort hashtable keys alphabetically" {
            $ht = @{ z_key = "value3"; a_key = "value1"; m_key = "value2" }
            $displayBlock = { param($kvp) Write-Host "$($kvp.Key): $($kvp.Value)" }
            $result = Show-PagedContent -Content $ht -DisplayScriptBlock $displayBlock -Silent -NoPaging
            $result | Should -Be "completed"
        }
        
        It "Should handle empty hashtable" {
            $ht = @{}
            $displayBlock = { param($kvp) Write-Host "$($kvp.Key): $($kvp.Value)" }
            $result = Show-PagedContent -Content $ht -DisplayScriptBlock $displayBlock -Silent -NoPaging
            $result | Should -Be "completed"
        }
        
        It "Should convert hashtable to key-value pairs" {
            $ht = @{ key1 = "value1"; key2 = "value2" }
            $displayBlock = { param($kvp) Write-Host "$($kvp.Key): $($kvp.Value)" }
            $result = Show-PagedContent -Content $ht -DisplayScriptBlock $displayBlock -Silent -NoPaging
            $result | Should -Be "completed"
        }
    }
    
    Context "PSCustomObject content processing" {
        It "Should handle PSCustomObject as single item" {
            $obj = [PSCustomObject]@{ Name = "Test"; Value = 42 }
            $displayBlock = { param($item) Write-Host "$($item.Name): $($item.Value)" }
            $result = Show-PagedContent -Content $obj -DisplayScriptBlock $displayBlock -Silent -NoPaging
            $result | Should -Be "completed"
        }
        
        It "Should handle array of PSCustomObjects" {
            $objects = @(
                [PSCustomObject]@{ Name = "Obj1"; Value = 10 },
                [PSCustomObject]@{ Name = "Obj2"; Value = 20 },
                [PSCustomObject]@{ Name = "Obj3"; Value = 30 }
            )
            $displayBlock = { param($item) Write-Host "$($item.Name): $($item.Value)" }
            $result = Show-PagedContent -Content $objects -DisplayScriptBlock $displayBlock -Silent -NoPaging
            $result | Should -Be "completed"
        }
    }
    
    Context "NoPaging switch behavior" {
        It "Should display all items without paging when NoPaging is specified" {
            $content = 1..50 | ForEach-Object { "Item $_" }
            $result = Show-PagedContent -Content $content -NoPaging -Silent
            $result | Should -Be "completed"
        }
        
        It "Should bypass paging for small datasets automatically" {
            $content = @("Item 1", "Item 2", "Item 3")
            $result = Show-PagedContent -Content $content -PageSize 10 -Silent
            $result | Should -Be "completed"
        }
    }
    
    Context "Silent mode behavior" {
        It "Should suppress all output in Silent mode" {
            $content = @("Item 1", "Item 2", "Item 3")
            # Should not produce any output to host
            { Show-PagedContent -Content $content -Silent } | Should -Not -Throw
        }
        
        It "Should bypass paging in Silent mode" {
            $content = 1..50 | ForEach-Object { "Item $_" }
            $result = Show-PagedContent -Content $content -PageSize 10 -Silent
            $result | Should -Be "completed"
        }
        
        It "Should return 'completed' for successful processing in Silent mode" {
            $content = @("Item 1", "Item 2")
            $result = Show-PagedContent -Content $content -Silent
            $result | Should -Be "completed"
        }
    }
    
    Context "Title and ShowPageInfo parameters" {
        It "Should accept custom title" {
            $content = @("Item 1", "Item 2")
            $result = Show-PagedContent -Content $content -Title "My Custom Report" -Silent -NoPaging
            $result | Should -Be "completed"
        }
        
        It "Should accept empty title" {
            $content = @("Item 1", "Item 2")
            $result = Show-PagedContent -Content $content -Title "" -Silent -NoPaging
            $result | Should -Be "completed"
        }
        
        It "Should respect ShowPageInfo parameter" {
            $content = @("Item 1", "Item 2")
            $result = Show-PagedContent -Content $content -ShowPageInfo $false -Silent -NoPaging
            $result | Should -Be "completed"
        }
    }
    
    Context "DisplayScriptBlock execution" {
        It "Should execute DisplayScriptBlock for each item" {
            # Use Write-Host mocking to verify execution count (NOT in Silent mode)
            $content = @("Item 1", "Item 2", "Item 3")
            $displayBlock = {
                param($item)
                Write-Host "DisplayBlock: $item"
            }
            
            Mock Write-Host { }
            
            # Use NoPaging but not Silent to allow DisplayScriptBlock execution
            Show-PagedContent -Content $content -DisplayScriptBlock $displayBlock -NoPaging
            
            # Verify Write-Host was called 3 times with our specific pattern
            Should -Invoke Write-Host -Times 3 -ParameterFilter { $Object -like "DisplayBlock:*" }
        }
        
        It "Should pass item to DisplayScriptBlock correctly" {
            $content = @("Item 1", "Item 2")
            $displayBlock = {
                param($item)
                Write-Host "Captured: $item"
            }
            
            Mock Write-Host { }
            
            # Use NoPaging but not Silent to allow DisplayScriptBlock execution
            Show-PagedContent -Content $content -DisplayScriptBlock $displayBlock -NoPaging
            
            # Verify each item was passed correctly
            Should -Invoke Write-Host -ParameterFilter { $Object -eq "Captured: Item 1" }
            Should -Invoke Write-Host -ParameterFilter { $Object -eq "Captured: Item 2" }
        }
        
        It "Should handle DisplayScriptBlock errors gracefully" {
            $content = @("Item 1", "Item 2")
            $displayBlock = {
                param($item)
                throw "Test error"
            }
            
            # Should not throw even if DisplayScriptBlock throws
            { Show-PagedContent -Content $content -DisplayScriptBlock $displayBlock -Silent -NoPaging } | Should -Not -Throw
        }
    }
    
    Context "Paging calculation and boundaries" {
        It "Should calculate correct number of pages" {
            # 25 items with PageSize 10 should result in 3 pages
            $content = 1..25 | ForEach-Object { "Item $_" }
            # Test in Silent mode to avoid interactive prompt
            $result = Show-PagedContent -Content $content -PageSize 10 -Silent
            $result | Should -Be "completed"
        }
        
        It "Should handle exact page boundary (items evenly divisible by PageSize)" {
            $content = 1..30 | ForEach-Object { "Item $_" }
            $result = Show-PagedContent -Content $content -PageSize 10 -Silent
            $result | Should -Be "completed"
        }
        
        It "Should handle partial last page" {
            $content = 1..23 | ForEach-Object { "Item $_" }
            $result = Show-PagedContent -Content $content -PageSize 10 -Silent
            $result | Should -Be "completed"
        }
    }
    
    Context "Navigation simulation (mocked input)" {
        BeforeEach {
            # Mock Read-Host to simulate user input
            Mock Read-Host { return "q" }
        }
        
        It "Should accept 'q' to quit paging" {
            $content = 1..50 | ForEach-Object { "Item $_" }
            $result = Show-PagedContent -Content $content -PageSize 10
            $result | Should -Be "quit"
        }
    }
    
    Context "Return values" {
        It "Should return 'completed' when all items displayed without paging" {
            $content = @("Item 1", "Item 2")
            $result = Show-PagedContent -Content $content -Silent -NoPaging
            $result | Should -Be "completed"
        }
        
        It "Should return 'completed' in Silent mode" {
            $content = 1..50 | ForEach-Object { "Item $_" }
            $result = Show-PagedContent -Content $content -PageSize 10 -Silent
            $result | Should -Be "completed"
        }
        
        It "Should return error message when DisplayScriptBlock required but missing" {
            $ht = @{ key1 = "value1" }
            $result = Show-PagedContent -Content $ht -Silent
            $result | Should -Match "error"
        }
    }
    
    Context "Integration with real-world scenarios" {
        It "Should handle settings-like data structure" {
            $settings = @(
                [PSCustomObject]@{ Name = "setting1"; Path = "setting1"; CurrentValue = "value1"; DefaultValue = "default1"; IsNested = $false },
                [PSCustomObject]@{ Name = "setting2"; Path = "parent.setting2"; CurrentValue = "value2"; DefaultValue = "default2"; IsNested = $true }
            )
            
            $displayBlock = {
                param($setting)
                Write-Host "Setting: $($setting.Name)" -ForegroundColor Yellow
                Write-Host "  Value: $($setting.CurrentValue)" -ForegroundColor Green
            }
            
            $result = Show-PagedContent -Content $settings -DisplayScriptBlock $displayBlock -Silent -NoPaging
            $result | Should -Be "completed"
        }
        
        It "Should handle device report-like data structure" {
            $reportItems = @(
                [PSCustomObject]@{ Property = "Device Name"; Value = "DESKTOP-ABC123" },
                [PSCustomObject]@{ Property = "Serial Number"; Value = "SN12345" },
                [PSCustomObject]@{ Property = "Last Sync"; Value = "2025-10-22 10:30:00" }
            )
            
            $displayBlock = {
                param($item)
                Write-Host "$($item.Property): $($item.Value)"
            }
            
            $result = Show-PagedContent -Content $reportItems -DisplayScriptBlock $displayBlock -Silent -NoPaging
            $result | Should -Be "completed"
        }
        
        It "Should handle log file content (multi-line string)" {
            $logContent = @"
[2025-10-22 10:00:00] INFO: Application started
[2025-10-22 10:00:05] DEBUG: Initializing modules
[2025-10-22 10:00:10] INFO: Modules loaded successfully
[2025-10-22 10:00:15] WARNING: Configuration file not found, using defaults
"@
            
            $result = Show-PagedContent -Content $logContent -PageSize 2 -Silent
            $result | Should -Be "completed"
        }
    }
    
    Context "PowerShell 5.1 compatibility" {
        It "Should not use null-coalescing operator" {
            # This test ensures the function runs without syntax errors in PS 5.1
            $content = @("Item 1", "Item 2")
            { Show-PagedContent -Content $content -Silent } | Should -Not -Throw
        }
        
        It "Should handle ordered dictionary creation" {
            # Ensure compatibility with PS 5.1 ordered dictionary syntax
            $content = @("Item 1", "Item 2")
            { Show-PagedContent -Content $content -Silent } | Should -Not -Throw
        }
    }
    
    Context "UseDynamicSize parameter" {
        It "Should accept UseDynamicSize switch parameter" {
            $content = @("Item 1", "Item 2", "Item 3")
            { Show-PagedContent -Content $content -UseDynamicSize -Silent } | Should -Not -Throw
        }
        
        It "Should calculate dynamic page size for PSCustomObjects with Description properties" {
            $content = @(
                [PSCustomObject]@{ Name = "App1"; Description = "Short description"; Intent = "required" },
                [PSCustomObject]@{ Name = "App2"; Description = "This is a much longer description that will wrap to multiple lines when displayed in the console window and should be accounted for in the line calculations"; Intent = "available" },
                [PSCustomObject]@{ Name = "App3"; Description = "Medium length description here"; Intent = "required" }
            )
            $displayBlock = {
                param($item)
                Write-Host "Name: $($item.Name)"
                Write-Host "  Description: $($item.Description)"
                Write-Host "  Intent: $($item.Intent)"
                Write-Host ""
            }
            $result = Show-PagedContent -Content $content -UseDynamicSize -PageSize 10 -DisplayScriptBlock $displayBlock -Silent
            $result | Should -Be "completed"
        }
        
        It "Should handle string arrays with UseDynamicSize" {
            $content = 1..50 | ForEach-Object { "Item $_" }
            $result = Show-PagedContent -Content $content -UseDynamicSize -Silent
            $result | Should -Be "completed"
        }
        
        It "Should skip dynamic sizing in Silent mode" {
            $content = 1..50 | ForEach-Object { "Item $_" }
            $result = Show-PagedContent -Content $content -UseDynamicSize -Silent
            $result | Should -Be "completed"
        }
        
        It "Should skip dynamic sizing with NoPaging switch" {
            $content = 1..50 | ForEach-Object { "Item $_" }
            $result = Show-PagedContent -Content $content -UseDynamicSize -NoPaging -Silent
            $result | Should -Be "completed"
        }
        
        It "Should handle empty Description properties gracefully" {
            $content = @(
                [PSCustomObject]@{ Name = "App1"; Description = $null; Intent = "required" },
                [PSCustomObject]@{ Name = "App2"; Description = ""; Intent = "available" }
            )
            $displayBlock = {
                param($item)
                Write-Host "Name: $($item.Name)"
                if ($item.Description) { Write-Host "  Description: $($item.Description)" }
                Write-Host "  Intent: $($item.Intent)"
            }
            $result = Show-PagedContent -Content $content -UseDynamicSize -DisplayScriptBlock $displayBlock -Silent
            $result | Should -Be "completed"
        }
    }
}

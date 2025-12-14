BeforeAll {
    # Import test helpers
    $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
    Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

    # Dot-source dependencies
    . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"

    # Dot-source the function under test
    . "$script:RepoRoot/functions/utilityFunctions/Get-DateInput.ps1"

    # Mock global variables that the function expects
    $global:logFile = "TestDrive:\test.log"

    # Mock write-log to prevent actual logging
    Mock write-log {}
}

Describe "Get-DateInput" -Tags 'Unit', 'Utility' {

    BeforeEach {
        # Mock Write-Host to suppress output
        Mock Write-Host {}
        Mock Write-Verbose {}
    }

    Context "Blank Input" {
        It "Should return null when user presses Enter without input on first prompt" {
            Mock Read-Host { return "" }

            $result = Get-DateInput

            $result | Should -BeNullOrEmpty
            Should -Invoke Read-Host -Times 1
        }

        It "Should return null when user enters whitespace on first prompt" {
            Mock Read-Host { return "   " }

            $result = Get-DateInput

            $result | Should -BeNullOrEmpty
            Should -Invoke Read-Host -Times 1
        }
    }

    Context "Relative Date - Days" {
        It "Should parse '30' as 30 days ago" {
            Mock Read-Host { return "30" }
            $expectedDate = (Get-Date).AddDays(-30).Date

            $result = Get-DateInput

            $result | Should -Not -BeNullOrEmpty
            $result.Date | Should -Be $expectedDate
        }

        It "Should parse '30d' as 30 days ago" {
            Mock Read-Host { return "30d" }
            $expectedDate = (Get-Date).AddDays(-30).Date

            $result = Get-DateInput

            $result | Should -Not -BeNullOrEmpty
            $result.Date | Should -Be $expectedDate
        }

        It "Should parse '1' as 1 day ago" {
            Mock Read-Host { return "1" }
            $expectedDate = (Get-Date).AddDays(-1).Date

            $result = Get-DateInput

            $result | Should -Not -BeNullOrEmpty
            $result.Date | Should -Be $expectedDate
        }

        It "Should parse '90d' as 90 days ago" {
            Mock Read-Host { return "90d" }
            $expectedDate = (Get-Date).AddDays(-90).Date

            $result = Get-DateInput

            $result | Should -Not -BeNullOrEmpty
            $result.Date | Should -Be $expectedDate
        }

        It "Should handle spaces in '30 d'" {
            Mock Read-Host { return " 30 d " }
            $expectedDate = (Get-Date).AddDays(-30).Date

            $result = Get-DateInput

            $result | Should -Not -BeNullOrEmpty
            $result.Date | Should -Be $expectedDate
        }
    }

    Context "Relative Date - Months" {
        It "Should parse '3m' as 3 months ago" {
            Mock Read-Host { return "3m" }
            $expectedDate = (Get-Date).AddMonths(-3).Date

            $result = Get-DateInput

            $result | Should -Not -BeNullOrEmpty
            $result.Date | Should -Be $expectedDate
        }

        It "Should parse '1m' as 1 month ago" {
            Mock Read-Host { return "1m" }
            $expectedDate = (Get-Date).AddMonths(-1).Date

            $result = Get-DateInput

            $result | Should -Not -BeNullOrEmpty
            $result.Date | Should -Be $expectedDate
        }

        It "Should parse '12m' as 12 months ago" {
            Mock Read-Host { return "12m" }
            $expectedDate = (Get-Date).AddMonths(-12).Date

            $result = Get-DateInput

            $result | Should -Not -BeNullOrEmpty
            $result.Date | Should -Be $expectedDate
        }
    }

    Context "Relative Date - Years" {
        It "Should parse '1y' as 1 year ago" {
            Mock Read-Host { return "1y" }
            $expectedDate = (Get-Date).AddYears(-1).Date

            $result = Get-DateInput

            $result | Should -Not -BeNullOrEmpty
            $result.Date | Should -Be $expectedDate
        }

        It "Should parse '2y' as 2 years ago" {
            Mock Read-Host { return "2y" }
            $expectedDate = (Get-Date).AddYears(-2).Date

            $result = Get-DateInput

            $result | Should -Not -BeNullOrEmpty
            $result.Date | Should -Be $expectedDate
        }
    }

    Context "Absolute Date - YYYY-MM-DD Format" {
        It "Should parse '2025-01-15' correctly" {
            Mock Read-Host { return "2025-01-15" }
            $expectedDate = Get-Date -Year 2025 -Month 1 -Day 15 -Hour 0 -Minute 0 -Second 0

            $result = Get-DateInput

            $result | Should -Not -BeNullOrEmpty
            $result.Date | Should -Be $expectedDate.Date
            $result.Hour | Should -Be 0
            $result.Minute | Should -Be 0
            $result.Second | Should -Be 0
        }

        It "Should parse '2024-12-25' correctly" {
            Mock Read-Host { return "2024-12-25" }
            $expectedDate = Get-Date -Year 2024 -Month 12 -Day 25 -Hour 0 -Minute 0 -Second 0

            $result = Get-DateInput

            $result | Should -Not -BeNullOrEmpty
            $result.Date | Should -Be $expectedDate.Date
        }

        It "Should parse '2023-03-01' correctly" {
            Mock Read-Host { return "2023-03-01" }
            $expectedDate = Get-Date -Year 2023 -Month 3 -Day 1 -Hour 0 -Minute 0 -Second 0

            $result = Get-DateInput

            $result | Should -Not -BeNullOrEmpty
            $result.Date | Should -Be $expectedDate.Date
        }
    }

    Context "Absolute Date - YYYY/MM/DD Format" {
        It "Should parse '2025/01/15' correctly" {
            Mock Read-Host { return "2025/01/15" }
            $expectedDate = Get-Date -Year 2025 -Month 1 -Day 15 -Hour 0 -Minute 0 -Second 0

            $result = Get-DateInput

            $result | Should -Not -BeNullOrEmpty
            $result.Date | Should -Be $expectedDate.Date
        }
    }

    Context "Absolute Date - MM-DD-YYYY Format" {
        It "Should parse '01-15-2025' correctly" {
            Mock Read-Host { return "01-15-2025" }
            $expectedDate = Get-Date -Year 2025 -Month 1 -Day 15 -Hour 0 -Minute 0 -Second 0

            $result = Get-DateInput

            $result | Should -Not -BeNullOrEmpty
            $result.Date | Should -Be $expectedDate.Date
        }

        It "Should parse '12-31-2024' correctly" {
            Mock Read-Host { return "12-31-2024" }
            $expectedDate = Get-Date -Year 2024 -Month 12 -Day 31 -Hour 0 -Minute 0 -Second 0

            $result = Get-DateInput

            $result | Should -Not -BeNullOrEmpty
            $result.Date | Should -Be $expectedDate.Date
        }
    }

    Context "Absolute Date - MM/DD/YYYY Format" {
        It "Should parse '01/15/2025' correctly" {
            Mock Read-Host { return "01/15/2025" }
            $expectedDate = Get-Date -Year 2025 -Month 1 -Day 15 -Hour 0 -Minute 0 -Second 0

            $result = Get-DateInput

            $result | Should -Not -BeNullOrEmpty
            $result.Date | Should -Be $expectedDate.Date
        }
    }

    Context "Invalid Input with Retry" {
        It "Should retry on invalid format and accept valid date" {
            $script:callCount = 0
            Mock Read-Host {
                $script:callCount++
                if ($script:callCount -eq 1)
                {
                    return "invalid-date"
                }
                return "2025-01-15"
            }

            $result = Get-DateInput

            $result | Should -Not -BeNullOrEmpty
            $result.Date | Should -Be (Get-Date -Year 2025 -Month 1 -Day 15).Date
            Should -Invoke Read-Host -Times 2
        }

        It "Should retry multiple times until valid input" {
            $script:callCount = 0
            Mock Read-Host {
                $script:callCount++
                switch ($script:callCount)
                {
                    1
                    {
                        return "bad-input"
                    }
                    2
                    {
                        return "also-bad"
                    }
                    3
                    {
                        return "30d"
                    }
                }
            }

            $result = Get-DateInput

            $result | Should -Not -BeNullOrEmpty
            Should -Invoke Read-Host -Times 3
        }

        It "Should return null if user enters blank after invalid input" {
            $script:callCount = 0
            Mock Read-Host {
                $script:callCount++
                if ($script:callCount -eq 1)
                {
                    return "invalid"
                }
                return ""
            }

            $result = Get-DateInput

            $result | Should -BeNullOrEmpty
            Should -Invoke Read-Host -Times 2
        }

        It "Should show error message on invalid input" {
            $script:callCount = 0
            Mock Read-Host {
                $script:callCount++
                if ($script:callCount -eq 1)
                {
                    return "baddate"
                }
                return ""
            }

            $result = Get-DateInput

            Should -Invoke Write-Host -ParameterFilter {
                $Object -like "*Invalid date format*"
            }
        }
    }

    Context "Invalid Date Values" {
        It "Should reject invalid month (13)" {
            $script:callCount = 0
            Mock Read-Host {
                $script:callCount++
                if ($script:callCount -eq 1)
                {
                    return "2025-13-01"
                }
                return ""
            }

            $result = Get-DateInput

            $result | Should -BeNullOrEmpty
            Should -Invoke Read-Host -Times 2
        }

        It "Should reject invalid day (32)" {
            $script:callCount = 0
            Mock Read-Host {
                $script:callCount++
                if ($script:callCount -eq 1)
                {
                    return "2025-01-32"
                }
                return ""
            }

            $result = Get-DateInput

            $result | Should -BeNullOrEmpty
            Should -Invoke Read-Host -Times 2
        }

        It "Should reject invalid year (999)" {
            $script:callCount = 0
            Mock Read-Host {
                $script:callCount++
                if ($script:callCount -eq 1)
                {
                    return "999-01-01"
                }
                return ""
            }

            $result = Get-DateInput

            $result | Should -BeNullOrEmpty
            Should -Invoke Read-Host -Times 2
        }
    }

    Context "Custom Message Parameter" {
        It "Should display custom message when provided" {
            Mock Read-Host { return "" }
            $customMessage = "Enter custom date for testing"

            $result = Get-DateInput -message $customMessage

            Should -Invoke Write-Host -ParameterFilter {
                $Object -eq $customMessage
            }
        }

        It "Should use default message when not provided" {
            Mock Read-Host { return "" }

            $result = Get-DateInput

            Should -Invoke Write-Host -ParameterFilter {
                $Object -like "*restrict the report to devices*"
            }
        }
    }

    Context "Edge Cases" {
        It "Should handle single digit months and days in YYYY-MM-DD format" {
            Mock Read-Host { return "2025-1-5" }
            $expectedDate = Get-Date -Year 2025 -Month 1 -Day 5 -Hour 0 -Minute 0 -Second 0

            $result = Get-DateInput

            $result | Should -Not -BeNullOrEmpty
            $result.Date | Should -Be $expectedDate.Date
        }

        It "Should handle single digit months and days in MM/DD/YYYY format" {
            Mock Read-Host { return "1/5/2025" }
            $expectedDate = Get-Date -Year 2025 -Month 1 -Day 5 -Hour 0 -Minute 0 -Second 0

            $result = Get-DateInput

            $result | Should -Not -BeNullOrEmpty
            $result.Date | Should -Be $expectedDate.Date
        }

        It "Should handle leap year date" {
            Mock Read-Host { return "2024-02-29" }
            $expectedDate = Get-Date -Year 2024 -Month 2 -Day 29 -Hour 0 -Minute 0 -Second 0

            $result = Get-DateInput

            $result | Should -Not -BeNullOrEmpty
            $result.Date | Should -Be $expectedDate.Date
        }

        It "Should set time to midnight (00:00:00) for absolute dates" {
            Mock Read-Host { return "2025-01-15" }

            $result = Get-DateInput

            $result.Hour | Should -Be 0
            $result.Minute | Should -Be 0
            $result.Second | Should -Be 0
        }
    }

    Context "Logging and Verbosity" {
        It "Should call write-log during execution" {
            Mock Read-Host { return "" }

            $result = Get-DateInput

            Should -Invoke write-log -Times 1 -Exactly:$false
        }

        It "Should log with function name" {
            Mock Read-Host { return "" }

            $result = Get-DateInput

            Should -Invoke write-log -ParameterFilter {
                $module -eq "Get-DateInput"
            } -Times 1 -Exactly:$false
        }
    }
}

<#
.SYNOPSIS
    Unit tests for ExportDeviceStorage function
.DESCRIPTION
    Tests device storage export functionality including:
    - Filter construction (with/without device prefix)
    - Native CallGraphAPI batching integration
    - CSV export generation
    - Error handling
    - Storage calculation (GB conversions, percentages)
.NOTES
    Part of reporting functions test suite
    Tests use mocked CallGraphAPI to avoid actual Graph API calls
    Focus: Filter correctness, batch processing, data transformation
#>

Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: ExportDeviceStorage" -Tags 'Unit', 'ReportingFunctions' {
    BeforeAll {
        # Direct dot-sourcing for PS 5.1 compatibility
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        
        # Load dependencies
        . (Join-Path $script:RepoRoot "functions\utilityFunctions\Write-Log.ps1")
        . (Join-Path $script:RepoRoot "functions\graphFunctions\CallGraphAPI.ps1")
        
        # Load function under test
        . (Join-Path $script:RepoRoot "functions\reportingFunctions\ExportDeviceStorage.ps1")
        
        # Mock Write-Log for all tests
        Mock Write-Log {}
        
        # Initialize required script variables
        $script:logFile = "TestDrive:\test.log"
        $script:testAccessToken = "test-access-token-12345"
        
        # Setup test output directory
        $script:testOutputDir = "TestDrive:\Reports"
        New-Item -Path $script:testOutputDir -ItemType Directory -Force | Out-Null
    }
    
    Context "When device prefix filter is configured" {
        BeforeEach {
            $global:settings = @{
                deviceNamePrefix = 'TEST-'
            }
            
            Mock CallGraphApi {
                param($ResourcePath, $Filter, $Method)
                
                # Mock initial device list call
                if ($ResourcePath -eq "deviceManagement/managedDevices" -and $Method -ne "POST")
                {
                    return @{
                        value = @(
                            @{ id = 'device-1'; deviceName = 'TEST-PC01'; serialNumber = 'SN001' },
                            @{ id = 'device-2'; deviceName = 'TEST-PC02'; serialNumber = 'SN002' }
                        )
                    }
                }
                
                # Mock batch response
                if ($ResourcePath -is [array])
                {
                    return @{
                        batchProcessed = $true
                        successCount   = 2
                        failureCount   = 0
                        value          = @(
                            @{
                                id                        = 'device-1'
                                deviceName                = 'TEST-PC01'
                                serialNumber              = 'SN001'
                                manufacturer              = 'Dell'
                                model                     = 'Latitude 7420'
                                systemFamily              = 'Latitude'
                                userPrincipalName         = 'user1@test.com'
                                userDisplayName           = 'User One'
                                operatingSystem           = 'Windows'
                                osVersion                 = '10.0.19045'
                                lastSyncDateTime          = '2025-11-07T10:00:00Z'
                                physicalMemoryInBytes     = 17179869184
                                totalStorageSpaceInBytes  = 512110190592
                                freeStorageSpaceInBytes   = 256055095296
                                joinType                  = 'azureADJoined'
                                complianceState           = 'compliant'
                            },
                            @{
                                id                        = 'device-2'
                                deviceName                = 'TEST-PC02'
                                serialNumber              = 'SN002'
                                manufacturer              = 'HP'
                                model                     = 'EliteBook 840'
                                systemFamily              = 'EliteBook'
                                userPrincipalName         = 'user2@test.com'
                                userDisplayName           = 'User Two'
                                operatingSystem           = 'Windows'
                                osVersion                 = '10.0.22631'
                                lastSyncDateTime          = '2025-11-07T11:00:00Z'
                                physicalMemoryInBytes     = 34359738368
                                totalStorageSpaceInBytes  = 1024220381184
                                freeStorageSpaceInBytes   = 512110190592
                                joinType                  = 'azureADJoined'
                                complianceState           = 'compliant'
                            }
                        )
                    }
                }
            }
        }
        
        It "Should construct filter with correct OData syntax 'startswith' (lowercase)" {
            $outputFile = Join-Path $script:testOutputDir "test1.csv"
            
            ExportDeviceStorage -AccessToken $script:testAccessToken -OutputFile $outputFile
            
            Should -Invoke CallGraphApi -ParameterFilter {
                $Filter -match "startswith\(deviceName,'TEST-'\)"
            }
        }
        
        It "Should include operatingSystem filter" {
            $outputFile = Join-Path $script:testOutputDir "test2.csv"
            
            ExportDeviceStorage -AccessToken $script:testAccessToken -OutputFile $outputFile
            
            Should -Invoke CallGraphApi -ParameterFilter {
                $Filter -match "operatingSystem eq 'Windows'"
            }
        }
        
        It "Should escape single quotes in device prefix" {
            $global:settings.deviceNamePrefix = "TEST'QUOTE-"
            $outputFile = Join-Path $script:testOutputDir "test3.csv"
            
            ExportDeviceStorage -AccessToken $script:testAccessToken -OutputFile $outputFile
            
            Should -Invoke CallGraphApi -ParameterFilter {
                $Filter -match "TEST''QUOTE-"
            }
        }
        
        It "Should return success when devices are exported" {
            $outputFile = Join-Path $script:testOutputDir "test4.csv"
            
            $result = ExportDeviceStorage -AccessToken $script:testAccessToken -OutputFile $outputFile
            
            $result | Should -Be $true
        }
        
        It "Should create CSV file with exported data" {
            $outputFile = Join-Path $script:testOutputDir "test5.csv"
            
            ExportDeviceStorage -AccessToken $script:testAccessToken -OutputFile $outputFile
            
            Test-Path $outputFile | Should -Be $true
        }
    }
    
    Context "When no device prefix is configured" {
        BeforeEach {
            $global:settings = @{
                deviceNamePrefix = $null
            }
            
            Mock CallGraphApi {
                param($ResourcePath, $Filter)
                
                if ($ResourcePath -eq "deviceManagement/managedDevices")
                {
                    return @{
                        value = @(
                            @{ id = 'device-1'; deviceName = 'PC01'; serialNumber = 'SN001' }
                        )
                    }
                }
                
                if ($ResourcePath -is [array])
                {
                    return @{
                        batchProcessed = $true
                        successCount   = 1
                        failureCount   = 0
                        value          = @(
                            @{
                                id                        = 'device-1'
                                deviceName                = 'PC01'
                                serialNumber              = 'SN001'
                                manufacturer              = 'Dell'
                                model                     = 'OptiPlex 7090'
                                physicalMemoryInBytes     = 8589934592
                                totalStorageSpaceInBytes  = 256055095296
                                freeStorageSpaceInBytes   = 128027547648
                                operatingSystem           = 'Windows'
                                osVersion                 = '10.0.19045'
                            }
                        )
                    }
                }
            }
        }
        
        It "Should use basic Windows filter without prefix" {
            $outputFile = Join-Path $script:testOutputDir "test6.csv"
            
            ExportDeviceStorage -AccessToken $script:testAccessToken -OutputFile $outputFile
            
            Should -Invoke CallGraphApi -ParameterFilter {
                $Filter -eq "operatingSystem eq 'Windows'"
            }
        }
        
        It "Should not include startswith clause when prefix is empty" {
            $outputFile = Join-Path $script:testOutputDir "test7.csv"
            
            ExportDeviceStorage -AccessToken $script:testAccessToken -OutputFile $outputFile
            
            Should -Invoke CallGraphApi -ParameterFilter {
                $Filter -notmatch "startswith"
            }
        }
    }
    
    Context "When using CallGraphAPI native batching" {
        BeforeEach {
            $global:settings = @{ deviceNamePrefix = 'BATCH-' }
            
            # Create 45 devices to test batching (should use multiple batches)
            $script:mockDevices = 1..45 | ForEach-Object {
                @{
                    id           = "device-$_"
                    deviceName   = "BATCH-PC$_"
                    serialNumber = "SN$_"
                }
            }
            
            Mock CallGraphApi {
                param($ResourcePath, $Filter)
                
                if ($ResourcePath -eq "deviceManagement/managedDevices")
                {
                    return @{ value = $script:mockDevices }
                }
                
                if ($ResourcePath -is [array])
                {
                    # CallGraphAPI should handle batching internally
                    $batchResults = $ResourcePath | ForEach-Object {
                        $deviceId = $_ -replace '.+/(.+?)\?.+', '$1'
                        @{
                            id                        = $deviceId
                            deviceName                = "BATCH-PC"
                            serialNumber              = "SN"
                            physicalMemoryInBytes     = 17179869184
                            totalStorageSpaceInBytes  = 512110190592
                            freeStorageSpaceInBytes   = 256055095296
                            operatingSystem           = 'Windows'
                            osVersion                 = '10.0.19045'
                        }
                    }
                    
                    return @{
                        batchProcessed = $true
                        successCount   = $batchResults.Count
                        failureCount   = 0
                        value          = $batchResults
                    }
                }
            }
        }
        
        It "Should pass array of resource paths to CallGraphAPI" {
            $outputFile = Join-Path $script:testOutputDir "test8.csv"
            
            ExportDeviceStorage -AccessToken $script:testAccessToken -OutputFile $outputFile
            
            Should -Invoke CallGraphApi -ParameterFilter {
                $ResourcePath -is [array]
            }
        }
        
        It "Should include select parameter in resource paths" {
            $outputFile = Join-Path $script:testOutputDir "test9.csv"
            
            ExportDeviceStorage -AccessToken $script:testAccessToken -OutputFile $outputFile
            
            Should -Invoke CallGraphApi -ParameterFilter {
                $ResourcePath -is [array] -and $ResourcePath[0] -match '\$select='
            }
        }
        
        It "Should request storage-related fields in select clause" {
            $outputFile = Join-Path $script:testOutputDir "test10.csv"
            
            ExportDeviceStorage -AccessToken $script:testAccessToken -OutputFile $outputFile
            
            Should -Invoke CallGraphApi -ParameterFilter {
                $ResourcePath -is [array] -and 
                $ResourcePath[0] -match 'physicalMemoryInBytes' -and
                $ResourcePath[0] -match 'totalStorageSpaceInBytes' -and
                $ResourcePath[0] -match 'freeStorageSpaceInBytes'
            }
        }
        
        It "Should handle large device counts with batching" {
            $outputFile = Join-Path $script:testOutputDir "test11.csv"
            
            $result = ExportDeviceStorage -AccessToken $script:testAccessToken -OutputFile $outputFile
            
            $result | Should -Be $true
            Should -Invoke CallGraphApi -Times 2 -Exactly
        }
    }
    
    Context "When calculating storage metrics" {
        BeforeEach {
            $global:settings = @{ deviceNamePrefix = 'CALC-' }
            
            Mock CallGraphApi {
                param($ResourcePath)
                
                if ($ResourcePath -eq "deviceManagement/managedDevices")
                {
                    return @{
                        value = @(
                            @{ id = 'device-calc'; deviceName = 'CALC-PC01'; serialNumber = 'SNCALC' }
                        )
                    }
                }
                
                if ($ResourcePath -is [array])
                {
                    return @{
                        batchProcessed = $true
                        successCount   = 1
                        failureCount   = 0
                        value          = @(
                            @{
                                id                        = 'device-calc'
                                deviceName                = 'CALC-PC01'
                                serialNumber              = 'SNCALC'
                                manufacturer              = 'Dell'
                                model                     = 'Precision 5560'
                                physicalMemoryInBytes     = 34359738368
                                totalStorageSpaceInBytes  = 1024220381184
                                freeStorageSpaceInBytes   = 512110190592
                                operatingSystem           = 'Windows'
                                osVersion                 = '11.0.22631'
                            }
                        )
                    }
                }
            }
        }
        
        It "Should convert bytes to GB correctly" {
            $outputFile = Join-Path $script:testOutputDir "test12.csv"
            
            ExportDeviceStorage -AccessToken $script:testAccessToken -OutputFile $outputFile
            
            $csv = Import-Csv $outputFile
            # 34359738368 bytes = 32 GB
            $csv[0].MemoryGB | Should -Be '32'
            # 1024220381184 bytes ≈ 953.87 GB
            [double]$csv[0].TotalStorageGB | Should -BeGreaterThan 953
            [double]$csv[0].TotalStorageGB | Should -BeLessThan 954
        }
        
        It "Should calculate used storage correctly" {
            $outputFile = Join-Path $script:testOutputDir "test13.csv"
            
            ExportDeviceStorage -AccessToken $script:testAccessToken -OutputFile $outputFile
            
            $csv = Import-Csv $outputFile
            # Used = Total - Free ≈ 476.94 GB
            [double]$csv[0].UsedStorageGB | Should -BeGreaterThan 476
            [double]$csv[0].UsedStorageGB | Should -BeLessThan 477
        }
        
        It "Should calculate storage percentage correctly" {
            $outputFile = Join-Path $script:testOutputDir "test14.csv"
            
            ExportDeviceStorage -AccessToken $script:testAccessToken -OutputFile $outputFile
            
            $csv = Import-Csv $outputFile
            # Percentage should be around 50%
            $percentage = $csv[0].UsedStoragePercent -replace '%', ''
            [double]$percentage | Should -BeGreaterThan 49
            [double]$percentage | Should -BeLessThan 51
        }
        
        It "Should handle null storage values gracefully" {
            Mock CallGraphApi {
                param($ResourcePath)
                
                if ($ResourcePath -eq "deviceManagement/managedDevices")
                {
                    return @{
                        value = @(
                            @{ id = 'device-null'; deviceName = 'NULL-PC'; serialNumber = 'SNNULL' }
                        )
                    }
                }
                
                if ($ResourcePath -is [array])
                {
                    return @{
                        batchProcessed = $true
                        successCount   = 1
                        failureCount   = 0
                        value          = @(
                            @{
                                id                        = 'device-null'
                                deviceName                = 'NULL-PC'
                                serialNumber              = 'SNNULL'
                                physicalMemoryInBytes     = $null
                                totalStorageSpaceInBytes  = $null
                                freeStorageSpaceInBytes   = $null
                                operatingSystem           = 'Windows'
                            }
                        )
                    }
                }
            }
            
            $outputFile = Join-Path $script:testOutputDir "test15.csv"
            
            ExportDeviceStorage -AccessToken $script:testAccessToken -OutputFile $outputFile
            
            $csv = Import-Csv $outputFile
            $csv[0].MemoryGB | Should -Be '0'
            $csv[0].TotalStorageGB | Should -Be '0'
            $csv[0].UsedStorageGB | Should -Be '0'
            $csv[0].UsedStoragePercent | Should -Be '0%'
        }
    }
    
    Context "When handling errors" {
        BeforeEach {
            $global:settings = @{ deviceNamePrefix = 'ERROR-' }
        }
        
        It "Should return false when no devices found" {
            Mock CallGraphApi {
                return @{ value = @() }
            }
            
            $outputFile = Join-Path $script:testOutputDir "test16.csv"
            
            $result = ExportDeviceStorage -AccessToken $script:testAccessToken -OutputFile $outputFile
            
            $result | Should -Be $false
        }
        
        It "Should return false when device list is null" {
            Mock CallGraphApi {
                return $null
            }
            
            $outputFile = Join-Path $script:testOutputDir "test17.csv"
            
            $result = ExportDeviceStorage -AccessToken $script:testAccessToken -OutputFile $outputFile
            
            $result | Should -Be $false
        }
        
        It "Should handle batch processing failures gracefully" {
            Mock CallGraphApi {
                param($ResourcePath)
                
                if ($ResourcePath -eq "deviceManagement/managedDevices")
                {
                    return @{
                        value = @(
                            @{ id = 'device-fail'; deviceName = 'FAIL-PC'; serialNumber = 'SNFAIL' }
                        )
                    }
                }
                
                if ($ResourcePath -is [array])
                {
                    return @{
                        batchProcessed = $true
                        successCount   = 0
                        failureCount   = 1
                        value          = @()
                    }
                }
            }
            
            $outputFile = Join-Path $script:testOutputDir "test18.csv"
            
            $result = ExportDeviceStorage -AccessToken $script:testAccessToken -OutputFile $outputFile
            
            $result | Should -Be $false
        }
        
        It "Should handle exceptions during processing" {
            Mock CallGraphApi {
                throw "Graph API error"
            }
            
            $outputFile = Join-Path $script:testOutputDir "test19.csv"
            
            $result = ExportDeviceStorage -AccessToken $script:testAccessToken -OutputFile $outputFile
            
            $result | Should -Be $false
        }
    }
    
    Context "When using custom filter parameter" {
        BeforeEach {
            $global:settings = @{ deviceNamePrefix = 'CUSTOM-' }
            
            Mock CallGraphApi {
                param($ResourcePath, $Filter)
                
                if ($ResourcePath -eq "deviceManagement/managedDevices")
                {
                    return @{
                        value = @(
                            @{ id = 'device-custom'; deviceName = 'CUSTOM-PC'; serialNumber = 'SNCUSTOM' }
                        )
                    }
                }
                
                if ($ResourcePath -is [array])
                {
                    return @{
                        batchProcessed = $true
                        successCount   = 1
                        failureCount   = 0
                        value          = @(
                            @{
                                id                        = 'device-custom'
                                deviceName                = 'CUSTOM-PC'
                                serialNumber              = 'SNCUSTOM'
                                physicalMemoryInBytes     = 17179869184
                                totalStorageSpaceInBytes  = 512110190592
                                freeStorageSpaceInBytes   = 256055095296
                                operatingSystem           = 'Windows'
                            }
                        )
                    }
                }
            }
        }
        
        It "Should use custom filter when provided" {
            $customFilter = "complianceState eq 'compliant'"
            $outputFile = Join-Path $script:testOutputDir "test20.csv"
            
            ExportDeviceStorage -AccessToken $script:testAccessToken -OutputFile $outputFile -Filter $customFilter
            
            Should -Invoke CallGraphApi -ParameterFilter {
                $Filter -eq $customFilter
            }
        }
        
        It "Should ignore settings prefix when custom filter provided" {
            $customFilter = "operatingSystem eq 'Windows' and complianceState eq 'compliant'"
            $outputFile = Join-Path $script:testOutputDir "test21.csv"
            
            ExportDeviceStorage -AccessToken $script:testAccessToken -OutputFile $outputFile -Filter $customFilter
            
            Should -Invoke CallGraphApi -ParameterFilter {
                $Filter -eq $customFilter -and $Filter -notmatch 'CUSTOM-'
            }
        }
    }
    
    Context "When verifying CSV export format" {
        BeforeEach {
            $global:settings = @{ deviceNamePrefix = 'CSV-' }
            
            Mock CallGraphApi {
                param($ResourcePath)
                
                if ($ResourcePath -eq "deviceManagement/managedDevices")
                {
                    return @{
                        value = @(
                            @{ id = 'device-csv'; deviceName = 'CSV-PC01'; serialNumber = 'SNCSV' }
                        )
                    }
                }
                
                if ($ResourcePath -is [array])
                {
                    return @{
                        batchProcessed = $true
                        successCount   = 1
                        failureCount   = 0
                        value          = @(
                            @{
                                id                        = 'device-csv'
                                deviceName                = 'CSV-PC01'
                                serialNumber              = 'SNCSV'
                                manufacturer              = 'Lenovo'
                                model                     = 'ThinkPad X1'
                                systemFamily              = 'ThinkPad'
                                userPrincipalName         = 'csvuser@test.com'
                                userDisplayName           = 'CSV User'
                                operatingSystem           = 'Windows'
                                osVersion                 = '11.0.22631'
                                lastSyncDateTime          = '2025-11-07T12:00:00Z'
                                physicalMemoryInBytes     = 17179869184
                                totalStorageSpaceInBytes  = 512110190592
                                freeStorageSpaceInBytes   = 256055095296
                                joinType                  = 'azureADJoined'
                                complianceState           = 'compliant'
                            }
                        )
                    }
                }
            }
        }
        
        It "Should include all expected columns in CSV" {
            $outputFile = Join-Path $script:testOutputDir "test22.csv"
            
            ExportDeviceStorage -AccessToken $script:testAccessToken -OutputFile $outputFile
            
            $csv = Import-Csv $outputFile
            $csv[0].PSObject.Properties.Name | Should -Contain 'SerialNumber'
            $csv[0].PSObject.Properties.Name | Should -Contain 'DeviceName'
            $csv[0].PSObject.Properties.Name | Should -Contain 'Manufacturer'
            $csv[0].PSObject.Properties.Name | Should -Contain 'Model'
            $csv[0].PSObject.Properties.Name | Should -Contain 'MemoryGB'
            $csv[0].PSObject.Properties.Name | Should -Contain 'TotalStorageGB'
            $csv[0].PSObject.Properties.Name | Should -Contain 'FreeStorageGB'
            $csv[0].PSObject.Properties.Name | Should -Contain 'UsedStorageGB'
            $csv[0].PSObject.Properties.Name | Should -Contain 'UsedStoragePercent'
        }
        
        It "Should format OS version correctly" {
            $outputFile = Join-Path $script:testOutputDir "test23.csv"
            
            ExportDeviceStorage -AccessToken $script:testAccessToken -OutputFile $outputFile
            
            $csv = Import-Csv $outputFile
            $csv[0].OperatingSystem | Should -BeLike "Windows *"
        }
        
        It "Should include user information" {
            $outputFile = Join-Path $script:testOutputDir "test24.csv"
            
            ExportDeviceStorage -AccessToken $script:testAccessToken -OutputFile $outputFile
            
            $csv = Import-Csv $outputFile
            $csv[0].UserPrincipalName | Should -Be 'csvuser@test.com'
            $csv[0].UserDisplayName | Should -Be 'CSV User'
        }
        
        It "Should include device compliance state" {
            $outputFile = Join-Path $script:testOutputDir "test25.csv"
            
            ExportDeviceStorage -AccessToken $script:testAccessToken -OutputFile $outputFile
            
            $csv = Import-Csv $outputFile
            $csv[0].ComplianceState | Should -Be 'compliant'
        }
    }
    
    AfterAll {
        # Clean up TestDrive
        if (Test-Path "TestDrive:\")
        {
            Get-ChildItem "TestDrive:\" -Recurse | Remove-Item -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }
}

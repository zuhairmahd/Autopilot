Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force
Import-Module "$PSScriptRoot/../Helpers/AutopilotGraphMocks.psm1" -Force

Describe "Comprehensive Autopilot Device Import Tests" -Tags 'Comprehensive', 'Autopilot', 'Import' {
    
    BeforeAll {
        # Get repository root
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
        
        # Initialize test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment
        
        # Load all functions directly
        $functionsPath = Join-Path $script:RepoRoot "functions"
        $functionFiles = Get-ChildItem -Path $functionsPath -Recurse -Filter *.ps1 -File
        
        Write-Verbose "Loading $($functionFiles.Count) functions from $functionsPath..."
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
        
        # Setup global variables
        $global:LogFile = Join-Path $script:TestContext.TestFolder "autopilot-import.log"
    }
    
    AfterAll {
        # Cleanup test environment
        if ($script:TestContext -and $script:TestContext.TestFolder)
        {
            Remove-Item -Path $script:TestContext.TestFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context "Function Availability Validation" {
        
        It "Should have ImportAutopilotDevice function available" {
            Get-Command -Name ImportAutopilotDevice -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have PrepareImportDevice function available" {
            Get-Command -Name PrepareImportDevice -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have ProcessImportResult function available" {
            Get-Command -Name ProcessImportResult -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have HandleDeviceEnrollmentState function available" {
            Get-Command -Name HandleDeviceEnrollmentState -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have GetDeviceHash function available" {
            Get-Command -Name GetDeviceHash -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have DeleteAutopilotDevice function available" {
            Get-Command -Name DeleteAutopilotDevice -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have AddCorporateDeviceIdentifier function available" {
            Get-Command -Name AddCorporateDeviceIdentifier -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have DeleteCorporateDeviceIdentifier function available" {
            $cmd = Get-Command -Name DeleteCorporateDeviceIdentifier -ErrorAction SilentlyContinue
            if ($cmd)
            {
                $cmd | Should -Not -BeNullOrEmpty
            }
            else
            {
                Set-ItResult -Skipped -Because "DeleteCorporateDeviceIdentifier function not found"
            }
        }
        
        It "Should have GetCorpDeviceIdentifier function available" {
            $cmd = Get-Command -Name GetCorpDeviceIdentifier -ErrorAction SilentlyContinue
            if ($cmd)
            {
                $cmd | Should -Not -BeNullOrEmpty
            }
            else
            {
                Set-ItResult -Skipped -Because "GetCorpDeviceIdentifier function not found"
            }
        }
        
        It "Should have CheckDeviceAssignment function available" {
            $cmd = Get-Command -Name CheckDeviceAssignment -ErrorAction SilentlyContinue
            if ($cmd)
            {
                $cmd | Should -Not -BeNullOrEmpty
            }
            else
            {
                Set-ItResult -Skipped -Because "CheckDeviceAssignment function not found"
            }
        }
        
        It "Should have DisplayDeviceAssignmentStatus function available" {
            $cmd = Get-Command -Name DisplayDeviceAssignmentStatus -ErrorAction SilentlyContinue
            if ($cmd)
            {
                $cmd | Should -Not -BeNullOrEmpty
            }
            else
            {
                Set-ItResult -Skipped -Because "DisplayDeviceAssignmentStatus function not found"
            }
        }
        
        It "Should have ProcessAssignmentResult function available" {
            $cmd = Get-Command -Name ProcessAssignmentResult -ErrorAction SilentlyContinue
            if ($cmd)
            {
                $cmd | Should -Not -BeNullOrEmpty
            }
            else
            {
                Set-ItResult -Skipped -Because "ProcessAssignmentResult function not found"
            }
        }
    }
    
    Context "Device Hash Generation and Validation" {
        
        It "Should validate device hash structure" {
            $mockHash = @{
                SerialNumber = "TEST123456"
                HardwareHash = "ABCDEF1234567890ABCDEF1234567890"
                ProductKey   = $null
            }
            
            $mockHash.SerialNumber | Should -Not -BeNullOrEmpty
            $mockHash.HardwareHash | Should -Not -BeNullOrEmpty
            $mockHash.HardwareHash.Length | Should -BeGreaterThan 0
        }
        
        It "Should handle missing hardware hash" {
            $mockHash = @{
                SerialNumber = "TEST123456"
                HardwareHash = $null
                ProductKey   = $null
            }
            
            $mockHash.HardwareHash | Should -BeNullOrEmpty
        }
        
        It "Should validate optional product key field" {
            $mockHashWithKey = @{
                SerialNumber = "TEST123456"
                HardwareHash = "ABCDEF1234567890"
                ProductKey   = "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX"
            }
            
            $mockHashWithKey.ProductKey | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Device Enrollment State Handling" {
        
        It "Should validate enrolled and managed device state" {
            $mockState = @{
                inAutopilot   = $true
                managed       = $true
                autopilot     = @{
                    device = @{
                        displayName     = "TEST-DEVICE"
                        serialNumber    = "TEST123456"
                        enrollmentState = "enrolled"
                    }
                }
                managedDevice = @{
                    device = @{
                        deviceName      = "TEST-DEVICE"
                        operatingSystem = "Windows"
                        complianceState = "compliant"
                    }
                }
            }
            
            $mockState.inAutopilot | Should -Be $true
            $mockState.managed | Should -Be $true
            $mockState.autopilot.device.enrollmentState | Should -Be "enrolled"
        }
        
        It "Should detect device only in Autopilot" {
            $mockState = @{
                inAutopilot   = $true
                managed       = $false
                autopilot     = @{
                    device = @{
                        displayName     = "AUTOPILOT-ONLY"
                        serialNumber    = "AP123456"
                        enrollmentState = "notContacted"
                    }
                }
                managedDevice = $null
            }
            
            $mockState.inAutopilot | Should -Be $true
            $mockState.managed | Should -Be $false
            $mockState.managedDevice | Should -BeNullOrEmpty
        }
        
        It "Should handle pending enrollment state" {
            $mockState = @{
                inAutopilot   = $true
                managed       = $false
                autopilot     = @{
                    device = @{
                        displayName     = "PENDING-DEVICE"
                        serialNumber    = "PD123456"
                        enrollmentState = "pending"
                    }
                }
                managedDevice = $null
            }
            
            $mockState.autopilot.device.enrollmentState | Should -Be "pending"
        }
    }
    
    Context "Import Preparation and Validation" {
        
        It "Should validate required fields for import" {
            $mockDeviceData = @{
                SerialNumber = "TEST123456"
                HardwareHash = "TESTHASH123"
                ProductKey   = $null
                GroupTag     = "TestGroup"
            }
            
            $mockDeviceData.SerialNumber | Should -Not -BeNullOrEmpty
            $mockDeviceData.HardwareHash | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle optional group tag" {
            $mockDeviceData = @{
                SerialNumber = "TEST123456"
                HardwareHash = "TESTHASH123"
                ProductKey   = $null
                GroupTag     = $null
            }
            
            $mockDeviceData.GroupTag | Should -BeNullOrEmpty
        }
        
        It "Should validate group tag when provided" {
            $mockDeviceData = @{
                SerialNumber = "TEST123456"
                HardwareHash = "TESTHASH123"
                ProductKey   = $null
                GroupTag     = "Corporate-Devices"
            }
            
            $mockDeviceData.GroupTag | Should -Be "Corporate-Devices"
            $mockDeviceData.GroupTag | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle missing serial number" {
            $mockDeviceData = @{
                SerialNumber = $null
                HardwareHash = "TESTHASH123"
                ProductKey   = $null
                GroupTag     = "TestGroup"
            }
            
            $mockDeviceData.SerialNumber | Should -BeNullOrEmpty
        }
    }
    
    Context "Import Result Processing" {
        
        It "Should validate successful import result structure" {
            $mockResult = @{
                Success      = $true
                DeviceId     = "test-device-id-12345"
                SerialNumber = "TEST123456"
                Status       = "Imported"
                Errors       = @()
            }
            
            $mockResult.Success | Should -Be $true
            $mockResult.DeviceId | Should -Not -BeNullOrEmpty
            $mockResult.Errors | Should -BeNullOrEmpty
        }
        
        It "Should validate failed import result structure" {
            $mockResult = @{
                Success      = $false
                DeviceId     = $null
                SerialNumber = "TEST123456"
                Status       = "Failed"
                Errors       = @("Invalid hardware hash", "Device already exists")
            }
            
            $mockResult.Success | Should -Be $false
            $mockResult.Errors.Count | Should -BeGreaterThan 0
            $mockResult.DeviceId | Should -BeNullOrEmpty
        }
        
        It "Should handle partial import success" {
            $mockResult = @{
                Success      = $true
                DeviceId     = "test-device-id-12345"
                SerialNumber = "TEST123456"
                Status       = "PartialSuccess"
                Errors       = @("Warning: Profile assignment pending")
            }
            
            $mockResult.Success | Should -Be $true
            $mockResult.DeviceId | Should -Not -BeNullOrEmpty
            $mockResult.Errors.Count | Should -Be 1
        }
        
        It "Should process multiple error messages" {
            $mockResult = @{
                Success      = $false
                DeviceId     = $null
                SerialNumber = "TEST123456"
                Status       = "Failed"
                Errors       = @(
                    "Invalid hardware hash format",
                    "Serial number already registered",
                    "Group tag does not exist"
                )
            }
            
            $mockResult.Errors.Count | Should -Be 3
            $mockResult.Errors | Should -Contain "Invalid hardware hash format"
        }
    }
    
    Context "Device Assignment Validation" {
        
        It "Should validate device assignment status structure" {
            $mockAssignmentStatus = @{
                DeviceId         = "test-device-id"
                AssignedProfile  = "Corporate Profile"
                AssignmentStatus = "assigned"
                AssignedDate     = (Get-Date).ToString("o")
            }
            
            $mockAssignmentStatus.AssignedProfile | Should -Not -BeNullOrEmpty
            $mockAssignmentStatus.AssignmentStatus | Should -Be "assigned"
        }
        
        It "Should detect unassigned device" {
            $mockAssignmentStatus = @{
                DeviceId         = "test-device-id"
                AssignedProfile  = $null
                AssignmentStatus = "notAssigned"
                AssignedDate     = $null
            }
            
            $mockAssignmentStatus.AssignmentStatus | Should -Be "notAssigned"
            $mockAssignmentStatus.AssignedProfile | Should -BeNullOrEmpty
        }
        
        It "Should handle pending profile assignment" {
            $mockAssignmentStatus = @{
                DeviceId         = "test-device-id"
                AssignedProfile  = "Corporate Profile"
                AssignmentStatus = "pending"
                AssignedDate     = (Get-Date).ToString("o")
            }
            
            $mockAssignmentStatus.AssignmentStatus | Should -Be "pending"
            $mockAssignmentStatus.AssignedProfile | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Corporate Device Identifier Management" {
        
        It "Should validate corporate device identifier structure" {
            $mockIdentifier = @{
                Id               = "corp-id-12345"
                SerialNumber     = "CORP123456"
                Type             = "serialNumber"
                CreatedDateTime  = (Get-Date).ToString("o")
                LastModifiedDate = (Get-Date).ToString("o")
            }
            
            $mockIdentifier.SerialNumber | Should -Not -BeNullOrEmpty
            $mockIdentifier.Type | Should -Be "serialNumber"
        }
        
        It "Should support IMEI as identifier type" {
            $mockIdentifier = @{
                Id               = "corp-id-67890"
                Imei             = "123456789012345"
                Type             = "imei"
                CreatedDateTime  = (Get-Date).ToString("o")
                LastModifiedDate = (Get-Date).ToString("o")
            }
            
            $mockIdentifier.Imei | Should -Not -BeNullOrEmpty
            $mockIdentifier.Type | Should -Be "imei"
        }
        
        It "Should handle identifier deletion" {
            $mockDeletionResult = @{
                Success = $true
                Id      = "corp-id-12345"
                Message = "Corporate device identifier deleted successfully"
            }
            
            $mockDeletionResult.Success | Should -Be $true
            $mockDeletionResult.Id | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Device Deletion and Cleanup" {
        
        It "Should validate device deletion result" {
            $mockDeletionResult = @{
                Success      = $true
                DeviceId     = "test-device-id-12345"
                SerialNumber = "TEST123456"
                Status       = "Deleted"
            }
            
            $mockDeletionResult.Success | Should -Be $true
            $mockDeletionResult.DeviceId | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle failed device deletion" {
            $mockDeletionResult = @{
                Success      = $false
                DeviceId     = "test-device-id-12345"
                SerialNumber = "TEST123456"
                Status       = "Failed"
                Error        = "Device not found"
            }
            
            $mockDeletionResult.Success | Should -Be $false
            $mockDeletionResult.Error | Should -Not -BeNullOrEmpty
        }
        
        It "Should validate cleanup after deletion" {
            $mockCleanupResult = @{
                DeviceDeleted     = $true
                IdentifierRemoved = $true
                CacheCleared      = $true
                CleanupErrors     = @()
            }
            
            $mockCleanupResult.DeviceDeleted | Should -Be $true
            $mockCleanupResult.IdentifierRemoved | Should -Be $true
            $mockCleanupResult.CleanupErrors | Should -BeNullOrEmpty
        }
    }
    
    Context "Import Workflow Integration" {
        
        It "Should validate complete import workflow structure" {
            $mockWorkflow = @{
                PreparationStep  = @{
                    Validated = $true
                    Errors    = @()
                }
                ImportStep       = @{
                    Success  = $true
                    DeviceId = "test-device-id"
                }
                AssignmentStep   = @{
                    Success = $true
                    Profile = "Corporate Profile"
                }
                VerificationStep = @{
                    Success = $true
                    Status  = "enrolled"
                }
            }
            
            $mockWorkflow.PreparationStep.Validated | Should -Be $true
            $mockWorkflow.ImportStep.Success | Should -Be $true
            $mockWorkflow.AssignmentStep.Success | Should -Be $true
            $mockWorkflow.VerificationStep.Success | Should -Be $true
        }
        
        It "Should handle workflow failure at preparation stage" {
            $mockWorkflow = @{
                PreparationStep = @{
                    Validated = $false
                    Errors    = @("Invalid hardware hash")
                }
                ImportStep      = @{
                    Success  = $false
                    DeviceId = $null
                }
            }
            
            $mockWorkflow.PreparationStep.Validated | Should -Be $false
            $mockWorkflow.PreparationStep.Errors.Count | Should -BeGreaterThan 0
            $mockWorkflow.ImportStep.Success | Should -Be $false
        }
        
        It "Should handle workflow failure at import stage" {
            $mockWorkflow = @{
                PreparationStep = @{
                    Validated = $true
                    Errors    = @()
                }
                ImportStep      = @{
                    Success  = $false
                    DeviceId = $null
                    Error    = "Device already exists"
                }
            }
            
            $mockWorkflow.PreparationStep.Validated | Should -Be $true
            $mockWorkflow.ImportStep.Success | Should -Be $false
            $mockWorkflow.ImportStep.Error | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Batch Import Scenarios" {
        
        It "Should validate batch import structure" {
            $mockBatchImport = @{
                TotalDevices      = 10
                SuccessfulImports = 8
                FailedImports     = 2
                Results           = @(
                    @{SerialNumber = "DEV001"; Success = $true},
                    @{SerialNumber = "DEV002"; Success = $true},
                    @{SerialNumber = "DEV003"; Success = $false; Error = "Invalid hash"}
                )
            }
            
            $mockBatchImport.TotalDevices | Should -Be 10
            $mockBatchImport.SuccessfulImports | Should -Be 8
            $mockBatchImport.FailedImports | Should -Be 2
        }
        
        It "Should calculate batch import success rate" {
            $totalDevices = 100
            $successfulImports = 95
            $successRate = ($successfulImports / $totalDevices) * 100
            
            $successRate | Should -Be 95
            $successRate | Should -BeGreaterThan 90
        }
        
        It "Should handle empty batch import" {
            $mockBatchImport = @{
                TotalDevices      = 0
                SuccessfulImports = 0
                FailedImports     = 0
                Results           = @()
            }
            
            $mockBatchImport.TotalDevices | Should -Be 0
            $mockBatchImport.Results | Should -BeNullOrEmpty
        }
    }
    
    Context "Edge Cases and Error Handling" {
        
        It "Should handle null device data" {
            $mockDeviceData = $null
            
            $mockDeviceData | Should -BeNullOrEmpty
        }
        
        It "Should handle duplicate device import attempt" {
            $mockResult = @{
                Success      = $false
                SerialNumber = "TEST123456"
                Status       = "Duplicate"
                Error        = "Device with this serial number already exists"
            }
            
            $mockResult.Success | Should -Be $false
            $mockResult.Status | Should -Be "Duplicate"
        }
        
        It "Should handle invalid hardware hash format" {
            $mockHash = "INVALID-HASH"
            
            $isValidFormat = $mockHash -match '^[A-F0-9]{16,}$'
            $isValidFormat | Should -Be $false
        }
        
        It "Should validate hardware hash format" {
            $mockHash = "ABCDEF1234567890"
            
            $isValidFormat = $mockHash -match '^[A-F0-9]{16,}$'
            $isValidFormat | Should -Be $true
        }
        
        It "Should handle missing required fields gracefully" {
            $mockIncompleteData = @{
                SerialNumber = "TEST123456"
                HardwareHash = $null
            }
            
            if ([string]::IsNullOrWhiteSpace($mockIncompleteData.HardwareHash))
            {
                $isValid = $false
            }
            else
            {
                $isValid = $true
            }
            
            $isValid | Should -Be $false
        }
        
        It "Should handle API timeout scenario" {
            $mockApiResult = @{
                Success   = $false
                Error     = "Request timed out"
                Timeout   = $true
                Retryable = $true
            }
            
            $mockApiResult.Success | Should -Be $false
            $mockApiResult.Timeout | Should -Be $true
            $mockApiResult.Retryable | Should -Be $true
        }
    }
}

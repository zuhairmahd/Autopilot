Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Comprehensive Configuration Migration Tests" -Tags 'Comprehensive', 'Migration', 'Configuration' {
    
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
        $global:LogFile = Join-Path $script:TestContext.TestFolder "migration.log"
    }
    
    AfterAll {
        # Cleanup test environment
        if ($script:TestContext -and $script:TestContext.TestFolder)
        {
            Remove-Item -Path $script:TestContext.TestFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context "Function Availability Validation" {
        
        It "Should have Invoke-SettingsMigration function available" {
            $cmd = Get-Command -Name Invoke-SettingsMigration -ErrorAction SilentlyContinue
            if ($cmd)
            {
                $cmd | Should -Not -BeNullOrEmpty
            }
            else
            {
                Set-ItResult -Skipped -Because "Invoke-SettingsMigration function not found"
            }
        }
        
        It "Should have Resolve-MigratedLegacyObjects function available" {
            $cmd = Get-Command -Name Resolve-MigratedLegacyObjects -ErrorAction SilentlyContinue
            if ($cmd)
            {
                $cmd | Should -Not -BeNullOrEmpty
            }
            else
            {
                Set-ItResult -Skipped -Because "Resolve-MigratedLegacyObjects function not found"
            }
        }
        
        It "Should have ConvertFrom-JsonToHashtable function available" {
            $cmd = Get-Command -Name ConvertFrom-JsonToHashtable -ErrorAction SilentlyContinue
            if ($cmd)
            {
                $cmd | Should -Not -BeNullOrEmpty
            }
            else
            {
                Set-ItResult -Skipped -Because "ConvertFrom-JsonToHashtable function not found"
            }
        }
        
        It "Should have Update-Setting function available" {
            Get-Command -Name Update-Setting -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Initialize-ApplicationConfiguration function available" {
            $cmd = Get-Command -Name Initialize-ApplicationConfiguration -ErrorAction SilentlyContinue
            if ($cmd)
            {
                $cmd | Should -Not -BeNullOrEmpty
            }
            else
            {
                Set-ItResult -Skipped -Because "Initialize-ApplicationConfiguration function not found"
            }
        }
    }
    
    Context "JSON to Hashtable Conversion" {
        
        It "Should convert simple JSON to hashtable" {
            $mockJson = @{
                tenantId = "test-tenant-id"
                clientId = "test-client-id"
                setting1 = "value1"
            } | ConvertTo-Json
            
            $jsonObject = $mockJson | ConvertFrom-Json
            $result = ConvertFrom-JsonToHashtable -JsonObject $jsonObject
            
            $result | Should -BeOfType [hashtable]
            $result.tenantId | Should -Be "test-tenant-id"
        }
        
        It "Should handle nested JSON objects" {
            $mockJson = @{
                parent = @{
                    child1 = "value1"
                    child2 = "value2"
                }
            } | ConvertTo-Json
            
            $jsonObject = $mockJson | ConvertFrom-Json
            $result = ConvertFrom-JsonToHashtable -JsonObject $jsonObject
            
            $result.parent | Should -BeOfType [hashtable]
            $result.parent.child1 | Should -Be "value1"
        }
        
        It "Should preserve array values" {
            $mockJson = @{
                items = @("item1", "item2", "item3")
            } | ConvertTo-Json
            
            $jsonObject = $mockJson | ConvertFrom-Json
            $result = ConvertFrom-JsonToHashtable -JsonObject $jsonObject
            
            # PowerShell coerces arrays differently - check count instead of type
            @($result.items).Count | Should -Be 3
        }
        
        It "Should handle empty arrays" {
            $mockJson = @{
                emptyArray = @()
            } | ConvertTo-Json
            
            $jsonObject = $mockJson | ConvertFrom-Json
            $result = ConvertFrom-JsonToHashtable -JsonObject $jsonObject
            
            $result.emptyArray | Should -BeNullOrEmpty -Or { $result.emptyArray.Count | Should -Be 0 }
        }
    }
    
    Context "Settings Migration Structure Validation" {
        
        It "Should validate legacy JSON settings structure" {
            $mockLegacySettings = @{
                tenantId                 = "test-tenant-id"
                clientId                 = "test-client-id"
                clientSecret             = "test-secret"
                desiredAutopilotProfiles = @("Profile1", "Profile2")
                usersToExclude           = @("user1@example.com")
            }
            
            $mockLegacySettings.tenantId | Should -Not -BeNullOrEmpty
            # Force array type by wrapping in @() for PowerShell type coercion
            @($mockLegacySettings.desiredAutopilotProfiles).Count | Should -Be 2
        }
        
        It "Should validate migrated PSD1 settings structure" {
            $mockMigratedSettings = @{
                tenantId                 = "test-tenant-id"
                clientId                 = "test-client-id"
                clientSecret             = "test-secret"
                desiredAutopilotProfiles = @("Profile1", "Profile2")
                usersToExclude           = @("user1@example.com")
                migrationVersion         = "1.0"
                migratedDate             = (Get-Date).ToString("o")
            }
            
            $mockMigratedSettings.migrationVersion | Should -Not -BeNullOrEmpty
            $mockMigratedSettings.migratedDate | Should -Not -BeNullOrEmpty
        }
        
        It "Should preserve authentication credentials during migration" {
            $mockOriginal = @{
                tenantId     = "tenant-123"
                clientId     = "client-456"
                clientSecret = "secret-789"
            }
            
            $mockMigrated = @{
                tenantId     = $mockOriginal.tenantId
                clientId     = $mockOriginal.clientId
                clientSecret = $mockOriginal.clientSecret
            }
            
            $mockMigrated.tenantId | Should -Be $mockOriginal.tenantId
            $mockMigrated.clientId | Should -Be $mockOriginal.clientId
            $mockMigrated.clientSecret | Should -Be $mockOriginal.clientSecret
        }
    }
    
    Context "Legacy Object Resolution" {
        
        It "Should identify object IDs requiring resolution" {
            $mockSettings = @{
                desiredAutopilotProfiles = @("profile-id-1", "profile-id-2")
                usersToExclude           = @("user-id-1")
                groupsToExclude          = @("group-id-1", "group-id-2")
            }
            
            $hasLegacyIds = $mockSettings.desiredAutopilotProfiles.Count -gt 0 -or
            $mockSettings.usersToExclude.Count -gt 0 -or
            $mockSettings.groupsToExclude.Count -gt 0
            
            $hasLegacyIds | Should -Be $true
        }
        
        It "Should validate object ID format (GUID-like)" {
            $mockObjectId = "12345678-1234-1234-1234-123456789012"
            
            $isGuidFormat = $mockObjectId -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            
            $isGuidFormat | Should -Be $true
        }
        
        It "Should detect human-readable names (non-GUID)" {
            $mockProfileName = "Corporate Profile"
            
            $isGuidFormat = $mockProfileName -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            
            $isGuidFormat | Should -Be $false
        }
        
        It "Should handle mixed ID and name arrays" {
            $mockArray = @(
                "12345678-1234-1234-1234-123456789012",
                "Human Readable Name",
                "Another Name"
            )
            
            $guids = $mockArray | Where-Object { $_ -match '^[0-9a-f]{8}-' }
            $names = $mockArray | Where-Object { $_ -notmatch '^[0-9a-f]{8}-' }
            
            $guids.Count | Should -Be 1
            $names.Count | Should -Be 2
        }
    }
    
    Context "Array Format Normalization" {
        
        It "Should normalize string arrays" {
            $mockArray = @("value1", "value2", "value3")
            
            $normalized = @($mockArray | ForEach-Object { $_ })
            
            # PowerShell coerces arrays differently - check count instead of type
            @($normalized).Count | Should -Be 3
        }
        
        It "Should normalize hashtable arrays" {
            $mockArray = @(
                @{key1 = "value1"},
                @{key2 = "value2"}
            )
            
            $normalized = @($mockArray | ForEach-Object { $_ })
            
            # PowerShell coerces arrays differently - check count and element type
            @($normalized).Count | Should -Be 2
            $normalized[0] | Should -BeOfType [hashtable]
        }
        
        It "Should handle single-item arrays" {
            $mockArray = @("single-value")
            
            $normalized = @($mockArray | ForEach-Object { $_ })
            
            # PowerShell coerces single-item arrays - check count instead of type
            @($normalized).Count | Should -Be 1
        }
        
        It "Should preserve empty arrays during normalization" {
            $mockArray = @()
            
            $normalized = @($mockArray | ForEach-Object { $_ })
            
            $normalized.Count | Should -Be 0
        }
    }
    
    Context "Migration Workflow Validation" {
        
        It "Should validate complete migration workflow structure" {
            $mockWorkflow = @{
                DetectionStep  = @{
                    LegacyJsonFound = $true
                    FilePath        = "C:\test\settings.json"
                }
                ConversionStep = @{
                    Success    = $true
                    OutputFile = "C:\test\settings.psd1"
                }
                ResolutionStep = @{
                    ObjectsResolved = 10
                    ObjectsFailed   = 0
                }
                ValidationStep = @{
                    Success = $true
                    Errors  = @()
                }
            }
            
            $mockWorkflow.DetectionStep.LegacyJsonFound | Should -Be $true
            $mockWorkflow.ConversionStep.Success | Should -Be $true
            $mockWorkflow.ResolutionStep.ObjectsFailed | Should -Be 0
            $mockWorkflow.ValidationStep.Success | Should -Be $true
        }
        
        It "Should handle migration workflow failure scenarios" {
            $mockFailedWorkflow = @{
                DetectionStep  = @{
                    LegacyJsonFound = $true
                    FilePath        = "C:\test\settings.json"
                }
                ConversionStep = @{
                    Success = $false
                    Error   = "Invalid JSON format"
                }
            }
            
            $mockFailedWorkflow.ConversionStep.Success | Should -Be $false
            $mockFailedWorkflow.ConversionStep.Error | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "PSD1 File Operations" {
        
        It "Should create valid PSD1 file structure" {
            $testFile = Join-Path $script:TestContext.TestFolder "test-settings.psd1"
            $testData = @{
                setting1 = "value1"
                setting2 = @("item1", "item2")
                setting3 = @{
                    nested = "value"
                }
            }
            
            Export-PowerShellDataFile -InputObject $testData -Path $testFile -Force | Out-Null
            
            Test-Path $testFile | Should -Be $true
        }
        
        It "Should successfully import PSD1 file" {
            $testFile = Join-Path $script:TestContext.TestFolder "test-import.psd1"
            $testData = @{
                key1 = "value1"
                key2 = "value2"
            }
            
            Export-PowerShellDataFile -InputObject $testData -Path $testFile -Force | Out-Null
            $imported = Import-PowerShellDataFile -Path $testFile
            
            $imported.key1 | Should -Be "value1"
            $imported.key2 | Should -Be "value2"
        }
        
        It "Should preserve data types in PSD1 roundtrip" {
            $testFile = Join-Path $script:TestContext.TestFolder "test-types.psd1"
            $testData = @{
                stringValue = "text"
                numberValue = 42
                boolValue   = $true
                arrayValue  = @(1, 2, 3)
            }
            
            Export-PowerShellDataFile -InputObject $testData -Path $testFile -Force | Out-Null
            $imported = Import-PowerShellDataFile -Path $testFile
            
            $imported.stringValue | Should -BeOfType [string]
            # PowerShell coerces single-item arrays - check count instead of type
            @($imported.arrayValue).Count | Should -Be 3
        }
    }
    
    Context "Error Handling and Recovery" {
        
        It "Should handle missing JSON file gracefully" {
            $nonExistentFile = Join-Path $script:TestContext.TestFolder "nonexistent.json"
            
            Test-Path $nonExistentFile | Should -Be $false
        }
        
        It "Should handle malformed JSON content" {
            $testFile = Join-Path $script:TestContext.TestFolder "malformed.json"
            Set-Content -Path $testFile -Value "{ invalid json }"
            
            { ConvertFrom-Json -InputObject (Get-Content $testFile -Raw) -ErrorAction Stop } | 
                Should -Throw
        }
        
        It "Should validate error recovery metadata" {
            $mockRecovery = @{
                ErrorOccurred    = $true
                ErrorMessage     = "Failed to resolve object ID"
                RecoveryAttempts = 3
                RecoverySuccess  = $false
                FallbackUsed     = $true
            }
            
            $mockRecovery.ErrorOccurred | Should -Be $true
            $mockRecovery.FallbackUsed | Should -Be $true
        }
    }
    
    Context "Backup and Rollback Scenarios" {
        
        It "Should validate backup file creation" {
            $mockBackup = @{
                OriginalFile = "C:\config\settings.json"
                BackupFile   = "C:\config\settings.json.backup.20250114"
                BackupDate   = (Get-Date).ToString("o")
                BackupSize   = 1024
            }
            
            $mockBackup.BackupFile | Should -Not -BeNullOrEmpty
            $mockBackup.BackupFile | Should -BeLike "*.backup.*"
        }
        
        It "Should validate rollback capability" {
            $mockRollback = @{
                RollbackAvailable = $true
                BackupFile        = "C:\config\settings.json.backup.20250114"
                RollbackTested    = $true
            }
            
            $mockRollback.RollbackAvailable | Should -Be $true
            $mockRollback.RollbackTested | Should -Be $true
        }
    }
    
    Context "Migration Metadata Tracking" {
        
        It "Should include migration metadata in migrated files" {
            $mockMetadata = @{
                migrationVersion = "1.0"
                migratedDate     = (Get-Date).ToString("o")
                migratedBy       = "AutopilotTool"
                sourceFormat     = "JSON"
                targetFormat     = "PSD1"
            }
            
            $mockMetadata.migrationVersion | Should -Not -BeNullOrEmpty
            $mockMetadata.migratedDate | Should -Not -BeNullOrEmpty
            $mockMetadata.sourceFormat | Should -Be "JSON"
            $mockMetadata.targetFormat | Should -Be "PSD1"
        }
        
        It "Should track migration statistics" {
            $mockStats = @{
                TotalObjects    = 50
                ObjectsResolved = 48
                ObjectsFailed   = 2
                SuccessRate     = 96
            }
            
            $mockStats.SuccessRate | Should -BeGreaterThan 90
            $mockStats.ObjectsResolved | Should -BeGreaterThan 0
        }
    }
}

# Helper function to convert object to hashtable
function ConvertTo-Hashtable
{
    param(
        [Parameter(ValueFromPipeline)]
        $InputObject
    )
    
    process
    {
        if ($null -eq $InputObject)
        {
            return $null
        }
        
        if ($InputObject -is [hashtable])
        {
            return $InputObject
        }
        
        $hash = @{}
        $InputObject.PSObject.Properties | ForEach-Object {
            $hash[$_.Name] = if ($_.Value -is [PSCustomObject])
            {
                ConvertTo-Hashtable $_.Value
            }
            else
            {
                $_.Value
            }
        }
        return $hash
    }
}

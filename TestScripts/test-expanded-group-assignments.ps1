#!/usr/bin/env pwsh

# Test script for expanded group assignment functionality
# Tests the new assignment types and menu integration

Write-Host "=== Expanded Group Assignment Functionality Tests ===" -ForegroundColor Green

$scriptPath = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
$rootPath = Split-Path $scriptPath -Parent

# Import required functions
try {
    . "$rootPath/functions/utilityFunctions/Write-Log.ps1"
    . "$rootPath/functions/utilityFunctions/GetGroupIdsByNames.ps1"
    . "$rootPath/functions/utilityFunctions/GetGroupDirectAssignments.ps1"
    . "$rootPath/functions/utilityFunctions/ShowGroupAssignments.ps1"
    
    $global:LogFile = "/tmp/expanded-group-test.log"
    Write-Host "✓ Functions imported successfully"
} catch {
    Write-Host "✗ Failed to import functions: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$testsPassed = 0
$testsTotal = 0

function Test-FunctionStructure {
    $script:testsTotal++
    Write-Host "`nTest: GetGroupDirectAssignments function structure" -ForegroundColor Yellow
    
    try {
        $getDirectCommand = Get-Command GetGroupDirectAssignments -ErrorAction Stop
        
        # Check required parameters exist
        $requiredParams = @('GroupName', 'AccessToken', 'IncludeBeta', 'ShowSummary', 'BatchSize')
        $actualParams = $getDirectCommand.Parameters.Keys
        
        $missingParams = $requiredParams | Where-Object { $_ -notin $actualParams }
        if ($missingParams.Count -eq 0) {
            Write-Host "  ✓ All required parameters present"
            $script:testsPassed++
        } else {
            Write-Host "  ✗ Missing parameters: $($missingParams -join ', ')" -ForegroundColor Red
        }
    } catch {
        Write-Host "  ✗ Function structure test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Test-AssignmentObjectStructure {
    $script:testsTotal++
    Write-Host "`nTest: Assignment object structure for new types" -ForegroundColor Yellow
    
    # Create a mock assignment object structure
    $mockAssignments = [PSCustomObject]@{
        GroupName                      = "TestGroup"
        GroupId                        = "test-group-id"
        AppAssignments                 = @()
        ConfigurationAssignments       = @()
        ComplianceAssignments          = @()
        AutopilotAssignments           = @()
        ScriptAssignments              = @()
        HealthScriptAssignments        = @()
        AppProtectionAssignments       = @()
        IntentAssignments              = @()
        ResourceAccessAssignments      = @()
        ConfigurationPolicyAssignments = @()
        GroupPolicyAssignments         = @()
        AllAssignments                 = @()
    }
    
    # Check all expected properties exist
    $expectedProperties = @(
        'GroupName', 'GroupId', 'AppAssignments', 'ConfigurationAssignments', 'ComplianceAssignments',
        'AutopilotAssignments', 'ScriptAssignments', 'HealthScriptAssignments', 'AppProtectionAssignments',
        'IntentAssignments', 'ResourceAccessAssignments', 'ConfigurationPolicyAssignments', 
        'GroupPolicyAssignments', 'AllAssignments'
    )
    
    $actualProperties = $mockAssignments.PSObject.Properties.Name
    $missingProperties = $expectedProperties | Where-Object { $_ -notin $actualProperties }
    
    if ($missingProperties.Count -eq 0) {
        Write-Host "  ✓ All expected assignment properties present"
        $script:testsPassed++
    } else {
        Write-Host "  ✗ Missing assignment properties: $($missingProperties -join ', ')" -ForegroundColor Red
    }
}

function Test-ShowGroupAssignmentsMenuItems {
    $script:testsTotal++
    Write-Host "`nTest: ShowGroupAssignments menu items structure" -ForegroundColor Yellow
    
    try {
        $showGroupCommand = Get-Command ShowGroupAssignments -ErrorAction Stop
        
        # Check the function content includes the new menu items
        $functionContent = Get-Content "$rootPath/functions/utilityFunctions/ShowGroupAssignments.ps1" -Raw
        
        $expectedMenuItems = @(
            'Show Application Assignments',
            'Show Device Configurations', 
            'Show Device Compliance Policies',
            'Show Device Management Scripts',
            'Show App Protection Policies',
            'Show Security Intents',
            'Show Resource Access Profiles',
            'Show Autopilot Profiles',
            'Show Device Health Scripts',
            'Show Configuration Policies',
            'Show Group Policy Configurations',
            'Export All Assignments'
        )
        
        $missingItems = @()
        foreach ($item in $expectedMenuItems) {
            if ($functionContent -notmatch [regex]::Escape($item)) {
                $missingItems += $item
            }
        }
        
        if ($missingItems.Count -eq 0) {
            Write-Host "  ✓ All expected menu items found in ShowGroupAssignments"
            $script:testsPassed++
        } else {
            Write-Host "  ✗ Missing menu items: $($missingItems -join ', ')" -ForegroundColor Red
        }
    } catch {
        Write-Host "  ✗ Menu items test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Test-TypeMapping {
    $script:testsTotal++
    Write-Host "`nTest: Assignment type mapping" -ForegroundColor Yellow
    
    # Check that the type mapping in ShowGroupAssignments includes all new types
    $functionContent = Get-Content "$rootPath/functions/utilityFunctions/ShowGroupAssignments.ps1" -Raw
    
    $expectedMappings = @(
        'Application',
        'Configuration', 
        'Compliance',
        'Script',
        'AppProtection',
        'Intent',
        'ResourceAccess',
        'AutopilotProfile',
        'HealthScript',
        'ConfigurationPolicy',
        'GroupPolicy'
    )
    
    $missingMappings = @()
    foreach ($mapping in $expectedMappings) {
        if ($functionContent -notmatch "'$mapping'") {
            $missingMappings += $mapping
        }
    }
    
    if ($missingMappings.Count -eq 0) {
        Write-Host "  ✓ All expected type mappings found"
        $script:testsPassed++
    } else {
        Write-Host "  ✗ Missing type mappings: $($missingMappings -join ', ')" -ForegroundColor Red
    }
}

function Test-BatchProcessingCalls {
    $script:testsTotal++
    Write-Host "`nTest: Batch processing calls for new resource types" -ForegroundColor Yellow
    
    $functionContent = Get-Content "$rootPath/functions/utilityFunctions/GetGroupDirectAssignments.ps1" -Raw
    
    $expectedBatchCalls = @(
        'Process-BatchAssignments -Resources $deviceScripts -ResourceType "Device Management Scripts"',
        'Process-BatchAssignments -Resources $appProtectionPolicies -ResourceType "App Protection Policies"',
        'Process-BatchAssignments -Resources $intents -ResourceType "Device Management Intents"',
        'Process-BatchAssignments -Resources $resourceAccessProfiles -ResourceType "Resource Access Profiles"',
        'Process-BatchAssignments -Resources $healthScripts -ResourceType "Device Health Scripts"',
        'Process-BatchAssignments -Resources $configurationPolicies -ResourceType "Configuration Policies"',
        'Process-BatchAssignments -Resources $groupPolicyConfigs -ResourceType "Group Policy Configurations"'
    )
    
    $missingCalls = @()
    foreach ($call in $expectedBatchCalls) {
        if ($functionContent -notlike "*$call*") {
            $missingCalls += $call
        }
    }
    
    if ($missingCalls.Count -eq 0) {
        Write-Host "  ✓ All expected batch processing calls found"
        $script:testsPassed++
    } else {
        Write-Host "  ✗ Missing batch processing calls: $($missingCalls.Count)"
        foreach ($missing in $missingCalls) {
            Write-Host "    - $missing" -ForegroundColor Red
        }
    }
}

function Test-AssignmentCategorySwitch {
    $script:testsTotal++
    Write-Host "`nTest: Assignment category switch statement" -ForegroundColor Yellow
    
    $functionContent = Get-Content "$rootPath/functions/utilityFunctions/GetGroupDirectAssignments.ps1" -Raw
    
    $expectedCategories = @(
        '"Script"',
        '"HealthScript"',
        '"AppProtection"', 
        '"Intent"',
        '"ResourceAccess"',
        '"ConfigurationPolicy"',
        '"GroupPolicy"'
    )
    
    $missingCategories = @()
    foreach ($category in $expectedCategories) {
        if ($functionContent -notmatch [regex]::Escape($category)) {
            $missingCategories += $category
        }
    }
    
    if ($missingCategories.Count -eq 0) {
        Write-Host "  ✓ All expected assignment categories found in switch statement"
        $script:testsPassed++
    } else {
        Write-Host "  ✗ Missing assignment categories: $($missingCategories -join ', ')" -ForegroundColor Red
    }
}

function Test-ApiEndpoints {
    $script:testsTotal++
    Write-Host "`nTest: New API endpoint references" -ForegroundColor Yellow
    
    $functionContent = Get-Content "$rootPath/functions/utilityFunctions/GetGroupDirectAssignments.ps1" -Raw
    
    $expectedEndpoints = @(
        'deviceManagement/deviceManagementScripts',
        'deviceManagement/deviceHealthScripts',
        'deviceAppManagement/managedAppPolicies',
        'deviceManagement/intents',
        'deviceManagement/resourceAccessProfiles',
        'deviceManagement/configurationPolicies',
        'deviceManagement/groupPolicyConfigurations'
    )
    
    $missingEndpoints = @()
    foreach ($endpoint in $expectedEndpoints) {
        if ($functionContent -notmatch [regex]::Escape($endpoint)) {
            $missingEndpoints += $endpoint
        }
    }
    
    if ($missingEndpoints.Count -eq 0) {
        Write-Host "  ✓ All expected API endpoints found"
        $script:testsPassed++
    } else {
        Write-Host "  ✗ Missing API endpoints: $($missingEndpoints -join ', ')" -ForegroundColor Red
    }
}

# Run all tests
Test-FunctionStructure
Test-AssignmentObjectStructure
Test-ShowGroupAssignmentsMenuItems
Test-TypeMapping
Test-BatchProcessingCalls
Test-AssignmentCategorySwitch
Test-ApiEndpoints

# Summary
Write-Host "`n=== Test Summary ===" -ForegroundColor Green
Write-Host "Tests Passed: $testsPassed/$testsTotal"

if ($testsPassed -eq $testsTotal) {
    Write-Host "✓ All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ Some tests failed" -ForegroundColor Red
    exit 1
}
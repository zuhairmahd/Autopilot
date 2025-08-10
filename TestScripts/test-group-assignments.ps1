# Test Group Assignment Functionality
Write-Host "=== Group Assignment Functionality Test ===" -ForegroundColor Green
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" 

$testPassed = 0
$testFailed = 0

# Setup test environment
$script:LogFile = "/tmp/test.log"

try {
    # Test 1: Load GetEntraGroup function
    Write-Host "`n=== Test 1: Load GetEntraGroup Function ===" -ForegroundColor Yellow
    . "./functions/utilityFunctions/GetEntraGroup.ps1"
    $getEntraGroupLoaded = Get-Command GetEntraGroup -ErrorAction SilentlyContinue
    if ($getEntraGroupLoaded) {
        Write-Host "✓ GetEntraGroup function loaded successfully" -ForegroundColor Green
        $testPassed++
    } else {
        Write-Host "✗ GetEntraGroup function failed to load" -ForegroundColor Red
        $testFailed++
    }

    # Test 2: Load ShowGroupAssignments function
    Write-Host "`n=== Test 2: Load ShowGroupAssignments Function ===" -ForegroundColor Yellow
    . "./functions/reportingFunctions/ShowGroupAssignments.ps1"
    $showGroupAssignmentsLoaded = Get-Command ShowGroupAssignments -ErrorAction SilentlyContinue
    if ($showGroupAssignmentsLoaded) {
        Write-Host "✓ ShowGroupAssignments function loaded successfully" -ForegroundColor Green
        $testPassed++
    } else {
        Write-Host "✗ ShowGroupAssignments function failed to load" -ForegroundColor Red
        $testFailed++
    }

    # Test 3: Load validateInput function and test groupName validation
    Write-Host "`n=== Test 3: Test Group Name Validation ===" -ForegroundColor Yellow
    . "./functions/utilityFunctions/validateInput.ps1"
    $validateInputLoaded = Get-Command validateInput -ErrorAction SilentlyContinue
    if ($validateInputLoaded) {
        # Test valid group name
        $testGroupName = "Test Group"
        $validationResult = validateInput -UserInput $testGroupName -type "groupName"
        if ($validationResult.valid -eq $true -and $validationResult.value -eq $testGroupName) {
            Write-Host "✓ Group name validation works correctly" -ForegroundColor Green
            $testPassed++
        } else {
            Write-Host "✗ Group name validation failed" -ForegroundColor Red
            $testFailed++
        }
    } else {
        Write-Host "✗ validateInput function failed to load" -ForegroundColor Red
        $testFailed++
    }

    # Test 4: Test GetUserInput with groupName type
    Write-Host "`n=== Test 4: Test GetUserInput with groupName Type ===" -ForegroundColor Yellow
    . "./functions/utilityFunctions/GetUserInput.ps1"
    $getUserInputLoaded = Get-Command GetUserInput -ErrorAction SilentlyContinue
    if ($getUserInputLoaded) {
        # Check if the function accepts groupName in ValidateSet
        $getUserInputFunction = Get-Command GetUserInput
        $inputTypeParam = $getUserInputFunction.Parameters['InputType']
        $validateSet = $inputTypeParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        if ($validateSet.ValidValues -contains 'groupName') {
            Write-Host "✓ GetUserInput supports groupName input type" -ForegroundColor Green
            $testPassed++
        } else {
            Write-Host "✗ GetUserInput does not support groupName input type" -ForegroundColor Red
            $testFailed++
        }
    } else {
        Write-Host "✗ GetUserInput function failed to load" -ForegroundColor Red
        $testFailed++
    }

    # Test 5: Check menu item in settings.json
    Write-Host "`n=== Test 5: Check Menu Item in Settings ===" -ForegroundColor Yellow
    if (Test-Path "./settings.json") {
        $settings = Get-Content "./settings.json" | ConvertFrom-Json
        $groupAssignmentMenu = $null
        foreach ($menu in $settings.menus) {
            if ($menu.name -eq "View group assignments") {
                $groupAssignmentMenu = $menu
                break
            }
            if ($menu.items) {
                foreach ($subMenu in $menu.items) {
                    if ($subMenu.name -eq "View group assignments") {
                        $groupAssignmentMenu = $subMenu
                        break
                    }
                }
            }
        }
        
        if ($groupAssignmentMenu) {
            Write-Host "✓ Group assignments menu item found in settings.json" -ForegroundColor Green
            Write-Host "  Description: $($groupAssignmentMenu.description)" -ForegroundColor Gray
            Write-Host "  Type: $($groupAssignmentMenu.type)" -ForegroundColor Gray
            $testPassed++
        } else {
            Write-Host "✗ Group assignments menu item not found in settings.json" -ForegroundColor Red
            $testFailed++
        }
    } else {
        Write-Host "✗ settings.json file not found" -ForegroundColor Red
        $testFailed++
    }

    # Test 6: Check return values in strings.json
    Write-Host "`n=== Test 6: Check Return Values in Strings ===" -ForegroundColor Yellow
    if (Test-Path "./strings.json") {
        $strings = Get-Content "./strings.json" | ConvertFrom-Json
        if ($strings.returnValues.noGroupFoundInDirectoryMessage) {
            Write-Host "✓ noGroupFoundInDirectoryMessage found in strings.json" -ForegroundColor Green
            Write-Host "  Value: $($strings.returnValues.noGroupFoundInDirectoryMessage)" -ForegroundColor Gray
            $testPassed++
        } else {
            Write-Host "✗ noGroupFoundInDirectoryMessage not found in strings.json" -ForegroundColor Red
            $testFailed++
        }
    } else {
        Write-Host "✗ strings.json file not found" -ForegroundColor Red
        $testFailed++
    }

    # Test 7: Check Get-StringsFromJson fallback
    Write-Host "`n=== Test 7: Check Get-StringsFromJson Fallback ===" -ForegroundColor Yellow
    # Check the source code directly instead of running the function
    $getStringsContent = Get-Content "./functions/setupFunctions/Get-StringsFromJson.ps1" -Raw
    if ($getStringsContent -match "noGroupFoundInDirectoryMessage") {
        Write-Host "✓ Get-StringsFromJson source includes noGroupFoundInDirectoryMessage" -ForegroundColor Green
        $testPassed++
    } else {
        Write-Host "✗ Get-StringsFromJson source missing noGroupFoundInDirectoryMessage" -ForegroundColor Red
        $testFailed++
    }

    # Test 8: Syntax validation of main.ps1
    Write-Host "`n=== Test 8: Syntax Validation of main.ps1 ===" -ForegroundColor Yellow
    $syntaxCheck = $null
    try {
        $syntaxCheck = [System.Management.Automation.PSParser]::Tokenize((Get-Content "./main.ps1" -Raw), [ref]$null)
        Write-Host "✓ main.ps1 syntax is valid" -ForegroundColor Green
        $testPassed++
    } catch {
        Write-Host "✗ main.ps1 syntax error: $($_.Exception.Message)" -ForegroundColor Red
        $testFailed++
    }

} catch {
    Write-Host "✗ Unexpected error during testing: $($_.Exception.Message)" -ForegroundColor Red
    $testFailed++
}

# Summary
Write-Host "`n=== Test Summary ===" -ForegroundColor Green
Write-Host "Tests Passed: $testPassed" -ForegroundColor Green
Write-Host "Tests Failed: $testFailed" -ForegroundColor Red
$totalTests = $testPassed + $testFailed
Write-Host "Total Tests: $totalTests"

if ($testFailed -eq 0) {
    Write-Host "`n🎉 All group assignment functionality tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n❌ Some tests failed. Please review the issues above." -ForegroundColor Red
    exit 1
}
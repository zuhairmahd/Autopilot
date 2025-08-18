# Test-MenuJsonExists functionality
# This test validates the new menu.json rebuild functionality

Write-Host "Testing Test-MenuJsonExists functionality" -ForegroundColor Cyan

try {
    # Test setup - dot source required functions
    . "$PSScriptRoot\..\functions\setupFunctions\FirstRunWizardFunctions\Test-MenuJsonExists.ps1"
    . "$PSScriptRoot\..\functions\setupFunctions\FirstRunWizardFunctions\ConvertTo-OrderedJson.ps1"
    . "$PSScriptRoot\..\functions\setupFunctions\FirstRunWizardFunctions\ConvertFrom-JsonToHashtable.ps1"
    . "$PSScriptRoot\..\functions\setupFunctions\FirstRunWizardFunctions\Merge-ConfigurationDefaults.ps1"
    . "$PSScriptRoot\..\functions\utilityFunctions\Write-Log.ps1"
    
    # Set up global variables
    $global:maxJSONDepth = 100
    $global:version = @{version = "1.0.0.0"}
    $global:LogFile = "/tmp/test_menu_log.txt"
    
    # Create a simple log file to satisfy the Write-Log function
    "Test Log File" | Set-Content $global:LogFile
    
    $testsPassed = 0
    $testsTotal = 4
    
    # Test 1: Create new menu.json when file doesn't exist
    Write-Host "Test 1: Creating new menu.json when file doesn't exist" -ForegroundColor Yellow
    $testFile1 = "/tmp/test_menu_new.json"
    if (Test-Path $testFile1) { Remove-Item $testFile1 -Force }
    
    $result1 = Test-MenuJsonExists -MenuFile $testFile1 -Silent
    if ($result1 -and (Test-Path $testFile1)) {
        $content1 = Get-Content $testFile1 -Raw | ConvertFrom-Json
        if ($content1.name -eq "menu.json" -and $content1.mainMenu -and $content1.appModeHierarchy) {
            Write-Host "✓ Test 1 PASSED: New menu.json created successfully with correct structure" -ForegroundColor Green
            $testsPassed++
        } else {
            Write-Host "✗ Test 1 FAILED: Menu structure is incorrect" -ForegroundColor Red
        }
    } else {
        Write-Host "✗ Test 1 FAILED: File creation failed" -ForegroundColor Red
    }
    
    # Test 2: Update existing menu.json with missing defaults
    Write-Host "Test 2: Updating existing menu.json with missing configurations" -ForegroundColor Yellow
    $testFile2 = "/tmp/test_menu_update.json"
    
    # Create a minimal menu.json
    $minimalMenu = @{
        name = "menu.json"
        description = "Test menu file"
        version = "1.0.0.0"
        mainMenu = @{
            Title = "Existing Main Menu"
            Description = "Existing description"
            type = "static"
            items = @()
        }
    }
    $minimalMenu | ConvertTo-Json -Depth 10 | Set-Content $testFile2 -Encoding UTF8
    
    $result2 = Test-MenuJsonExists -MenuFile $testFile2 -Silent
    if ($result2) {
        $content2 = Get-Content $testFile2 -Raw | ConvertFrom-Json
        if ($content2.appModeHierarchy -and $content2.appModeDefaults -and $content2.mainMenu.Title -eq "Existing Main Menu") {
            Write-Host "✓ Test 2 PASSED: Existing menu updated with missing defaults while preserving existing content" -ForegroundColor Green
            $testsPassed++
        } else {
            Write-Host "✗ Test 2 FAILED: Update did not work correctly" -ForegroundColor Red
        }
    } else {
        Write-Host "✗ Test 2 FAILED: Update function returned false" -ForegroundColor Red
    }
    
    # Test 3: Verify all expected menu configurations are present
    Write-Host "Test 3: Verifying all expected menu configurations are present" -ForegroundColor Yellow
    $expectedMenus = @("mainMenu", "checkMenu", "serialNumberMenu", "autopilotMenu", "settingsMenu", "environmentMenu", "exportMenu", "deviceWaitMenu", "deviceMenu", "deviceActionsMenu")
    $content3 = Get-Content $testFile1 -Raw | ConvertFrom-Json
    $foundMenus = 0
    
    foreach ($menuName in $expectedMenus) {
        if ($content3.$menuName) {
            $foundMenus++
        }
    }
    
    if ($foundMenus -eq $expectedMenus.Count) {
        Write-Host "✓ Test 3 PASSED: All $($expectedMenus.Count) expected menus found" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "✗ Test 3 FAILED: Only $foundMenus out of $($expectedMenus.Count) expected menus found" -ForegroundColor Red
    }
    
    # Test 4: Verify app mode hierarchy structure
    Write-Host "Test 4: Verifying app mode hierarchy structure" -ForegroundColor Yellow
    $hierarchy = $content3.appModeHierarchy
    $expectedModes = @("full", "admin", "advanced", "helpdesk", "registration", "advancedRegistration", "custom")
    $foundModes = 0
    $missingModes = @()
    
    foreach ($mode in $expectedModes) {
        if ($null -ne $hierarchy.$mode) {
            $foundModes++
        } else {
            $missingModes += $mode
        }
    }
    
    if ($foundModes -eq $expectedModes.Count -and $hierarchy.full -contains "*" -and $hierarchy.admin -contains "advanced") {
        Write-Host "✓ Test 4 PASSED: App mode hierarchy structure is correct" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "✗ Test 4 FAILED: App mode hierarchy structure is incorrect" -ForegroundColor Red
        Write-Host "Debug: Found modes: $foundModes/$($expectedModes.Count), Missing modes: $($missingModes -join ', ')" -ForegroundColor Red
        Write-Host "Full contains '*': $($hierarchy.full -contains '*'), Admin contains 'advanced': $($hierarchy.admin -contains 'advanced')" -ForegroundColor Red
        Write-Host "Hierarchy properties: $($hierarchy.PSObject.Properties.Name -join ', ')" -ForegroundColor Red
    }
    
    # Clean up test files
    if (Test-Path $testFile1) { Remove-Item $testFile1 -Force }
    if (Test-Path $testFile2) { Remove-Item $testFile2 -Force }
    if (Test-Path $global:LogFile) { Remove-Item $global:LogFile -Force }
    
    # Report results
    Write-Host "`nTest Results:" -ForegroundColor Cyan
    Write-Host "Passed: $testsPassed/$testsTotal" -ForegroundColor $(if ($testsPassed -eq $testsTotal) { "Green" } else { "Yellow" })
    
    if ($testsPassed -eq $testsTotal) {
        Write-Host "✓ All Test-MenuJsonExists tests PASSED" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "✗ Some Test-MenuJsonExists tests FAILED" -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host "✗ Test execution failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}
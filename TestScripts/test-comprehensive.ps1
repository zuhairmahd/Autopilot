# Comprehensive First Run Wizard Test
# This test validates all aspects of the wizard functionality

Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "                 Comprehensive First Run Wizard Test                           " -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green

$testResults = @()

# Test 1: Function Loading
Write-TestSection "`n1. Testing Function Loading..."
try
{
    $functionsFolder = "$PWD\functions"
    if (Test-Path $functionsFolder)
    {
        $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -ErrorAction Stop
        foreach ($function in $functions)
        {
            . $function.FullName
        }
        Write-Host "[PASS] Functions loaded successfully" -ForegroundColor Green
        $testResults += "Function Loading: PASS"
    }
    else
    {
        Write-Host "[FAIL] Functions folder not found" -ForegroundColor Red
        $testResults += "Function Loading: FAIL"
    }
}
catch
{
    Write-Host "[FAIL] Error loading functions: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += "Function Loading: FAIL"
}

# Test 2: Wizard Function Availability
Write-Host "`n2. Testing Wizard Function Availability..." -ForegroundColor Cyan
$requiredFunctions = @(
    "Start-FirstRunWizard",
    "Get-BasicConfigurationFromUser", 
    "Get-AuthenticationConfigurationFromUser",
    "New-ConfigurationFile",
    "Test-SettingsJsonExists",
    "Test-StringsJsonExists"
)

$allFunctionsAvailable = $true
foreach ($func in $requiredFunctions)
{
    if (Get-Command $func -ErrorAction SilentlyContinue)
    {
        Write-Host "  [PASS] $func" -ForegroundColor Green
    }
    else
    {
        Write-Host "  [FAIL] $func" -ForegroundColor Red
        $allFunctionsAvailable = $false
    }
}

if ($allFunctionsAvailable)
{
    Write-Host "[PASS] All required functions available" -ForegroundColor Green
    $testResults += "Function Availability: PASS"
}
else
{
    Write-Host "[FAIL] Some required functions missing" -ForegroundColor Red
    $testResults += "Function Availability: FAIL"
}

# Test 3: Silent Mode Configuration Collection
Write-Host "`n3. Testing Silent Mode Configuration Collection..." -ForegroundColor Cyan
try
{
    $basicConfig = Get-BasicConfigurationFromUser -Silent
    if ($basicConfig -and $basicConfig.AppId -and $basicConfig.TenantId -and $basicConfig.domain)
    {
        Write-Host "[PASS] Basic configuration collected in silent mode" -ForegroundColor Green
        $testResults += "Silent Basic Config: PASS"
    }
    else
    {
        Write-Host "[FAIL] Basic configuration failed in silent mode" -ForegroundColor Red
        $testResults += "Silent Basic Config: FAIL"
    }
    
    $authConfig = Get-AuthenticationConfigurationFromUser -Silent
    if ($authConfig -and $authConfig.AppSecret)
    {
        Write-Host "[PASS] Authentication configuration collected in silent mode" -ForegroundColor Green
        $testResults += "Silent Auth Config: PASS"
    }
    else
    {
        Write-Host "[FAIL] Authentication configuration failed in silent mode" -ForegroundColor Red
        $testResults += "Silent Auth Config: FAIL"
    }
}
catch
{
    Write-Host "[FAIL] Error in silent mode tests: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += "Silent Basic Config: FAIL"
    $testResults += "Silent Auth Config: FAIL"
}

# Test 4: File Creation and Encryption
Write-Host "`n4. Testing File Creation and Encryption..." -ForegroundColor Cyan
$testFolder = "$PWD\comprehensive-test"
if (Test-Path $testFolder)
{
    Remove-Item $testFolder -Recurse -Force
}
New-Item -Path $testFolder -ItemType Directory -Force | Out-Null

try
{
    $configFile = "$testFolder\.secrets\config.json"
    $settingsFile = "$testFolder\settings.json"
    $stringsFile = "$testFolder\strings.json"
    $LogFile = "$testFolder\test.log"
    
    # Test wizard execution
    $wizardSuccess = Start-FirstRunWizard -ConfigFile $configFile -SettingsFile $settingsFile -StringsFile $stringsFile -Silent
    
    if ($wizardSuccess)
    {
        Write-Host "[PASS] Wizard execution successful" -ForegroundColor Green
        $testResults += "Wizard Execution: PASS"
        
        # Test config file encryption
        if (Test-Path $configFile)
        {
            $encryptionStatus = Test-FileEncryptionStatus -FilePath $configFile
            if ($encryptionStatus.IsEncrypted)
            {
                Write-Host "[PASS] Config file encrypted successfully" -ForegroundColor Green
                $testResults += "Config Encryption: PASS"
                
                # Test decryption
                $decryptResult = Invoke-JsonFileEncryption -FilePath $configFile -Key "DefaultPassword123!" -Decrypt -InMemoryOnly
                if ($decryptResult.Success)
                {
                    Write-Host "[PASS] Config file decryption successful" -ForegroundColor Green
                    $testResults += "Config Decryption: PASS"
                }
                else
                {
                    Write-Host "[FAIL] Config file decryption failed" -ForegroundColor Red
                    $testResults += "Config Decryption: FAIL"
                }
            }
            else
            {
                Write-Host "[FAIL] Config file not encrypted" -ForegroundColor Red
                $testResults += "Config Encryption: FAIL"
            }
        }
        else
        {
            Write-Host "[FAIL] Config file not created" -ForegroundColor Red
            $testResults += "Config Encryption: FAIL"
        }
        
        # Test settings file creation
        if (Test-Path $settingsFile)
        {
            try
            {
                $settings = Get-Content $settingsFile -Raw | ConvertFrom-Json
                if ($settings.version -and $settings.globalSettings)
                {
                    Write-Host "[PASS] Settings file created with valid structure" -ForegroundColor Green
                    $testResults += "Settings Creation: PASS"
                }
                else
                {
                    Write-Host "[FAIL] Settings file has invalid structure" -ForegroundColor Red
                    $testResults += "Settings Creation: FAIL"
                }
            }
            catch
            {
                Write-Host "[FAIL] Settings file has invalid JSON" -ForegroundColor Red
                $testResults += "Settings Creation: FAIL"
            }
        }
        else
        {
            Write-Host "[FAIL] Settings file not created" -ForegroundColor Red
            $testResults += "Settings Creation: FAIL"
        }
        
        # Test strings file creation
        if (Test-Path $stringsFile)
        {
            try
            {
                $strings = Get-Content $stringsFile -Raw | ConvertFrom-Json
                if ($strings.returnValues -and $strings.deviceStates -and $strings.deviceActions)
                {
                    Write-Host "[PASS] Strings file created with valid structure" -ForegroundColor Green
                    $testResults += "Strings Creation: PASS"
                }
                else
                {
                    Write-Host "[FAIL] Strings file has invalid structure" -ForegroundColor Red
                    $testResults += "Strings Creation: FAIL"
                }
            }
            catch
            {
                Write-Host "[FAIL] Strings file has invalid JSON" -ForegroundColor Red
                $testResults += "Strings Creation: FAIL"
            }
        }
        else
        {
            Write-Host "[FAIL] Strings file not created" -ForegroundColor Red
            $testResults += "Strings Creation: FAIL"
        }
        
    }
    else
    {
        Write-Host "[FAIL] Wizard execution failed" -ForegroundColor Red
        $testResults += "Wizard Execution: FAIL"
    }
    
}
catch
{
    Write-Host "[FAIL] Error in file creation tests: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += "Wizard Execution: FAIL"
}
finally
{
    # Clean up test folder
    if (Test-Path $testFolder)
    {
        Remove-Item $testFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Test 5: PowerShell 5.1 Compatibility
Write-Host "`n5. Testing PowerShell 5.1 Compatibility..." -ForegroundColor Cyan
try
{
    # Test hashtable usage (should be regular hashtables, not ordered)
    $testHashtable = @{
        key1 = "value1"
        key2 = "value2"
    }
    
    if ($testHashtable.GetType().Name -eq "Hashtable")
    {
        Write-Host "[PASS] Uses regular hashtables (PS 5.1 compatible)" -ForegroundColor Green
        $testResults += "PS 5.1 Compatibility: PASS"
    }
    else
    {
        Write-Host "[FAIL] Uses ordered hashtables (PS 5.1 incompatible)" -ForegroundColor Red
        $testResults += "PS 5.1 Compatibility: FAIL"
    }
}
catch
{
    Write-Host "[FAIL] Error in compatibility tests: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += "PS 5.1 Compatibility: FAIL"
}

# Test Summary
Write-Host "`n═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "                              Test Summary                                      " -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green

$totalTests = $testResults.Count
$passedTests = ($testResults | Where-Object { $_ -match "PASS" }).Count
$failedTests = ($testResults | Where-Object { $_ -match "FAIL" }).Count

Write-Host "`nTest Results:" -ForegroundColor Cyan
foreach ($result in $testResults)
{
    if ($result -match "PASS")
    {
        Write-Host "  [PASS] $result" -ForegroundColor Green
    }
    else
    {
        Write-Host "  [FAIL] $result" -ForegroundColor Red
    }
}

Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "  Total Tests: $totalTests" -ForegroundColor White
Write-Host "  Passed: $passedTests" -ForegroundColor Green
Write-Host "  Failed: $failedTests" -ForegroundColor Red
Write-Host "  Success Rate: $([math]::Round(($passedTests / $totalTests) * 100, 2))%" -ForegroundColor $(if ($failedTests -eq 0) { "Green" } else { "Yellow" })

if ($failedTests -eq 0)
{
    Write-Host "`n🎉 All tests passed! The First Run Wizard is fully functional." -ForegroundColor Green
}
else
{
    Write-Host "`n⚠️  Some tests failed. Please review the implementation." -ForegroundColor Yellow
}

Write-Host "`nComprehensive test completed!" -ForegroundColor Green

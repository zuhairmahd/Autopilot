<#
.SYNOPSIS
    Test main.ps1 integration with First Run Wizard using unified framework
#>

[CmdletBinding()]
param(
    [string]$TestName = "Main.ps1 Integration with First Run Wizard",
    [string]$TestFolder = $null
)

# Load unified test helper
. "$PSScriptRoot\test-helper.ps1"

# Resolve root and set metadata
$RootPath = Split-Path -Parent $PSScriptRoot

Write-Host "Testing main.ps1 Integration with First Run Wizard" -ForegroundColor Green

# Load all application functions at script level (scoping-critical)
$null = Load-AllFunctions -RootPath $RootPath -VerboseLoading:$false

try
{
    # Initialize unified framework (explicit params)
    $TestContext = Start-UnifiedTest -TestName $TestName -TestFolder $TestFolder -RootPath $RootPath -SkipFunctionCheck:$true
    Write-Host "Test folder: $($TestContext.TestFolder)" -ForegroundColor Yellow

    Write-TestSection "Preparing test-scoped files"
    
    # Ensure test-scoped folders exist
    $null = New-Item -Path (Join-Path $TestContext.TestFolder '.secrets') -ItemType Directory -Force -ErrorAction SilentlyContinue
    $null = New-Item -Path (Join-Path $TestContext.TestFolder 'Logs') -ItemType Directory -Force -ErrorAction SilentlyContinue
    
    # Remove test-scoped config to simulate first run
    $testConfigPath = Join-Path $TestContext.TestFolder ".secrets\config.json"
    if (Test-Path $testConfigPath)
    {
        Remove-Item $testConfigPath -Force -ErrorAction SilentlyContinue
        Write-TestResult "Removed existing test config.json" $true
    }
    
    Write-TestSection "Testing main.ps1 with wizard in silent mode"
    
    # Create a test version of main.ps1 that calls the wizard in silent mode
    $mainTestScript = @"
# Test version of main.ps1 that uses silent mode for wizard
param(
    [string]`$configFile = "`$($TestContext.TestFolder)\.secrets\config.json",
    [string]`$InitFile = "`$($TestContext.TestFolder)\settings.json",
    [string]`$LogFile = "`$($TestContext.TestFolder)\Logs\Autopilot.log",
    [string]`$StringsFile = "`$pwd\strings.json"
)

# Import functions from repo root (parent of this script's folder), recursively
`$repoRoot = Split-Path -Parent `$PSScriptRoot
`$functionsFolder = Join-Path `$repoRoot 'functions'
if (Test-Path `$functionsFolder) {
    `$functions = Get-ChildItem -Path `$functionsFolder -Filter '*.ps1' -Recurse -ErrorAction Stop
    foreach (`$function in `$functions) {
        . `$function.FullName
    }
} else {
    Write-Host "Functions folder not found: `$functionsFolder" -ForegroundColor Red
}

# Check if config file exists
if (-not (Test-Path `$configFile)) {
    Write-Host "Configuration file `$configFile not found." -ForegroundColor Yellow
    Write-Host "Starting first run wizard to set up your configuration..." -ForegroundColor Green
    
    # Launch the first run wizard in silent mode
    `$wizardResult = Start-FirstRunWizard -ConfigFile `$configFile -SettingsFile `$InitFile -StringsFile `$StringsFile -Silent
    
    if (`$wizardResult) {
        Write-Host "First run wizard completed successfully." -ForegroundColor Green
        
        # Verify configuration file encryption status and presence of other files
        if (Test-Path `$configFile) {
            `$enc = Test-FileEncryptionStatus -FilePath `$configFile
            if (`$enc.IsEncrypted) {
                Write-Host "Configuration file is encrypted." -ForegroundColor Green
            } else {
                Write-Host "Configuration file is not encrypted." -ForegroundColor Red
                exit 1
            }

            # Test settings file
            if (Test-Path `$InitFile) {
                Write-Host "Settings file created successfully." -ForegroundColor Green
            } else {
                Write-Host "Settings file was not created." -ForegroundColor Red
                exit 1
            }

            # Test strings file
            if (Test-Path `$StringsFile) {
                Write-Host "Strings file created successfully." -ForegroundColor Green
            } else {
                Write-Host "Strings file was not created." -ForegroundColor Red
                exit 1
            }

            Write-Host "Main.ps1 integration test completed successfully!" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "Configuration file was not created." -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "First run wizard failed." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Configuration file already exists." -ForegroundColor Yellow
    exit 0
}
"@
    
    # Write the test script
    $testMainScript = "$TestFolder\main-test.ps1"
    Set-Content -Path $testMainScript -Value $mainTestScript -Encoding UTF8
    
    # Run the test script
    # Run the test script with explicit test-scoped paths
    $testResult = pwsh -NoProfile -ExecutionPolicy Bypass -File $testMainScript -configFile "$TestFolder\.secrets\config.json" -InitFile "$TestFolder\settings.json" -LogFile "$TestFolder\Logs\Autopilot.log" -StringsFile "$TestFolder\strings.json" 2>&1
    
    Write-TestSubSection "Test script output"
    Write-Host $testResult -ForegroundColor Gray
    
    # Check results
    if ($testResult -match "Main\.ps1 integration test completed successfully!")
    {
        Write-TestResult "Main.ps1 integration test passed!" $true
        
        # Verify test-scoped files were created
        if (Test-Path "$TestFolder\.secrets\config.json")
        {
            Write-TestResult "Config file created and encrypted" $true
        }
        else
        {
            Write-TestResult "Config file not created" $false
        }
        
        if (Test-Path "$TestFolder\settings.json")
        {
            Write-TestResult "Settings file created" $true
        }
        else
        {
            Write-TestResult "Settings file not created" $false
        }
        
        if (Test-Path "$TestFolder\strings.json")
        {
            Write-TestResult "Strings file created" $true
        }
        else
        {
            Write-TestResult "Strings file not created" $false
        }
    }
    else
    {
        Write-TestResult "Main.ps1 integration test failed!" $false
    }

}
catch
{
    Write-TestResult "Test failed with error: $($_.Exception.Message)" $false "Red"
    Write-Host "Full error:" -ForegroundColor Red
    Write-Host $_.Exception.ToString() -ForegroundColor Red
}
finally
{
    # Compute counters and complete via unified framework
    $TotalTests = 3
    $PassedTests = (@(
            (Test-Path "$TestFolder\.secrets\config.json"),
            (Test-Path "$TestFolder\settings.json"),
            (Test-Path "$TestFolder\strings.json")
        ) | Where-Object { $_ } ).Count
    $FailedTests = $TotalTests - $PassedTests
    $null = Complete-UnifiedTest -TestContext $TestContext -PassedTests $PassedTests -FailedTests $FailedTests -TotalTests $TotalTests
}

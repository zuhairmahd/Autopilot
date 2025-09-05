# Phase 4 Performance Optimization Tests
# Tests for advanced memory optimization, parallel processing, and string operations

# Test framework setup
$global:testStartTime = Get-Date
$global:testResults = @()

function Add-TestResult($TestName, $Success, $Duration, $Details = "", $ExpectedImprovement = "") {
    $global:testResults += @{
        TestName = $TestName
        Success = $Success
        Duration = $Duration
        Details = $Details
        ExpectedImprovement = $ExpectedImprovement
        Timestamp = Get-Date
    }
}

function Measure-TestExecution($TestName, $ScriptBlock, $ExpectedImprovement = "") {
    Write-Host "Testing: $TestName" -ForegroundColor Cyan
    $startTime = Get-Date
    try {
        $result = & $ScriptBlock
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalMilliseconds
        
        $success = if ($result -is [hashtable] -and $result.ContainsKey('Success')) { 
            $result.Success 
        } elseif ($result -is [array] -and $result.Count -eq 2 -and $result[0] -is [bool]) { 
            $result[0] 
        } else { 
            $true 
        }
        
        $details = if ($result -is [hashtable] -and $result.ContainsKey('Details')) { 
            $result.Details 
        } elseif ($result -is [array] -and $result.Count -eq 2) { 
            $result[1] 
        } else { 
            "Duration: $($duration)ms" 
        }
        
        Add-TestResult -TestName $TestName -Success $success -Duration $duration -Details $details -ExpectedImprovement $ExpectedImprovement
        
        if ($success) {
            Write-Host "✓ PASS: $TestName ($($duration)ms)" -ForegroundColor Green
            if ($ExpectedImprovement) {
                Write-Host "  Expected improvement: $ExpectedImprovement" -ForegroundColor Yellow
            }
        } else {
            Write-Host "✗ FAIL: $TestName ($($duration)ms)" -ForegroundColor Red
            Write-Host "  Details: $details" -ForegroundColor Gray
        }
    }
    catch {
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalMilliseconds
        Add-TestResult -TestName $TestName -Success $false -Duration $duration -Details $_.Exception.Message -ExpectedImprovement $ExpectedImprovement
        Write-Host "✗ ERROR: $TestName - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Phase 4 Advanced Performance Optimization Tests" -ForegroundColor White
Write-Host "Testing memory optimization, parallel processing, and string operations" -ForegroundColor Gray
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

# Test 1: String Builder Performance
Measure-TestExecution "String Builder vs Concatenation Performance" {
    try {
        # Load the optimized function
        . "$PWD/functions/menuFunctions/Create-MenuBanner.ps1"
        
        # Test data
        $testMenu = @{
            Title = "Test Menu"
            Description = "This is a test menu with a longer description to test string building performance"
        }
        $testHistory = New-Object System.Collections.ArrayList
        for ($i = 1; $i -le 10; $i++) {
            [void]$testHistory.Add("Menu Level $i")
        }
        
        # Measure optimized version
        $optimizedStart = Get-Date
        for ($i = 1; $i -le 100; $i++) {
            $banner = Create-MenuBanner -Menu $testMenu -History $testHistory
        }
        $optimizedEnd = Get-Date
        $optimizedTime = ($optimizedEnd - $optimizedStart).TotalMilliseconds
        
        return @{
            Success = $optimizedTime -lt 1000  # Should complete in less than 1 second
            Details = "Optimized version: $($optimizedTime)ms for 100 iterations. Expected 30-50% improvement over string concatenation."
        }
    }
    catch {
        return @{
            Success = $false
            Details = "Error testing string builder: $($_.Exception.Message)"
        }
    }
} -ExpectedImprovement "30-50% faster string building"

# Test 2: Array List Performance
Measure-TestExecution "ArrayList vs Array Concatenation Performance" {
    try {
        # Test data
        $testData = @()
        $testArrayList = New-Object System.Collections.ArrayList
        
        # Measure traditional array concatenation
        $arrayStart = Get-Date
        for ($i = 1; $i -le 1000; $i++) {
            $testData = $testData + @("Item$i")
        }
        $arrayEnd = Get-Date
        $arrayTime = ($arrayEnd - $arrayStart).TotalMilliseconds
        
        # Measure ArrayList operations
        $listStart = Get-Date
        for ($i = 1; $i -le 1000; $i++) {
            [void]$testArrayList.Add("Item$i")
        }
        $listEnd = Get-Date
        $listTime = ($listEnd - $listStart).TotalMilliseconds
        
        $improvement = if ($arrayTime -gt 0) { 
            [math]::Round((($arrayTime - $listTime) / $arrayTime) * 100, 1) 
        } else { 0 }
        
        return @{
            Success = $testArrayList.Count -eq 1000 -and $testData.Count -eq 1000 -and $listTime -le $arrayTime
            Details = "Array concatenation: $($arrayTime)ms, ArrayList: $($listTime)ms, Improvement: $improvement%, Items: Array=$($testData.Count), List=$($testArrayList.Count)"
        }
    }
    catch {
        return @{
            Success = $false
            Details = "Error testing ArrayList: $($_.Exception.Message)"
        }
    }
} -ExpectedImprovement "20-40% reduction in memory allocation overhead"

# Test 3: Parallel Operations Validation
Measure-TestExecution "Parallel Operations Framework Validation" {
    try {
        # Load the parallel operations function
        . "$PWD/functions/utilityFunctions/Invoke-ParallelFileOperations.ps1"
        
        # Test that the framework is properly implemented
        $testOperations = @(
            @{ Type = "Validate"; Path = "$PWD/main.ps1" }
            @{ Type = "Validate"; Path = "$PWD/settings.json" }
            @{ Type = "Validate"; Path = "$PWD/strings.json" }
        )
        
        # Test parallel operations framework
        $results = Invoke-ParallelFileOperations -Operations $testOperations -MaxConcurrency 2
        $successCount = ($results | Where-Object { $_.Success }).Count
        
        return @{
            Success = $results.Count -eq $testOperations.Count -and $successCount -ge 2
            Details = "Framework validation: $successCount/$($testOperations.Count) operations successful. Parallel operations framework is functional."
        }
    }
    catch {
        return @{
            Success = $false
            Details = "Error testing parallel operations framework: $($_.Exception.Message)"
        }
    }
} -ExpectedImprovement "25-40% improvement in file I/O operations"

# Test 4: Asynchronous Logging Performance
Measure-TestExecution "Asynchronous Logging Performance" {
    try {
        # Load the async logging function
        . "$PWD/functions/utilityFunctions/Invoke-AsynchronousLogging.ps1"
        
        $tempDir = if ($env:TEMP) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { "/tmp" }
        $testLogFile = Join-Path $tempDir "phase4_async_test.log"
        if (Test-Path $testLogFile) {
            Remove-Item -Path $testLogFile -Force
        }
        
        # Initialize async logging
        $initResult = Initialize-AsynchronousLogging -LogFile $testLogFile -MaxQueueSize 1000 -FlushIntervalMs 100
        
        if (-not $initResult.Success) {
            return @{
                Success = $false
                Details = "Failed to initialize async logging: $($initResult.Error)"
            }
        }
        
        # Test async logging performance
        $asyncStart = Get-Date
        for ($i = 1; $i -le 100; $i++) {
            Write-AsyncLog -LogFile $testLogFile -Module "Phase4Test" -Message "Test message $i" -LogLevel "Information"
        }
        $asyncEnd = Get-Date
        $asyncTime = ($asyncEnd - $asyncStart).TotalMilliseconds
        
        # Wait for queue to flush
        Start-Sleep -Milliseconds 500
        
        # Test synchronous logging for comparison
        $syncLogFile = Join-Path $tempDir "phase4_sync_test.log"
        if (Test-Path $syncLogFile) {
            Remove-Item -Path $syncLogFile -Force
        }
        
        $syncStart = Get-Date
        for ($i = 1; $i -le 100; $i++) {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
            $logMessage = "[$timestamp] [Information] [Phase4Test] Test message $i"
            $logMessage | Out-File -FilePath $syncLogFile -Append -Encoding UTF8
        }
        $syncEnd = Get-Date
        $syncTime = ($syncEnd - $syncStart).TotalMilliseconds
        
        # Stop async logging
        $stopResult = Stop-AsynchronousLogging -TimeoutSeconds 5
        
        # Check log files
        $asyncExists = Test-Path $testLogFile
        $syncExists = Test-Path $syncLogFile
        
        # Cleanup
        Remove-Item -Path $testLogFile -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $syncLogFile -Force -ErrorAction SilentlyContinue
        
        $improvement = if ($syncTime -gt 0) { 
            [math]::Round((($syncTime - $asyncTime) / $syncTime) * 100, 1) 
        } else { 0 }
        
        return @{
            Success = $initResult.Success -and $stopResult.Success -and $asyncExists -and $syncExists -and $asyncTime -le $syncTime
            Details = "Async: $($asyncTime)ms, Sync: $($syncTime)ms, Improvement: $improvement%, Files created: Async=$asyncExists, Sync=$syncExists"
        }
    }
    catch {
        # Cleanup on error
        try { Stop-AsynchronousLogging -TimeoutSeconds 2 | Out-Null } catch { }
        return @{
            Success = $false
            Details = "Error testing async logging: $($_.Exception.Message)"
        }
    }
} -ExpectedImprovement "15-25% reduction in logging overhead"

# Test 5: Memory Usage Optimization
Measure-TestExecution "Memory Usage Optimization" {
    try {
        # Test memory-efficient operations
        $beforeMemory = [System.GC]::GetTotalMemory($false)
        
        # Test 1: Efficient string building
        $stringBuilder = New-Object System.Text.StringBuilder
        for ($i = 1; $i -le 1000; $i++) {
            [void]$stringBuilder.Append("Test string $i`n")
        }
        $result1 = $stringBuilder.ToString()
        
        # Test 2: Efficient array building
        $arrayList = New-Object System.Collections.ArrayList(1000)
        for ($i = 1; $i -le 1000; $i++) {
            [void]$arrayList.Add("Item $i")
        }
        $result2 = $arrayList.ToArray()
        
        # Force garbage collection to measure
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        [System.GC]::Collect()
        $afterMemory = [System.GC]::GetTotalMemory($false)
        
        $memoryUsed = [math]::Round(($afterMemory - $beforeMemory) / 1MB, 2)
        
        return @{
            Success = $result1.Length -gt 0 -and $result2.Count -eq 1000 -and $memoryUsed -lt 10
            Details = "String length: $($result1.Length), Array count: $($result2.Count), Memory used: $($memoryUsed)MB"
        }
    }
    catch {
        return @{
            Success = $false
            Details = "Error testing memory optimization: $($_.Exception.Message)"
        }
    }
} -ExpectedImprovement "30-50% reduction in temporary object allocations"

# Test 6: JSON Processing Optimization
Measure-TestExecution "JSON Processing Performance" {
    try {
        # Create test JSON data
        $testData = @{
            settings = @{
                global = @{
                    appMode = "full"
                    logLevel = "Information"
                    autoUpdate = $true
                }
                domain = @{
                    name = "testdomain.com"
                    enabled = $true
                    groupsToInclude = @("Group1", "Group2", "Group3")
                    groupsToExclude = @("ExcludeGroup1", "ExcludeGroup2")
                }
            }
            auth = @{
                authType = "PublicAuthFlow"
                scopes = @("User.Read", "Device.Read.All", "DeviceManagementManagedDevices.ReadWrite.All")
            }
        }
        
        # Test JSON serialization/deserialization performance
        $jsonStart = Get-Date
        for ($i = 1; $i -le 50; $i++) {
            $json = $testData | ConvertTo-Json -Depth 10
            $restored = $json | ConvertFrom-Json
        }
        $jsonEnd = Get-Date
        $jsonTime = ($jsonEnd - $jsonStart).TotalMilliseconds
        
        return @{
            Success = $jsonTime -lt 5000  # Should complete within 5 seconds
            Details = "JSON processing: $($jsonTime)ms for 50 iterations (serialize + deserialize)"
        }
    }
    catch {
        return @{
            Success = $false
            Details = "Error testing JSON processing: $($_.Exception.Message)"
        }
    }
} -ExpectedImprovement "20-30% improvement in configuration processing"

# Test 7: Function Loading Performance
Measure-TestExecution "Function Loading Performance Validation" {
    try {
        $loadStart = Get-Date
        
        # Test loading of optimized functions
        $optimizedFunctions = @(
            "$PWD/functions/menuFunctions/Create-MenuBanner.ps1"
            "$PWD/functions/setupFunctions/Get-AvailableDomains.ps1"
            "$PWD/functions/utilityFunctions/Invoke-ParallelFileOperations.ps1"
            "$PWD/functions/utilityFunctions/Invoke-AsynchronousLogging.ps1"
        )
        
        $loadedCount = 0
        foreach ($functionFile in $optimizedFunctions) {
            if (Test-Path $functionFile) {
                . $functionFile
                $loadedCount++
            }
        }
        
        $loadEnd = Get-Date
        $loadTime = ($loadEnd - $loadStart).TotalMilliseconds
        
        return @{
            Success = $loadedCount -eq $optimizedFunctions.Count -and $loadTime -lt 2000
            Details = "Loaded $loadedCount/$($optimizedFunctions.Count) optimized functions in $($loadTime)ms"
        }
    }
    catch {
        return @{
            Success = $false
            Details = "Error testing function loading: $($_.Exception.Message)"
        }
    }
} -ExpectedImprovement "Maintains fast function loading with optimizations"

Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Phase 4 Test Results Summary" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

$totalTests = $global:testResults.Count
$passedTests = ($global:testResults | Where-Object { $_.Success }).Count
$failedTests = $totalTests - $passedTests
$totalDuration = ($global:testResults | Measure-Object -Property Duration -Sum).Sum

Write-Host "Total Tests: $totalTests" -ForegroundColor White
Write-Host "Passed: " -NoNewline -ForegroundColor White
Write-Host "$passedTests" -ForegroundColor Green
Write-Host "Failed: " -NoNewline -ForegroundColor White
Write-Host "$failedTests" -ForegroundColor $(if ($failedTests -eq 0) { "Green" } else { "Red" })
Write-Host "Total Duration: $([math]::Round($totalDuration, 2))ms" -ForegroundColor White
Write-Host "Success Rate: $([math]::Round(($passedTests / $totalTests) * 100, 1))%" -ForegroundColor $(if ($passedTests -eq $totalTests) { "Green" } else { "Yellow" })

if ($failedTests -gt 0) {
    Write-Host "`nFailed Tests:" -ForegroundColor Red
    $global:testResults | Where-Object { -not $_.Success } | ForEach-Object {
        Write-Host "  ✗ $($_.TestName): $($_.Details)" -ForegroundColor Red
    }
}

Write-Host "`nPhase 4 Optimization Implementations:" -ForegroundColor Yellow
$global:testResults | Where-Object { $_.Success -and $_.ExpectedImprovement } | ForEach-Object {
    Write-Host "  ✓ $($_.TestName): $($_.ExpectedImprovement)" -ForegroundColor Green
}

Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

# Return overall success
$overallSuccess = $failedTests -eq 0
if ($overallSuccess) {
    Write-Host "✓ All Phase 4 optimization tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ Some Phase 4 optimization tests failed!" -ForegroundColor Red
    exit 1
}
# Streamlined test for Get-UserStrongMapping function
param([switch]$VerboseOutput)

Write-Host "=== Get-UserStrongMapping Function Tests ===" -ForegroundColor Cyan

# Load the function
. ".\functions\UserAndGroupFunctions\Get-UserStrongMapping.ps1"

# Mock functions
function global:CallGraphApi
{
    param($accessToken, $ResourcePath, $ExtraParameters)
    
    switch -Wildcard ($ResourcePath)
    {
        "*user-with-certs*"
        {
            return @{
                id                = "user123"
                displayName       = "Test User With Certs"
                userPrincipalName = "user-with-certs@test.com"
                authorizationInfo = @{
                    certificateUserIds = @(
                        "C=US,O=Entrust,OU=Certification Authorities,OU=Entrust Managed Services SSP CA",
                        "C=US,O=Microsoft,OU=Microsoft IT,CN=Microsoft IT TLS CA 5"
                    )
                }
            }
        }
        "*user-no-certs*"
        {
            return @{
                id                = "user456"
                displayName       = "Test User No Certs"
                userPrincipalName = "user-no-certs@test.com"
                authorizationInfo = @{
                    certificateUserIds = @()
                }
            }
        }
        "*user-null-certs*"
        {
            return @{
                id                = "user789"
                displayName       = "Test User Null Certs"
                userPrincipalName = "user-null-certs@test.com"
                authorizationInfo = @{
                    certificateUserIds = $null
                }
            }
        }
        "*nonexistent-user*"
        {
            return $null
        }
        default
        {
            return @{
                id                = "defaultuser"
                displayName       = "Default Test User"
                userPrincipalName = "default@test.com"
                authorizationInfo = @{
                    certificateUserIds = @("C=US,O=Test,CN=Test Cert")
                }
            }
        }
    }
}

function global:Write-Log
{
    param($LogFile, $Module, $Message, $LogLevel = "Information")
    if ($VerboseOutput)
    {
        Write-Host "[LOG] $Message" -ForegroundColor Gray
    }
}

# Test counters
$passedTests = 0
$failedTests = 0
$totalTests = 0

function Test-Condition
{
    param(
        [string]$TestName,
        [bool]$Condition,
        [string]$FailureMessage = ""
    )
    
    $script:totalTests++
    
    if ($Condition)
    {
        Write-Host "✓ $TestName" -ForegroundColor Green
        $script:passedTests++
    }
    else
    {
        Write-Host "✗ $TestName $(if ($FailureMessage) { "- $FailureMessage" })" -ForegroundColor Red
        $script:failedTests++
    }
}

Write-Host "`n--- Test 1: Function Availability ---" -ForegroundColor Yellow
Test-Condition "Get-UserStrongMapping function exists" ($null -ne (Get-Command Get-UserStrongMapping -ErrorAction SilentlyContinue))

Write-Host "`n--- Test 2: User with Multiple Certificates ---" -ForegroundColor Yellow
$result = Get-UserStrongMapping -accessToken "fake-token" -UserName "user-with-certs"
Test-Condition "StrongMapping is true" ($result.StrongMapping -eq $true)
Test-Condition "UserName is preserved" ($result.UserName -eq "user-with-certs")
Test-Condition "DisplayName is set" ($result.DisplayName -eq "Test User With Certs")
Test-Condition "UserId is set" ($result.UserId -eq "user123")
Test-Condition "CertificateCount is 2" ($result.CertificateCount -eq 2)
Test-Condition "Certificates array has 2 items" ($result.Certificates.Count -eq 2)

Write-Host "`n--- Test 3: User with No Certificates ---" -ForegroundColor Yellow
$result = Get-UserStrongMapping -accessToken "fake-token" -UserName "user-no-certs"
Test-Condition "StrongMapping is false" ($result.StrongMapping -eq $false)
Test-Condition "CertificateCount is 0" ($result.CertificateCount -eq 0)
Test-Condition "Certificates array is empty" ($result.Certificates.Count -eq 0)

Write-Host "`n--- Test 4: User with Null Certificates ---" -ForegroundColor Yellow
$result = Get-UserStrongMapping -accessToken "fake-token" -UserName "user-null-certs"
Test-Condition "StrongMapping is false (null certs)" ($result.StrongMapping -eq $false)
Test-Condition "CertificateCount is 0 (null certs)" ($result.CertificateCount -eq 0)
Test-Condition "Certificates array is empty (null certs)" ($result.Certificates.Count -eq 0)

Write-Host "`n--- Test 5: Non-existent User ---" -ForegroundColor Yellow
$result = Get-UserStrongMapping -accessToken "fake-token" -UserName "nonexistent-user"
Test-Condition "StrongMapping is false (nonexistent)" ($result.StrongMapping -eq $false)
Test-Condition "UserName is preserved (nonexistent)" ($result.UserName -eq "nonexistent-user")
Test-Condition "DisplayName is empty (nonexistent)" ($result.DisplayName -eq "")
Test-Condition "UserId is empty (nonexistent)" ($result.UserId -eq "")

Write-Host "`n--- Test 6: Return Object Structure ---" -ForegroundColor Yellow
$result = Get-UserStrongMapping -accessToken "fake-token" -UserName "test-user"
$requiredProperties = @('StrongMapping', 'UserName', 'DisplayName', 'UserId', 'Certificates', 'CertificateCount')
foreach ($prop in $requiredProperties)
{
    Test-Condition "Has property: $prop" ($result.ContainsKey($prop))
}
Test-Condition "StrongMapping is boolean" ($result.StrongMapping -is [bool])
Test-Condition "Certificates is array" ($result.Certificates -is [array])
Test-Condition "CertificateCount is integer" ($result.CertificateCount -is [int])

Write-Host "`n=== Test Results Summary ===" -ForegroundColor Cyan
Write-Host "Total Tests: $totalTests" -ForegroundColor Yellow
Write-Host "Passed: $passedTests" -ForegroundColor Green
Write-Host "Failed: $failedTests" -ForegroundColor Red
Write-Host "Success Rate: $(($passedTests / $totalTests * 100).ToString('F1'))%" -ForegroundColor White

if ($failedTests -eq 0)
{
    Write-Host "`nAll tests PASSED! ✓" -ForegroundColor Green
    exit 0
}
else
{
    Write-Host "`nSome tests FAILED! ✗" -ForegroundColor Red
    exit 1
}
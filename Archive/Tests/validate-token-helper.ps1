<#
.SYNOPSIS
    Quick validation script for New-MockGraphToken helper

.DESCRIPTION
    Tests that the new token generation function works correctly
#>

$ErrorActionPreference = 'Stop'

# Load the helper module
Import-Module "$PSScriptRoot\Helpers\AutopilotGraphMocks.psm1" -Force

# Load DecodeJwtToken
. "$PSScriptRoot\..\functions\graphFunctions\DecodeJwtToken.ps1"

Write-Host "`n=== Testing New-MockGraphToken ===" -ForegroundColor Cyan

# Test 1: Create token with scopes array
Write-Host "`nTest 1: Token with scopes array" -ForegroundColor Yellow
$token1 = New-MockGraphToken -Scopes @('User.Read.All', 'Group.Read.All')
Write-Host "Token created: $($token1.Substring(0, 50))..."

# Decode it
$decoded1 = DecodeJwtToken -Token $token1
Write-Host "Decoded roles: $($decoded1.roles)"
Write-Host "Roles type: $($decoded1.roles.GetType().Name)"
Write-Host "Roles count: $($decoded1.roles.Count)"

# Test 2: Create token with custom payload (comma-separated string)
Write-Host "`nTest 2: Token with custom payload (comma-separated)" -ForegroundColor Yellow
$token2 = New-MockGraphToken -CustomPayload @{
    roles = 'User.Read.All, Group.Read.All'
    aud = 'https://graph.microsoft.com'
}
Write-Host "Token created: $($token2.Substring(0, 50))..."

$decoded2 = DecodeJwtToken -Token $token2
Write-Host "Decoded roles: $($decoded2.roles)"
Write-Host "Roles type: $($decoded2.roles.GetType().Name)"

# Test 3: Empty scopes
Write-Host "`nTest 3: Token with empty scopes" -ForegroundColor Yellow
$token3 = New-MockGraphToken -Scopes @()
Write-Host "Token created: $($token3.Substring(0, 50))..."

$decoded3 = DecodeJwtToken -Token $token3
Write-Host "Decoded roles: $($decoded3.roles)"
Write-Host "Roles type: $(if ($decoded3.roles) { $decoded3.roles.GetType().Name } else { 'null/empty' })"

Write-Host "`n=== All tests completed ===" -ForegroundColor Green

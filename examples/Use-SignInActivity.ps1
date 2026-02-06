# Example: Using Refactored Sign-In Activity Functions
# This script demonstrates how to use the refactored Get-SignInActivity function
# with Get-AutopilotEventAnalysis and Show-AutopilotEventAnalysis

# Prerequisites:
# - Valid access token with AuditLog.Read.All and Directory.Read.All permissions
# - Microsoft Entra ID P1 or P2 license

# ============================================================================
# Example 1: Get sign-in activity for a specific user
# ============================================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Example 1: Get Sign-In Activity for User" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$userPrincipalName = "user@contoso.com"
$accessToken = $global:accessToken  # Assumes token is already available

# Get full sign-in data
$signInData = Get-SignInActivity -UserPrincipalName $userPrincipalName -AccessToken $accessToken

if ($signInData.Success)
{
    Write-Host "Successfully retrieved $($signInData.SignIns.Count) sign-in events" -ForegroundColor Green
    Write-Host "Latest sign-in:" -ForegroundColor Yellow
    Write-Host "  Status: $($signInData.LatestSignIn.SignInSucceeded)" -ForegroundColor $(if ($signInData.LatestSignIn.SignInSucceeded)
        {
            'Green'
        }
        else
        {
            'Red'
        })
    Write-Host "  IP Address: $($signInData.LatestSignIn.IPAddress)" -ForegroundColor Cyan
    Write-Host "  Location: $($signInData.LatestSignIn.LocationCity), $($signInData.LatestSignIn.LocationState)" -ForegroundColor Cyan
}
else
{
    Write-Host "Failed to retrieve sign-in data: $($signInData.Message)" -ForegroundColor Red
}

# ============================================================================
# Example 2: Get enrichment data for reports
# ============================================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Example 2: Get Enrichment Data" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$enrichmentData = Get-SignInActivity -UserPrincipalName $userPrincipalName -AccessToken $accessToken -EnrichmentOnly

Write-Host "Enrichment Data Fields:" -ForegroundColor Yellow
foreach ($key in $enrichmentData.Keys | Sort-Object)
{
    Write-Host "  $key : $($enrichmentData[$key])" -ForegroundColor Cyan
}

# ============================================================================
# Example 3: Autopilot Event Analysis WITHOUT Sign-In Enrichment
# ============================================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Example 3: Autopilot Analysis (No Sign-In Data)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Analyze autopilot events (standard)
$analysisBasic = Get-AutopilotEventAnalysis -AccessToken $accessToken -StartDate (Get-Date).AddDays(-30)

Write-Host "Total Events: $($analysisBasic.TotalEvents)" -ForegroundColor Cyan
Write-Host "Failed Events: $($analysisBasic.FailureCount)" -ForegroundColor $(if ($analysisBasic.FailureCount -gt 0)
    {
        'Red'
    }
    else
    {
        'Green'
    })
Write-Host "Success Events: $($analysisBasic.SuccessCount)" -ForegroundColor Green

# Display the analysis
$analysisBasic | Show-AutopilotEventAnalysis -ShowSummary -ShowChronologicalFailures

# ============================================================================
# Example 4: Autopilot Event Analysis WITH Sign-In Enrichment
# ============================================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Example 4: Autopilot Analysis (With Sign-In Data)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Analyze autopilot events WITH sign-in data enrichment
$analysisEnriched = Get-AutopilotEventAnalysis -AccessToken $accessToken `
    -StartDate (Get-Date).AddDays(-30) `
    -IncludeSignInData

Write-Host "Total Events: $($analysisEnriched.TotalEvents)" -ForegroundColor Cyan
Write-Host "Failed Events: $($analysisEnriched.FailureCount)" -ForegroundColor $(if ($analysisEnriched.FailureCount -gt 0)
    {
        'Red'
    }
    else
    {
        'Green'
    })

# Check if failed events have sign-in data
$enrichedCount = ($analysisEnriched.FailedEvents | Where-Object {
        $_.PSObject.Properties.Name -contains 'SignInLatestStatus'
    }).Count

Write-Host "Failed Events Enriched with Sign-In Data: $enrichedCount" -ForegroundColor Yellow

# Display the enriched analysis (sign-in data will appear in chronological failures)
$analysisEnriched | Show-AutopilotEventAnalysis -ShowSummary -ShowChronologicalFailures

# ============================================================================
# Example 5: Focused Analysis on a Specific User
# ============================================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Example 5: User-Specific Analysis with Sign-In" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$targetUser = "problem.user@contoso.com"

# Get analysis for specific user with sign-in enrichment
$userAnalysis = Get-AutopilotEventAnalysis -AccessToken $accessToken `
    -UserPrincipalName $targetUser `
    -IncludeSignInData

Write-Host "Analysis for user: $targetUser" -ForegroundColor Yellow
Write-Host "  Total Events: $($userAnalysis.TotalEvents)" -ForegroundColor Cyan
Write-Host "  Failed Events: $($userAnalysis.FailureCount)" -ForegroundColor Red
Write-Host "  Success Events: $($userAnalysis.SuccessCount)" -ForegroundColor Green

# Display detailed failures with sign-in context
$userAnalysis | Show-AutopilotEventAnalysis -ShowChronologicalFailures -ShowMultipleFailures

# ============================================================================
# Example 6: Using Legacy Function Name (Backward Compatibility)
# ============================================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Example 6: Legacy Function Support" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# The old Get-UserSignInActivity still works for backward compatibility
$legacyResult = Get-UserSignInActivity -accessToken $accessToken `
    -userPrincipalName $userPrincipalName `
    -maxResults 5 `
    -daysBack 30

Write-Host "Legacy function returned: $($legacyResult.SignIns.Count) sign-ins" -ForegroundColor Yellow
Write-Host "Note: This function is deprecated. Use Get-SignInActivity instead." -ForegroundColor Yellow

# ============================================================================
# Key Benefits of the Refactored Code
# ============================================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Key Benefits of Refactored Code" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "1. Fixed Runtime Error:" -ForegroundColor Green
Write-Host "   - Properly initializes `$returnObject" -ForegroundColor Gray
Write-Host "   - No more undefined variable errors" -ForegroundColor Gray

Write-Host "`n2. Improved Structure:" -ForegroundColor Green
Write-Host "   - Removed unnecessary nested functions" -ForegroundColor Gray
Write-Host "   - Separated concerns with ConvertTo-SignInEnrichmentData helper" -ForegroundColor Gray
Write-Host "   - Added EnrichmentOnly mode for easy integration" -ForegroundColor Gray

Write-Host "`n3. Seamless Integration:" -ForegroundColor Green
Write-Host "   - Get-AutopilotEventAnalysis: Add -IncludeSignInData switch" -ForegroundColor Gray
Write-Host "   - Show-AutopilotEventAnalysis: Automatically displays sign-in data when present" -ForegroundColor Gray
Write-Host "   - Caches sign-in requests to avoid duplicate API calls" -ForegroundColor Gray

Write-Host "`n4. Better Maintainability:" -ForegroundColor Green
Write-Host "   - Comprehensive logging at all levels" -ForegroundColor Gray
Write-Host "   - Clear parameter names (UserPrincipalName vs signInUPN)" -ForegroundColor Gray
Write-Host "   - Full comment-based help documentation" -ForegroundColor Gray
Write-Host "   - Follows repository coding standards" -ForegroundColor Gray

Write-Host "`n5. Enhanced Features:" -ForegroundColor Green
Write-Host "   - Support for global access token fallback" -ForegroundColor Gray
Write-Host "   - Configurable MaxResults and DaysBack parameters" -ForegroundColor Gray
Write-Host "   - Sign-in pattern analysis and failure reason tracking" -ForegroundColor Gray
Write-Host "   - Conditional Access policy information" -ForegroundColor Gray

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Examples Complete!" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

function Show-UserReadinessReport()
{
    <#
    .SYNOPSIS
        Displays a formatted report of user readiness check results.
    
    .DESCRIPTION
        Takes the output from Test-UserReadiness and displays it in a user-friendly format.
        Shows all checks performed, their results, and suggested resolutions for any failures.
        Uses ASCII characters only for PowerShell 5.1 compatibility.
    
    .PARAMETER ReadinessResult
        The result object returned from Test-UserReadiness function.
    
    .EXAMPLE
        $result = Test-UserReadiness -UserName "john.doe@contoso.com" -AccessToken $token -GroupsToInclude $groups -GroupsToExclude $excludedGroups -Settings $settings
        Show-UserReadinessReport -ReadinessResult $result
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$ReadinessResult
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Displaying user readiness report"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Displaying user readiness report for user: $($ReadinessResult.UserName)" -LogLevel Verbose
    
    # Display header
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  User Readiness Report" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "User: $($ReadinessResult.UserName)" -ForegroundColor White
    if ($ReadinessResult.DisplayName)
    {
        Write-Host "Name: $($ReadinessResult.DisplayName)" -ForegroundColor White
    }
    Write-Host ""
    
    # Display overall status
    if ($ReadinessResult.IsReady)
    {
        Write-Host "[PASS] User is ready to receive a Windows 11 device" -ForegroundColor Green
        Write-Host ""
    }
    else
    {
        Write-Host "[FAIL] User is NOT ready to receive a Windows 11 device" -ForegroundColor Red
        Write-Host ""
        Write-Host "Issues found: $($ReadinessResult.IssueCount)" -ForegroundColor Red
        if ($ReadinessResult.WarningCount -gt 0)
        {
            Write-Host "Warnings: $($ReadinessResult.WarningCount)" -ForegroundColor Yellow
        }
        Write-Host ""
    }
    
    # Display individual check results
    Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "  Check Results" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($check in $ReadinessResult.Checks)
    {
        # Display check name and status
        if ($check.Passed)
        {
            Write-Host "[PASS] $($check.CheckName)" -ForegroundColor Green
        }
        else
        {
            if ($check.Severity -eq "Error")
            {
                Write-Host "[FAIL] $($check.CheckName)" -ForegroundColor Red
            }
            else
            {
                Write-Host "[WARN] $($check.CheckName)" -ForegroundColor Yellow
            }
        }
        
        # Display message
        Write-Host "       $($check.Message)" -ForegroundColor White
        
        # Display details
        if ($check.Details -and $check.Details.Count -gt 0)
        {
            foreach ($detail in $check.Details)
            {
                Write-Host "       $detail" -ForegroundColor Gray
            }
        }
        
        # Display suggested resolution for failed checks
        if (-not $check.Passed -and $check.SuggestedResolution)
        {
            Write-Host ""
            Write-Host "       Resolution:" -ForegroundColor Cyan
            Write-Host "       $($check.SuggestedResolution)" -ForegroundColor Cyan
        }
        
        Write-Host ""
    }
    
    # Display footer with next steps
    Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
    
    if ($ReadinessResult.IsReady)
    {
        Write-Host "Next Step: You can now proceed to check the device status." -ForegroundColor Green
    }
    else
    {
        Write-Host "Next Steps:" -ForegroundColor Yellow
        Write-Host "  1. Review the issues and warnings above" -ForegroundColor Yellow
        Write-Host "  2. Apply the suggested resolutions" -ForegroundColor Yellow
        Write-Host "  3. Run the readiness check again after making changes" -ForegroundColor Yellow
    }
    
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Verbose "[$functionName] Readiness report display completed"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Readiness report displayed for user: $($ReadinessResult.UserName)" -LogLevel Verbose
}

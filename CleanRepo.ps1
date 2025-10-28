<#
.SYNOPSIS
    Cleans up local Git branches that have been deleted from the remote repository.

.DESCRIPTION
    This script identifies and deletes local branches whose remote tracking branches
    no longer exist (marked as 'gone' in git branch -vv output).

.PARAMETER WhatIf
    Shows what would happen if the script runs without actually deleting branches.

.EXAMPLE
    .\CleanRepo.ps1
    Interactively deletes stale branches after prompting for each one.

.EXAMPLE
    .\CleanRepo.ps1 -WhatIf
    Shows which branches would be deleted without actually deleting them.
#>

[CmdletBinding(SupportsShouldProcess)]
param() 

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host " Git Repository Cleanup - Remove Stale Local Branches" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
if ($WhatIfPreference)
{
    Write-Host " [WHATIF MODE - No changes will be made]" -ForegroundColor Yellow
}
Write-Host ""

# Get list of branches with gone remotes
Write-Host "Scanning for local branches with deleted remote tracking branches..." -ForegroundColor Yellow
$staleBranches = git branch -vv | Where-Object { $_ -match 'gone\]' } | ForEach-Object { $_.Trim().Split()[0] }

if ($staleBranches.Count -eq 0)
{
    Write-Host ""
    Write-Host "No stale branches found. Repository is clean!" -ForegroundColor Green
    Write-Host ""
}
else
{
    Write-Host ""
    Write-Host "Found $($staleBranches.Count) stale branch(es) to delete:" -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($branch in $staleBranches)
    {
        Write-Host "  - $branch" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "Deleting stale branches..." -ForegroundColor Yellow
    Write-Host ""
    
    $deletedCount = 0
    $failedCount = 0
    $skippedCount = 0    
    foreach ($branch in $staleBranches)
    {
        if (-not $WhatIfPreference)
        {
            Write-Host "Please choose what kind of delete you want to apply:"
            Write-Host "1. Force delete"
            Write-Host "2. Soft delete"
            Write-Host "3. Skip"
            $deleteChoice = Read-Host "Enter your choice (1 or 2)"
            while ($deleteChoice -notin @("1", "2", "3"))                 
            {
                Write-Host "Invalid choice. Please enter 1, 2, or 3." -ForegroundColor Red
                [console]::beep(1000, 300)   
                $deleteChoice = Read-Host "Enter your choice (1 or 2)"
            }
        }
        else
        {
            # In WhatIf mode, default to force delete for simulation
            $deleteChoice = "1"
        }
                                                        
        if ($deleteChoice -eq "1")
        {
            if ($PSCmdlet.ShouldProcess($branch, "Force delete branch"))
            {
                Write-Host "Deleting branch: $branch ... " -NoNewline -ForegroundColor White
                $result = git branch -D $branch 2>&1
                
                if ($LASTEXITCODE -eq 0)
                {
                    Write-Host "SUCCESS" -ForegroundColor Green
                    $deletedCount++
                }
                else
                {
                    Write-Host "FAILED" -ForegroundColor Red
                    Write-Host "  Error: $result" -ForegroundColor Red
                    $failedCount++
                }
            }
            else
            {
                Write-Host "What if: Performing the operation ""Force delete branch"" on target ""$branch""." -ForegroundColor Cyan
            }
        }
        elseif ($deleteChoice -eq "2")
        {
            if ($PSCmdlet.ShouldProcess($branch, "Soft delete branch"))
            {
                Write-Host "Deleting branch: $branch ... " -NoNewline -ForegroundColor White
                $result = git branch -d $branch 2>&1
                
                if ($LASTEXITCODE -eq 0)
                {
                    Write-Host "SUCCESS" -ForegroundColor Green
                    $deletedCount++
                }
                else
                {
                    Write-Host "FAILED" -ForegroundColor Red
                    Write-Host "  Error: $result" -ForegroundColor Red
                    $failedCount++
                }
            }
            else
            {
                Write-Host "What if: Performing the operation ""Soft delete branch"" on target ""$branch""." -ForegroundColor Cyan
            }
        }
        else
        {
            Write-Host "Skipping deletion of branch: $branch" -ForegroundColor Red
            $skippedCount++
            continue
        }
    }
    
    Write-Host ""
    Write-Host "==============================================================" -ForegroundColor Cyan
    Write-Host " Cleanup Summary" -ForegroundColor Cyan
    Write-Host "==============================================================" -ForegroundColor Cyan
    Write-Host "Successfully deleted: $deletedCount branch(es)" -ForegroundColor Green
    
    if ($failedCount -gt 0)
    {
        Write-Host "Failed to delete:     $failedCount branch(es)" -ForegroundColor Red
    }
    if ($skippedCount -gt 0)
    {
        Write-Host "Skipped deletion of:  $skippedCount branch(es)" -ForegroundColor Yellow
    }                                           
    Write-Host ""
}
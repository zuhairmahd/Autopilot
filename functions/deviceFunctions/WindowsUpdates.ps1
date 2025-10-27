function Apply-WindowsUpdates()
{
    <#
    .SYNOPSIS
        Downloads and installs Windows Updates using Microsoft-recommended COM-based approach.
    
    .DESCRIPTION
        Iteratively searches for, downloads, and installs Windows Updates until no more updates are available.
        Uses the Microsoft Update COM objects (IUpdateSession, IUpdateSearcher, IUpdateDownloader, IUpdateInstaller)
        which is the Microsoft-recommended approach for programmatic update management.
        
        Supports:
        - Multiple update categories (Security, Critical, Definition, Feature, Driver, etc.)
        - Iterative installation until all updates are applied
        - Reboot detection and user-controlled restart options
        - Detailed progress reporting at every stage
        - Filtering by update classification
    
    .PARAMETER UpdateCategories
        Array of update categories to install. Valid values:
        - 'Security' - Security updates
        - 'Critical' - Critical updates  
        - 'Definition' - Definition updates (Windows Defender, etc.)
        - 'Feature' - Feature updates
        - 'ServicePack' - Service packs
        - 'Tools' - Tools and utilities
        - 'UpdateRollup' - Update rollups
        - 'Driver' - Driver updates
        - 'Other' - Other updates
        - 'All' - All update types (default)
        
        If not specified or empty, all updates will be installed.
    
    .PARAMETER MaxIterations
        Maximum number of search/install cycles to perform. Default is 10.
        Prevents infinite loops while ensuring all updates are applied.
    
    .PARAMETER Reboot
        Reboot behavior when updates require restart:
        - 'Prompt' - Ask user for permission (default)
        - 'Soft' - Return code 3010 (soft reboot required)
        - 'Hard' - Return code 1641 (hard reboot required)
        - 'Delayed' - Schedule reboot with timeout
        - 'None' - Never reboot automatically
    
    .PARAMETER RebootTimeout
        Timeout in seconds for delayed reboot. Default is 120 seconds.
    
    .PARAMETER SkipPreview
        Skip preview/optional updates. Default is $true.
    
    .PARAMETER SkipFeature
        Skip feature updates (major Windows version upgrades). Default is $true.
    
    .PARAMETER noOptIn
        Skip opting into Microsoft Update service. Default is $false.
    
    .EXAMPLE
        ApplyWindowsUpdates
        Installs all available updates with user prompt for reboot.
    
    .EXAMPLE
        ApplyWindowsUpdates -UpdateCategories 'Security', 'Critical' -Reboot None
        Installs only security and critical updates without automatic reboot.
    
    .EXAMPLE
        ApplyWindowsUpdates -UpdateCategories 'Driver' -MaxIterations 5
        Installs driver updates only, maximum 5 search cycles.
    
    .NOTES
        Requires administrative privileges.
        Uses Windows Update COM objects as recommended by Microsoft.
        Reference: https://learn.microsoft.com/en-us/windows/win32/wua_sdk/using-the-windows-update-agent-api
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [ValidateSet('Security', 'Critical', 'Definition', 'Feature', 'ServicePack', 'Tools', 'UpdateRollup', 'Driver', 'Other', 'All')]
        [string[]]$UpdateCategories = @('All'),
        [Parameter(Mandatory = $False)]
        [ValidateRange(1, 50)]
        [int]$MaxIterations = 10,
        [Parameter(Mandatory = $False)] 
        [ValidateSet('Prompt', 'Soft', 'Hard', 'None', 'Delayed')] 
        [String]$Reboot = 'Prompt',
        [Parameter(Mandatory = $False)] 
        [ValidateRange(30, 3600)]
        [Int32]$RebootTimeout = 120,
        [Parameter(Mandatory = $False)]
        [bool]$SkipPreview = $true,
        [Parameter(Mandatory = $False)]
        [bool]$SkipFeature = $true,
        [Parameter(Mandatory = $False)]
        [switch]$noOptIn
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "WINDOWS UPDATE OPERATION STARTED" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  Windows Update Manager" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Log system information
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "PowerShell version: $($PSVersionTable.PSVersion)" -LogLevel "Debug"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Current user: $env:USERNAME" -LogLevel "Debug"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Computer name: $env:COMPUTERNAME" -LogLevel "Debug"
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Running as administrator: $isAdmin" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -LogLevel "Debug"
    
    # Log configuration
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Configuration parameters:" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Update categories: $($UpdateCategories -join ', ')" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Maximum iterations: $MaxIterations" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Reboot mode: $Reboot" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Reboot timeout: $RebootTimeout seconds" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Skip preview updates: $SkipPreview" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Skip feature updates: $SkipFeature" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Skip Microsoft Update opt-in: $noOptIn" -LogLevel "Information"
    
    Write-Host "Configuration:" -ForegroundColor Cyan
    Write-Host "  Update Categories: $($UpdateCategories -join ', ')" -ForegroundColor White
    Write-Host "  Max Iterations: $MaxIterations" -ForegroundColor White
    Write-Host "  Reboot Mode: $Reboot" -ForegroundColor White
    Write-Host "  Skip Preview: $SkipPreview" -ForegroundColor White
    Write-Host "  Skip Feature: $SkipFeature" -ForegroundColor White
    Write-Host ""
    
    $operationStartTime = Get-Date
    $globalStats = @{
        TotalIterations        = 0
        TotalUpdatesFound      = 0
        TotalUpdatesDownloaded = 0
        TotalUpdatesInstalled  = 0
        TotalUpdatesFailed     = 0
        TotalDownloadSize      = 0
        SkippedPreview         = 0
        SkippedFeature         = 0
        SkippedProcessed       = 0
        RebootRequired         = $false
        RebootType             = 'None'
    }
    
    # Track processed updates across iterations to prevent re-downloading/installing
    $processedUpdates = @{}
    
    try
    {
        # Opt into Microsoft Update (unless disabled)
        if (-not $noOptIn)
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "MICROSOFT UPDATE SERVICE REGISTRATION" -LogLevel "Information"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
            Write-Host "Registering Microsoft Update service..." -ForegroundColor Cyan
            
            try
            {
                $ServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager"
                $ServiceID = "7971f918-a847-4430-9279-4a52d1efe18d"
                
                # Check if already registered
                $existingService = $ServiceManager.Services | Where-Object { $_.ServiceID -eq $ServiceID }
                if ($existingService)
                {
                    Write-Host "  Microsoft Update service already registered" -ForegroundColor Green
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Microsoft Update service already registered" -LogLevel "Information"
                }
                else
                {
                    $ServiceManager.AddService2($ServiceID, 7, "") | Out-Null
                    Write-Host "  Microsoft Update service registered successfully" -ForegroundColor Green
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Microsoft Update service registered successfully" -LogLevel "Information"
                }
            }
            catch
            {
                Write-Host "  WARNING: Could not register Microsoft Update service" -ForegroundColor Yellow
                Write-Host "  $($_.Exception.Message)" -ForegroundColor Yellow
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Failed to register Microsoft Update: $($_.Exception.Message)" -LogLevel "Warning"
            }
            Write-Host ""
        }
        
        # Build search criteria based on update categories
        $searchCriteria = "IsInstalled=0"
        
        if ($UpdateCategories -notcontains 'All')
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Building category-specific search criteria" -LogLevel "Verbose"
            $categoryFilters = @()
            
            # Map category names to Windows Update category IDs
            $categoryMap = @{
                'Security'     = "0FA1201D-4330-4FA8-8AE9-B877473B6441"
                'Critical'     = "E6CF1350-C01B-414D-A61F-263D14D133B4"
                'Definition'   = "E0789628-CE08-4437-BE74-2495B842F43B"
                'Feature'      = "3689BDC8-B205-4AF4-8D4A-A63924C5E9D5"
                'ServicePack'  = "68C5B0A3-D1A6-4553-AE49-01D3A7827828"
                'Tools'        = "B54E7D24-7ADD-428F-8B75-90A396FA584F"
                'UpdateRollup' = "28BC880E-0592-4CBF-8F95-C79B17911D5F"
                'Driver'       = "EBFC1FC5-71A4-4F7B-9ACA-3B9A503104A0"
            }
            
            foreach ($category in $UpdateCategories)
            {
                if ($categoryMap.ContainsKey($category))
                {
                    $categoryFilters += "CategoryIDs contains '$($categoryMap[$category])'"
                }
            }
            
            if ($categoryFilters.Count -gt 0)
            {
                $searchCriteria += " and (" + ($categoryFilters -join " or ") + ")"
            }
        }
        
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Search criteria: $searchCriteria" -LogLevel "Information"
        
        # Iterative update loop
        $iteration = 0
        $updatesRemaining = $true
        
        while ($updatesRemaining -and $iteration -lt $MaxIterations)
        {
            $iteration++
            $globalStats.TotalIterations = $iteration
            
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "ITERATION $iteration of $MaxIterations" -LogLevel "Information"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host "  Update Cycle $iteration of $MaxIterations" -ForegroundColor Cyan
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host ""
            
            # Create update session
            Write-Host "Initializing Windows Update session..." -ForegroundColor Cyan
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Creating update session objects" -LogLevel "Verbose"
            
            $updateSession = New-Object -ComObject Microsoft.Update.Session
            $updateSearcher = $updateSession.CreateUpdateSearcher()
            
            # Search for updates
            Write-Host "Searching for available updates..." -ForegroundColor Cyan
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Searching with criteria: $searchCriteria" -LogLevel "Information"
            
            $searchStartTime = Get-Date
            try
            {
                $searchResult = $updateSearcher.Search($searchCriteria)
                $searchDuration = (Get-Date) - $searchStartTime
                
                Write-Host "  Search completed in $([Math]::Round($searchDuration.TotalSeconds, 2)) seconds" -ForegroundColor Green
                Write-Host "  Found $($searchResult.Updates.Count) potential updates" -ForegroundColor Green
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Search completed. Found $($searchResult.Updates.Count) updates in $([Math]::Round($searchDuration.TotalSeconds, 2))s" -LogLevel "Information"
            }
            catch
            {
                Write-Host "  ERROR: Update search failed" -ForegroundColor Red
                Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Update search failed: $($_.Exception.Message)" -LogLevel "Error"
                
                if ($_.Exception.Message -like "*8024004A*")
                {
                    Write-Host "  This error occurs when Windows Update is unavailable (e.g., during OS setup)" -ForegroundColor Yellow
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error 8024004A detected - Windows Update unavailable" -LogLevel "Error"
                }
                break
            }
            Write-Host ""
            
            # Filter updates
            Write-Host "Filtering updates..." -ForegroundColor Cyan
            $updatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
            $iterationStats = @{
                Found     = $searchResult.Updates.Count
                Accepted  = 0
                Skipped   = 0
                Preview   = 0
                Feature   = 0
                Processed = 0
            }
            
            foreach ($update in $searchResult.Updates)
            {
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Evaluating: $($update.Title)" -LogLevel "Verbose"
                
                # Check if this update was already processed in a previous iteration
                $updateKey = "$($update.Identity.UpdateID)_$($update.Identity.RevisionNumber)"
                if ($processedUpdates.ContainsKey($updateKey))
                {
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "  Skipped (Already Processed): $($update.Title)" -LogLevel "Information"
                    $iterationStats.Processed++
                    $globalStats.SkippedProcessed++
                    continue
                }
                
                # Accept EULA if needed
                if (-not $update.EulaAccepted)
                {
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "  Accepting EULA for: $($update.Title)" -LogLevel "Verbose"
                    $update.AcceptEula()
                }
                
                # Check for feature update
                $isFeatureUpdate = $false
                foreach ($category in $update.Categories)
                {
                    if ($category.CategoryID -eq "3689BDC8-B205-4AF4-8D4A-A63924C5E9D5")
                    {
                        $isFeatureUpdate = $true
                        break
                    }
                }
                
                # Apply filters
                if ($SkipFeature -and $isFeatureUpdate)
                {
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "  Skipped (Feature): $($update.Title)" -LogLevel "Information"
                    $iterationStats.Feature++
                    $globalStats.SkippedFeature++
                    continue
                }
                
                if ($SkipPreview -and $update.Title -match "Preview")
                {
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "  Skipped (Preview): $($update.Title)" -LogLevel "Information"
                    $iterationStats.Preview++
                    $globalStats.SkippedPreview++
                    continue
                }
                
                # Add to install collection
                [void]$updatesToInstall.Add($update)
                $iterationStats.Accepted++
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "  Accepted: $($update.Title)" -LogLevel "Information"
            }
            
            $iterationStats.Skipped = $iterationStats.Feature + $iterationStats.Preview + $iterationStats.Processed
            $globalStats.TotalUpdatesFound += $iterationStats.Found
            
            Write-Host "  Total found: $($iterationStats.Found)" -ForegroundColor White
            Write-Host "  Accepted: $($iterationStats.Accepted)" -ForegroundColor Green
            Write-Host "  Skipped: $($iterationStats.Skipped) (Feature: $($iterationStats.Feature), Preview: $($iterationStats.Preview), Already Processed: $($iterationStats.Processed))" -ForegroundColor Yellow
            Write-Host ""
            
            # Check if we have updates to install
            if ($updatesToInstall.Count -eq 0)
            {
                # Check if we skipped updates because they were already processed
                if ($iterationStats.Processed -gt 0)
                {
                    Write-Host "No new updates to install. $($iterationStats.Processed) update(s) were already processed in previous iterations." -ForegroundColor Yellow
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "No new updates available. $($iterationStats.Processed) already processed. System may require restart." -LogLevel "Warning"
                    
                    # Prompt user to restart if we keep seeing the same updates
                    Write-Host ""
                    Write-Host "The same updates keep appearing, which typically means:" -ForegroundColor Yellow
                    Write-Host "  1. A system restart is required to complete previous installations" -ForegroundColor Yellow
                    Write-Host "  2. Update dependencies need to be resolved" -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "Would you like to restart the system now to apply pending updates?" -ForegroundColor Cyan
                    Write-Host "  [Y] Yes  [N] No  [D] Delayed ($RebootTimeout seconds)" -ForegroundColor White
                    Write-Host ""
                    
                    do
                    {
                        $response = Read-Host "Enter choice (Y/N/D)"
                        $response = $response.ToUpper()
                    } 
                    while ($response -notin @('Y', 'N', 'D'))
                    
                    switch ($response)
                    {
                        'Y'
                        {
                            Write-Host ""
                            Write-Host "Initiating immediate restart..." -ForegroundColor Yellow
                            Write-Log -LogFile $LogFile -Module "$functionName" -Message "User selected immediate restart due to recurring updates" -LogLevel "Information"
                            & shutdown.exe /r /t 10 /c "Restarting to resolve pending Windows Updates"
                            $globalStats.RebootType = 'Immediate'
                            $globalStats.RebootRequired = $true
                            Start-Sleep -Seconds 2
                        }
                        'D'
                        {
                            Write-Host ""
                            Write-Host "Scheduling restart in $RebootTimeout seconds..." -ForegroundColor Yellow
                            Write-Log -LogFile $LogFile -Module "$functionName" -Message "User selected delayed restart due to recurring updates ($RebootTimeout seconds)" -LogLevel "Information"
                            & shutdown.exe /r /t $RebootTimeout /c "Restarting to resolve pending Windows Updates"
                            $globalStats.RebootType = 'Delayed'
                            $globalStats.RebootRequired = $true
                        }
                        'N'
                        {
                            Write-Host ""
                            Write-Host "Restart postponed. Please restart manually to resolve pending updates." -ForegroundColor Yellow
                            Write-Log -LogFile $LogFile -Module "$functionName" -Message "User postponed restart for recurring updates" -LogLevel "Information"
                            $globalStats.RebootType = 'Manual'
                        }
                    }
                }
                else
                {
                    Write-Host "No updates to install in this cycle." -ForegroundColor Green
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "No updates to install. Ending iteration loop." -LogLevel "Information"
                }
                $updatesRemaining = $false
                break
            }
            
            # Download updates
            Write-Host "Downloading $($updatesToInstall.Count) update(s)..." -ForegroundColor Cyan
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Starting download phase for $($updatesToInstall.Count) updates" -LogLevel "Information"
            
            $downloader = $updateSession.CreateUpdateDownloader()
            $downloader.Updates = $updatesToInstall
            
            $downloadCount = 0
            foreach ($update in $updatesToInstall)
            {
                $downloadCount++
                $sizeInMB = [Math]::Round($update.MaxDownloadSize / 1MB, 2)
                Write-Host "  [$downloadCount/$($updatesToInstall.Count)] $($update.Title) ($sizeInMB MB)" -ForegroundColor White
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "  Downloading [$downloadCount/$($updatesToInstall.Count)]: $($update.Title) ($sizeInMB MB)" -LogLevel "Information"
                
                $globalStats.TotalDownloadSize += $update.MaxDownloadSize
            }
            
            $downloadStartTime = Get-Date
            try
            {
                $downloadResult = $downloader.Download()
                $downloadDuration = (Get-Date) - $downloadStartTime
                
                Write-Host ""
                Write-Host "  Download completed in $([Math]::Round($downloadDuration.TotalSeconds, 2)) seconds" -ForegroundColor Green
                Write-Host "  Result Code: $($downloadResult.ResultCode)" -ForegroundColor Green
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Download completed in $([Math]::Round($downloadDuration.TotalSeconds, 2))s. Result: $($downloadResult.ResultCode)" -LogLevel "Information"
                
                $globalStats.TotalUpdatesDownloaded += $updatesToInstall.Count
            }
            catch
            {
                Write-Host "  ERROR: Download failed" -ForegroundColor Red
                Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Download failed: $($_.Exception.Message)" -LogLevel "Error"
                break
            }
            Write-Host ""
            
            # Install updates
            Write-Host "Installing $($updatesToInstall.Count) update(s)..." -ForegroundColor Cyan
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Starting installation phase for $($updatesToInstall.Count) updates" -LogLevel "Information"
            
            $installer = $updateSession.CreateUpdateInstaller()
            $installer.Updates = $updatesToInstall
            $installer.ForceQuiet = $true
            
            $installStartTime = Get-Date
            $installCount = 0
            $successCount = 0
            $failCount = 0
            
            try
            {
                $installResult = $installer.Install()
                $installDuration = (Get-Date) - $installStartTime
                
                Write-Host ""
                Write-Host "  Installation completed in $([Math]::Round($installDuration.TotalSeconds, 2)) seconds" -ForegroundColor Green
                Write-Host "  Overall Result Code: $($installResult.ResultCode)" -ForegroundColor Green
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Installation completed in $([Math]::Round($installDuration.TotalSeconds, 2))s. Result: $($installResult.ResultCode)" -LogLevel "Information"
                
                # Check individual update results
                Write-Host ""
                Write-Host "  Individual Update Results:" -ForegroundColor Cyan
                for ($i = 0; $i -lt $updatesToInstall.Count; $i++)
                {
                    $updateResult = $installResult.GetUpdateResult($i)
                    $update = $updatesToInstall.Item($i)
                    
                    # Result codes: 2=Succeeded, 3=SucceededWithErrors, 4=Failed, 5=Aborted
                    $resultText = switch ($updateResult.ResultCode)
                    {
                        2
                        {
                            "SUCCESS"; $successCount++; $globalStats.TotalUpdatesInstalled++
                            # Track successfully installed update
                            $updateKey = "$($update.Identity.UpdateID)_$($update.Identity.RevisionNumber)"
                            $processedUpdates[$updateKey] = @{
                                Title     = $update.Title
                                Iteration = $iteration
                                Timestamp = Get-Date
                                Result    = 'Success'
                            }
                        }
                        3
                        {
                            "SUCCESS (with errors)"; $successCount++; $globalStats.TotalUpdatesInstalled++
                            # Track update with errors as processed
                            $updateKey = "$($update.Identity.UpdateID)_$($update.Identity.RevisionNumber)"
                            $processedUpdates[$updateKey] = @{
                                Title     = $update.Title
                                Iteration = $iteration
                                Timestamp = Get-Date
                                Result    = 'SuccessWithErrors'
                            }
                        }
                        4
                        {
                            "FAILED"; $failCount++; $globalStats.TotalUpdatesFailed++
                            # Track failed update to avoid retry
                            $updateKey = "$($update.Identity.UpdateID)_$($update.Identity.RevisionNumber)"
                            $processedUpdates[$updateKey] = @{
                                Title     = $update.Title
                                Iteration = $iteration
                                Timestamp = Get-Date
                                Result    = 'Failed'
                            }
                        }
                        5
                        {
                            "ABORTED"; $failCount++; $globalStats.TotalUpdatesFailed++
                            # Track aborted update
                            $updateKey = "$($update.Identity.UpdateID)_$($update.Identity.RevisionNumber)"
                            $processedUpdates[$updateKey] = @{
                                Title     = $update.Title
                                Iteration = $iteration
                                Timestamp = Get-Date
                                Result    = 'Aborted'
                            }
                        }
                        default
                        {
                            "UNKNOWN ($($updateResult.ResultCode))" 
                        }
                    }
                    
                    $color = if ($updateResult.ResultCode -eq 2)
                    {
                        "Green" 
                    }
                    elseif ($updateResult.ResultCode -eq 3)
                    {
                        "Yellow" 
                    }
                    else
                    {
                        "Red" 
                    }
                    
                    Write-Host "    [$resultText] $($update.Title)" -ForegroundColor $color
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "    [$resultText] $($update.Title) (HRESULT: $($updateResult.HResult))" -LogLevel "Information"
                    
                    if ($updateResult.RebootRequired)
                    {
                        $globalStats.RebootRequired = $true
                        Write-Host "      ** REBOOT REQUIRED **" -ForegroundColor Yellow
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "      Update requires reboot" -LogLevel "Warning"
                    }
                }
                
                Write-Host ""
                Write-Host "  Summary: $successCount succeeded, $failCount failed" -ForegroundColor $(if ($failCount -eq 0)
                    {
                        "Green" 
                    }
                    else
                    {
                        "Yellow" 
                    })
                
                # Check if reboot required
                if ($installResult.RebootRequired)
                {
                    $globalStats.RebootRequired = $true
                    Write-Host ""
                    Write-Host "  SYSTEM REBOOT REQUIRED" -ForegroundColor Yellow
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Installation requires system reboot" -LogLevel "Warning"
                }
            }
            catch
            {
                Write-Host "  ERROR: Installation failed" -ForegroundColor Red
                Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Installation failed: $($_.Exception.Message)" -LogLevel "Error"
                break
            }
            
            Write-Host ""
            Write-Host "Iteration $iteration complete." -ForegroundColor Green
            Write-Host ""
            
            # If we installed updates successfully, continue to next iteration
            # (unless we hit max iterations or need reboot)
            if ($successCount -gt 0 -and -not $globalStats.RebootRequired)
            {
                Write-Host "Checking for additional updates..." -ForegroundColor Cyan
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Continuing to next iteration to check for more updates" -LogLevel "Information"
            }
            else
            {
                $updatesRemaining = $false
            }
        }
        
        # Final summary
        $operationEndTime = Get-Date
        $totalDuration = $operationEndTime - $operationStartTime
        
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "OPERATION COMPLETED" -LogLevel "Information"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
        
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "  Windows Update Summary" -ForegroundColor Cyan
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Cycles Completed: $($globalStats.TotalIterations) of $MaxIterations" -ForegroundColor White
        Write-Host "Total Updates Found: $($globalStats.TotalUpdatesFound)" -ForegroundColor White
        Write-Host "Updates Downloaded: $($globalStats.TotalUpdatesDownloaded)" -ForegroundColor Green
        Write-Host "Updates Installed: $($globalStats.TotalUpdatesInstalled)" -ForegroundColor Green
        Write-Host "Updates Failed: $($globalStats.TotalUpdatesFailed)" -ForegroundColor $(if ($globalStats.TotalUpdatesFailed -eq 0)
            {
                "Green" 
            }
            else
            {
                "Red" 
            })
        Write-Host "Skipped (Preview): $($globalStats.SkippedPreview)" -ForegroundColor Yellow
        Write-Host "Skipped (Feature): $($globalStats.SkippedFeature)" -ForegroundColor Yellow
        Write-Host "Skipped (Already Processed): $($globalStats.SkippedProcessed)" -ForegroundColor Yellow
        Write-Host "Total Downloaded: $([Math]::Round($globalStats.TotalDownloadSize / 1MB, 2)) MB" -ForegroundColor White
        Write-Host "Total Duration: $([Math]::Round($totalDuration.TotalMinutes, 2)) minutes" -ForegroundColor White
        Write-Host "Reboot Required: $($globalStats.RebootRequired)" -ForegroundColor $(if ($globalStats.RebootRequired)
            {
                "Yellow" 
            }
            else
            {
                "Green" 
            })
        Write-Host ""
        
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Final statistics: $($globalStats | ConvertTo-Json -Compress)" -LogLevel "Information"
        
        # Handle reboot if required
        if ($globalStats.RebootRequired)
        {
            Write-Host "==========================================" -ForegroundColor Yellow
            Write-Host "  REBOOT REQUIRED" -ForegroundColor Yellow
            Write-Host "==========================================" -ForegroundColor Yellow
            Write-Host ""
            
            switch ($Reboot)
            {
                'Prompt'
                {
                    Write-Host "One or more updates require a system restart." -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "Would you like to restart now?" -ForegroundColor Cyan
                    Write-Host "  [Y] Yes  [N] No  [D] Delayed ($RebootTimeout seconds)" -ForegroundColor White
                    Write-Host ""
                    
                    do
                    {
                        $response = Read-Host "Enter choice (Y/N/D)"
                        $response = $response.ToUpper()
                    } 
                    while ($response -notin @('Y', 'N', 'D'))
                    
                    switch ($response)
                    {
                        'Y'
                        {
                            Write-Host ""
                            Write-Host "Initiating immediate restart..." -ForegroundColor Yellow
                            Write-Log -LogFile $LogFile -Module "$functionName" -Message "User selected immediate restart" -LogLevel "Information"
                            & shutdown.exe /r /t 10 /c "Restarting to complete Windows Updates"
                            $globalStats.RebootType = 'Immediate'
                            Start-Sleep -Seconds 2
                        }
                        'D'
                        {
                            Write-Host ""
                            Write-Host "Scheduling restart in $RebootTimeout seconds..." -ForegroundColor Yellow
                            Write-Log -LogFile $LogFile -Module "$functionName" -Message "User selected delayed restart ($RebootTimeout seconds)" -LogLevel "Information"
                            & shutdown.exe /r /t $RebootTimeout /c "Restarting to complete Windows Updates"
                            $globalStats.RebootType = 'Delayed'
                        }
                        'N'
                        {
                            Write-Host ""
                            Write-Host "Restart postponed. Please restart manually to complete updates." -ForegroundColor Yellow
                            Write-Log -LogFile $LogFile -Module "$functionName" -Message "User postponed restart" -LogLevel "Information"
                            $globalStats.RebootType = 'Manual'
                        }
                    }
                }
                'Soft'
                {
                    Write-Host "Soft reboot required. Returning code 3010." -ForegroundColor Yellow
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning exit code 3010 (soft reboot)" -LogLevel "Information"
                    $globalStats.RebootType = 'Soft'
                    return @{
                        ExitCode     = 3010
                        Statistics   = $globalStats
                        RebootNeeded = $true
                    }
                }
                'Hard'
                {
                    Write-Host "Hard reboot required. Returning code 1641." -ForegroundColor Yellow
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning exit code 1641 (hard reboot)" -LogLevel "Information"
                    $globalStats.RebootType = 'Hard'
                    return @{
                        ExitCode     = 1641
                        Statistics   = $globalStats
                        RebootNeeded = $true
                    }
                }
                'Delayed'
                {
                    Write-Host "Scheduling restart in $RebootTimeout seconds..." -ForegroundColor Yellow
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Scheduling delayed restart ($RebootTimeout seconds)" -LogLevel "Information"
                    & shutdown.exe /r /t $RebootTimeout /c "Restarting to complete Windows Updates"
                    $globalStats.RebootType = 'Delayed'
                }
                'None'
                {
                    Write-Host "Automatic restart disabled. Please restart manually." -ForegroundColor Yellow
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Reboot required but automatic restart disabled" -LogLevel "Warning"
                    $globalStats.RebootType = 'Manual'
                }
            }
        }
        else
        {
            Write-Host "No system restart required." -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "Operation completed successfully." -ForegroundColor Green
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Operation completed successfully in $([Math]::Round($totalDuration.TotalSeconds, 2)) seconds" -LogLevel "Information"
        
        # Determine return code
        $exitCode = if ($globalStats.TotalUpdatesFailed -eq 0 -and $globalStats.TotalUpdatesInstalled -eq 0)
        {
            0  # No updates available
        }
        elseif ($globalStats.TotalUpdatesFailed -eq 0)
        {
            0  # Success
        }
        elseif ($globalStats.TotalUpdatesInstalled -gt 0 -and $globalStats.TotalUpdatesFailed -gt 0)
        {
            1  # Partial success
        }
        else
        {
            2  # All failed
        }
        
        return @{
            ExitCode     = $exitCode
            Statistics   = $globalStats
            RebootNeeded = $globalStats.RebootRequired
        }
    }
    catch
    {
        $operationEndTime = Get-Date
        $operationDuration = if ($operationStartTime)
        {
            $operationEndTime - $operationStartTime 
        }
        else
        {
            [TimeSpan]::Zero 
        }
        
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "OPERATION FAILED" -LogLevel "Error"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error occurred at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))" -LogLevel "Error"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Operation duration before failure: $([Math]::Round($operationDuration.TotalSeconds, 2)) seconds" -LogLevel "Error"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error type: $($_.Exception.GetType().Name)" -LogLevel "Error"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error message: $($_.Exception.Message)" -LogLevel "Error"
        
        if ($_.Exception.InnerException)
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Inner exception: $($_.Exception.InnerException.Message)" -LogLevel "Error"
        }
        
        Write-Host ""
        Write-Host "ERROR: Windows Update operation failed" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""
        
        Write-Error "Windows Update operation failed: $($_.Exception.Message)"
        
        return @{
            ExitCode     = 999
            Statistics   = $globalStats
            RebootNeeded = $false
            Error        = $_.Exception.Message
        }
    }
}

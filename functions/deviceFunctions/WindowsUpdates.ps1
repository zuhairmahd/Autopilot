function GetInstalledWindowsUpdates()
{
    [CmdletBinding()]
    param()
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] =========================================="
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
    Write-Verbose "[$functionName] Starting Windows updates retrieval operation"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Starting Windows updates retrieval operation" -LogLevel "Information"
    Write-Verbose "[$functionName] =========================================="
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
    Write-Verbose "[$functionName] PowerShell version: $($PSVersionTable.PSVersion)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "PowerShell version: $($PSVersionTable.PSVersion)" -LogLevel "Information"
    Write-Verbose "[$functionName] Current user: $env:USERNAME"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Current user: $env:USERNAME" -LogLevel "Information"
    Write-Verbose "[$functionName] Computer name: $env:COMPUTERNAME"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Computer name: $env:COMPUTERNAME" -LogLevel "Information"
    Write-Verbose "[$functionName] Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -LogLevel "Information"
    
    $operationStartTime = Get-Date
    
    try
    {
        Write-Verbose "[$functionName] Attempting to retrieve installed Windows updates using Get-HotFix..."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Attempting to retrieve installed Windows updates using Get-HotFix..." -LogLevel "Information"
        Write-Verbose "[$functionName] This operation queries the Windows Update history from the system registry"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "This operation queries the Windows Update history from the system registry" -LogLevel "Information"
        
        $updates = Get-HotFix -ErrorAction Stop
        
        Write-Verbose "[$functionName] Successfully retrieved Windows updates information"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Successfully retrieved Windows updates information" -LogLevel "Information"
        Write-Verbose "[$functionName] Total updates found: $($updates.Count)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Total updates found: $($updates.Count)" -LogLevel "Information"
        
        if ($updates.Count -gt 0)
        {
            Write-Verbose "[$functionName] Update summary:"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Update summary:" -LogLevel "Information"
            $updates | ForEach-Object -Begin { $counter = 1 } -Process {
                Write-Verbose "[$functionName]   $counter. $($_.HotFixID) - $($_.Description) (Installed: $($_.InstalledOn))"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "$counter. $($_.HotFixID) - $($_.Description) (Installed: $($_.InstalledOn))" -LogLevel "Information"
                $counter++
                if ($counter -gt 10)
                {
                    Write-Verbose "[$functionName]   ... and $($updates.Count - 10) more updates (truncated for verbosity)"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "... and $($updates.Count - 10) more updates (truncated for verbosity)" -LogLevel "Information"
                    return
                }
            }
            
            # Group by type for summary
            $securityUpdates = $updates | Where-Object { $_.Description -like "*Security*" }
            $criticalUpdates = $updates | Where-Object { $_.Description -like "*Critical*" }
            $generalUpdates = $updates | Where-Object { $_.Description -notlike "*Security*" -and $_.Description -notlike "*Critical*" }
            
            Write-Verbose "[$functionName] Update breakdown:"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Update breakdown:" -LogLevel "Information"
            Write-Verbose "[$functionName]   - Security updates: $($securityUpdates.Count)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Security updates: $($securityUpdates.Count)" -LogLevel "Information"
            Write-Verbose "[$functionName]   - Critical updates: $($criticalUpdates.Count)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Critical updates: $($criticalUpdates.Count)" -LogLevel "Error"
            Write-Verbose "[$functionName]   - General updates: $($generalUpdates.Count)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "- General updates: $($generalUpdates.Count)" -LogLevel "Information"
            
            # Find most recent update
            $mostRecent = $updates | Sort-Object InstalledOn -Descending | Select-Object -First 1
            if ($mostRecent.InstalledOn)
            {
                Write-Verbose "[$functionName] Most recent update: $($mostRecent.HotFixID) installed on $($mostRecent.InstalledOn)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Most recent update: $($mostRecent.HotFixID) installed on $($mostRecent.InstalledOn)" -LogLevel "Information"
            }
        }
        else
        {
            Write-Verbose "[$functionName] No Windows updates found in the system"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No Windows updates found in the system" -LogLevel "Information"
            Write-Warning "No installed Windows updates were found. This may indicate:"
            Write-Warning "  - System is newly installed"
            Write-Warning "  - Windows Update service issues"
            Write-Warning "  - Registry access problems"
        }
        
        $operationEndTime = Get-Date
        $operationDuration = $operationEndTime - $operationStartTime
        Write-Verbose "[$functionName] =========================================="
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
        Write-Verbose "[$functionName] OPERATION COMPLETED SUCCESSFULLY"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "OPERATION COMPLETED SUCCESSFULLY" -LogLevel "Information"
        Write-Verbose "[$functionName] =========================================="
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
        Write-Verbose "[$functionName] Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))" -LogLevel "Information"
        Write-Verbose "[$functionName] Total operation time: $($operationDuration.TotalMilliseconds) milliseconds"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Total operation time: $($operationDuration.TotalMilliseconds) milliseconds" -LogLevel "Information"
        Write-Verbose "[$functionName] Returning $($updates.Count) Windows updates"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning $($updates.Count) Windows updates" -LogLevel "Information"
        
        return $updates
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
        
        Write-Verbose "[$functionName] =========================================="
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
        Write-Verbose "[$functionName] OPERATION FAILED"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "OPERATION FAILED" -LogLevel "Error"
        Write-Verbose "[$functionName] =========================================="
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
        Write-Verbose "[$functionName] Error occurred at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error occurred at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))" -LogLevel "Error"
        Write-Verbose "[$functionName] Operation duration before failure: $($operationDuration.TotalMilliseconds) milliseconds"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Operation duration before failure: $($operationDuration.TotalMilliseconds) milliseconds" -LogLevel "Information"
        Write-Verbose "[$functionName] Error type: $($_.Exception.GetType().Name)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error type: $($_.Exception.GetType().Name)" -LogLevel "Error"
        Write-Verbose "[$functionName] Error message: $($_.Exception.Message)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error message: $($_.Exception.Message)" -LogLevel "Error"
        
        if ($_.Exception.InnerException)
        {
            Write-Verbose "[$functionName] Inner exception: $($_.Exception.InnerException.Message)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Inner exception: $($_.Exception.InnerException.Message)" -LogLevel "Error"
        }
        
        Write-Error "Failed to retrieve Windows updates: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Returning null due to error"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning null due to error" -LogLevel "Error"
        return $null
    }
}

function ApplyWindowsUpdates()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)] 
        [ValidateSet('Soft', 'Hard', 'None', 'Delayed')] 
        [String] $Reboot = 'Soft',
        [Parameter(Mandatory = $False)] 
        [Int32] $RebootTimeout = 120,
        [Parameter(Mandatory = $False)] 
        [switch] $ExcludeDrivers,
        [Parameter(Mandatory = $False)] 
        [switch] $ExcludeUpdates,
        [Parameter(Mandatory = $False)]
        [switch]$noOptIn
    )

    $functionName = $MyInvocation.MyCommand.Name
    $returnObject = @{}
    Write-Verbose "[$functionName] =========================================="
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
    Write-Verbose "[$functionName] Starting Windows Update application process"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Starting Windows Update application process" -LogLevel "Information"
    Write-Verbose "[$functionName] =========================================="
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
    Write-Verbose "[$functionName] PowerShell version: $($PSVersionTable.PSVersion)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "PowerShell version: $($PSVersionTable.PSVersion)" -LogLevel "Information"
    Write-Verbose "[$functionName] Current user: $env:USERNAME"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Current user: $env:USERNAME" -LogLevel "Information"
    Write-Verbose "[$functionName] Computer name: $env:COMPUTERNAME"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Computer name: $env:COMPUTERNAME" -LogLevel "Information"
    Write-Verbose "[$functionName] Running as admin: $((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Running as admin: $((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))" -LogLevel "Information"
    Write-Verbose "[$functionName] Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -LogLevel "Information"
    Write-Verbose "[$functionName] Configuration parameters:"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Configuration parameters:" -LogLevel "Information"
    Write-Verbose "[$functionName]   - Reboot mode: $Reboot"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Reboot mode: $Reboot" -LogLevel "Information"
    Write-Verbose "[$functionName]   - Reboot timeout: $RebootTimeout seconds"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Reboot timeout: $RebootTimeout seconds" -LogLevel "Information"
    Write-Verbose "[$functionName]   - Exclude drivers: $ExcludeDrivers"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Exclude drivers: $ExcludeDrivers" -LogLevel "Information"
    Write-Verbose "[$functionName]   - Exclude updates: $ExcludeUpdates"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Exclude updates: $ExcludeUpdates" -LogLevel "Information"
    Write-Verbose "[$functionName]   - Skip Microsoft Update opt-in: $noOptIn"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Skip Microsoft Update opt-in: $noOptIn" -LogLevel "Information"
    $operationStartTime = Get-Date
    $needReboot = $false
    try
    {
        # Opt into Microsoft Update
        if (-not $noOptIn)
        {
            Write-Verbose "[$functionName] =========================================="
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
            Write-Verbose "[$functionName] MICROSOFT UPDATE OPT-IN PROCESS"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "MICROSOFT UPDATE OPT-IN PROCESS" -LogLevel "Information"
            Write-Verbose "[$functionName] =========================================="
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
            $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
            Write-Output "$ts Opting into Microsoft Update"
            Write-Verbose "[$functionName] Creating Microsoft Update ServiceManager COM object..."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Creating Microsoft Update ServiceManager COM object..." -LogLevel "Information"
            
            try
            {
                $ServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager"
                Write-Verbose "[$functionName] ServiceManager created successfully"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "ServiceManager created successfully" -LogLevel "Information"
                $ServiceID = "7971f918-a847-4430-9279-4a52d1efe18d"
                Write-Verbose "[$functionName] Microsoft Update Service ID: $ServiceID"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Microsoft Update Service ID: $ServiceID" -LogLevel "Information"
                Write-Verbose "[$functionName] Adding Microsoft Update service with authorization level 7..."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Adding Microsoft Update service with authorization level 7..." -LogLevel "Information"
                $ServiceManager.AddService2($ServiceID, 7, "") | Out-Null
                Write-Verbose "[$functionName] Microsoft Update service added successfully"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Microsoft Update service added successfully" -LogLevel "Information"
            }
            catch
            {
                Write-Verbose "[$functionName] Failed to opt into Microsoft Update: $($_.Exception.Message)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Failed to opt into Microsoft Update: $($_.Exception.Message)" -LogLevel "Error"
                Write-Warning "Could not opt into Microsoft Update. Continuing with existing update sources."
            }
        }
        else
        {
            Write-Verbose "[$functionName] Skipping Microsoft Update opt-in as requested (noOptIn = $noOptIn)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Skipping Microsoft Update opt-in as requested (noOptIn = $noOptIn)" -LogLevel "Information"
        }
        Write-Verbose "[$functionName] =========================================="
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
        Write-Verbose "[$functionName] WINDOWS UPDATE SESSION INITIALIZATION"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "WINDOWS UPDATE SESSION INITIALIZATION" -LogLevel "Information"
        Write-Verbose "[$functionName] =========================================="
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
        # Install all available updates
        Write-Verbose "[$functionName] Creating Windows Update session objects..."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Creating Windows Update session objects..." -LogLevel "Information"
        $WUDownloader = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateDownloader()
        $WUInstaller = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateInstaller()
        Write-Verbose "[$functionName] Update downloader and installer objects created successfully"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Update downloader and installer objects created successfully" -LogLevel "Information"
        # Determine search queries based on parameters
        if ($ExcludeDrivers)
        {
            # Updates only
            $queries = @("IsInstalled=0 and Type='Software'")
            Write-Verbose "[$functionName] Search mode: Software updates only (drivers excluded)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Search mode: Software updates only (drivers excluded)" -LogLevel "Information"
        }
        elseif ($ExcludeUpdates)
        {
            # Drivers only
            $queries = @("IsInstalled=0 and Type='Driver'")
            Write-Verbose "[$functionName] Search mode: Driver updates only (software updates excluded)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Search mode: Driver updates only (software updates excluded)" -LogLevel "Information"
        }
        else
        {
            # Both
            $queries = @("IsInstalled=0 and Type='Software'", "IsInstalled=0 and Type='Driver'")
            Write-Verbose "[$functionName] Search mode: Both software updates and drivers"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Search mode: Both software updates and drivers" -LogLevel "Information"
        }
        
        Write-Verbose "[$functionName] Search queries to execute:"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Search queries to execute:" -LogLevel "Information"
        $queries | ForEach-Object { Write-Verbose "[$functionName]   - $_" }
        Write-Verbose "[$functionName] =========================================="
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
        Write-Verbose "[$functionName] UPDATE SEARCH AND COLLECTION PROCESS"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "UPDATE SEARCH AND COLLECTION PROCESS" -LogLevel "Information"
        Write-Verbose "[$functionName] =========================================="
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
        $WUUpdates = New-Object -ComObject Microsoft.Update.UpdateColl
        $totalUpdatesFound = 0
        $skippedPreviewUpdates = 0
        $queries | ForEach-Object {
            $currentQuery = $_
            $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
            Write-Host "$ts Getting $currentQuery updates."
            Write-Verbose "[$functionName] Executing search query: $currentQuery"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Executing search query: $currentQuery" -LogLevel "Information"
            try
            {
                Write-Verbose "[$functionName] Creating update searcher for query: $currentQuery"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Creating update searcher for query: $currentQuery" -LogLevel "Information"
                $searchResult = (New-Object -ComObject Microsoft.Update.Session).CreateupdateSearcher().Search($currentQuery)
                Write-Verbose "[$functionName] Search completed. Found $($searchResult.Updates.Count) potential updates"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Search completed. Found $($searchResult.Updates.Count) potential updates" -LogLevel "Information"
                $searchResult.Updates | ForEach-Object {
                    $currentUpdate = $_
                    Write-Verbose "[$functionName] Processing update: $($currentUpdate.Title)"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Processing update: $($currentUpdate.Title)" -LogLevel "Verbose"
                    Write-Verbose "[$functionName]   - Update ID: $($currentUpdate.Identity.UpdateID)"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Update ID: $($currentUpdate.Identity.UpdateID)" -LogLevel "Information"
                    Write-Verbose "[$functionName]   - Revision: $($currentUpdate.Identity.RevisionNumber)"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Revision: $($currentUpdate.Identity.RevisionNumber)" -LogLevel "Information"
                    Write-Verbose "[$functionName]   - Size: $([Math]::Round($currentUpdate.MaxDownloadSize / 1MB, 2)) MB"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Size: $([Math]::Round($currentUpdate.MaxDownloadSize / 1MB, 2)) MB" -LogLevel "Information"
                    Write-Verbose "[$functionName]   - Is downloaded: $($currentUpdate.IsDownloaded)"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Is downloaded: $($currentUpdate.IsDownloaded)" -LogLevel "Information"
                    Write-Verbose "[$functionName]   - EULA accepted: $($currentUpdate.EulaAccepted)"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- EULA accepted: $($currentUpdate.EulaAccepted)" -LogLevel "Information"
                    
                    if (!$currentUpdate.EulaAccepted)
                    {
                        Write-Verbose "[$functionName]   - Accepting EULA for update: $($currentUpdate.Title)"
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Accepting EULA for update: $($currentUpdate.Title)" -LogLevel "Information"
                        $currentUpdate.AcceptEula()
                        Write-Verbose "[$functionName]   - EULA accepted successfully"
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "- EULA accepted successfully" -LogLevel "Information"
                    }
                    
                    $featureUpdate = $currentUpdate.Categories | Where-Object { $_.CategoryID -eq "3689BDC8-B205-4AF4-8D4A-A63924C5E9D5" }
                    if ($featureUpdate)
                    {
                        $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
                        Write-Host "$ts Skipping feature update: $($currentUpdate.Title)"
                        Write-Verbose "[$functionName] Skipped feature update (Category ID: 3689BDC8-B205-4AF4-8D4A-A63924C5E9D5)"
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Skipped feature update (Category ID: 3689BDC8-B205-4AF4-8D4A-A63924C5E9D5)" -LogLevel "Information"
                        $skippedFeatureUpdates++
                    }
                    elseif ($currentUpdate.Title -match "Preview")
                    { 
                        $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
                        Write-Host "$ts Skipping preview update: $($currentUpdate.Title)"
                        Write-Verbose "[$functionName] Skipped preview update (contains 'Preview' in title)"
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Skipped preview update (contains 'Preview' in title)" -LogLevel "Information"
                        $skippedPreviewUpdates++
                    }
                    else
                    {
                        Write-Verbose "[$functionName] Adding update to installation queue: $($currentUpdate.Title)"
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Adding update to installation queue: $($currentUpdate.Title)" -LogLevel "Information"
                        [void]$WUUpdates.Add($currentUpdate)
                        $totalUpdatesFound++
                    }
                }
            }
            catch
            {
                # If this script is running during specialize, error 8024004A will happen:
                # 8024004A	Windows Update agent operations are not available while OS setup is running.
                $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
                Write-Warning "$ts Unable to search for updates: $_"
                Write-Verbose "[$functionName] Search failed for query '$currentQuery': $($_.Exception.Message)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Search failed for query '$currentQuery': $($_.Exception.Message)" -LogLevel "Error"
                Write-Verbose "[$functionName] Error type: $($_.Exception.GetType().Name)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error type: $($_.Exception.GetType().Name)" -LogLevel "Error"
                
                if ($_.Exception.Message -like "*8024004A*")
                {
                    Write-Verbose "[$functionName] This appears to be error 8024004A - Windows Update operations not available during OS setup"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "This appears to be error 8024004A - Windows Update operations not available during OS setup" -LogLevel "Error"
                }
            }
        }
        Write-Verbose "[$functionName] =========================================="
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
        Write-Verbose "[$functionName] UPDATE SEARCH SUMMARY"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "UPDATE SEARCH SUMMARY" -LogLevel "Information"
        Write-Verbose "[$functionName] =========================================="
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
        Write-Verbose "[$functionName] Total updates found for installation: $totalUpdatesFound"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Total updates found for installation: $totalUpdatesFound" -LogLevel "Information"
        Write-Verbose "[$functionName] Feature updates skipped: $skippedFeatureUpdates"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Feature updates skipped: $skippedFeatureUpdates" -LogLevel "Information"
        Write-Verbose "[$functionName] Preview updates skipped: $skippedPreviewUpdates"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Preview updates skipped: $skippedPreviewUpdates" -LogLevel "Information"
        Write-Verbose "[$functionName] Updates in installation queue: $($WUUpdates.Count)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Updates in installation queue: $($WUUpdates.Count)" -LogLevel "Information"
        $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
        if ($WUUpdates.Count -eq 0)
        {
            Write-Host "$ts No Updates Found"
            Write-Verbose "[$functionName] No updates available for installation"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No updates available for installation" -LogLevel "Information"
            
            $operationEndTime = Get-Date
            $operationDuration = $operationEndTime - $operationStartTime
            Write-Verbose "[$functionName] =========================================="
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
            Write-Verbose "[$functionName] OPERATION COMPLETED - NO UPDATES"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "OPERATION COMPLETED - NO UPDATES" -LogLevel "Information"
            Write-Verbose "[$functionName] =========================================="
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
            Write-Verbose "[$functionName] Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))" -LogLevel "Information"
            Write-Verbose "[$functionName] Total operation time: $($operationDuration.TotalMilliseconds) milliseconds"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Total operation time: $($operationDuration.TotalMilliseconds) milliseconds" -LogLevel "Information"
            
            return 0
        }
        else
        {
            Write-Host "$ts Updates found: $($WUUpdates.count)"
            Write-Verbose "[$functionName] Proceeding with installation of $($WUUpdates.Count) updates"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Proceeding with installation of $($WUUpdates.Count) updates" -LogLevel "Information"
        }
        Write-Verbose "[$functionName] =========================================="
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
        Write-Verbose "[$functionName] UPDATE DOWNLOAD AND INSTALLATION PROCESS"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "UPDATE DOWNLOAD AND INSTALLATION PROCESS" -LogLevel "Information"
        Write-Verbose "[$functionName] =========================================="
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
        $updateCounter = 1
        $successfulInstalls = 0
        $failedInstalls = 0
        $totalDownloadSize = 0
        foreach ($update in $WUUpdates)
        {
            Write-Verbose "[$functionName] ----------------------------------------"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "----------------------------------------" -LogLevel "Information"
            Write-Verbose "[$functionName] Processing update $updateCounter of $($WUUpdates.Count)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Processing update $updateCounter of $($WUUpdates.Count)" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Update: $($update.Title)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Update: $($update.Title)" -LogLevel "Information"
            Write-Verbose "[$functionName] Size: $([Math]::Round($update.MaxDownloadSize / 1MB, 2)) MB"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Size: $([Math]::Round($update.MaxDownloadSize / 1MB, 2)) MB" -LogLevel "Information"
            Write-Verbose "[$functionName] ----------------------------------------"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "----------------------------------------" -LogLevel "Information"
            $singleUpdate = New-Object -ComObject Microsoft.Update.UpdateColl
            $singleUpdate.Add($update) | Out-Null
            $WUDownloader = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateDownloader()
            $WUDownloader.Updates = $singleUpdate
            $WUInstaller = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateInstaller()
            $WUInstaller.Updates = $singleUpdate
            $WUInstaller.ForceQuiet = $true
            Write-Verbose "[$functionName] Downloader and installer configured for single update"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Downloader and installer configured for single update" -LogLevel "Information"
            # Download phase
            $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
            Write-Output "$ts Downloading update: $($update.Title)"
            Write-Verbose "[$functionName] Starting download process..."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Starting download process..." -LogLevel "Information"
            try
            {
                $downloadStartTime = Get-Date
                $Download = $WUDownloader.Download()
                $downloadEndTime = Get-Date
                $downloadDuration = $downloadEndTime - $downloadStartTime
                $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
                Write-Host "$ts   Download result: $($Download.ResultCode) ($($Download.HResult))"
                Write-Verbose "[$functionName] Download completed in $($downloadDuration.TotalSeconds) seconds"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Download completed in $($downloadDuration.TotalSeconds) seconds" -LogLevel "Information"
                Write-Verbose "[$functionName] Download result code: $($Download.ResultCode)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Download result code: $($Download.ResultCode)" -LogLevel "Information"
                Write-Verbose "[$functionName] Download HRESULT: $($Download.HResult)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Download HRESULT: $($Download.HResult)" -LogLevel "Information"
                $totalDownloadSize += $update.MaxDownloadSize
                # Installation phase
                $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
                Write-Host "$ts Installing update: $($update.Title)"
                Write-Verbose "[$functionName] Starting installation process..."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Starting installation process..." -LogLevel "Information"
                $installStartTime = Get-Date
                $Results = $WUInstaller.Install()
                $installEndTime = Get-Date
                $installDuration = $installEndTime - $installStartTime
                $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
                Write-Host "$ts   Install result: $($Results.ResultCode) ($($Results.HResult))"
                Write-Verbose "[$functionName] Installation completed in $($installDuration.TotalSeconds) seconds"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Installation completed in $($installDuration.TotalSeconds) seconds" -LogLevel "Information"
                Write-Verbose "[$functionName] Installation result code: $($Results.ResultCode)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Installation result code: $($Results.ResultCode)" -LogLevel "Information"
                Write-Verbose "[$functionName] Installation HRESULT: $($Results.HResult)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Installation HRESULT: $($Results.HResult)" -LogLevel "Information"
                # result code 2 = success, see https://learn.microsoft.com/en-us/windows/win32/api/wuapi/ne-wuapi-operationresultcode
                if ($Results.ResultCode -eq 2)
                {
                    $successfulInstalls++
                    Write-Verbose "[$functionName] Update installed successfully"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Update installed successfully" -LogLevel "Information"
                }
                else
                {
                    $failedInstalls++
                    Write-Verbose "[$functionName] Update installation failed or incomplete (ResultCode: $($Results.ResultCode))"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Update installation failed or incomplete (ResultCode: $($Results.ResultCode))" -LogLevel "Error"
                }
                if ($Results.RebootRequired)
                {
                    $needReboot = $true
                    Write-Verbose "[$functionName] This update requires a system reboot"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "This update requires a system reboot" -LogLevel "Information"
                }
            }
            catch
            {
                $failedInstalls++
                Write-Verbose "[$functionName] Exception during update processing: $($_.Exception.Message)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Exception during update processing: $($_.Exception.Message)" -LogLevel "Error"
                Write-Warning "Failed to process update '$($update.Title)': $($_.Exception.Message)"
            }
            
            $updateCounter++
        }
        Write-Verbose "[$functionName] =========================================="
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
        Write-Verbose "[$functionName] INSTALLATION SUMMARY"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "INSTALLATION SUMMARY" -LogLevel "Information"
        Write-Verbose "[$functionName] =========================================="
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
        Write-Verbose "[$functionName] Total updates processed: $($WUUpdates.Count)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Total updates processed: $($WUUpdates.Count)" -LogLevel "Information"
        Write-Verbose "[$functionName] Successful installations: $successfulInstalls"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Successful installations: $successfulInstalls" -LogLevel "Information"
        Write-Verbose "[$functionName] Failed installations: $failedInstalls"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Failed installations: $failedInstalls" -LogLevel "Error"
        Write-Verbose "[$functionName] Total download size: $([Math]::Round($totalDownloadSize / 1MB, 2)) MB"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Total download size: $([Math]::Round($totalDownloadSize / 1MB, 2)) MB" -LogLevel "Information"
        Write-Verbose "[$functionName] Reboot required: $needReboot"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Reboot required: $needReboot" -LogLevel "Information"
        
        # Specify return code
        $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
        if ($needReboot)
        {
            Write-Host "$ts Windows Update indicated that a reboot is needed."
            Write-Verbose "[$functionName] System reboot is required to complete the update installation"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "System reboot is required to complete the update installation" -LogLevel "Information"
            $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
            if ($Reboot -eq "Hard")
            {
                Write-Host "$ts Exiting with return code 1641 to indicate a hard reboot is needed."
                Write-Verbose "[$functionName] Returning exit code 1641 (hard reboot required)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning exit code 1641 (hard reboot required)" -LogLevel "Information"
                $operationEndTime = Get-Date
                $operationDuration = $operationEndTime - $operationStartTime
                Write-Verbose "[$functionName] =========================================="
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
                Write-Verbose "[$functionName] OPERATION COMPLETED - HARD REBOOT REQUIRED"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "OPERATION COMPLETED - HARD REBOOT REQUIRED" -LogLevel "Information"
                Write-Verbose "[$functionName] =========================================="
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
                Write-Verbose "[$functionName] Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))" -LogLevel "Information"
                Write-Verbose "[$functionName] Total operation time: $($operationDuration.TotalMilliseconds) milliseconds"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Total operation time: $($operationDuration.TotalMilliseconds) milliseconds" -LogLevel "Information"
                return 1641
            }
            elseif ($Reboot -eq "Soft")
            {
                Write-Host "$ts Exiting with return code 3010 to indicate a soft reboot is needed."
                Write-Verbose "[$functionName] Returning exit code 3010 (soft reboot required)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning exit code 3010 (soft reboot required)" -LogLevel "Information"
                
                $operationEndTime = Get-Date
                $operationDuration = $operationEndTime - $operationStartTime
                Write-Verbose "[$functionName] =========================================="
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
                Write-Verbose "[$functionName] OPERATION COMPLETED - SOFT REBOOT REQUIRED"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "OPERATION COMPLETED - SOFT REBOOT REQUIRED" -LogLevel "Information"
                Write-Verbose "[$functionName] =========================================="
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
                Write-Verbose "[$functionName] Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))" -LogLevel "Information"
                Write-Verbose "[$functionName] Total operation time: $($operationDuration.TotalMilliseconds) milliseconds"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Total operation time: $($operationDuration.TotalMilliseconds) milliseconds" -LogLevel "Information"
                
                return 3010
            }
            elseif ($Reboot -eq "Delayed")
            {
                Write-Host "$ts Rebooting with a $RebootTimeout second delay"
                Write-Verbose "[$functionName] Initiating delayed reboot with $RebootTimeout second timeout"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Initiating delayed reboot with $RebootTimeout second timeout" -LogLevel "Information"
                Write-Verbose "[$functionName] Executing: shutdown.exe /r /t $RebootTimeout /c 'Rebooting to complete the installation of Windows updates.'"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Executing: shutdown.exe /r /t $RebootTimeout /c 'Rebooting to complete the installation of Windows updates.'" -LogLevel "Information"
                
                & shutdown.exe /r /t $RebootTimeout /c "Rebooting to complete the installation of Windows updates."
                
                $operationEndTime = Get-Date
                $operationDuration = $operationEndTime - $operationStartTime
                Write-Verbose "[$functionName] =========================================="
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
                Write-Verbose "[$functionName] OPERATION COMPLETED - DELAYED REBOOT INITIATED"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "OPERATION COMPLETED - DELAYED REBOOT INITIATED" -LogLevel "Information"
                Write-Verbose "[$functionName] =========================================="
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
                Write-Verbose "[$functionName] Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))" -LogLevel "Information"
                Write-Verbose "[$functionName] Total operation time: $($operationDuration.TotalMilliseconds) milliseconds"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Total operation time: $($operationDuration.TotalMilliseconds) milliseconds" -LogLevel "Information"
                Write-Verbose "[$functionName] System will reboot in $RebootTimeout seconds"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "System will reboot in $RebootTimeout seconds" -LogLevel "Information"
                
                return 0
            }
            elseif ($Reboot -eq "None")
            {
                Write-Verbose "[$functionName] Reboot required but reboot mode is 'None' - no automatic reboot will occur"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Reboot required but reboot mode is 'None' - no automatic reboot will occur" -LogLevel "Information"
                Write-Warning "A reboot is required to complete the updates, but automatic reboot is disabled."
                
                $operationEndTime = Get-Date
                $operationDuration = $operationEndTime - $operationStartTime
                Write-Verbose "[$functionName] =========================================="
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
                Write-Verbose "[$functionName] OPERATION COMPLETED - MANUAL REBOOT REQUIRED"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "OPERATION COMPLETED - MANUAL REBOOT REQUIRED" -LogLevel "Information"
                Write-Verbose "[$functionName] =========================================="
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
                Write-Verbose "[$functionName] Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))" -LogLevel "Information"
                Write-Verbose "[$functionName] Total operation time: $($operationDuration.TotalMilliseconds) milliseconds"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Total operation time: $($operationDuration.TotalMilliseconds) milliseconds" -LogLevel "Information"
                
                return 3010  # Indicate reboot needed but not performed
            }    
        }
        else
        {
            Write-Host "$ts Windows Update indicated that no reboot is required."
            Write-Verbose "[$functionName] No system reboot is required"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No system reboot is required" -LogLevel "Information"
        }
        $operationEndTime = Get-Date
        $operationDuration = $operationEndTime - $operationStartTime
        Write-Verbose "[$functionName] =========================================="
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
        Write-Verbose "[$functionName] OPERATION COMPLETED SUCCESSFULLY"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "OPERATION COMPLETED SUCCESSFULLY" -LogLevel "Information"
        Write-Verbose "[$functionName] =========================================="
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
        Write-Verbose "[$functionName] Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))" -LogLevel "Information"
        Write-Verbose "[$functionName] Total operation time: $($operationDuration.TotalMilliseconds) milliseconds"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Total operation time: $($operationDuration.TotalMilliseconds) milliseconds" -LogLevel "Information"
        Write-Verbose "[$functionName] Returning success code: 1000"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning success code: 1000" -LogLevel "Information"
        if ($failedInstalls -eq 0 -and $WUUpdates.Count -eq 0 -and $successfulInstalls -eq 0)
        {
            Write-Verbose "[$functionName] No updates found to install, returning code 1000"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No updates found to install, returning code 1000" -LogLevel "Information"
            $returnCode = 999
            Write-Verbose "[$functionName] No updates were found to install"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No updates were found to install" -LogLevel "Information"
        }
        elseif ($failedInstalls -eq 0 -and $WUUpdates.Count -eq $successfulInstalls)
        {
            $returnCode = 1000
            Write-Verbose "[$functionName] All updates downloaded successfully"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "All updates downloaded successfully" -LogLevel "Information"
        }
        elseif ($failedInstalls -eq 0 -and $successfulInstalls -lt $WUUpdates.Count -and $WUUpdates.Count -gt 0)
        {
            $returnCode = 1001
            Write-Verbose "[$functionName] Not all updates were installed successfully, but some updates were applied"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Not all updates were installed successfully, but some updates were applied" -LogLevel "Information"
        }
        elseif ($WUUpdates.Count -eq $failedInstalls -and $WUUpdates.Count -gt 0)
        {
            $returnCode = 1003
            Write-Verbose "[$functionName] All updates failed to install"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "All updates failed to install" -LogLevel "Error"
        }   
        else
        {
            $returnCode = 1002
            Write-Verbose "[$functionName] Some updates failed to install"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Some updates failed to install" -LogLevel "Error"
        }   
        $returnObject = @{
            TotalUpdatesProcessed   = $WUUpdates.Count
            SuccessfulInstallations = $successfulInstalls
            ReturnCode              = $returnCode
            FailedInstallations     = $failedInstalls
            RebootRequired          = $needReboot
        }        
        Write-Verbose "[$functionName] Returning object: $($returnObject | ConvertTo-Json -Depth $maxJSONDepth)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning object: $($returnObject | ConvertTo-Json -Depth $maxJSONDepth)" -LogLevel "Information"
        return $returnObject
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
        Write-Verbose "[$functionName] =========================================="
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
        Write-Verbose "[$functionName] OPERATION FAILED"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "OPERATION FAILED" -LogLevel "Error"
        Write-Verbose "[$functionName] =========================================="
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Information"
        Write-Verbose "[$functionName] Error occurred at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error occurred at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))" -LogLevel "Error"
        Write-Verbose "[$functionName] Operation duration before failure: $($operationDuration.TotalMilliseconds) milliseconds"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Operation duration before failure: $($operationDuration.TotalMilliseconds) milliseconds" -LogLevel "Information"
        Write-Verbose "[$functionName] Error type: $($_.Exception.GetType().Name)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error type: $($_.Exception.GetType().Name)" -LogLevel "Error"
        Write-Verbose "[$functionName] Error message: $($_.Exception.Message)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error message: $($_.Exception.Message)" -LogLevel "Error"
        if ($_.Exception.InnerException)
        {
            Write-Verbose "[$functionName] Inner exception: $($_.Exception.InnerException.Message)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Inner exception: $($_.Exception.InnerException.Message)" -LogLevel "Error"
        }
        # Log the full call stack for debugging
        Write-Verbose "[$functionName] Call stack:"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Call stack:" -LogLevel "Information"
        $_.ScriptStackTrace -split "`n" | ForEach-Object { Write-Verbose "[$functionName]   $_" }
        Write-Error "Windows Update operation failed: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Returning error code due to exception"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning error code due to exception" -LogLevel "Error"
        throw
    }
}

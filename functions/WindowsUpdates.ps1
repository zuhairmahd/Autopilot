function GetInstalledWindowsUpdates()
{
    [CmdletBinding()]
    param()
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] =========================================="
    Write-Verbose "[$functionName] Starting Windows updates retrieval operation"
    Write-Verbose "[$functionName] =========================================="
    Write-Verbose "[$functionName] PowerShell version: $($PSVersionTable.PSVersion)"
    Write-Verbose "[$functionName] Current user: $env:USERNAME"
    Write-Verbose "[$functionName] Computer name: $env:COMPUTERNAME"
    Write-Verbose "[$functionName] Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    
    $operationStartTime = Get-Date
    
    try
    {
        Write-Verbose "[$functionName] Attempting to retrieve installed Windows updates using Get-HotFix..."
        Write-Verbose "[$functionName] This operation queries the Windows Update history from the system registry"
        
        $updates = Get-HotFix -ErrorAction Stop
        
        Write-Verbose "[$functionName] Successfully retrieved Windows updates information"
        Write-Verbose "[$functionName] Total updates found: $($updates.Count)"
        
        if ($updates.Count -gt 0)
        {
            Write-Verbose "[$functionName] Update summary:"
            $updates | ForEach-Object -Begin { $counter = 1 } -Process {
                Write-Verbose "[$functionName]   $counter. $($_.HotFixID) - $($_.Description) (Installed: $($_.InstalledOn))"
                $counter++
                if ($counter -gt 10)
                {
                    Write-Verbose "[$functionName]   ... and $($updates.Count - 10) more updates (truncated for verbosity)"
                    return
                }
            }
            
            # Group by type for summary
            $securityUpdates = $updates | Where-Object { $_.Description -like "*Security*" }
            $criticalUpdates = $updates | Where-Object { $_.Description -like "*Critical*" }
            $generalUpdates = $updates | Where-Object { $_.Description -notlike "*Security*" -and $_.Description -notlike "*Critical*" }
            
            Write-Verbose "[$functionName] Update breakdown:"
            Write-Verbose "[$functionName]   - Security updates: $($securityUpdates.Count)"
            Write-Verbose "[$functionName]   - Critical updates: $($criticalUpdates.Count)"
            Write-Verbose "[$functionName]   - General updates: $($generalUpdates.Count)"
            
            # Find most recent update
            $mostRecent = $updates | Sort-Object InstalledOn -Descending | Select-Object -First 1
            if ($mostRecent.InstalledOn)
            {
                Write-Verbose "[$functionName] Most recent update: $($mostRecent.HotFixID) installed on $($mostRecent.InstalledOn)"
            }
        }
        else
        {
            Write-Verbose "[$functionName] No Windows updates found in the system"
            Write-Warning "No installed Windows updates were found. This may indicate:"
            Write-Warning "  - System is newly installed"
            Write-Warning "  - Windows Update service issues"
            Write-Warning "  - Registry access problems"
        }
        
        $operationEndTime = Get-Date
        $operationDuration = $operationEndTime - $operationStartTime
        Write-Verbose "[$functionName] =========================================="
        Write-Verbose "[$functionName] OPERATION COMPLETED SUCCESSFULLY"
        Write-Verbose "[$functionName] =========================================="
        Write-Verbose "[$functionName] Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
        Write-Verbose "[$functionName] Total operation time: $($operationDuration.TotalMilliseconds) milliseconds"
        Write-Verbose "[$functionName] Returning $($updates.Count) Windows updates"
        
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
        Write-Verbose "[$functionName] OPERATION FAILED"
        Write-Verbose "[$functionName] =========================================="
        Write-Verbose "[$functionName] Error occurred at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
        Write-Verbose "[$functionName] Operation duration before failure: $($operationDuration.TotalMilliseconds) milliseconds"
        Write-Verbose "[$functionName] Error type: $($_.Exception.GetType().Name)"
        Write-Verbose "[$functionName] Error message: $($_.Exception.Message)"
        
        if ($_.Exception.InnerException)
        {
            Write-Verbose "[$functionName] Inner exception: $($_.Exception.InnerException.Message)"
        }
        
        Write-Error "Failed to retrieve Windows updates: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Returning null due to error"
        return $null
    }
}

function ApplyWindowsUpdates()
{
    [CmdletBinding()]
    Param(
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
    Write-Verbose "[$functionName] Starting Windows Update application process"
    Write-Verbose "[$functionName] =========================================="
    Write-Verbose "[$functionName] PowerShell version: $($PSVersionTable.PSVersion)"
    Write-Verbose "[$functionName] Current user: $env:USERNAME"
    Write-Verbose "[$functionName] Computer name: $env:COMPUTERNAME"
    Write-Verbose "[$functionName] Running as admin: $((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))"
    Write-Verbose "[$functionName] Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Verbose "[$functionName] Configuration parameters:"
    Write-Verbose "[$functionName]   - Reboot mode: $Reboot"
    Write-Verbose "[$functionName]   - Reboot timeout: $RebootTimeout seconds"
    Write-Verbose "[$functionName]   - Exclude drivers: $ExcludeDrivers"
    Write-Verbose "[$functionName]   - Exclude updates: $ExcludeUpdates"
    Write-Verbose "[$functionName]   - Skip Microsoft Update opt-in: $noOptIn"
    $operationStartTime = Get-Date
    $needReboot = $false
    try
    {
        # Opt into Microsoft Update
        if (-not $noOptIn)
        {
            Write-Verbose "[$functionName] =========================================="
            Write-Verbose "[$functionName] MICROSOFT UPDATE OPT-IN PROCESS"
            Write-Verbose "[$functionName] =========================================="
            $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
            Write-Output "$ts Opting into Microsoft Update"
            Write-Verbose "[$functionName] Creating Microsoft Update ServiceManager COM object..."
            
            try
            {
                $ServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager"
                Write-Verbose "[$functionName] ServiceManager created successfully"
                $ServiceID = "7971f918-a847-4430-9279-4a52d1efe18d"
                Write-Verbose "[$functionName] Microsoft Update Service ID: $ServiceID"
                Write-Verbose "[$functionName] Adding Microsoft Update service with authorization level 7..."
                $ServiceManager.AddService2($ServiceID, 7, "") | Out-Null
                Write-Verbose "[$functionName] Microsoft Update service added successfully"
            }
            catch
            {
                Write-Verbose "[$functionName] Failed to opt into Microsoft Update: $($_.Exception.Message)"
                Write-Warning "Could not opt into Microsoft Update. Continuing with existing update sources."
            }
        }
        else
        {
            Write-Verbose "[$functionName] Skipping Microsoft Update opt-in as requested (noOptIn = $noOptIn)"
        }
        Write-Verbose "[$functionName] =========================================="
        Write-Verbose "[$functionName] WINDOWS UPDATE SESSION INITIALIZATION"
        Write-Verbose "[$functionName] =========================================="
        # Install all available updates
        Write-Verbose "[$functionName] Creating Windows Update session objects..."
        $WUDownloader = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateDownloader()
        $WUInstaller = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateInstaller()
        Write-Verbose "[$functionName] Update downloader and installer objects created successfully"
        # Determine search queries based on parameters
        if ($ExcludeDrivers)
        {
            # Updates only
            $queries = @("IsInstalled=0 and Type='Software'")
            Write-Verbose "[$functionName] Search mode: Software updates only (drivers excluded)"
        }
        elseif ($ExcludeUpdates)
        {
            # Drivers only
            $queries = @("IsInstalled=0 and Type='Driver'")
            Write-Verbose "[$functionName] Search mode: Driver updates only (software updates excluded)"
        }
        else
        {
            # Both
            $queries = @("IsInstalled=0 and Type='Software'", "IsInstalled=0 and Type='Driver'")
            Write-Verbose "[$functionName] Search mode: Both software updates and drivers"
        }
        
        Write-Verbose "[$functionName] Search queries to execute:"
        $queries | ForEach-Object { Write-Verbose "[$functionName]   - $_" }
        Write-Verbose "[$functionName] =========================================="
        Write-Verbose "[$functionName] UPDATE SEARCH AND COLLECTION PROCESS"
        Write-Verbose "[$functionName] =========================================="
        $WUUpdates = New-Object -ComObject Microsoft.Update.UpdateColl
        $totalUpdatesFound = 0
        $skippedPreviewUpdates = 0
        $queries | ForEach-Object {
            $currentQuery = $_
            $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
            Write-Host "$ts Getting $currentQuery updates."
            Write-Verbose "[$functionName] Executing search query: $currentQuery"
            try
            {
                Write-Verbose "[$functionName] Creating update searcher for query: $currentQuery"
                $searchResult = (New-Object -ComObject Microsoft.Update.Session).CreateupdateSearcher().Search($currentQuery)
                Write-Verbose "[$functionName] Search completed. Found $($searchResult.Updates.Count) potential updates"
                $searchResult.Updates | ForEach-Object {
                    $currentUpdate = $_
                    Write-Verbose "[$functionName] Processing update: $($currentUpdate.Title)"
                    Write-Verbose "[$functionName]   - Update ID: $($currentUpdate.Identity.UpdateID)"
                    Write-Verbose "[$functionName]   - Revision: $($currentUpdate.Identity.RevisionNumber)"
                    Write-Verbose "[$functionName]   - Size: $([Math]::Round($currentUpdate.MaxDownloadSize / 1MB, 2)) MB"
                    Write-Verbose "[$functionName]   - Is downloaded: $($currentUpdate.IsDownloaded)"
                    Write-Verbose "[$functionName]   - EULA accepted: $($currentUpdate.EulaAccepted)"
                    
                    if (!$currentUpdate.EulaAccepted)
                    {
                        Write-Verbose "[$functionName]   - Accepting EULA for update: $($currentUpdate.Title)"
                        $currentUpdate.AcceptEula()
                        Write-Verbose "[$functionName]   - EULA accepted successfully"
                    }
                    
                    $featureUpdate = $currentUpdate.Categories | Where-Object { $_.CategoryID -eq "3689BDC8-B205-4AF4-8D4A-A63924C5E9D5" }
                    if ($featureUpdate)
                    {
                        $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
                        Write-Host "$ts Skipping feature update: $($currentUpdate.Title)"
                        Write-Verbose "[$functionName] Skipped feature update (Category ID: 3689BDC8-B205-4AF4-8D4A-A63924C5E9D5)"
                        $skippedFeatureUpdates++
                    }
                    elseif ($currentUpdate.Title -match "Preview")
                    { 
                        $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
                        Write-Host "$ts Skipping preview update: $($currentUpdate.Title)"
                        Write-Verbose "[$functionName] Skipped preview update (contains 'Preview' in title)"
                        $skippedPreviewUpdates++
                    }
                    else
                    {
                        Write-Verbose "[$functionName] Adding update to installation queue: $($currentUpdate.Title)"
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
                Write-Verbose "[$functionName] Error type: $($_.Exception.GetType().Name)"
                
                if ($_.Exception.Message -like "*8024004A*")
                {
                    Write-Verbose "[$functionName] This appears to be error 8024004A - Windows Update operations not available during OS setup"
                }
            }
        }
        Write-Verbose "[$functionName] =========================================="
        Write-Verbose "[$functionName] UPDATE SEARCH SUMMARY"
        Write-Verbose "[$functionName] =========================================="
        Write-Verbose "[$functionName] Total updates found for installation: $totalUpdatesFound"
        Write-Verbose "[$functionName] Feature updates skipped: $skippedFeatureUpdates"
        Write-Verbose "[$functionName] Preview updates skipped: $skippedPreviewUpdates"
        Write-Verbose "[$functionName] Updates in installation queue: $($WUUpdates.Count)"
        $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
        if ($WUUpdates.Count -eq 0)
        {
            Write-Host "$ts No Updates Found"
            Write-Verbose "[$functionName] No updates available for installation"
            
            $operationEndTime = Get-Date
            $operationDuration = $operationEndTime - $operationStartTime
            Write-Verbose "[$functionName] =========================================="
            Write-Verbose "[$functionName] OPERATION COMPLETED - NO UPDATES"
            Write-Verbose "[$functionName] =========================================="
            Write-Verbose "[$functionName] Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
            Write-Verbose "[$functionName] Total operation time: $($operationDuration.TotalMilliseconds) milliseconds"
            
            Return 0
        }
        else
        {
            Write-Host "$ts Updates found: $($WUUpdates.count)"
            Write-Verbose "[$functionName] Proceeding with installation of $($WUUpdates.Count) updates"
        }
        Write-Verbose "[$functionName] =========================================="
        Write-Verbose "[$functionName] UPDATE DOWNLOAD AND INSTALLATION PROCESS"
        Write-Verbose "[$functionName] =========================================="
        $updateCounter = 1
        $successfulInstalls = 0
        $failedInstalls = 0
        $totalDownloadSize = 0
        foreach ($update in $WUUpdates)
        {
            Write-Verbose "[$functionName] ----------------------------------------"
            Write-Verbose "[$functionName] Processing update $updateCounter of $($WUUpdates.Count)"
            Write-Verbose "[$functionName] Update: $($update.Title)"
            Write-Verbose "[$functionName] Size: $([Math]::Round($update.MaxDownloadSize / 1MB, 2)) MB"
            Write-Verbose "[$functionName] ----------------------------------------"
            $singleUpdate = New-Object -ComObject Microsoft.Update.UpdateColl
            $singleUpdate.Add($update) | Out-Null
            $WUDownloader = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateDownloader()
            $WUDownloader.Updates = $singleUpdate
            $WUInstaller = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateInstaller()
            $WUInstaller.Updates = $singleUpdate
            $WUInstaller.ForceQuiet = $true
            Write-Verbose "[$functionName] Downloader and installer configured for single update"
            # Download phase
            $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
            Write-Output "$ts Downloading update: $($update.Title)"
            Write-Verbose "[$functionName] Starting download process..."
            try
            {
                $downloadStartTime = Get-Date
                $Download = $WUDownloader.Download()
                $downloadEndTime = Get-Date
                $downloadDuration = $downloadEndTime - $downloadStartTime
                $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
                Write-Host "$ts   Download result: $($Download.ResultCode) ($($Download.HResult))"
                Write-Verbose "[$functionName] Download completed in $($downloadDuration.TotalSeconds) seconds"
                Write-Verbose "[$functionName] Download result code: $($Download.ResultCode)"
                Write-Verbose "[$functionName] Download HRESULT: $($Download.HResult)"
                $totalDownloadSize += $update.MaxDownloadSize
                # Installation phase
                $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
                Write-Host "$ts Installing update: $($update.Title)"
                Write-Verbose "[$functionName] Starting installation process..."
                $installStartTime = Get-Date
                $Results = $WUInstaller.Install()
                $installEndTime = Get-Date
                $installDuration = $installEndTime - $installStartTime
                $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
                Write-Host "$ts   Install result: $($Results.ResultCode) ($($Results.HResult))"
                Write-Verbose "[$functionName] Installation completed in $($installDuration.TotalSeconds) seconds"
                Write-Verbose "[$functionName] Installation result code: $($Results.ResultCode)"
                Write-Verbose "[$functionName] Installation HRESULT: $($Results.HResult)"
                # result code 2 = success, see https://learn.microsoft.com/en-us/windows/win32/api/wuapi/ne-wuapi-operationresultcode
                if ($Results.ResultCode -eq 2)
                {
                    $successfulInstalls++
                    Write-Verbose "[$functionName] Update installed successfully"
                }
                else
                {
                    $failedInstalls++
                    Write-Verbose "[$functionName] Update installation failed or incomplete (ResultCode: $($Results.ResultCode))"
                }
                if ($Results.RebootRequired)
                {
                    $needReboot = $true
                    Write-Verbose "[$functionName] This update requires a system reboot"
                }
            }
            catch
            {
                $failedInstalls++
                Write-Verbose "[$functionName] Exception during update processing: $($_.Exception.Message)"
                Write-Warning "Failed to process update '$($update.Title)': $($_.Exception.Message)"
            }
            
            $updateCounter++
        }
        Write-Verbose "[$functionName] =========================================="
        Write-Verbose "[$functionName] INSTALLATION SUMMARY"
        Write-Verbose "[$functionName] =========================================="
        Write-Verbose "[$functionName] Total updates processed: $($WUUpdates.Count)"
        Write-Verbose "[$functionName] Successful installations: $successfulInstalls"
        Write-Verbose "[$functionName] Failed installations: $failedInstalls"
        Write-Verbose "[$functionName] Total download size: $([Math]::Round($totalDownloadSize / 1MB, 2)) MB"
        Write-Verbose "[$functionName] Reboot required: $needReboot"
        
        # Specify return code
        $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
        if ($needReboot)
        {
            Write-Host "$ts Windows Update indicated that a reboot is needed."
            Write-Verbose "[$functionName] System reboot is required to complete the update installation"
            $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
            if ($Reboot -eq "Hard")
            {
                Write-Host "$ts Exiting with return code 1641 to indicate a hard reboot is needed."
                Write-Verbose "[$functionName] Returning exit code 1641 (hard reboot required)"
                $operationEndTime = Get-Date
                $operationDuration = $operationEndTime - $operationStartTime
                Write-Verbose "[$functionName] =========================================="
                Write-Verbose "[$functionName] OPERATION COMPLETED - HARD REBOOT REQUIRED"
                Write-Verbose "[$functionName] =========================================="
                Write-Verbose "[$functionName] Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
                Write-Verbose "[$functionName] Total operation time: $($operationDuration.TotalMilliseconds) milliseconds"
                Return 1641
            }
            elseif ($Reboot -eq "Soft")
            {
                Write-Host "$ts Exiting with return code 3010 to indicate a soft reboot is needed."
                Write-Verbose "[$functionName] Returning exit code 3010 (soft reboot required)"
                
                $operationEndTime = Get-Date
                $operationDuration = $operationEndTime - $operationStartTime
                Write-Verbose "[$functionName] =========================================="
                Write-Verbose "[$functionName] OPERATION COMPLETED - SOFT REBOOT REQUIRED"
                Write-Verbose "[$functionName] =========================================="
                Write-Verbose "[$functionName] Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
                Write-Verbose "[$functionName] Total operation time: $($operationDuration.TotalMilliseconds) milliseconds"
                
                Return 3010
            }
            elseif ($Reboot -eq "Delayed")
            {
                Write-Host "$ts Rebooting with a $RebootTimeout second delay"
                Write-Verbose "[$functionName] Initiating delayed reboot with $RebootTimeout second timeout"
                Write-Verbose "[$functionName] Executing: shutdown.exe /r /t $RebootTimeout /c 'Rebooting to complete the installation of Windows updates.'"
                
                & shutdown.exe /r /t $RebootTimeout /c "Rebooting to complete the installation of Windows updates."
                
                $operationEndTime = Get-Date
                $operationDuration = $operationEndTime - $operationStartTime
                Write-Verbose "[$functionName] =========================================="
                Write-Verbose "[$functionName] OPERATION COMPLETED - DELAYED REBOOT INITIATED"
                Write-Verbose "[$functionName] =========================================="
                Write-Verbose "[$functionName] Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
                Write-Verbose "[$functionName] Total operation time: $($operationDuration.TotalMilliseconds) milliseconds"
                Write-Verbose "[$functionName] System will reboot in $RebootTimeout seconds"
                
                Return 0
            }
            elseif ($Reboot -eq "None")
            {
                Write-Verbose "[$functionName] Reboot required but reboot mode is 'None' - no automatic reboot will occur"
                Write-Warning "A reboot is required to complete the updates, but automatic reboot is disabled."
                
                $operationEndTime = Get-Date
                $operationDuration = $operationEndTime - $operationStartTime
                Write-Verbose "[$functionName] =========================================="
                Write-Verbose "[$functionName] OPERATION COMPLETED - MANUAL REBOOT REQUIRED"
                Write-Verbose "[$functionName] =========================================="
                Write-Verbose "[$functionName] Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
                Write-Verbose "[$functionName] Total operation time: $($operationDuration.TotalMilliseconds) milliseconds"
                
                Return 3010  # Indicate reboot needed but not performed
            }    
        }
        else
        {
            Write-Host "$ts Windows Update indicated that no reboot is required."
            Write-Verbose "[$functionName] No system reboot is required"
        }
        $operationEndTime = Get-Date
        $operationDuration = $operationEndTime - $operationStartTime
        Write-Verbose "[$functionName] =========================================="
        Write-Verbose "[$functionName] OPERATION COMPLETED SUCCESSFULLY"
        Write-Verbose "[$functionName] =========================================="
        Write-Verbose "[$functionName] Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
        Write-Verbose "[$functionName] Total operation time: $($operationDuration.TotalMilliseconds) milliseconds"
        Write-Verbose "[$functionName] Returning success code: 1000"
        if ($failedInstalls -eq 0 -and $WUUpdates.Count -eq 0 -and $successfulInstalls -eq 0)
        {
            Write-Verbose "[$functionName] No updates found to install, returning code 1000"
            $returnCode = 999
            Write-Verbose "[$functionName] No updates were found to install"
        }
        elseif ($failedInstalls -eq 0 -and $WUUpdates.Count -eq $successfulInstalls)
        {
            $returnCode = 1000
            Write-Verbose "[$functionName] All updates downloaded successfully"
        }
        elseif ($failedInstalls -eq 0 -and $successfulInstalls -lt $WUUpdates.Count -and $WUUpdates.Count -gt 0)
        {
            $returnCode = 1001
            Write-Verbose "[$functionName] Not all updates were installed successfully, but some updates were applied"
        }
        elseif ($WUUpdates.Count -eq $failedInstalls -and $WUUpdates.Count -gt 0)
        {
            $returnCode = 1003
            Write-Verbose "[$functionName] All updates failed to install"
        }   
        else
        {
            $returnCode = 1002
            Write-Verbose "[$functionName] Some updates failed to install"
        }   
        $returnObject = @{
            TotalUpdatesProcessed   = $WUUpdates.Count
            SuccessfulInstallations = $successfulInstalls
            ReturnCode              = $returnCode
            FailedInstallations     = $failedInstalls
            RebootRequired          = $needReboot
        }        
        Write-Verbose "[$functionName] Returning object: $($returnObject | ConvertTo-Json -Depth 3)"
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
        Write-Verbose "[$functionName] OPERATION FAILED"
        Write-Verbose "[$functionName] =========================================="
        Write-Verbose "[$functionName] Error occurred at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
        Write-Verbose "[$functionName] Operation duration before failure: $($operationDuration.TotalMilliseconds) milliseconds"
        Write-Verbose "[$functionName] Error type: $($_.Exception.GetType().Name)"
        Write-Verbose "[$functionName] Error message: $($_.Exception.Message)"
        if ($_.Exception.InnerException)
        {
            Write-Verbose "[$functionName] Inner exception: $($_.Exception.InnerException.Message)"
        }
        # Log the full call stack for debugging
        Write-Verbose "[$functionName] Call stack:"
        $_.ScriptStackTrace -split "`n" | ForEach-Object { Write-Verbose "[$functionName]   $_" }
        Write-Error "Windows Update operation failed: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Returning error code due to exception"
        throw
    }
}
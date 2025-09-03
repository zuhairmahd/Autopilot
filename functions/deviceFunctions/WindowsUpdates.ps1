function GetInstalledWindowsUpdates()
{
    [CmdletBinding()]
    param()
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Starting Windows updates retrieval operation" -LogLevel "Verbose"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "PowerShell version: $($PSVersionTable.PSVersion)" -LogLevel "Debug"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Current user: $env:USERNAME" -LogLevel "Debug"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Computer name: $env:COMPUTERNAME" -LogLevel "Debug"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -LogLevel "Debug"
    
    $operationStartTime = Get-Date
    
    try
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Attempting to retrieve installed Windows updates using Get-HotFix..." -LogLevel "Verbose"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "This operation queries the Windows Update history from the system registry" -LogLevel "Debug"
        
        $updates = Get-HotFix -ErrorAction Stop
        
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Successfully retrieved Windows updates information" -LogLevel "Information"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Total updates found: $($updates.Count)" -LogLevel "Verbose"
        
        if ($updates.Count -gt 0)
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Update summary:" -LogLevel "Verbose"
            $updates | ForEach-Object -Begin { $counter = 1 } -Process {
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "$counter. $($_.HotFixID) - $($_.Description) (Installed: $($_.InstalledOn))" -LogLevel "Debug"
                $counter++
                if ($counter -gt 10)
                {
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "... and $($updates.Count - 10) more updates (truncated for verbosity)" -LogLevel "Debug"
                    return
                }
            }
            
            # Group by type for summary
            $securityUpdates = $updates | Where-Object { $_.Description -like "*Security*" }
            $criticalUpdates = $updates | Where-Object { $_.Description -like "*Critical*" }
            $generalUpdates = $updates | Where-Object { $_.Description -notlike "*Security*" -and $_.Description -notlike "*Critical*" }
            
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Update breakdown:" -LogLevel "Verbose"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Security updates: $($securityUpdates.Count)" -LogLevel "Information"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Critical updates: $($criticalUpdates.Count)" -LogLevel "Warning"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "- General updates: $($generalUpdates.Count)" -LogLevel "Verbose"
            
            # Find most recent update
            $mostRecent = $updates | Sort-Object InstalledOn -Descending | Select-Object -First 1
            if ($mostRecent.InstalledOn)
            {
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Most recent update: $($mostRecent.HotFixID) installed on $($mostRecent.InstalledOn)" -LogLevel "Information"
            }
        }
        else
        {
Write-Log -LogFile $LogFile -Module "$functionName" -Message "No Windows updates found in the system" -LogLevel "Verbose"
            Write-Warning "No installed Windows updates were found. This may indicate:"
            Write-Warning "  - System is newly installed"
            Write-Warning "  - Windows Update service issues"
            Write-Warning "  - Registry access problems"
        }
        
        $operationEndTime = Get-Date
        $operationDuration = $operationEndTime - $operationStartTime
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "OPERATION COMPLETED SUCCESSFULLY" -LogLevel "Information"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))" -LogLevel "Debug"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Total operation time: $($operationDuration.TotalMilliseconds) milliseconds" -LogLevel "Verbose"
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
        
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "OPERATION FAILED" -LogLevel "Information"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error occurred at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))" -LogLevel "Error"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Operation duration before failure: $($operationDuration.TotalMilliseconds) milliseconds" -LogLevel "Verbose"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error type: $($_.Exception.GetType().Name)" -LogLevel "Error"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error message: $($_.Exception.Message)" -LogLevel "Error"
        
        if ($_.Exception.InnerException)
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Inner exception: $($_.Exception.InnerException.Message)" -LogLevel "Error"
        }
        
        Write-Error "Failed to retrieve Windows updates: $($_.Exception.Message)"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning null due to error" -LogLevel "Information"
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
Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Starting Windows Update application process" -LogLevel "Verbose"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "PowerShell version: $($PSVersionTable.PSVersion)" -LogLevel "Debug"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Current user: $env:USERNAME" -LogLevel "Debug"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Computer name: $env:COMPUTERNAME" -LogLevel "Debug"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Running as admin: $((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))" -LogLevel "Information"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -LogLevel "Debug"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Configuration parameters:" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Reboot mode: $Reboot" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Reboot timeout: $RebootTimeout seconds" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Exclude drivers: $ExcludeDrivers" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Exclude updates: $ExcludeUpdates" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Skip Microsoft Update opt-in: $noOptIn" -LogLevel "Information"
    $operationStartTime = Get-Date
    $needReboot = $false
    try
    {
        # Opt into Microsoft Update
        if (-not $noOptIn)
        {
Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "MICROSOFT UPDATE OPT-IN PROCESS" -LogLevel "Information"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
            $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
            Write-Output "$ts Opting into Microsoft Update"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Creating Microsoft Update ServiceManager COM object..." -LogLevel "Information"
            
            try
            {
                $ServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "ServiceManager created successfully" -LogLevel "Information"
                $ServiceID = "7971f918-a847-4430-9279-4a52d1efe18d"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Microsoft Update Service ID: $ServiceID" -LogLevel "Information"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Adding Microsoft Update service with authorization level 7..." -LogLevel "Information"
                $ServiceManager.AddService2($ServiceID, 7, "") | Out-Null
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Microsoft Update service added successfully" -LogLevel "Information"
            }
            catch
            {
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Failed to opt into Microsoft Update: $($_.Exception.Message)" -LogLevel "Error"
                Write-Warning "Could not opt into Microsoft Update. Continuing with existing update sources."
            }
        }
        else
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Skipping Microsoft Update opt-in as requested (noOptIn = $noOptIn)" -LogLevel "Information"
        }
Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "WINDOWS UPDATE SESSION INITIALIZATION" -LogLevel "Information"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
        # Install all available updates
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Creating Windows Update session objects..." -LogLevel "Information"
        $WUDownloader = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateDownloader()
        $WUInstaller = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateInstaller()
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Update downloader and installer objects created successfully" -LogLevel "Information"
        # Determine search queries based on parameters
        if ($ExcludeDrivers)
        {
            # Updates only
            $queries = @("IsInstalled=0 and Type='Software'")
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Search mode: Software updates only (drivers excluded)" -LogLevel "Information"
        }
        elseif ($ExcludeUpdates)
        {
            # Drivers only
            $queries = @("IsInstalled=0 and Type='Driver'")
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Search mode: Driver updates only (software updates excluded)" -LogLevel "Information"
        }
        else
        {
            # Both
            $queries = @("IsInstalled=0 and Type='Software'", "IsInstalled=0 and Type='Driver'")
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Search mode: Both software updates and drivers" -LogLevel "Information"
        }
        
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Search queries to execute:" -LogLevel "Information"
        $queries | ForEach-Object { Write-Verbose "[$functionName]   - $_" }
Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "UPDATE SEARCH AND COLLECTION PROCESS" -LogLevel "Information"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
        $WUUpdates = New-Object -ComObject Microsoft.Update.UpdateColl
        $totalUpdatesFound = 0
        $skippedPreviewUpdates = 0
        $queries | ForEach-Object {
            $currentQuery = $_
            $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
            Write-Host "$ts Getting $currentQuery updates."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Executing search query: $currentQuery" -LogLevel "Information"
            try
            {
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Creating update searcher for query: $currentQuery" -LogLevel "Information"
                $searchResult = (New-Object -ComObject Microsoft.Update.Session).CreateupdateSearcher().Search($currentQuery)
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Search completed. Found $($searchResult.Updates.Count) potential updates" -LogLevel "Verbose"
                $searchResult.Updates | ForEach-Object {
                    $currentUpdate = $_
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Processing update: $($currentUpdate.Title)" -LogLevel "Verbose"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Update ID: $($currentUpdate.Identity.UpdateID)" -LogLevel "Information"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Revision: $($currentUpdate.Identity.RevisionNumber)" -LogLevel "Information"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Size: $([Math]::Round($currentUpdate.MaxDownloadSize / 1MB, 2)) MB" -LogLevel "Information"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Is downloaded: $($currentUpdate.IsDownloaded)" -LogLevel "Information"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "- EULA accepted: $($currentUpdate.EulaAccepted)" -LogLevel "Information"
                    
                    if (!$currentUpdate.EulaAccepted)
                    {
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "- Accepting EULA for update: $($currentUpdate.Title)" -LogLevel "Information"
                        $currentUpdate.AcceptEula()
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "- EULA accepted successfully" -LogLevel "Information"
                    }
                    
                    $featureUpdate = $currentUpdate.Categories | Where-Object { $_.CategoryID -eq "3689BDC8-B205-4AF4-8D4A-A63924C5E9D5" }
                    if ($featureUpdate)
                    {
                        $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
                        Write-Host "$ts Skipping feature update: $($currentUpdate.Title)"
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Skipped feature update (Category ID: 3689BDC8-B205-4AF4-8D4A-A63924C5E9D5)" -LogLevel "Information"
                        $skippedFeatureUpdates++
                    }
                    elseif ($currentUpdate.Title -match "Preview")
                    { 
                        $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
                        Write-Host "$ts Skipping preview update: $($currentUpdate.Title)"
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Skipped preview update (contains 'Preview' in title)" -LogLevel "Information"
                        $skippedPreviewUpdates++
                    }
                    else
                    {
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
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Search failed for query '$currentQuery': $($_.Exception.Message)" -LogLevel "Error"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error type: $($_.Exception.GetType().Name)" -LogLevel "Error"
                
                if ($_.Exception.Message -like "*8024004A*")
                {
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "This appears to be error 8024004A - Windows Update operations not available during OS setup" -LogLevel "Error"
                }
            }
        }
Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "UPDATE SEARCH SUMMARY" -LogLevel "Verbose"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Total updates found for installation: $totalUpdatesFound" -LogLevel "Verbose"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Feature updates skipped: $skippedFeatureUpdates" -LogLevel "Information"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Preview updates skipped: $skippedPreviewUpdates" -LogLevel "Information"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Updates in installation queue: $($WUUpdates.Count)" -LogLevel "Information"
        $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
        if ($WUUpdates.Count -eq 0)
        {
            Write-Host "$ts No Updates Found"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No updates available for installation" -LogLevel "Information"
            
            $operationEndTime = Get-Date
            $operationDuration = $operationEndTime - $operationStartTime
Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "OPERATION COMPLETED - NO UPDATES" -LogLevel "Information"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))" -LogLevel "Debug"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Total operation time: $($operationDuration.TotalMilliseconds) milliseconds" -LogLevel "Verbose"
            
            return 0
        }
        else
        {
            Write-Host "$ts Updates found: $($WUUpdates.count)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Proceeding with installation of $($WUUpdates.Count) updates" -LogLevel "Information"
        }
Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "UPDATE DOWNLOAD AND INSTALLATION PROCESS" -LogLevel "Information"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
        $updateCounter = 1
        $successfulInstalls = 0
        $failedInstalls = 0
        $totalDownloadSize = 0
        foreach ($update in $WUUpdates)
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "----------------------------------------" -LogLevel "Information"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Processing update $updateCounter of $($WUUpdates.Count)" -LogLevel "Debug"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Update: $($update.Title)" -LogLevel "Information"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Size: $([Math]::Round($update.MaxDownloadSize / 1MB, 2)) MB" -LogLevel "Information"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "----------------------------------------" -LogLevel "Information"
            $singleUpdate = New-Object -ComObject Microsoft.Update.UpdateColl
            $singleUpdate.Add($update) | Out-Null
            $WUDownloader = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateDownloader()
            $WUDownloader.Updates = $singleUpdate
            $WUInstaller = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateInstaller()
            $WUInstaller.Updates = $singleUpdate
            $WUInstaller.ForceQuiet = $true
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Downloader and installer configured for single update" -LogLevel "Information"
            # Download phase
            $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
            Write-Output "$ts Downloading update: $($update.Title)"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Starting download process..." -LogLevel "Verbose"
            try
            {
                $downloadStartTime = Get-Date
                $Download = $WUDownloader.Download()
                $downloadEndTime = Get-Date
                $downloadDuration = $downloadEndTime - $downloadStartTime
                $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
                Write-Host "$ts   Download result: $($Download.ResultCode) ($($Download.HResult))"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Download completed in $($downloadDuration.TotalSeconds) seconds" -LogLevel "Information"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Download result code: $($Download.ResultCode)" -LogLevel "Information"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Download HRESULT: $($Download.HResult)" -LogLevel "Information"
                $totalDownloadSize += $update.MaxDownloadSize
                # Installation phase
                $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
                Write-Host "$ts Installing update: $($update.Title)"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Starting installation process..." -LogLevel "Verbose"
                $installStartTime = Get-Date
                $Results = $WUInstaller.Install()
                $installEndTime = Get-Date
                $installDuration = $installEndTime - $installStartTime
                $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
                Write-Host "$ts   Install result: $($Results.ResultCode) ($($Results.HResult))"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Installation completed in $($installDuration.TotalSeconds) seconds" -LogLevel "Information"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Installation result code: $($Results.ResultCode)" -LogLevel "Information"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Installation HRESULT: $($Results.HResult)" -LogLevel "Information"
                # result code 2 = success, see https://learn.microsoft.com/en-us/windows/win32/api/wuapi/ne-wuapi-operationresultcode
                if ($Results.ResultCode -eq 2)
                {
                    $successfulInstalls++
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Update installed successfully" -LogLevel "Information"
                }
                else
                {
                    $failedInstalls++
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Update installation failed or incomplete (ResultCode: $($Results.ResultCode))" -LogLevel "Error"
                }
                if ($Results.RebootRequired)
                {
                    $needReboot = $true
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "This update requires a system reboot" -LogLevel "Information"
                }
            }
            catch
            {
                $failedInstalls++
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Exception during update processing: $($_.Exception.Message)" -LogLevel "Verbose"
                Write-Warning "Failed to process update '$($update.Title)': $($_.Exception.Message)"
            }
            
            $updateCounter++
        }
Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "INSTALLATION SUMMARY" -LogLevel "Verbose"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Total updates processed: $($WUUpdates.Count)" -LogLevel "Information"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Successful installations: $successfulInstalls" -LogLevel "Information"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Failed installations: $failedInstalls" -LogLevel "Error"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Total download size: $([Math]::Round($totalDownloadSize / 1MB, 2)) MB" -LogLevel "Information"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Reboot required: $needReboot" -LogLevel "Information"
        
        # Specify return code
        $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
        if ($needReboot)
        {
            Write-Host "$ts Windows Update indicated that a reboot is needed."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "System reboot is required to complete the update installation" -LogLevel "Information"
            $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
            if ($Reboot -eq "Hard")
            {
                Write-Host "$ts Exiting with return code 1641 to indicate a hard reboot is needed."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning exit code 1641 (hard reboot required)" -LogLevel "Information"
                $operationEndTime = Get-Date
                $operationDuration = $operationEndTime - $operationStartTime
Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "OPERATION COMPLETED - HARD REBOOT REQUIRED" -LogLevel "Information"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))" -LogLevel "Debug"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Total operation time: $($operationDuration.TotalMilliseconds) milliseconds" -LogLevel "Verbose"
                return 1641
            }
            elseif ($Reboot -eq "Soft")
            {
                Write-Host "$ts Exiting with return code 3010 to indicate a soft reboot is needed."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning exit code 3010 (soft reboot required)" -LogLevel "Information"
                
                $operationEndTime = Get-Date
                $operationDuration = $operationEndTime - $operationStartTime
Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "OPERATION COMPLETED - SOFT REBOOT REQUIRED" -LogLevel "Information"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))" -LogLevel "Debug"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Total operation time: $($operationDuration.TotalMilliseconds) milliseconds" -LogLevel "Verbose"
                
                return 3010
            }
            elseif ($Reboot -eq "Delayed")
            {
                Write-Host "$ts Rebooting with a $RebootTimeout second delay"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Initiating delayed reboot with $RebootTimeout second timeout" -LogLevel "Information"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Executing: shutdown.exe /r /t $RebootTimeout /c 'Rebooting to complete the installation of Windows updates.'" -LogLevel "Information"
                
                & shutdown.exe /r /t $RebootTimeout /c "Rebooting to complete the installation of Windows updates."
                
                $operationEndTime = Get-Date
                $operationDuration = $operationEndTime - $operationStartTime
Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "OPERATION COMPLETED - DELAYED REBOOT INITIATED" -LogLevel "Information"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))" -LogLevel "Debug"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Total operation time: $($operationDuration.TotalMilliseconds) milliseconds" -LogLevel "Verbose"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "System will reboot in $RebootTimeout seconds" -LogLevel "Information"
                
                return 0
            }
            elseif ($Reboot -eq "None")
            {
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Reboot required but reboot mode is 'None' - no automatic reboot will occur" -LogLevel "Information"
                Write-Warning "A reboot is required to complete the updates, but automatic reboot is disabled."
                
                $operationEndTime = Get-Date
                $operationDuration = $operationEndTime - $operationStartTime
Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "OPERATION COMPLETED - MANUAL REBOOT REQUIRED" -LogLevel "Information"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))" -LogLevel "Debug"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Total operation time: $($operationDuration.TotalMilliseconds) milliseconds" -LogLevel "Verbose"
                
                return 3010  # Indicate reboot needed but not performed
            }    
        }
        else
        {
            Write-Host "$ts Windows Update indicated that no reboot is required."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No system reboot is required" -LogLevel "Information"
        }
        $operationEndTime = Get-Date
        $operationDuration = $operationEndTime - $operationStartTime
Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "OPERATION COMPLETED SUCCESSFULLY" -LogLevel "Information"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))" -LogLevel "Debug"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Total operation time: $($operationDuration.TotalMilliseconds) milliseconds" -LogLevel "Verbose"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning success code: 1000" -LogLevel "Information"
        if ($failedInstalls -eq 0 -and $WUUpdates.Count -eq 0 -and $successfulInstalls -eq 0)
        {
Write-Log -LogFile $LogFile -Module "$functionName" -Message "No updates found to install, returning code 1000" -LogLevel "Verbose"
            $returnCode = 999
Write-Log -LogFile $LogFile -Module "$functionName" -Message "No updates were found to install" -LogLevel "Verbose"
        }
        elseif ($failedInstalls -eq 0 -and $WUUpdates.Count -eq $successfulInstalls)
        {
            $returnCode = 1000
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "All updates downloaded successfully" -LogLevel "Information"
        }
        elseif ($failedInstalls -eq 0 -and $successfulInstalls -lt $WUUpdates.Count -and $WUUpdates.Count -gt 0)
        {
            $returnCode = 1001
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Not all updates were installed successfully, but some updates were applied" -LogLevel "Information"
        }
        elseif ($WUUpdates.Count -eq $failedInstalls -and $WUUpdates.Count -gt 0)
        {
            $returnCode = 1003
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "All updates failed to install" -LogLevel "Error"
        }   
        else
        {
            $returnCode = 1002
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Some updates failed to install" -LogLevel "Error"
        }   
        $returnObject = @{
            TotalUpdatesProcessed   = $WUUpdates.Count
            SuccessfulInstallations = $successfulInstalls
            ReturnCode              = $returnCode
            FailedInstallations     = $failedInstalls
            RebootRequired          = $needReboot
        }        
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
Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "OPERATION FAILED" -LogLevel "Information"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "==========================================" -LogLevel "Debug"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error occurred at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))" -LogLevel "Error"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Operation duration before failure: $($operationDuration.TotalMilliseconds) milliseconds" -LogLevel "Verbose"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error type: $($_.Exception.GetType().Name)" -LogLevel "Error"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error message: $($_.Exception.Message)" -LogLevel "Error"
        if ($_.Exception.InnerException)
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Inner exception: $($_.Exception.InnerException.Message)" -LogLevel "Error"
        }
        # Log the full call stack for debugging
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Call stack:" -LogLevel "Information"
        $_.ScriptStackTrace -split "`n" | ForEach-Object { Write-Verbose "[$functionName]   $_" }
        Write-Error "Windows Update operation failed: $($_.Exception.Message)"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning error code due to exception" -LogLevel "Information"
        throw
    }
}

function GetInstalledWindowsUpdates()
{
    [CmdletBinding()]
    param()
    try
    {
        $updates = Get-HotFix -ErrorAction Stop
        return $updates
    }
    catch
    {
        Write-Error "Failed to retrieve Windows updates: $_"
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

    $needReboot = $false

    # Opt into Microsoft Update
    if (-not $noOptIn)
    {
        $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
        Write-Output "$ts Opting into Microsoft Update"
        $ServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager"
        $ServiceID = "7971f918-a847-4430-9279-4a52d1efe18d"
        $ServiceManager.AddService2($ServiceId, 7, "") | Out-Null
    }
    
    # Install all available updates
    $WUDownloader = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateDownloader()
    $WUInstaller = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateInstaller()

    if ($ExcludeDrivers)
    {
        # Updates only
        $queries = @("IsInstalled=0 and Type='Software'")
    }
    elseif ($ExcludeUpdates)
    {
        # Drivers only
        $queries = @("IsInstalled=0 and Type='Driver'")
    }
    else
    {
        # Both
        $queries = @("IsInstalled=0 and Type='Software'", "IsInstalled=0 and Type='Driver'")
    }

    $WUUpdates = New-Object -ComObject Microsoft.Update.UpdateColl
    $queries | ForEach-Object {
        $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
        Write-Host "$ts Getting $_ updates."        
        try
        {
            ((New-Object -ComObject Microsoft.Update.Session).CreateupdateSearcher().Search($_)).Updates | ForEach-Object {
                if (!$_.EulaAccepted)
                {
                    $_.AcceptEula() 
                }
                $featureUpdate = $_.Categories | Where-Object { $_.CategoryID -eq "3689BDC8-B205-4AF4-8D4A-A63924C5E9D5" }
                if ($featureUpdate)
                {
                    $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
                    Write-Host "$ts Skipping feature update: $($_.Title)"
                }
                elseif ($_.Title -match "Preview")
                { 
                    $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
                    Write-Host "$ts Skipping preview update: $($_.Title)"
                }
                else
                {
                    [void]$WUUpdates.Add($_)
                }
            }
        }
        catch
        {
            # If this script is running during specialize, error 8024004A will happen:
            # 8024004A	Windows Update agent operations are not available while OS setup is running.
            $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
            Write-Warning "$ts Unable to search for updates: $_"
        }
    }

    $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
    if ($WUUpdates.Count -eq 0)
    {
        Write-Host "$ts No Updates Found"
        Return 0
    }
    else
    {
        Write-Host "$ts Updates found: $($WUUpdates.count)"
    }
    foreach ($update in $WUUpdates)
    {
        $singleUpdate = New-Object -ComObject Microsoft.Update.UpdateColl
        $singleUpdate.Add($update) | Out-Null
        $WUDownloader = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateDownloader()
        $WUDownloader.Updates = $singleUpdate
        $WUInstaller = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateInstaller()
        $WUInstaller.Updates = $singleUpdate
        $WUInstaller.ForceQuiet = $true
        $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
        Write-Output "$ts Downloading update: $($update.Title)"
        $Download = $WUDownloader.Download()
        $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
        Write-Host "$ts   Download result: $($Download.ResultCode) ($($Download.HResult))"
        $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
        Write-Host "$ts Installing update: $($update.Title)"
        $Results = $WUInstaller.Install()
        $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
        Write-Host "$ts   Install result: $($Results.ResultCode) ($($Results.HResult))"
        # result code 2 = success, see https://learn.microsoft.com/en-us/windows/win32/api/wuapi/ne-wuapi-operationresultcode
        if ($Results.RebootRequired)
        {
            $needReboot = $true
        }
    }
    
    # Specify return code
    $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
    if ($needReboot)
    {
        Write-Host "$ts Windows Update indicated that a reboot is needed."
        $ts = Get-Date -f "yyyy/MM/dd hh:mm:ss tt"
        if ($Reboot -eq "Hard")
        {
            Write-Host "$ts Exiting with return code 1641 to indicate a hard reboot is needed."
            Return 1641
        }
        elseif ($Reboot -eq "Soft")
        {
            Write-Host "$ts Exiting with return code 3010 to indicate a soft reboot is needed."
            Return 3010
        }
        elseif ($Reboot -eq "Delayed")
        {
            Write-Host "$ts Rebooting with a $RebootTimeout second delay"
            & shutdown.exe /r /t $RebootTimeout /c "Rebooting to complete the installation of Windows updates."
            Return 0
        }    
    }
    else
    {
        Write-Host "$ts Windows Update indicated that no reboot is required."
    }
    return 1000
}
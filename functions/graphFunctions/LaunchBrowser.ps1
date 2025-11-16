function LaunchBrowser()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$url,
        [ValidateSet("Chrome", "Edge", "Firefox", "Default")]
        [string]$browser
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    #print log of incoming parameters.
    Write-Verbose "[$functionName] Launching browser with URL: $url"
    Write-Verbose "[$functionName] Browser preference: $browser"
    Write-Verbose "[$functionName] Private session: $private"
    if ($null -eq $browser -or $browser -eq '')
    {
        Write-Verbose "[$functionName] No browser specified, attempting to read value from settings"
        if ($null -ne $settings.preferredBrowser -and $settings.preferredBrowser -ne '')
        {
            Write-Verbose "[$functionName] Using preferred browser from settings: $($settings.preferredBrowser)"
            $browser = $settings.preferredBrowser
        }
        else
        {
            Write-Verbose "[$functionName] No preferred browser set in settings, defaulting to Edge"
            $browser = 'Default'
        }
    }
    
    switch ($Browser)
    {
        'Edge'
        {
            Write-Verbose "[$functionName] Opening Edge browser for authentication"
            if ($settings.privateSession)
            {
                Write-Verbose "[$functionName] Private session detected.  Opening $($settings.preferredBrowser) in private mode"
                $urlParams = @{
                    FilePath     = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
                    ArgumentList = "--inprivate", $url  
                }
            }
            else
            {
                $urlParams = @{
                    FilePath     = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
                    ArgumentList = $url
                }
            }
        }
        'Chrome'
        {
            Write-Verbose "[$functionName] Opening Chrome browser for authentication"
            if ($settings.privateSession)
            {
                Write-Verbose "[$functionName] Private session detected.  Opening $($settings.preferredBrowser) in private mode"
                $urlParams = @{
                    FilePath     = "C:\Program Files\Google\Chrome\Application\chrome.exe"
                    ArgumentList = "--incognito", $url
                }
            }
            else
            {
                $urlParams = @{
                    FilePath     = "C:\Program Files\Google\Chrome\Application\chrome.exe"
                    ArgumentList = $url     
                }
            }
        }
        'Firefox'
        {
            Write-Verbose "[$functionName] Opening Firefox browser for authentication"
            if ($settings.privateSession)
            {
                Write-Verbose "[$functionName] Private session detected.  Opening $($settings.preferredBrowser) in private mode"
                $urlParams = @{
                    FilePath     = "C:\Program Files\Mozilla Firefox\firefox.exe"
                    ArgumentList = "-private-window", $url
                }
            }
            else
            {
                $urlParams = @{
                    FilePath     = "C:\Program Files\Mozilla Firefox\firefox.exe"
                    ArgumentList = $url
                }
            }
        }
        default
        {
            Write-Verbose "[$functionName] Opening default browser for authentication"
            $urlParams = @{
                FilePath     = "start"
                ArgumentList = $url     
            }
        }
    }
    Write-Verbose "[$functionName] Launching $browser with URL: $url"
    try
    {
        # Start the browser with the specified URL
        Start-Process @urlParams
        Write-Verbose "[$functionName] Browser launched successfully."
    }
    catch
    {
        Write-Error "Failed to launch browser: $_"
        return $false
    }
    return $true
}


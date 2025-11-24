function LaunchBrowser()
{
    <#
    .SYNOPSIS
    Launches a web browser with a specified URL.

    .DESCRIPTION
    This function opens a web browser (Chrome, Edge, Firefox, or system default) with the
    specified URL. It supports private/incognito mode based on settings and uses the preferred
    browser from settings if not explicitly specified. The function handles browser-specific
    paths and argument formats.

    .PARAMETER url
    The URL to open in the browser. This parameter is mandatory.

    .PARAMETER browser
    The browser to use. Valid values: "Chrome", "Edge", "Firefox", "Default".
    If not specified, uses the preferredBrowser setting or defaults to "Default".

    .OUTPUTS
    None. Opens the specified browser with the URL.

    .EXAMPLE
    LaunchBrowser -url "https://login.microsoftonline.com/oauth2/authorize" -browser "Edge"
    LaunchBrowser -url "https://portal.azure.com"

    .NOTES
    Reads preferredBrowser and privateSession settings from $settings variable.
    Uses standard installation paths for browsers.
    Private session mode supported for Edge, Chrome, and Firefox.
    Compatible with PowerShell 5.1.
    #>
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


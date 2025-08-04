function Get-NavigationPathContext()
{
    [CmdletBinding()]
    param()
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Analyzing navigation path from MenuHistory"
    
    if (-not $Global:MenuHistory -or $Global:MenuHistory.Count -eq 0)
    {
        Write-Verbose "[$functionName] No menu history available"
        return 'Unknown'
    }
    
    # Create navigation path signature from menu titles
    $menuTitles = @()
    foreach ($menu in $Global:MenuHistory)
    {
        if ($menu -and $menu.Title)
        {
            # Normalize menu titles for consistent context generation
            $normalizedTitle = $menu.Title -replace '\s+', '' -replace '[^a-zA-Z0-9]', ''
            $menuTitles += $normalizedTitle
            Write-Verbose "[$functionName] Added normalized menu title: $normalizedTitle"
        }
    }
    
    if ($menuTitles.Count -eq 0)
    {
        Write-Verbose "[$functionName] No valid menu titles found in history"
        return 'Unknown'
    }
    
    # Generate context based on navigation path patterns
    $pathSignature = $menuTitles -join '-'
    Write-Verbose "[$functionName] Generated path signature: $pathSignature"
    
    # Check for specific known navigation patterns
    switch -Regex ($pathSignature)
    {
        'MainMenu-CheckDeviceStatus-LookupbySerialNumber'
        {
            Write-Verbose "[$functionName] Detected CheckMenu -> SerialNumber navigation path"
            return 'ViaCheckMenu'
        }
        'MainMenu-AutopilotMenu-CheckdeviceAutopilotstatus'
        {
            Write-Verbose "[$functionName] Detected AutopilotMenu -> SerialNumber navigation path"
            return 'ViaAutopilotMenu'
        }
        'MainMenu-AutopilotMenu.*SerialNumber'
        {
            Write-Verbose "[$functionName] Detected general AutopilotMenu -> SerialNumber navigation path"
            return 'ViaAutopilotMenu'
        }
        'MainMenu-CheckDeviceStatus.*SerialNumber'
        {
            Write-Verbose "[$functionName] Detected general CheckMenu -> SerialNumber navigation path"
            return 'ViaCheckMenu'
        }
        default
        {
            # For unknown patterns, create a generic path-based context
            if ($menuTitles.Count -gt 1)
            {
                $parentMenu = $menuTitles[-2]  # Second to last menu (parent of current)
                Write-Verbose "[$functionName] Creating context based on parent menu: $parentMenu"
                return "Via$parentMenu"
            }
            else
            {
                Write-Verbose "[$functionName] Single menu in path, using direct context"
                return 'Direct'
            }
        }
    }
}


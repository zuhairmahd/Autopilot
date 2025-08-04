function Create-MenuBanner()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Menu,
        [Parameter(Mandatory = $true)]
        [System.Collections.ArrayList]$History
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    $banner = $Menu.Title
    Write-Verbose "[$functionName] Creating banner for menu: $($Menu.Title)"
    if (-not [string]::IsNullOrEmpty($Menu.Description))
    {
        Write-Verbose "[$functionName] Adding description to banner: $($Menu.Description)"
        $banner += "`n$($Menu.Description)"
        Write-Verbose "Banner after adding description: $banner"
    }
    
    # Create breadcrumb
    if ($History.Count -gt 0)
    {
        Write-Verbose "[$functionName] Creating breadcrumb from history"
        $cleanHistory = @()
        $previousItem = ""
        foreach ($item in $History)
        {
            Write-Verbose "[$functionName] Processing history item: $item"
            if ($item -ne $previousItem -and ![string]::IsNullOrWhiteSpace($item))
            {
                Write-Verbose "[$functionName] Adding the item $item to clean history since it is not equal to the previous item '$previousItem'"
                $cleanHistory += $item
                $previousItem = $item
                Write-Verbose "[$functionName] Updated previous item to: $previousItem"
            }
        }
        
        if ($cleanHistory.Count -gt 0)
        {
            Write-Verbose "[$functionName] Clean history created with items: $($cleanHistory -join ', ')"
            $path = $cleanHistory -join " > "
            if ($cleanHistory[-1] -eq $Menu.Title)
            {
                Write-Verbose "[$functionName] Last item in clean history is the current menu title, using path: $path"
                $banner += "`n[$path]"
                Write-Verbose "Banner after adding breadcrumb: $banner"
            }
            else
            {
                Write-Verbose "[$functionName] Last item in clean history is not the current menu title, appending current menu title"
                $banner += "`n[$path > $($Menu.Title)]"
                Write-Verbose "Banner after appending current menu title: $banner"
            }
        }
        else
        {
            Write-Verbose "[$functionName] Clean history is empty, using only current menu title"
            $banner += "`n[$($Menu.Title)]"
            Write-Verbose "Banner after using only current menu title: $banner"
        }
    }
    else
    {
        Write-Verbose "[$functionName] History is empty, using only current menu title"
        $banner += "`n[$($Menu.Title)]"
        Write-Verbose "Banner after using only current menu title: $banner"
    }
    Write-Verbose "[$functionName] Final banner created: $banner"
    return $banner
}


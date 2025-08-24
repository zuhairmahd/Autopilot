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
    
    # Phase 4A Optimization: Use System.Text.StringBuilder for efficient string building
    $bannerBuilder = New-Object System.Text.StringBuilder
    [void]$bannerBuilder.Append($Menu.Title)
    
    Write-Verbose "[$functionName] Creating banner for menu: $($Menu.Title)"
    
    if (-not [string]::IsNullOrEmpty($Menu.Description))
    {
        Write-Verbose "[$functionName] Adding description to banner: $($Menu.Description)"
        [void]$bannerBuilder.AppendLine().Append($Menu.Description)
        Write-Verbose "Banner after adding description: $($bannerBuilder.ToString())"
    }
    
    # Create breadcrumb
    if ($History.Count -gt 0)
    {
        Write-Verbose "[$functionName] Creating breadcrumb from history"
        
        # Phase 4A Optimization: Pre-allocate ArrayList with estimated capacity
        $cleanHistory = New-Object System.Collections.ArrayList($History.Count)
        $previousItem = ""
        
        foreach ($item in $History)
        {
            Write-Verbose "[$functionName] Processing history item: $item"
            if ($item -ne $previousItem -and ![string]::IsNullOrWhiteSpace($item))
            {
                Write-Verbose "[$functionName] Adding the item $item to clean history since it is not equal to the previous item '$previousItem'"
                [void]$cleanHistory.Add($item)
                $previousItem = $item
                Write-Verbose "[$functionName] Updated previous item to: $previousItem"
            }
        }
        
        if ($cleanHistory.Count -gt 0)
        {
            Write-Verbose "[$functionName] Clean history created with items: $($cleanHistory -join ', ')"
            $path = $cleanHistory -join " > "
            
            [void]$bannerBuilder.AppendLine()
            
            if ($cleanHistory[-1] -eq $Menu.Title)
            {
                Write-Verbose "[$functionName] Last item in clean history is the current menu title, using path: $path"
                [void]$bannerBuilder.Append("[$path]")
                Write-Verbose "Banner after adding breadcrumb: $($bannerBuilder.ToString())"
            }
            else
            {
                Write-Verbose "[$functionName] Last item in clean history is not the current menu title, appending current menu title"
                [void]$bannerBuilder.Append("[$path > $($Menu.Title)]")
                Write-Verbose "Banner after appending current menu title: $($bannerBuilder.ToString())"
            }
        }
        else
        {
            Write-Verbose "[$functionName] Clean history is empty, using only current menu title"
            [void]$bannerBuilder.AppendLine().Append("[$($Menu.Title)]")
            Write-Verbose "Banner after using only current menu title: $($bannerBuilder.ToString())"
        }
    }
    else
    {
        Write-Verbose "[$functionName] History is empty, using only current menu title"
        [void]$bannerBuilder.AppendLine().Append("[$($Menu.Title)]")
        Write-Verbose "Banner after using only current menu title: $($bannerBuilder.ToString())"
    }
    
    $banner = $bannerBuilder.ToString()
    Write-Verbose "[$functionName] Final banner created: $banner"
    return $banner
}


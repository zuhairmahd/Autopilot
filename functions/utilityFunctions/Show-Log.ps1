function Show-Log()
{
    [CmdletBinding()] 
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)         ]
        [string]$logFile,
        [string[]]$Module = 'All',
        [switch]$Raw,
        [switch]$NoColor,
        [switch]$UseGrid,
        [ValidateSet('Error', 'Warning', 'Information', 'Verbose', 'Debug', 'All')] 
        [string[]]$Level = 'All',
        [int]$MenuPageSize = 25,
        [int]$OutputPageSize = 100
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Invoked with parameters: Raw=$Raw, NoColor=$NoColor, Module=$($Module -join ','), Level=$($Level -join ','), UseGrid=$UseGrid, MenuPageSize=$MenuPageSize, OutputPageSize=$OutputPageSize"

    function Show-MenuSelection()
    {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)] 
            [string]$Title,
            [Parameter(Mandatory)] 
            [string[]]$Items,
            [switch]$AllowMulti,
            [switch]$UseGrid,
            [string]$AllLabel = 'All'
        )
        $functionName = $MyInvocation.MyCommand.Name
        if ($UseGrid -and (Get-Command Out-GridView -ErrorAction SilentlyContinue))
        {
            $ovParams = @{ Title = $Title }
            Write-Verbose "[$functionName] Showing menu selection with Out-GridView. Title: $Title, AllowMulti: $AllowMulti"
            if ($AllowMulti)
            {
                $ovParams.Add('PassThru', $true) 
                Write-Verbose "[$functionName] Out-GridView PassThru enabled"
            }
            $sel = $Items | Out-GridView @ovParams
            if ($null -eq $sel)
            {
                Write-Verbose "[$functionName] Out-GridView selection was null"
                return @() 
            }
            if ($AllowMulti)
            {
                Write-Verbose "[$functionName] Returning multiple selections from Out-GridView."    
                return $sel 
            }
            return @($sel)
        }
        if (-not $Items -or $Items.Count -eq 0)
        {
            Write-Verbose "[$functionName] No items to display in menu selection."                  
            return @() 
        }
        $total = $Items.Count
        $pageSize = if ($MenuPageSize -gt 0)
        {
            $MenuPageSize 
        }
        else
        {
            $Items.Count 
        }
        $page = 0
        Write-Verbose "[$functionName] Starting menu selection loop. Total items: $total, Page size: $pageSize"
        while ($true)
        {
            Write-Verbose "[$functionName] Displaying page $($page + 1) of menu selection."
            Clear-Host
            Write-Host "`n$Title" -ForegroundColor Cyan
            $startIndex = $page * $pageSize
            $pageItems = $Items[$startIndex..([Math]::Min($startIndex + $pageSize - 1, $total - 1))]
            for ($i = 0; $i -lt $pageItems.Count; $i++)
            {
                $globalIndex = $startIndex + $i + 1
                Write-Verbose "[$functionName] Displaying item $($globalIndex): $($pageItems[$i])"
                Write-Host ("{0,4}. {1}" -f $globalIndex, $pageItems[$i])
            }
            $pageCount = [Math]::Ceiling($total / [double]$pageSize)
            $nav = if ($pageCount -gt 1)
            {
                " Page $(($page+1))/$pageCount (n=next, p=prev)" 
            }
            else
            {
                '' 
            }
            Write-Verbose "[$functionName] Navigation prompt: $nav"
            if ($AllowMulti)
            {
                Write-Host "Enter indexes / ranges / '$AllLabel' for all,$nav or q to quit:" -NoNewline
                Write-Verbose "[$functionName] Prompting for multiple selections: Enter indexes / ranges / '$AllLabel' for all,$nav or q to quit:"
            }
            else
            {
                Write-Host "Enter index$nav or q to quit:" -NoNewline
                Write-Verbose "[$functionName] Prompting for single selection: Enter index$nav or q to quit:"
            }
            Write-Host ''
            $resp = Read-Host 'Selection'
            Write-Verbose "[$functionName] User input received: $resp"
            switch ($resp.Trim().ToLower())
            {
                'q'
                {
                    Write-Verbose "[$functionName] User selected to quit."
                    return @() 
                }
                'n'
                {
                    Write-Verbose "[$functionName] User selected next page."
                    if ($page -lt ($pageCount - 1))
                    {
                        Write-Verbose "[$functionName] Advancing to next page: $($page + 2)"
                        $page++ 
                    }
                    Write-Verbose "[$functionName] Staying on current page: $($page + 1) since it is the last one"
                    continue 
                }
                'p'
                {
                    Write-Verbose "[$functionName] User selected previous page."
                    if ($page -gt 0)
                    {
                        Write-Verbose "[$functionName] Returning to previous page: $page"
                        $page-- 
                    }
                    else
                    {
                        Write-Verbose "[$functionName] Already at first page, cannot go back further."
                    }   
                }
            }
            
            if ($AllowMulti -and $resp.Trim().ToLower() -eq $AllLabel.ToLower())
            {
                Write-Verbose "[$functionName] User selected all items and multiple selection is allowed."
                return $Items 
            }
            if (-not $AllowMulti)
            {
                Write-Verbose "[$functionName] User selected single item and multiple selection is not allowed."
                if ([int]::TryParse($resp, [ref]$null))
                {
                    $n = [int]$resp
                    Write-Verbose "[$functionName] User selected single item: $n"
                    if ($n -ge 1 -and $n -le $Items.Count)
                    {
                        Write-Verbose "[$functionName] Returning single selected item: $($Items[$n - 1])"
                        return @($Items[$n - 1]) 
                    }
                }
                Write-Warning 'Invalid selection.'; Start-Sleep -Milliseconds 800; continue
            }
            $selected = New-Object System.Collections.Generic.List[string]
            foreach ($token in $resp.Split(',') | ForEach-Object Trim | Where-Object { $_ })
            {
                if ($token -match '^(\d+)-(\d+)$')
                {
                    $start = [int]$matches[1]; $end = [int]$matches[2]
                    Write-Verbose "[$functionName] User selected range: $start-$end"
                    if ($start -le $end -and $start -ge 1 -and $end -le $Items.Count)
                    {
                        Write-Verbose "[$functionName] Adding items in range: $start-$end"
                        for ($x = $start; $x -le $end; $x++)
                        {
                            $selected.Add($Items[$x - 1]) 
                        }
                    }
                    else
                    {
                        Write-Warning "Range out of bounds: $token"
                    }
                }
                elseif ([int]::TryParse($token, [ref]$null))
                {
                    $n = [int]$token
                    Write-Verbose "[$functionName] User selected single item: $n"
                    if ($n -ge 1 -and $n -le $Items.Count)
                    {
                        $selected.Add($Items[$n - 1]) 
                    }
                    else
                    {
                        Write-Warning "Index out of bounds: $token"
                    }
                }
                else
                {
                    Write-Warning "Invalid token: $token"
                }
                if ($selected.Count -gt 0)
            }
        }
        if ($selected.Count -gt 0)
        {
            Write-Verbose "[$functionName] Returning multiple selected items. Count: $($selected.Count)"
            return $selected.ToArray()
        }
        Write-Warning 'No valid selections made.'; Start-Sleep -Milliseconds 800
    }
}
}

function Convert-LogLine()
{
    [CmdletBinding()]
    param(
        [string]$Line
    )
            
    $functionName = $MyInvocation.MyCommand.Name                
    # Standard format: timestamp [Level] [Module] [Thread:n] [Context:xx] Message
    $standardRegex = '^(?<Timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}) \[(?<Level>[^\]]+)\] \[(?<Module>[^\]]+)\] \[Thread:(?<Thread>[^\]]+)\] \[Context:(?<Context>[^\]]*)\] (?<Message>.*)$'
    # CMTrace format: <![LOG[Message]LOG]!><time=".." date=".." component="Module" ... type="N" thread="T" ...>
    $cmRegex = '^<!\[LOG\[(?<Message>.*?)\]LOG\]!><time="(?<Time>[^"]+)" date="(?<Date>[^"]+)" component="(?<Component>[^"]*)".*? type="(?<Type>[123])" thread="(?<Thread>[^"]*)"'
    Write-Verbose "[$functionName] Converting log line: $Line"
    if ($Line -match $standardRegex)
    {
        Write-Verbose "[$functionName] Matched standard log format."
        $logObject = [PSCustomObject]@{
            Format    = 'Standard'
            Timestamp = [datetime]::ParseExact($matches['Timestamp'], 'yyyy-MM-dd HH:mm:ss.fff', $null)
            Level     = $matches['Level']
            Module    = $matches['Module']
            Thread    = $matches['Thread']
            Context   = $matches['Context']
            Message   = $matches['Message']
        }
        if ($Raw)
        {
            $logObject | Add-Member -MemberType NoteProperty -Name Raw -Value $Line
        }
        return $logObject
    }
    elseif ($Line -match $cmRegex)
    {
        # Map CMTrace type to level (3=Error,2=Warning,1=Information)
        $level = switch ($matches['Type'])
        {
            '3'
            {
                'Error'
            } '2'
            {
                'Warning'
            } default
            {
                'Information'
            } 
        }
        Write-Verbose "[$functionName] Matched CMTrace log format. Mapped type $($matches['Type']) to level $level."
        # Combine date+time (CMTrace date: MM-dd-yyyy, time: HH:mm:ss.fff+000)
        $rawTime = $matches['Time']
        $rawDate = $matches['Date']
        $timePart = ($rawTime -split '\+')[0]
        $dtString = "$rawDate $timePart"
        $timestamp = $null
        [datetime]::TryParseExact($dtString, 'MM-dd-yyyy HH:mm:ss.fff', $null, [System.Globalization.DateTimeStyles]::None, [ref]$timestamp) | Out-Null
        Write-Verbose "[$functionName] Parsed timestamp: $timestamp"
        $logObject = [PSCustomObject]@{
            Format    = 'CMTrace'
            Timestamp = $timestamp
            Level     = $level
            Module    = $matches['Component']
            Thread    = $matches['Thread']
            Context   = $null
            Message   = $matches['Message']
        }
        if ($Raw)
        {
            $logObject | Add-Member -MemberType NoteProperty -Name Raw -Value $Line
        }
        return $logObject
    }
    else
    {
        Write-Verbose "[$functionName] Log line did not match known formats."
        return $null
    }
}

try 
{
    if (-not (Test-Path -Path $logFile))
    {
        Write-Verbose "[$functionName] Log file '$logFile' does not exist."     
        throw "Log file '$logFile' does not exist."
    }
    Write-Verbose "[$functionName] Invoked with parameters: Raw=$Raw, NoColor=$NoColor, Module=$($Module -join ','), Level=$($Level -join ','), UseGrid=$UseGrid, MenuPageSize=$MenuPageSize, OutputPageSize=$OutputPageSize"
    Write-Host "Using log: $logFile" -ForegroundColor Green
}
catch
{
    Write-Error $_
}                   

# Parse file
$parsed = New-Object System.Collections.Generic.List[object]
Get-Content -Path $logFile | ForEach-Object {
    $obj = Convert-LogLine -Line $_
    if ($obj)
    {
        $parsed.Add($obj) 
    }
}

if ($parsed.Count -eq 0)
{
    Write-Warning 'No recognizable log entries.'; return 
}

if ($settings.DisplayManualFilterSelection)
{
    Write-Verbose "[$functionName] DisplayManualFilterSelection is enabled in settings."
    $Module = $null        
    $Level = $null
}
    
$allModules = $parsed | Where-Object Module | Select-Object -ExpandProperty Module -Unique | Sort-Object
if (-not $Module)
{
    $selectedModules = if ($UseGrid)
    {
        Show-MenuSelection -Title 'Select module(s):' -Items ($allModules + 'All') -AllowMulti -UseGrid
    }
    else
    {               
        Show-MenuSelection -Title 'Select module(s):' -Items ($allModules + 'All') -AllowMulti
    }
    if ($selectedModules -contains 'All')
    {
        $selectedModules = $allModules 
    }
}
elseif ($Module -contains 'All')
{
    $selectedModules = $allModules
}
else
{
    $selectedModules = $Module
}
    
$allLevels = $parsed | Where-Object Level | Select-Object -ExpandProperty Level -Unique | Sort-Object
if (-not $Level -or $Level.Count -eq 0)
{
    $selectedLevels = if ($UseGrid)
    {
        Show-MenuSelection -Title 'Select log level(s):' -Items ($allLevels + 'All') -AllowMulti -UseGrid
    }
    else
    {           
        Show-MenuSelection -Title 'Select log level(s):' -Items ($allLevels + 'All') -AllowMulti
    }
    if ($selectedLevels -contains 'All')
    {
        $selectedLevels = $allLevels 
    }
}
elseif ($Level -contains 'All')
{
    $selectedLevels = $allLevels
}
else
{
    $selectedLevels = $Level
}

# Filter
$filtered = $parsed | Where-Object { ($selectedModules -contains $_.Module) -and ($selectedLevels -contains $_.Level) }

if ($filtered.Count -eq 0)
{
    Write-Warning 'No entries match the selected criteria.'; return 
}

$ordered = $filtered | Sort-Object Timestamp

Write-Host ("`nTotal matching entries: {0} (Modules: {1}; Levels: {2})" -f $ordered.Count, ($selectedModules -join ','), ($selectedLevels -join ',')) -ForegroundColor Yellow

# Use Out-GridView if requested and available
if ($UseGrid -and (Get-Command Out-GridView -ErrorAction SilentlyContinue))
{
    Write-Host "Displaying logs in grid view..." -ForegroundColor Cyan
    $logFileName = Split-Path -Path $logFile -Leaf      
    $ordered | Out-GridView -Title "Log Viewer - $logFileName" -Wait
    return
}

$outPageSize = if ($OutputPageSize -gt 0)
{
    $OutputPageSize 
}
else
{
    $ordered.Count 
}
$outPage = 0
$outPageCount = [Math]::Ceiling([double]$ordered.Count / $outPageSize)
while ($true)
{
    $start = $outPage * $outPageSize
    $end = [Math]::Min($start + $outPageSize - 1, $ordered.Count - 1)
        
    $slice = if ($ordered.Count -gt 0)
    {
        $ordered[$start..$end] 
    }
    else
    {
        @() 
    }
    Write-Host ("`nPage {0}/{1} Showing entries {2}-{3}" -f ($outPage + 1), $outPageCount, ($start + 1), ($end + 1)) -ForegroundColor Cyan
    foreach ($entry in $slice)
    {
        if ($Raw)
        {
            Write-Output $entry.Raw; continue 
        }
        $display = "[{0}] [{1}] {2}" -f $entry.Level, $entry.Module, $entry.Message
        if ($NoColor)
        {
            Write-Output $display 
        }
        else
        {
            switch ($entry.Level)
            {
                'Error'
                {
                    $color = 'Red' 
                }
                'Warning'
                {
                    $color = 'Yellow' 
                }
                'Information'
                {
                    $color = 'White' 
                }
                'Verbose'
                {
                    $color = 'DarkGray' 
                }
                'Debug'
                {
                    $color = 'Cyan' 
                }
                default
                {
                    $color = 'White' 
                }
            }
            Write-Host $display -ForegroundColor $color
        }
    }
    if ($outPageCount -le 1)
    {
        break 
    }
    $nav = Read-Host 'n=next, p=prev, q=quit, a=all remaining'
    switch ($nav.ToLower())
    {
        'n'
        {
            if ($outPage -lt ($outPageCount - 1))
            {
                $outPage++ 
            }
            else
            {
                Write-Host 'Last page.' -ForegroundColor DarkGray 
            } 
        }
        'p'
        {
            if ($outPage -gt 0)
            {
                $outPage-- 
            }
            else
            {
                Write-Host 'First page.' -ForegroundColor DarkGray 
            } 
        }
        'a'
        {
            if ($outPage -lt ($outPageCount - 1))
            {
                $remaining = $ordered[($end + 1)..($ordered.Count - 1)]
                foreach ($entry in $remaining)
                {
                    if ($Raw)
                    {
                        Write-Output $entry.Raw; continue 
                    }
                    $display = "[{0}] [{1}] {2}" -f $entry.Level, $entry.Module, $entry.Message
                    if ($NoColor)
                    {
                        Write-Output $display 
                    }
                    else
                    {
                        switch ($entry.Level)
                        {
                            'Error'
                            {
                                $color = 'Red'
                            } 'Warning'
                            {
                                $color = 'Yellow'
                            } 'Information'
                            {
                                $color = 'White'
                            } 'Verbose'
                            {
                                $color = 'DarkGray'
                            } 'Debug'
                            {
                                $color = 'Cyan'
                            } default
                            {
                                $color = 'White'
                            } 
                        }
                        Write-Host $display -ForegroundColor $color
                    }
                }
            }
            break
        }
        'q'
        {
            break 
        }
        default
        { 
        }
    }
    if ($nav -eq 'a' -or $nav -eq 'q')
    {
        break 
    }
}
}

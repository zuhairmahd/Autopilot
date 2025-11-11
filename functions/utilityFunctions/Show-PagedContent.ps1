function Show-PagedContent()
{
    <#
    .SYNOPSIS
        Generic paging function for displaying large datasets with navigation controls.
    
    .DESCRIPTION
        Provides a reusable paging mechanism for displaying large amounts of data with navigation.
        Supports multiple input types: arrays, hashtables, PSCustomObjects, and multi-line strings.
        Uses a scriptblock for flexible item display formatting.
        
        Navigation commands:
        - 'n' or 'N': Next page
        - 'p' or 'P': Previous page
        - '1-N': Jump to specific page number
        - 'q' or 'Q': Quit/exit paging
    
    .PARAMETER Content
        The content to display. Can be:
        - Array of items (objects, strings, etc.)
        - Hashtable
        - PSCustomObject
        - Multi-line string
    
    .PARAMETER PageSize
        Number of items to display per page. Default: 10
    
    .PARAMETER DisplayScriptBlock
        ScriptBlock that defines how to display each item. Receives the item as $_ or $args[0].
        For strings, this is optional and will default to Write-Host.
        For complex objects, this is required.
    
    .PARAMETER Title
        Optional title to display at the top of each page.
    
    .PARAMETER ShowPageInfo
        If specified, displays page information (current page, total pages, item range).
    
    .PARAMETER Silent
        If specified, suppresses all output and navigation (useful for testing/automation).
    
    .PARAMETER NoPaging
        If specified, displays all content without paging (useful when content is small).
    
    .PARAMETER UseDynamicSize
        If specified, automatically calculates screen-aware page sizes based on content type.
        For arrays/objects with properties like Description, calculates actual lines per item
        considering console width and text wrapping. Adjusts page size to fit console height.
        Without this switch, uses fixed PageSize regardless of item complexity.
    
    .OUTPUTS
        System.String
        Returns navigation action taken: 'completed', 'quit', or error message.
    
    .EXAMPLE
        # Display array of settings with custom formatting
        $settings = @($setting1, $setting2, $setting3)
        Show-PagedContent -Content $settings -DisplayScriptBlock {
            param($item)
            Write-Host "Setting: $($item.Name)" -ForegroundColor Yellow
            Write-Host "  Value: $($item.Value)" -ForegroundColor Green
        } -Title "Application Settings"
    
    .EXAMPLE
        # Display hashtable with default formatting
        $report = @{ Key1 = "Value1"; Key2 = "Value2" }
        Show-PagedContent -Content $report -DisplayScriptBlock {
            param($kvp)
            Write-Host "$($kvp.Key): $($kvp.Value)"
        } -PageSize 5
    
    .EXAMPLE
        # Display multi-line string with paging
        $logContent = Get-Content "large-log.txt" -Raw
        Show-PagedContent -Content $logContent -PageSize 20 -Title "Log File Contents"
    
    .EXAMPLE
        # Display without paging
        Show-PagedContent -Content $smallArray -NoPaging -DisplayScriptBlock { param($item) Write-Host $item }
    
    .EXAMPLE
        # Display complex multi-line items with automatic screen-aware paging
        $apps = @($app1, $app2, $app3)
        Show-PagedContent -Content $apps -UseDynamicSize -DisplayScriptBlock {
            param($app)
            Write-Host "Name: $($app.Name)"
            Write-Host "  Description: $($app.Description)"
            Write-Host "  Intent: $($app.Intent)"
            Write-Host ""
        }
    
    .NOTES
        - Maintains PowerShell 5.1 compatibility (no null-coalescing, ordered hashtables created via [ordered])
        - Follows repository coding standards (4-space indentation, Write-Verbose, Write-Log)
        - Implements ASCII-only navigation prompts
        - Uses separate Write-Host calls for newlines
        - UseDynamicSize: Automatically detects object properties and calculates lines per item
        - Reserves lines for headers, page info, and navigation prompts when calculating page size
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $Content,
        [Parameter(Mandatory = $false)]
        [int]$PageSize = 10,
        [Parameter(Mandatory = $false)]
        [scriptblock]$DisplayScriptBlock,
        [Parameter(Mandatory = $false)]
        [string]$Title = "",
        [Parameter(Mandatory = $false)]
        [bool]$ShowPageInfo = $true,
        [Parameter(Mandatory = $false)]
        [switch]$Silent,
        [Parameter(Mandatory = $false)]
        [switch]$NoPaging,
        [Parameter(Mandatory = $false)]
        [switch]$UseDynamicSize
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $logFile -Module $functionName -Message "Starting paged content display (UseDynamicSize: $($UseDynamicSize.IsPresent))" -LogLevel "Verbose"
    Write-Verbose "[$functionName] Starting paged content display (UseDynamicSize: $($UseDynamicSize.IsPresent))"
    
    # Validate parameters
    if ($PageSize -lt 1)
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Invalid PageSize: $PageSize. Must be >= 1. Using default 10." -LogLevel "Warning"
        Write-Warning "[$functionName] Invalid PageSize: $PageSize. Must be >= 1. Using default 10."
        $PageSize = 10
    }
    
    # Handle null or empty content
    if ($null -eq $Content)
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Content is null, nothing to display" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Content is null, nothing to display"
        if (-not $Silent)
        {
            Write-Host "No content to display." -ForegroundColor Yellow
        }
        return "completed"
    }
    
    # Convert content to array for consistent processing
    $items = @()
    $contentType = $Content.GetType().Name
    Write-Log -LogFile $logFile -Module $functionName -Message "Content type: $contentType" -LogLevel "Verbose"
    Write-Verbose "[$functionName] Content type: $contentType"
    
    if ($Content -is [string])
    {
        # Handle multi-line string - split into lines
        if ([string]::IsNullOrWhiteSpace($Content))
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Content is empty string" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Content is empty string"
            if (-not $Silent)
            {
                Write-Host "No content to display." -ForegroundColor Yellow
            }
            return "completed"
        }
        
        # Split by newlines (handle both Windows and Unix line endings)
        $items = $Content -split "`r`n|`n|`r" | Where-Object { $_ -ne $null }
        Write-Log -LogFile $logFile -Module $functionName -Message "Split string into $($items.Count) lines" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Split string into $($items.Count) lines"
        
        # Use default display for strings if not provided
        if (-not $DisplayScriptBlock)
        {
            $DisplayScriptBlock = { param($line) Write-Host $line }
        }
    }
    elseif ($Content -is [hashtable])
    {
        # Convert hashtable to array of key-value pairs (sorted by key)
        $items = $Content.GetEnumerator() | Sort-Object -Property Key
        Write-Log -LogFile $logFile -Module $functionName -Message "Converted hashtable to $($items.Count) sorted key-value pairs" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Converted hashtable to $($items.Count) sorted key-value pairs"
        
        # Require DisplayScriptBlock for hashtables
        if (-not $DisplayScriptBlock)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "DisplayScriptBlock is required for hashtable content" -LogLevel "Error"
            Write-Warning "[$functionName] DisplayScriptBlock is required for hashtable content"
            return "error: DisplayScriptBlock required for hashtable"
        }
    }
    elseif ($Content -is [System.Collections.IEnumerable] -and $Content -isnot [string])
    {
        # Handle arrays and other collections
        $items = @($Content)
        Write-Log -LogFile $logFile -Module $functionName -Message "Converted collection to array with $($items.Count) items" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Converted collection to array with $($items.Count) items"
        
        # Require DisplayScriptBlock for object arrays (unless items are simple strings)
        if (-not $DisplayScriptBlock)
        {
            if ($items.Count -gt 0 -and $items[0] -isnot [string])
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "DisplayScriptBlock is required for non-string array items" -LogLevel "Error"
                Write-Warning "[$functionName] DisplayScriptBlock is required for non-string array items"
                return "error: DisplayScriptBlock required for object array"
            }
            # Default display for string arrays
            $DisplayScriptBlock = { param($item) Write-Host $item }
        }
    }
    else
    {
        # Single object or PSCustomObject - wrap in array
        $items = @($Content)
        Write-Log -LogFile $logFile -Module $functionName -Message "Wrapped single object into array" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Wrapped single object into array"
        
        # Require DisplayScriptBlock for objects
        if (-not $DisplayScriptBlock)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "DisplayScriptBlock is required for object content" -LogLevel "Error"
            Write-Warning "[$functionName] DisplayScriptBlock is required for object content"
            return "error: DisplayScriptBlock required for objects"
        }
    }
    
    # Check if we have any items to display
    if ($items.Count -eq 0)
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "No items to display after processing" -LogLevel "Verbose"
        Write-Verbose "[$functionName] No items to display after processing"
        if (-not $Silent)
        {
            Write-Host "No content to display." -ForegroundColor Yellow
        }
        return "completed"
    }
    
    Write-Log -LogFile $logFile -Module $functionName -Message "Total items to display: $($items.Count)" -LogLevel "Information"
    Write-Verbose "[$functionName] Total items to display: $($items.Count)"
    
    # Dynamic size calculation if UseDynamicSize is enabled
    if ($UseDynamicSize -and -not $Silent -and -not $NoPaging)
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "UseDynamicSize enabled - calculating lines per item based on content type" -LogLevel "Information"
        Write-Verbose "[$functionName] Calculating dynamic page size based on content"
        
        try
        {
            # Get console dimensions
            $consoleHeight = $Host.UI.RawUI.WindowSize.Height
            $consoleWidth = $Host.UI.RawUI.WindowSize.Width
            
            Write-Verbose "[$functionName] Console dimensions: ${consoleWidth}x${consoleHeight}"
            
            # Determine content type and calculate lines per item
            $estimatedLinesPerItem = 1  # Default for simple content
            
            if ($items.Count -gt 0)
            {
                $firstItem = $items[0]
                
                # Check if items are multi-line strings
                if ($firstItem -is [string])
                {
                    # For multi-line strings, each item is already a line
                    $estimatedLinesPerItem = 1
                    Write-Verbose "[$functionName] Content type: String - using 1 line per item"
                }
                # Check if items are objects with properties (PSCustomObject, etc.)
                elseif ($firstItem -is [PSCustomObject] -or $firstItem.GetType().Name -match 'PSCustomObject|OrderedDictionary')
                {
                    # Calculate average lines based on actual object content
                    $totalLines = 0
                    $sampleSize = [Math]::Min(10, $items.Count)  # Sample first 10 items for performance
                    
                    for ($i = 0; $i -lt $sampleSize; $i++)
                    {
                        $item = $items[$i]
                        $itemLines = 0
                        
                        # Get all properties
                        $properties = $item.PSObject.Properties
                        
                        foreach ($prop in $properties)
                        {
                            # Each property typically takes 1 line
                            $itemLines += 1
                            
                            # Check for Description or similar long-text properties
                            if ($prop.Name -match 'Description|Comments|Notes' -and $prop.Value)
                            {
                                # Calculate wrapped lines for description
                                # Assume "  PropertyName: " prefix (varies, use average of 14 chars)
                                $prefix = 14
                                $availableWidth = $consoleWidth - $prefix
                                
                                if ($availableWidth -gt 0 -and $prop.Value.Length -gt $availableWidth)
                                {
                                    $wrappedLines = [Math]::Ceiling($prop.Value.Length / $availableWidth)
                                    $itemLines += ($wrappedLines - 1)  # Add extra wrapped lines
                                }
                            }
                        }
                        
                        # Add 1 for blank line between items (typical pattern)
                        $itemLines += 1
                        $totalLines += $itemLines
                    }
                    
                    $estimatedLinesPerItem = [Math]::Ceiling($totalLines / $sampleSize)
                    Write-Verbose "[$functionName] Content type: PSCustomObject - calculated $estimatedLinesPerItem lines per item (sampled $sampleSize items)"
                }
                # Check if items are hashtables or other dictionary types
                elseif ($firstItem -is [System.Collections.DictionaryEntry] -or $firstItem -is [hashtable])
                {
                    # Dictionary entries typically display as "Key: Value" on one line
                    $estimatedLinesPerItem = 1
                    Write-Verbose "[$functionName] Content type: Dictionary - using 1 line per item"
                }
                else
                {
                    # For other object types, use a conservative estimate
                    $estimatedLinesPerItem = 3
                    Write-Verbose "[$functionName] Content type: $($firstItem.GetType().Name) - using conservative estimate of 3 lines per item"
                }
            }
            
            Write-Log -LogFile $logFile -Module $functionName -Message "Calculated EstimatedLinesPerItem: $estimatedLinesPerItem" -LogLevel "Information"
            
            # Reserve lines for UI elements:
            # - Initial info (2 lines: total items message + navigation hint)
            # - Title (2-3 lines: blank + title + blank)
            # - Page info header (3 lines: page number + showing items + blank)
            # - Navigation footer (3 lines: blank + separator + navigation prompt)
            # Total reserved: approximately 10-11 lines
            $reservedLines = 11
            
            # Calculate available lines for content
            $availableLines = $consoleHeight - $reservedLines
            
            if ($availableLines -gt 0 -and $estimatedLinesPerItem -gt 0)
            {
                # Calculate max items that fit on screen
                $calculatedPageSize = [Math]::Floor($availableLines / $estimatedLinesPerItem)
                
                # Ensure at least 1 item per page
                if ($calculatedPageSize -lt 1)
                {
                    $calculatedPageSize = 1
                }
                
                # Use the smaller of calculated size or provided PageSize
                # This allows manual override if user wants fewer items per page
                if ($calculatedPageSize -lt $PageSize)
                {
                    Write-Log -LogFile $logFile -Module $functionName -Message "Adjusting PageSize from $PageSize to $calculatedPageSize (console: ${consoleWidth}x${consoleHeight}, lines per item: $estimatedLinesPerItem, available: $availableLines)" -LogLevel "Information"
                    Write-Verbose "[$functionName] Dynamic paging: Adjusted PageSize from $PageSize to $calculatedPageSize"
                    $PageSize = $calculatedPageSize
                }
                else
                {
                    Write-Log -LogFile $logFile -Module $functionName -Message "PageSize $PageSize fits within console (calculated max: $calculatedPageSize)" -LogLevel "Verbose"
                    Write-Verbose "[$functionName] PageSize $PageSize fits within console (calculated max: $calculatedPageSize)"
                }
            }
            else
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Console height $consoleHeight too small for dynamic paging (reserved: $reservedLines), using provided PageSize $PageSize" -LogLevel "Warning"
                Write-Verbose "[$functionName] Console too small for dynamic paging, using provided PageSize"
            }
        }
        catch
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Failed to calculate dynamic page size: $($_.Exception.Message). Using provided PageSize $PageSize" -LogLevel "Warning"
            Write-Verbose "[$functionName] Dynamic paging calculation failed, using provided PageSize: $($_.Exception.Message)"
        }
    }
    elseif ($UseDynamicSize)
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "UseDynamicSize specified but disabled in current mode (Silent=$($Silent.IsPresent), NoPaging=$($NoPaging.IsPresent))" -LogLevel "Verbose"
        Write-Verbose "[$functionName] UseDynamicSize not applicable in current mode"
    }
    
    # Determine if paging is needed
    $needsPaging = ($items.Count -gt $PageSize) -and (-not $NoPaging) -and (-not $Silent)
    
    if (-not $needsPaging)
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Displaying all $($items.Count) items without paging" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Displaying all $($items.Count) items without paging"
        
        if (-not $Silent)
        {
            if (-not [string]::IsNullOrWhiteSpace($Title))
            {
                Write-Host ""
                Write-Host "══ $Title ══" -ForegroundColor Cyan
                Write-Host ""
            }
            
            foreach ($item in $items)
            {
                try
                {
                    & $DisplayScriptBlock $item
                }
                catch
                {
                    Write-Log -LogFile $logFile -Module $functionName -Message "Error displaying item: $($_.Exception.Message)" -LogLevel "Error"
                    Write-Warning "[$functionName] Error displaying item: $($_.Exception.Message)"
                }
            }
        }
        
        return "completed"
    }
    
    # Calculate paging parameters
    $totalItems = $items.Count
    $totalPages = [Math]::Ceiling($totalItems / $PageSize)
    $currentPage = 1
    
    Write-Log -LogFile $logFile -Module $functionName -Message "Paging enabled: $totalItems items, $PageSize per page, $totalPages total pages" -LogLevel "Information"
    Write-Verbose "[$functionName] Paging enabled: $totalItems items, $PageSize per page, $totalPages total pages"
    
    if (-not $Silent -and $ShowPageInfo)
    {
        Write-Host "Total items: $totalItems (showing $PageSize per page, $totalPages pages total)" -ForegroundColor Gray
        Write-Host "Use 'n' for next page, 'p' for previous page, 'q' to quit, or page number to jump" -ForegroundColor Yellow
        Write-Host ""
    }
    
    # Paging loop
    do
    {
        # Calculate page boundaries
        $startIndex = ($currentPage - 1) * $PageSize
        $endIndex = [Math]::Min($startIndex + $PageSize - 1, $totalItems - 1)
        $pageItems = $items[$startIndex..$endIndex]
        
        Write-Log -LogFile $logFile -Module $functionName -Message "Displaying page $currentPage of $totalPages (items $($startIndex + 1) to $($endIndex + 1))" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Displaying page $currentPage of $totalPages (items $($startIndex + 1) to $($endIndex + 1))"
        
        if (-not $Silent)
        {
            # Display title and page info
            if (-not [string]::IsNullOrWhiteSpace($Title))
            {
                Write-Host ""
                Write-Host "══ $Title ══" -ForegroundColor Cyan
            }
            
            if ($ShowPageInfo)
            {
                Write-Host "═══ Page $currentPage of $totalPages ═══" -ForegroundColor Cyan
                Write-Host "Showing items $($startIndex + 1) - $($endIndex + 1) of $totalItems" -ForegroundColor Gray
                Write-Host ""
            }
            
            # Display items on current page
            foreach ($item in $pageItems)
            {
                try
                {
                    & $DisplayScriptBlock $item
                }
                catch
                {
                    Write-Log -LogFile $logFile -Module $functionName -Message "Error displaying item: $($_.Exception.Message)" -LogLevel "Error"
                    Write-Warning "[$functionName] Error displaying item: $($_.Exception.Message)"
                }
            }
            
            # Display navigation prompt
            Write-Host ""
            Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
            Write-Host "Page navigation: [n]ext | [p]revious | [1-$totalPages] jump to page | [q]uit" -ForegroundColor Yellow
            
            # Handle navigation input
            $navigationAction = $null
            
            do
            {
                $userInput = Read-Host "Enter command"
                
                switch ($userInput.ToLower())
                {
                    'n'
                    {
                        if ($currentPage -lt $totalPages)
                        {
                            $currentPage++
                            $navigationAction = 'continue'
                            Write-Log -LogFile $logFile -Module $functionName -Message "User navigated to next page: $currentPage" -LogLevel "Verbose"
                            Write-Verbose "[$functionName] User navigated to next page: $currentPage"
                        }
                        else
                        {
                            Write-Host "Already on last page" -ForegroundColor Yellow
                        }
                    }
                    'p'
                    {
                        if ($currentPage -gt 1)
                        {
                            $currentPage--
                            $navigationAction = 'continue'
                            Write-Log -LogFile $logFile -Module $functionName -Message "User navigated to previous page: $currentPage" -LogLevel "Verbose"
                            Write-Verbose "[$functionName] User navigated to previous page: $currentPage"
                        }
                        else
                        {
                            Write-Host "Already on first page" -ForegroundColor Yellow
                        }
                    }
                    'q'
                    {
                        $navigationAction = 'quit'
                        Write-Log -LogFile $logFile -Module $functionName -Message "User quit paging" -LogLevel "Verbose"
                        Write-Verbose "[$functionName] User quit paging"
                    }
                    default
                    {
                        # Check if it's a page number
                        if ($userInput -match '^\d+$')
                        {
                            $pageNumber = [int]$userInput
                            if ($pageNumber -ge 1 -and $pageNumber -le $totalPages)
                            {
                                $currentPage = $pageNumber
                                $navigationAction = 'continue'
                                Write-Log -LogFile $logFile -Module $functionName -Message "User jumped to page: $currentPage" -LogLevel "Verbose"
                                Write-Verbose "[$functionName] User jumped to page: $currentPage"
                            }
                            else
                            {
                                Write-Host "Invalid page number. Enter 1-$totalPages" -ForegroundColor Red
                            }
                        }
                        else
                        {
                            Write-Host "Invalid command. Use n, p, q, or page number" -ForegroundColor Red
                        }
                    }
                }
                
                if ($navigationAction)
                {
                    break
                }
            } while ($true)
            
            if ($navigationAction -eq 'quit')
            {
                break
            }
            
            # Clear screen for next page (optional - can be disabled if needed)
            Clear-Host
        }
        else
        {
            # Silent mode - just process and exit
            break
        }
    } while ($true)
    
    $finalResult = if ($navigationAction -eq 'quit') { "quit" } else { "completed" }
    Write-Log -LogFile $logFile -Module $functionName -Message "Paging finished: $finalResult" -LogLevel "Information"
    Write-Verbose "[$functionName] Paging finished: $finalResult"
    
    return $finalResult
}

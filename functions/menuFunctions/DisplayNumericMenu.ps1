function DisplayNumericMenu()
{
    <#
    .SYNOPSIS
    Displays a numbered menu with user input validation and optional paging support.

    .DESCRIPTION
    This function presents a numbered menu to the user with automatic paging for large choice lists.
    It handles user input validation, navigation commands (Back, Main Menu, Exit), and provides
    flexible configuration for prompts and behavior. The function supports both immediate selection
    and Enter-required modes.

    The choices parameter accepts two formats:
    - String array (legacy format): @("Option 1", "Option 2", "Option 3")
    - Hashtable array (new format): @(@{name="Option 1"; description="Description 1"}, @{name="Option 2"; description="Description 2"})

    When hashtables are provided, descriptions are displayed after the name in Gray color.

    .PARAMETER choices
    Array of menu choices to display. This parameter is mandatory.
    Accepts either an array of strings (legacy format) or an array of hashtables with 'name'
    and optional 'description' keys (new format). The function auto-detects the format.

    .PARAMETER banner
    Banner message displayed above the menu. Default is "Please press the number of your choice and press enter."

    .PARAMETER Prompt
    Prompt text for user input. Default is "Please select an option".

    .PARAMETER errorMessage
    Error message displayed for invalid selections. Default is "Invalid selection. Please try again."

    .PARAMETER RequireEnter
    When specified, requires user to press Enter after selection instead of immediate processing.

    .PARAMETER MaxItemsPerPage
    Maximum items to display per page. If 0, uses setting from $settings.maxMenuItemsPerPage or defaults to 15.

    .OUTPUTS
    System.String or System.Int32
    Returns selected choice string (the name), navigation command ("Back", "Main Menu"), exit code (0), or
    NoMenusConfigured value if no choices provided.

    .EXAMPLE
    $choice = DisplayNumericMenu -choices @("Option 1", "Option 2", "Option 3")
    $choice = DisplayNumericMenu -choices $items -banner "Select action:" -MaxItemsPerPage 10
    $choice = DisplayNumericMenu -choices @(@{name="Save"; description="Save current file"}, @{name="Load"; description="Load existing file"})

    .NOTES
    Supports automatic paging when choice count exceeds MaxItemsPerPage.
    Navigation options: "B" or "b" for Back, "M" or "m" for Main Menu, "0" for Exit.
    Page navigation: "N" for next page, "P" for previous page.
    Returns NoMenusConfigured value from $returnValues if choices array is empty.
    When hashtables with descriptions are provided, they are displayed in Gray color after the
    choice name, separated by " - " to distinguish them from the menu item name.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $choices,
        [string]$banner = "Please press the number of your choice and press enter.",
        [string]$Prompt = "Please select an option",
        $errorMessage = "Invalid selection. Please try again.",
        [switch]$RequireEnter,
        [int]$MaxItemsPerPage = 0
    )
    #region Print a verbose message with received parameters
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Displaying numeric menu with $($choices.Count) options" -LogLevel "Debug"
    Write-Verbose "[$functionName] Received parameters: $($choices | Out-String)"
    Write-Verbose "[$functionName] Prompt: $Prompt"
    Write-Verbose "[$functionName] ErrorMessage: $errorMessage"
    Write-Verbose "[$functionName] Banner: $banner"
    #endregion
    #Check if we are passed a blank array and return gracefully
    if (-not $choices -or $choices.Count -eq 0)
    {
        Write-Verbose "[$functionName] No choices provided, returning no menus configured message."
        Write-Log -LogFile $LogFile -Module $functionName -Message "No menu items available to display." -LogLevel "Warning"
        return $returnValues.NoMenusConfigured
    }

    # Ensure choices is an array (handle single item case)
    if ($choices -isnot [array])
    {
        $choices = @($choices)
    }

    # Detect if choices are hashtables (new format) or strings (legacy format)
    $isHashtableFormat = $choices[0] -is [hashtable]
    if ($isHashtableFormat)
    {
        Write-Verbose "[$functionName] Detected hashtable format for choices (new format with descriptions)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Using hashtable format for menu choices" -LogLevel "Debug"
    }
    else
    {
        Write-Verbose "[$functionName] Detected string format for choices (legacy format)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Using string format for menu choices" -LogLevel "Debug"
    }

    # Helper function to get the name from a choice (handles both formats)
    $getChoiceName = {
        param($choice)
        if ($choice -is [hashtable])
        {
            # Validate that hashtable has 'name' key
            if ($choice.ContainsKey('name'))
            {
                return $choice.name
            }
            Write-Warning "[$functionName] Hashtable choice missing required 'name' key"
            return "[Unknown]"
        }
        return $choice
    }

    # Helper function to get the description from a choice (returns empty for strings)
    $getChoiceDescription = {
        param($choice)
        if ($choice -is [hashtable] -and $choice.ContainsKey('description') -and $choice.description)
        {
            return $choice.description
        }
        return ""
    }

    # Build a normalized list of choice names for validation and return
    $choiceNames = @()
    foreach ($choice in $choices)
    {
        $choiceNames += & $getChoiceName $choice
    }

    # Get max items per page from settings if not explicitly provided
    if ($MaxItemsPerPage -le 0)
    {
        $MaxItemsPerPage = if ($settings -and $settings.maxMenuItemsPerPage)
        {
            $settings.maxMenuItemsPerPage
        }
        else
        {
            15  # Default if settings not available
        }
    }
    Write-Verbose "[$functionName] Max items per page: $MaxItemsPerPage"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Using max items per page: $MaxItemsPerPage" -LogLevel "Debug"

    # Check if paging is needed
    $needsPaging = $choices.Count -gt $MaxItemsPerPage
    $currentPage = 1
    $totalPages = [Math]::Ceiling($choices.Count / $MaxItemsPerPage)

    if ($needsPaging)
    {
        Write-Verbose "[$functionName] Paging enabled: $($choices.Count) items across $totalPages pages"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Menu paging enabled: $($choices.Count) items, $totalPages pages" -LogLevel "Debug"
    }
    # Main menu display loop (supports paging)
    do
    {
        # Calculate items for current page
        $startIndex = ($currentPage - 1) * $MaxItemsPerPage
        $endIndex = [Math]::Min($startIndex + $MaxItemsPerPage, $choices.Count) - 1
        $pageChoices = $choices[$startIndex..$endIndex]

        # Display page header if paging is active
        if ($needsPaging)
        {
            Write-Host "`n=== Page $currentPage of $totalPages ===" -ForegroundColor Cyan
            Write-Host "Showing items $($startIndex + 1) - $($endIndex + 1) of $($choices.Count)" -ForegroundColor Gray
            Write-Host ""
        }

        # Display the menu options for current page
        Write-Host $banner -ForegroundColor Green
        for ($i = 0; $i -lt $pageChoices.Count; $i++)
        {
            $globalIndex = $startIndex + $i + 1
            $choiceName = & $getChoiceName $pageChoices[$i]
            $choiceDesc = & $getChoiceDescription $pageChoices[$i]

            Write-Host "$globalIndex. $choiceName" -NoNewline -ForegroundColor White

            # Display description if available
            if (-not [string]::IsNullOrWhiteSpace($choiceDesc))
            {
                Write-Host "`n - $choiceDesc" -ForegroundColor Gray
            }
            else
            {
                Write-Host ""
            }
        }
        Write-Host "0. Exit" -ForegroundColor White

        # Add paging navigation options if needed
        if ($needsPaging)
        {
            Write-Host "" -ForegroundColor White
            Write-Host "Navigation: " -NoNewline -ForegroundColor Yellow
            if ($currentPage -lt $totalPages)
            {
                Write-Host "[N]ext page | " -NoNewline -ForegroundColor Yellow
            }
            if ($currentPage -gt 1)
            {
                Write-Host "[P]revious page | " -NoNewline -ForegroundColor Yellow
            }
            Write-Host "[1-$totalPages] Jump to page" -ForegroundColor Yellow
        }

        # Prepare valid key options (numeric keys) - all items remain valid regardless of page
        $validKeys = @()
        for ($i = 0; $i -le $choices.Count; $i++)
        {
            $validKeys += $i.ToString()
        }

        # Add paging navigation keys
        $pagingKeys = @()
        if ($needsPaging)
        {
            if ($currentPage -lt $totalPages)
            {
                $pagingKeys += "n"
            }
            if ($currentPage -gt 1)
            {
                $pagingKeys += "p"
            }
            # Allow page number jumps
            for ($p = 1; $p -le $totalPages; $p++)
            {
                if ($p -ne $currentPage)
                {
                    $pagingKeys += "page$p"
                }
            }
        }

        # Add mnemonic keys based on available choices (easter egg functionality)
        $mnemonicKeys = @()
        if ($choiceNames -contains "Back")
        {
            $mnemonicKeys += "b"
            Write-Verbose "[$functionName] Added mnemonic key 'b' for Back navigation"
        }
        if ($choiceNames -contains "Main Menu")
        {
            $mnemonicKeys += "m"
            Write-Verbose "[$functionName] Added mnemonic key 'm' for Main Menu navigation"
        }
        # Always allow q and e for exit
        $mnemonicKeys += @("q", "e")
        Write-Verbose "[$functionName] Added mnemonic keys 'q' and 'e' for Exit"

        $allValidKeys = $validKeys + $mnemonicKeys + $pagingKeys
        Write-Verbose "[$functionName] Valid keys: $($allValidKeys -join ', ')"
        Write-Verbose "[$functionName] Mnemonic keys: $($mnemonicKeys -join ', ')"
        if ($needsPaging)
        {
            Write-Verbose "[$functionName] Paging keys: $($pagingKeys -join ', ')"
        }
        Write-Log -LogFile $LogFile -Module $functionName -Message "Valid menu options: $($validKeys -join ', '), Mnemonic keys: $($mnemonicKeys -join ', ')" -LogLevel "Debug"

        # Handle paging navigation
        $pageNavigationOccurred = $false

        if ($RequireEnter)
        {
            # Original behavior with ReadLine
            Write-Verbose "[$functionName] Using ReadLine for input (requires Enter key)..."
            Write-Log -LogFile $LogFile -Module $functionName -Message "Using ReadLine for input (requires Enter key)" -LogLevel "Debug"
            Write-Host "$Prompt " -NoNewline -ForegroundColor Yellow
            $selection = $host.UI.ReadLine()
            Write-Verbose "[$functionName] User input received: '$selection'"
            Start-Sleep -Milliseconds 600
            # Clean input
            $selection = $selection.Trim().ToLower()
            Write-Verbose "[$functionName] Raw user input received after cleanup: '$selection'"
        }
        else
        {
            # New behavior with immediate keystroke capture
            Write-Verbose "[$functionName] Waiting for keystroke input (no Enter required)..."
            Write-Log -LogFile $LogFile -Module $functionName -Message "Waiting for keystroke input (no Enter required)" -LogLevel "Debug"
            Write-Host "$Prompt " -NoNewline -ForegroundColor Yellow
            $keyInfo = $null
            $selection = $null
            # Keep reading keys until a valid one is pressed
            do
            {
                Write-Verbose "[$functionName] Waiting for key press..."
                try
                {
                    $keyInfo = $host.UI.RawUI.ReadKey("NoEcho, IncludeKeyDown")
                    $selection = $keyInfo.Character.ToString().ToLower()
                    Write-Verbose "[$functionName] Key pressed: '$selection' (Character code: $([int]$keyInfo.Character))"
                    $keyCode = [int]$keyInfo.VirtualKeyCode
                    Write-Verbose "[$functionName] Key pressed virtual code: '$selection' (Character code: $([int]$keyInfo.Character), VK: $keyCode)"
                    # Handle special case for numpad keys which might have different character codes
                    if ($keyCode -ge 96 -and $keyCode -le 105)
                    {
                        # Convert numpad key codes (96-105) to numbers (0-9)
                        Write-Verbose "[$functionName] Detected numpad key press."
                        $selection = ($keyCode - 96).ToString()
                        Write-Verbose "[$functionName] Converted numpad key to: $selection"
                    }
                }
                catch
                {
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Error reading key: $_" -LogLevel "Verbose"
                    $selection = $null
                }
            } until ($allValidKeys -contains $selection)

            # Echo the selection so user can see what was chosen
            Write-Host $selection -ForegroundColor Green
            Write-Log -LogFile $LogFile -Module $functionName -Message "Valid key pressed: '$selection'" -LogLevel "Debug"
        }

        # Handle paging navigation first
        if ($needsPaging)
        {
            if ($selection -eq "n" -and $currentPage -lt $totalPages)
            {
                Write-Verbose "[$functionName] Navigating to next page"
                $currentPage++
                $pageNavigationOccurred = $true
            }
            elseif ($selection -eq "p" -and $currentPage -gt 1)
            {
                Write-Verbose "[$functionName] Navigating to previous page"
                $currentPage--
                $pageNavigationOccurred = $true
            }
            elseif ($selection -match '^\d+$')
            {
                $pageNum = [int]$selection
                if ($pageNum -ge 1 -and $pageNum -le $totalPages -and $pageNum -ne $currentPage)
                {
                    Write-Verbose "[$functionName] Jumping to page $pageNum"
                    $currentPage = $pageNum
                    $pageNavigationOccurred = $true
                }
            }
        }

        # If page navigation occurred, continue to next iteration
        if ($pageNavigationOccurred)
        {
            continue
        }

        # Validate the selection and handle mnemonic keys
        while ($selection -notin $allValidKeys)
        {
            # Check if it's a valid numeric selection
            if ($selection -match '^\d+$' -and [int]$selection -ge 0 -and [int]$selection -le $choiceNames.Count)
            {
                break
            }

            Write-Host $errorMessage -ForegroundColor Red
            Write-Log -LogFile $LogFile -Module $functionName -Message "Invalid selection: '$selection'" -LogLevel "Warning"
            [console]::beep(1000, 500)

            if ($RequireEnter)
            {
                # Re-prompt with ReadLine
                $selection = Read-Host -Prompt $Prompt
                $selection = $selection.Trim().ToLower()
            }
            else
            {
                # Re-prompt
                $selection = $null
                $keyInfo = $host.UI.RawUI.ReadKey("NoEcho, IncludeKeyDown")
                $selection = [string]$keyInfo.Character.ToString().ToLower()
            }
        }
        # Break out of paging loop if a valid menu selection was made
        if (-not $pageNavigationOccurred)
        {
            break
        }
    } while ($needsPaging)  # End of paging loop

    # Handle mnemonic keys first
    if ($selection -eq "b" -and $choiceNames -contains "Back")
    {
        Write-Verbose "[$functionName] Mnemonic key 'b' pressed, returning 'Back'"
        Write-Log -LogFile $LogFile -Module $functionName -Message "User pressed mnemonic key 'b' for Back navigation" -LogLevel "Information"
        return "Back"
    }
    elseif ($selection -eq "m" -and $choiceNames -contains "Main Menu")
    {
        Write-Verbose "[$functionName] Mnemonic key 'm' pressed, returning 'Main Menu'"
        Write-Log -LogFile $LogFile -Module $functionName -Message "User pressed mnemonic key 'm' for Main Menu navigation" -LogLevel "Information"
        return "Main Menu"
    }
    elseif ($selection -in @("q", "e"))
    {
        Write-Verbose "[$functionName] Mnemonic key '$selection' pressed for exit"
        Write-Log -LogFile $LogFile -Module $functionName -Message "User pressed mnemonic key '$selection' for exit" -LogLevel "Information"
        return [int]0
    }
    elseif ($selection -eq "0")
    {
        Write-Verbose "[$functionName] Exiting script with selection: $selection"
        Write-Log -LogFile $LogFile -Module $functionName -Message "User selected exit option" -LogLevel "Information"
        # Return integer 0 for exit option to ensure proper type matching
        return [int]$selection
    }
    elseif ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $choiceNames.Count)
    {
        # Convert to integer explicitly to avoid any type conversion issues
        $index = [int]$selection - 1
        Write-Verbose "[$functionName] Returning choice at index $($index): '$($choiceNames[$index])'"
        Write-Log -LogFile $LogFile -Module $functionName -Message "User selected option $($index + 1): '$($choiceNames[$index])'" -LogLevel "Debug"
        # Return the selected choice name
        return $choiceNames[$index]
    }
    else
    {
        # This should not happen due to validation, but handle as fallback
        Write-Log -LogFile $LogFile -Module $functionName -Message "Unexpected selection: $selection, defaulting to exit" -LogLevel "Warning"
        return [int]0
    }
}


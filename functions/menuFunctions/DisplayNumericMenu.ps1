function DisplayNumericMenu()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string[]]$choices,
        [string]$banner = "Please press the number of your choice and press enter.",
        [string]$Prompt = "Please select an option",
        $errorMessage = "Invalid selection. Please try again.",
        [switch]$RequireEnter
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
    # Display the menu options
    Write-Host $banner -ForegroundColor Green
    for ($i = 0; $i -lt $choices.Count; $i++)
    {
        Write-Host "$($i + 1). $($choices[$i])" -ForegroundColor White
    }
    Write-Host "0. Exit" -ForegroundColor White
    
    # Prepare valid key options (numeric keys)
    $validKeys = @()
    for ($i = 0; $i -le $choices.Count; $i++)
    {
        $validKeys += $i.ToString()
    }
    
    # Add mnemonic keys based on available choices (easter egg functionality)
    $mnemonicKeys = @()
    if ($choices -contains "Back")
    {
        $mnemonicKeys += "b"
        Write-Verbose "[$functionName] Added mnemonic key 'b' for Back navigation"
    }
    if ($choices -contains "Main Menu")
    {
        $mnemonicKeys += "m"
        Write-Verbose "[$functionName] Added mnemonic key 'm' for Main Menu navigation"
    }
    # Always allow q and e for exit
    $mnemonicKeys += @("q", "e")
    Write-Verbose "[$functionName] Added mnemonic keys 'q' and 'e' for Exit"
    
    $allValidKeys = $validKeys + $mnemonicKeys
    Write-Verbose "[$functionName] Valid keys: $($allValidKeys -join ', ')"
    Write-Verbose "[$functionName] Mnemonic keys: $($mnemonicKeys -join ', ')"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Valid menu options: $($validKeys -join ', '), Mnemonic keys: $($mnemonicKeys -join ', ')" -LogLevel "Debug"
    
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
    
    # Validate the selection and handle mnemonic keys
    while ($selection -notin $allValidKeys)
    {
        # Check if it's a valid numeric selection
        if ($selection -match '^\d+$' -and [int]$selection -ge 0 -and [int]$selection -le $choices.Count)
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
    # Handle mnemonic keys first
    if ($selection -eq "b" -and $choices -contains "Back")
    {
        Write-Verbose "[$functionName] Mnemonic key 'b' pressed, returning 'Back'"
        Write-Log -LogFile $LogFile -Module $functionName -Message "User pressed mnemonic key 'b' for Back navigation" -LogLevel "Information"
        return "Back"
    }
    elseif ($selection -eq "m" -and $choices -contains "Main Menu")
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
    elseif ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $choices.Count)
    {
        # Convert to integer explicitly to avoid any type conversion issues
        $index = [int]$selection - 1
        Write-Verbose "[$functionName] Returning choice at index $($index): '$($choices[$index])'"
Write-Log -LogFile $LogFile -Module $functionName -Message "User selected option $($index + 1): '$($choices[$index])'" -LogLevel "Debug"
        # Return the selected choice
        return $choices[$index]
    }
    else
    {
        # This should not happen due to validation, but handle as fallback
        Write-Log -LogFile $LogFile -Module $functionName -Message "Unexpected selection: $selection, defaulting to exit" -LogLevel "Warning"
        return [int]0
    }
}


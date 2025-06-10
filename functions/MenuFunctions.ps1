function DisplayNumericMenu()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$choices,
        [string]$banner = "Please press the number of your choice and press enter.",
        [string]$Prompt = "Please select an option",
        $errorMessage = "Invalid selection. Please try again.",
        [switch]$RequireEnter
    )
    #region Print a verbose message with received parameters
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Received parameters: $($choices | Out-String)"
    Write-Verbose "[$functionName] Prompt: $Prompt"
    Write-Verbose "[$functionName] ErrorMessage: $errorMessage"
    Write-Verbose "[$functionName] Banner: $banner"
    #endregion

    # Display the menu options
    Write-Host $banner -ForegroundColor Green
    for ($i = 0; $i -lt $choices.Count; $i++)
    {
        Write-Host "$($i + 1). $($choices[$i])"
    }
    Write-Host "0. Exit"
    
    # Prepare valid key options
    $validKeys = @()
    for ($i = 0; $i -le $choices.Count; $i++)
    {
        $validKeys += $i.ToString()
    }
    Write-Verbose "[$functionName] Valid keys: $($validKeys -join ', ')"
    
    if ($RequireEnter)
    {
        # Original behavior with ReadLine
        Write-Verbose "[$functionName] Using ReadLine for input (requires Enter key)..."
        Write-Host "$Prompt " -NoNewline -ForegroundColor Yellow
        $selection = $host.UI.ReadLine()
        Write-Verbose "[$functionName] User input received: '$selection'"
        Start-Sleep -Milliseconds 600
        # Clean input
        $selection = $selection.Trim()
        Write-Verbose "[$functionName] Raw user input received after cleanup: '$selection'"
    }
    else
    {
        # New behavior with immediate keystroke capture
        Write-Verbose "[$functionName] Waiting for keystroke input (no Enter required)..."
        Write-Host "$Prompt " -NoNewline -ForegroundColor Yellow
        $keyInfo = $null
        $selection = $null
        # Keep reading keys until a valid one is pressed
        do
        {
            Write-Verbose "[$functionName] Waiting for key press..."
            try
            {
                $keyInfo = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                $selection = $keyInfo.Character.ToString()
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
                Write-Verbose "[$functionName] Error reading key: $_"
                $selection = $null
            }
        } until ($validKeys -contains $selection)
        
        # Echo the selection so user can see what was chosen
        Write-Host $selection
        Write-Verbose "[$functionName] Valid key pressed: '$selection'"
    }
    
    # Validate the selection
    while ($selection -notmatch '^\d+$' -or [int]$selection -lt 0 -or [int]$selection -gt $choices.Count)
    {
        Write-Host $errorMessage -ForegroundColor Red
        Write-Verbose "[$functionName] Invalid selection: '$selection'"
        [console]::beep(1000, 500)
        
        if ($RequireEnter)
        {
            # Re-prompt with ReadLine
            $selection = Read-Host -Prompt $Prompt
            $selection = $selection.Trim()
        }
        else
        {
            # Re-prompt
            $selection = $null
            $keyInfo = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            $selection = [string]$keyInfo.Character.ToString()
        }
    }
    if ($selection -ne "0")
    {
        # Convert to integer explicitly to avoid any type conversion issues
        $index = [int]$selection - 1
        Write-Verbose "[$functionName] Returning choice at index $($index): '$($choices[$index])'"
        # Return the selected choice
        return $choices[$index]
    }
    else
    {
        Write-Verbose "[$functionName] Exiting script with selection: $selection"
        # Return integer 0 for exit option to ensure proper type matching
        return [int]$selection
    }
}

function NewMenu()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [Parameter(Mandatory = $false)]
        [string]$Description
    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Creating new menu with title: $Title and description: $Description"    
    $menu = [ordered]@{
        Title       = $Title
        Description = $Description
        Items       = @()
    }
    
    return $menu
}

function AddMenuItem()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Menu,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $false)]
        [scriptblock]$Action,
        [Parameter(Mandatory = $false)]
        [hashtable]$Submenu,
        [Parameter(Mandatory = $false)]
        [switch]$ReturnsValue
    )
    $functionName = $MyInvocation.MyCommand.Name
    if ($Action -and $Submenu)
    {
        throw "A menu item cannot have both an Action and a Submenu."
    }
    
    if (-not $Action -and -not $Submenu)
    {
        throw "A menu item must have either an Action or a Submenu."
    }
    
    $item = [ordered] @{
        Name         = $Name
        Action       = $Action
        Submenu      = $Submenu
        ReturnsValue = $ReturnsValue
    }
    Write-Verbose "[$functionName] Adding the following menu item:"
    Write-Verbose "[$functionName] name: $Name"
    if ($null -ne $action -or $action -eq '')
    {
        Write-Verbose "[$functionName] Type: action"
    }
    if ($null -ne $Submenu -or $Submenu -eq '')
    {
        Write-Verbose "[$functionName] Type: submenu"
    }
    Write-Verbose "[$functionName] returns value: $ReturnsValue"
    $Menu.Items += $item
    return $Menu
}

function GoBack()
{
    [CmdletBinding()]
    param(    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Going back to previous menu."
    if ($Global:History.Count -gt 0 -and $Global:MenuHistory.Count -gt 0)
    {
        Write-Verbose "[$functionName] Removing last item from history since count is $($Global:History.Count)"
        $Global:History.RemoveAt($Global:History.Count - 1)
        # Get previous menu from MenuHistory
        Write-Verbose "[$functionName] Getting previous menu from MenuHistory since count is $($Global:MenuHistory.Count)"
        if ($Global:MenuHistory.Count -gt 0)
        {
            Write-Verbose "[$functionName] Finding previous menu by removing last item from MenuHistory."
            $previousMenu = $Global:MenuHistory[$Global:MenuHistory.Count - 1]
            Write-Verbose "[$functionName] Previous menu found: $($previousMenu.Title)"
            Write-Verbose "[$functionName] Removing last menu from MenuHistory since count is $($Global:MenuHistory.Count)"
            $Global:MenuHistory.RemoveAt($Global:MenuHistory.Count - 1)
            Write-Verbose "[$functionName] Current depth after going back: $($Global:MenuHistory.Count)"
            Write-Verbose "[$functionName] Returning to previous menu: $($previousMenu.Title)"
            return ShowMenu -Menu $previousMenu 
        }
    }
    else
    {
        Write-Verbose "[$functionName] Cannot go back - no previous menu available"
        return ShowMenu -Menu $Menu 
    }
}

function GoToMainMenu()
{
    [CmdletBinding()]
    param ()
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Going to main menu."
    # Go to main menu
    if ($Global:MenuHistory.Count -gt 0)
    {
        $mainMenu = $Global:MenuHistory[0]
        Write-Verbose "[$functionName] Clearing history and menu history since we are going to main menu."
        $Global:History.Clear()
        $Global:MenuHistory.Clear()
        [void]$Global:MenuHistory.Add($mainMenu)
        Write-Verbose "[$functionName] Reset to main menu. Current depth: $($Global:MenuHistory.Count)"
        return ShowMenu -Menu $mainMenu
    }
    else
    {
        Write-Verbose "[$functionName] Cannot go to main menu - no main menu available"
        return ShowMenu -Menu $Menu 
    }
}

function Get-CallingContext()
{
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Examine the call stack to determine context
    Write-Verbose "[$functionName] Analyzing call stack to determine context"
    $callStack = Get-PSCallStack
    Write-Verbose "[$functionName] Call stack depth: $($callStack.Count)"
    
    # Look at the calling function (skip current function)
    if ($callStack.Count -gt 1)
    {
        Write-Verbose "[$functionName] Call stack has more than one entry, analyzing caller"
        $caller = $callStack[1]
        Write-Verbose "[$functionName] Called from: $($caller.FunctionName) at line $($caller.ScriptLineNumber)"
        
        # If called from ShowMenu itself, it's likely navigation
        if ($caller.FunctionName -eq 'ShowMenu')
        {
            Write-Verbose "[$functionName] Called from ShowMenu, assuming navigation context"
            return 'Navigation'
        }
        
        # Check if called from known navigation functions
        if ($caller.FunctionName -in @('Handle-BackNavigation', 'Handle-MainMenuNavigation', 'GoBack', 'GoToMainMenu'))
        {
            return 'Navigation'
        }
    }
    
    # If we can't determine from call stack, assume direct call
    return 'Direct'
}

function Push-MenuToStack()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Menu
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    try
    {
        # Only add if it's not already the current menu to prevent duplicates
        if ($Global:MenuHistory.Count -eq 0 -or $Global:MenuHistory[-1].Title -ne $Menu.Title)
        {
            Write-Verbose "[$functionName] Pushing menu '$($Menu.Title)' to stack"
            Write-Verbose "[$functionName] Current History Count: $($Global:History.Count)"
            [void]$Global:History.Add($Menu.Title)
            Write-Verbose "[$functionName] New History Count: $($Global:History.Count)"
            Write-Verbose "[$functionName] Current History: $($Global:History -join ', ')"
            Write-Verbose "[$functionName] Current MenuHistory Count: $($Global:MenuHistory.Count)"
            [void]$Global:MenuHistory.Add($Menu)
            Write-Verbose "[$functionName] New MenuHistory Count: $($Global:MenuHistory.Count)"
            Write-Verbose "[$functionName] Pushed menu '$($Menu.Title)' to stack. New depth: $($Global:MenuHistory.Count)"
        }
        else
        {
            Write-Verbose "[$functionName] Menu '$($Menu.Title)' already at top of stack, skipping push"
        }
    }
    catch
    {
        Write-Verbose "[$functionName] Error pushing to stack: $_"
        # Fallback for PowerShell 5.1 compatibility
        Write-Verbose "[$functionName] Using fallback method to push menu '$($Menu.Title)'"
        Write-Verbose "Current history count: $($Global:History.Count)"
        $Global:History += $Menu.Title
        Write-Verbose "New history count: $($Global:History.Count)"
        Write-Verbose "Current menu history count: $($Global:MenuHistory.Count)"
        $Global:MenuHistory += $Menu
        Write-Verbose "New menu history count: $($Global:MenuHistory.Count)"
        Write-Verbose "[$functionName] Used fallback method to push menu '$($Menu.Title)'. New depth: $($Global:MenuHistory.Count)"
    }
}

function Pop-MenuFromStack()
{
    [CmdletBinding()]
    param()
    
    $functionName = $MyInvocation.MyCommand
    if ($Global:History.Count -gt 0 -and $Global:MenuHistory.Count -gt 0)
    {
        Write-Host "[$functionName] Starting pop operation"
        Write-Verbose "[$functionName] Popping menu from stack"
        try
        {
            Write-Host "[$functionName] Current History Count: $($Global:History.Count)"
            Write-Host "[$functionName] Current History : $($Global:History -join ', ')"
            $Global:History.RemoveAt($Global:History.Count - 1)
            Write-Host "[$functionName] New History Count: $($Global:History.Count)"
            Write-Host "[$functionName] New history: $($Global:History -join ', ')"
            Write-Host "[$functionName] Current MenuHistory Count: $($Global:MenuHistory.Count)"
            # Write-Host "[$functionName] Current MenuHistory: $($Global:MenuHistory | ForEach-Object { $_.Title } -join ', ')"
            
            # Get the menu that was just removed for logging
            $poppedMenu = $Global:MenuHistory[$Global:MenuHistory.Count - 1]
            Write-Host "[$functionName] Removing menu: $($poppedMenu.Title)"
            # Remove the current menu from the stack
            $Global:MenuHistory.RemoveAt($Global:MenuHistory.Count - 1)
            Write-Host "[$functionName] New MenuHistory Count after pop: $($Global:MenuHistory.Count)"
            # Create a simple array of titles for display
            $menuTitles = $Global:MenuHistory | ForEach-Object { $_.Title }
            $menuTitlesString = $menuTitles -join ', '
            Write-Host "[$functionName] New MenuHistory: $menuTitlesString"
            # Return the menu that is now at the top of the stack (the previous menu)
            if ($Global:MenuHistory.Count -gt 0)
            {
                Write-Host "[$functionName] Latest MenuHistory Count: $($Global:MenuHistory.Count)"
                Write-Host "[$functionName] Stack is not empty, returning to previous menu"
                try
                {
                    $targetMenu = $Global:MenuHistory[$Global:MenuHistory.Count - 1]
                    if ($targetMenu -and $targetMenu.Title)
                    {
                        Write-Host "[$functionName] Previous menu: $($targetMenu.Title)"
                        Write-Host "[$functionName] Returning to previous menu: $($targetMenu.Title)"
                        return $targetMenu
                    }
                    else
                    {
                        Write-Host "[$functionName] Error: Target menu is null or missing Title property"
                        return $null
                    }
                }
                catch
                {
                    Write-Host "[$functionName] Error accessing target menu: $_"
                    return $null
                }
            }
            else
            {
                Write-Host "[$functionName] Latest MenuHistory Count: $($Global:MenuHistory.Count)"
                Write-Host "[$functionName] Stack is now empty, cannot return to previous menu"
                return $null
            }        
        }
        catch
        {
            Write-Host "[$functionName] Error popping from stack: $_"
            Write-Host "[$functionName] Error details: $($_.Exception.Message)"
            Write-Host "[$functionName] Stack trace: $($_.ScriptStackTrace)"
            return $null
        }
    }
    else
    {
        Write-Verbose "[$functionName] Cannot pop - stack is empty"
        return $null
    }
}

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

function Handle-BackNavigation()
{
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Handling back navigation"
    
    if ($Global:MenuHistory.Count -gt 0)
    {
        Write-Verbose "[$functionName] Current MenuHistory Count: $($Global:MenuHistory.Count)"
        $targetMenu = Pop-MenuFromStack
        
        if ($targetMenu)
        {
            Write-Verbose "[$functionName] Returning to previous menu: $($targetMenu.Title)"
            return ShowMenu -Menu $targetMenu -CalledBy 'Navigation' -StackOperation 'None'
        }
    }
    
    Write-Verbose "[$functionName] Cannot go back - no previous menu available"
    return $null
}

function Handle-MainMenuNavigation()
{
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Handling main menu navigation"
    
    if ($Global:MenuHistory.Count -gt 0)
    {
        Write-Verbose "[$functionName] Current MenuHistory Count: $($Global:MenuHistory.Count)"
        $mainMenu = $Global:MenuHistory[0]
        Write-Verbose "[$functionName] Clearing stack and returning to main menu: $($mainMenu.Title)"
        
        # Clear stack and reset to main menu
        $Global:History.Clear()
        $Global:MenuHistory.Clear()
        
        return ShowMenu -Menu $mainMenu -CalledBy 'Navigation' -StackOperation 'Push'
    }
    
    Write-Verbose "[$functionName] Cannot go to main menu - no main menu available"
    return $null
}

function Handle-MenuItemSelection()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $SelectedOption,
        [Parameter(Mandatory = $true)]
        [array]$Choices,
        [Parameter(Mandatory = $true)]
        [array]$MenuItems,
        [Parameter(Mandatory = $true)]
        [hashtable]$CurrentMenu
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Find the selected item
    $selectedIndex = -1
    for ($i = 0; $i -lt $Choices.Count; $i++)
    {
        Write-Verbose "[$functionName] Checking choice $($i): $($Choices[$i]) against selected option: $SelectedOption"
        if ($Choices[$i] -eq $SelectedOption)
        {
            Write-Verbose "[$functionName] Match found at index $i"
            $selectedIndex = $i
            break
        }
    }
    
    if ($selectedIndex -eq -1 -or $selectedIndex -ge $MenuItems.Count)
    {
        Write-Verbose "[$functionName] Invalid selection index: $selectedIndex"
        return ShowMenu -Menu $CurrentMenu -CalledBy 'Direct' -StackOperation 'None'
    }
    
    $selectedItem = $MenuItems[$selectedIndex]
    Write-Verbose "[$functionName] Selected item: $($selectedItem.Name)"
    
    if ($selectedItem.Action)
    {
        Write-Verbose "[$functionName] Selected item has an Action"
        return Handle-ActionExecution -SelectedItem $selectedItem -CurrentMenu $CurrentMenu
    }
    elseif ($selectedItem.Submenu)
    {
        Write-Verbose "[$functionName] Selected item has a Submenu"
        return Handle-SubmenuNavigation -SelectedItem $selectedItem
    }
    else
    {
        Write-Verbose "[$functionName] Selected item has neither Action nor Submenu"
        return ShowMenu -Menu $CurrentMenu -CalledBy 'Direct' -StackOperation 'None'
    }
}

function Handle-ActionExecution()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $SelectedItem,
        [Parameter(Mandatory = $true)]
        [hashtable]$CurrentMenu
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Executing action: $($SelectedItem.Name)"
    
    # Execute the action
    $result = & $SelectedItem.Action
    Write-Verbose "[$functionName] Action executed, result: $result"
    
    # Handle different result types
    if ($SelectedItem.ReturnsValue)
    {
        Write-Verbose "[$functionName] Action returns a value, processing result"
        # Handle navigation results from actions
        if ($result -eq "Back")
        {
            Write-Verbose "[$functionName] Action returned 'Back', navigating back"
            return Handle-BackNavigation
        }
        elseif ($result -eq "Main Menu")
        {
            Write-Verbose "[$functionName] Action returned 'Main Menu', navigating to main menu"
            return Handle-MainMenuNavigation
        }
        elseif ($result -eq 0)
        {
            Write-Verbose "[$functionName] Action returned 0, exiting application"
            return [int]$result
        }
        
        Write-Verbose "[$functionName] Action returned value: $result"
        return $result
    }
    
    # Handle special signals
    if ($result -eq "EXIT_APPLICATION")
    {
        Write-Verbose "[$functionName] Action requested application exit"
        return $null
    }
    
    if ($result -eq $backoutText)
    {
        Write-Verbose "[$functionName] Action returned backout text"
        return ShowMenu -Menu $CurrentMenu -CalledBy 'Action' -StackOperation 'None'
    }
    
    # Display result and continue
    if ($null -ne $result)
    {
        Write-Host "`n$result" -ForegroundColor Cyan
    }
    
    Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    return ShowMenu -Menu $CurrentMenu -CalledBy 'Action' -StackOperation 'None'
}

function Handle-SubmenuNavigation()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $SelectedItem
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Navigating to submenu: $($SelectedItem.Submenu.Title)"
    
    return ShowMenu -Menu $SelectedItem.Submenu -CalledBy 'Submenu' -StackOperation 'Auto'
}

function ShowMenu()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Menu,
        [Parameter(Mandatory = $false)]
        [string]$BackoutText = $backoutText,
        [Parameter(Mandatory = $false)]
        [ValidateSet('Auto', 'Push', 'Pop', 'None')]
        [string]$StackOperation = 'Auto',
        [Parameter(Mandatory = $false)]
        [ValidateSet('Unknown', 'Direct', 'Action', 'Submenu', 'Navigation')]
        [string]$CalledBy = 'Unknown'
    )
    $functionName = $MyInvocation.MyCommand.Name
    # region Initialize global variables if they don't exist and display debug
    Write-Verbose "[$functionName] Initializing global variables if not already set"
    Write-Verbose "Menu history count: $($Global:MenuHistory.Count)"
    Write-Verbose "History count: $($Global:History.Count)"

    if (-not $Global:MenuHistory)
    {
        Write-Verbose "[$functionName] Initializing MenuHistory"
        $Global:MenuHistory = [System.Collections.ArrayList]::new() 
    }
    if (-not $Global:History)
    {
        Write-Verbose "[$functionName] Initializing History"
        $Global:History = [System.Collections.ArrayList]::new() 
    }
    Write-Verbose "[$functionName] ===== MENU NAVIGATION DEBUG ====="
    Write-Verbose "[$functionName] Entering ShowMenu for: $($Menu.Title)"
    Write-Verbose "[$functionName] CalledBy: $CalledBy"
    Write-Verbose "[$functionName] StackOperation: $StackOperation"
    Write-Verbose "[$functionName] Current Depth: $($Global:MenuHistory.Count)"
    Write-Verbose "[$functionName] History Count: $($Global:History.Count)"
    Write-Verbose "[$functionName] MenuHistory Count: $($Global:MenuHistory.Count)"
    #endregion

    # Determine calling context if not explicitly provided
    if ($CalledBy -eq 'Unknown')
    {
        Write-Verbose "[$functionName] CalledBy is 'Unknown', determining calling context"
        $CalledBy = Get-CallingContext
        Write-Verbose "[$functionName] Determined CalledBy: $CalledBy"
    }
    
    # Handle stack operations based on calling context and explicit instructions
    switch ($StackOperation)
    {
        'Auto'
        {
            Write-Verbose "[$functionName] Auto stack operation based on CalledBy context"
            switch ($CalledBy)
            {
                'Submenu'
                {
                    Write-Verbose "[$functionName] Auto-pushing to stack for submenu navigation"
                    Push-MenuToStack -Menu $Menu
                }
                'Action'
                {
                    Write-Verbose "[$functionName] Auto-pushing to stack for action execution"
                    Push-MenuToStack -Menu $Menu
                }
                'Navigation'
                {
                    Write-Verbose "[$functionName] No stack operation for navigation"
                    # Navigation (Back/Main Menu) handles its own stack management
                }                'Direct'
                {
                    Write-Verbose "[$functionName] Direct call - checking if this is initial menu"
                    # Check if this is the initial main menu call (already in stack from main.ps1)
                    if ($Global:MenuHistory.Count -eq 1 -and $Global:MenuHistory[0].Title -eq $Menu.Title)
                    {
                        Write-Verbose "[$functionName] Initial main menu call - already in stack, no push needed"
                    }
                    elseif ($Global:MenuHistory.Count -eq 0)
                    {
                        Write-Verbose "[$functionName] Empty stack - adding initial menu"
                        Push-MenuToStack -Menu $Menu
                    }
                    else
                    {
                        Write-Verbose "[$functionName] Direct call with existing stack - pushing menu"
                        Push-MenuToStack -Menu $Menu
                    }
                }
            }
        }
        'Push'
        {
            Write-Verbose "[$functionName] Explicit push to stack"
            Push-MenuToStack -Menu $Menu
        }
        'Pop'
        {
            Write-Verbose "[$functionName] Explicit pop from stack"
            Pop-MenuFromStack
        }
        'None'
        {
            Write-Verbose "[$functionName] No stack operation requested"
        }
    }    
    Write-Verbose "[$functionName] Stack state after operation - MenuHistory Count: $($Global:MenuHistory.Count), History: $($Global:History.Count)"
    Write-Verbose "[$functionName] =================================="
    
    #region Display choices and add navigation options
    $choices = @()
    $menuItems = @()
    Write-Verbose "[$functionName] Initializing choices and menu items."
    
    # Loop through menu items and add to choices
    foreach ($item in $Menu.Items)
    {
        Write-Verbose "[$functionName] Adding item: $($item.Name)"
        $choices += $item.Name
        $menuItems += $item
    }

    # Add navigation options based on current depth
    if ($Global:MenuHistory.Count -gt 0)
    {
        Write-Verbose "[$functionName] Adding 'Back' option since depth is $($Global:MenuHistory.Count)"
        $choices += "Back"
    }
    if ($Global:MenuHistory.Count -gt 1)
    {
        Write-Verbose "[$functionName] Adding 'Main Menu' option since depth is $($Global:MenuHistory.Count)"
        $choices += "Main Menu"
    }
    #endregion

    #region Create banner text and breadcrumb
    $banner = Create-MenuBanner -Menu $Menu -History $Global:History
    #endregion

    # Display menu and get selection
    $selectedOption = DisplayNumericMenu -choices $choices -banner $banner -Prompt "Please select an option" -RequireEnter
    Write-Verbose "[$functionName] Selected option: $selectedOption"
    
    # Handle navigation options
    if ($selectedOption -eq "Back" -or $selectedOption -eq "back")
    {
        return Handle-BackNavigation
    }
    elseif ($selectedOption -eq "Main Menu" -or $selectedOption -eq "main menu")
    {
        return Handle-MainMenuNavigation
    }
    elseif ($selectedOption -eq 0 -or $selectedOption -eq "0")
    {
        Write-Verbose "[$functionName] Exiting application"
        return $null
    }
    else
    {
        # Handle menu item selection
        return Handle-MenuItemSelection -SelectedOption $selectedOption -Choices $choices -MenuItems $menuItems -CurrentMenu $Menu
    }
}

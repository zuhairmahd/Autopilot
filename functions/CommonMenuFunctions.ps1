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
        Start-Sleep -Milliseconds 600
        # Clean input
        $selection = $selection.Trim()
        Write-Verbose "[$functionName] Raw user input received: '$selection'"
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
                $keyCode = [int]$keyInfo.VirtualKeyCode
                Write-Verbose "[$functionName] Key pressed: '$selection' (Character code: $([int]$keyInfo.Character), VK: $keyCode)"
                # Handle special case for numpad keys which might have different character codes
                if ($keyCode -ge 96 -and $keyCode -le 105)
                {
                    # Convert numpad key codes (96-105) to numbers (0-9)
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
            $selection = $keyInfo.Character.ToString()
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

function ShowMenu()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Menu,
        [Parameter(Mandatory = $false)]
        [int]$Depth = 0,
        [Parameter(Mandatory = $false)]
        [System.Collections.ArrayList]$History = $null,
        [Parameter(Mandatory = $false)]
        [System.Collections.ArrayList]$MenuHistory = $null,
        [string]$BackoutText = $backoutText
    )
    #region Validate parameters
    $functionName = $MyInvocation.MyCommand.Name#region Print a verbose message with received parameters
    Write-Verbose "[$functionName] Received parameters: $($Menu | Out-String)"
    Write-Verbose "[$functionName] Depth: $Depth"
    Write-Verbose "[$functionName] History: $($History | Out-String)"
    Write-Verbose "[$functionName] MenuHistory: $($MenuHistory | Out-String)"
    Write-Verbose "[$functionName] BackoutText: $BackoutText"
    #endregion
    
    # Initialize history if not provided
    if ($null -eq $History)
    {
        Write-Verbose "[$functionName] Initializing history."
        $History = New-Object System.Collections.ArrayList
    }
    
    # Initialize menu history if not provided
    if ($null -eq $MenuHistory)
    {
        Write-Verbose "[$functionName] Initializing menu history."
        $MenuHistory = New-Object System.Collections.ArrayList
    }
    
    # Clear screen for better readability
    # Clear-Host
    Write-Verbose "[$functionName] Clearing the screen for better readability." 
    
    # Add navigation options based on depth
    $choices = @()
    $menuItems = @()
    Write-Verbose "[$functionName] Initializing choices and menu items."
    # Loop through menu items and add to choices
    foreach ($item in $Menu.Items)
    {
        Write-Verbose "[$functionName] Adding item: $($item.Name)"
        $choices += $item.Name
        Write-Verbose "[$functionName] Adding menu $($item.Name) to menu items."
        $menuItems += $item
    }
    
    # Add navigation options - use ASCII friendly characters instead of Unicode arrows
    if ($Depth -gt 0)
    {
        Write-Verbose "[$functionName] Adding navigation since the depth is $depth."
        $choices += "Back"
    }
    if ($Depth -gt 1)
    {
        Write-Verbose "[$functionName] Adding main menu since the depth is $depth."
        $choices += "Main Menu"
    }
    
    # Create banner text
    Write-Verbose "[$functionName] Creating banner text."
    $banner = $Menu.Title
    if (-not [string]::IsNullOrEmpty($Menu.Description))
    {
        Write-Verbose "[$functionName] Adding description to banner."
        $banner += "`n$($Menu.Description)"
    }
    
    # Add current path to banner - create proper breadcrumb
    if ($History.Count -gt 0)
    {
        Write-Verbose "[$functionName] Adding current path to banner, since history count is $($History.Count)"
        # Create a clean breadcrumb path without duplicates
        Write-Verbose "[$functionName] Cleaning history to remove duplicates."
        $cleanHistory = [System.Collections.ArrayList]@()
        $previousItem = ""
        foreach ($item in $History)
        {
            if ($item -ne $previousItem)
            {
                Write-Verbose "[$functionName] Adding item to clean history: $item since it is not equal to $previousItem"
                [void]$cleanHistory.Add($item)
                $previousItem = $item
            }
        }
        $path = $cleanHistory -join " > "
        $banner += "`n[$path]"
    }
    
    # Display menu and get selection
    $selectedOption = DisplayNumericMenu -choices $choices -banner $banner -Prompt "Please select an option" -RequireEnter
    
    # Handle navigation options
    if ($selectedOption -eq "Back")
    {
        Write-Verbose "[$functionName] Going back to previous menu."
        if ($History.Count -gt 0)
        {
            Write-Verbose "[$functionName] Removing last item from history since count is $($History.Count)"
            $History.RemoveAt($History.Count - 1)
            # Get previous menu from MenuHistory
            Write-Verbose "[$functionName] Getting previous menu from MenuHistory since count is $($MenuHistory.Count)"
            $previousMenu = $MenuHistory[$MenuHistory.Count - 1]
            Write-Verbose "[$functionName] Removing last menu from MenuHistory since count is $($MenuHistory.Count)"
            $MenuHistory.RemoveAt($MenuHistory.Count - 1)
            Write-Verbose "[$functionName] Returning to previous menu: $($previousMenu.Title)"
            return ShowMenu -Menu $previousMenu -Depth ($Depth - 1) -History $History -MenuHistory $MenuHistory
        }
    }
    elseif ($selectedOption -eq "Main Menu")
    {
        Write-Verbose "[$functionName] Going to main menu."
        # Go to main menu
        $mainMenu = $MenuHistory[0]
        Write-Verbose "[$functionName] Clearing history and menu history since we are going to main menu."
        $History.Clear()
        $MenuHistory.Clear()
        $MenuHistory.Add($mainMenu)
        return ShowMenu -Menu $mainMenu -Depth 0 -History $History -MenuHistory $MenuHistory
    }
    elseif ($selectedOption -eq 0)
    {
        Write-Verbose "[$functionName] Exiting script."
        return $null
    }
    else
    {
        # Find the selected item
        Write-Verbose "[$functionName] Finding selected item."
        $selectedIndex = $choices.IndexOf($selectedOption)
        Write-Verbose "[$functionName] Selected index: $selectedIndex"
        $selectedItem = $menuItems[$selectedIndex]
        Write-Verbose "[$functionName] Selected item: $($selectedItem |Out-String)"        # Handle action or submenu        
        if ($selectedItem.Action)
        {
            Write-Verbose "[$functionName] Executing action for selected item."
            # Navigation enhancement: Add current menu to history before executing action
            # This ensures that actions can access the full navigation path
            $tempHistory = $History.Clone()
            $tempMenuHistory = $MenuHistory.Clone()
            $tempHistory.Add($Menu.Title)
            $tempMenuHistory.Add($Menu)
            
            # Make navigation parameters available to the action script block via script scope variables
            # This allows action script blocks to access current navigation context when needed
            $script:CurrentMenuDepth = $Depth + 1  # Increment depth for the action
            $script:CurrentMenuHistory = $tempHistory
            $script:CurrentMenuHistory_Menu = $tempMenuHistory            # Execute the action
            $result = & $selectedItem.Action
            
            #If you get the special return boolean, return the value directly.
            if ($selectedItem.ReturnsValue)
            {
                Write-Verbose "[$functionName] Action returned a value: $result"
                return $result
            }
            
            # Check if the action returned a signal to exit the application
            # This happens when actions internally handle exit requests from submenus
            if ($result -eq "EXIT_APPLICATION")
            {
                Write-Verbose "[$functionName] Action requested application exit, propagating exit signal"
                return $null
            }
            
            # If the action returned the backout text, respect it and don't show "press any key"
            if ($result -eq $backoutText)
            {
                Write-Verbose "[$functionName] Action returned backout text, returning to menu"
                return ShowMenu -Menu $Menu -Depth $Depth -History $History -MenuHistory $MenuHistory
            }
            
            # Display action result if any
            if ($null -ne $result)
            {
                Write-Host "`n$result" -ForegroundColor Cyan
            }
            
            Write-Verbose "[$functionName] Action executed: $($selectedItem.Name)"
            Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
            $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            
            return ShowMenu -Menu $Menu -Depth $Depth -History $History -MenuHistory $MenuHistory
        }
        elseif ($selectedItem.Submenu)
        {
            Write-Verbose "[$functionName] Navigating to submenu: $($selectedItem.Submenu.Title)"
            # Navigate to submenu - only add the title once to avoid duplicates
            $History.Add($Menu.Title)
            $MenuHistory.Add($Menu)
            return ShowMenu -Menu $selectedItem.Submenu -Depth ($Depth + 1) -History $History -MenuHistory $MenuHistory
        }
    }
}


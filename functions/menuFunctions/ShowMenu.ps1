function ShowMenu()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Menu,
        [Parameter(Mandatory = $false)]
        [ValidateSet('Auto', 'Push', 'Pop', 'None')]
        [string]$StackOperation = 'Auto',
        [Parameter(Mandatory = $false)]        [string]$CalledBy = 'Unknown'
    )
    
    # region Initialize global variables if they don't exist and display debug
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Checking global variables."
    if (-not $Global:MenuHistory)
    {
        Write-Verbose "[$functionName] Initializing MenuHistory"
        $Global:MenuHistory = [System.Collections.ArrayList]::new() 
    }
    else
    {
        Write-Verbose "[$functionName] MenuHistory is already initialized with $($Global:MenuHistory.Count) items."
    }
    if (-not $Global:History)
    {
        Write-Verbose "[$functionName] Initializing History"
        $Global:History = [System.Collections.ArrayList]::new() 
    }
    else
    {
        Write-Verbose "[$functionName] History is already initialized with $($Global:History.Count) items."
    }
    Write-Verbose "[$functionName] ===== MENU NAVIGATION DEBUG ====="
    Write-Verbose "[$functionName] Entering ShowMenu for: $($Menu.Title)"
    Write-Verbose "[$functionName] CalledBy: $CalledBy"
    Write-Verbose "[$functionName] StackOperation: $StackOperation"
    Write-Verbose "[$functionName] Current Depth: $($Global:MenuHistory.Count)"
    Write-Verbose "[$functionName] History Count: $($Global:History.Count)"
    Write-Verbose "[$functionName] MenuHistory Count: $($Global:MenuHistory.Count)"
    Write-Verbose "[$functionName] Current Menu: $($Menu.Title)"
    Write-Verbose "[$functionName] Previous menu (if available): $($Global:MenuHistory[-1].Title)"
    Write-Verbose "[$functionName] =================================="
    #endregion Initialize global variables if they don't exist and display debug
    
    # Determine calling context if not explicitly provided
    if ($CalledBy -eq 'Unknown')
    {
        Write-Verbose "[$functionName] CalledBy is 'Unknown', determining calling context"
        $CalledBy = Get-CallingContext -Menu $Menu
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
                }
                'Direct'
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
                default
                {
                    # Handle new dynamic context types
                    Write-Verbose "[$functionName] Handling dynamic context: $CalledBy"
                    
                    # Determine behavior based on context pattern
                    switch -Regex ($CalledBy)
                    {
                        '^(Getter|Setter|Creator|Remover|Validator|Connection)_.*'
                        {
                            Write-Verbose "[$functionName] Context suggests data operation - pushing to stack"
                            Push-MenuToStack -Menu $Menu
                        }
                        '^(MenuFunction|ActionFunction)_.*'
                        {
                            Write-Verbose "[$functionName] Context suggests menu/action function - pushing to stack"
                            Push-MenuToStack -Menu $Menu
                        }
                        '^Custom_.*'
                        {
                            Write-Verbose "[$functionName] Custom context - pushing to stack"
                            Push-MenuToStack -Menu $Menu
                        }
                        default
                        {
                            Write-Verbose "[$functionName] Unknown context pattern: $CalledBy - treating as direct call"
                            if ($Global:MenuHistory.Count -eq 0)
                            {
                                Write-Verbose "[$functionName] Empty stack - adding menu"
                                Push-MenuToStack -Menu $Menu
                            }
                            else
                            {
                                Write-Verbose "[$functionName] Existing stack - pushing menu"
                                Push-MenuToStack -Menu $Menu
                            }
                        }
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
    
    # Loop through menu items and add to choices (excluding items in exclusion list)
    foreach ($item in $Menu.Items)
    {
        # If this menu was prefiltered at build time, skip additional include checks
        $includeItem = $false
        # Pass the menus configuration if available, otherwise null (which will allow all items)
        $includeItem = Test-MenuItemIncluded -MenuItemName $item.Name -Menus $menusToPass -CurrentMenu $Menu
        if ($includeItem)
        {
            Write-Verbose "[$functionName] Adding item: $($item.Name)"
            $choices += $item.Name
            $menuItems += $item
        }
        else
        {
            Write-Verbose "[$functionName] Excluding item: $($item.Name)"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Excluding menu item from display: $($item.Name)" -LogLevel "Information"
        }
    }
    
    # Clear screen for better readability
    # Clear-Host
    Write-Verbose "[$functionName] Clearing the screen for better readability." 
    
    # Add navigation options based on current depth
    if ($Global:MenuHistory.Count -gt 1)
    {
        Write-Verbose "[$functionName] Adding 'Back' option since depth is $($Global:MenuHistory.Count)"
        $choices += "Back"
    }
    if ($Global:MenuHistory.Count -gt 2)
    {
        Write-Verbose "[$functionName] Adding 'Main Menu' option since depth is $($Global:MenuHistory.Count)"
        $choices += "Main Menu"
    }
    #endregion

    #region Create banner text and breadcrumb
    $banner = Create-MenuBanner -Menu $Menu -History $Global:History
    if ($null -ne $settings.appMode -and $settings.appMode -ne "full" -and $settings.appMode -ne '')
    {
        Write-Verbose "[$functionName] App mode is not 'full', adding app mode to banner"
        Write-Log -LogFile $LogFile -Module $functionName -Message "App mode is not 'full', adding app mode to banner" -LogLevel "Information"
        $banner = "(App Mode: $($settings.appMode))`n$banner"
    }
    #endregion

    # Display menu and get selection
    $selectedOption = DisplayNumericMenu -choices $choices -banner $banner -Prompt "Please select an option" -RequireEnter
    Write-Verbose "[$functionName] Selected option: $selectedOption"
    
    # Check if the selected option is a return value from global return values
    if ($returnValues -and $selectedOption -in $returnValues.Values)
    {
        Write-Verbose "[$functionName] Selected option is a return value: $selectedOption"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Displaying return value to user: $selectedOption" -LogLevel "Information"
        
        # Display the return value message to the user
        Write-Host "`n$selectedOption" -ForegroundColor Yellow
        Write-Host "`nPress any key to continue..." -ForegroundColor Green
        
        # Wait for user input
        try 
        {
            $null = $host.UI.RawUI.ReadKey("NoEcho, IncludeKeyDown")
        }
        catch 
        {
            Write-Verbose "[$functionName] Error reading key input: $_"
            # Fallback to Read-Host if RawUI fails
            Read-Host "Press Enter to continue"
        }
        
        # Check if we should exit or go back to previous menu
        if ($Global:MenuHistory.Count -gt 1)
        {
            Write-Verbose "[$functionName] Returning to previous menu after displaying return value"
            return Handle-BackNavigation
        }
        else
        {
            Write-Verbose "[$functionName] No previous menu available, exiting application"
            return $returnValues.exitString
        }
    }
    
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
        # Validate that we have items to pass to Handle-MenuItemSelection
        if ($choices.Count -eq 0 -or $menuItems.Count -eq 0)
        {
            Write-Verbose "[$functionName] No menu items available for selection, returning to previous menu or exiting"
            Write-Log -LogFile $LogFile -Module $functionName -Message "No menu items available for selection" -LogLevel "Warning"
            
            if ($Global:MenuHistory.Count -gt 1)
            {
                return Handle-BackNavigation
            }
            else
            {
                return $null
            }
        }
        
        # Handle menu item selection
        # return Handle-MenuItemSelection -SelectedOption $selectedOption -Choices $choices -MenuItems $menuItems -CurrentMenu $Menu
        $selectionResult = Handle-MenuItemSelection -SelectedOption $selectedOption -Choices $choices -MenuItems $menuItems -CurrentMenu $Menu
        # Check if we need to auto-pop the stack for -ReturnsValue actions
        #     # This happens when:
        #     # 1. We pushed a menu to the stack (StackOperation was 'Push' or auto-pushed)
        #     # 2. The result is from a -ReturnsValue action (not navigation commands)
        #     # 3. The result is not null and not a menu object
        if ($selectionResult -and ($StackOperation -eq 'Push' -or ($StackOperation -eq 'Auto' -and $CalledBy -in @('Action', 'Submenu', 'Custom_GroupAssignmentSubmenu'))) -and $selectionResult -notin @("Back", "Main Menu", 0, "0", $null) -and $selectionResult -isnot [hashtable]) 
        {
            Write-Verbose "[$functionName] Auto-popping stack for -ReturnsValue action result: $selectionResult"
            $poppedMenu = Pop-MenuFromStack
            Write-Verbose "[$functionName] Auto-popped menu: $(if ($poppedMenu) { $poppedMenu.Title } else { 'null' })"
        }
        
        return $selectionResult
    }
}



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
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Received parameters: $($choices | Out-String)" -LogLevel "Information"
    Write-Verbose "[$functionName] Prompt: $Prompt"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Prompt: $Prompt" -LogLevel "Information"
    Write-Verbose "[$functionName] ErrorMessage: $errorMessage"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "ErrorMessage: $errorMessage" -LogLevel "Information"
    Write-Verbose "[$functionName] Banner: $banner"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Banner: $banner" -LogLevel "Information"
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
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Valid keys: $($validKeys -join ', ')" -LogLevel "Information"
    
    if ($RequireEnter)
    {
        # Original behavior with ReadLine
        Write-Verbose "[$functionName] Using ReadLine for input (requires Enter key)..."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Using ReadLine for input (requires Enter key)..." -LogLevel "Information"
        Write-Host "$Prompt " -NoNewline -ForegroundColor Yellow
        $selection = $host.UI.ReadLine()
        Write-Verbose "[$functionName] User input received: '$selection'"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "User input received: '$selection'" -LogLevel "Information"
        Start-Sleep -Milliseconds 600
        # Clean input
        $selection = $selection.Trim()
        Write-Verbose "[$functionName] Raw user input received after cleanup: '$selection'"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Raw user input received after cleanup: '$selection'" -LogLevel "Information"
    }
    else
    {
        # New behavior with immediate keystroke capture
        Write-Verbose "[$functionName] Waiting for keystroke input (no Enter required)..."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Waiting for keystroke input (no Enter required)..." -LogLevel "Information"
        Write-Host "$Prompt " -NoNewline -ForegroundColor Yellow
        $keyInfo = $null
        $selection = $null
        # Keep reading keys until a valid one is pressed
        do
        {
            Write-Verbose "[$functionName] Waiting for key press..."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Waiting for key press..." -LogLevel "Information"
            try
            {
                $keyInfo = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                $selection = $keyInfo.Character.ToString()
                Write-Verbose "[$functionName] Key pressed: '$selection' (Character code: $([int]$keyInfo.Character))"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Key pressed: '$selection' (Character code: $([int]$keyInfo.Character))" -LogLevel "Information"
                $keyCode = [int]$keyInfo.VirtualKeyCode
                Write-Verbose "[$functionName] Key pressed virtual code: '$selection' (Character code: $([int]$keyInfo.Character), VK: $keyCode)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Key pressed virtual code: '$selection' (Character code: $([int]$keyInfo.Character), VK: $keyCode)" -LogLevel "Information"
                # Handle special case for numpad keys which might have different character codes
                if ($keyCode -ge 96 -and $keyCode -le 105)
                {
                    # Convert numpad key codes (96-105) to numbers (0-9)
                    Write-Verbose "[$functionName] Detected numpad key press."
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Detected numpad key press." -LogLevel "Verbose"
                    $selection = ($keyCode - 96).ToString()
                    Write-Verbose "[$functionName] Converted numpad key to: $selection"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Converted numpad key to: $selection" -LogLevel "Information"
                }
            }
            catch
            {
                Write-Verbose "[$functionName] Error reading key: $_"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error reading key: $_" -LogLevel "Error"
                $selection = $null
            }
        } until ($validKeys -contains $selection)
        
        # Echo the selection so user can see what was chosen
        Write-Host $selection
        Write-Verbose "[$functionName] Valid key pressed: '$selection'"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Valid key pressed: '$selection'" -LogLevel "Information"
    }
    
    # Validate the selection
    while ($selection -notmatch '^\d+$' -or [int]$selection -lt 0 -or [int]$selection -gt $choices.Count)
    {
        Write-Host $errorMessage -ForegroundColor Red
        Write-Verbose "[$functionName] Invalid selection: '$selection'"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Invalid selection: '$selection'" -LogLevel "Error"
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
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning choice at index $($index): '$($choices[$index])'" -LogLevel "Information"
        # Return the selected choice
        return $choices[$index]
    }
    else
    {
        Write-Verbose "[$functionName] Exiting script with selection: $selection"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Exiting script with selection: $selection" -LogLevel "Information"
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
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Creating new menu with title: $Title and description: $Description"    " -LogLevel "Information"
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
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Adding the following menu item:" -LogLevel "Information"
    Write-Verbose "[$functionName] name: $Name"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "name: $Name" -LogLevel "Information"
    if ($null -ne $action -or $action -eq '')
    {
        Write-Verbose "[$functionName] Type: action"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Type: action" -LogLevel "Information"
    }
    if ($null -ne $Submenu -or $Submenu -eq '')
    {
        Write-Verbose "[$functionName] Type: submenu"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Type: submenu" -LogLevel "Information"
    }
    Write-Verbose "[$functionName] returns value: $ReturnsValue"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "returns value: $ReturnsValue" -LogLevel "Information"
    $Menu.Items += $item
    return $Menu
}

function Get-CallingContext()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [hashtable]$Menu = $null,
        [Parameter(Mandatory = $false)]
        [string]$PreferredContext = $null,
        [Parameter(Mandatory = $false)]
        [switch]$IncludeNavigationPath
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Analyzing call stack to determine context"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Analyzing call stack to determine context" -LogLevel "Information"
    Write-Verbose "[$functionName] PreferredContext: $PreferredContext"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "PreferredContext: $PreferredContext" -LogLevel "Information"
    Write-Verbose "[$functionName] Menu provided: $($null -ne $Menu)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Menu provided: $($null -ne $Menu)" -LogLevel "Information"
    Write-Verbose "[$functionName] IncludeNavigationPath: $IncludeNavigationPath"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "IncludeNavigationPath: $IncludeNavigationPath" -LogLevel "Information"
    
    $callStack = Get-PSCallStack
    Write-Verbose "[$functionName] Call stack depth: $($callStack.Count)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Call stack depth: $($callStack.Count)" -LogLevel "Information"
    
    # If PreferredContext is provided and valid, use it (but still apply navigation path if requested)
    if ($PreferredContext -and $PreferredContext -in @('Direct', 'Action', 'Submenu', 'Navigation'))
    {
        Write-Verbose "[$functionName] Using preferred context: $PreferredContext"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Using preferred context: $PreferredContext" -LogLevel "Information"
        $baseContext = $PreferredContext
    }
    else
    {
        # Determine base context using original logic
        $baseContext = Get-BaseCallingContext -CallStack $callStack -Menu $Menu
    }
    
    # If navigation path is requested and available, enhance the context
    if ($IncludeNavigationPath -and $Global:MenuHistory -and $Global:MenuHistory.Count -gt 0)
    {
        $navigationContext = Get-NavigationPathContext
        if ($navigationContext -ne 'Unknown')
        {
            $enhancedContext = "$baseContext-$navigationContext"
            Write-Verbose "[$functionName] Enhanced context with navigation path: $enhancedContext"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Enhanced context with navigation path: $enhancedContext" -LogLevel "Information"
            return $enhancedContext
        }
    }
    
    Write-Verbose "[$functionName] Returning base context: $baseContext"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning base context: $baseContext" -LogLevel "Information"
    return $baseContext
}

function Get-BaseCallingContext()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$CallStack,
        [Parameter(Mandatory = $false)]
        [hashtable]$Menu = $null
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Look at the calling function (skip current function and Get-CallingContext)
    if ($CallStack.Count -gt 2)
    {
        Write-Verbose "[$functionName] Call stack has sufficient depth, analyzing caller"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Call stack has sufficient depth, analyzing caller" -LogLevel "Information"
        $caller = $CallStack[2]  # Skip Get-CallingContext and Get-BaseCallingContext
        Write-Verbose "[$functionName] Called from: $($caller.FunctionName) at line $($caller.ScriptLineNumber)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Called from: $($caller.FunctionName) at line $($caller.ScriptLineNumber)" -LogLevel "Information"
        
        # If called from ShowMenu itself, it's likely navigation
        if ($caller.FunctionName -eq 'ShowMenu')
        {
            Write-Verbose "[$functionName] Called from ShowMenu, assuming navigation context"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Called from ShowMenu, assuming navigation context" -LogLevel "Information"
            return 'Navigation'
        }
        
        # Check if called from known navigation functions
        if ($caller.FunctionName -in @('Handle-BackNavigation', 'Handle-MainMenuNavigation', 'GoBack', 'GoToMainMenu'))
        {
            Write-Verbose "[$functionName] Called from known navigation function: $($caller.FunctionName)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Called from known navigation function: $($caller.FunctionName)" -LogLevel "Information"
            return 'Navigation'
        }
        
        # Check if called from menu item action execution functions
        if ($caller.FunctionName -in @('Handle-ActionExecution', 'Handle-MenuItemSelection'))
        {
            Write-Verbose "[$functionName] Called from action execution function: $($caller.FunctionName)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Called from action execution function: $($caller.FunctionName)" -LogLevel "Information"
            return 'Action'
        }
        
        # Check if called from submenu navigation functions
        if ($caller.FunctionName -in @('Handle-SubmenuNavigation'))
        {
            Write-Verbose "[$functionName] Called from submenu navigation function: $($caller.FunctionName)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Called from submenu navigation function: $($caller.FunctionName)" -LogLevel "Information"
            return 'Submenu'
        }
        
        # Generate unique context based on calling function properties
        $callerContext = Get-UniqueCallerContext -CallStack $CallStack -Menu $Menu
        if ($callerContext -ne 'Unknown')
        {
            Write-Verbose "[$functionName] Generated unique caller context: $callerContext"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Generated unique caller context: $callerContext" -LogLevel "Information"
            return $callerContext
        }
    }
    
    # If we can't determine from call stack, assume direct call
    Write-Verbose "[$functionName] Unable to determine specific context, defaulting to 'Direct'"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Unable to determine specific context, defaulting to 'Direct'" -LogLevel "Error"
    return 'Direct'
}

function Get-NavigationPathContext()
{
    [CmdletBinding()]
    param()
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Analyzing navigation path from MenuHistory"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Analyzing navigation path from MenuHistory" -LogLevel "Information"
    
    if (-not $Global:MenuHistory -or $Global:MenuHistory.Count -eq 0)
    {
        Write-Verbose "[$functionName] No menu history available"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No menu history available" -LogLevel "Information"
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
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Added normalized menu title: $normalizedTitle" -LogLevel "Information"
        }
    }
    
    if ($menuTitles.Count -eq 0)
    {
        Write-Verbose "[$functionName] No valid menu titles found in history"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No valid menu titles found in history" -LogLevel "Information"
        return 'Unknown'
    }
    
    # Generate context based on navigation path patterns
    $pathSignature = $menuTitles -join '-'
    Write-Verbose "[$functionName] Generated path signature: $pathSignature"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Generated path signature: $pathSignature" -LogLevel "Information"
    
    # Check for specific known navigation patterns
    switch -Regex ($pathSignature)
    {
        'MainMenu-CheckDeviceStatus-LookupbySerialNumber'
        {
            Write-Verbose "[$functionName] Detected CheckMenu -> SerialNumber navigation path"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Detected CheckMenu -> SerialNumber navigation path" -LogLevel "Verbose"
            return 'ViaCheckMenu'
        }
        'MainMenu-AutopilotMenu-CheckdeviceAutopilotstatus'
        {
            Write-Verbose "[$functionName] Detected AutopilotMenu -> SerialNumber navigation path"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Detected AutopilotMenu -> SerialNumber navigation path" -LogLevel "Verbose"
            return 'ViaAutopilotMenu'
        }
        'MainMenu-AutopilotMenu.*SerialNumber'
        {
            Write-Verbose "[$functionName] Detected general AutopilotMenu -> SerialNumber navigation path"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Detected general AutopilotMenu -> SerialNumber navigation path" -LogLevel "Verbose"
            return 'ViaAutopilotMenu'
        }
        'MainMenu-CheckDeviceStatus.*SerialNumber'
        {
            Write-Verbose "[$functionName] Detected general CheckMenu -> SerialNumber navigation path"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Detected general CheckMenu -> SerialNumber navigation path" -LogLevel "Verbose"
            return 'ViaCheckMenu'
        }
        default
        {
            # For unknown patterns, create a generic path-based context
            if ($menuTitles.Count -gt 1)
            {
                $parentMenu = $menuTitles[-2]  # Second to last menu (parent of current)
                Write-Verbose "[$functionName] Creating context based on parent menu: $parentMenu"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Creating context based on parent menu: $parentMenu" -LogLevel "Information"
                return "Via$parentMenu"
            }
            else
            {
                Write-Verbose "[$functionName] Single menu in path, using direct context"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Single menu in path, using direct context" -LogLevel "Information"
                return 'Direct'
            }
        }
    }
}

function Get-UniqueCallerContext()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$CallStack,
        [Parameter(Mandatory = $false)]
        [hashtable]$Menu = $null
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Generating unique context from call stack"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Generating unique context from call stack" -LogLevel "Information"
    
    if ($CallStack.Count -lt 2) 
    {
        Write-Verbose "[$functionName] Insufficient call stack depth"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Insufficient call stack depth" -LogLevel "Information"
        return 'Unknown'
    }
    
    # Skip Get-CallingContext (index 0) and look at actual caller (index 1)
    $caller = $CallStack[1]
    Write-Verbose "[$functionName] Caller: $caller"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Caller: $caller" -LogLevel "Information"
    $callerFunction = $caller.FunctionName
    Write-Verbose "[$functionName] Caller function name: $callerFunction"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Caller function name: $callerFunction" -LogLevel "Information"
    $callerLine = $caller.ScriptLineNumber
    Write-Verbose "[$functionName] Caller line number: $callerLine"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Caller line number: $callerLine" -LogLevel "Information"
    if ($null -ne $caller.ScriptName)
    {
        $callerFile = Split-Path -Leaf $caller.ScriptName    
        Write-Verbose "[$functionName] Caller script name: $callerFile"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Caller script name: $callerFile" -LogLevel "Information"
    }
    else
    {
        Write-Verbose "[$functionName] Caller script name is null"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Caller script name is null" -LogLevel "Information"
        $callerFile = 'main.exe'
    }
    
    
    Write-Verbose "[$functionName] Analyzing caller: $callerFunction in $callerFile at line $callerLine"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Analyzing caller: $callerFunction in $callerFile at line $callerLine" -LogLevel "Information"
    
    # Create context based on function name patterns
    switch -Regex ($callerFunction)
    {
        '^Get-.*'
        {
            Write-Verbose "[$functionName] Caller appears to be a Get function"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Caller appears to be a Get function" -LogLevel "Information"
            return "Getter_$($callerFunction)"
        }
        '^Set-.*'
        {
            Write-Verbose "[$functionName] Caller appears to be a Set function"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Caller appears to be a Set function" -LogLevel "Information"
            return "Setter_$($callerFunction)"
        }
        '^New-.*'
        {
            Write-Verbose "[$functionName] Caller appears to be a New/Create function"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Caller appears to be a New/Create function" -LogLevel "Information"
            return "Creator_$($callerFunction)"
        }
        '^Remove-.*|^Delete-.*'
        {
            Write-Verbose "[$functionName] Caller appears to be a Remove/Delete function"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Caller appears to be a Remove/Delete function" -LogLevel "Information"
            return "Remover_$($callerFunction)"
        }
        '^Test-.*|^Validate-.*'
        {
            Write-Verbose "[$functionName] Caller appears to be a Test/Validate function"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Caller appears to be a Test/Validate function" -LogLevel "Information"
            return "Validator_$($callerFunction)"
        }
        '^Connect-.*|^Disconnect-.*'
        {
            Write-Verbose "[$functionName] Caller appears to be a Connection function"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Caller appears to be a Connection function" -LogLevel "Information"
            return "Connection_$($callerFunction)"
        }
        '.*Menu.*'
        {
            Write-Verbose "[$functionName] Caller appears to be menu-related"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Caller appears to be menu-related" -LogLevel "Information"
            return "MenuFunction_$($callerFunction)"
        }
        '.*Action.*|.*Execute.*'
        {
            Write-Verbose "[$functionName] Caller appears to be action/execution related"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Caller appears to be action/execution related" -LogLevel "Information"
            return "ActionFunction_$($callerFunction)"
        }
        default
        {
            # If no pattern matches, create context based on file and function combination
            if ($callerFile -and $callerFunction)
            {
                $fileBaseName = [System.IO.Path]::GetFileNameWithoutExtension($callerFile)
                Write-Verbose "[$functionName] Creating context from file and function: $fileBaseName/$callerFunction"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Creating context from file and function: $fileBaseName/$callerFunction" -LogLevel "Information"
                return "Custom_$($fileBaseName)_$($callerFunction)"
            }
            else
            {
                Write-Verbose "[$functionName] Unable to create unique context, caller function: $callerFunction"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Unable to create unique context, caller function: $callerFunction" -LogLevel "Error"
                return 'Unknown'
            }
        }
    }
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
        if ($Global:MenuHistory.Count -eq 0 -or $Global:MenuHistory[$Global:MenuHistory.Count - 1].Title -ne $Menu.Title)
        {
            Write-Verbose "[$functionName] Pushing menu '$($Menu.Title)' to stack"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Pushing menu '$($Menu.Title)' to stack" -LogLevel "Information"
            Write-Verbose "[$functionName] Current History Count: $($Global:History.Count)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Current History Count: $($Global:History.Count)" -LogLevel "Information"
            [void]$Global:History.Add($Menu.Title)
            Write-Verbose "[$functionName] New History Count: $($Global:History.Count)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "New History Count: $($Global:History.Count)" -LogLevel "Information"
            Write-Verbose "[$functionName] Current History: $($Global:History -join ', ')"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Current History: $($Global:History -join ', ')" -LogLevel "Information"
            Write-Verbose "[$functionName] Current MenuHistory Count: $($Global:MenuHistory.Count)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Current MenuHistory Count: $($Global:MenuHistory.Count)" -LogLevel "Information"
            [void]$Global:MenuHistory.Add($Menu)
            Write-Verbose "[$functionName] New MenuHistory Count: $($Global:MenuHistory.Count)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "New MenuHistory Count: $($Global:MenuHistory.Count)" -LogLevel "Information"
            Write-Verbose "[$functionName] Pushed menu '$($Menu.Title)' to stack. New depth: $($Global:MenuHistory.Count)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Pushed menu '$($Menu.Title)' to stack. New depth: $($Global:MenuHistory.Count)" -LogLevel "Information"
        }
        else
        {
            Write-Verbose "[$functionName] Menu '$($Menu.Title)' already at top of stack, skipping push"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Menu '$($Menu.Title)' already at top of stack, skipping push" -LogLevel "Information"
        }
    }
    catch
    {
        Write-Verbose "[$functionName] Error pushing to stack: $_"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error pushing to stack: $_" -LogLevel "Error"
        # Fallback for PowerShell 5.1 compatibility
        Write-Verbose "[$functionName] Using fallback method to push menu '$($Menu.Title)'"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Using fallback method to push menu '$($Menu.Title)'" -LogLevel "Information"
        Write-Verbose "Current history count: $($Global:History.Count)"
        $Global:History += $Menu.Title
        Write-Verbose "New history count: $($Global:History.Count)"
        Write-Verbose "Current menu history count: $($Global:MenuHistory.Count)"
        $Global:MenuHistory += $Menu
        Write-Verbose "New menu history count: $($Global:MenuHistory.Count)"
        Write-Verbose "[$functionName] Used fallback method to push menu '$($Menu.Title)'. New depth: $($Global:MenuHistory.Count)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Used fallback method to push menu '$($Menu.Title)'. New depth: $($Global:MenuHistory.Count)" -LogLevel "Information"
    }
}

function Pop-MenuFromStack()
{
    [CmdletBinding()]
    param()
    
    $functionName = $MyInvocation.MyCommand
    if ($Global:History.Count -gt 0 -and $Global:MenuHistory.Count -gt 0)
    {
        Write-Verbose "[$functionName] Starting pop operation"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Starting pop operation" -LogLevel "Information"
        Write-Verbose "[$functionName] Popping menu from stack"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Popping menu from stack" -LogLevel "Information"
        try
        {
            Write-Verbose "[$functionName] Current History Count: $($Global:History.Count)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Current History Count: $($Global:History.Count)" -LogLevel "Information"
            Write-Verbose "[$functionName] Current History : $($Global:History -join ', ')"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Current History : $($Global:History -join ', ')" -LogLevel "Information"
            $Global:History.RemoveAt($Global:History.Count - 1)
            Write-Verbose "[$functionName] New History Count: $($Global:History.Count)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "New History Count: $($Global:History.Count)" -LogLevel "Information"
            Write-Verbose "[$functionName] New history: $($Global:History -join ', ')"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "New history: $($Global:History -join ', ')" -LogLevel "Information"
            Write-Verbose "[$functionName] Current MenuHistory Count: $($Global:MenuHistory.Count)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Current MenuHistory Count: $($Global:MenuHistory.Count)" -LogLevel "Information"
            # Write-Verbose "[$functionName] Current MenuHistory: $($Global:MenuHistory | ForEach-Object { $_.Title } -join ', ')"
            
            # Get the menu that was just removed for logging
            $poppedMenu = $Global:MenuHistory[$Global:MenuHistory.Count - 1]
            Write-Verbose "[$functionName] Removing menu: $($poppedMenu.Title)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Removing menu: $($poppedMenu.Title)" -LogLevel "Information"
            # Remove the current menu from the stack
            $Global:MenuHistory.RemoveAt($Global:MenuHistory.Count - 1)
            Write-Verbose "[$functionName] New MenuHistory Count after pop: $($Global:MenuHistory.Count)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "New MenuHistory Count after pop: $($Global:MenuHistory.Count)" -LogLevel "Information"
            # Create a simple array of titles for display
            $menuTitles = $Global:MenuHistory | ForEach-Object { $_.Title }
            $menuTitlesString = $menuTitles -join ', '
            Write-Verbose "[$functionName] New MenuHistory: $menuTitlesString"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "New MenuHistory: $menuTitlesString" -LogLevel "Information"
            # Return the menu that is now at the top of the stack (the previous menu)
            if ($Global:MenuHistory.Count -gt 0)
            {
                Write-Verbose "[$functionName] Latest MenuHistory Count: $($Global:MenuHistory.Count)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Latest MenuHistory Count: $($Global:MenuHistory.Count)" -LogLevel "Information"
                Write-Verbose "[$functionName] Stack is not empty, returning to previous menu"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Stack is not empty, returning to previous menu" -LogLevel "Information"
                try
                {
                    $targetMenu = $Global:MenuHistory[$Global:MenuHistory.Count - 1]
                    if ($targetMenu -and $targetMenu.Title)
                    {
                        Write-Verbose "[$functionName] Previous menu: $($targetMenu.Title)"
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Previous menu: $($targetMenu.Title)" -LogLevel "Information"
                        Write-Verbose "[$functionName] Returning to previous menu: $($targetMenu.Title)"
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning to previous menu: $($targetMenu.Title)" -LogLevel "Information"
                        return $targetMenu
                    }
                    else
                    {
                        Write-Verbose "[$functionName] Error: Target menu is null or missing Title property"
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error: Target menu is null or missing Title property" -LogLevel "Error"
                        return $null
                    }
                }
                catch
                {
                    Write-Verbose "[$functionName] Error accessing target menu: $_"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error accessing target menu: $_" -LogLevel "Error"
                    return $null
                }
            }
            else
            {
                Write-Verbose "[$functionName] Latest MenuHistory Count: $($Global:MenuHistory.Count)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Latest MenuHistory Count: $($Global:MenuHistory.Count)" -LogLevel "Information"
                Write-Verbose "[$functionName] Stack is now empty, cannot return to previous menu"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Stack is now empty, cannot return to previous menu" -LogLevel "Error"
                return $null
            }        
        }
        catch
        {
            Write-Verbose "[$functionName] Error popping from stack: $_"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error popping from stack: $_" -LogLevel "Error"
            Write-Verbose "[$functionName] Error details: $($_.Exception.Message)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error details: $($_.Exception.Message)" -LogLevel "Error"
            Write-Verbose "[$functionName] Stack trace: $($_.ScriptStackTrace)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Stack trace: $($_.ScriptStackTrace)" -LogLevel "Information"
            return $null
        }
    }
    else
    {
        Write-Verbose "[$functionName] Cannot pop - stack is empty"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Cannot pop - stack is empty" -LogLevel "Error"
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
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Creating banner for menu: $($Menu.Title)" -LogLevel "Information"
    if (-not [string]::IsNullOrEmpty($Menu.Description))
    {
        Write-Verbose "[$functionName] Adding description to banner: $($Menu.Description)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Adding description to banner: $($Menu.Description)" -LogLevel "Information"
        $banner += "`n$($Menu.Description)"
        Write-Verbose "Banner after adding description: $banner"
    }
    
    # Create breadcrumb
    if ($History.Count -gt 0)
    {
        Write-Verbose "[$functionName] Creating breadcrumb from history"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Creating breadcrumb from history" -LogLevel "Information"
        $cleanHistory = @()
        $previousItem = ""
        foreach ($item in $History)
        {
            Write-Verbose "[$functionName] Processing history item: $item"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Processing history item: $item" -LogLevel "Verbose"
            if ($item -ne $previousItem -and ![string]::IsNullOrWhiteSpace($item))
            {
                Write-Verbose "[$functionName] Adding the item $item to clean history since it is not equal to the previous item '$previousItem'"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Adding the item $item to clean history since it is not equal to the previous item '$previousItem'" -LogLevel "Information"
                $cleanHistory += $item
                $previousItem = $item
                Write-Verbose "[$functionName] Updated previous item to: $previousItem"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Updated previous item to: $previousItem" -LogLevel "Information"
            }
        }
        
        if ($cleanHistory.Count -gt 0)
        {
            Write-Verbose "[$functionName] Clean history created with items: $($cleanHistory -join ', ')"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Clean history created with items: $($cleanHistory -join ', ')" -LogLevel "Information"
            $path = $cleanHistory -join " > "
            if ($cleanHistory[-1] -eq $Menu.Title)
            {
                Write-Verbose "[$functionName] Last item in clean history is the current menu title, using path: $path"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Last item in clean history is the current menu title, using path: $path" -LogLevel "Information"
                $banner += "`n[$path]"
                Write-Verbose "Banner after adding breadcrumb: $banner"
            }
            else
            {
                Write-Verbose "[$functionName] Last item in clean history is not the current menu title, appending current menu title"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Last item in clean history is not the current menu title, appending current menu title" -LogLevel "Information"
                $banner += "`n[$path > $($Menu.Title)]"
                Write-Verbose "Banner after appending current menu title: $banner"
            }
        }
        else
        {
            Write-Verbose "[$functionName] Clean history is empty, using only current menu title"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Clean history is empty, using only current menu title" -LogLevel "Information"
            $banner += "`n[$($Menu.Title)]"
            Write-Verbose "Banner after using only current menu title: $banner"
        }
    }
    else
    {
        Write-Verbose "[$functionName] History is empty, using only current menu title"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "History is empty, using only current menu title" -LogLevel "Information"
        $banner += "`n[$($Menu.Title)]"
        Write-Verbose "Banner after using only current menu title: $banner"
    }
    Write-Verbose "[$functionName] Final banner created: $banner"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Final banner created: $banner" -LogLevel "Information"
    return $banner
}

function Handle-BackNavigation()
{
    [CmdletBinding()]
    param()
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Handling back navigation"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Handling back navigation" -LogLevel "Information"
    
    if ($Global:MenuHistory.Count -gt 0)
    {
        Write-Verbose "[$functionName] Current MenuHistory Count: $($Global:MenuHistory.Count)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Current MenuHistory Count: $($Global:MenuHistory.Count)" -LogLevel "Information"
        $targetMenu = Pop-MenuFromStack
        
        if ($targetMenu)
        {
            Write-Verbose "[$functionName] Returning to previous menu: $($targetMenu.Title)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning to previous menu: $($targetMenu.Title)" -LogLevel "Information"
            return ShowMenu -Menu $targetMenu -CalledBy 'Navigation' -StackOperation 'None'
        }
    }
    
    Write-Verbose "[$functionName] Cannot go back - no previous menu available"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Cannot go back - no previous menu available" -LogLevel "Error"
    return $null
}

function Handle-MainMenuNavigation()
{
    [CmdletBinding()]
    param()
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Handling main menu navigation"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Handling main menu navigation" -LogLevel "Information"
    
    if ($Global:MenuHistory.Count -gt 0)
    {
        Write-Verbose "[$functionName] Current MenuHistory Count: $($Global:MenuHistory.Count)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Current MenuHistory Count: $($Global:MenuHistory.Count)" -LogLevel "Information"
        $mainMenu = $Global:MenuHistory[0]
        Write-Verbose "[$functionName] Clearing stack and returning to main menu: $($mainMenu.Title)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Clearing stack and returning to main menu: $($mainMenu.Title)" -LogLevel "Information"
        
        # Clear stack and reset to main menu
        $Global:History.Clear()
        $Global:MenuHistory.Clear()
        
        return ShowMenu -Menu $mainMenu -CalledBy 'Navigation' -StackOperation 'Push'
    }
    
    Write-Verbose "[$functionName] Cannot go to main menu - no main menu available"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Cannot go to main menu - no main menu available" -LogLevel "Error"
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
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking choice $($i): $($Choices[$i]) against selected option: $SelectedOption" -LogLevel "Verbose"
        if ($Choices[$i] -eq $SelectedOption)
        {
            Write-Verbose "[$functionName] Match found at index $i"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Match found at index $i" -LogLevel "Information"
            $selectedIndex = $i
            break
        }
    }
    
    if ($selectedIndex -eq -1 -or $selectedIndex -ge $MenuItems.Count)
    {
        Write-Verbose "[$functionName] Invalid selection index: $selectedIndex"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Invalid selection index: $selectedIndex" -LogLevel "Error"
        return ShowMenu -Menu $CurrentMenu -CalledBy 'Direct' -StackOperation 'None'
    }
    
    $selectedItem = $MenuItems[$selectedIndex]
    Write-Verbose "[$functionName] Selected item: $($selectedItem.Name)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Selected item: $($selectedItem.Name)" -LogLevel "Information"
    
    if ($selectedItem.Action)
    {
        Write-Verbose "[$functionName] Selected item has an Action"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Selected item has an Action" -LogLevel "Information"
        return Handle-ActionExecution -SelectedItem $selectedItem -CurrentMenu $CurrentMenu
    }
    elseif ($selectedItem.Submenu)
    {
        Write-Verbose "[$functionName] Selected item has a Submenu"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Selected item has a Submenu" -LogLevel "Information"
        return Handle-SubmenuNavigation -SelectedItem $selectedItem
    }
    else
    {
        Write-Verbose "[$functionName] Selected item has neither Action nor Submenu"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Selected item has neither Action nor Submenu" -LogLevel "Information"
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
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Executing action: $($SelectedItem.Name)" -LogLevel "Information"
    
    # Execute the action
    $result = & $SelectedItem.Action
    Write-Verbose "[$functionName] Action executed, result: $result"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Action executed, result: $result" -LogLevel "Information"
    
    # Handle different result types
    if ($SelectedItem.ReturnsValue)
    {
        Write-Verbose "[$functionName] Action returns a value, processing result"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Action returns a value, processing result" -LogLevel "Verbose"
        # Handle navigation results from actions
        if ($result -eq "Back")
        {
            Write-Verbose "[$functionName] Action returned 'Back', navigating back"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Action returned 'Back', navigating back" -LogLevel "Information"
            return Handle-BackNavigation
        }
        elseif ($result -eq "Main Menu")
        {
            Write-Verbose "[$functionName] Action returned 'Main Menu', navigating to main menu"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Action returned 'Main Menu', navigating to main menu" -LogLevel "Information"
            return Handle-MainMenuNavigation
        }
        elseif ($result -eq 0)
        {
            Write-Verbose "[$functionName] Action returned 0, exiting application"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Action returned 0, exiting application" -LogLevel "Information"
            return [int]$result
        }
        
        Write-Verbose "[$functionName] Action returned value: $result"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Action returned value: $result" -LogLevel "Information"
        return $result
    }
    
    # Handle special signals
    if ($result -eq "EXIT_APPLICATION")
    {
        Write-Verbose "[$functionName] Action requested application exit because result is $result"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Action requested application exit because result is $result" -LogLevel "Information"
        return $null
    }
    
    if ($result -eq $returnValues.backoutText)
    {
        Write-Verbose "[$functionName] Action returned backout text because result is $result"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Action returned backout text because result is $result" -LogLevel "Information"
        return ShowMenu -Menu $CurrentMenu -CalledBy 'Action' -StackOperation 'None'
    }
    
    # Display result and continue
    if ($null -ne $result)
    {
        Write-Host "`n$result" -ForegroundColor Cyan
    }
    
    Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp")
    
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
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Navigating to submenu: $($SelectedItem.Submenu.Title)" -LogLevel "Information"
    
    return ShowMenu -Menu $SelectedItem.Submenu -CalledBy 'Submenu' -StackOperation 'Auto'
}

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
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking global variables." -LogLevel "Verbose"
    if (-not $Global:MenuHistory)
    {
        Write-Verbose "[$functionName] Initializing MenuHistory"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Initializing MenuHistory" -LogLevel "Information"
        $Global:MenuHistory = [System.Collections.ArrayList]::new() 
    }
    else
    {
        Write-Verbose "[$functionName] MenuHistory is already initialized with $($Global:MenuHistory.Count) items."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "MenuHistory is already initialized with $($Global:MenuHistory.Count) items." -LogLevel "Information"
    }
    if (-not $Global:History)
    {
        Write-Verbose "[$functionName] Initializing History"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Initializing History" -LogLevel "Information"
        $Global:History = [System.Collections.ArrayList]::new() 
    }
    else
    {
        Write-Verbose "[$functionName] History is already initialized with $($Global:History.Count) items."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "History is already initialized with $($Global:History.Count) items." -LogLevel "Information"
    }
    Write-Verbose "[$functionName] ===== MENU NAVIGATION DEBUG ====="
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "===== MENU NAVIGATION DEBUG =====" -LogLevel "Information"
    Write-Verbose "[$functionName] Entering ShowMenu for: $($Menu.Title)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Entering ShowMenu for: $($Menu.Title)" -LogLevel "Information"
    Write-Verbose "[$functionName] CalledBy: $CalledBy"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "CalledBy: $CalledBy" -LogLevel "Information"
    Write-Verbose "[$functionName] StackOperation: $StackOperation"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "StackOperation: $StackOperation" -LogLevel "Information"
    Write-Verbose "[$functionName] Current Depth: $($Global:MenuHistory.Count)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Current Depth: $($Global:MenuHistory.Count)" -LogLevel "Information"
    Write-Verbose "[$functionName] History Count: $($Global:History.Count)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "History Count: $($Global:History.Count)" -LogLevel "Information"
    Write-Verbose "[$functionName] MenuHistory Count: $($Global:MenuHistory.Count)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "MenuHistory Count: $($Global:MenuHistory.Count)" -LogLevel "Information"
    Write-Verbose "[$functionName] Current Menu: $($Menu.Title)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Current Menu: $($Menu.Title)" -LogLevel "Information"
    Write-Verbose "[$functionName] Previous menu (if available): $($Global:MenuHistory[-1].Title)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Previous menu (if available): $($Global:MenuHistory[-1].Title)" -LogLevel "Information"
    Write-Verbose "[$functionName] =================================="
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "==================================" -LogLevel "Information"
    #endregion    # Determine calling context if not explicitly provided
    
    if ($CalledBy -eq 'Unknown')
    {
        Write-Verbose "[$functionName] CalledBy is 'Unknown', determining calling context"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "CalledBy is 'Unknown', determining calling context" -LogLevel "Information"
        $CalledBy = Get-CallingContext -Menu $Menu
        Write-Verbose "[$functionName] Determined CalledBy: $CalledBy"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Determined CalledBy: $CalledBy" -LogLevel "Information"
    }
    
    # Handle stack operations based on calling context and explicit instructions
    switch ($StackOperation)
    {
        'Auto'
        {
            Write-Verbose "[$functionName] Auto stack operation based on CalledBy context" 
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Auto stack operation based on CalledBy context" " -LogLevel "Information"
            switch ($CalledBy)
            {
                'Submenu'
                {
                    Write-Verbose "[$functionName] Auto-pushing to stack for submenu navigation"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Auto-pushing to stack for submenu navigation" -LogLevel "Information"
                    Push-MenuToStack -Menu $Menu
                }
                'Action'
                {
                    Write-Verbose "[$functionName] Auto-pushing to stack for action execution"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Auto-pushing to stack for action execution" -LogLevel "Information"
                    Push-MenuToStack -Menu $Menu
                }
                'Navigation'
                {
                    Write-Verbose "[$functionName] No stack operation for navigation"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "No stack operation for navigation" -LogLevel "Information"
                    # Navigation (Back/Main Menu) handles its own stack management
                }
                'Direct'
                {
                    Write-Verbose "[$functionName] Direct call - checking if this is initial menu"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Direct call - checking if this is initial menu" -LogLevel "Verbose"
                    # Check if this is the initial main menu call (already in stack from main.ps1)
                    if ($Global:MenuHistory.Count -eq 1 -and $Global:MenuHistory[0].Title -eq $Menu.Title)
                    {
                        Write-Verbose "[$functionName] Initial main menu call - already in stack, no push needed"
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Initial main menu call - already in stack, no push needed" -LogLevel "Information"
                    }
                    elseif ($Global:MenuHistory.Count -eq 0)
                    {
                        Write-Verbose "[$functionName] Empty stack - adding initial menu"
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Empty stack - adding initial menu" -LogLevel "Information"
                        Push-MenuToStack -Menu $Menu
                    }
                    else
                    {
                        Write-Verbose "[$functionName] Direct call with existing stack - pushing menu"
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Direct call with existing stack - pushing menu" -LogLevel "Information"
                        Push-MenuToStack -Menu $Menu
                    }
                }
                default
                {
                    # Handle new dynamic context types
                    Write-Verbose "[$functionName] Handling dynamic context: $CalledBy"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Handling dynamic context: $CalledBy" -LogLevel "Information"
                    
                    # Determine behavior based on context pattern
                    switch -Regex ($CalledBy)
                    {
                        '^(Getter|Setter|Creator|Remover|Validator|Connection)_.*'
                        {
                            Write-Verbose "[$functionName] Context suggests data operation - pushing to stack"
                            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Context suggests data operation - pushing to stack" -LogLevel "Information"
                            Push-MenuToStack -Menu $Menu
                        }
                        '^(MenuFunction|ActionFunction)_.*'
                        {
                            Write-Verbose "[$functionName] Context suggests menu/action function - pushing to stack"
                            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Context suggests menu/action function - pushing to stack" -LogLevel "Information"
                            Push-MenuToStack -Menu $Menu
                        }
                        '^Custom_.*'
                        {
                            Write-Verbose "[$functionName] Custom context - pushing to stack"
                            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Custom context - pushing to stack" -LogLevel "Information"
                            Push-MenuToStack -Menu $Menu
                        }
                        default
                        {
                            Write-Verbose "[$functionName] Unknown context pattern: $CalledBy - treating as direct call"
                            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Unknown context pattern: $CalledBy - treating as direct call" -LogLevel "Information"
                            if ($Global:MenuHistory.Count -eq 0)
                            {
                                Write-Verbose "[$functionName] Empty stack - adding menu"
                                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Empty stack - adding menu" -LogLevel "Information"
                                Push-MenuToStack -Menu $Menu
                            }
                            else
                            {
                                Write-Verbose "[$functionName] Existing stack - pushing menu"
                                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Existing stack - pushing menu" -LogLevel "Information"
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
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Explicit push to stack" -LogLevel "Information"
            Push-MenuToStack -Menu $Menu
        }
        'Pop'
        {
            Write-Verbose "[$functionName] Explicit pop from stack"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Explicit pop from stack" -LogLevel "Information"
            Pop-MenuFromStack
        }
        'None'
        {
            Write-Verbose "[$functionName] No stack operation requested"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No stack operation requested" -LogLevel "Information"
        }
    }    
    Write-Verbose "[$functionName] Stack state after operation - MenuHistory Count: $($Global:MenuHistory.Count), History: $($Global:History.Count)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Stack state after operation - MenuHistory Count: $($Global:MenuHistory.Count), History: $($Global:History.Count)" -LogLevel "Information"
    Write-Verbose "[$functionName] =================================="
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "==================================" -LogLevel "Information"
    
    #region Display choices and add navigation options
    $choices = @()
    $menuItems = @()
    Write-Verbose "[$functionName] Initializing choices and menu items."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Initializing choices and menu items." -LogLevel "Information"
    
    # Loop through menu items and add to choices
    foreach ($item in $Menu.Items)
    {
        Write-Verbose "[$functionName] Adding item: $($item.Name)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Adding item: $($item.Name)" -LogLevel "Information"
        $choices += $item.Name
        $menuItems += $item
    }

    # Add navigation options based on current depth
    if ($Global:MenuHistory.Count -gt 1)
    {
        Write-Verbose "[$functionName] Adding 'Back' option since depth is $($Global:MenuHistory.Count)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Adding 'Back' option since depth is $($Global:MenuHistory.Count)" -LogLevel "Information"
        $choices += "Back"
    }
    if ($Global:MenuHistory.Count -gt 2)
    {
        Write-Verbose "[$functionName] Adding 'Main Menu' option since depth is $($Global:MenuHistory.Count)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Adding 'Main Menu' option since depth is $($Global:MenuHistory.Count)" -LogLevel "Information"
        $choices += "Main Menu"
    }
    #endregion

    #region Create banner text and breadcrumb
    $banner = Create-MenuBanner -Menu $Menu -History $Global:History
    #endregion

    # Display menu and get selection
    $selectedOption = DisplayNumericMenu -choices $choices -banner $banner -Prompt "Please select an option" -RequireEnter
    Write-Verbose "[$functionName] Selected option: $selectedOption"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Selected option: $selectedOption" -LogLevel "Information"
    
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
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Exiting application" -LogLevel "Information"
        return $null
    }
    else
    {
        # Handle menu item selection
        return Handle-MenuItemSelection -SelectedOption $selectedOption -Choices $choices -MenuItems $menuItems -CurrentMenu $Menu
    }
}


